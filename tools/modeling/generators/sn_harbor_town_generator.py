# -*- coding: utf-8 -*-
"""Steam Navigator — 港口街景第一批 10 件参数化生成脚本。

工单：tools/modeling/briefs/sn_harbor_town_batch1.json
集合：SN_Harbor_Town（本脚本负责新建；重跑只重建本批 SN_HT_* 10 件）
布局：沿工作台 y=110 一行排开，x = -48, -28, -12, 2, 14, 24, 32, 40, 48, 58
轴心：底面中心（object.location = 布局位置，几何全部为局部坐标，底面 z=0）
预算：合计 <= 11500 tri；单件 tri_budget 见 ITEMS（验收上限 1.2×）
材质：调色板 SN_Wood / SN_Wood_Dark / SN_Wood_Deck / SN_Metal / SN_Iron / SN_Brass /
      SN_Stone / SN_Canvas / SN_Canvas_Shade / SN_Brick / SN_Plaster / SN_Glass_Dark；
      SN_Brick / SN_Plaster / SN_Glass_Dark 为本批新增（见 NEW_MATERIALS，仅在缺失时创建）

设计要点
--------
- 全部几何由本文件顶部 ITEMS 参数表 + 各 build_* 函数生成，改数值即可重建；禁止手工摆点。
- 每件是**一个 mesh 对象**（多材质槽），原点在底面中心。
- 壳体全部闭合（边界边/非流形边为 0）：薄板一律做成"两层面 + 四周边缘"的闭合 slab，
  双坡屋面用 roof_slab()，不给单层面片，屋面上下两面都可读。
- 窗/门只是 0.05–0.1 m 深的暗色板 + 石过梁/窗台，不做凹陷室内、不做可进入门。
- 招牌/钟盘/门牌上没有文字或数字；文字由 2D UI 标签层负责。
- 互相接触的部件之间留 2–20 mm 缝或有意嵌入 5–10 mm，避免共面 z-fighting。
- 几何函数为纯 Python（不 import bpy），可用 dryrun_props.py 离线校验。

用法
----
Blender 内：
    p = r"<abs path>/sn_harbor_town_generator.py"
    ns = {"__name__": "sn_harbor_town_generator", "__file__": p}
    exec(compile(open(p, encoding="utf-8").read(), p, "exec"), ns)
    ns["build_all"]()
    ns["report"]()
纯 Python 干跑：
    python tools/modeling/generators/dryrun_props.py tools/modeling/generators/sn_harbor_town_generator.py
"""

import math

COLLECTION = "SN_Harbor_Town"
PREFIX = "SN_HT_"
ROW_Y = 110.0

# (对象名, 布局位置, tri 预算, 目标包围盒 X×Y×Z)
ITEMS = [
    ("SN_HT_Warehouse_Long", (-48.0, ROW_Y, 0.0), 2600, (20.0, 9.0, 11.0)),
    ("SN_HT_Warehouse_Short", (-28.0, ROW_Y, 0.0), 1700, (11.0, 9.0, 9.5)),
    ("SN_HT_Harbor_Office", (-12.0, ROW_Y, 0.0), 2200, (9.0, 8.0, 14.0)),
    ("SN_HT_Cargo_Shed", (2.0, ROW_Y, 0.0), 700, (8.0, 6.0, 4.5)),
    ("SN_HT_Tavern", (14.0, ROW_Y, 0.0), 1700, (10.0, 8.0, 8.0)),
    ("SN_HT_Fence_Row", (24.0, ROW_Y, 0.0), 300, (6.0, 0.30, 1.5)),
    ("SN_HT_Dock_Worker_A", (32.0, ROW_Y, 0.0), 250, (0.7, 0.45, 1.8)),
    ("SN_HT_Dock_Worker_B", (40.0, ROW_Y, 0.0), 250, (0.8, 0.5, 1.8)),
    ("SN_HT_Rowboat", (48.0, ROW_Y, 0.0), 550, (4.2, 1.5, 0.8)),
    ("SN_HT_Cargo_Lighter", (58.0, ROW_Y, 0.0), 700, (8.0, 3.0, 1.6)),
]

TOTAL_BUDGET = 11500

# 工单 acceptance 白名单（12 个材质）
PALETTE = {
    "SN_Wood", "SN_Wood_Dark", "SN_Wood_Deck", "SN_Metal", "SN_Iron",
    "SN_Brass", "SN_Stone", "SN_Canvas", "SN_Canvas_Shade",
    "SN_Brick", "SN_Plaster", "SN_Glass_Dark",
}

# 本批新增材质（已存在则复用，不覆盖既有参数）
NEW_MATERIALS = {
    "SN_Brick": {"base": (0.260, 0.098, 0.062), "roughness": 0.92, "metallic": 0.0},
    "SN_Plaster": {"base": (0.520, 0.470, 0.385), "roughness": 0.95, "metallic": 0.0},
    "SN_Glass_Dark": {"base": (0.032, 0.042, 0.052), "roughness": 0.25, "metallic": 0.35},
}

# 第 1 步基线（工作台 234 对象：213 mesh + 19 empty + 1 camera + 1 light）回归指纹
BASELINE_DIGEST = "4fe3f250493dd9fc409585e7093c14787110b9c17d585608135f943af4e4d000"

WOOD = "SN_Wood"
DARK = "SN_Wood_Dark"
DECK = "SN_Wood_Deck"
METAL = "SN_Metal"
IRON = "SN_Iron"
BRASS = "SN_Brass"
STONE = "SN_Stone"
CANVAS = "SN_Canvas"
CANVAS_SHADE = "SN_Canvas_Shade"
BRICK = "SN_Brick"
PLASTER = "SN_Plaster"
GLASS = "SN_Glass_Dark"


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


def rect_pts(x0, x1, y0, y1, z):
    return [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)]


def hexa(bottom, top):
    """8 顶点六面体：bottom / top 各 4 点，顺序一致。"""
    verts = list(bottom) + list(top)
    faces = [
        (0, 3, 2, 1), (4, 5, 6, 7),
        (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7),
    ]
    return verts, faces


def box(lo, hi):
    """轴对齐闭合盒；端点自动排序，允许传反序端点。"""
    x0, x1 = sorted((lo[0], hi[0]))
    y0, y1 = sorted((lo[1], hi[1]))
    z0, z1 = sorted((lo[2], hi[2]))
    return hexa(rect_pts(x0, x1, y0, y1, z0), rect_pts(x0, x1, y0, y1, z1))


def tb(x0, x1, y0, y1, z0, z1, ti=0.0):
    """收分盒：顶面相对底面四边各内收 ti。"""
    x0, x1 = sorted((x0, x1))
    y0, y1 = sorted((y0, y1))
    return hexa(rect_pts(x0, x1, y0, y1, z0),
                rect_pts(x0 + ti, x1 - ti, y0 + ti, y1 - ti, z1))


def prism_z(pts, z0, z1):
    """XY 平面闭合多边形沿 Z 拉伸成闭合棱柱。"""
    n = len(pts)
    verts = [(x, y, z0) for x, y in pts] + [(x, y, z1) for x, y in pts]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    return verts, faces


def prism_y(pts, y0, y1):
    """XZ 平面闭合多边形沿 Y 拉伸成闭合棱柱（山墙、拱券用）。"""
    n = len(pts)
    verts = [(x, y0, z) for x, z in pts] + [(x, y1, z) for x, z in pts]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    return verts, faces


