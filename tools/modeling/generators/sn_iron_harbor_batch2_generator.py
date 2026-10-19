# -*- coding: utf-8 -*-
"""Steam Navigator — 铁港第二批 6 件道具参数化生成脚本。

工单：tools/modeling/briefs/sn_iron_harbor_batch2.json
集合：SN_IronHarbor_Props（已存在第一批 6 件，本脚本只追加/重建本批 6 件）
布局：y=30 一排，x = -12, -7, -2, 3, 8, 13
轴心：底面中心（object.location = 布局位置，几何全部为局部坐标，底面 z=0）
预算：合计 <= 1900 tri；单件见 ITEMS 表（验收上限 1.5×）
材质：只用调色板 + 本批新增 SN_Coal（base 0.020/0.019/0.018，rough 0.95，metallic 0）

设计要点
--------
- 全部几何由本文件顶部的参数表生成，改数值即可重建；禁止手工摆点。
- 每个 item 是**一个 mesh 对象**（多材质槽），原点在底面中心。
- 环与环共享顶点（焊接）；每个壳体闭合，边界边/非流形边应为 0。
- 互相穿插的部件之间错开 1–5 mm，避免共面 z-fighting（第一批木箱铁箍的老坑）。
- 几何函数为纯 Python（不 import bpy），可用 dryrun 在没有 Blender 的环境跑。

用法
----
Blender 内：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")   # build_all() + report()
纯 Python 干跑（不建对象，只校验几何/预算/包围盒）：
    python tools/modeling/generators/dryrun_batch2.py
"""

import math

COLLECTION = "SN_IronHarbor_Props"

# (对象名, 布局位置, 单件 tri 预算, 目标世界尺寸 x/y/z)
ITEMS = [
    ("SN_Gas_Lamp", (-12.0, 30.0, 0.0), 250, (0.35, 0.35, 3.50)),
    ("SN_Gangway", (-7.0, 30.0, 0.0), 300, (6.00, 1.20, 0.50)),
    ("SN_Grab_Bucket", (-2.0, 30.0, 0.0), 400, (1.50, 1.50, 1.50)),
    ("SN_Coal_Pile", (3.0, 30.0, 0.0), 500, (3.00, 2.50, 1.20)),
    ("SN_Dock_Ladder", (8.0, 30.0, 0.0), 160, (0.60, 0.25, 3.20)),
    ("SN_Plate_Stack", (13.0, 30.0, 0.0), 250, (3.00, 2.00, 0.60)),
]

TOTAL_BUDGET = 1900

# 已有材质不得改参数；本批只允许新增 SN_Coal
NEW_MATERIALS = {
    "SN_Coal": {"base": (0.020, 0.019, 0.018), "roughness": 0.95, "metallic": 0.0},
}


# --------------------------------------------------------------------------- #
# 纯几何工具（无 bpy 依赖）
# --------------------------------------------------------------------------- #

class Part:
    """累积一个对象的顶点 / 面 / 面材质。"""

    def __init__(self):
        self.verts = []
        self.faces = []   # [(indices, material_name), ...]

    def add(self, verts, faces, material):
        offset = len(self.verts)
        self.verts.extend(verts)
        for face in faces:
            self.faces.append((tuple(i + offset for i in face), material))

    def add_part(self, other):
        for face, mat in other.faces:
            self.faces.append((tuple(i + len(self.verts) for i in face), mat))
        self.verts.extend(other.verts)


def ring(n, rx, ry, z, cx=0.0, cy=0.0, phase=None):
    """z 高度处的椭圆环，逆时针（从 +Z 看）。"""
    if phase is None:
        phase = math.pi / n
    return [
        (cx + rx * math.cos(phase + 2.0 * math.pi * i / n),
         cy + ry * math.sin(phase + 2.0 * math.pi * i / n),
         z)
        for i in range(n)
    ]


def band(lower, upper):
    """两圈等长顶点之间的侧壁四边形；lower 在下方时法线朝外。"""
    n = len(lower)
    verts = list(lower) + list(upper)
    faces = []
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    return verts, faces


def cap(pts, flip=False):
    """扇三角化封盖。pts 逆时针时法线朝 +Z；flip=True 朝 -Z。"""
    n = len(pts)
    faces = [(0, i, i + 1) for i in range(1, n - 1)]
    if flip:
        faces = [tuple(reversed(f)) for f in faces]
    return list(pts), faces


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


