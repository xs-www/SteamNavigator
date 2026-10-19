# -*- coding: utf-8 -*-
"""Steam Navigator — 铁港第四批 6 件道具参数化生成脚本。

工单：tools/modeling/briefs/sn_iron_harbor_batch4.json
集合：SN_IronHarbor_Props（已有 18 件，本脚本只追加/重建本批 6 件）
布局：y=42 一排，x = -12, -7, -2, 3, 8, 13
轴心：底面中心（object.location = 布局位置，几何全部为局部坐标，底面 z=0）
预算：合计 <= 1600 tri；单件见 ITEMS 表（验收上限 1.5×）
材质：只用既有调色板（本批不新增）

设计要点
--------
- 全部几何由本文件顶部的参数表生成，改数值即可重建；禁止手工摆点。
- 每个 item 是**一个 mesh 对象**（多材质槽），原点在底面中心。
- 环与环共享顶点（焊接）；每个壳体闭合，边界边/非流形边应为 0。
- 互相穿插的部件之间错开 3–8 mm，避免共面 z-fighting。
- 几何函数为纯 Python（不 import bpy），可用 dryrun_props.py 离线校验。
- 本文件自带几何工具函数（与前几批重复但各自独立），保持单文件可执行。

用法
----
Blender 内：import runpy; runpy.run_path(<本文件>, run_name="__main__")
纯 Python 干跑：python tools/modeling/generators/dryrun_props.py tools/modeling/generators/sn_iron_harbor_batch4_generator.py
"""

import math

COLLECTION = "SN_IronHarbor_Props"

ITEMS = [
    ("SN_Buoy", (-12.0, 42.0, 0.0), 250, (1.20, 1.20, 1.80)),
    ("SN_Chain_Coil", (-7.0, 42.0, 0.0), 250, (1.00, 1.00, 0.30)),
    ("SN_Capstan", (-2.0, 42.0, 0.0), 350, (1.20, 1.20, 1.10)),
    ("SN_Handcart", (3.0, 42.0, 0.0), 300, (2.00, 1.00, 1.00)),
    ("SN_Fender_Ball", (8.0, 42.0, 0.0), 120, (0.80, 0.80, 0.90)),
    ("SN_Gear_Crate", (13.0, 42.0, 0.0), 250, (0.80, 0.80, 0.80)),
]

TOTAL_BUDGET = 1600

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


def translate(vf, dx, dy, dz):
    verts, faces = vf
    return [(x + dx, y + dy, z + dz) for x, y, z in verts], faces


def revolved(profile, sides, phase=None):
    """回转壳：profile = [(z, r)...]，上下封盖，环共享顶点。"""
    if phase is None:
        phase = math.pi / sides
    verts = []
    for z, r in profile:
        verts.extend(ring(sides, r, r, z, phase=phase))
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


def ball_shell(profile, sides):
    """球壳：profile 首尾 r=0 作两极，中间为环。"""
    if profile[0][1] > 1e-9 or profile[-1][1] > 1e-9:
        raise ValueError("ball_shell 的首尾必须是 r=0 的极点")
    rings = [ring(sides, r, r, z) for z, r in profile[1:-1]]
    verts = []
    z0 = profile[0][0]
    verts.append((0.0, 0.0, z0))
    bottom = 0
    offsets = []
    for pts in rings:
        offsets.append(len(verts))
        verts.extend(pts)
    top = len(verts)
    verts.append((0.0, 0.0, profile[-1][0]))
    faces = []
    n = sides
    first = offsets[0]
    for i in range(n):
        faces.append((bottom, first + i, first + (i + 1) % n))
    for k in range(len(offsets) - 1):
        a, b = offsets[k], offsets[k + 1]
        for i in range(n):
            j = (i + 1) % n
            faces.append((a + i, a + j, b + j, b + i))
    last = offsets[-1]
    for i in range(n):
        faces.append((last + i, last + (i + 1) % n, top))
    return verts, faces


def tube_axis(profile, sides, z_center, axis="x"):
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
        good = (len(profile) - 1) * sides
        faces.append((good, good + i, good + i + 1))
    return verts, faces


def disc_axis(cx, pos0, pos1, radius, z_center, axis="y", sides=8):
    """水平轴上的圆盘（齿轮 / 轮子），可指定另一个水平坐标。"""
    vf = tube_axis([(pos0, radius), (pos1, radius)], sides, z_center, axis)
    return translate(vf, cx, 0.0, 0.0) if axis == "y" else translate(vf, 0.0, cx, 0.0)


def annulus(r_out, r_in, z0, z1, sides=8, phase=None, centre=(0.0, 0.0)):
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


# --------------------------------------------------------------------------- #
# 1. SN_Buoy —— 浮标（1.2 × 1.2 × 1.8）
# --------------------------------------------------------------------------- #