def tri_prism_x(x0, x1, y0, y1, ze, zr):
    """三角形截面（YZ）沿 X 拉伸的闭合山墙体。"""
    ym = (y0 + y1) / 2.0
    verts = [(x0, y0, ze), (x0, y1, ze), (x0, ym, zr),
             (x1, y0, ze), (x1, y1, ze), (x1, ym, zr)]
    faces = [(2, 1, 0), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)]
    return verts, faces


def arc_band(cx, cz, r_in, r_out, y0, y1, a0, a1, segs):
    """圆弧环带（拱券 / 圆箍）：矩形截面沿圆弧扫掠的闭合壳体。"""
    rings = []
    for k in range(segs + 1):
        a = a0 + (a1 - a0) * k / float(segs)
        rx, rz = math.cos(a), math.sin(a)
        ox, oz = cx + r_out * rx, cz + r_out * rz
        ix, iz = cx + r_in * rx, cz + r_in * rz
        rings.append([(ox, y0, oz), (ox, y1, oz), (ix, y1, iz), (ix, y0, iz)])
    verts = [p for r in rings for p in r]
    faces = []
    for k in range(segs):
        a, b = k * 4, (k + 1) * 4
        for i in range(4):
            j = (i + 1) % 4
            faces.append((a + i, a + j, b + j, b + i))
    faces.append((3, 2, 1, 0))
    faces.append((segs * 4, segs * 4 + 1, segs * 4 + 2, segs * 4 + 3))
    return verts, faces


def roof_slab(x0, x1, ye, ze, yr, zr, t):
    """单坡屋面闭合板：底面从檐口 (ye,ze) 到屋脊 (yr,zr)，沿外法线加厚 t。"""
    dy, dz = yr - ye, zr - ze
    length = math.hypot(dy, dz)
    ny, nz = -dz / length, dy / length
    if nz < 0.0:
        ny, nz = -ny, -nz
    bottom = [(x0, ye, ze), (x1, ye, ze), (x1, yr, zr), (x0, yr, zr)]
    top = [(x, y + ny * t, z + nz * t) for x, y, z in bottom]
    return hexa(bottom, top)


def ring(n, rx, ry, z, cx=0.0, cy=0.0, phase=None):
    if phase is None:
        phase = math.pi / n
    return [
        (cx + rx * math.cos(phase + 2.0 * math.pi * i / n),
         cy + ry * math.sin(phase + 2.0 * math.pi * i / n),
         z)
        for i in range(n)
    ]


def circle(n, r, phase=None):
    if phase is None:
        phase = math.pi / n
    return [(r * math.cos(phase + 2.0 * math.pi * i / n),
             r * math.sin(phase + 2.0 * math.pi * i / n)) for i in range(n)]


def revolved(profile, sides, phase=None):
    """[(z, r), ...] 绕 Z 轴回转，首尾环用扇形封盖（r 不得为 0）。"""
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
    """2D 闭合截面沿 p0→p1 拉伸成闭合壳体（首尾封盖）。"""
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
    return sweep(p0, p1, circle(sides, r))


def loft(rings):
    """同点数闭合截面沿 X 顺序放样成闭合壳体（首尾扇形封盖）。"""
    n = len(rings[0])
    verts = [p for r in rings for p in r]
    faces = []
    for k in range(len(rings) - 1):
        a, b = k * n, (k + 1) * n
        for i in range(n):
            j = (i + 1) % n
            faces.append((a + i, a + j, b + j, b + i))
    last = (len(rings) - 1) * n
    faces.append(tuple(range(n - 1, -1, -1)))
    faces.append(tuple(range(last, last + n)))
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


# --------------------------------------------------------------------------- #
# 共用小部件
# --------------------------------------------------------------------------- #

def add_window(m, cx, cz, w, h, y, s=-1.0, mat=GLASS):
    """窗：0.05 m 深暗色板 + 石窗台 + 石过梁（不做凹陷室内）。"""
    m.add(*box((cx - w / 2, y, cz - h / 2), (cx + w / 2, y + s * 0.05, cz + h / 2)), mat)
    m.add(*box((cx - w / 2 - 0.09, y, cz - h / 2 - 0.13),
               (cx + w / 2 + 0.09, y + s * 0.13, cz - h / 2)), STONE)
    m.add(*box((cx - w / 2 - 0.09, y, cz + h / 2),
               (cx + w / 2 + 0.09, y + s * 0.11, cz + h / 2 + 0.13)), STONE)


def add_door(m, cx, z0, w, h, y, s=-1.0, mat=DARK, frame=WOOD):
    """门：0.05 m 深暗色门板 + 两侧门框 + 门楣。"""
    m.add(*box((cx - w / 2, y, z0), (cx + w / 2, y + s * 0.05, z0 + h)), mat)
    for sx in (-1.0, 1.0):
        xa = cx + sx * (w / 2.0) - 0.11
        m.add(*box((xa, y, z0), (xa + 0.22, y + s * 0.14, z0 + h)), frame)
    m.add(*box((cx - w / 2 - 0.22, y, z0 + h),
               (cx + w / 2 + 0.22, y + s * 0.15, z0 + h + 0.20)), frame)


def add_crate(m, cx, cy, size, z0=0.0, mat=WOOD, band=DARK):
    """木箱：箱体 + 正面两根竖条（比箱面凸 15 mm）。"""
    half = size / 2.0
    m.add(*box((cx - half, cy - half, z0), (cx + half, cy + half, z0 + size)), mat)
    for sx in (-1.0, 1.0):
        x = cx + sx * half * 0.55
        m.add(*box((x - 0.035, cy - half - 0.015, z0 + 0.06),
                   (x + 0.035, cy - half, z0 + size - 0.06)), band)


def add_barrel(m, cx, cy, r, h, z0=0.0):
    """木桶：8 边回转，中腰最宽。"""
    m.add(*revolved([(z0, r * 0.80), (z0 + h * 0.22, r),
                     (z0 + h * 0.78, r), (z0 + h, r * 0.80)], 8), WOOD)
    m.add(*revolved([(z0 + h * 0.28, r * 1.02), (z0 + h * 0.40, r * 1.02)], 8), IRON)
    m.add(*revolved([(z0 + h * 0.62, r * 1.02), (z0 + h * 0.74, r * 1.02)], 8), IRON)


def add_bollard(m, cx, cy, h, z0=0.0, mat=IRON, r=0.13):
    m.add(*revolved([(z0, r * 1.15), (z0 + h * 0.20, r * 0.80),
                     (z0 + h * 0.80, r * 0.75), (z0 + h, r * 1.05)], 8), mat)
    m.add(*box((cx - r * 1.35, cy - r * 1.35, z0 + h),
               (cx + r * 1.35, cy + r * 1.35, z0 + h + 0.05)), BRASS)


def add_lantern(m, cx, cy, z_top, hook_len=0.22, body=IRON):
    """挂灯：铁吊杆 + 黄铜顶盖 + 灯体 + 黄铜底座。"""
    m.add(*rod((cx, cy, z_top), (cx, cy, z_top - hook_len), 0.014, 6), METAL)
    zt = z_top - hook_len
    m.add(*box((cx - 0.085, cy - 0.085, zt - 0.04), (cx + 0.085, cy + 0.085, zt)), BRASS)
    m.add(*box((cx - 0.070, cy - 0.070, zt - 0.24), (cx + 0.070, cy + 0.070, zt - 0.04)), body)
    m.add(*box((cx - 0.085, cy - 0.085, zt - 0.29), (cx + 0.085, cy + 0.085, zt - 0.24)), BRASS)


