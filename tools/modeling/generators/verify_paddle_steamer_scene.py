# -*- coding: utf-8 -*-
"""Steam Navigator — SN_Paddle_Steamer 场景只读验收（在 Blender 内运行）。

覆盖 dryrun 查不到的部分：
1. 集合 / 命名 / 层级 / 轴心 / 包围盒 / 三角面 / 材质；
2. 网格健康：非流形边、边界边（甲板允许）、退化面、孤立点；
3. 明轮 8 个旋转角与轮罩、船体、明轮台的三角面相交矩阵（世界坐标 BVH）；
4. 左右对称（船体 + 镜像部件）；
5. 全船连通岛分析：抓悬空 / 松接触部件；
6. 回归：工作台其它对象数量与位置未变（只读快照）。

用法（已连 Blender 的会话，只读）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")
"""

import json
import math

import bpy
import bmesh
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

COLLECTION = "SN_Paddle_Steamer_Prototype"
PREFIX = "SN_PS_"
ROOT = "SN_PS_Root"
TRI_BUDGET = 12000
SIZE_TARGET = (24.4, 8.7, 10.5)
SIZE_TOL = 0.8
PADDLE_PIVOTS = ("SN_PS_Paddle_Port_Pivot", "SN_PS_Paddle_Starboard_Pivot")
OPEN_ALLOWED = {"SN_PS_Deck", "SN_PS_Nameplate_Port", "SN_PS_Nameplate_Starboard"}
FLOATING = 0.05
LOOSE = 0.005
FLOAT_BBOX_GAP = 0.35

# 期望的既有对象（名称 / 近似位置）——回归基线
BASELINE = {
    "Camera": (27.38, -31.32, 21.92),
    "Light": (17.8, -26.73, 30.03),
    "SN_Ship_Root": (0.0, 0.0, 0.0),
    "SN_Crane_Root": (0.0, 16.0, 0.0),
    "SN_PF_Root": (-45.0, 0.0, 0.0),
    "SN_Ironclad": (0.0, 90.0, 0.0),
}


def world_bvh(obj):
    """把对象网格变换到世界坐标后建 BVH。"""
    mw = obj.matrix_world
    me = obj.data
    verts = [mw @ v.co for v in me.vertices]
    polys = [list(p.vertices) for p in me.polygons]
    return BVHTree.FromPolygons(verts, polys, all_triangles=False, epsilon=0.0)


def mesh_health(obj):
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    bm.edges.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    boundary = sum(1 for e in bm.edges if e.is_boundary)
    nonman = sum(1 for e in bm.edges if not e.is_manifold and not e.is_boundary)
    degenerate = 0
    for f in bm.faces:
        if f.calc_area() < 1e-9:
            degenerate += 1
    loose = sum(1 for v in bm.verts if not v.link_edges)
    verts = len(bm.verts)
    faces = len(bm.faces)
    bm.free()
    return {
        "verts": verts, "faces": faces,
        "boundary_edges": boundary, "non_manifold_edges": nonman,
        "degenerate_faces": degenerate, "loose_verts": loose,
    }


