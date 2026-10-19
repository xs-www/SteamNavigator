# -*- coding: utf-8 -*-
"""Steam Navigator — 铁港第三批 6 件道具参数化生成脚本。

工单：tools/modeling/briefs/sn_iron_harbor_batch3.json
集合：SN_IronHarbor_Props（已有第一批 + 第二批 12 件，本脚本只追加/重建本批 6 件）
布局：y=36 一排，x = -12, -7, -2, 3, 8, 13
轴心：底面中心（object.location = 布局位置，几何全部为局部坐标，底面 z=0）
预算：合计 <= 1300 tri；单件见 ITEMS 表（验收上限 1.5×）
材质：只用既有调色板（本批不新增材质）

设计要点
--------
- 全部几何由本文件顶部的参数表生成，改数值即可重建；禁止手工摆点。
- 每个 item 是**一个 mesh 对象**（多材质槽），原点在底面中心。
- 环与环共享顶点（焊接）；每个壳体闭合，边界边/非流形边应为 0。
- 互相穿插的部件之间错开 1–5 mm，避免共面 z-fighting。
- 几何函数为纯 Python（不 import bpy），可用 dryrun_props.py 离线校验。
- 本文件自带几何工具函数（与第二批生成器重复但各自独立），保持单文件可执行。

用法
----
Blender 内：import runpy; runpy.run_path(<本文件>, run_name="__main__")
纯 Python 干跑：python tools/modeling/generators/dryrun_props.py tools/modeling/generators/sn_iron_harbor_batch3_generator.py
"""

import math

COLLECTION = "SN_IronHarbor_Props"

ITEMS = [
    ("SN_Timber_Stack", (-12.0, 36.0, 0.0), 250, (4.00, 1.50, 1.20)),
    ("SN_Sack_Pile", (-7.0, 36.0, 0.0), 300, (1.50, 1.00, 0.80)),
    ("SN_Steam_Pipe", (-2.0, 36.0, 0.0), 150, (2.00, 0.30, 0.40)),
    ("SN_Mooring_Rope", (3.0, 36.0, 0.0), 200, (0.90, 0.90, 0.50)),
    ("SN_Cargo_Net", (8.0, 36.0, 0.0), 250, (3.00, 3.00, 0.15)),
    ("SN_Pallet", (13.0, 36.0, 0.0), 100, (1.20, 1.00, 0.15)),
]

TOTAL_BUDGET = 1300

# 本批不新增材质
NEW_MATERIALS = {}


# --------------------------------------------------------------------------- #
# 纯几何工具（无 bpy 依赖）
# --------------------------------------------------------------------------- #

class Part:
    def __init__(self):
        self.verts = []
        self.faces = []

    def add(self, verts, faces, material):
        offset = len(self.verts)
        self.verts.extend(verts)
        for face in faces:
            self.faces.append((tuple(i + offset for i in face), material))


def ring(n, rx, ry, z, cx=0.0, cy=0.0, phase=None):
    if phase is None:
        phase = math.pi / n
    return [
        (cx + rx * math.cos(phase + 2.0 * math.pi * i / n),
         cy + ry * math.sin(phase + 2.0 * math.pi * i / n),
         z)
        for i in range(n)
    ]


