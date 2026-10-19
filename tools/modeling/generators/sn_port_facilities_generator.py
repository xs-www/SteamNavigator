# -*- coding: utf-8 -*-
"""Steam Navigator — 港口设施锚点第一批 6 件参数化生成脚本。

工单：tools/modeling/briefs/sn_port_facilities_batch1.json
规划：tools/modeling/briefs/PORT_FACILITIES_PLAN.md
集合：SN_Port_Facilities（本脚本负责新建；重跑只重建本批 6 件）
布局：沿 y=60 一字排开，x = 10, 18, 26, 36, -8, -30
轴心：底面中心（object.location = 布局位置，几何全部为局部坐标，底面 z=0）
预算：合计 <= 10500 tri；单件 tri_budget 见 ITEMS（验收上限 1.2×）
材质：调色板 SN_Wood / SN_Wood_Dark / SN_Wood_Deck / SN_Metal / SN_Iron /
      SN_Brass / SN_Stone / SN_Canvas / SN_Canvas_Shade；SN_Iron 为本批新增（见 NEW_MATERIALS）

设计要点
--------
- 全部几何由本文件顶部的参数表与各 build_* 函数生成，改数值即可重建；禁止手工摆点。
- 每件是**一个 mesh 对象**（多材质槽），原点在底面中心。
- 壳体全部闭合（边界边/非流形边为 0）：薄板一律做成"上下两层面 + 四周边缘"的闭合
  slab（见 grid_slab / box / rod），单层帆布与纸张不靠双面材质兜底。
- 互相接触的部件之间留 2–20 mm 缝或有意嵌入 5–10 mm，避免共面 z-fighting。
- 几何函数为纯 Python（不 import bpy），可用 dryrun_props.py 离线校验。
- 招牌/纸张上没有文字，文字由 2D UI 标签层负责。

用法
----
Blender 内：import runpy; runpy.run_path(<本文件>, run_name="__main__")
纯 Python 干跑：python tools/modeling/generators/dryrun_props.py tools/modeling/generators/sn_port_facilities_generator.py
"""

import math

COLLECTION = "SN_Port_Facilities"

# (对象名, 布局位置, tri 预算, 目标包围盒 L×W×H)
ITEMS = [
    ("SN_Market_Stall", (10.0, 60.0, 0.0), 1800, (5.0, 3.0, 3.2)),
    ("SN_Notice_Board", (18.0, 60.0, 0.0), 500, (2.8, 0.5, 2.6)),
    ("SN_Water_Tank", (26.0, 60.0, 0.0), 1400, (4.0, 4.0, 5.2)),
    ("SN_Signal_Tower", (36.0, 60.0, 0.0), 1600, (3.2, 2.4, 8.5)),
    ("SN_Shipyard_Gantry", (-8.0, 60.0, 0.0), 2600, (14.0, 4.0, 10.0)),
    ("SN_Dry_Dock", (-30.0, 60.0, 0.0), 2200, (18.0, 8.0, 2.6)),
]

TOTAL_BUDGET = 10500

# 调色板（工单 acceptance 白名单）
PALETTE = {
    "SN_Wood", "SN_Wood_Dark", "SN_Wood_Deck", "SN_Metal", "SN_Iron",
    "SN_Brass", "SN_Stone", "SN_Canvas", "SN_Canvas_Shade",
}

# 本批唯一新增材质：氧化铁（比 SN_Metal 更暗、金属度更低，和 SN_Iron_Hull 区分）
NEW_MATERIALS = {
    "SN_Iron": {"base": (0.072, 0.076, 0.084), "roughness": 0.52, "metallic": 0.62},
}

WOOD = "SN_Wood"
DARK = "SN_Wood_Dark"
DECK = "SN_Wood_Deck"
METAL = "SN_Metal"
IRON = "SN_Iron"
BRASS = "SN_Brass"
STONE = "SN_Stone"
CANVAS = "SN_Canvas"
CANVAS_SHADE = "SN_Canvas_Shade"


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

    def append(self, other):
        offset = len(self.verts)
        self.verts.extend(other.verts)
        for face, material in other.faces:
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


def rect_pts(x0, x1, y0, y1, z):
    return [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)]


def box(lo, hi):
    x0, y0, z0 = lo
    x1, y1, z1 = hi
    return hexa(rect_pts(x0, x1, y0, y1, z0), rect_pts(x0, x1, y0, y1, z1))


def hexa(bottom, top):
    """8 顶点六面体：bottom / top 各 4 点，顺序一致。"""
    verts = list(bottom) + list(top)
    faces = [
        (0, 3, 2, 1), (4, 5, 6, 7),
        (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7),
    ]
    return verts, faces


def translate(vf, dx, dy, dz):
    verts, faces = vf
    return [(x + dx, y + dy, z + dz) for x, y, z in verts], faces


def rot_y(vf, angle, cx=0.0, cz=0.0):
    c, s = math.cos(angle), math.sin(angle)
    verts, faces = vf
    out = []
    for x, y, z in verts:
        dx, dz = x - cx, z - cz
        out.append((cx + dx * c + dz * s, y, cz - dx * s + dz * c))
    return out, faces


