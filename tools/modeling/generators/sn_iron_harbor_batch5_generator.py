# -*- coding: utf-8 -*-
"""Steam Navigator — 铁港第五批 7 件道具参数化生成脚本。

工单：tools/modeling/briefs/sn_iron_harbor_batch5.json
集合：SN_IronHarbor_Props（已有 24 件，本脚本只追加/重建本批 7 件）
布局：y=48 一排，x = -12, -7, -2, 3, 8, 13, 18
轴心：底面中心（object.location = 布局位置，几何全部为局部坐标，底面 z=0）
预算：合计 <= 2100 tri；单件见 ITEMS 表（验收上限 1.5×）
材质：只用既有调色板（本批不新增）

设计要点
--------
- 全部几何由本文件顶部的参数表生成，改数值即可重建；禁止手工摆点。
- 每个 item 是**一个 mesh 对象**（多材质槽），原点在底面中心。
- 环与环共享顶点（焊接）；每个壳体闭合，边界边/非流形边应为 0。
  （煤溜槽的漏斗做成"薄壁漏斗"——外壳+内壳+顶沿，看得见开口但仍是闭合壳）
- 互相穿插的部件之间错开 3–20 mm，避免共面 z-fighting。
- 几何函数为纯 Python（不 import bpy），可用 dryrun_props.py 离线校验。
- 本文件自带几何工具函数（与前几批重复但各自独立），保持单文件可执行。

用法
----
Blender 内：import runpy; runpy.run_path(<本文件>, run_name="__main__")
纯 Python 干跑：python tools/modeling/generators/dryrun_props.py tools/modeling/generators/sn_iron_harbor_batch5_generator.py
"""

import math

COLLECTION = "SN_IronHarbor_Props"

ITEMS = [
    ("SN_Dock_Stairs", (-12.0, 48.0, 0.0), 300, (3.00, 2.00, 3.00)),
    ("SN_Port_Sign", (-7.0, 48.0, 0.0), 150, (2.00, 0.25, 1.60)),
    ("SN_Bell", (-2.0, 48.0, 0.0), 200, (0.60, 0.60, 0.90)),
    ("SN_Flag_Pole", (3.0, 48.0, 0.0), 200, (1.40, 0.30, 6.00)),
    ("SN_Coal_Chute", (8.0, 48.0, 0.0), 400, (2.50, 1.50, 1.50)),
    ("SN_Boiler_Unit", (13.0, 48.0, 0.0), 700, (3.00, 2.00, 2.50)),
    ("SN_Keel_Block", (18.0, 48.0, 0.0), 160, (1.20, 0.80, 0.60)),
]

TOTAL_BUDGET = 2100

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
        faces.append((o + k, o + n, i0 + n, i0 + k))       # 顶沿
        faces.append((i0 + k, i0 + n, i1 + n, i1 + k))     # 内壳
        faces.append((i1 + k, i1 + n, bo + n, bo + k))     # 底沿
        faces.append((bo + k, bo + n, o + n, o + k))       # 外壳
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
        faces.append((k, n, 4 + n, 4 + k))                 # 内壁
        faces.append((8 + k, 12 + k, 12 + n, 8 + n))       # 外壁
        faces.append((4 + k, 4 + n, 12 + n, 12 + k))       # 上口
        faces.append((k, 8 + k, 8 + n, n))                 # 下口
    return verts, faces


# --------------------------------------------------------------------------- #
# 1. SN_Dock_Stairs —— 码头石阶（3.0 × 2.0 × 3.0）
# --------------------------------------------------------------------------- #