def box(lo, hi):
    x0, y0, z0 = lo
    x1, y1, z1 = hi
    verts = [
        (x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
        (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1),
    ]
    faces = [
        (0, 3, 2, 1), (4, 5, 6, 7),
        (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7),
    ]
    return verts, faces


def tube_axis(profile, sides, z_center, axis="x"):
    """水平圆柱壳：profile = [(轴向位置, 半径)...]，两端封盖。"""
    phase = math.pi / 2.0 + math.pi / sides
    verts = []
    for pos, r in profile:
        for i in range(sides):
            a = phase + 2.0 * math.pi * i / sides
            c, s = r * math.cos(a), r * math.sin(a)
            if axis == "x":
                verts.append((pos, c, z_center + s))
            else:
                verts.append((c, pos, z_center - s))
    faces = []
    for k in range(len(profile) - 1):
        base, nxt = k * sides, (k + 1) * sides
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((base + i, base + j, nxt + j, nxt + i))
    for i in range(1, sides - 1):
        faces.append((0, i + 1, i))
        top = (len(profile) - 1) * sides
        faces.append((top, top + i, top + i + 1))
    return verts, faces


def annulus(r_out, r_in, z0, z1, sides=8, phase=None, centre=(0.0, 0.0)):
    """环形（绳卷 / 吊环）：外壁 + 内壁 + 上下环面。"""
    if phase is None:
        phase = math.pi / sides
    cx, cy = centre
    ob = ring(sides, r_out, r_out, z0, cx, cy, phase)
    ot = ring(sides, r_out, r_out, z1, cx, cy, phase)
    ib = ring(sides, r_in, r_in, z0, cx, cy, phase)
    it = ring(sides, r_in, r_in, z1, cx, cy, phase)
    verts = []
    faces = []
    o0 = len(verts); verts.extend(ob)
    o1 = len(verts); verts.extend(ot)
    i0 = len(verts); verts.extend(ib)
    i1 = len(verts); verts.extend(it)
    for i in range(sides):
        j = (i + 1) % sides
        faces.append((o0 + i, o0 + j, o1 + j, o1 + i))
        faces.append((i1 + i, i1 + j, i0 + j, i0 + i))
        faces.append((o1 + i, o1 + j, i1 + j, i1 + i))
        faces.append((o0 + i, i0 + i, i0 + j, o0 + j))
    return verts, faces


def tube_rings(rings):
    """若干等长环之间的管道壳 + 两端封盖（环共享顶点）。"""
    n = len(rings[0])
    verts = []
    for pts in rings:
        verts.extend(pts)
    faces = []
    for k in range(len(rings) - 1):
        base, nxt = k * n, (k + 1) * n
        for i in range(n):
            j = (i + 1) % n
            faces.append((base + i, base + j, nxt + j, nxt + i))
    for i in range(1, n - 1):
        faces.append((0, i + 1, i))
    top = (len(rings) - 1) * n
    for i in range(1, n - 1):
        faces.append((top, top + i, top + i + 1))
    return verts, faces


def sack(centre, length, rx, ry, rz, axis="x", sides=6, waist=0.72):
    """鼓形麻袋：两端收 0.72、中间鼓起的短管壳。"""
    cx, cy, cz = centre
    rings = []
    for t, s in ((-0.5, waist), (0.0, 1.0), (0.5, waist)):
        pts = []
        for i in range(sides):
            a = math.pi / sides + 2.0 * math.pi * i / sides
            u, v = math.cos(a) * s, math.sin(a) * s
            if axis == "x":
                pts.append((cx + length * t, cy + ry * u, cz + rz * v))
            else:
                pts.append((cx + rx * u, cy + length * t, cz + rz * v))
        rings.append(pts)
    return tube_rings(rings)


# --------------------------------------------------------------------------- #
# 1. SN_Timber_Stack —— 木料堆（4.0 × 1.5 × 1.2）
# --------------------------------------------------------------------------- #

def build_timber_stack():
    m = Part()
    WOOD, DARK, MET = "SN_Wood", "SN_Wood_Dark", "SN_Metal"

    x0, x1 = -2.000, 2.000
    layer_h = 0.300
    # 偶数层 3 根宽料（0.44 宽 / 0.09 缝），奇数层 4 根窄料（0.33 / 0.06），交错堆叠
    patterns = [
        (0.440, 0.090, 3),
        (0.330, 0.060, 4),
        (0.440, 0.090, 3),
        (0.330, 0.060, 4),
    ]
    z = 0.0
    for li, (w, gap, count) in enumerate(patterns):
        total = count * w + (count - 1) * gap
        y = -total / 2.0
        for _ in range(count):
            m.add(*box((x0, y, z), (x1, y + w, z + layer_h)), WOOD if li % 2 == 0 else DARK)
            y += w + gap
        z += layer_h

    # 两端金属绑带：顶压条 + 两侧下垂（与木料错开 15 mm，避免共面）
    for sx in (-1.0, 1.0):
        xa, xb = sorted((sx * 1.380, sx * 1.450))
        m.add(*box((xa, -0.735, 1.188), (xb, 0.735, 1.222)), MET)
        for sy in (-1.0, 1.0):
            ya, yb = sorted((sy * 0.735, sy * 0.755))
            m.add(*box((xa, ya, 0.000), (xb, yb, 1.210)), MET)
    return m


# --------------------------------------------------------------------------- #
# 2. SN_Sack_Pile —— 麻袋堆（1.5 × 1.0 × 0.8）
# --------------------------------------------------------------------------- #

def build_sack_pile():
    m = Part()
    CAN = "SN_Canvas"

    # 底层：2 条沿 Y 横放
    for sx in (-1.0, 1.0):
        m.add(*sack((sx * 0.500, 0.0, 0.135), 0.950, 0.260, 0.250, 0.135, "y"), CAN)
    # 中层：2 条沿 X 横放
    for sy in (-1.0, 1.0):
        m.add(*sack((0.0, sy * 0.220, 0.400), 0.800, 0.210, 0.220, 0.130, "x"), CAN)
    # 顶层：1 条沿 Y
    m.add(*sack((0.0, 0.0, 0.665), 0.850, 0.230, 0.220, 0.130, "y"), CAN)
    return m


# --------------------------------------------------------------------------- #
# 3. SN_Steam_Pipe —— 蒸汽管段（2.0 × 0.3 × 0.4）
# --------------------------------------------------------------------------- #

def build_steam_pipe():
    m = Part()
    MET = "SN_Metal"

    z_axis = 0.280
    r_pipe = 0.100
    # 主钢管
    m.add(*tube_axis([(-1.000, r_pipe), (1.000, r_pipe)], 8, z_axis, "x"), MET)
    # 两端法兰（略粗，端面比管口外探 20 mm）
    for sx in (-1.0, 1.0):
        xa, xb = sorted((sx * 0.960, sx * 1.020))
        m.add(*tube_axis([(xa, 0.145), (xb, 0.145)], 8, z_axis, "x"), MET)
    # 两道支墩
    for sx in (-1.0, 1.0):
        cx = sx * 0.560
        m.add(*box((cx - 0.070, -0.120, 0.000), (cx + 0.070, 0.120, 0.200)), MET)
    return m


# --------------------------------------------------------------------------- #
# 4. SN_Mooring_Rope —— 缆绳卷（0.9 × 0.9 × 0.5）
# --------------------------------------------------------------------------- #

def build_mooring_rope():
    m = Part()
    CAN = "SN_Canvas"

    # 下盘 + 上盘（盘绕两层）
    m.add(*annulus(0.450, 0.200, 0.000, 0.200, 10), CAN)
    m.add(*annulus(0.390, 0.180, 0.200, 0.380, 10), CAN)
    # 端头垂下一段（贴外缘）
    m.add(*box((0.380, -0.032, 0.000), (0.452, 0.032, 0.440)), CAN)
    return m


# --------------------------------------------------------------------------- #
# 5. SN_Cargo_Net —— 吊货网（3.0 × 3.0 × 0.15，平铺态）
# --------------------------------------------------------------------------- #

def build_cargo_net():
    m = Part()
    CAN, MET = "SN_Canvas", "SN_Metal"

    half = 1.500
    span = (-1.200, -0.600, 0.000, 0.600, 1.200)
    r_half = 0.025
    # 沿 X 的绳（下层，落地）
    for y in span:
        m.add(*box((-half, y - r_half, 0.000), (half, y + r_half, 0.053)), CAN)
    # 沿 Y 的绳（上层，与下层错开 2 mm 避免共面）
    for x in span:
        m.add(*box((x - r_half, -half, 0.051), (x + r_half, half, 0.104)), CAN)

    # 四角方形吊环（抬起 4 mm，避免与绳底共面）
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            m.add(*annulus(0.140, 0.070, 0.004, 0.074, 4,
                           phase=math.pi / 4.0, centre=(sx * 1.320, sy * 1.320)), MET)
    return m


# --------------------------------------------------------------------------- #
# 6. SN_Pallet —— 托盘（1.2 × 1.0 × 0.15）
# --------------------------------------------------------------------------- #

def build_pallet():
    m = Part()
    WOOD = "SN_Wood"

    x0, x1 = -0.600, 0.600
    # 底板 2 根（沿 X）
    for sy in (-1.0, 1.0):
        ya, yb = sorted((sy * 0.280, sy * 0.480))
        m.add(*box((x0, ya, 0.000), (x1, yb, 0.020)), WOOD)
    # 三根纵梁
    for cy in (-0.380, 0.000, 0.380):
        m.add(*box((x0, cy - 0.040, 0.020), (x1, cy + 0.040, 0.110)), WOOD)
    # 面板条 3 根
    for cy in (-0.380, 0.000, 0.380):
        m.add(*box((x0, cy - 0.120, 0.110), (x1, cy + 0.120, 0.135)), WOOD)
    return m


BUILDERS = {
    "SN_Timber_Stack": build_timber_stack,
    "SN_Sack_Pile": build_sack_pile,
    "SN_Steam_Pipe": build_steam_pipe,
    "SN_Mooring_Rope": build_mooring_rope,
    "SN_Cargo_Net": build_cargo_net,
    "SN_Pallet": build_pallet,
}


def build_all_geometry():
    return {name: BUILDERS[name]() for name, _pos, _budget, _size in ITEMS}


# --------------------------------------------------------------------------- #
# Blender 侧：建对象 / 自检
# --------------------------------------------------------------------------- #

def _ensure_material(name):
    import bpy
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    spec = NEW_MATERIALS.get(name)
    if spec is None:
        raise RuntimeError("材质 %s 不存在且未在 NEW_MATERIALS 声明" % name)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*spec["base"], 1.0)
    bsdf.inputs["Roughness"].default_value = spec["roughness"]
    bsdf.inputs["Metallic"].default_value = spec["metallic"]
    mat.diffuse_color = (*spec["base"], 1.0)
    return mat