def cone(base_pts, apex):
    n = len(base_pts)
    verts = list(base_pts) + [apex]
    faces = [(i, (i + 1) % n, n) for i in range(n)]
    return verts, faces


def closed_mound(rings, apex):
    """闭合壳体：若干等长环之间的侧壁 + 顶部锥面 + 底面封盖，全部共享顶点。

    rings 只有一个环时即为"锥 + 底盖"的闭合锥体。封盖必须复用环顶点，
    否则会留下边界边（干跑脚本会报 boundary>0）。
    """
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
    apex_idx = len(verts)
    verts.append(apex)
    top = (len(rings) - 1) * n
    for i in range(n):
        faces.append((top + i, top + ((i + 1) % n), apex_idx))
    for i in range(1, n - 1):
        faces.append((0, i + 1, i))
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


def annulus(r_out, r_in, z0, z1, sides=8):
    """八角环形（吊环）：外壁 + 内壁 + 上下环面。"""
    ob = ring(sides, r_out, r_out, z0)
    ot = ring(sides, r_out, r_out, z1)
    ib = ring(sides, r_in, r_in, z0)
    it = ring(sides, r_in, r_in, z1)
    verts = []
    faces = []
    base = 0

    def push(pts):
        nonlocal base
        start = len(verts)
        verts.extend(pts)
        return start

    o0 = push(ob)
    o1 = push(ot)
    i0 = push(ib)
    i1 = push(it)
    for i in range(sides):
        j = (i + 1) % sides
        faces.append((o0 + i, o0 + j, o1 + j, o1 + i))          # 外壁
        faces.append((i1 + i, i1 + j, i0 + j, i0 + i))          # 内壁（反向）
        faces.append((o1 + i, o1 + j, i1 + j, i1 + i))          # 顶环面 +Z
        faces.append((o0 + i, i0 + i, i0 + j, o0 + j))          # 底环面 -Z
    return verts, faces


def jit(i, k):
    """确定性抖动 -1..1，保证重建结果逐位一致。"""
    h = (i * 73856093) ^ (k * 19349663)
    h &= 0x7FFFFFFF
    return (h % 2000) / 1000.0 - 1.0


# --------------------------------------------------------------------------- #
# 1. SN_Gas_Lamp —— 煤气灯柱（0.35 × 0.35 × 3.5）
# --------------------------------------------------------------------------- #

def build_gas_lamp():
    m = Part()
    MET, CAN = "SN_Metal", "SN_Canvas"

    # 基座（八角锥台）
    m.add(*revolved([(0.000, 0.170), (0.140, 0.150)], 8), MET)
    # 灯杆（八角柱，向上收分）
    m.add(*revolved([(0.130, 0.058), (2.920, 0.042)], 8), MET)
    # 灯座颈圈
    m.add(*revolved([(2.900, 0.085), (3.010, 0.075)], 8), MET)
    # 横臂（沿 X 的扁铁，托住灯罩）
    m.add(*box((-0.175, -0.022, 2.980), (0.175, 0.022, 3.050)), MET)
    # 灯罩底盘
    m.add(*revolved([(3.040, 0.115), (3.058, 0.115)], 8), MET)
    # 灯罩玻璃（SN_Canvas，微收分）
    m.add(*revolved([(3.050, 0.112), (3.360, 0.104)], 8), CAN)
    # 顶盖板
    m.add(*revolved([(3.352, 0.118), (3.375, 0.118)], 8), MET)
    # 灯帽锥 + 顶（封盖与锥面共享底环顶点）
    base = ring(8, 0.145, 0.145, 3.370)
    m.add(*closed_mound([base], (0.0, 0.0, 3.500)), MET)
    return m


# --------------------------------------------------------------------------- #
# 2. SN_Gangway —— 船岸跳板（6.0 × 1.2 × 0.5）
# --------------------------------------------------------------------------- #