def main():
    col = bpy.data.collections[COLLECTION]
    root = bpy.data.objects[ROOT]
    failures = []
    checks = []

    def check(name, ok, detail=""):
        checks.append({"check": name, "passed": bool(ok), "detail": detail})
        if not ok:
            failures.append({"check": name, "detail": detail})

    # 1) 集合 / 命名 / 层级
    mesh_objs = [o for o in col.objects if o.type == "MESH"]
    empty_objs = [o for o in col.objects if o.type == "EMPTY"]
    names = [o.name for o in col.objects]
    check("collection_membership", len(col.objects) == len(mesh_objs) + len(empty_objs))
    bad_prefix = [o.name for o in mesh_objs if not o.name.startswith(PREFIX)]
    check("prefix", not bad_prefix, ",".join(bad_prefix))
    check("root_present", ROOT in names)
    check("root_is_empty", root.type == "EMPTY")
    check("root_at_workbench_pos", (Vector(tuple(root.location)) - Vector((45.0, 0.0, 0.0))).length < 1e-6,
          str(tuple(round(v, 3) for v in root.location)))
    for prop in ("asset", "version", "units", "pivot", "forward_axis", "style", "tri_budget"):
        check("root_prop_" + prop, prop in root.keys())
    check("root_asset", root.get("asset") == "SN_Paddle_Steamer")
    for piv in PADDLE_PIVOTS:
        ob = bpy.data.objects.get(piv)
        check("pivot:" + piv, ob is not None and ob.parent == root)
    for name in ("SN_PS_Paddle_Port", "SN_PS_Paddle_Starboard"):
        ob = bpy.data.objects.get(name)
        check("paddle_parent:" + name, ob is not None and ob.parent is not None
              and ob.parent.name in PADDLE_PIVOTS and ob.parent.name.endswith(
                  "Port_Pivot" if name.endswith("Port") else "Starboard_Pivot"))

    # 2) 三角面 / 包围盒 / 材质
    tris = 0
    mn = Vector((1e18,) * 3)
    mx = Vector((-1e18,) * 3)
    health_fail = []
    mats = set()
    for ob in mesh_objs:
        tris += sum(max(1, len(p.vertices) - 2) for p in ob.data.polygons)
        for c in ob.bound_box:
            p = ob.matrix_world @ Vector(c)
            for i in range(3):
                mn[i] = min(mn[i], p[i])
                mx[i] = max(mx[i], p[i])
        for m in ob.data.materials:
            if m:
                mats.add(m.name)
        h = mesh_health(ob)
        h["object"] = ob.name
        if h["boundary_edges"] and ob.name not in OPEN_ALLOWED:
            health_fail.append((ob.name, "boundary=%d" % h["boundary_edges"]))
        if h["non_manifold_edges"]:
            health_fail.append((ob.name, "nonmanifold=%d" % h["non_manifold_edges"]))
        if h["degenerate_faces"]:
            health_fail.append((ob.name, "degenerate=%d" % h["degenerate_faces"]))
        if h["loose_verts"]:
            health_fail.append((ob.name, "loose=%d" % h["loose_verts"]))
        if len(ob.data.materials) > 8:
            health_fail.append((ob.name, "mat_slots=%d" % len(ob.data.materials)))
    size = tuple(round(mx[i] - mn[i], 3) for i in range(3))
    check("tri_budget", tris <= TRI_BUDGET, "%d / %d" % (tris, TRI_BUDGET))
    check("bbox", all(abs(size[i] - SIZE_TARGET[i]) <= SIZE_TOL for i in range(3)),
          "%.2f x %.2f x %.2f" % size)
    check("mesh_health", not health_fail, str(health_fail[:8]))
    # 批次 C：本船材质槽 8 -> 9，唯一新增为 SN_PS_UpperWhite（上层建筑/舱室「二级白」，
    # 仅 SN_Paddle_Steamer 使用；新增理由：共享材质 SN_Wood_Deck / SN_Flag_White 必须保持原值，
    # 不能拿它们做上层建筑分层）。其它阈值（单对象槽数 ≤8、双面、tri/尺寸等）均未放宽。
    expected_mats = {"SN_White", "SN_Iron_Hull", "SN_Iron_Red", "SN_Wood_Deck",
                     "SN_Metal", "SN_Brass", "SN_Flag_Blue", "SN_Flag_White",
                     "SN_PS_UpperWhite"}
    check("materials", mats == expected_mats, ",".join(sorted(mats)))
    # 单层曲面材质双面
    bad_cull = [n for n in expected_mats
                if (bpy.data.materials.get(n) and bpy.data.materials[n].use_backface_culling)]
    check("materials_double_sided", not bad_cull, ",".join(bad_cull))

    # 3) 明轮 8 旋转角 vs 轮罩 / 船体 / 明轮台（只测桨叶/轮缘/辐条，跳过穿舱轮轴）
    wheel = bpy.data.objects["SN_PS_Paddle_Port"]
    box = bpy.data.objects["SN_PS_Paddle_Box_Port"]
    hull = bpy.data.objects["SN_PS_Hull"]
    sponson = bpy.data.objects["SN_PS_Sponson_Port"]
    targets = {"paddle_box": box, "hull": hull, "sponson": sponson}
    target_bvh = {k: world_bvh(v) for k, v in targets.items()}
    base_mw = wheel.matrix_world.copy()
    pivot_world = bpy.data.objects["SN_PS_Paddle_Port_Pivot"].matrix_world.translation.copy()
    pivot_local = bpy.data.objects["SN_PS_Paddle_Port_Pivot"].matrix_world.inverted() @ pivot_world
    wm = wheel.data

    def rotating_bvh(obj):
        """只取离轮轴 >= 0.55 m 的桨叶 / 轮缘 / 辐条外段。"""
        xc, zc = pivot_local.x, pivot_local.z
        mw = obj.matrix_world
        verts = []
        remap = {}
        polys = []
        for poly in wm.polygons:
            keep = True
            for vi in poly.vertices:
                co = wm.vertices[vi].co
                if math.hypot(co.x - xc, co.z - zc) < 0.55:
                    keep = False
                    break
            if not keep:
                continue
            for vi in poly.vertices:
                if vi not in remap:
                    remap[vi] = len(verts)
                    verts.append(mw @ wm.vertices[vi].co)
            polys.append([remap[vi] for vi in poly.vertices])
        return BVHTree.FromPolygons(verts, polys, all_triangles=False, epsilon=0.0)

    rot_hits = {}
    for deg in range(0, 360, 45):
        rot = (Matrix.Translation(pivot_world)
               @ Matrix.Rotation(math.radians(deg), 4, "Y")
               @ Matrix.Translation(-pivot_world))
        wheel.matrix_world = rot @ base_mw
        bpy.context.view_layer.update()
        wb = rotating_bvh(wheel)
        for key, tb in target_bvh.items():
            if wb.overlap(tb):
                rot_hits.setdefault(key, []).append(deg)
    wheel.matrix_world = base_mw
    bpy.context.view_layer.update()
    check("paddle_clearance", not rot_hits, json.dumps(rot_hits, ensure_ascii=False))

    # 4) 左右对称
    hull_me = hull.data
    left = sorted((round(v.co.x, 5), round(v.co.y, 5), round(v.co.z, 5))
                  for v in hull_me.vertices if v.co.y > 1e-6)
    right = sorted((round(v.co.x, 5), round(-v.co.y, 5), round(v.co.z, 5))
                   for v in hull_me.vertices if v.co.y < -1e-6)
    center = sum(1 for v in hull_me.vertices if abs(v.co.y) < 1e-6)
    mirror_ok = (len(left) == len(right) and all(
        max(abs(a[i] - b[i]) for i in range(3)) < 1e-5 for a, b in zip(left, right)))
    check("hull_mirror", mirror_ok,
          "L=%d R=%d C=%d" % (len(left), len(right), center))

    # 5) 连通岛分析（世界坐标 BVH，逐岛）
    def box_gap(a, b):
        dx = max(0.0, max(a[0] - b[3], b[0] - a[3]))
        dy = max(0.0, max(a[1] - b[4], b[1] - a[4]))
        dz = max(0.0, max(a[2] - b[5], b[2] - a[5]))
        return (dx * dx + dy * dy + dz * dz) ** 0.5

    islands = []
    for ob in mesh_objs:
        me = ob.data
        mw = ob.matrix_world
        n = len(me.vertices)
        parent = list(range(n))

        def find(a):
            while parent[a] != a:
                parent[a] = parent[parent[a]]
                a = parent[a]
            return a

        for e in me.edges:
            ra, rb = find(e.vertices[0]), find(e.vertices[1])
            if ra != rb:
                parent[rb] = ra
        iv, iff = {}, {}
        for v in me.vertices:
            iv.setdefault(find(v.index), []).append(v.index)
        for poly in me.polygons:
            iff.setdefault(find(poly.vertices[0]), []).append(list(poly.vertices))
        for r, vids in iv.items():
            faces = iff.get(r)
            if not faces:
                continue
            local = {vid: i for i, vid in enumerate(vids)}
            verts = [mw @ me.vertices[vid].co for vid in vids]
            fcs = [[local[i] for i in f] for f in faces]
            xs = [v.x for v in verts]
            ys = [v.y for v in verts]
            zs = [v.z for v in verts]
            islands.append({
                "object": ob.name,
                "bbox": (min(xs), min(ys), min(zs), max(xs), max(ys), max(zs)),
                "tree": BVHTree.FromPolygons(verts, fcs, all_triangles=False,
                                             epsilon=0.0),
                "samples": verts[::max(1, len(verts) // 12)][:12],
                "tris": sum(max(0, len(f) - 2) for f in fcs),
            })
    for isl in islands:
        isl["min_dist"] = 1e18
        isl["nearest"] = None
    for i in range(len(islands)):
        a = islands[i]
        for j in range(i + 1, len(islands)):
            b = islands[j]
            if box_gap(a["bbox"], b["bbox"]) > FLOAT_BBOX_GAP:
                continue
            if a["tree"].overlap(b["tree"]):
                best = 0.0
            else:
                best = 1e18
                for p in a["samples"]:
                    hit = b["tree"].find_nearest(p)
                    if hit[0] is not None and hit[3] < best:
                        best = hit[3]
                for p in b["samples"]:
                    hit = a["tree"].find_nearest(p)
                    if hit[0] is not None and hit[3] < best:
                        best = hit[3]
            if best < a["min_dist"]:
                a["min_dist"], a["nearest"] = best, b["object"]
            if best < b["min_dist"]:
                b["min_dist"], b["nearest"] = best, a["object"]
    floating = [{"object": i["object"],
                 "center": tuple(round((i["bbox"][k] + i["bbox"][k + 3]) / 2.0, 2)
                                 for k in range(3)),
                 "min_dist": round(i["min_dist"], 3),
                 "nearest": i["nearest"], "tris": i["tris"]}
                for i in islands if i["min_dist"] > FLOATING]
    loose_islands = [{"object": i["object"],
                      "center": tuple(round((i["bbox"][k] + i["bbox"][k + 3]) / 2.0, 2)
                                      for k in range(3)),
                      "min_dist": round(i["min_dist"], 3),
                      "nearest": i["nearest"]}
                     for i in islands if LOOSE < i["min_dist"] <= FLOATING]
    check("connectivity_floating", not floating, json.dumps(floating[:6], ensure_ascii=False))

    # 6) 回归基线
    reg = {}
    for name, loc in BASELINE.items():
        ob = bpy.data.objects.get(name)
        reg[name] = None if ob is None else round(
            (Vector(tuple(ob.location)) - Vector(loc)).length, 4)
    check("regression", all(v is not None and v <= 0.05 for v in reg.values()),
          json.dumps(reg, ensure_ascii=False))

    result = {
        "asset": "SN_Paddle_Steamer",
        "objects": len(col.objects),
        "meshes": len(mesh_objs),
        "empties": len(empty_objs),
        "tris": tris,
        "bbox": size,
        "bbox_min": [round(v, 3) for v in mn],
        "bbox_max": [round(v, 3) for v in mx],
        "materials": sorted(mats),
        "paddle_clearance_hits": rot_hits,
        "floating": floating,
        "loose": loose_islands[:10],
        "island_count": len(islands),
        "health": [(c["check"], c["passed"]) for c in checks],
        "failures": failures,
        "passed": not failures,
    }
    print("PADDLE_STEAMER_VERIFY " + json.dumps(result, ensure_ascii=False))
    return result


if __name__ == "__main__":
    main()