def _basis(p0, p1):
    dx, dy, dz = (p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2])
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    d = (dx / length, dy / length, dz / length)
    ref = (0.0, 0.0, 1.0) if abs(d[2]) < 0.9 else (1.0, 0.0, 0.0)
    u = (d[1] * ref[2] - d[2] * ref[1],
         d[2] * ref[0] - d[0] * ref[2],
         d[0] * ref[1] - d[1] * ref[0])
    ul = math.sqrt(u[0] ** 2 + u[1] ** 2 + u[2] ** 2)
    u = (u[0] / ul, u[1] / ul, u[2] / ul)
    v = (d[1] * u[2] - d[2] * u[1],
         d[2] * u[0] - d[0] * u[2],
         d[0] * u[1] - d[1] * u[0])
    return u, v


def sweep(p0, p1, section):
    """把 2D 闭合截面沿 p0→p1 拉伸成闭合壳体（首尾封盖）。"""
    u, v = _basis(p0, p1)
    verts = []
    for p in (p0, p1):
        for a, b in section:
            verts.append((p[0] + a * u[0] + b * v[0],
                          p[1] + a * u[1] + b * v[1],
                          p[2] + a * u[2] + b * v[2]))
    n = len(section)
    faces = []
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    for i in range(1, n - 1):
        faces.append((0, i + 1, i))
        faces.append((n, n + i, n + i + 1))
    return verts, faces


def beam(p0, p1, w, h=None):
    h = w if h is None else h
    return sweep(p0, p1, [(-w / 2, -h / 2), (w / 2, -h / 2),
                          (w / 2, h / 2), (-w / 2, h / 2)])


def rod(p0, p1, r, sides=6):
    section = [(r * math.cos(2.0 * math.pi * i / sides + math.pi / sides),
                r * math.sin(2.0 * math.pi * i / sides + math.pi / sides))
               for i in range(sides)]
    return sweep(p0, p1, section)


def revolved(profile, sides, phase=None):
    """[(z, r), ...] 绕 Z 轴回转；首尾环封盖（r 不得为 0）。"""
    if phase is None:
        phase = 0.0
    verts = []
    for z, r in profile:
        verts.extend(ring(sides, r, r, z, phase=phase))
    faces = []
    for k in range(len(profile) - 1):
        base, nxt = k * sides, (k + 1) * sides
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((base + i, base + j, nxt + j, nxt + i))
    last = (len(profile) - 1) * sides
    for i in range(1, sides - 1):
        faces.append((0, i + 1, i))
        faces.append((last, last + i, last + i + 1))
    return verts, faces


def band_ring(z0, z1, r_in, r_out, sides, phase=0.0):
    """闭口圆环带（外壁 / 上环面 / 内壁 / 下环面），用来做铁箍、法兰、手轮。"""
    rings = [ring(sides, r_out, r_out, z0, phase=phase),
             ring(sides, r_out, r_out, z1, phase=phase),
             ring(sides, r_in, r_in, z1, phase=phase),
             ring(sides, r_in, r_in, z0, phase=phase)]
    verts = [p for pts in rings for p in pts]
    faces = []
    for k in range(4):
        a = k * sides
        b = ((k + 1) % 4) * sides
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((a + i, a + j, b + j, b + i))
    return verts, faces


def grid_slab(fn, nu, nv, thickness):
    """参数曲面 (u,v)->(x,y,z) 的闭合薄板：上表面 + 下表面 + 四周边缘。"""
    top = [[fn(i / float(nu), j / float(nv)) for j in range(nv + 1)]
           for i in range(nu + 1)]
    cols = nv + 1
    verts = []
    for i in range(nu + 1):
        for j in range(nv + 1):
            x, y, z = top[i][j]
            verts.append((x, y, z))
    off = len(verts)
    for i in range(nu + 1):
        for j in range(nv + 1):
            x, y, z = top[i][j]
            verts.append((x, y, z - thickness))

    def ti(i, j):
        return i * cols + j

    faces = []
    for i in range(nu):
        for j in range(nv):
            a, b, c, d = ti(i, j), ti(i + 1, j), ti(i + 1, j + 1), ti(i, j + 1)
            faces.append((a, b, c, d))
            faces.append((off + d, off + c, off + b, off + a))
    for j in range(nv):
        faces.append((ti(0, j), ti(0, j + 1), off + ti(0, j + 1), off + ti(0, j)))
        faces.append((ti(nu, j), off + ti(nu, j), off + ti(nu, j + 1), ti(nu, j + 1)))
    for i in range(nu):
        faces.append((ti(i, 0), off + ti(i, 0), off + ti(i + 1, 0), ti(i + 1, 0)))
        faces.append((ti(i, nv), ti(i + 1, nv), off + ti(i + 1, nv), off + ti(i, nv)))
    return verts, faces


# --------------------------------------------------------------------------- #
# 共用小部件
# --------------------------------------------------------------------------- #

def add_crate(m, cx, cy, size):
    """木箱：箱体 + 4 根角柱 + 2 根横条（比箱面凸 15 mm，避开共面）。"""
    half = size / 2.0
    m.add(*box((cx - half, cy - half, 0.0), (cx + half, cy + half, size)), WOOD)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            x = cx + sx * (half - 0.02)
            y = cy + sy * (half - 0.02)
            m.add(*box((x - 0.030, y - 0.030, 0.05),
                       (x + 0.030, y + 0.030, size - 0.05)), DARK)
    for sy in (-1.0, 1.0):
        y = cy + sy * (half + 0.015)
        m.add(*box((cx - half + 0.06, y - 0.015, size * 0.5 - 0.035),
                   (cx + half - 0.06, y + 0.015, size * 0.5 + 0.035)), DARK)


