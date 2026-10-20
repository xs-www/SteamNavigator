# -*- coding: utf-8 -*-
"""Steam Navigator — 第一批 P0 整改脚本（2026-10-19）。

依据 docs/archive/MODELING_ACCEPTANCE_2026-10-19.md 第 5 节 P0：

  1. 修正系缆桩的桩头（改为十字形）和底座法兰
     -> 由 sn_mooring_bollard_generator.py 重建 SN_Mooring_Bollard
  2. 调整 SN_Ore 为锈红铁矿色
     -> 仅改材质参数，不动 SN_Ore_Pile 几何
  3. 将第一批 6 件 GLB 导入 Godot（本脚本不涉及，由 Lead 另行验证）
  4. 用三段岸壁完成连续拼接测试
     -> 在本脚本里临时复制 3 段 SN_Dock_Wall 到 y=18 拼接，供人工/截图验收
        命名为 SN_TMP_Splice_1..3，验收后必须删除（不是交付物）

本脚本只做上述三件事，且只触碰 SN_Mooring_Bollard / SN_Ore 材质 /
SN_TMP_Splice_* 三类；其余对象一律只读。禁止保存 .blend、禁止导出 .glb。

用法：在 Blender 里 exec 本文件后调用 report()；或直接运行本文件（会执行全部动作）。
"""

import bpy
import bmesh
import hashlib
import json
import os

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
GEN_DIR = os.path.join(WORKDIR, "tools", "modeling", "generators")
BOLLARD_GEN = os.path.join(GEN_DIR, "sn_mooring_bollard_generator.py")
# 基线快照是本地产物，留在 gitignore 的 .design/ 下
BASELINE = os.path.join(WORKDIR, ".design", "sn_iron_harbor_batch2_baseline.json")

COLLECTION = "SN_IronHarbor_Props"
SPLICE_SOURCE = "SN_Dock_Wall"
SPLICE_Y = 18.0
SPLICE_XS = (-12.0, -6.0, 0.0)
SPLICE_PREFIX = "SN_TMP_Splice_"

# 锈红铁矿：偏暗、低饱和，base 为 Linear，roughness/metallic 保持不变
ORE_BASE = (0.155, 0.038, 0.024)
ORE_ROUGHNESS = 0.95
ORE_METALLIC = 0.0


def rebuild_bollard():
    """执行系缆桩生成器（重建几何，材质不变）。"""
    ns = {"__name__": "__main__", "__file__": BOLLARD_GEN}
    with open(BOLLARD_GEN, encoding="utf-8") as fh:
        code = compile(fh.read(), BOLLARD_GEN, "exec")
    exec(code, ns)
    return ns


def recolor_ore():
    """把 SN_Ore 改成锈红铁矿色，只改参数不改结构。"""
    mat = bpy.data.materials["SN_Ore"]
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    before = {
        "base": [round(v, 6) for v in bsdf.inputs["Base Color"].default_value],
        "roughness": round(bsdf.inputs["Roughness"].default_value, 6),
        "metallic": round(bsdf.inputs["Metallic"].default_value, 6),
    }
    bsdf.inputs["Base Color"].default_value = (*ORE_BASE, 1.0)
    bsdf.inputs["Roughness"].default_value = ORE_ROUGHNESS
    bsdf.inputs["Metallic"].default_value = ORE_METALLIC
    mat.diffuse_color = (*ORE_BASE, 1.0)
    mat.roughness = ORE_ROUGHNESS
    mat.metallic = ORE_METALLIC
    return before


def build_splice_test():
    """在 y=18 临时复制三段岸壁，验证沿 X 连续拼接。"""
    coll = bpy.data.collections[COLLECTION]
    clear_splice_test()
    src = bpy.data.objects[SPLICE_SOURCE]
    made = []
    for i, x in enumerate(SPLICE_XS, start=1):
        dup = src.copy()               # 共享网格数据，不复制几何
        dup.name = "%s%d" % (SPLICE_PREFIX, i)
        dup.data = src.data            # 显式复用同一 mesh
        dup.location = (x, SPLICE_Y, src.location.z)
        coll.objects.link(dup)
        made.append(dup)
    return made


def clear_splice_test():
    removed = []
    for obj in list(bpy.data.objects):
        if obj.name.startswith(SPLICE_PREFIX):
            removed.append(obj.name)
            bpy.data.objects.remove(obj, do_unlink=True)
    return removed


def _object_rows():
    rows = []
    for o in sorted(bpy.data.objects, key=lambda x: x.name):
        if o.type == "MESH":
            h = hashlib.sha1()
            for v in o.data.vertices:
                h.update(("%.6f,%.6f,%.6f;" % tuple(v.co)).encode())
            rows.append({
                "name": o.name, "type": o.type,
                "loc": [round(v, 6) for v in o.location],
                "verts": len(o.data.vertices), "polys": len(o.data.polygons),
                "vhash": h.hexdigest()[:12],
                "mats": sorted(m.name for m in o.data.materials),
            })
        else:
            rows.append({"name": o.name, "type": o.type,
                         "loc": [round(v, 6) for v in o.location]})
    return rows