def _make_object(name, part, location):
    import bpy
    import bmesh

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in part.verts], [], [list(f) for f, _ in part.faces])
    mesh.update()

    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()

    slots = []
    for _face, mat_name in part.faces:
        if mat_name not in slots:
            slots.append(mat_name)
    for mat_name in slots:
        mesh.materials.append(_ensure_material(mat_name))
    index = {m: i for i, m in enumerate(slots)}
    for poly, (_face, mat_name) in zip(mesh.polygons, part.faces):
        poly.material_index = index[mat_name]
        poly.use_smooth = False

    obj = bpy.data.objects.new(name, mesh)
    bpy.data.collections[COLLECTION].objects.link(obj)
    obj.location = location
    return obj


def build_all():
    import bpy

    if bpy.data.collections.get(COLLECTION) is None:
        raise RuntimeError("集合 %s 不存在" % COLLECTION)

    for name, _pos, _budget, _size in ITEMS:
        old = bpy.data.objects.get(name)
        if old is not None:
            old_mesh = old.data
            bpy.data.objects.remove(old, do_unlink=True)
            if old_mesh is not None and old_mesh.users == 0:
                bpy.data.meshes.remove(old_mesh)
    for name, _pos, _budget, _size in ITEMS:
        for stale in [m for m in bpy.data.meshes if m.users == 0 and m.name.startswith(name)]:
            bpy.data.meshes.remove(stale)

    geometry = build_all_geometry()
    return [_make_object(name, geometry[name], pos) for name, pos, _b, _s in ITEMS]


