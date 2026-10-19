# -*- coding: utf-8 -*-
"""Steam Navigator — 船舶模块 11 件参数化生成脚本。

工单：tools/modeling/briefs/sn_ship_modules_batch1.json
集合：SN_Ship_Modules（新建；重跑时只删除/重建本批 11 件）
布局：y=60 一排（锅炉 / 货舱），y=68 一排（导航 / 安全 / 客舱）
轴心：底面中心（object.location = 布局位置，几何全部为局部坐标，底面 z=0）
预算：合计 <= 8250 tri；单件见 ITEMS 表（验收上限 1.5×）
材质：只用既有调色板（本批不新增材质）

设计要点
--------
- 11 件对应 Core 里除船体外的全部模块实体，造型按类别区分：
  锅炉 = 横/立式圆筒 + 烟囱 + 管阀；货舱 = 木箱 + 铁肋 + 格栅；
  导航 = 黄铜镜筒 / 海图室；安全 = 救生艇 / 安全阀；客舱 = 甲板室。
- 全部几何由本文件顶部参数表生成，改数值即可重建；禁止手工摆点。
- 每个 item 是**一个 mesh 对象**（多材质槽），原点在底面中心。
- 每个壳体闭合且顶点焊接，边界边 / 非流形边应为 0；互相穿插的部件之间
  错开 3–20 mm，避免共面 z-fighting。
- 几何函数为纯 Python（不 import bpy），可用 dryrun_props.py 离线校验。
- 本文件自带几何工具函数（与前几批重复但各自独立），保持单文件可执行。

用法
----
Blender 内：import runpy; runpy.run_path(<本文件>, run_name="__main__")
纯 Python 干跑：python tools/modeling/generators/dryrun_props.py tools/modeling/generators/sn_ship_modules_generator.py
"""

import math

COLLECTION = "SN_Ship_Modules"

ITEMS = [
    ("SN_Boiler_Efficient", (-21.0, 60.0, 0.0), 650, (1.80, 1.60, 2.60)),
    ("SN_Boiler_Standard", (-16.0, 60.0, 0.0), 950, (2.80, 1.90, 2.70)),
    ("SN_Boiler_Performance", (-9.0, 60.0, 0.0), 1200, (3.40, 2.10, 3.00)),
    ("SN_Cargo_Small_Hold", (-2.0, 60.0, 0.0), 600, (2.40, 2.00, 1.80)),
    ("SN_Cargo_Medium_Hold", (4.0, 60.0, 0.0), 700, (3.20, 2.40, 2.20)),
    ("SN_Cargo_Large_Hold", (11.0, 60.0, 0.0), 800, (4.00, 2.80, 2.60)),
    ("SN_Nav_Spyglass", (-21.0, 68.0, 0.0), 450, (1.35, 0.80, 1.75)),
    ("SN_Nav_Chart_Room", (-16.5, 68.0, 0.0), 800, (2.80, 2.20, 2.60)),
    ("SN_Safety_Lifeboat", (-10.0, 68.0, 0.0), 700, (4.20, 1.50, 1.10)),
    ("SN_Safety_Valve", (-3.0, 68.0, 0.0), 550, (1.50, 1.30, 1.85)),
    ("SN_Cabin_Passenger", (4.0, 68.0, 0.0), 900, (3.40, 2.40, 2.60)),
]

TOTAL_BUDGET = 8300

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
    return hexa(
        [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)],
        [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)],
    )


def hexa(bottom, top):
    """8 顶点六面体：bottom / top 各 4 点，从 +Z 看逆时针。"""
    verts = list(bottom) + list(top)
    faces = [
        (0, 3, 2, 1), (4, 5, 6, 7),
        (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7),
    ]
    return verts, faces


def translate(vf, dx, dy, dz):
    verts, faces = vf
    return [(x + dx, y + dy, z + dz) for x, y, z in verts], faces


def revolved(profile, sides, phase=None):
    """回转体：profile = [(z, r), ...]，首尾各一个封盖三角扇。"""
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


def tube_axis(profile, sides, z_center, axis="x"):
    """沿 X/Y 轴的圆柱：profile = [(pos, r), ...]。"""
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


def disc_axis(cx, pos0, pos1, radius, z_center, axis="y", sides=8):
    vf = tube_axis([(pos0, radius), (pos1, radius)], sides, z_center, axis)
    return translate(vf, cx, 0.0, 0.0) if axis == "y" else translate(vf, 0.0, cx, 0.0)


def closed_mound(rings, apex):
    """闭合壳体：若干等长环之间的侧壁 + 顶部锥面 + 底面封盖（环共享顶点）。"""
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


def ball_shell(profile, sides):
    if profile[0][1] > 1e-9 or profile[-1][1] > 1e-9:
        raise ValueError("ball_shell 的首尾必须是 r=0 的极点")
    rings = [ring(sides, r, r, z) for z, r in profile[1:-1]]
    verts = [(0.0, 0.0, profile[0][0])]
    bottom = 0
    offsets = []
    for pts in rings:
        offsets.append(len(verts))
        verts.extend(pts)
    top = len(verts)
    verts.append((0.0, 0.0, profile[-1][0]))
    faces = []
    first = offsets[0]
    for i in range(sides):
        faces.append((bottom, first + i, first + (i + 1) % sides))
    for k in range(len(offsets) - 1):
        a, b = offsets[k], offsets[k + 1]
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((a + i, a + j, b + j, b + i))
    last = offsets[-1]
    for i in range(sides):
        faces.append((last + i, last + (i + 1) % sides, top))
    return verts, faces


def funnel_rect(top_half, bot_half, z_top, z_bot, wall, z_lip=0.03):
    """方口薄壁漏斗（闭合壳）：外壳 + 顶沿 + 内壳 + 底沿。开口可见但网格水密。"""
    def rect(h, z):
        return [(-h, -h, z), (h, -h, z), (h, h, z), (-h, h, z)]

    ot = rect(top_half, z_top)
    it = rect(top_half - wall, z_top)
    ib = rect(bot_half - wall, z_bot + z_lip)
    ob = rect(bot_half, z_bot)
    verts = ot + it + ib + ob
    o, i0, i1, bo = 0, 4, 8, 12
    faces = []
    for k in range(4):
        n = (k + 1) % 4
        faces.append((o + k, o + n, i0 + n, i0 + k))
        faces.append((i0 + k, i0 + n, i1 + n, i1 + k))
        faces.append((i1 + k, i1 + n, bo + n, bo + k))
        faces.append((bo + k, bo + n, o + n, o + k))
    return verts, faces