def build_dock_stairs():
    m = Part()
    STONE, WOOD = "SN_Stone", "SN_Wood"

    steps, rise, tread = 6, 0.450, 2.0 / 6.0
    for i in range(steps):
        z0 = i * rise
        ya = -1.0 + i * tread
        m.add(*box((-1.500, ya, z0), (1.500, 1.000, z0 + rise)), STONE)

    # 两侧矮挡墙（沿 Y 倾斜的六面体）
    for sx in (-1.0, 1.0):
        xa, xb = sorted((sx * 1.300, sx * 1.500))
        bottom = [(xa, -1.0, 0.000), (xb, -1.0, 0.000), (xb, 1.0, 0.000), (xa, 1.0, 0.000)]
        top = [(xa, -1.0, 0.900), (xb, -1.0, 0.900), (xb, 1.0, 2.920), (xa, 1.0, 2.920)]
        m.add(*hexa(bottom, top), STONE)

    # 木扶手（压在两挡墙顶，底面内缩 20 mm 避免共面）
    for sx in (-1.0, 1.0):
        xa, xb = sorted((sx * 1.310, sx * 1.490))
        bottom = [(xa, -1.0, 0.880), (xb, -1.0, 0.880), (xb, 1.0, 2.900), (xa, 1.0, 2.900)]
        top = [(xa, -1.0, 0.980), (xb, -1.0, 0.980), (xb, 1.0, 3.000), (xa, 1.0, 3.000)]
        m.add(*hexa(bottom, top), WOOD)
    return m


# --------------------------------------------------------------------------- #
# 2. SN_Port_Sign —— 港口牌（2.0 × 0.25 × 1.6）
# --------------------------------------------------------------------------- #

def build_port_sign():
    m = Part()
    WOOD, MET = "SN_Wood", "SN_Metal"

    for sx in (-1.0, 1.0):
        cx = sx * 0.900
        m.add(*box((cx - 0.070, -0.070, 0.000), (cx + 0.070, 0.070, 1.520)), WOOD)
        m.add(*box((cx - 0.080, -0.125, 0.000), (cx + 0.080, 0.125, 0.100)), MET)
        base = [(cx - 0.100, -0.100, 1.500), (cx + 0.100, -0.100, 1.500),
                (cx + 0.100, 0.100, 1.500), (cx - 0.100, 0.100, 1.500)]
        m.add(*closed_mound([base], (cx, 0.0, 1.600)), MET)

    # 横牌
    m.add(*box((-1.000, -0.040, 0.850), (1.000, 0.040, 1.400)), WOOD)
    # 铁边框（上下两条 + 左右两条，略厚于牌面形成凸边）
    m.add(*box((-1.020, -0.052, 1.380), (1.020, 0.052, 1.430)), MET)
    m.add(*box((-1.020, -0.052, 0.820), (1.020, 0.052, 0.870)), MET)
    for sx in (-1.0, 1.0):
        xa, xb = sorted((sx * 0.970, sx * 1.020))
        m.add(*box((xa, -0.052, 0.820), (xb, 0.052, 1.430)), MET)
    return m


# --------------------------------------------------------------------------- #
# 3. SN_Bell —— 港口钟（0.6 × 0.6 × 0.9）
# --------------------------------------------------------------------------- #

def build_bell():
    m = Part()
    MET = "SN_Metal"

    # 支架：两根立柱 + 顶横梁 + 两个底座
    for sx in (-1.0, 1.0):
        cx = sx * 0.260
        m.add(*box((cx - 0.035, -0.035, 0.000), (cx + 0.035, 0.035, 0.880)), MET)
        m.add(*box((cx - 0.080, -0.090, 0.000), (cx + 0.080, 0.090, 0.070)), MET)
    m.add(*box((-0.290, -0.035, 0.820), (0.290, 0.035, 0.880)), MET)

    # 钟体（八边回转，开口朝下）
    m.add(*revolved([(0.300, 0.290), (0.330, 0.270), (0.560, 0.170),
                     (0.720, 0.105), (0.800, 0.060)], 8), MET)
    # 钟锤（锤杆 + 锤头）
    m.add(*revolved([(0.700, 0.022), (0.430, 0.022)], 6), MET)
    m.add(*revolved([(0.300, 0.070), (0.420, 0.070)], 6), MET)
    return m


# --------------------------------------------------------------------------- #
# 4. SN_Flag_Pole —— 旗杆 + 旗（1.4 × 0.3 × 6.0）
# --------------------------------------------------------------------------- #

def build_flag_pole():
    m = Part()
    WOOD, CAN = "SN_Wood", "SN_Canvas"

    # 底座
    m.add(*revolved([(0.000, 0.140), (0.120, 0.120)], 8), WOOD)
    # 细杆
    m.add(*revolved([(0.100, 0.050), (5.880, 0.038)], 8), WOOD)
    # 顶部球
    m.add(*ball_shell([(5.860, 0.0), (5.900, 0.065), (5.960, 0.065), (6.000, 0.0)], 6), WOOD)

    # 低模旗：4 段 × 2 行波浪面 + 14 mm 厚度，做成闭合薄板（不是开放单层）
    m.add(*_flag_slab(5.780, 5.120, 0.045, 1.250, 0.115, 4, 0.014), CAN)
    return m