def add_railing(m, x0, x1, y, z0, z1, posts=3, mat=METAL, s=-1.0):
    """铁栏：顶部扶手 + 若干立柱（都在 y 面外侧）。"""
    m.add(*box((x0, y, z1 - 0.06), (x1, y + s * 0.05, z1)), mat)
    m.add(*box((x0, y, z0 + 0.20), (x1, y + s * 0.04, z0 + 0.26)), mat)
    for i in range(posts):
        x = x0 + (x1 - x0) * i / float(max(1, posts - 1))
        m.add(*box((x - 0.035, y, z0), (x + 0.035, y + s * 0.05, z1)), mat)


# --------------------------------------------------------------------------- #
# 1. SN_HT_Warehouse_Long —— 长条砖木仓库（20.0 × 9.0 × 11.0）
# --------------------------------------------------------------------------- #

def build_warehouse_long():
    m = Part()
    # 石基座：定 20.0 × 9.0 落地轮廓
    m.add(*box((-10.00, -4.50, 0.00), (10.00, 4.50, 0.55)), STONE)
    m.add(*box((-9.88, -4.38, 0.55), (9.88, 4.38, 0.66)), STONE)
    # 砖墙主体（上沿 7.62；屋面底面正好落在墙顶）
    m.add(*box((-9.70, -4.20, 0.58), (9.70, 4.20, 7.62)), BRICK)
    # 两端山墙（三角，7.60 → 10.82）
    m.add(*tri_prism_x(-9.70, -9.32, -4.20, 4.20, 7.60, 10.82), BRICK)
    m.add(*tri_prism_x(9.32, 9.70, -4.20, 4.20, 7.60, 10.82), BRICK)
    # 双坡屋面（两片闭合板；檐口贴墙顶，脊顶 = 11.00）
    m.add(*roof_slab(-9.90, 9.90, -4.20, 7.62, 0.0, 10.82, 0.22), DARK)
    m.add(*roof_slab(-9.90, 9.90, 4.20, 7.62, 0.0, 10.82, 0.22), DARK)
    m.add(*box((-9.90, -0.22, 10.76), (9.90, 0.22, 11.00)), IRON)
    # 山墙檐口压条（沿 X，前后各一）
    for sy in (-1.0, 1.0):
        m.add(*box((-9.92, sy * 4.18 - 0.02, 7.42), (9.92, sy * 4.18 + 0.02, 7.66)), STONE)

    # 木构立柱节奏：每面 6 根壁柱 + 上下两道通长横梁
    for sy in (-1.0, 1.0):
        for x in (-8.55, -5.13, -1.71, 1.71, 5.13, 8.55):
            m.add(*box((x - 0.16, sy * 4.20, 0.60),
                       (x + 0.16, sy * 4.20 + sy * 0.16, 7.56)), DARK)
        for z in (2.95, 6.75):
            m.add(*box((-9.56, sy * 4.20, z), (9.56, sy * 4.20 + sy * 0.13, z + 0.20)), DARK)
        # 柱间斜撑（每开间一根，交替方向）
        for i, x in enumerate((-8.55, -5.13, -1.71, 1.71, 5.13)):
            x2 = x + (1.71 if i % 2 == 0 else 1.71)
            xa, xb = sorted((x, x2))
            m.add(*beam((xa + 0.20, sy * 4.30, 2.95), (xb - 0.20, sy * 4.30, 3.75),
                        0.10, 0.10), DARK)

    # 2 扇滑轨装卸大门（-Y 立面）
    for cx in (-4.20, 3.00):
        m.add(*box((cx - 1.65, -4.20, 0.62), (cx + 1.65, -4.26, 5.05)), DARK)
        for sx in (-1.0, 1.0):
            x = cx + sx * 1.65
            m.add(*box((x - 0.11, -4.20, 0.62), (x + 0.11, -4.34, 5.05)), WOOD)
        m.add(*box((cx - 1.90, -4.20, 5.05), (cx + 1.90, -4.34, 5.25)), WOOD)
        m.add(*box((cx - 1.96, -4.20, 5.28), (cx + 1.96, -4.28, 5.44)), IRON)
        # 门板竖向拼缝（4 根细条，凸 8 mm）
        for k in (-1, 1):
            x = cx + k * 0.55
            m.add(*box((x - 0.025, -4.26, 0.70), (x + 0.025, -4.285, 4.95)), IRON)

    # 4 扇深色窗（-Y 立面，门上方）+ 4 扇（+Y 背面）
    for x in (-7.60, -3.40, 2.20, 6.80):
        add_window(m, x, 6.15, 1.30, 1.60, -4.20, -1.0)
    for x in (-7.60, -3.40, 2.20, 6.80):
        add_window(m, x, 6.15, 1.30, 1.60, 4.20, 1.0)

    # 2 个屋脊通风帽
    for vx in (-6.20, 6.20):
        m.add(*box((vx - 0.56, -0.30, 10.30), (vx + 0.56, 0.30, 10.74)), DARK)
        m.add(*box((vx - 0.64, -0.36, 10.74), (vx + 0.64, 0.36, 10.84)), IRON)
        for sy in (-1.0, 1.0):
            m.add(*box((vx - 0.44, sy * 0.30, 10.40),
                       (vx + 0.44, sy * 0.30 + sy * 0.05, 10.64)), IRON)

    # 山墙吊货梁 + 滑轮 + 吊钩（+X 端，全部收在 x ≤ 10.0 内）
    m.add(*beam((9.20, 0.0, 8.92), (9.94, 0.0, 8.92), 0.26, 0.26), DARK)
    m.add(*beam((9.62, 0.0, 7.40), (9.86, 0.0, 8.78), 0.14, 0.14), DARK)
    m.add(*rod((9.82, 0.0, 8.90), (9.82, 0.0, 8.34), 0.05, 6), IRON)
    m.add(*rod((9.82, -0.05, 8.22), (9.82, 0.05, 8.22), 0.14, 8), IRON)
    m.add(*box((9.76, -0.05, 8.02), (9.88, 0.05, 8.20)), METAL)

    # 空白招牌板（-Y、两门之间，位于上下横梁之间）
    m.add(*box((-1.30, -4.20, 6.86), (1.30, -4.32, 7.46)), WOOD)
    for sx in (-1.0, 1.0):
        m.add(*box((sx * 1.10 - 0.06, -4.32, 6.82),
                   (sx * 1.10 + 0.06, -4.40, 7.50)), IRON)
    m.add(*box((-1.16, -4.32, 6.98), (1.16, -4.335, 7.34)), CANVAS)

    # 基座前两级石阶（在基座顶面上，不外扩）
    for i, (y0, z0, z1) in enumerate(((-4.30, 0.55, 0.72), (-4.12, 0.55, 0.63))):
        m.add(*box((-9.40, y0, z0), (9.40, y0 + 0.22, z1)), STONE)
    return m


# --------------------------------------------------------------------------- #
# 2. SN_HT_Warehouse_Short —— 短仓库 / 转运站（11.0 × 9.0 × 9.5）
# --------------------------------------------------------------------------- #