def build_gangway():
    m = Part()
    WOOD, MET = "SN_Wood", "SN_Metal"

    x0, x1 = -3.000, 2.950
    n_plank, gap = 5, 0.012
    half_w = 0.575
    pw = (2.0 * half_w - gap * (n_plank - 1)) / n_plank
    y = -half_w
    for _ in range(n_plank):
        m.add(*box((x0, y, 0.000), (x1, y + pw, 0.100)), WOOD)
        y += pw + gap

    # 两侧钢梁（与木板重叠 25 mm，避免共面）
    for sy in (-1.0, 1.0):
        ya, yb = sorted((sy * 0.550, sy * 0.600))
        m.add(*box((x0, ya, 0.000), (x1, yb, 0.120)), MET)

    # 立柱：每侧 3 根
    for px in (-2.50, 0.00, 2.50):
        for sy in (-1.0, 1.0):
            cy = sy * 0.575
            m.add(*box((px - 0.023, cy - 0.023, 0.100), (px + 0.023, cy + 0.023, 0.440)), MET)

    # 扶手
    for sy in (-1.0, 1.0):
        ya, yb = sorted((sy * 0.550, sy * 0.600))
        m.add(*box((x0, ya, 0.435), (x1, yb, 0.478)), MET)

    # 端部搭钩（+X 端两只，三截互相错开避免共面）
    for sy in (-1.0, 1.0):
        cy = sy * 0.575
        m.add(*box((2.860, cy - 0.019, 0.100), (2.940, cy + 0.019, 0.520)), MET)   # 立杆
        m.add(*box((2.890, cy - 0.0205, 0.470), (3.000, cy + 0.0205, 0.515)), MET)  # 上臂
        m.add(*box((2.955, cy - 0.0185, 0.300), (3.000, cy + 0.0185, 0.489)), MET)  # 下钩
    return m


# --------------------------------------------------------------------------- #
# 3. SN_Grab_Bucket —— 双瓣抓斗（1.5³）
# --------------------------------------------------------------------------- #

def _clamshell(angles, radii, zs, y_shift):
    """单个斗瓣：三圈（顶口 / 最宽 / 刃口）之间的侧壁 + 接缝面 + 上下封盖。

    闭合抓斗的造型是"蛋形"：顶部（铰接口）窄、中间最宽、底部刃口收拢；
    两瓣的刃口在底中缝相接。半径数组必须"顶 < 中 > 底"，否则会做成漏斗。
    """
    rings = []
    for r, z in zip(radii, zs):
        rings.append([(r * math.cos(a), r * math.sin(a) + y_shift, z) for a in angles])
    n = len(angles)
    verts = []
    for pts in rings:
        verts.extend(pts)
    faces = []
    # 外侧壁
    for k in range(len(rings) - 1):
        base, nxt = k * n, (k + 1) * n
        for i in range(n - 1):
            faces.append((base + i, base + i + 1, nxt + i + 1, nxt + i))
    # 接缝面（两端点之间，逐圈连接；端点 sin=0，故接缝面共面）
    for k in range(len(rings) - 1):
        base, nxt = k * n, (k + 1) * n
        faces.append((base + n - 1, base, nxt, nxt + n - 1))
    # 顶口封盖
    top = (len(rings) - 1) * n
    for i in range(1, n - 1):
        faces.append((top, top + i, top + i + 1))
    # 刃口封盖（反向）
    for i in range(1, n - 1):
        faces.append((0, i + 1, i))
    return verts, faces


def build_grab_bucket():
    m = Part()
    MET = "SN_Metal"
    n = 5
    # 斗口要够宽（接近最宽处），否则会读成"窄口锅"；最宽点略高于中腰
    radii = (0.580, 0.747, 0.100)
    zs = (0.640, 0.340, 0.000)

    # 两个斗瓣：接缝错开 ±3 mm，避免两个接缝面共面
    half_a = [math.pi + math.pi * 0.25 * i for i in range(n)]          # 180°..360°（y<=0）
    half_b = [0.0 + math.pi * 0.25 * i for i in range(n)]              # 0°..180°（y>=0）
    m.add(*_clamshell(half_a, radii, zs, -0.003), MET)
    m.add(*_clamshell(half_b, radii, zs, 0.003), MET)

    # 铰接轴（沿 X 的八边形柱，抬高到斗口之上）
    m.add(*tube_axis([(-0.180, 0.052), (0.180, 0.052)], 8, 0.664, "x"), MET)
    # 铰接耳板
    for sx in (-1.0, 1.0):
        xa, xb = sorted((sx * 0.175, sx * 0.215))
        m.add(*box((xa, -0.050, 0.620), (xb, 0.050, 0.740)), MET)
    # 拉杆（铰接轴 -> 横梁）
    for sx in (-1.0, 1.0):
        xa, xb = sorted((sx * 0.065, sx * 0.115))
        m.add(*box((xa, -0.022, 0.680), (xb, 0.022, 1.020)), MET)
    # 顶部横梁
    m.add(*box((-0.200, -0.045, 1.000), (0.200, 0.045, 1.080)), MET)
    # 拉杆（横梁 -> 吊环）
    for sx in (-1.0, 1.0):
        xa, xb = sorted((sx * 0.115, sx * 0.165))
        m.add(*box((xa, -0.030, 1.050), (xb, 0.030, 1.280)), MET)
    # 顶部吊环
    m.add(*annulus(0.200, 0.130, 1.240, 1.460, 8), MET)
    return m