def _flag_slab(z_top, z_bot, x0, span, amp, seg, thickness):
    """波浪旗面：前后两张网格 + 四周边缘，闭合成薄板。"""
    rows = []
    for z, k in ((z_top, 0.85), (z_bot, 1.0)):
        row = []
        for i in range(seg + 1):
            t = i / seg
            row.append((x0 + span * t, amp * math.sin(t * math.pi * 1.5) * k, z))
        rows.append(row)
    mcols = seg + 1
    verts = []
    for row in rows:
        for x, y, z in row:
            verts.append((x, y - thickness / 2.0, z))
    for row in rows:
        for x, y, z in row:
            verts.append((x, y + thickness / 2.0, z))
    faces = []
    off = 2 * mcols
    for i in range(seg):                                   # 正面
        faces.append((i, i + 1, mcols + i + 1, mcols + i))
    for i in range(seg):                                   # 背面
        faces.append((off + mcols + i, off + mcols + i + 1, off + i + 1, off + i))
    for i in range(seg):                                   # 上缘 / 下缘
        faces.append((i, off + i, off + i + 1, i + 1))
        faces.append((mcols + i + 1, off + mcols + i + 1, off + mcols + i, mcols + i))
    faces.append((0, mcols, off + mcols, off))                              # 左缘
    faces.append((off + seg, off + mcols + seg, mcols + seg, seg))          # 右缘
    return verts, faces


# --------------------------------------------------------------------------- #
# 5. SN_Coal_Chute —— 煤溜槽（2.5 × 1.5 × 1.5）
# --------------------------------------------------------------------------- #

def build_coal_chute():
    m = Part()
    MET, DARK = "SN_Metal", "SN_Wood_Dark"

    # 薄壁方口漏斗：顶口 1.5×1.5 @ z=1.5，喉口 0.5×0.5 @ z=1.0
    m.add(*funnel_rect(0.750, 0.250, 1.500, 1.000, 0.045), MET)

    # 斜槽：从喉口斜到地面（低端落在 z=0，不留悬空）
    bottom = rect_pts(1.300, 1.750, -0.200, 0.200, 0.000)
    top = rect_pts(-0.210, 0.270, -0.200, 0.200, 1.020)
    m.add(*hexa(bottom, top), MET)

    # 4 条斜撑：落地后斜插进漏斗外壁（z=1.30 处漏斗半宽 0.55）
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            bx = sorted((sx * 0.560, sx * 0.640))
            by = sorted((sy * 0.560, sy * 0.640))
            tx = sorted((sx * 0.480, sx * 0.560))
            ty = sorted((sy * 0.480, sy * 0.560))
            m.add(*hexa(rect_pts(bx[0], bx[1], by[0], by[1], 0.000),
                        rect_pts(tx[0], tx[1], ty[0], ty[1], 1.300)), MET)

    # 两根横撑（连接前后斜撑）
    for sy in (-1.0, 1.0):
        ya, yb = sorted((sy * 0.552, sy * 0.628))
        m.add(*box((-0.628, ya, 0.540), (0.628, yb, 0.620)), DARK)
    # 喉口木托环（套在喉口外部）
    m.add(*box((-0.350, -0.350, 0.960), (0.350, 0.350, 1.040)), DARK)
    return m


# --------------------------------------------------------------------------- #
# 6. SN_Boiler_Unit —— 小型锅炉机组（3.0 × 2.0 × 2.5）
# --------------------------------------------------------------------------- #