def add_lantern(m, cx, cy, z_top, body=IRON):
    """挂灯：黄铜顶盖 + 灯体 + 黄铜底座 + 吊环。"""
    m.add(*box((cx - 0.075, cy - 0.075, z_top - 0.040),
               (cx + 0.075, cy + 0.075, z_top)), BRASS)
    m.add(*box((cx - 0.062, cy - 0.062, z_top - 0.220),
               (cx + 0.062, cy + 0.062, z_top - 0.040)), body)
    m.add(*box((cx - 0.075, cy - 0.075, z_top - 0.260),
               (cx + 0.075, cy + 0.075, z_top - 0.220)), BRASS)
    m.add(*rod((cx, cy, z_top), (cx, cy, z_top + 0.100), 0.012, 6), METAL)


def add_ladder(m, x, y, z0, z1, width=0.52, rungs=6, thickness=0.05):
    """竖直爬梯：两根梯梁 + 若干踏棍（梯梁沿 Z，梯面在 XZ 平面）。"""
    for sx in (-1.0, 1.0):
        cx = x + sx * width / 2.0
        m.add(*box((cx - thickness / 2, y - thickness / 2, z0),
                   (cx + thickness / 2, y + thickness / 2, z1)), METAL)
    for i in range(rungs):
        z = z0 + (z1 - z0) * (i + 0.5) / rungs
        m.add(*box((x - width / 2, y - 0.020, z - 0.020),
                   (x + width / 2, y + 0.020, z + 0.020)), METAL)


# --------------------------------------------------------------------------- #
# 1. SN_Market_Stall —— 市场棚（5.0 × 3.0 × 3.2）
# --------------------------------------------------------------------------- #

def build_market_stall():
    m = Part()

    # 4 根木柱：后柱 3.10 m、前柱 2.70 m（前后高差 0.40 m 让棚顶前倾）
    posts = [(-2.20, -1.20, 3.10), (-2.20, 1.20, 3.10),
             (2.20, -1.20, 2.70), (2.20, 1.20, 2.70)]
    for x, y, h in posts:
        m.add(*box((x - 0.060, y - 0.060, 0.0), (x + 0.060, y + 0.060, h)), WOOD)
        m.add(*box((x - 0.110, y - 0.110, 0.0), (x + 0.110, y + 0.110, 0.080)), DARK)

    # 前后横梁（沿 Y）与两侧斜梁（沿 X，承帆布）
    for x, h in ((-2.20, 3.10), (2.20, 2.70)):
        m.add(*box((x - 0.050, -1.30, h - 0.090), (x + 0.050, 1.30, h)), WOOD)
    for y in (-1.20, 1.20):
        m.add(*beam((-2.20, y, 3.130), (2.20, y, 2.730), 0.090, 0.090), WOOD)

    # 帆布遮阳棚：后高前低 + 横向微下垂，0.025 m 厚闭合薄板
    def awning(u, v):
        return (-2.5 + 5.0 * u,
                -1.5 + 3.0 * v,
                3.20 - 0.48 * u - 0.05 * math.sin(math.pi * v))

    m.add(*grid_slab(awning, 6, 4, 0.025), CANVAS)

    # 前柜台 + 台面（台面外挑 6 cm）
    m.add(*box((1.30, -1.05, 0.0), (2.10, 1.05, 1.02)), WOOD)
    m.add(*box((1.24, -1.12, 1.02), (2.16, 1.12, 1.12)), DECK)

    # 两侧半高挡板（前端搭柜台、后端搭后柱）
    for y in (-1.28, 1.28):
        m.add(*box((-2.12, y - 0.030, 0.0), (1.60, y + 0.030, 0.90)), DARK)

    # 柜台后货架（两块立板 + 两层搁板）
    for y in (-1.10, 1.10):
        m.add(*box((-2.12, y - 0.040, 0.0), (-1.58, y + 0.040, 1.30)), DARK)
    for z in (0.50, 1.00):
        m.add(*box((-2.10, -1.10, z), (-1.60, 1.10, z + 0.05)), WOOD)

    # 两个木箱
    add_crate(m, -1.05, -0.50, 0.60)
    add_crate(m, -1.05, 0.50, 0.60)

    # 空图标招牌板：挂在两根前柱之间，中央留 0.6 × 0.4 m 浅色空白面板
    m.add(*box((2.14, -1.14, 2.30), (2.22, 1.14, 2.70)), WOOD)
    m.add(*box((2.22, -0.30, 2.30), (2.26, 0.30, 2.70)), CANVAS)

    # 2 盏挂灯：前柱外侧的挂钩 + 灯
    for sy in (-1.0, 1.0):
        y = sy * 1.20
        m.add(*beam((2.20, y, 2.25), (2.38, y, 2.25), 0.035, 0.035), METAL)
        m.add(*rod((2.38, y, 2.25), (2.38, y, 2.19), 0.010, 6), METAL)
        add_lantern(m, 2.38, y, 2.19, body=METAL)

    # 柜台与后柱之间的斜撑
    for sy in (-1.0, 1.0):
        y = sy * 1.05
        m.add(*beam((-2.10, y, 1.22), (1.35, y, 1.05), 0.045, 0.045), DARK)
    return m


# --------------------------------------------------------------------------- #
# 2. SN_Notice_Board —— 委托告示板（2.8 × 0.5 × 2.6）
# --------------------------------------------------------------------------- #