def _material_rows():
    out = []
    for m in sorted(bpy.data.materials, key=lambda x: x.name):
        b = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        out.append({
            "name": m.name,
            "base": [round(v, 6) for v in b.inputs["Base Color"].default_value],
            "metallic": round(b.inputs["Metallic"].default_value, 6),
            "roughness": round(b.inputs["Roughness"].default_value, 6),
        })
    return out


def report():
    """只读自检：几何 / 材质 / 回归比对。"""
    rows = _object_rows()
    mats = _material_rows()
    targets = [n for n in bpy.data.collections[COLLECTION].objects.keys()]
    boll = bpy.data.objects["SN_Mooring_Bollard"]
    boll.data.calc_loop_triangles()
    xs = [v.co.x for v in boll.data.vertices]
    ys = [v.co.y for v in boll.data.vertices]
    zs = [v.co.z for v in boll.data.vertices]

    bm = bmesh.new()
    bm.from_mesh(boll.data)
    health = {
        "loose_verts": sum(1 for v in bm.verts if not v.link_edges),
        "degenerate_faces": sum(1 for f in bm.faces if f.calc_area() < 1e-9),
        "non_manifold_edges": sum(1 for e in bm.edges if not e.is_manifold),
        "boundary_edges": sum(1 for e in bm.edges if e.is_boundary),
    }
    bm.free()

    out = {
        "bollard": {
            "location": [round(v, 4) for v in boll.location],
            "tris": len(boll.data.loop_triangles),
            "verts": len(boll.data.vertices),
            "size": [round(max(xs) - min(xs), 4), round(max(ys) - min(ys), 4), round(max(zs) - min(zs), 4)],
            "zmin": round(min(zs), 4),
            "head_diameter": round(max(xs) - min(xs), 4),
            "materials": [m.name for m in boll.data.materials],
            "mesh_datablock": boll.data.name,
            "health": health,
        },
        "bollard_mesh_datablocks": sorted(
            [{"name": m.name, "users": m.users, "polys": len(m.polygons)}
             for m in bpy.data.meshes if m.name.startswith("SN_Mooring_Bollard")],
            key=lambda d: d["name"],
        ),
        "ore": next(m for m in mats if m["name"] == "SN_Ore"),
        "splice": sorted(o.name for o in bpy.data.objects if o.name.startswith(SPLICE_PREFIX)),
        "props_collection": targets,
        "object_count": len(rows),
        "scene_hash": hashlib.sha1(json.dumps(rows, sort_keys=True).encode()).hexdigest(),
        "mat_hash": hashlib.sha1(json.dumps(mats, sort_keys=True).encode()).hexdigest(),
        "regression": {},
    }

    if os.path.exists(BASELINE):
        with open(BASELINE, encoding="utf-8") as fh:
            base = json.load(fh)
        # 本次整改合法改动的对象 / 临时对象，比对时排除
        ignore = {"SN_Mooring_Bollard"} | {
            n for n in bpy.data.objects.keys() if n.startswith(SPLICE_PREFIX)
        }
        base_rows = [r for r in base["objects"] if r["name"] not in ignore]
        now_rows = [r for r in rows if r["name"] not in ignore]
        base_mats = [m for m in base["materials"] if m["name"] != "SN_Ore"]
        now_mats = [m for m in mats if m["name"] != "SN_Ore"]
        out["regression"] = {
            "others_objects_unchanged": base_rows == now_rows,
            "others_materials_unchanged": base_mats == now_mats,
            # 比对口径：两侧都排除 SN_Mooring_Bollard 与 SN_TMP_Splice_*，
            # 所以下面两个计数应相等；场景总数差 = 1（重建的桩）+ splice 数量
            "compared_objects_baseline": len(base_rows),
            "compared_objects_current": len(now_rows),
            "baseline_objects_total": base["objects_total"],
            "scene_objects_total": len(rows),
            "scene_objects_excluding_temp": len([r for r in rows if not r["name"].startswith(SPLICE_PREFIX)]),
            "ignored_in_comparison": sorted(ignore),
            "added_in_comparison": sorted({r["name"] for r in now_rows} - {r["name"] for r in base_rows}),
            "removed_in_comparison": sorted({r["name"] for r in base_rows} - {r["name"] for r in now_rows}),
        }

    print("P0_REPORT " + json.dumps(out, ensure_ascii=False))
    return out


if __name__ == "__main__":
    rebuild_bollard()
    recolor_ore()
    build_splice_test()
    report()