def report():
    import bpy
    import bmesh

    out = {"items": [], "total_tris": 0, "health": {}, "scene": {}}
    for name, pos, budget, size in ITEMS:
        obj = bpy.data.objects[name]
        mesh = obj.data
        mesh.calc_loop_triangles()
        tris = len(mesh.loop_triangles)

        bm = bmesh.new()
        bm.from_mesh(mesh)
        bm.edges.ensure_lookup_table()
        loose = sum(1 for v in bm.verts if not v.link_edges)
        degen = sum(1 for f in bm.faces if f.calc_area() < 1e-9)
        nonman = sum(1 for e in bm.edges if not e.is_manifold)
        boundary = sum(1 for e in bm.edges if e.is_boundary)
        bm.free()
        overflow = sum(1 for p in mesh.polygons if p.material_index >= len(mesh.materials))

        xs = [v.co.x for v in mesh.vertices]
        ys = [v.co.y for v in mesh.vertices]
        zs = [v.co.z for v in mesh.vertices]
        measured = [round(max(xs) - min(xs), 4), round(max(ys) - min(ys), 4), round(max(zs) - min(zs), 4)]

        out["items"].append({
            "name": name,
            "location": [round(v, 4) for v in obj.location],
            "tris": tris,
            "budget": budget,
            "verts": len(mesh.vertices),
            "size": measured,
            "target": list(size),
            "size_delta": [round(measured[i] - size[i], 4) for i in range(3)],
            "zmin": round(min(zs), 4),
            "materials": [m.name for m in mesh.materials],
            "loose_verts": loose,
            "degenerate_faces": degen,
            "non_manifold_edges": nonman,
            "boundary_edges": boundary,
            "mat_slot_overflow": overflow,
            "mesh_datablock": mesh.name,
        })
        out["total_tris"] += tris

    out["health"] = {
        "all_manifold": all(i["non_manifold_edges"] == 0 and i["boundary_edges"] == 0 for i in out["items"]),
        "no_loose": all(i["loose_verts"] == 0 for i in out["items"]),
        "no_degenerate": all(i["degenerate_faces"] == 0 for i in out["items"]),
        "no_mat_overflow": all(i["mat_slot_overflow"] == 0 for i in out["items"]),
        "all_within_1_5x_budget": all(i["tris"] <= int(i["budget"] * 1.5) for i in out["items"]),
        "total_within_budget": out["total_tris"] <= TOTAL_BUDGET,
        "all_sizes_ok": all(abs(d) <= 0.1 for i in out["items"] for d in i["size_delta"]),
    }
    out["scene"] = {
        "objects": len(bpy.data.objects),
        "mesh": sum(1 for o in bpy.data.objects if o.type == "MESH"),
        "materials": sorted(m.name for m in bpy.data.materials),
        "props_collection": sorted(o.name for o in bpy.data.collections[COLLECTION].objects),
        "mesh_datablocks": len(bpy.data.meshes),
    }
    print("BATCH3_REPORT " + repr(out))
    return out


if __name__ == "__main__":
    build_all()
    report()