def build_warehouse_short():
    m = Part()
    # 石基座：定 11.0 × 9.0 落地轮廓
    m.add(*box((-5.50, -4.50, 0.00), (5.50, 4.50, 0.45)), STONE)
    m.add(*box((-5.40, -4.40, 0.45), (5.40, 4.40, 0.55)), STONE)
    # 木构墙主体（主仓 -2.20 ~ +4.20 深）
    m.add(*box((-5.20, -2.20, 0.48), (5.20, 4.20, 7.55)), WOOD)
    # 山墙（灰泥抹面三角）
    m.add(*tri_prism_x(-5.20, -4.92, -2.20, 4.20, 7.53, 9.33), PLASTER)
    m.add(*tri_prism_x(4.92, 5.20, -2.20, 4.20, 7.53, 9.33), PLASTER)
    # 不对称双坡屋面（脊线在 y=+1.00，脊顶 9.50）
    m.add(*roof_slab(-5.25, 5.25, -2.20, 7.55, 1.00, 9.33, 0.20), DARK)
    m.add(*roof_slab(-5.25, 5.25, 4.20, 7.55, 1.00, 9.33, 0.20), DARK)
    m.add(*box((-5.25, 0.82, 9.28), (5.25, 1.18, 9.50)), IRON)

    # 单坡侧棚（-Y，3.30 → 4.70，闭合板 + 3 根木柱 + 斜撑）
    m.add(*roof_slab(-5.20, 5.20, -4.44, 3.30, -2.20, 4.70, 0.12), CANVAS_SHADE)
    for x in (-4.90, 0.0, 4.90):
        m.add(*box((x - 0.08, -4.42, 0.45), (x + 0.08, -4.26, 3.42)), DARK)
        m.add(*box((x - 0.14, -4.50, 0.45), (x + 0.14, -4.18, 0.60)), STONE)
    for x in (-2.45, 2.45):
        m.add(*beam((x, -4.34, 0.62), (x, -2.24, 4.55), 0.10, 0.10), DARK)

    # 木构壁柱 / 横梁（-Y 立面）
    for x in (-5.02, -1.72, 1.72, 5.02):
        m.add(*box((x - 0.14, -2.20, 0.55), (x + 0.14, -2.34, 7.45)), DARK)
    for z in (1.60, 5.10):
        m.add(*box((-5.06, -2.20, z), (5.06, -2.33, z + 0.18)), DARK)

    # 单扇装卸门 + 滑轨
    m.add(*box((-1.55, -2.20, 0.55), (1.55, -2.26, 4.20)), DARK)
    for sx in (-1.0, 1.0):
        m.add(*box((sx * 1.66 - 0.11, -2.20, 0.55), (sx * 1.66 + 0.11, -2.34, 4.20)), WOOD)
    m.add(*box((-1.86, -2.20, 4.20), (1.86, -2.33, 4.40)), WOOD)
    m.add(*box((-1.92, -2.22, 4.42), (1.92, -2.30, 4.56)), IRON)

    # 2 扇窗（-Y，侧棚屋面以上）
    for x in (-3.60, 3.60):
        add_window(m, x, 5.75, 1.15, 1.45, -2.20, -1.0)

    # 屋顶通风管
    m.add(*rod((3.55, 2.55, 8.30), (3.55, 2.55, 9.34), 0.10, 8), METAL)
    m.add(*box((3.40, 2.40, 9.30), (3.70, 2.70, 9.42)), IRON)
    m.add(*box((3.36, 2.36, 9.26), (3.74, 2.74, 9.34)), IRON)

    # 空白招牌
    m.add(*box((-1.00, -2.20, 6.55), (1.00, -2.32, 7.10)), WOOD)
    for sx in (-1.0, 1.0):
        m.add(*box((sx * 0.86 - 0.05, -2.32, 6.50),
                   (sx * 0.86 + 0.05, -2.38, 7.15)), IRON)
    m.add(*box((-0.88, -2.32, 6.64), (0.88, -2.335, 7.02)), CANVAS)

    # 基座前石阶
    m.add(*box((-5.10, -4.34, 0.45), (5.10, -4.06, 0.62)), STONE)
    return m


# --------------------------------------------------------------------------- #
# 3. SN_HT_Harbor_Office —— 港务办公楼（9.0 × 8.0 × 14.0，最高地标）
# --------------------------------------------------------------------------- #

def build_harbor_office():
    m = Part()
    # 基座：定 9.0 × 8.0 落地轮廓（Y: -3.60 ~ +4.00，阳台外沿到 -4.00）
    m.add(*box((-4.50, -3.60, 0.00), (4.50, 4.00, 0.55)), STONE)
    m.add(*box((-4.42, -3.52, 0.55), (4.42, 3.94, 0.66)), STONE)
    # 三层砖石主体
    m.add(*box((-4.35, -3.45, 0.60), (4.35, 3.85, 9.40)), BRICK)
    # 顶层灰泥立面（-Y 面）+ 三道层间线脚
    m.add(*box((-4.32, -3.52, 6.70), (4.32, -3.45, 9.36)), PLASTER)
    for z in (3.55, 6.55):
        m.add(*box((-4.42, -3.58, z), (4.42, 3.92, z + 0.17)), STONE)
    m.add(*box((-4.50, -3.66, 9.40), (4.50, 4.00, 9.66)), STONE)

    # 拱形入口（-Y）：门板 + 两侧门框 + 半圆拱券
    m.add(*box((-1.02, -3.52, 0.56), (1.02, -3.45, 2.28)), DARK)
    for sx in (-1.0, 1.0):
        m.add(*box((sx * 1.16 - 0.12, -3.45, 0.56),
                   (sx * 1.16 + 0.12, -3.60, 2.30)), STONE)
    m.add(*arc_band(0.0, 2.28, 1.02, 1.28, -3.60, -3.45, 0.0, math.pi, 8), STONE)
    # 拱内上部暗色板（与门板同面，不发光；半圆多边形闭合到门板顶弦）
    half = [(1.00 * math.cos(math.pi * i / 8.0),
             2.28 + 1.00 * math.sin(math.pi * i / 8.0)) for i in range(9)]
    m.add(*prism_y(half, -3.50, -3.45), DARK)

    # 6 扇窗（-Y 立面，三层各 2 扇）
    for cz in (1.95, 4.85, 7.70):
        for x in (-2.70, 2.70):
            add_window(m, x, cz, 1.10, 1.60, -3.45, -1.0)
    # 侧面各 3 扇窗（+X / -X 立面）
    for sx in (-1.0, 1.0):
        for cz in (1.95, 4.85, 7.70):
            m.add(*box((sx * 4.35, -1.30, cz - 0.70),
                       (sx * 4.40, 1.30, cz + 0.70)), GLASS)
            m.add(*box((sx * 4.35, -1.42, cz + 0.70),
                       (sx * 4.42, 1.42, cz + 0.85)), STONE)

    # 2 层铁栏小阳台（-Y，中心 x=0，挑出到 y=-3.97）
    for z0 in (3.80, 6.80):
        m.add(*box((-1.45, -3.45, z0), (1.45, -3.97, z0 + 0.12)), STONE)
        add_railing(m, -1.38, 1.38, -3.94, z0 + 0.12, z0 + 1.02, posts=3, s=-1.0)
        for sx in (-1.0, 1.0):
            m.add(*beam((sx * 1.20, -3.50, z0 - 0.30),
                        (sx * 0.90, -3.90, z0 - 0.02), 0.09, 0.09), IRON)

    # 屋顶钟楼（塔身 3.2 × 3.2，顶到 14.00 的八角尖顶）
    m.add(*box((-1.60, -1.40, 9.62), (1.60, 1.80, 12.40)), BRICK)
    m.add(*box((-1.80, -1.60, 12.40), (1.80, 2.00, 12.66)), STONE)
    m.add(*box((-1.70, -1.50, 9.90), (1.70, 1.90, 10.06)), STONE)
    # 4 面钟盘（黄铜盘面 + 深色指针，无数字）
    ccz = 11.45
    for nx, ny in ((1.0, 0.0), (-1.0, 0.0), (0.0, -1.0), (0.0, 1.0)):
        cx = nx * 1.60
        cy = 0.20 + ny * 1.60
        p0 = (cx, cy, ccz)
        p1 = (cx + nx * 0.12, cy + ny * 0.12, ccz)
        m.add(*sweep(p0, p1, circle(10, 0.62)), BRASS)
        fx = cx + nx * 0.14
        fy = cy + ny * 0.14
        if nx != 0.0:
            m.add(*box((fx, fy - 0.025, ccz), (fx + nx * 0.04, fy + 0.025, ccz + 0.44)), IRON)
            m.add(*box((fx, fy - 0.30, ccz - 0.025), (fx + nx * 0.04, fy + 0.03, ccz + 0.025)), IRON)
        else:
            m.add(*box((fx - 0.025, fy, ccz), (fx + 0.025, fy + ny * 0.04, ccz + 0.44)), IRON)
            m.add(*box((fx - 0.30, fy, ccz - 0.025), (fx + 0.03, fy + ny * 0.04, ccz + 0.025)), IRON)
    # 塔身百叶窗 / 门洞暗板：0.08 m 厚、外凸 0.01 m（其余 0.07 m 嵌入塔面），不挡钟盘
    for nx, ny in ((1.0, 0.0), (-1.0, 0.0), (0.0, -1.0), (0.0, 1.0)):
        px = nx * 1.60
        py = 0.20 + ny * 1.60
        if nx != 0.0:
            m.add(*box((px - nx * 0.07, py - 0.19, 10.12),
                       (px + nx * 0.01, py + 0.19, 10.78)), GLASS)
        else:
            m.add(*box((px - 0.19, py - ny * 0.07, 10.12),
                       (px + 0.19, py + ny * 0.01, 10.78)), GLASS)
    # 八角尖顶（12.66 → 14.00）
    m.add(*revolved([(12.66, 1.10), (13.30, 0.62), (14.00, 0.07)], 8), IRON)
    m.add(*rod((0.0, 0.20, 13.96), (0.0, 0.20, 14.00), 0.05, 6), BRASS)

    # 屋角旗杆座 + 旗杆
    m.add(*box((3.10, 3.05, 9.62), (3.82, 3.70, 9.98)), STONE)
    m.add(*rod((3.46, 3.38, 9.96), (3.46, 3.38, 11.60), 0.05, 8), METAL)
    m.add(*box((3.38, 3.30, 11.58), (3.54, 3.46, 11.70)), BRASS)

    # 空白门牌 / 招牌板（顶层立面）
    m.add(*box((-1.10, -3.45, 8.30), (1.10, -3.53, 8.86)), WOOD)
    m.add(*box((-0.98, -3.53, 8.38), (0.98, -3.535, 8.78)), CANVAS)
    return m