def build_notice_board():
    m = Part()

    # 2 根立柱（后柱更高，托起披檐后沿；柱顶刚好顶到披檐下沿）
    for sx, h in ((-1.25, 2.520), (1.25, 2.210)):
        m.add(*box((sx - 0.050, -0.050, 0.0), (sx + 0.050, 0.050, h)), WOOD)
        m.add(*box((sx - 0.100, -0.080, 0.0), (sx + 0.100, 0.080, 0.080)), DARK)

    # 布告板组件（先建平放坐标，再整体后仰 5°）
    bp = Part()
    bp.add(*box((-1.25, -0.060, 2.05), (1.25, 0.060, 2.15)), WOOD)   # 上横档
    bp.add(*box((-1.25, -0.060, 1.05), (1.25, 0.060, 1.15)), WOOD)   # 下横档
    for sx in (-1.0, 1.0):                                            # 左右立档
        xa, xb = sorted((sx * 1.15, sx * 1.25))
        bp.add(*box((xa, -0.060, 1.05), (xb, 0.060, 2.15)), WOOD)
    bp.add(*box((-1.18, -0.025, 1.10), (1.18, 0.025, 2.10)), DARK)   # 后挡板

    # 6 张浅色纸张（8 mm 厚闭合薄板，前后错位 8–20 mm，板面内微转 ±2°）
    paper_spec = [
        (-0.62, 1.32, 0.42, 0.28, 2.0), (-0.62, 1.64, 0.42, 0.28, -1.5),
        (-0.62, 1.96, 0.42, 0.28, 1.0),
        (0.62, 1.32, 0.42, 0.28, -2.0), (0.62, 1.64, 0.42, 0.28, 1.5),
        (0.62, 1.96, 0.42, 0.28, -1.0),
    ]
    for cx, cz, pw, ph, deg in paper_spec:
        vf = box((cx - pw / 2, 0.027, cz - ph / 2), (cx + pw / 2, 0.035, cz + ph / 2))
        bp.add(*rot_y(vf, math.radians(deg), cx, cz), CANVAS)

    # 整体后仰 5°（绕板底横档前缘）：上沿后移约 0.10 m
    bp.verts = rot_y((bp.verts, []), math.radians(-5.0), 0.0, 1.05)[0]
    m.append(bp)

    # 小披檐（后高前低的闭合薄板，顶沿 = 2.60 m）
    def eave(u, v):
        return (-1.40 + 2.80 * u, -0.25 + 0.50 * v, 2.25 + 0.35 * (1.0 - u))

    m.add(*grid_slab(eave, 4, 1, 0.060), CANVAS)

    # 侧挂煤油灯托架（+X 柱外侧）
    m.add(*beam((1.25, 0.14, 1.62), (1.38, 0.14, 1.66), 0.030, 0.030), METAL)
    m.add(*rod((1.38, 0.14, 1.66), (1.38, 0.14, 1.60), 0.010, 6), METAL)
    m.add(*box((1.33, 0.075, 1.44), (1.40, 0.205, 1.60)), METAL)
    m.add(*box((1.32, 0.068, 1.60), (1.40, 0.212, 1.62)), METAL)
    return m


# --------------------------------------------------------------------------- #
# 3. SN_Water_Tank —— 港口水箱（4.0 × 4.0 × 5.2）
# --------------------------------------------------------------------------- #

def build_water_tank():
    m = Part()
    sides = 16
    phase = 0.0  # phase=0 让 16 边形在 ±X / ±Y 上都落顶点，包围盒精确 = 4.0 × 4.0

    # 石砌基座（两级收分，底面半径 2.00）
    m.add(*revolved([(0.00, 2.00), (0.14, 2.00), (0.14, 1.94),
                     (0.42, 1.94), (0.42, 1.86)], sides, phase), STONE)

    # 筒身（16 边）；底环嵌入基座顶面 25 mm，避免悬空/共面
    m.add(*revolved([(0.395, 1.78), (4.02, 1.78)], sides, phase), METAL)

    # 顶部收口环 + 锥形顶盖（顶沿 5.20 m）
    m.add(*revolved([(3.96, 1.84), (4.06, 1.84)], sides, phase), IRON)
    m.add(*revolved([(4.02, 1.78), (4.10, 1.72), (5.00, 0.20), (5.20, 0.14)],
                    sides, phase), METAL)

    # 3 道铁箍（比筒壁外凸 60 mm，闭合实心环带）
    for z0 in (1.05, 2.35, 3.55):
        m.add(*revolved([(z0, 1.84), (z0 + 0.10, 1.84)], sides, phase), IRON)

    # 铆钉：2 圈 × 16 颗，贴在 16 边形的面心上（面心半径 = 1.78·cos(π/16)）
    apothem = 1.78 * math.cos(math.pi / sides)
    for z in (1.55, 2.95):
        for i in range(sides):
            angle = (i + 0.5) * 2.0 * math.pi / sides
            cx = (apothem + 0.012) * math.cos(angle)
            cy = (apothem + 0.012) * math.sin(angle)
            m.add(*box((cx - 0.026, cy - 0.026, z - 0.026),
                       (cx + 0.026, cy + 0.026, z + 0.026)), IRON)

    # 出水弯管 + 阀门（+X 侧，最远 x = 1.98 < 2.00）
    m.add(*rod((1.70, 0.0, 0.95), (1.88, 0.0, 0.95), 0.080, 8), METAL)
    m.add(*rod((1.88, 0.0, 0.95), (1.88, 0.0, 0.45), 0.080, 8), METAL)
    m.add(*box((1.80, -0.10, 0.68), (1.96, 0.10, 0.80)), IRON)
    wheel = translate(band_ring(0.80, 0.86, 0.050, 0.100, 8), 1.88, 0.0, 0.0)
    m.add(*wheel, METAL)

    # 侧爬梯（-Y 侧，离筒壁 50 mm）
    add_ladder(m, 0.0, -1.83, 0.30, 3.70, width=0.52, rungs=7)
    for sx in (-1.0, 1.0):
        for z in (1.05, 2.05, 3.05):
            m.add(*beam((sx * 0.26, -1.83, z), (sx * 0.26, -1.78, z), 0.040, 0.040), METAL)

    # 液位计（细长深色窄条 + 黄铜上下端头，不发光）
    m.add(*box((1.730, 0.300, 0.95), (1.770, 0.400, 3.45)), IRON)
    for z in (0.93, 3.40):
        m.add(*box((1.720, 0.290, z), (1.780, 0.410, z + 0.050)), BRASS)

    # 小黄铜铭牌（空白）
    m.add(*box((1.730, -0.460, 2.30), (1.780, -0.200, 2.55)), BRASS)
    return m