def rect_pts(x0, x1, y0, y1, z):
    return [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)]


def taper_band(z0, z1, axy0, axy1, t):
    """套在锥形墩身上的矩形铁箍：内壁贴合锥面，外壁外扩 t，上下口封闭。"""
    ax0, ay0 = axy0
    ax1, ay1 = axy1
    inner0 = rect_pts(-ax0, ax0, -ay0, ay0, z0)
    inner1 = rect_pts(-ax1, ax1, -ay1, ay1, z1)
    outer0 = rect_pts(-ax0 - t, ax0 + t, -ay0 - t, ay0 + t, z0)
    outer1 = rect_pts(-ax1 - t, ax1 + t, -ay1 - t, ay1 + t, z1)
    verts = inner0 + inner1 + outer0 + outer1
    faces = []
    for k in range(4):
        n = (k + 1) % 4
        faces.append((k, n, 4 + n, 4 + k))
        faces.append((8 + k, 12 + k, 12 + n, 8 + n))
        faces.append((4 + k, 4 + n, 12 + n, 12 + k))
        faces.append((k, 8 + k, 8 + n, n))
    return verts, faces


def loft(sections):
    """沿 X 放样闭合实体：每站为同一顶点数的闭合截面环，首尾用 n-gon 封盖。"""
    n = len(sections[0])
    verts = [p for sec in sections for p in sec]
    faces = []
    for k in range(len(sections) - 1):
        a, b = k * n, (k + 1) * n
        for i in range(n):
            j = (i + 1) % n
            faces.append((a + i, a + j, b + j, b + i))
    faces.append(tuple(range(n - 1, -1, -1)))
    last = (len(sections) - 1) * n
    faces.append(tuple(range(last, last + n)))
    return verts, faces


def cyl(z0, z1, radius, sides=8):
    return revolved([(z0, radius), (z1, radius)], sides)


def tube_x(x0, x1, radius, z_center, sides=8):
    return tube_axis([(x0, radius), (x1, radius)], sides, z_center, "x")


def tube_y(y0, y1, radius, z_center, sides=8):
    return tube_axis([(y0, radius), (y1, radius)], sides, z_center, "y")


def front_and_back(x0, x1, radius, z_center, sides=8):
    """沿 X 的实心圆柱（前后两个封盖），等价 tube_x。"""
    return tube_x(x0, x1, radius, z_center, sides)


# --------------------------------------------------------------------------- #
# 1. SN_Boiler_Efficient —— 小型高效立式锅炉（1.80 × 1.60 × 2.60）
# --------------------------------------------------------------------------- #

def build_boiler_efficient():
    m = Part()
    MET, DARK, IRON, BRASS = "SN_Metal", "SN_Wood_Dark", "SN_Iron_Hull", "SN_Brass"

    # 滑橇底座 + 地脚螺栓
    m.add(*box((-0.90, -0.80, 0.00), (0.90, 0.80, 0.18)), DARK)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            cx, cy = sx * 0.80, sy * 0.70
            m.add(*box((cx - 0.05, cy - 0.05, 0.18), (cx + 0.05, cy + 0.05, 0.26)), MET)

    # 立式锅筒 + 三道铁箍
    m.add(*cyl(0.18, 1.60, 0.60, 10), MET)
    for z in (0.55, 1.05, 1.50):
        m.add(*cyl(z, z + 0.06, 0.635, 10), IRON)

    # 穹顶 + 烟囱 + 蒸汽包
    m.add(*ball_shell([(1.56, 0.0), (1.66, 0.40), (1.80, 0.55),
                       (1.94, 0.60), (2.04, 0.60), (2.12, 0.0)], 10), MET)
    m.add(*translate(revolved([(2.04, 0.185), (2.55, 0.155)], 8), -0.20, 0.0, 0.0), MET)
    m.add(*translate(cyl(2.51, 2.60, 0.21, 8), -0.20, 0.0, 0.0), BRASS)
    m.add(*translate(ball_shell([(2.06, 0.0), (2.10, 0.14), (2.16, 0.18), (2.22, 0.0)], 8),
                     0.28, 0.0, 0.0), BRASS)

    # 炉门 / 灰门（+X 正面）
    m.add(*box((0.58, -0.24, 0.52), (0.70, 0.24, 1.02)), IRON)
    for sy in (-1.0, 1.0):
        m.add(*box((0.52, sy * 0.27 - 0.03, 0.90), (0.58, sy * 0.27 + 0.03, 0.96)), MET)
    m.add(*box((0.70, -0.06, 0.70), (0.76, 0.06, 0.78)), BRASS)
    m.add(*box((0.55, -0.20, 0.22), (0.66, 0.20, 0.44)), IRON)

    # 给水管 + 泵体（-Y 侧）
    m.add(*translate(cyl(0.26, 1.48, 0.05, 8), 0.44, -0.52, 0.0), MET)
    m.add(*translate(tube_y(-0.52, -0.30, 0.05, 1.44), 0.44, 0.0, 0.0), MET)
    m.add(*box((0.26, -0.64, 0.30), (0.54, -0.44, 0.58)), BRASS)

    # 压力表（嵌进锅筒 2 cm）+ 铭牌（外凸 5 mm，避免与底座外表面共面）
    m.add(*disc_axis(0.30, 0.48, 0.62, 0.10, 1.30, "x", 8), MET)
    m.add(*box((0.845, -0.30, 0.04), (0.905, 0.30, 0.16)), BRASS)
    return m


# --------------------------------------------------------------------------- #
# 2. SN_Boiler_Standard —— 标准卧式锅炉（2.80 × 1.90 × 2.70）
# --------------------------------------------------------------------------- #