# --------------------------------------------------------------------------- #
# 4. SN_Coal_Pile —— 煤堆（3.0 × 2.5 × 1.2）
# --------------------------------------------------------------------------- #

def build_coal_pile():
    m = Part()
    COAL = "SN_Coal"
    n = 16

    levels = [
        (0.00, 1.45, 1.20, 0.00),
        (0.42, 1.16, 0.95, 0.05),
        (0.74, 0.79, 0.64, 0.045),
        (0.99, 0.40, 0.32, 0.03),
    ]
    rings = []
    for li, (z, rx, ry, amp) in enumerate(levels):
        pts = []
        for i in range(n):
            a = 2.0 * math.pi * i / n + 0.13 * li
            dx = amp * jit(i, li * 7 + 1)
            dy = amp * jit(i, li * 7 + 2)
            dz = 0.02 * jit(i, li * 7 + 3) if li else 0.0
            pts.append((rx * math.cos(a) + dx, ry * math.sin(a) + dy, z + dz))
        rings.append(pts)

    verts, faces = closed_mound(rings, (0.060 * jit(99, 1), 0.050 * jit(99, 2), 1.170))
    # 抖动会让实际外轮廓缩水，这里把底面撑到精确的 ±1.50 / ±1.25，
    # 保证包围盒 3.0 × 2.5（工单尺寸，误差需 <= 0.1）。
    sx = 1.500 / max(abs(v[0]) for v in verts)
    sy = 1.250 / max(abs(v[1]) for v in verts)
    verts = [(x * sx, y * sy, z) for x, y, z in verts]
    m.add(verts, faces, COAL)

    # 次堆
    base = ring(8, 0.55, 0.45, 0.0, cx=-0.85, cy=0.70)
    mid = ring(8, 0.38, 0.31, 0.24, cx=-0.85, cy=0.70)
    m.add(*closed_mound([base, mid], (-0.82, 0.72, 0.40)), COAL)

    # 散落煤块（14 块，底面抬 4 mm 避免与堆底共面）
    for k in range(14):
        cx = 1.05 * jit(k, 11)
        cy = 0.82 * jit(k, 12)
        s = 0.10 + 0.06 * abs(jit(k, 13))
        h = 0.07 + 0.05 * abs(jit(k, 14))
        bpts = [
            (cx - s, cy - s * 0.8, 0.004), (cx + s * 0.9, cy - s, 0.004),
            (cx + s, cy + s * 0.9, 0.004), (cx - s * 0.8, cy + s, 0.004),
        ]
        apex = (cx + 0.02 * jit(k, 15), cy + 0.02 * jit(k, 16), h)
        m.add(*closed_mound([bpts], apex), COAL)
    return m


# --------------------------------------------------------------------------- #
# 5. SN_Dock_Ladder —— 码头铁爬梯（0.6 × 0.25 × 3.2）
# --------------------------------------------------------------------------- #

def build_dock_ladder():
    m = Part()
    MET = "SN_Metal"

    # 两侧立杆
    for sx in (-1.0, 1.0):
        xa, xb = sorted((sx * 0.250, sx * 0.300))
        m.add(*box((xa, -0.025, 0.000), (xb, 0.025, 3.060)), MET)

    # 踏杆 ×7
    for k in range(7):
        zc = 0.300 + 0.420 * k
        m.add(*box((-0.270, -0.022, zc), (0.270, 0.022, zc + 0.045)), MET)

    # 顶部挂钩（每侧两截，横向探出 +Y）
    for sx in (-1.0, 1.0):
        xa, xb = sorted((sx * 0.244, sx * 0.304))
        m.add(*box((xa, -0.025, 3.040), (xb, 0.025, 3.200)), MET)      # 竖段
        m.add(*box((xa, 0.020, 3.155), (xb, 0.250, 3.195)), MET)       # 横臂
    return m


# --------------------------------------------------------------------------- #
# 6. SN_Plate_Stack —— 钢板堆（3.0 × 2.0 × 0.6）
# --------------------------------------------------------------------------- #