# --------------------------------------------------------------------------- #
# 4. SN_Signal_Tower —— 情报信号塔（3.2 × 2.4 × 8.5）
# --------------------------------------------------------------------------- #

def build_signal_tower():
    m = Part()
    keys = [(-1.0, -1.0), (-1.0, 1.0), (1.0, -1.0), (1.0, 1.0)]
    foot = {(-1.0, -1.0): (-1.35, -0.95), (-1.0, 1.0): (-1.35, 0.95),
            (1.0, -1.0): (1.35, -0.95), (1.0, 1.0): (1.35, 0.95)}
    top = {(-1.0, -1.0): (-0.42, -0.36), (-1.0, 1.0): (-0.42, 0.36),
           (1.0, -1.0): (0.42, -0.36), (1.0, 1.0): (0.42, 0.36)}

    def leg_pt(key, z):
        bx, by = foot[key]
        tx, ty = top[key]
        t = (z - 0.10) / (6.150 - 0.10)
        return (bx + (tx - bx) * t, by + (ty - by) * t, z)

    # 4 根收分钢腿 + 底面地脚板（地脚板定出 3.2 × 2.4 的落地轮廓）
    for key in keys:
        bx, by = foot[key]
        tx, ty = top[key]
        m.add(*hexa(rect_pts(bx - 0.070, bx + 0.070, by - 0.070, by + 0.070, 0.100),
                    rect_pts(tx - 0.045, tx + 0.045, ty - 0.045, ty + 0.045, 6.150)), METAL)
        m.add(*box((bx - 0.250, by - 0.250, 0.0), (bx + 0.250, by + 0.250, 0.100)), METAL)

    # 水平横梁 + X 斜撑（两层）
    faces = [((-1.0, -1.0), (1.0, -1.0)), ((1.0, -1.0), (1.0, 1.0)),
             ((1.0, 1.0), (-1.0, 1.0)), ((-1.0, 1.0), (-1.0, -1.0))]
    for z in (2.55, 4.30):
        for a, b in faces:
            m.add(*beam(leg_pt(a, z), leg_pt(b, z), 0.060, 0.060), METAL)
    for z0, z1 in ((1.20, 2.55), (2.55, 4.30)):
        for a, b in faces:
            m.add(*beam(leg_pt(a, z0), leg_pt(b, z1), 0.045, 0.045), METAL)

    # 顶部平台（2.1 × 1.7） + 栏杆
    m.add(*box((-1.05, -0.85, 6.150), (1.05, 0.85, 6.280)), DARK)
    rail_posts = [(-1.00, -0.80), (-1.00, 0.80), (0.00, -0.80), (0.00, 0.80),
                  (1.00, -0.80), (1.00, 0.80)]
    for x, y in rail_posts:
        m.add(*box((x - 0.030, y - 0.030, 6.280), (x + 0.030, y + 0.030, 6.760)), METAL)
    for y in (-0.80, 0.80):
        m.add(*beam((-1.00, y, 6.740), (1.00, y, 6.740), 0.050, 0.050), METAL)
    for x in (-1.00, 1.00):
        m.add(*beam((x, -0.80, 6.740), (x, 0.80, 6.740), 0.050, 0.050), METAL)

    # 旗语桅杆（收分，桅顶小球顶沿 = 8.50 m）
    m.add(*revolved([(6.280, 0.100), (7.200, 0.090), (8.250, 0.060), (8.350, 0.050)],
                    8, 0.0), DARK)
    m.add(*revolved([(8.350, 0.070), (8.400, 0.065), (8.460, 0.040), (8.500, 0.020)],
                    8, 0.0), BRASS)

    # 两片摆臂：黄铜抱箍 + 短支架 + 臂（与桅杆留 0.15 m 净距）
    for side, z_arm, tip_z in ((-1.0, 7.65, 7.95), (1.0, 7.25, 6.95)):
        m.add(*band_ring(z_arm - 0.045, z_arm + 0.045, 0.070, 0.135, 8), BRASS)
        m.add(*beam((side * 0.120, 0.0, z_arm), (side * 0.245, 0.0, z_arm), 0.050, 0.050), BRASS)
        m.add(*beam((side * 0.245, 0.0, z_arm), (side * 1.180, 0.0, tip_z), 0.075, 0.045), DARK)
        m.add(*rod((side * 1.180, 0.0, tip_z), (side * 1.260, 0.0, tip_z), 0.045, 6), BRASS)

    # 灯室：黄铜壳 + 深色面板 + 顶盖（挂在桅杆 +Y 侧）
    m.add(*beam((0.0, 0.060, 7.86), (0.0, 0.330, 7.86), 0.050, 0.050), BRASS)
    m.add(*box((-0.180, 0.330, 7.520), (0.180, 0.660, 7.860)), BRASS)
    m.add(*box((0.176, 0.360, 7.560), (0.188, 0.630, 7.820)), IRON)   # +X 面板
    m.add(*box((-0.188, 0.360, 7.560), (-0.176, 0.630, 7.820)), IRON)  # -X 面板
    m.add(*box((-0.140, 0.656, 7.560), (0.140, 0.668, 7.820)), IRON)   # +Y 面板
    m.add(*box((-0.210, 0.300, 7.860), (0.210, 0.690, 7.890)), BRASS)  # 顶盖

    # 旗绳（细圆柱，不用单面片）+ 绳端小滑轮
    m.add(*rod((0.040, 0.0, 8.320), (1.000, -0.800, 6.760), 0.012, 6), CANVAS)

    # 底部工具柜 + 锁扣
    m.add(*box((0.520, -0.560, 0.000), (1.420, 0.560, 0.860)), DARK)
    m.add(*box((0.470, -0.100, 0.640), (0.530, 0.100, 0.760)), BRASS)
    m.add(*box((0.500, -0.560, 0.860), (1.440, 0.560, 0.900)), WOOD)

    # 侧爬梯：沿 -Y 面的两根斜撑之间贴面爬升（不是悬空直梯）
    z0, z1, rungs = 0.20, 6.05, 12
    for sx in (-1.0, 1.0):
        pa = (sx * (1.35 - 0.93 * (z0 - 0.10) / 6.05 - 0.12),
              -0.95 + 0.59 * (z0 - 0.10) / 6.05 - 0.07, z0)
        pb = (sx * (1.35 - 0.93 * (z1 - 0.10) / 6.05 - 0.12),
              -0.95 + 0.59 * (z1 - 0.10) / 6.05 - 0.07, z1)
        m.add(*beam(pa, pb, 0.050, 0.050), METAL)
    for i in range(1, rungs + 1):
        z = z0 + (z1 - z0) * i / (rungs + 1.0)
        t = (z - 0.10) / 6.05
        half = 1.35 - 0.93 * t - 0.12
        y = -0.95 + 0.59 * t - 0.07
        m.add(*box((-half, y - 0.020, z - 0.020), (half, y + 0.020, z + 0.020)), METAL)
    return m