def build_boiler_standard():
    m = Part()
    MET, DARK, IRON, BRASS = "SN_Metal", "SN_Wood_Dark", "SN_Iron_Hull", "SN_Brass"

    # 木底座 + 地脚螺栓
    m.add(*box((-1.40, -0.95, 0.00), (1.40, 0.95, 0.22)), DARK)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            cx, cy = sx * 1.28, sy * 0.84
            m.add(*box((cx - 0.05, cy - 0.05, 0.22), (cx + 0.05, cy + 0.05, 0.30)), MET)

    # 鞍座
    for sx in (-1.0, 1.0):
        cx = sx * 0.58
        m.add(*box((cx - 0.10, -0.66, 0.22), (cx + 0.10, 0.66, 0.52)), IRON)

    # 卧式锅筒 + 端盖 + 三道加强箍
    m.add(*tube_x(-1.04, 1.04, 0.66, 1.02, 10), MET)
    m.add(*tube_x(-1.16, -1.04, 0.72, 1.02, 10), IRON)
    m.add(*tube_x(1.04, 1.16, 0.72, 1.02, 10), IRON)
    for x in (-0.62, 0.0, 0.62):
        m.add(*tube_x(x - 0.05, x + 0.05, 0.695, 1.02, 10), IRON)

    # 炉门 + 铰链 + 把手；灰盘
    m.add(*box((1.14, -0.26, 0.60), (1.26, 0.26, 1.08)), IRON)
    for sy in (-1.0, 1.0):
        m.add(*box((1.12, sy * 0.30 - 0.05, 0.94), (1.20, sy * 0.30 + 0.05, 1.00)), MET)
    m.add(*box((1.24, -0.06, 0.70), (1.30, 0.06, 0.78)), BRASS)
    m.add(*box((0.96, -0.46, 0.22), (1.18, 0.46, 0.44)), MET)

    # 蒸汽包 + 安全阀 + 杠杆重锤
    m.add(*translate(ball_shell([(1.62, 0.0), (1.68, 0.26), (1.76, 0.32), (1.82, 0.0)], 10),
                     0.28, 0.0, 0.0), BRASS)
    m.add(*translate(cyl(1.78, 1.98, 0.09, 8), 0.28, 0.0, 0.0), MET)
    m.add(*hexa([(0.14, -0.03, 1.96), (0.66, -0.03, 1.96), (0.66, 0.03, 1.96), (0.14, 0.03, 1.96)],
                [(0.14, -0.03, 2.02), (0.66, -0.03, 2.02), (0.66, 0.03, 2.02), (0.14, 0.03, 2.02)]), MET)
    m.add(*box((0.58, -0.06, 1.74), (0.66, 0.06, 1.94)), IRON)

    # 烟囱 + 顶圈；汽笛
    m.add(*translate(revolved([(1.52, 0.26), (2.62, 0.22)], 8), -0.82, 0.0, 0.0), MET)
    m.add(*translate(cyl(2.58, 2.62, 0.29, 8), -0.82, 0.0, 0.0), MET)
    m.add(*translate(cyl(1.66, 1.96, 0.05, 6), 0.78, -0.10, 0.0), BRASS)
    m.add(*translate(cyl(1.94, 1.98, 0.09, 6), 0.78, -0.10, 0.0), BRASS)

    # 顶部扶手（两侧）+ 立柱
    for sy in (-1.0, 1.0):
        y = sy * 0.52
        m.add(*translate(tube_x(-0.92, 0.92, 0.025, 1.74, 6), 0.0, y, 0.0), BRASS)
        for x in (-0.86, 0.0, 0.86):
            m.add(*box((x - 0.03, y - 0.03, 1.40), (x + 0.03, y + 0.03, 1.74)), MET)

    # 压力表（嵌进端盖 2 cm）
    for sy in (-1.0, 1.0):
        m.add(*disc_axis(sy * 0.24, 1.14, 1.22, 0.10, 1.38, "x", 8), MET)
        m.add(*box((1.20, sy * 0.24 - 0.02, 1.30), (1.23, sy * 0.24 + 0.02, 1.38)), BRASS)

    # 侧给水管（-Y 侧，贴住锅筒）+ 支脚（落在底座上）
    m.add(*translate(tube_x(-0.62, 0.62, 0.06, 1.08, 8), 0.0, -0.70, 0.0), MET)
    for x in (-0.55, 0.55):
        m.add(*translate(cyl(0.30, 1.08, 0.06, 8), x, -0.70, 0.0), MET)
        m.add(*box((x - 0.08, -0.78, 0.22), (x + 0.08, -0.62, 0.40)), IRON)

    # 铭牌（底座 +X 端面）
    m.add(*box((1.38, -0.40, 0.04), (1.42, 0.40, 0.16)), BRASS)
    return m


# --------------------------------------------------------------------------- #
# 3. SN_Boiler_Performance —— 高性能双锅筒锅炉（3.40 × 2.10 × 3.00）
# --------------------------------------------------------------------------- #

def build_boiler_performance():
    m = Part()
    MET, DARK, IRON, BRASS = "SN_Metal", "SN_Wood_Dark", "SN_Iron_Hull", "SN_Brass"

    # 底座 + 地脚螺栓
    m.add(*box((-1.70, -1.05, 0.00), (1.70, 1.05, 0.24)), DARK)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            cx, cy = sx * 1.56, sy * 0.92
            m.add(*box((cx - 0.05, cy - 0.05, 0.24), (cx + 0.05, cy + 0.05, 0.32)), MET)

    # 双卧式锅筒 + 端盖 + 三道箍
    for sy in (-1.0, 1.0):
        y = sy * 0.50
        m.add(*translate(tube_x(-1.32, 1.32, 0.54, 1.12, 8), 0.0, y, 0.0), MET)
        m.add(*translate(tube_x(-1.44, -1.32, 0.60, 1.12, 8), 0.0, y, 0.0), IRON)
        m.add(*translate(tube_x(1.32, 1.44, 0.60, 1.12, 8), 0.0, y, 0.0), IRON)
        for x in (-0.85, 0.0, 0.85):
            m.add(*translate(tube_x(x - 0.05, x + 0.05, 0.565, 1.12, 8), 0.0, y, 0.0), IRON)
        # 炉门 + 把手 + 灰门
        m.add(*box((1.42, y - 0.26, 0.62), (1.54, y + 0.26, 1.12)), IRON)
        m.add(*box((1.52, y - 0.05, 0.80), (1.58, y + 0.05, 0.94)), BRASS)
        m.add(*box((1.44, y - 0.30, 0.22), (1.52, y + 0.30, 0.46)), IRON)

    # 支座
    for sy in (-1.0, 1.0):
        for sx in (-1.0, 1.0):
            cx = sx * 0.72
            m.add(*box((cx - 0.10, sy * 0.50 - 0.44, 0.20), (cx + 0.10, sy * 0.50 + 0.44, 0.62)), IRON)

    # 过热器筒 + 端盖
    m.add(*tube_x(-0.95, 0.95, 0.26, 2.02, 8), BRASS)
    m.add(*tube_x(-1.01, -0.95, 0.30, 2.02, 8), IRON)
    m.add(*tube_x(0.95, 1.01, 0.30, 2.02, 8), IRON)

    # 连接立管（贴住锅筒顶与过热器筒底）
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            m.add(*translate(cyl(1.55, 2.02, 0.07, 8), sx * 0.55, sy * 0.22, 0.0), MET)

    # 安全阀（锅筒顶）
    for sy in (-1.0, 1.0):
        m.add(*translate(cyl(1.64, 1.86, 0.07, 8), 0.55, sy * 0.50, 0.0), MET)
        m.add(*translate(cyl(1.84, 1.90, 0.11, 8), 0.55, sy * 0.50, 0.0), BRASS)

    # 汽包（过热器筒顶）
    for sx in (-1.0, 1.0):
        m.add(*translate(ball_shell([(2.22, 0.0), (2.26, 0.14), (2.32, 0.18), (2.38, 0.0)], 8),
                         sx * 0.45, 0.0, 0.0), BRASS)

    # 主蒸汽管
    m.add(*translate(tube_x(-0.90, 0.90, 0.09, 1.78, 8), 0.0, 0.0, 0.0), BRASS)

    # 双烟囱 + 顶圈 + 中箍
    for sy in (-1.0, 1.0):
        y = sy * 0.50
        m.add(*translate(revolved([(1.55, 0.24), (2.92, 0.20)], 8), -0.95, y, 0.0), MET)
        m.add(*translate(cyl(2.88, 2.94, 0.27, 8), -0.95, y, 0.0), BRASS)
        m.add(*translate(cyl(2.00, 2.04, 0.255, 8), -0.95, y, 0.0), BRASS)

    # 仪表（嵌进端盖 2 cm）
    m.add(*disc_axis(0.18, 1.42, 1.50, 0.09, 1.38, "x", 8), MET)
    m.add(*disc_axis(-0.18, 1.42, 1.50, 0.09, 1.38, "x", 8), MET)

    # 铭牌（底座 -Y 面，外凸 1 cm）
    m.add(*box((-0.60, -1.06, 0.04), (0.60, -1.04, 0.16)), BRASS)
    return m