# --------------------------------------------------------------------------- #
# 4. SN_HT_Cargo_Shed —— 开放式货棚（8.0 × 6.0 × 4.5）
# --------------------------------------------------------------------------- #

def build_cargo_shed():
    m = Part()
    # 4 根木柱（脚落在 +/-3.50, +/-2.55）；石柱础
    for x in (-3.50, 3.50):
        for y in (-2.55, 2.55):
            m.add(*box((x - 0.10, y - 0.10, 0.00), (x + 0.10, y + 0.10, 0.22)), STONE)
            m.add(*box((x - 0.075, y - 0.075, 0.20), (x + 0.075, y + 0.075, 3.72)), WOOD)
    # 柱头横梁（沿 X / 沿 Y）
    for y in (-2.55, 2.55):
        m.add(*box((-3.50, y - 0.07, 3.45), (3.50, y + 0.07, 3.72)), DARK)
    for x in (-3.50, 3.50):
        m.add(*box((x - 0.07, -2.55, 3.45), (x + 0.07, 2.55, 3.72)), DARK)
    # 双坡屋面（帆布/木顶，闭合双面板；檐口 y=±3.00，脊顶 4.50）
    m.add(*roof_slab(-4.00, 4.00, -2.96, 3.55, 0.0, 4.367, 0.14), CANVAS)
    m.add(*roof_slab(-4.00, 4.00, 2.96, 3.55, 0.0, 4.367, 0.14), CANVAS)
    m.add(*box((-4.00, -0.20, 4.30), (4.00, 0.20, 4.50)), DARK)
    # 屋面横椽（3 道，从檐口搭到屋脊，下垂 80 mm 露在帆布下方）
    for x in (-1.60, 0.0, 1.60):
        m.add(*beam((x, -2.96, 3.48), (x, 0.0, 4.29), 0.10, 0.10), DARK)
        m.add(*beam((x, 2.96, 3.48), (x, 0.0, 4.29), 0.10, 0.10), DARK)
    # 后挡板（+Y）
    for x in (-3.44, 3.44):
        m.add(*box((x - 0.06, 2.48, 0.20), (x + 0.06, 2.62, 3.45)), DARK)
    m.add(*box((-3.50, 2.55, 0.18), (3.50, 2.66, 3.00)), WOOD)
    m.add(*box((-3.44, 2.48, 2.98), (3.44, 2.62, 3.14)), DARK)
    # 工作台（+X 侧）
    m.add(*box((1.60, -1.05, 0.92), (3.40, 1.05, 1.04)), DECK)
    for y in (-0.90, 0.90):
        m.add(*box((1.66, y - 0.06, 0.00), (1.80, y + 0.06, 0.92)), DARK)
        m.add(*box((3.20, y - 0.06, 0.00), (3.34, y + 0.06, 0.92)), DARK)
    m.add(*box((1.62, -0.95, 0.34), (3.38, 0.95, 0.44)), DARK)
    # 2 个木箱
    add_crate(m, -2.30, -1.35, 0.72)
    add_crate(m, -2.55, 1.45, 0.60)
    # 2 个吊挂钩（从柱头横梁垂下）
    for x, y in ((-0.90, -2.55), (1.00, -2.55)):
        m.add(*rod((x, y, 3.45), (x, y, 2.72), 0.030, 6), METAL)
        m.add(*beam((x, y, 2.72), (x + 0.14, y, 2.60), 0.05, 0.05), IRON)
        m.add(*rod((x + 0.14, y, 2.60), (x + 0.14, y, 2.44), 0.035, 6), IRON)
    # 对角斜撑（4 面各 1 根）
    for x, y in ((-3.50, -2.55), (3.50, -2.55)):
        m.add(*beam((x, y, 3.20), (x - math.copysign(0.55, x), y, 2.40), 0.08, 0.08), DARK)
    return m


# --------------------------------------------------------------------------- #
# 5. SN_HT_Tavern —— 码头酒馆（10.0 × 8.0 × 8.0）
# --------------------------------------------------------------------------- #

