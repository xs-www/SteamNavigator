# -*- coding: utf-8 -*-
"""Steam Navigator — 系缆桩 SN_Mooring_Bollard 参数化生成脚本（实船参考版）。

参考
----
按用户提供的实船舱面系缆桩照片重做，四个特征必须成立：
  1. 底座是**方形法兰板**（切角八角近似方板），四角各一颗六角螺栓；
  2. 桩身是**粗圆柱**，根部有喇叭形放大脚（铸造过渡），向上略微收分；
  3. 十字桩头由两根**粗圆柱横臂**正交构成，横臂端部有倒角收口（不是方头）；
  4. 圆柱柱身在十字**之上**还留一小截，顶面为平顶倒角。

约定
----
- 单位米，+X 前向，+Z 向上；原点在底面中心（object.location = 布局位置）。
- 外形尺寸 0.62 × 0.62 × 0.70（高/臂展 = 1.13，按照片改的矮壮比例；
  旧版 0.5 × 0.5 × 0.85 高/宽 1.70，读起来像"细柱顶十字"）。
  工单 tools/modeling/briefs/sn_iron_harbor_batch1.json 已同步为新尺寸。
- 低模 flat shading，无贴图，材质仅 SN_Metal。
- 全部几何由下方 PLATE / BOLTS / SHAFT / ARM 参数表生成，改数值即可重建。
- 三角面预算：工单 200，验收上限 1.5×=300；本版 288（底座 44 + 螺栓 80 +
  柱身 44 + 横臂 120）。
- 环与环共享顶点（焊接），每个壳体闭合：边界边 / 非流形边应为 0。
- 两根横臂 z 相差 2 mm，避免平顶面共面 z-fighting。

用法
----
在 Blender 中执行：build() 生成对象，report() 只读自检。
也可作为独立脚本运行：blender -b <file>.blend -P sn_mooring_bollard_generator.py
"""

import bpy
import bmesh
import math

OBJECT_NAME = "SN_Mooring_Bollard"
COLLECTION = "SN_IronHarbor_Props"
MATERIAL = "SN_Metal"
LOCATION = (-2.0, 24.0, 0.0)

# 方形法兰板：切角八角，half=边长一半，corner=切角长度
PLATE = {
    "half": 0.298,
    "corner": 0.068,
    "z0": 0.000,
    "z1": 0.075,
    "z2": 0.105,       # 顶面（带 7% 收分倒角）
    "top_scale": 0.93,
}

# 四角螺栓：位置 (±pos, ±pos)，六角头，穿过顶面露出 z1
BOLTS = {"pos": 0.192, "r": 0.040, "z0": 0.078, "z1": 0.132, "sides": 6}

# 桩身回转轮廓 (z, r)：根部喇叭脚（明显外张）-> 粗柱身 -> 顶部
SHAFT = {
    "sides": 8,
    "profile": [(0.095, 0.235), (0.200, 0.165), (0.700, 0.132)],
}

# 十字横臂：粗圆柱 + 端部倒角收口
ARM = {
    "sides": 8,
    "r_body": 0.093,
    "r_tip": 0.078,
    "chamfer": 0.026,
    "half": 0.310,
    "z_a": 0.585,      # 沿 X 的横臂
    "z_b": 0.587,      # 沿 Y 的横臂（错开 2 mm，避免平顶面共面）
}


# --------------------------------------------------------------------------- #
# 几何工具
# --------------------------------------------------------------------------- #

def _append(acc_v, acc_f, v, f):
    offset = len(acc_v)
    acc_v.extend(v)
    acc_f.extend([tuple(i + offset for i in face) for face in f])


def _plate_ring(scale, z):
    """方板（切角八角），逆时针（从 +Z 看）。"""
    a = PLATE["half"] * scale
    c = PLATE["corner"] * scale
    return [
        (a, a - c, z), (a - c, a, z), (-(a - c), a, z), (-a, a - c, z),
        (-a, -(a - c), z), (-(a - c), -a, z), (a - c, -a, z), (a, -(a - c), z),
    ]


def _plate_shell():
    rings = [
        _plate_ring(1.0, PLATE["z0"]),
        _plate_ring(1.0, PLATE["z1"]),
        _plate_ring(PLATE["top_scale"], PLATE["z2"]),
    ]
    verts = []
    for ring in rings:
        verts.extend(ring)
    faces = []
    n = len(rings[0])
    for k in range(len(rings) - 1):
        base, nxt = k * n, (k + 1) * n
        for i in range(n):
            j = (i + 1) % n
            faces.append((base + i, base + j, nxt + j, nxt + i))
    for i in range(1, n - 1):
        faces.append((0, i + 1, i))                                     # 底 -Z
        faces.append(((len(rings) - 1) * n,
                      (len(rings) - 1) * n + i,
                      (len(rings) - 1) * n + i + 1))                    # 顶 +Z
    return verts, faces


def _vertical_shell(profile, sides, phase=None):
    """回转壳：profile 为 [(z, r)...]，环共享顶点，上下封盖。"""
    if phase is None:
        phase = math.pi / sides
    verts = []
    for z, r in profile:
        for i in range(sides):
            a = phase + 2.0 * math.pi * i / sides
            verts.append((r * math.cos(a), r * math.sin(a), z))
    faces = []
    for k in range(len(profile) - 1):
        base, nxt = k * sides, (k + 1) * sides
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((base + i, base + j, nxt + j, nxt + i))
    for i in range(1, sides - 1):
        faces.append((0, i + 1, i))                                    # 底 -Z
        top = (len(profile) - 1) * sides
        faces.append((top, top + i, top + i + 1))                      # 顶 +Z
    return verts, faces