# --------------------------------------------------------------------------- #
# 4. SN_Cargo_Small_Hold —— 小型货舱模块（2.40 × 2.00 × 1.80）
# --------------------------------------------------------------------------- #

def build_cargo_small_hold():
    m = Part()
    WOOD, DARK, MET, BRASS = "SN_Wood", "SN_Wood_Dark", "SN_Metal", "SN_Brass"

    # 底座 + 箱体
    m.add(*box((-1.20, -1.00, 0.00), (1.20, 1.00, 0.12)), DARK)
    m.add(*box((-1.15, -0.94, 0.10), (1.15, 0.94, 1.52)), WOOD)

    # 四角柱（外凸 5 mm，避免外表面与箱体共面）
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            cx, cy = sx * 1.10, sy * 0.89
            m.add(*box((cx - 0.055, cy - 0.055, 0.08), (cx + 0.055, cy + 0.055, 1.58)), DARK)

    # 侧肋（±Y）+ 端肋（±X）
    for sy in (-1.0, 1.0):
        ya, yb = sorted((sy * 0.94, sy * 1.00))
        for x in (-0.72, -0.24, 0.24, 0.72):
            m.add(*box((x - 0.05, ya, 0.14), (x + 0.05, yb, 1.50)), MET)
    for sx in (-1.0, 1.0):
        xa, xb = sorted((sx * 1.15, sx * 1.20))
        for y in (-0.42, 0.42):
            m.add(*box((xa, y - 0.05, 0.14), (xb, y + 0.05, 1.50)), MET)

    # 两道水平铁带
    for sy in (-1.0, 1.0):
        ya, yb = sorted((sy * 0.94, sy * 1.00))
        for z in (0.55, 1.05):
            m.add(*box((-1.15, ya, z), (1.15, yb, z + 0.10)), MET)

    # 顶部围板
    m.add(*box((-1.15, -0.94, 1.52), (1.15, -0.84, 1.68)), DARK)
    m.add(*box((-1.15, 0.84, 1.52), (1.15, 0.94, 1.68)), DARK)
    m.add(*box((-1.15, -0.84, 1.52), (-1.05, 0.84, 1.68)), DARK)
    m.add(*box((1.05, -0.84, 1.52), (1.15, 0.84, 1.68)), DARK)

    # 格栅
    for x in (-0.60, -0.30, 0.0, 0.30, 0.60):
        m.add(*box((x - 0.025, -0.84, 1.60), (x + 0.025, 0.84, 1.64)), MET)
    for y in (-0.42, 0.42):
        m.add(*box((-1.02, y - 0.025, 1.62), (1.02, y + 0.025, 1.66)), MET)

    # 四吊耳 + 铜铭牌
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            cx, cy = sx * 1.02, sy * 0.82
            m.add(*box((cx - 0.06, cy - 0.06, 1.68), (cx + 0.06, cy + 0.06, 1.80)), MET)
    m.add(*box((1.15, -0.20, 0.72), (1.18, 0.20, 0.92)), BRASS)
    return m


# --------------------------------------------------------------------------- #
# 5. SN_Cargo_Medium_Hold —— 中型货舱模块（3.20 × 2.40 × 2.20）
# --------------------------------------------------------------------------- #

def build_cargo_medium_hold():
    m = Part()
    WOOD, DARK, MET, BRASS = "SN_Wood", "SN_Wood_Dark", "SN_Metal", "SN_Brass"

    m.add(*box((-1.60, -1.20, 0.00), (1.60, 1.20, 0.14)), DARK)
    m.add(*box((-1.53, -1.12, 0.12), (1.53, 1.12, 1.80)), WOOD)

    # 四角柱
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            cx, cy = sx * 1.48, sy * 1.07
            m.add(*box((cx - 0.06, cy - 0.06, 0.10), (cx + 0.06, cy + 0.06, 1.86)), DARK)

    # 五道侧肋 + 两道端肋
    for sy in (-1.0, 1.0):
        ya, yb = sorted((sy * 1.12, sy * 1.20))
        for x in (-1.20, -0.60, 0.0, 0.60, 1.20):
            m.add(*box((x - 0.055, ya, 0.16), (x + 0.055, yb, 1.78)), MET)
    for sx in (-1.0, 1.0):
        xa, xb = sorted((sx * 1.53, sx * 1.60))
        for y in (-0.55, 0.55):
            m.add(*box((xa, y - 0.055, 0.16), (xb, y + 0.055, 1.78)), MET)

    # 两道水平铁带
    for sy in (-1.0, 1.0):
        ya, yb = sorted((sy * 1.12, sy * 1.20))
        for z in (0.60, 1.20):
            m.add(*box((-1.53, ya, z), (1.53, yb, z + 0.10)), MET)

    # 顶部围板
    m.add(*box((-1.53, -1.12, 1.80), (1.53, -1.02, 1.96)), DARK)
    m.add(*box((-1.53, 1.02, 1.80), (1.53, 1.12, 1.96)), DARK)
    m.add(*box((-1.53, -1.02, 1.80), (-1.43, 1.02, 1.96)), DARK)
    m.add(*box((1.43, -1.02, 1.80), (1.53, 1.02, 1.96)), DARK)

    # 六格栅 + 横撑
    for x in (-1.20, -0.72, -0.24, 0.24, 0.72, 1.20):
        m.add(*box((x - 0.03, -1.02, 1.88), (x + 0.03, 1.02, 1.92)), MET)
    for y in (-0.56, 0.56):
        m.add(*box((-1.35, y - 0.03, 1.90), (1.35, y + 0.03, 1.94)), MET)

    # 四吊耳 + 铭牌
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            cx, cy = sx * 1.40, sy * 1.05
            m.add(*box((cx - 0.07, cy - 0.07, 1.96), (cx + 0.07, cy + 0.07, 2.20)), MET)
    m.add(*box((1.53, -0.24, 0.85), (1.56, 0.24, 1.05)), BRASS)
    return m