def build_tavern():
    m = Part()
    # 石基座：定 10.0 × 8.0 落地轮廓
    m.add(*box((-5.00, -4.00, 0.00), (5.00, 4.00, 0.40)), STONE)
    m.add(*box((-4.90, -3.90, 0.40), (4.90, 3.90, 0.50)), STONE)
    # 墙体：下层砖裙 + 上层灰泥
    m.add(*box((-4.80, -3.45, 0.44), (4.80, 3.45, 1.70)), BRICK)
    m.add(*box((-4.80, -3.45, 1.66), (4.80, 3.45, 6.68)), PLASTER)
    # 二层腰线
    m.add(*box((-4.86, -3.51, 3.52), (4.86, 3.51, 3.70)), STONE)
    # 山墙（两端三角）+ 双坡屋面（檐口贴墙顶 6.68，脊顶 8.00）
    m.add(*tri_prism_x(-4.80, -4.46, -3.45, 3.45, 6.66, 7.83), PLASTER)
    m.add(*tri_prism_x(4.46, 4.80, -3.45, 3.45, 6.66, 7.83), PLASTER)
    m.add(*roof_slab(-4.90, 4.90, -3.45, 6.68, 0.0, 7.83, 0.18), DARK)
    m.add(*roof_slab(-4.90, 4.90, 3.45, 6.68, 0.0, 7.83, 0.18), DARK)
    m.add(*box((-4.90, -0.20, 7.80), (4.90, 0.20, 8.00)), IRON)
    # 山墙横向系梁（两端各 1 道，贴在 eave 高度）
    for sx in (-1.0, 1.0):
        m.add(*box((sx * 4.80 - 0.04, -3.30, 6.70), (sx * 4.80 + 0.04, 3.30, 6.92)), DARK)
    # 正面木构（-Y）：4 根壁柱 + 2 道横梁 + 2 根斜撑
    for x in (-4.66, -1.50, 1.50, 4.66):
        m.add(*box((x - 0.12, -3.45, 0.50), (x + 0.12, -3.58, 6.60)), DARK)
    for z in (3.30, 6.20):
        m.add(*box((-4.72, -3.45, z), (4.72, -3.58, z + 0.18)), DARK)
    for x, dx in ((-4.50, 1.0), (1.70, 1.0)):
        m.add(*beam((x, -3.60, 3.48), (x + dx * 1.70, -3.60, 4.30), 0.10, 0.10), DARK)

    # 门廊：2 柱 + 小雨棚（挑出到 y=-3.96，收在 4.00 内）
    for sx in (-1.0, 1.0):
        m.add(*box((sx * 1.72 - 0.08, -3.96, 0.42), (sx * 1.72 + 0.08, -3.80, 3.16)), WOOD)
        m.add(*box((sx * 1.72 - 0.14, -4.00, 0.42), (sx * 1.72 + 0.14, -3.74, 0.56)), STONE)
        m.add(*beam((sx * 1.72, -3.86, 3.06), (sx * 1.72, -3.58, 2.68), 0.07, 0.07), DARK)
    m.add(*roof_slab(-2.05, 2.05, -3.94, 3.10, -3.45, 3.46, 0.10), DARK)
    m.add(*box((-2.05, -3.98, 3.04), (2.05, -3.45, 3.14)), WOOD)
    # 门 + 石阶（门在门廊内）
    add_door(m, 0.0, 0.44, 1.15, 2.60, -3.45, -1.0)
    m.add(*box((-1.40, -3.92, 0.40), (1.40, -3.52, 0.52)), STONE)
    m.add(*box((-1.32, -3.90, 0.52), (1.32, -3.60, 0.60)), STONE)

    # 4 扇窗（-Y 立面，上下层各 2）
    for cz in (1.10, 4.90):
        for x in (-2.95, 2.95):
            add_window(m, x, cz, 1.05, 1.35, -3.45, -1.0)
    # 山墙小窗（+X 山墙，尖顶下方）
    m.add(*box((4.80, -0.45, 6.90), (4.86, 0.45, 7.55)), GLASS)

    # 悬挂空白招牌（门廊右柱外侧铁支架 + 木牌）
    m.add(*beam((1.72, -3.86, 3.06), (1.72, -3.62, 3.30), 0.07, 0.07), IRON)
    m.add(*beam((1.72, -3.62, 3.30), (2.55, -3.62, 3.30), 0.07, 0.07), IRON)
    for x in (1.92, 2.38):
        m.add(*rod((x, -3.62, 3.30), (x, -3.62, 3.00), 0.018, 6), IRON)
    m.add(*box((1.82, -3.70, 2.52), (2.48, -3.62, 3.02)), WOOD)
    m.add(*box((1.90, -3.715, 2.60), (2.40, -3.70, 2.94)), CANVAS)

    # 烟囱（+Y 坡屋面，砖砌 + 石压顶）
    m.add(*box((3.20, 1.55, 7.10), (3.90, 2.25, 7.92)), BRICK)
    m.add(*box((3.12, 1.47, 7.92), (3.98, 2.33, 8.00)), STONE)
    # 门前 2 只木桶
    add_barrel(m, -3.15, -3.12, 0.34, 0.72)
    add_barrel(m, 3.30, -2.95, 0.32, 0.68)
    # 门廊挂灯：吊杆顶嵌入门廊梁底 10 mm（梁底 3.04 < 吊杆顶 3.05），灯体挂在门洞左侧、不挡门
    add_lantern(m, -1.15, -3.80, 3.05, hook_len=0.12, body=METAL)
    return m


# --------------------------------------------------------------------------- #
# 6. SN_HT_Fence_Row —— 岸线围栏模块（6.0 × 0.30 × 1.5）
# --------------------------------------------------------------------------- #

def build_fence_row():
    m = Part()
    # 石基条：定 6.0 × 0.30 轮廓，高度 0.18
    m.add(*box((-3.00, -0.15, 0.00), (3.00, 0.15, 0.18)), STONE)
    m.add(*box((-2.94, -0.12, 0.18), (2.94, 0.12, 0.24)), STONE)
    # 6 根铁立柱（x = -2.90 ... +2.90，间距 1.16；端柱贴近模块边缘便于首尾相接）+ 柱帽 + 尖顶
    xs = [-2.90 + 1.16 * i for i in range(6)]
    for x in xs:
        m.add(*box((x - 0.055, -0.055, 0.16), (x + 0.055, 0.055, 1.30)), IRON)
        m.add(*box((x - 0.085, -0.085, 1.30), (x + 0.085, 0.085, 1.40)), IRON)
        m.add(*tb(x - 0.060, x + 0.060, -0.060, 0.060, 1.40, 1.50, 0.035), IRON)
    # 2 道横栏（贯通全模块，端头贴在柱心）
    for z in (0.56, 0.96):
        m.add(*box((xs[0], -0.035, z), (xs[-1], 0.035, z + 0.09)), IRON)
    return m


# --------------------------------------------------------------------------- #
# 7. SN_HT_Dock_Worker_A —— 站立张望的码头工人剪影（0.7 × 0.45 × 1.8）
# --------------------------------------------------------------------------- #