def build_buoy():
    m = Part()
    MET, DARK = "SN_Metal", "SN_Wood_Dark"

    # 底部配重环（宽底）
    m.add(*revolved([(0.000, 0.600), (0.100, 0.600), (0.180, 0.520)], 10), DARK)
    # 圆柱浮体（中段略鼓）
    m.add(*revolved([(0.160, 0.520), (0.300, 0.560), (0.900, 0.560), (1.050, 0.480)], 10), MET)
    # 顶部灯架：4 根立柱
    post = 0.032
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            cx, cy = sx * 0.190, sy * 0.190
            m.add(*box((cx - post, cy - post, 1.040), (cx + post, cy + post, 1.500)), MET)
    # 灯架顶框（四根横梁）
    for sy in (-1.0, 1.0):
        ya, yb = sorted((sy * 0.222, sy * 0.190))
        m.add(*box((-0.222, ya, 1.500), (0.222, yb, 1.536)), MET)
    for sx in (-1.0, 1.0):
        xa, xb = sorted((sx * 0.222, sx * 0.190))
        m.add(*box((xa, -0.190, 1.500), (xb, 0.190, 1.536)), MET)
    # 灯具（六边形灯头）
    m.add(*revolved([(1.520, 0.075), (1.740, 0.075), (1.800, 0.030)], 6, phase=0.0), DARK)
    return m


# --------------------------------------------------------------------------- #
# 2. SN_Chain_Coil —— 锚链堆（1.0 × 1.0 × 0.3）
# --------------------------------------------------------------------------- #

def build_chain_coil():
    m = Part()
    MET = "SN_Metal"

    # 链环：带孔的方形环（4 边环），俯视能看出环孔，比实心方块更像"锚链"
    # 3 层收径盘绕；环厚 0.09，层间重叠 2 mm 避免共面
    link_thick = 0.090
    layers = [
        (0.000, 0.380, 6),
        (0.088, 0.300, 3),
        (0.176, 0.200, 2),
    ]
    for z0, radius, count in layers:
        for i in range(count):
            a = 2.0 * math.pi * i / count
            cx = radius * math.cos(a)
            cy = radius * math.sin(a)
            m.add(*annulus(0.200, 0.125, z0, z0 + link_thick, 4,
                           phase=math.pi / 4.0, centre=(cx, cy)), MET)
    return m


# --------------------------------------------------------------------------- #
# 3. SN_Capstan —— 手动绞盘（1.2 × 1.2 × 1.1）
# --------------------------------------------------------------------------- #

def build_capstan():
    m = Part()
    MET, WOOD = "SN_Metal", "SN_Wood"

    # 底座
    m.add(*revolved([(0.000, 0.560), (0.160, 0.520)], 8), MET)
    # 齿轮箱（八角鼓）
    m.add(*revolved([(0.150, 0.400), (0.480, 0.380)], 8), MET)
    # 木卷筒
    m.add(*revolved([(0.460, 0.260), (0.980, 0.250)], 8), WOOD)
    # 卷筒上箍
    m.add(*revolved([(0.620, 0.268), (0.660, 0.268)], 8), MET)
    # 顶部轮毂
    m.add(*revolved([(0.960, 0.180), (1.100, 0.140)], 8), MET)
    # 四根推杆（径向，沿 ±X / ±Y）
    bar_h, bar_w = 0.050, 0.046
    for sx in (-1.0, 1.0):
        xa, xb = sorted((sx * 0.090, sx * 0.600))
        m.add(*box((xa, -bar_w, 0.990), (xb, bar_w, 0.990 + bar_h)), MET)
    for sy in (-1.0, 1.0):
        ya, yb = sorted((sy * 0.090, sy * 0.600))
        m.add(*box((-bar_w, ya, 0.990), (bar_w, yb, 0.990 + bar_h)), MET)
    # 齿轮箱侧面露出两个齿轮
    m.add(*disc_axis(-0.130, 0.330, 0.400, 0.170, 0.330, "y", 8), MET)
    m.add(*disc_axis(0.150, 0.330, 0.395, 0.115, 0.270, "y", 8), MET)
    # 底座四角螺栓
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            cx, cy = sx * 0.400, sy * 0.400
            m.add(*box((cx - 0.045, cy - 0.045, 0.140), (cx + 0.045, cy + 0.045, 0.200)), MET)
    return m


# --------------------------------------------------------------------------- #
# 4. SN_Handcart —— 平板手推车（2.0 × 1.0 × 1.0）
# --------------------------------------------------------------------------- #