# --------------------------------------------------------------------------- #
# 6. SN_Cargo_Large_Hold —— 大型货舱模块（4.00 × 2.80 × 2.60）
# --------------------------------------------------------------------------- #

def build_cargo_large_hold():
    m = Part()
    WOOD, DARK, MET, BRASS = "SN_Wood", "SN_Wood_Dark", "SN_Metal", "SN_Brass"

    m.add(*box((-2.00, -1.40, 0.00), (2.00, 1.40, 0.18)), DARK)
    m.add(*box((-1.92, -1.32, 0.16), (1.92, 1.32, 2.10)), WOOD)

    # 四角柱
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            cx, cy = sx * 1.86, sy * 1.26
            m.add(*box((cx - 0.07, cy - 0.07, 0.14), (cx + 0.07, cy + 0.07, 2.16)), DARK)

    # 五道侧肋（±Y）+ 三道端肋（+X）
    for sy in (-1.0, 1.0):
        ya, yb = sorted((sy * 1.32, sy * 1.40))
        for x in (-1.60, -0.80, 0.0, 0.80, 1.60):
            m.add(*box((x - 0.065, ya, 0.22), (x + 0.065, yb, 2.02)), MET)
    xa, xb = 1.92, 2.00
    for y in (-1.05, 0.0, 1.05):
        m.add(*box((xa, y - 0.065, 0.22), (xb, y + 0.065, 2.02)), MET)

    # 两道水平铁带
    for sy in (-1.0, 1.0):
        ya, yb = sorted((sy * 1.32, sy * 1.40))
        for z in (0.65, 1.35):
            m.add(*box((-1.92, ya, z), (1.92, yb, z + 0.10)), MET)

    # 尾端双开门（-X，嵌进箱体 2 cm；合页/斜撑/把手只外凸 4–6 mm）
    for y0, y1 in ((-1.30, -0.04), (0.04, 1.30)):
        m.add(*box((-2.00, y0, 0.25), (-1.90, y1, 2.00)), DARK)
        ymid = (y0 + y1) / 2.0
        m.add(*box((-2.004, ymid - 0.36, 0.80), (-1.994, ymid + 0.36, 0.88)), MET)
        m.add(*box((-2.004, ymid - 0.36, 1.40), (-1.994, ymid + 0.36, 1.48)), MET)
        m.add(*box((-2.006, ymid - 0.05, 1.06), (-1.990, ymid + 0.05, 1.22)), BRASS)
    for sy in (-1.0, 1.0):
        m.add(*box((-2.004, sy * 1.26 - 0.04, 0.30), (-1.994, sy * 1.26 + 0.04, 0.38)), BRASS)

    # 顶部围板
    m.add(*box((-1.92, -1.32, 2.10), (1.92, -1.20, 2.28)), DARK)
    m.add(*box((-1.92, 1.20, 2.10), (1.92, 1.32, 2.28)), DARK)
    m.add(*box((-1.92, -1.20, 2.10), (-1.80, 1.20, 2.28)), DARK)
    m.add(*box((1.80, -1.20, 2.10), (1.92, 1.20, 2.28)), DARK)

    # 八格栅 + 两道横撑
    for x in (-1.75, -1.25, -0.75, -0.25, 0.25, 0.75, 1.25, 1.75):
        m.add(*box((x - 0.03, -1.20, 2.20), (x + 0.03, 1.20, 2.24)), MET)
    for y in (-0.60, 0.60):
        m.add(*box((-1.65, y - 0.035, 2.22), (1.65, y + 0.035, 2.26)), MET)

    # 两侧通风口（贴在箱体侧壁、避开竖向铁肋）
    for sy in (-1.0, 1.0):
        ya, yb = sorted((sy * 1.32, sy * 1.40))
        m.add(*box((0.22, ya, 1.60), (0.62, yb, 1.90)), DARK)
        ya2, yb2 = sorted((sy * 1.322, sy * 1.405))
        m.add(*box((0.28, ya2, 1.66), (0.56, yb2, 1.84)), MET)

    # 四吊耳 + 铭牌
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            cx, cy = sx * 1.80, sy * 1.15
            m.add(*box((cx - 0.08, cy - 0.08, 2.28), (cx + 0.08, cy + 0.08, 2.60)), MET)
    m.add(*box((1.92, -0.35, 0.95), (1.95, 0.35, 1.20)), BRASS)
    return m


# --------------------------------------------------------------------------- #
# 7. SN_Nav_Spyglass —— 航海望远镜（1.35 × 0.80 × 1.75）
# --------------------------------------------------------------------------- #