def build_dock_worker_a():
    m = Part()
    # 靴子（铁头靴，深色）
    for sy in (-1.0, 1.0):
        m.add(*box((-0.24, sy * 0.11 - 0.075, 0.0), (0.20, sy * 0.11 + 0.075, 0.17)), METAL)
    # 裤腿（宽裤）
    for sy in (-1.0, 1.0):
        m.add(*tb(-0.17, 0.13, sy * 0.11 - 0.068, sy * 0.11 + 0.068, 0.15, 0.84, 0.012),
              DARK)
    # 短外套：下摆宽、胸口收（剪影优先，全深色）
    m.add(*tb(-0.22, 0.20, -0.20, 0.20, 0.58, 1.18, 0.02), DARK)
    m.add(*tb(-0.20, 0.18, -0.19, 0.19, 1.15, 1.46, 0.03), DARK)
    # 腰带（铁扣）+ 浅色领巾（小块浅色只做领口识别，不破坏深色剪影）
    m.add(*box((-0.206, -0.208, 0.98), (0.206, 0.208, 1.05)), METAL)
    m.add(*box((-0.085, -0.085, 1.46), (0.085, 0.085, 1.52)), CANVAS_SHADE)
    # 领口 / 脖子
    m.add(*box((-0.06, -0.06, 1.43), (0.06, 0.06, 1.53)), DARK)
    # 头
    m.add(*tb(-0.11, 0.12, -0.115, 0.115, 1.50, 1.71, 0.02), DARK)
    # 鸭舌帽：帽筒 + 朝 +X 的帽檐
    m.add(*box((-0.115, -0.12, 1.69), (0.115, 0.12, 1.80)), DARK)
    m.add(*box((0.02, -0.115, 1.665), (0.38, 0.115, 1.705)), DARK)
    # 双臂（外套袖）+ 手（深色）
    for sy in (-1.0, 1.0):
        m.add(*tb(-0.10, 0.10, sy * 0.205 - 0.042, sy * 0.205 + 0.042, 1.06, 1.44, 0.012),
              DARK)
        m.add(*tb(-0.085, 0.095, sy * 0.205 - 0.036, sy * 0.205 + 0.036, 0.84, 1.08, 0.01),
              METAL)
    return m


# --------------------------------------------------------------------------- #
# 8. SN_HT_Dock_Worker_B —— 抱箱前倾的码头工人剪影（0.8 × 0.5 × 1.8）
# --------------------------------------------------------------------------- #

def build_dock_worker_b():
    m = Part()
    # 靴子（前倾，脚尖朝 +X）
    for sy in (-1.0, 1.0):
        m.add(*box((-0.22, sy * 0.115 - 0.075, 0.0), (0.16, sy * 0.115 + 0.075, 0.16)), METAL)
    # 腿（微屈）
    for sy in (-1.0, 1.0):
        m.add(*tb(-0.16, 0.10, sy * 0.115 - 0.068, sy * 0.115 + 0.068, 0.14, 0.86, 0.015),
              DARK)
    # 躯干（前倾：上沿比下沿更靠 +X）
    m.add(*hexa(rect_pts(-0.19, 0.16, -0.195, 0.195, 0.80),
                rect_pts(-0.10, 0.25, -0.185, 0.185, 1.44)), DARK)
    # 浅色领巾（唯一浅色小块，帮助区分头肩）
    m.add(*box((-0.02, -0.10, 1.30), (0.10, 0.10, 1.40)), CANVAS_SHADE)
    # 脖子 / 头 / 帽（头略前探）
    m.add(*box((0.01, -0.06, 1.42), (0.12, 0.06, 1.52)), DARK)
    m.add(*tb(0.00, 0.22, -0.115, 0.115, 1.49, 1.70, 0.02), DARK)
    m.add(*box((-0.01, -0.12, 1.68), (0.22, 0.12, 1.80)), DARK)
    m.add(*box((0.20, -0.115, 1.655), (0.40, 0.115, 1.695)), DARK)
    # 双臂前伸环抱木箱
    for sy in (-1.0, 1.0):
        m.add(*tb(-0.06, 0.20, sy * 0.205 - 0.045, sy * 0.205 + 0.045, 1.10, 1.34, 0.0),
              DARK)
        m.add(*tb(0.18, 0.42, sy * 0.205 - 0.042, sy * 0.205 + 0.042, 1.04, 1.30, 0.0),
              DARK)
        m.add(*box((0.38, sy * 0.19 - 0.035, 1.02), (0.50, sy * 0.19 + 0.035, 1.24)), METAL)
    # 木箱（抱在胸前，x 0.18 ~ 0.52）
    m.add(*box((0.18, -0.19, 1.00), (0.52, 0.19, 1.28)), WOOD)
    for x in (0.25, 0.45):
        m.add(*box((x - 0.03, -0.205, 1.05), (x + 0.03, -0.19, 1.23)), DARK)
    return m


# --------------------------------------------------------------------------- #
# 9. SN_HT_Rowboat —— 系泊小划艇（4.2 × 1.5 × 0.8）
# --------------------------------------------------------------------------- #

def build_rowboat():
    m = Part()
    # 船壳：9 站放样，截面为"U 形 + 甲板弦"闭合多边形（甲板面 z=0.70）
    stations = [
        (2.10, 0.12), (1.65, 0.40), (1.20, 0.57), (0.60, 0.68),
        (0.00, 0.72), (-0.60, 0.72), (-1.20, 0.67), (-1.70, 0.54), (-2.10, 0.30),
    ]
    rings = []
    for x, hw in stations:
        rings.append([
            (x, -hw, 0.70), (x, -hw, 0.40), (x, -0.62 * hw, 0.14),
            (x, -0.22 * hw, 0.00), (x, 0.22 * hw, 0.00), (x, 0.62 * hw, 0.14),
            (x, hw, 0.40), (x, hw, 0.70),
        ])
    m.add(*loft(rings), WOOD)
    # 舷缘压条：沿甲板边折线（9 站 → 每侧 8 段闭合 beam），端部贴住船壳、无横向悬空；
    # 首尾两段沿段向内收 26 mm，避免斜切端盖把 X 包围盒顶出 4.2 m
    def _pull(a, b, dist):
        dx, dy = b[0] - a[0], b[1] - a[1]
        length = math.hypot(dx, dy)
        return (a[0] + dx / length * dist, a[1] + dy / length * dist, a[2])

    for sy in (-1.0, 1.0):
        pts = [(x, sy * hw, 0.70) for x, hw in stations]
        for k in range(len(pts) - 1):
            p0, p1 = pts[k], pts[k + 1]
            if k == 0:
                p0 = _pull(p0, p1, 0.026)
            if k == len(pts) - 2:
                p1 = _pull(p1, p0, 0.026)
            m.add(*beam(p0, p1, 0.06, 0.12), DARK)
    # 舱内深色板（读作开口）+ 2 道坐板
    m.add(*box((-1.50, -0.55, 0.70), (1.42, 0.55, 0.722)), DECK)
    for x in (-0.95, 0.55):
        m.add(*box((x - 0.10, -0.64, 0.722), (x + 0.10, 0.64, 0.79)), WOOD)
    # 艏柱（到 0.80）+ 艉板
    m.add(*box((1.94, -0.075, 0.52), (2.10, 0.075, 0.80)), DARK)
    m.add(*box((-2.10, -0.32, 0.50), (-1.94, 0.32, 0.78)), DARK)
    # 艏部系缆环
    m.add(*box((1.90, -0.05, 0.60), (2.04, 0.05, 0.68)), IRON)
    m.add(*rod((1.97, 0.0, 0.68), (1.97, 0.0, 0.74), 0.035, 6), IRON)
    # 2 支桨（斜搭在坐板与舷缘之间，桨叶收在船壳线内）
    for sy in (-1.0, 1.0):
        m.add(*beam((-1.45, sy * 0.16, 0.75), (1.18, sy * 0.48, 0.77), 0.055, 0.05), WOOD)
        m.add(*beam((1.18, sy * 0.48, 0.77), (1.46, sy * 0.52, 0.772), 0.100, 0.026), DECK)
    # 船底两条龙骨条（贴底，避免悬空）
    for sy in (-1.0, 1.0):
        m.add(*box((-1.60, sy * 0.10, 0.0), (1.30, sy * 0.16, 0.03)), DARK)
    return m


# --------------------------------------------------------------------------- #
# 10. SN_HT_Cargo_Lighter —— 平底驳船（8.0 × 3.0 × 1.6）
# --------------------------------------------------------------------------- #