# --------------------------------------------------------------------------- #
# 5. SN_Shipyard_Gantry —— 船厂龙门吊（14.0 × 4.0 × 10.0）
# --------------------------------------------------------------------------- #

def build_shipyard_gantry():
    m = Part()
    leg_x = (-6.50, 6.50)
    leg_bottom_y = 1.780
    leg_top_z = 8.995

    def leg_y(z):
        t = (z - 0.12) / (leg_top_z - 0.12)
        return leg_bottom_y + (0.450 - leg_bottom_y) * t

    # 2 组 A 形腿（脚距 ±1.78 → 总宽 4.0），顶部收拢到 ±0.45
    for x in leg_x:
        for sy in (-1.0, 1.0):
            m.add(*hexa(rect_pts(x - 0.130, x + 0.130,
                                 sy * leg_bottom_y - 0.220, sy * leg_bottom_y + 0.220, 0.120),
                        rect_pts(x - 0.120, x + 0.120,
                                 sy * 0.450 - 0.150, sy * 0.450 + 0.150, leg_top_z)), METAL)
            m.add(*box((x - 0.260, sy * leg_bottom_y - 0.220, 0.0),
                       (x + 0.260, sy * leg_bottom_y + 0.220, 0.120)), IRON)
        # 顶部横梁与中下部横梁 / 斜撑（在 YZ 平面内）
        m.add(*box((x - 0.140, -0.450, 8.680), (x + 0.140, 0.450, leg_top_z)), METAL)
        m.add(*box((x - 0.100, -0.980, 3.400), (x + 0.100, 0.980, 3.560)), METAL)
        m.add(*beam((x, -1.650, 1.400), (x, 1.650, 3.400), 0.090, 0.090), METAL)
        m.add(*beam((x, 1.650, 1.400), (x, -1.650, 3.400), 0.090, 0.090), METAL)

    # 侧爬梯：贴 +X 组 A 形腿的 +X 面，随腿收分倾斜
    for sx in (-1.0, 1.0):
        xa = 6.50 + sx * 0.150
        m.add(*beam((xa, -1.720, 0.220), (xa, -0.640, 8.500), 0.050, 0.050), METAL)
    for i in range(1, 13):
        z = 0.220 + (8.500 - 0.220) * i / 13.0
        t = (z - 0.12) / (leg_top_z - 0.12)
        y = leg_bottom_y + (0.450 - leg_bottom_y) * t - 0.060
        m.add(*beam((6.35, y, z), (6.65, y, z), 0.040, 0.040), IRON)

    # 箱形主梁（下沿 9.00 m，净高 ≥ 8.5 m；x = ±7.00 定出 14.0 m 总长）
    m.add(*box((-7.00, -0.450, 9.000), (7.00, 0.450, 9.750)), METAL)
    for sy in (-1.0, 1.0):
        m.add(*box((-7.00, sy * 0.450, 9.000), (7.00, sy * 0.580, 9.120)), IRON)
        m.add(*box((-7.00, sy * 0.450, 9.630), (7.00, sy * 0.520, 9.750)), IRON)
    for x in (-7.00, 7.00):
        xa, xb = sorted((x, x - math.copysign(0.080, x)))
        m.add(*box((xa, -0.470, 8.980), (xb, 0.470, 9.770)), IRON)

    # 主梁顶走道 + 扶手（顶沿 10.00 m）
    m.add(*box((-6.80, -0.300, 9.749), (6.80, 0.300, 9.800)), DARK)
    for sy in (-1.0, 1.0):
        for x in (-6.80, -3.40, 0.0, 3.40, 6.80):
            m.add(*box((x - 0.030, sy * 0.400 - 0.030, 9.800),
                       (x + 0.030, sy * 0.400 + 0.030, 10.000)), METAL)
        m.add(*box((-6.80, sy * 0.400 - 0.035, 9.960),
                   (6.80, sy * 0.400 + 0.035, 10.000)), METAL)

    # 小车（第 3/4 跨位置 x=3.0） + 滚轮
    m.add(*box((2.42, -0.560, 8.430), (3.58, 0.560, 9.000)), METAL)
    for x in (2.62, 3.38):
        m.add(*rod((x, -0.620, 8.560), (x, 0.620, 8.560), 0.170, 8), IRON)
    m.add(*box((2.75, -0.230, 8.900), (3.25, 0.230, 9.010)), BRASS)

    # 吊钩滑轮组（z = 5.0–5.56） + 钩头
    m.add(*box((2.62, -0.360, 5.000), (3.38, 0.360, 5.560)), METAL)
    for x in (2.82, 3.18):
        m.add(*rod((x, -0.400, 5.230), (x, 0.400, 5.230), 0.220, 8), IRON)
    m.add(*box((2.90, -0.120, 4.700), (3.10, 0.120, 5.000)), METAL)
    m.add(*rod((3.00, 0.0, 4.720), (3.00, 0.0, 4.420), 0.080, 6), METAL)
    m.add(*rod((3.00, 0.0, 4.420), (3.16, 0.0, 4.300), 0.070, 6), IRON)
    m.add(*rod((3.16, 0.0, 4.300), (3.16, 0.0, 4.460), 0.060, 6), IRON)

    # 2 根钢缆（细圆柱，不用单面片）
    for x in (2.78, 3.22):
        m.add(*rod((x, 0.0, 8.430), (x, 0.0, 5.560), 0.022, 6), METAL)

    # 两组 A 形腿之间的横向斜撑（端点落在腿面上）
    for sy in (-1.0, 1.0):
        y_low = sy * leg_y(4.90)
        y_high = sy * leg_y(6.90)
        m.add(*beam((-6.50, y_low, 4.90), (6.50, y_low, 4.90), 0.080, 0.080), METAL)
        m.add(*beam((-6.50, y_high, 6.90), (6.50, y_high, 6.90), 0.080, 0.080), METAL)
        m.add(*beam((-6.50, y_low, 4.90), (6.50, y_high, 6.90), 0.060, 0.060), METAL)
        m.add(*beam((6.50, y_low, 4.90), (-6.50, y_high, 6.90), 0.060, 0.060), METAL)

    # 小型操作平台（挂在 +Y 侧主梁下）
    m.add(*box((4.20, 0.500, 7.200), (5.30, 1.300, 7.300)), DARK)
    for x in (4.25, 5.25):
        for y in (0.55, 1.25):
            m.add(*box((x - 0.030, y - 0.030, 7.300), (x + 0.030, y + 0.030, 7.700)), METAL)
    for y in (0.55, 1.25):
        m.add(*box((4.22, y - 0.035, 7.660), (5.28, y + 0.035, 7.700)), METAL)
    for x in (4.20, 5.30):
        m.add(*beam((x, 1.280, 7.300), (x, 0.450, 8.980), 0.070, 0.070), METAL)
    return m