def build_nav_spyglass():
    m = Part()
    BRASS, MET, DARK, WOOD = "SN_Brass", "SN_Metal", "SN_Wood_Dark", "SN_Wood"

    # 底座 + 立柱 + 环箍
    m.add(*box((-0.40, -0.40, 0.00), (0.40, 0.40, 0.10)), DARK)
    m.add(*box((-0.34, -0.34, 0.08), (0.34, 0.34, 0.14)), WOOD)
    m.add(*cyl(0.12, 1.30, 0.13, 8), BRASS)
    m.add(*cyl(1.24, 1.32, 0.15, 8), MET)

    # 叉架 + 俯仰轴
    for sy in (-1.0, 1.0):
        y = sy * 0.12
        m.add(*box((-0.05, y - 0.04, 1.28), (0.05, y + 0.04, 1.64)), MET)
    m.add(*tube_y(-0.16, 0.16, 0.04, 1.52, 6), MET)

    # 镜筒（目镜 / 物镜 / 调焦环）
    m.add(*tube_x(-0.52, 0.58, 0.11, 1.52, 8), BRASS)
    m.add(*tube_x(0.58, 0.70, 0.14, 1.52, 8), MET)
    m.add(*tube_x(0.70, 0.74, 0.15, 1.52, 8), BRASS)
    m.add(*tube_x(-0.60, -0.52, 0.06, 1.52, 8), MET)
    m.add(*tube_x(-0.64, -0.60, 0.075, 1.52, 8), BRASS)
    # 调焦手轮（嵌进镜筒）前后准星（嵌进镜筒 1 cm）
    m.add(*translate(tube_y(0.08, 0.14, 0.06, 1.52, 8), 0.18, 0.0, 0.0), BRASS)
    m.add(*box((0.50, -0.012, 1.62), (0.53, 0.012, 1.75)), MET)
    m.add(*box((-0.30, -0.012, 1.62), (-0.27, 0.012, 1.72)), MET)
    m.add(*box((-0.12, -0.14, 1.40), (0.12, -0.12, 1.48)), BRASS)
    return m


# --------------------------------------------------------------------------- #
# 8. SN_Nav_Chart_Room —— 海图室（2.80 × 2.20 × 2.60）
# --------------------------------------------------------------------------- #

def build_nav_chart_room():
    m = Part()
    WOOD, DARK, MET, BRASS, GLASS = "SN_Wood", "SN_Wood_Dark", "SN_Metal", "SN_Brass", "SN_Iron_Hull"

    # 基座 + 舱室主体
    m.add(*box((-1.40, -1.10, 0.00), (1.40, 1.10, 0.12)), DARK)
    m.add(*box((-1.30, -1.00, 0.10), (1.30, 1.00, 2.00)), WOOD)

    # 四角柱
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            cx, cy = sx * 1.25, sy * 0.95
            m.add(*box((cx - 0.06, cy - 0.06, 0.08), (cx + 0.06, cy + 0.06, 2.06)), DARK)

    # 腰线（一圈）
    for sy in (-1.0, 1.0):
        ya, yb = sorted((sy * 1.00, sy * 1.03))
        m.add(*box((-1.31, ya, 1.68), (1.31, yb, 1.78)), DARK)
    for sx in (-1.0, 1.0):
        xa, xb = sorted((sx * 1.30, sx * 1.33))
        m.add(*box((xa, -1.00, 1.68), (xb, 1.00, 1.78)), DARK)

    # 侧窗（±Y 各两扇）+ 前窗（+X 两扇）
    for sy in (-1.0, 1.0):
        for cx in (-0.55, 0.55):
            ya, yb = sorted((sy * 1.00, sy * 1.05))
            m.add(*box((cx - 0.30, ya, 1.18), (cx + 0.30, yb, 1.66)), BRASS)
            ya2, yb2 = sorted((sy * 1.03, sy * 1.07))
            m.add(*box((cx - 0.24, ya2, 1.24), (cx + 0.24, yb2, 1.60)), GLASS)
    for cy in (-0.65, 0.65):
        m.add(*box((1.30, cy - 0.26, 1.18), (1.35, cy + 0.26, 1.66)), BRASS)
        m.add(*box((1.33, cy - 0.20, 1.24), (1.37, cy + 0.20, 1.60)), GLASS)

    # 舱门 + 门框 + 把手 + 雨棚
    m.add(*box((1.30, -0.32, 0.14), (1.34, 0.32, 1.02)), DARK)
    for cy in (-0.36, 0.36):
        m.add(*box((1.30, cy - 0.04, 0.10), (1.35, cy + 0.04, 1.06)), BRASS)
    m.add(*box((1.33, -0.06, 0.62), (1.36, 0.06, 0.70)), BRASS)
    m.add(*box((1.30, -0.44, 1.06), (1.40, 0.44, 1.12)), BRASS)

    # 屋顶 + 天窗
    m.add(*box((-1.40, -1.10, 2.00), (1.40, 1.10, 2.14)), DARK)
    m.add(*box((-0.52, -0.30, 2.12), (0.52, 0.30, 2.24)), BRASS)
    m.add(*box((-0.46, -0.24, 2.22), (0.46, 0.24, 2.26)), GLASS)

    # 罗经柜（屋顶 -X）
    m.add(*translate(box((-0.10, -0.10, 2.14), (0.10, 0.10, 2.24)), -0.95, 0.0, 0.0), DARK)
    m.add(*translate(ball_shell([(2.20, 0.0), (2.24, 0.10), (2.30, 0.12), (2.34, 0.0)], 8),
                     -0.95, 0.0, 0.0), BRASS)

    # 烟囱管 + 信号桅（底端嵌进屋顶）
    m.add(*translate(cyl(2.10, 2.56, 0.075, 8), 0.90, -0.62, 0.0), MET)
    m.add(*translate(cyl(2.52, 2.60, 0.11, 8), 0.90, -0.62, 0.0), MET)
    m.add(*translate(cyl(2.10, 2.52, 0.035, 6), 0.90, 0.70, 0.0), MET)
    m.add(*translate(box((-0.18, -0.012, 2.46), (0.18, 0.012, 2.49)), 0.90, 0.70, 0.0), MET)

    # 屋顶栏杆
    posts = [(-1.32, -1.02), (1.32, -1.02), (1.32, 1.02), (-1.32, 1.02),
             (0.0, -1.02), (0.0, 1.02), (-1.32, 0.0), (1.32, 0.0)]
    for px, py in posts:
        m.add(*box((px - 0.03, py - 0.03, 2.14), (px + 0.03, py + 0.03, 2.50)), MET)
    m.add(*box((-1.35, -1.05, 2.46), (1.35, -1.02, 2.50)), MET)
    m.add(*box((-1.35, 1.02, 2.46), (1.35, 1.05, 2.50)), MET)
    m.add(*box((-1.35, -1.05, 2.46), (-1.32, 1.05, 2.50)), MET)
    m.add(*box((1.32, -1.05, 2.46), (1.35, 1.05, 2.50)), MET)
    return m


# --------------------------------------------------------------------------- #
# 9. SN_Safety_Lifeboat —— 救生艇（4.20 × 1.50 × 1.10）
# --------------------------------------------------------------------------- #

LIFE_STATIONS = [-1.90, -1.55, -1.10, -0.55, 0.0, 0.55, 1.10, 1.55, 1.90]


def life_beam(x):
    t = min(1.0, (x / 2.00) ** 2)
    return 0.75 * math.sqrt(max(0.03, 1.0 - t))