def build_cargo_lighter():
    m = Part()
    # 平底船壳：定 8.0 × 3.0 轮廓（舷侧板外凸到 ±1.50）
    m.add(*box((-3.96, -1.44, 0.00), (3.96, 1.44, 0.85)), DECK)
    # 两道舷侧腰板（外凸 0.06，定出 Y=3.0）
    for sy in (-1.0, 1.0):
        m.add(*box((-3.96, sy * 1.44, 0.16), (3.96, sy * 1.50, 0.32)), DARK)
        m.add(*box((-3.96, sy * 1.44, 0.46), (3.96, sy * 1.50, 0.62)), DARK)
        m.add(*box((-3.96, sy * 1.44, 0.80), (3.96, sy * 1.50, 0.88)), WOOD)
    # 前后舷板（x 到 ±4.00）
    for sx in (-1.0, 1.0):
        m.add(*box((sx * 3.96, -1.44, 0.00), (sx * 4.00, 1.44, 0.85)), DECK)
    # 舷墙（内壁 0.85 → 1.22）
    for sy in (-1.0, 1.0):
        m.add(*box((-3.90, sy * 1.30, 0.85), (3.90, sy * 1.44, 1.22)), WOOD)
    for sx in (-1.0, 1.0):
        m.add(*box((sx * 3.72, -1.44, 0.85), (sx * 3.90, 1.44, 1.22)), WOOD)
        m.add(*box((sx * 3.70, -1.46, 1.18), (sx * 3.92, 1.46, 1.26)), DARK)
    # 甲板（比舷墙内收 0.14）
    m.add(*box((-3.72, -1.30, 0.80), (3.72, 1.30, 0.87)), DARK)
    # 甲板货箱
    add_crate(m, 2.35, 0.0, 0.72, z0=0.87)
    # 小舱棚（艉部）
    m.add(*box((-2.95, -0.98, 0.86), (-1.15, 0.98, 1.38)), DARK)
    m.add(*box((-3.08, -1.10, 1.36), (-1.02, 1.10, 1.46)), WOOD)
    m.add(*box((-3.08, -1.10, 1.46), (-1.02, 1.10, 1.50)), CANVAS_SHADE)
    # 舱棚门（+X 面暗板）
    m.add(*box((-1.15, -0.22, 0.87), (-1.09, 0.22, 1.30)), DARK)
    # 舵柄：立柱 + 斜柄（顶 1.60）
    m.add(*box((-3.62, -0.09, 0.86), (-3.44, 0.09, 1.50)), DARK)
    m.add(*beam((-3.53, 0.0, 1.46), (-2.95, 0.0, 1.56), 0.09, 0.08), WOOD)
    # 2 个系缆桩
    for sy in (-1.0, 1.0):
        add_bollard(m, 3.20, sy * 1.12, 0.36, z0=0.87, mat=IRON, r=0.10)
        add_bollard(m, -3.50, sy * 1.12, 0.34, z0=0.87, mat=IRON, r=0.09)
    # 舱棚顶小通风帽
    m.add(*rod((-1.55, 0.0, 1.50), (-1.55, 0.0, 1.60), 0.10, 8), METAL)
    return m


# --------------------------------------------------------------------------- #
# 注册表
# --------------------------------------------------------------------------- #

BUILDERS = {
    "SN_HT_Warehouse_Long": build_warehouse_long,
    "SN_HT_Warehouse_Short": build_warehouse_short,
    "SN_HT_Harbor_Office": build_harbor_office,
    "SN_HT_Cargo_Shed": build_cargo_shed,
    "SN_HT_Tavern": build_tavern,
    "SN_HT_Fence_Row": build_fence_row,
    "SN_HT_Dock_Worker_A": build_dock_worker_a,
    "SN_HT_Dock_Worker_B": build_dock_worker_b,
    "SN_HT_Rowboat": build_rowboat,
    "SN_HT_Cargo_Lighter": build_cargo_lighter,
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


def build_all(collection_name=COLLECTION):
    import bpy

    collection = _ensure_collection()

    # 重跑：只清掉本集合内本批 SN_HT_ 对象（不碰其他对象，也不碰其他集合）
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


def _regression_digest():
    import bpy
    import hashlib
    import json
    rows = []
    for o in bpy.data.objects:
        if o.name.startswith(PREFIX):
            continue
        tris = 0
        if o.type == "MESH" and o.data:
            o.data.calc_loop_triangles()
            tris = len(o.data.loop_triangles)
        rows.append((o.name, o.type, tuple(round(v, 5) for v in o.location), tris))
    rows.sort()
    return hashlib.sha256(json.dumps(rows, default=str).encode()).hexdigest(), len(rows)


def report():
    import bpy
    import bmesh

    out = {"items": [], "total_tris": 0, "health": {}, "scene": {}, "layout": {}}
    collection = bpy.data.collections.get(COLLECTION) or _ensure_collection()

    for name, pos, budget, size in ITEMS:
        obj = bpy.data.objects.get(name)
        if obj is None:
            out["items"].append({"name": name, "missing": True})
            continue
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
            "in_collection": obj.name in collection.objects,
            "prefix_ok": name.startswith(PREFIX),
            "location": [round(v, 4) for v in obj.location],
            "tris": tris,
            "budget": budget,
            "tris_within_budget": tris <= int(budget * 1.2),
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
        })
        out["total_tris"] += tris

    items = [i for i in out["items"] if "missing" not in i]
    names = sorted(i["name"] for i in items)
    out["layout"] = {
        "collection": sorted(o.name for o in collection.objects),
        "collection_count": len(collection.objects),
        "names_unique": len(names) == len(set(names)),
        "all_prefix": all(n.startswith(PREFIX) for n in names),
        "all_in_collection": all(i["in_collection"] for i in items),
        "all_grounded": all(abs(i["zmin"]) <= 1e-6 for i in items),
        "location_ok": all(
            abs(i["location"][0] - ITEMS[k][1][0]) < 1e-6
            and abs(i["location"][1] - ITEMS[k][1][1]) < 1e-6
            and abs(i["location"][2] - ITEMS[k][1][2]) < 1e-6
            for k, i in enumerate(items)),
    }

    out["health"] = {
        "all_manifold": all(i["non_manifold_edges"] == 0 for i in items),
        "no_boundary": all(i["boundary_edges"] == 0 for i in items),
        "no_loose": all(i["loose_verts"] == 0 for i in items),
        "no_degenerate": all(i["degenerate_faces"] == 0 for i in items),
        "no_mat_overflow": all(i["mat_slot_overflow"] == 0 for i in items),
        "all_within_1_2x_budget": all(i["tris_within_budget"] for i in items),
        "total_within_budget": out["total_tris"] <= TOTAL_BUDGET,
        "all_sizes_ok": all(abs(d) <= 0.15 for i in items for d in i["size_delta"]),
        "palette_only": all(i["materials_in_palette"] for i in items),
    }

    digest, obj_count = _regression_digest()
    out["scene"] = {
        "objects": len(bpy.data.objects),
        "mesh": sum(1 for o in bpy.data.objects if o.type == "MESH"),
        "materials": sorted(m.name for m in bpy.data.materials),
        "regression_digest": digest,
        "regression_matches_baseline": digest == BASELINE_DIGEST,
        "regression_object_count": obj_count,
        "baseline_objects": 234,
    }
    print("HARBOR_TOWN_REPORT " + repr(out))
    return out


if __name__ == "__main__":
    build_all()
    report()