def build_plate_stack():
    m = Part()
    MET, WOOD = "SN_Metal", "SN_Wood_Dark"

    # 木垫条
    for ya, yb in ((-0.950, -0.800), (0.800, 0.950)):
        m.add(*box((-1.450, ya, 0.000), (1.450, yb, 0.080)), WOOD)

    # 4 层钢板：相邻层重叠 2 mm，避免共面
    offsets = (0.000, 0.012, -0.012, 0.006)
    for i, dx in enumerate(offsets):
        z0 = 0.075 + 0.108 * i
        m.add(*box((-1.485 + dx, -0.990, z0), (1.485 + dx, 0.990, z0 + 0.110)), MET)

    # 两道金属绑带（顶压条 + 两侧下垂）
    for sx in (-1.0, 1.0):
        xa, xb = sorted((sx * 0.750, sx * 0.850))
        m.add(*box((xa, -1.000, 0.500), (xb, 1.000, 0.550)), MET)          # 顶压条
        m.add(*box((xa, 0.980, 0.000), (xb, 1.000, 0.530)), MET)           # +Y 侧带
        m.add(*box((xa, -1.000, 0.000), (xb, -0.980, 0.530)), MET)         # -Y 侧带
    return m


BUILDERS = {
    "SN_Gas_Lamp": build_gas_lamp,
    "SN_Gangway": build_gangway,
    "SN_Grab_Bucket": build_grab_bucket,
    "SN_Coal_Pile": build_coal_pile,
    "SN_Dock_Ladder": build_dock_ladder,
    "SN_Plate_Stack": build_plate_stack,
}


def build_all_geometry():
    """返回 {对象名: Part}，纯几何，不依赖 bpy。"""
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
    mat.roughness = spec["roughness"]
    mat.metallic = spec["metallic"]
    try:
        mat.blend_method = "HASHED"      # 与现有调色板一致
    except (AttributeError, TypeError):
        pass
    return mat


def _make_object(name, part, location):
    import bpy
    import bmesh

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in part.verts], [], [list(f) for f, _ in part.faces])
    mesh.update()

    # 统一朝外：多壳体各自独立，recalc 按连通分量处理
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

    coll = bpy.data.collections.get(COLLECTION)
    if coll is None:
        raise RuntimeError("集合 %s 不存在" % COLLECTION)

    # 允许重跑：只删除这 6 个同名对象及其网格
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
    made = []
    for name, pos, _budget, _size in ITEMS:
        made.append(_make_object(name, geometry[name], pos))
    return made


def report():
    import bpy
    import bmesh
    import hashlib

    out = {"items": [], "total_tris": 0, "health": {}, "scene": {}}
    per_item = {}
    for name, pos, budget, size in ITEMS:
        obj = bpy.data.objects[name]
        mesh = obj.data
        mesh.calc_loop_triangles()
        tris = len(mesh.loop_triangles)
        per_item[name] = {"tris": tris, "budget": budget, "limit": int(budget * 1.5)}

        bm = bmesh.new()
        bm.from_mesh(mesh)
        bm.edges.ensure_lookup_table()
        loose = sum(1 for v in bm.verts if not v.link_edges)
        degen = sum(1 for f in bm.faces if f.calc_area() < 1e-9)
        nonman = sum(1 for e in bm.edges if not e.is_manifold)
        boundary = sum(1 for e in bm.edges if e.is_boundary)
        overflow = sum(1 for p in mesh.polygons if p.material_index >= len(mesh.materials))
        bm.free()

        xs = [v.co.x for v in mesh.vertices]
        ys = [v.co.y for v in mesh.vertices]
        zs = [v.co.z for v in mesh.vertices]
        measured = [round(max(xs) - min(xs), 4), round(max(ys) - min(ys), 4), round(max(zs) - min(zs), 4)]
        delta = [round(measured[i] - size[i], 4) for i in range(3)]

        out["items"].append({
            "name": name,
            "location": [round(v, 4) for v in obj.location],
            "tris": tris,
            "budget": budget,
            "verts": len(mesh.vertices),
            "size": measured,
            "target": list(size),
            "size_delta": delta,
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

    scene_objs = bpy.data.objects
    out["scene"] = {
        "objects": len(scene_objs),
        "mesh": sum(1 for o in scene_objs if o.type == "MESH"),
        "materials": sorted(m.name for m in bpy.data.materials),
        "props_collection": sorted(o.name for o in bpy.data.collections[COLLECTION].objects),
        "mesh_datablocks": len(bpy.data.meshes),
    }
    print("BATCH2_REPORT " + repr(out))
    return out


if __name__ == "__main__":
    import bpy  # noqa: F401
    build_all()
    report()