def life_section(x):
    b = life_beam(x)
    return [
        (x, -b, 0.88), (x, -0.72 * b, 0.62), (x, -0.40 * b, 0.30),
        (x, -0.18 * b, 0.14), (x, 0.18 * b, 0.14), (x, 0.40 * b, 0.30),
        (x, 0.72 * b, 0.62), (x, b, 0.88),
    ]


def build_safety_lifeboat():
    m = Part()
    WOOD, DARK, CANVAS, BRASS = "SN_Wood", "SN_Wood_Dark", "SN_Canvas", "SN_Brass"

    # 放样艇壳（封闭实体，顶面即甲板）
    sections = [life_section(x) for x in LIFE_STATIONS]
    m.add(*loft(sections), WOOD)

    # 舱内活动面（深色内底板，嵌进甲板 5 mm，让"开口艇"读得出来）
    plate_stations = [-1.75, -1.45, -1.05, -0.55, 0.0, 0.55, 1.05, 1.45, 1.75]
    plate_sections = []
    for x in plate_stations:
        h = max(0.12, life_beam(x) - 0.09)
        plate_sections.append([
            (x, -h, 0.875), (x, h, 0.875), (x, h, 0.905), (x, -h, 0.905),
        ])
    m.add(*loft(plate_sections), DARK)

    # 艏部小甲板 + 艉部储物箱（都嵌进甲板，不留缝）
    m.add(*box((1.40, -0.16, 0.87), (1.84, 0.16, 0.98)), WOOD)
    m.add(*box((-1.62, -0.38, 0.862), (-1.18, 0.38, 0.98)), DARK)

    # 龙骨 + 艏柱 + 艉柱
    m.add(*box((-1.95, -0.06, 0.00), (2.05, 0.06, 0.16)), DARK)
    m.add(*box((1.90, -0.06, 0.10), (2.10, 0.06, 0.98)), DARK)
    m.add(*box((-2.10, -0.06, 0.10), (-1.90, 0.06, 0.95)), DARK)

    # 舷缘压条（沿站距分段的斜六面体）
    for sy in (-1.0, 1.0):
        for k in range(len(LIFE_STATIONS) - 1):
            x0, x1 = LIFE_STATIONS[k], LIFE_STATIONS[k + 1]
            # 首尾段各缩进 4 mm，避免端面与艇壳端盖共面
            if k == 0:
                x0 += 0.004
            if k == len(LIFE_STATIONS) - 2:
                x1 -= 0.004
            b0, b1 = life_beam(x0), life_beam(x1)
            yin0, yout0 = sorted((sy * (b0 - 0.06), sy * b0))
            yin1, yout1 = sorted((sy * (b1 - 0.06), sy * b1))
            bottom = [(x0, yin0, 0.84), (x1, yin1, 0.84), (x1, yout1, 0.84), (x0, yout0, 0.84)]
            top = [(x0, yin0, 0.92), (x1, yin1, 0.92), (x1, yout1, 0.92), (x0, yout0, 0.92)]
            m.add(*hexa(bottom, top), DARK)

    # 三道坐板
    for x in (-1.25, -0.15, 0.95):
        b = life_beam(x)
        m.add(*box((x - 0.09, -b + 0.02, 0.86), (x + 0.09, b - 0.02, 0.94)), WOOD)

    # 双桨 + 桨架 + 桨叶（同木质，桨叶加大到能读出"桨"）
    for sy in (-1.0, 1.0):
        m.add(*translate(tube_x(-1.55, 1.05, 0.04, 1.02, 6), 0.0, sy * 0.42, 0.0), WOOD)
        for rx in (-0.90, 0.40):
            m.add(*box((rx - 0.05, sy * 0.42 - 0.05, 0.86), (rx + 0.05, sy * 0.42 + 0.05, 0.985)), DARK)
        m.add(*box((1.02, sy * 0.42 - 0.12, 0.985), (1.52, sy * 0.42 + 0.12, 1.055)), WOOD)

    # 缆绳盘（低矮圆盘）
    m.add(*translate(cyl(0.90, 0.99, 0.16, 8), 0.50, 0.34, 0.0), CANVAS)

    # 艏艉吊环
    for sx in (-1.0, 1.0):
        cx = 1.90 if sx > 0 else -1.90
        m.add(*box((cx - 0.06, -0.10, 0.92), (cx + 0.06, 0.10, 1.10)), BRASS)
    return m


# --------------------------------------------------------------------------- #
# 10. SN_Safety_Valve —— 安全阀组（1.50 × 1.30 × 1.85）
# --------------------------------------------------------------------------- #

def build_safety_valve():
    m = Part()
    MET, IRON, BRASS = "SN_Metal", "SN_Iron_Hull", "SN_Brass"

    # 底法兰 + 立管
    m.add(*cyl(0.00, 0.10, 0.55, 8), MET)
    m.add(*cyl(0.08, 1.02, 0.15, 8), MET)

    # 阀体 + 两端法兰
    m.add(*tube_x(-0.30, 0.30, 0.24, 1.05, 8), MET)
    m.add(*tube_x(-0.38, -0.30, 0.28, 1.05, 8), IRON)
    m.add(*tube_x(0.30, 0.38, 0.28, 1.05, 8), IRON)

    # 阀盖 / 填料函 / 阀杆
    m.add(*cyl(1.05, 1.20, 0.20, 8), BRASS)
    m.add(*cyl(1.18, 1.28, 0.13, 8), BRASS)
    m.add(*cyl(1.26, 1.80, 0.035, 6), MET)

    # 手轮
    m.add(*cyl(1.78, 1.82, 0.20, 8), MET)
    m.add(*cyl(1.76, 1.84, 0.05, 6), BRASS)

    # 杠杆重锤（斜梁 + 悬挂重块）
    m.add(*hexa([(0.05, -0.04, 1.18), (0.95, -0.04, 1.32), (0.95, 0.04, 1.32), (0.05, 0.04, 1.18)],
                [(0.05, -0.04, 1.26), (0.95, -0.04, 1.40), (0.95, 0.04, 1.40), (0.05, 0.04, 1.26)]), MET)
    m.add(*box((0.88, -0.09, 0.98), (0.98, 0.09, 1.34)), IRON)

    # 出口管（-Y 侧转向落地）
    m.add(*tube_y(-0.24, -0.60, 0.12, 1.05, 8), MET)
    m.add(*translate(cyl(0.10, 1.05, 0.12, 8), 0.0, -0.60, 0.0), MET)
    m.add(*translate(cyl(0.00, 0.10, 0.16, 8), 0.0, -0.60, 0.0), MET)

    # 压力表（+X 端）
    m.add(*disc_axis(0.16, 0.36, 0.44, 0.10, 1.05, "x", 8), MET)
    m.add(*disc_axis(0.16, 0.44, 0.46, 0.11, 1.05, "x", 8), BRASS)
    return m