def build_boiler_unit():
    m = Part()
    MET, WOOD = "SN_Metal", "SN_Wood"

    # 底座
    m.add(*box((-1.500, -1.000, 0.000), (1.500, 1.000, 0.250)), WOOD)
    # 两个鞍座
    for sx in (-1.0, 1.0):
        cx = sx * 0.780
        m.add(*box((cx - 0.110, -0.760, 0.220), (cx + 0.110, 0.760, 0.560)), MET)
    # 卧式锅炉（十边形圆柱）
    m.add(*tube_axis([(-1.250, 0.750), (1.250, 0.750)], 10, 1.000, "x"), MET)
    # 两端端盖
    for sx in (-1.0, 1.0):
        xa, xb = sorted((sx * 1.240, sx * 1.320))
        m.add(*tube_axis([(xa, 0.820), (xb, 0.820)], 10, 1.000, "x"), MET)
    # 三道加强箍
    for x in (-0.720, 0.000, 0.720):
        m.add(*tube_axis([(x - 0.045, 0.782), (x + 0.045, 0.782)], 10, 1.000, "x"), MET)
    # 烟囱（锥台 + 顶沿）
    m.add(*revolved([(1.560, 0.300), (2.400, 0.240)], 10), MET)
    m.add(*revolved([(2.380, 0.300), (2.500, 0.300)], 10), MET)
    # 两个阀门（立在锅炉顶的阀杆 + 手轮横杆）
    for sx in (-1.0, 1.0):
        cx = sx * 0.420
        stem = revolved([(1.720, 0.045), (1.860, 0.045)], 6)
        m.add(*translate(stem, cx, 0.0, 0.0), MET)
        m.add(*box((cx - 0.120, -0.030, 1.840), (cx + 0.120, 0.030, 1.880)), MET)
    # 压力表（装在 -X 端盖上，轴向沿 X）+ 炉门
    m.add(*disc_axis(0.000, -1.345, -1.300, 0.150, 1.260, "x", 8), MET)
    m.add(*box((0.560, -0.760, 0.340), (0.920, -0.740, 0.700)), MET)
    # 底座螺栓
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            cx, cy = sx * 1.320, sy * 0.860
            m.add(*box((cx - 0.055, cy - 0.055, 0.240), (cx + 0.055, cy + 0.055, 0.300)), MET)
    return m


# --------------------------------------------------------------------------- #
# 7. SN_Keel_Block —— 船台龙骨墩（1.2 × 0.8 × 0.6）
# --------------------------------------------------------------------------- #

def build_keel_block():
    m = Part()
    DARK, MET = "SN_Wood_Dark", "SN_Metal"

    # 梯形木墩（下 1.2×0.8，上 0.8×0.6，高 0.42）
    m.add(*hexa(
        [(-0.600, -0.400, 0.000), (0.600, -0.400, 0.000),
         (0.600, 0.400, 0.000), (-0.600, 0.400, 0.000)],
        [(-0.400, -0.300, 0.420), (0.400, -0.300, 0.420),
         (0.400, 0.300, 0.420), (-0.400, 0.300, 0.420)],
    ), DARK)

    # 顶部弧形托座：沿 Y 拉伸的 U 形截面（缺口朝上）
    poly = [(-0.400, 0.400), (-0.400, 0.600), (-0.220, 0.500),
            (0.220, 0.500), (0.400, 0.600), (0.400, 0.400)]
    n = len(poly)
    y0, y1 = -0.300, 0.300
    verts = [(x, y0, z) for x, z in poly] + [(x, y1, z) for x, z in poly]
    faces = []
    for i in range(1, n - 1):
        faces.append((0, i, i + 1))
        faces.append((n, n + i + 1, n + i))
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    m.add(verts, faces, DARK)

    # 两道铁箍：内壁贴合锥面（不再悬空），外壁外扩 20 mm
    # 墩身半宽随高度线性收缩：ax(z)=0.6-0.4762z，ay(z)=0.4-0.2381z
    def half_at(z):
        return (0.600 - (0.200 / 0.420) * z, 0.400 - (0.100 / 0.420) * z)

    for z0, z1 in ((0.060, 0.140), (0.280, 0.360)):
        m.add(*taper_band(z0, z1, half_at(z0), half_at(z1), 0.020), MET)
    return m


BUILDERS = {
    "SN_Dock_Stairs": build_dock_stairs,
    "SN_Port_Sign": build_port_sign,
    "SN_Bell": build_bell,
    "SN_Flag_Pole": build_flag_pole,
    "SN_Coal_Chute": build_coal_chute,
    "SN_Boiler_Unit": build_boiler_unit,
    "SN_Keel_Block": build_keel_block,
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
    print("BATCH5_REPORT " + repr(out))
    return out


if __name__ == "__main__":
    build_all()
    report()