# --------------------------------------------------------------------------- #
# 6. SN_Dry_Dock —— 干船坞底座（18.0 × 8.0 × 2.6）
# --------------------------------------------------------------------------- #

def build_dry_dock():
    m = Part()

    # 坞底石板（18 × 8 × 0.18）
    m.add(*box((-9.00, -4.00, 0.000), (9.00, 4.00, 0.180)), STONE)

    # 两侧 3 级收分石砌坞壁：内壁台阶 2.20 / 2.60 / 3.00，外壁 4.00
    for sy in (-1.0, 1.0):
        for y_in, z0, z1 in ((2.20, 0.180, 1.000),
                             (2.60, 1.000, 1.800),
                             (3.00, 1.800, 2.600)):
            ya, yb = sorted((sy * y_in, sy * 4.00))
            m.add(*box((-9.00, ya, z0), (9.00, yb, z1)), STONE)
        # 内壁腰线（向坞内凸 20 mm 的砌缝，不与坞壁共面）
        for y_in, z0 in ((2.20, 0.900), (2.60, 1.700)):
            ya, yb = sorted((sy * y_in, sy * (y_in - 0.020)))
            m.add(*box((-9.00, ya, z0), (9.00, yb, z0 + 0.120)), STONE)

    # 2 条滑道轨（沿 X，y = ±0.62）
    for sy in (-1.0, 1.0):
        ya, yb = sorted((sy * 0.550, sy * 0.700))
        m.add(*box((-8.80, ya, 0.180), (8.80, yb, 0.320)), METAL)

    # 5 组龙骨墩（间距 3 m；梯形木墩 + U 形托座）
    for cx in (-6.0, -3.0, 0.0, 3.0, 6.0):
        m.add(*hexa(rect_pts(cx - 0.400, cx + 0.400, -0.500, 0.500, 0.320),
                    rect_pts(cx - 0.300, cx + 0.300, -0.400, 0.400, 0.770)), DARK)
        for sy in (-1.0, 1.0):
            ya, yb = sorted((sy * 0.180, sy * 0.380))
            m.add(*box((cx - 0.400, ya, 0.770), (cx + 0.400, yb, 0.920)), DARK)

    # 排水沟（+Y 半坞：两条矮缘 + 中间深色沟槽）
    m.add(*box((-8.80, 1.020, 0.180), (8.80, 1.100, 0.240)), STONE)
    m.add(*box((-8.80, 1.340, 0.180), (8.80, 1.420, 0.240)), STONE)
    m.add(*box((-8.80, 1.100, 0.180), (8.80, 1.340, 0.200)), METAL)

    # 两侧短石阶（每侧 6 级，贴着坞壁内面）
    for sy in (-1.0, 1.0):
        for i in range(6):
            x0 = 6.20 + i * 0.380
            top = 0.180 + (i + 1) * 0.400
            ya, yb = sorted((sy * 2.05, sy * 2.62))
            m.add(*box((x0, ya, 0.180), (x0 + 0.380, yb, top)), STONE)

    # 坞壁转角短扶壁（读出石砌体量）
    for sy in (-1.0, 1.0):
        for x in (-8.60, 8.60):
            ya, yb = sorted((sy * 3.20, sy * 4.00))
            m.add(*box((x - 0.250, ya, 0.180), (x + 0.250, yb, 2.300)), STONE)
    return m