# --------------------------------------------------------------------------- #
# 11. SN_Cabin_Passenger —— 客舱模块（3.40 × 2.40 × 2.60）
# --------------------------------------------------------------------------- #

def build_cabin_passenger():
    m = Part()
    WOOD, DARK, MET, BRASS, GLASS = "SN_Wood", "SN_Wood_Dark", "SN_Metal", "SN_Brass", "SN_Iron_Hull"
    DECK = "SN_Wood_Deck"

    # 甲板基座 + 舱室主体
    m.add(*box((-1.70, -1.20, 0.00), (1.70, 1.20, 0.14)), DECK)
    m.add(*box((-1.58, -1.06, 0.12), (1.58, 1.06, 1.98)), WOOD)

    # 四角柱（外凸 5 mm，避免外表面与舱室外壁共面）
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            cx, cy = sx * 1.52, sy * 1.00
            m.add(*box((cx - 0.065, cy - 0.065, 0.10), (cx + 0.065, cy + 0.065, 2.04)), DARK)

    # 上下两道腰线
    for z0, z1 in ((0.96, 1.04), (1.86, 1.94)):
        for sy in (-1.0, 1.0):
            ya, yb = sorted((sy * 1.06, sy * 1.09))
            m.add(*box((-1.60, ya, z0), (1.60, yb, z1)), DARK)
        for sx in (-1.0, 1.0):
            xa, xb = sorted((sx * 1.58, sx * 1.61))
            m.add(*box((xa, -1.08, z0), (xb, 1.08, z1)), DARK)

    # 侧窗（±Y 各三扇）+ 前窗（+X 两扇）
    for sy in (-1.0, 1.0):
        for cx in (-1.00, 0.0, 1.00):
            ya, yb = sorted((sy * 1.06, sy * 1.11))
            m.add(*box((cx - 0.26, ya, 1.22), (cx + 0.26, yb, 1.64)), BRASS)
            ya2, yb2 = sorted((sy * 1.09, sy * 1.13))
            m.add(*box((cx - 0.21, ya2, 1.27), (cx + 0.21, yb2, 1.59)), GLASS)
    for cy in (-0.66, 0.66):
        m.add(*box((1.58, cy - 0.24, 1.22), (1.63, cy + 0.24, 1.64)), BRASS)
        m.add(*box((1.61, cy - 0.19, 1.27), (1.65, cy + 0.19, 1.59)), GLASS)

    # 舱门 + 门框 + 把手 + 雨棚
    m.add(*box((1.58, -0.34, 0.14), (1.62, 0.34, 1.60)), DARK)
    for cy in (-0.38, 0.38):
        m.add(*box((1.58, cy - 0.04, 0.10), (1.63, cy + 0.04, 1.64)), BRASS)
    m.add(*box((1.62, -0.10, 0.70), (1.65, -0.02, 0.78)), BRASS)
    m.add(*box((1.62, -0.46, 1.60), (1.70, 0.46, 1.68)), DARK)

    # 屋顶 + 天窗
    m.add(*box((-1.70, -1.20, 1.98), (1.70, 1.20, 2.12)), DARK)
    m.add(*box((-0.55, -0.32, 2.10), (0.55, 0.32, 2.22)), BRASS)
    m.add(*box((-0.48, -0.26, 2.20), (0.48, 0.26, 2.24)), GLASS)

    # 双通风筒（底端嵌进屋顶）
    for cx in (-1.30, 1.30):
        m.add(*box((cx - 0.10, -0.10, 2.09), (cx + 0.10, 0.10, 2.20)), MET)
        m.add(*translate(revolved([(2.18, 0.12), (2.38, 0.09)], 8), cx, 0.0, 0.0), MET)
        m.add(*translate(cyl(2.34, 2.392, 0.13, 8), cx, 0.0, 0.0), BRASS)

    # 屋顶栏杆（10 根立柱 + 四边扶手）
    posts = [(-1.62, -1.12), (-0.55, -1.12), (0.55, -1.12), (1.62, -1.12),
             (-1.62, 1.12), (-0.55, 1.12), (0.55, 1.12), (1.62, 1.12),
             (-1.62, 0.0), (1.62, 0.0)]
    for px, py in posts:
        m.add(*box((px - 0.03, py - 0.03, 2.12), (px + 0.03, py + 0.03, 2.50)), MET)
    m.add(*box((-1.65, -1.15, 2.46), (1.65, -1.12, 2.50)), MET)
    m.add(*box((-1.65, 1.12, 2.46), (1.65, 1.15, 2.50)), MET)
    m.add(*box((-1.65, -1.15, 2.46), (-1.62, 1.15, 2.50)), MET)
    m.add(*box((1.62, -1.15, 2.46), (1.65, 1.15, 2.50)), MET)

    # 信号桅（屋顶 -X 角，底端嵌进屋顶）
    m.add(*translate(cyl(2.08, 2.54, 0.03, 6), -1.55, -1.05, 0.0), MET)
    m.add(*translate(box((-0.10, -0.01, 2.52), (0.10, 0.01, 2.55)), -1.55, -1.05, 0.0), BRASS)
    return m


BUILDERS = {
    "SN_Boiler_Efficient": build_boiler_efficient,
    "SN_Boiler_Standard": build_boiler_standard,
    "SN_Boiler_Performance": build_boiler_performance,
    "SN_Cargo_Small_Hold": build_cargo_small_hold,
    "SN_Cargo_Medium_Hold": build_cargo_medium_hold,
    "SN_Cargo_Large_Hold": build_cargo_large_hold,
    "SN_Nav_Spyglass": build_nav_spyglass,
    "SN_Nav_Chart_Room": build_nav_chart_room,
    "SN_Safety_Lifeboat": build_safety_lifeboat,
    "SN_Safety_Valve": build_safety_valve,
    "SN_Cabin_Passenger": build_cabin_passenger,
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

    coll = bpy.data.collections.get(COLLECTION)
    if coll is None:
        coll = bpy.data.collections.new(COLLECTION)
        bpy.context.scene.collection.children.link(coll)

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
        "modules_collection": sorted(o.name for o in bpy.data.collections[COLLECTION].objects),
        "mesh_datablocks": len(bpy.data.meshes),
    }
    print("SHIP_MODULES_REPORT " + repr(out))
    return out


if __name__ == "__main__":
    build_all()
    report()