def build_handcart():
    m = Part()
    WOOD, MET = "SN_Wood", "SN_Metal"

    # 车板 5 条板条
    n, gap = 5, 0.018
    half_y = 0.360
    pw = (2.0 * half_y - gap * (n - 1)) / n
    y = -half_y
    for _ in range(n):
        m.add(*box((-1.000, y, 0.360), (1.000, y + pw, 0.412)), WOOD)
        y += pw + gap
    # 两侧边梁
    for sy in (-1.0, 1.0):
        ya, yb = sorted((sy * 0.380, sy * 0.440))
        m.add(*box((-1.000, ya, 0.310), (1.000, yb, 0.365)), MET)
    # 后轮（沿 Y 的圆柱）+ 车轴
    for sy in (-1.0, 1.0):
        ya, yb = sorted((sy * 0.420, sy * 0.510))
        m.add(*tube_axis([(ya, 0.260), (yb, 0.260)], 8, 0.270, "y"), MET)
    m.add(*tube_axis([(-0.530, 0.035), (0.530, 0.035)], 8, 0.270, "y"), MET)
    # 前支腿
    for sy in (-1.0, 1.0):
        ya, yb = sorted((sy * 0.300, sy * 0.360))
        m.add(*box((-1.020, ya, 0.000), (-0.900, yb, 0.320)), MET)
    # 两个把手立柱 + 顶部横杆
    for sy in (-1.0, 1.0):
        ya, yb = sorted((sy * 0.300, sy * 0.380))
        m.add(*box((0.880, ya, 0.400), (0.980, yb, 1.000)), MET)
    m.add(*box((0.880, -0.380, 0.940), (0.980, 0.380, 1.000)), MET)
    return m


# --------------------------------------------------------------------------- #
# 5. SN_Fender_Ball —— 圆形碰垫（0.8 × 0.8 × 0.9）
# --------------------------------------------------------------------------- #

def build_fender_ball():
    m = Part()
    CAN, MET = "SN_Canvas", "SN_Metal"

    profile = [(0.000, 0.0), (0.120, 0.270), (0.320, 0.400),
               (0.520, 0.400), (0.720, 0.270), (0.840, 0.0)]
    m.add(*ball_shell(profile, 6), CAN)
    # 表面编织纹：两道腰箍
    m.add(*revolved([(0.300, 0.412), (0.340, 0.412)], 6, phase=0.0), CAN)
    m.add(*revolved([(0.500, 0.412), (0.540, 0.412)], 6, phase=0.0), CAN)
    # 顶部吊环（方形环）
    m.add(*annulus(0.105, 0.055, 0.835, 0.900, 4, phase=math.pi / 4.0), MET)
    return m


# --------------------------------------------------------------------------- #
# 6. SN_Gear_Crate —— 精密齿轮箱（0.8 × 0.8 × 0.8）
# --------------------------------------------------------------------------- #

def build_gear_crate():
    m = Part()
    WOOD, MET = "SN_Wood", "SN_Metal"

    # 箱体 + 盖（盖比箱体窄 4 mm，留出"顶盖缝隙"）
    m.add(*box((-0.400, -0.400, 0.000), (0.400, 0.400, 0.720)), WOOD)
    m.add(*box((-0.396, -0.396, 0.728), (0.396, 0.396, 0.800)), WOOD)
    # 四角铁包角
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            cx, cy = sx * 0.365, sy * 0.365
            m.add(*box((cx - 0.045, cy - 0.045, 0.000), (cx + 0.045, cy + 0.045, 0.810)), MET)
    # 盖顶两道绑带
    for sy in (-1.0, 1.0):
        ya, yb = sorted((sy * 0.300, sy * 0.360))
        m.add(*box((-0.402, ya, 0.800), (0.402, yb, 0.818)), MET)
    # 箱侧露出的齿轮（大齿轮 + 小齿轮）：内端 y=0.395，比箱面内缩 5 mm 避免共面
    m.add(*disc_axis(0.020, 0.395, 0.448, 0.185, 0.400, "y", 8), MET)
    m.add(*disc_axis(-0.240, 0.395, 0.436, 0.115, 0.250, "y", 8), MET)
    # 大齿轮的四颗齿
    for k in range(4):
        a = math.pi / 4.0 + k * math.pi / 2.0
        cx = 0.020 + 0.215 * math.cos(a)
        cz = 0.400 + 0.215 * math.sin(a)
        m.add(*box((cx - 0.045, 0.395, cz - 0.045), (cx + 0.045, 0.446, cz + 0.045)), MET)
    return m


BUILDERS = {
    "SN_Buoy": build_buoy,
    "SN_Chain_Coil": build_chain_coil,
    "SN_Capstan": build_capstan,
    "SN_Handcart": build_handcart,
    "SN_Fender_Ball": build_fender_ball,
    "SN_Gear_Crate": build_gear_crate,
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
    print("BATCH4_REPORT " + repr(out))
    return out


if __name__ == "__main__":
    build_all()
    report()