# --------------------------------------------------------------------------- #
# 注册表
# --------------------------------------------------------------------------- #

BUILDERS = {
    "SN_Market_Stall": build_market_stall,
    "SN_Notice_Board": build_notice_board,
    "SN_Water_Tank": build_water_tank,
    "SN_Signal_Tower": build_signal_tower,
    "SN_Shipyard_Gantry": build_shipyard_gantry,
    "SN_Dry_Dock": build_dry_dock,
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
    mat.use_backface_culling = False
    return mat


def _ensure_collection():
    import bpy
    col = bpy.data.collections.get(COLLECTION)
    if col is None:
        col = bpy.data.collections.new(COLLECTION)
        bpy.context.scene.collection.children.link(col)
    return col


def _make_object(name, part, location, collection):
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
    collection.objects.link(obj)
    obj.location = location
    return obj


def build_all():
    import bpy

    collection = _ensure_collection()

    # 重跑：只清掉本集合内本批 6 件（不碰其他对象，也不碰其他集合）
    for name, _pos, _budget, _size in ITEMS:
        old = collection.objects.get(name)
        if old is not None:
            old_mesh = old.data
            bpy.data.objects.remove(old, do_unlink=True)
            if old_mesh is not None and old_mesh.users == 0:
                bpy.data.meshes.remove(old_mesh)
    for name, _pos, _budget, _size in ITEMS:
        for stale in [me for me in bpy.data.meshes
                      if me.users == 0 and me.name.startswith(name)]:
            bpy.data.meshes.remove(stale)

    geometry = build_all_geometry()
    return {name: _make_object(name, geometry[name], pos, collection)
            for name, pos, _b, _s in ITEMS}


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
        measured = [round(max(xs) - min(xs), 4), round(max(ys) - min(ys), 4),
                    round(max(zs) - min(zs), 4)]

        mats = [m.name for m in mesh.materials]
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
            "materials": mats,
            "materials_in_palette": all(x in PALETTE for x in mats),
            "loose_verts": loose,
            "degenerate_faces": degen,
            "non_manifold_edges": nonman,
            "boundary_edges": boundary,
            "mat_slot_overflow": overflow,
            "mesh_datablock": mesh.name,
        })
        out["total_tris"] += tris

    out["health"] = {
        "all_manifold": all(i["non_manifold_edges"] == 0 for i in out["items"]),
        "no_boundary": all(i["boundary_edges"] == 0 for i in out["items"]),
        "no_loose": all(i["loose_verts"] == 0 for i in out["items"]),
        "no_degenerate": all(i["degenerate_faces"] == 0 for i in out["items"]),
        "no_mat_overflow": all(i["mat_slot_overflow"] == 0 for i in out["items"]),
        "all_within_1_2x_budget": all(i["tris"] <= int(i["budget"] * 1.2) for i in out["items"]),
        "total_within_budget": out["total_tris"] <= TOTAL_BUDGET,
        "all_sizes_ok": all(abs(d) <= 0.1 for i in out["items"] for d in i["size_delta"]),
        "all_grounded": all(abs(i["zmin"]) <= 1e-6 for i in out["items"]),
        "palette_only": all(i["materials_in_palette"] for i in out["items"]),
    }

    collection = bpy.data.collections.get(COLLECTION)
    out["scene"] = {
        "objects": len(bpy.data.objects),
        "mesh": sum(1 for o in bpy.data.objects if o.type == "MESH"),
        "collection": sorted(o.name for o in collection.objects) if collection else [],
        "materials": sorted(m.name for m in bpy.data.materials),
    }
    print("PORT_FACILITIES_REPORT " + repr(out))
    return out


if __name__ == "__main__":
    build_all()
    report()