def _axis_shell(profile, sides, z_center, axis):
    """水平圆柱壳：profile 为 [(轴向位置, r)...]，两端封盖。

    轴为 x 时截面在 YZ 平面，轴为 y 时截面在 XZ 平面；参数化保证侧面法线朝外
    （build() 里还会统一 recalc 一次）。
    """
    phase = math.pi / 2.0 + math.pi / sides   # 让正上方是一个平面
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


def build_geometry():
    """返回 (verts, faces)，全部为局部坐标，底面 z=0。"""
    verts = []
    faces = []

    _append(verts, faces, *_plate_shell())

    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            bolt = _vertical_shell(
                [(BOLTS["z0"], BOLTS["r"]), (BOLTS["z1"], BOLTS["r"])],
                BOLTS["sides"],
            )
            shifted = [(x + sx * BOLTS["pos"], y + sy * BOLTS["pos"], z) for x, y, z in bolt[0]]
            _append(verts, faces, shifted, bolt[1])

    _append(verts, faces, *_vertical_shell(SHAFT["profile"], SHAFT["sides"]))

    arm = ARM
    arm_profile = [
        (-arm["half"], arm["r_tip"]),
        (-arm["half"] + arm["chamfer"], arm["r_body"]),
        (arm["half"] - arm["chamfer"], arm["r_body"]),
        (arm["half"], arm["r_tip"]),
    ]
    _append(verts, faces, *_axis_shell(arm_profile, arm["sides"], arm["z_a"], "x"))
    _append(verts, faces, *_axis_shell(arm_profile, arm["sides"], arm["z_b"], "y"))
    return verts, faces


def _recalc_normals(mesh):
    """按连通壳体统一朝外，避免参数化绕序错误导致反面剔除穿帮。"""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()


def build():
    coll = bpy.data.collections[COLLECTION]
    old = bpy.data.objects.get(OBJECT_NAME)
    if old is not None:
        old_mesh = old.data
        bpy.data.objects.remove(old, do_unlink=True)
        if old_mesh is not None and old_mesh.users == 0:
            bpy.data.meshes.remove(old_mesh)

    # 扫掉同名残留网格：历史轮次留下的 users=0 孤儿会占住基名、并被写进 .blend。
    # 只清同名且无用户的，不用 orphans_purge，避免误清工作台里有意的 0-user 数据。
    for stale in [m for m in bpy.data.meshes if m.users == 0 and m.name.startswith(OBJECT_NAME)]:
        bpy.data.meshes.remove(stale)

    verts, faces = build_geometry()
    mesh = bpy.data.meshes.new(OBJECT_NAME)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    _recalc_normals(mesh)
    for poly in mesh.polygons:
        poly.use_smooth = False

    mat = bpy.data.materials.get(MATERIAL)
    if mat is None:
        raise RuntimeError("缺少材质 %s" % MATERIAL)
    mesh.materials.append(mat)

    obj = bpy.data.objects.new(OBJECT_NAME, mesh)
    coll.objects.link(obj)
    obj.location = LOCATION
    return obj


def report():
    obj = bpy.data.objects[OBJECT_NAME]
    mesh = obj.data
    mesh.calc_loop_triangles()
    xs = [v.co.x for v in mesh.vertices]
    ys = [v.co.y for v in mesh.vertices]
    zs = [v.co.z for v in mesh.vertices]

    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.edges.ensure_lookup_table()
    loose = sum(1 for v in bm.verts if not v.link_edges)
    degenerate = sum(1 for f in bm.faces if f.calc_area() < 1e-9)
    non_manifold = sum(1 for e in bm.edges if not e.is_manifold)
    boundary = sum(1 for e in bm.edges if e.is_boundary)
    bm.free()

    mesh_names = sorted(m.name for m in bpy.data.meshes if m.name.startswith(OBJECT_NAME))
    info = {
        "name": obj.name,
        "collection": [c.name for c in obj.users_collection],
        "location": [round(v, 4) for v in obj.location],
        "verts": len(mesh.vertices),
        "polys": len(mesh.polygons),
        "tris": len(mesh.loop_triangles),
        "size": [round(max(xs) - min(xs), 4), round(max(ys) - min(ys), 4), round(max(zs) - min(zs), 4)],
        "zmin": round(min(zs), 4),
        "base_centre_xy": [round((max(xs) + min(xs)) / 2, 4), round((max(ys) + min(ys)) / 2, 4)],
        "materials": [m.name for m in mesh.materials],
        "loose_verts": loose,
        "degenerate_faces": degenerate,
        "non_manifold_edges": non_manifold,
        "boundary_edges": boundary,
        "mesh_datablocks": mesh_names,
        "single_mesh_datablock": len(mesh_names) == 1,
        "mesh_datablock_name": mesh.name,
    }
    print("BOLLARD_REPORT " + repr(info))
    return info


if __name__ == "__main__":
    build()
    report()
