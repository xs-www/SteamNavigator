# -*- coding: utf-8 -*-
"""Steam Navigator — 铁港建筑套件：`SN_HT_Tavern` LOD0 生成器（纯 Python 几何）。

工单：tools/modeling/briefs/sn_iron_harbor_architecture_kit_v1.json（`tavern`）
集合 / 对象名 / 轴心 / 尺寸与旧占位资产一致（10.0 × 8.0 × 8.0 m，轴心 = 底面中心）；
几何函数不 import bpy，可 `dryrun_props.py` 离线干跑；材质与 UV 由
`sn_iron_harbor_materials` 在 Blender 侧统一写入（本文件只分配 6 个调色板材质槽）。

设计要点
--------
- **主立面在本地 +X 端面**：`port_stage.gd` 的 `TOWN_SLOTS` 给 tavern 槽位 yaw −100°，
  资产本地 +X 正对 PortStage 固定机位（偏轴约 43°，仍清晰可见）；+Y 侧墙是次可见面
  （掠射约 47°），−X 背面放服务门。
- 两层立面：首层砖（0.43–3.90）、二层灰泥（3.90–6.60），层间石腰带打断；+X 是山墙端，
  屋顶双坡（脊线沿 X，脊顶 7.60、檐口 6.60），屋面铁板厚 0.22、出挑 0.30、带脊瓦与立缝。
- 门廊：主体 +X 外皮退到 3.90，门廊从 3.90 挑到 5.00（= 包围盒），2 根木柱 + 斜撑 +
  单坡廊顶，把入口包在山墙下。
- 轮廓识别点（不依赖颜色）：① 8.00 m 高的砖烟囱（在 −X 端）；② 悬挂空白招牌（+X 立面上，
  铁托架 + 木牌，无文字）；③ 门廊柱廊与山墙三角。
- 所有开口都是 `panel()` 生成的**真凹口**（窗 0.14–0.16 m、门 0.20–0.28 m），
  不是共面深色贴片；倒角走显式几何（vchamfer_box / 型材轮廓 / 屋面板 2 段倒角）。
"""

import math

# --------------------------------------------------------------------------- #
# 资产与材质
# --------------------------------------------------------------------------- #

ASSET = "SN_HT_Tavern"
NAME = ASSET + "_LOD0"
TARGET_SIZE = (10.0, 8.0, 8.0)
TRI_BUDGET = 8000
TRI_FLOOR = 5000

BRICK = "SN_Town_Brick"
PLASTER = "SN_Town_Plaster"
WOOD = "SN_Town_Wood"
IRON = "SN_Town_Iron"
STONE = "SN_Town_Stone"
GLASS = "SN_Town_Glass"
PALETTE = (BRICK, PLASTER, WOOD, IRON, STONE, GLASS)

# --------------------------------------------------------------------------- #
# 体量（局部坐标：X 长轴 ±5.0，Y 进深 ±4.0，Z 0 → 8.0）
# --------------------------------------------------------------------------- #

HALF_X, HALF_Y = 5.0, 4.0
PLINTH_TOP = 0.45          # 石基压顶
WALL_XF = 3.90             # +X 主立面外皮（门廊从这里挑到 +5.00）
WALL_XB = -4.70            # -X 背面外皮
WALL_Y = 3.70             # ±Y 侧墙外皮
PANEL_T = 0.40             # 主立面墙板厚
SIDE_T = 0.34              # 侧墙 / 背墙板厚
STOREY_Z = 3.90            # 首层 / 二层分界
EAVE_Z = 6.60              # 檐口（墙顶）
RIDGE_Z = 7.60             # 屋脊底皮
ROOF_T = 0.22              # 屋面板厚
ROOF_Y = 4.00              # 屋面檐口外沿（= HALF_Y）
ROOF_XB = -4.95            # 屋面 -X 出挑
ROOF_XF = 4.15             # 屋面 +X 山墙出挑
ROOF_SLOPE = (RIDGE_Z - EAVE_Z) / WALL_Y
ROOF_EAVE_Z = RIDGE_Z - ROOF_Y * ROOF_SLOPE     # 檐口处屋面底皮 6.519
PORCH_X = 5.00             # 门廊外沿 = 包围盒 +X
PORCH_HALF_W = 2.10        # 门廊半宽
PORCH_EAVE_Z = 3.40        # 廊顶外沿板底
PORCH_TOP_Z = 3.98         # 廊顶贴墙处板底
CHIMNEY_TOP = 8.00         # 烟囱顶 = 包围盒最高点
WALL_Z0 = PLINTH_TOP - 0.02  # 墙板底（嵌入石基 0.02）

# --------------------------------------------------------------------------- #
# 立面开洞表：(u0, u1, v0, v1, 凹深, 凹底材质)
# u = 立面水平坐标（+X/−X 面为 Y，±Y 面为 X），v = Z
# --------------------------------------------------------------------------- #

FRONT_LOW = [
    (-0.62, 0.62, 0.44, 2.79, 0.28, WOOD),    # 入口双开门（凹 0.28）
    (-2.75, -1.62, 1.55, 2.90, 0.16, GLASS),  # 首层左窗
    (1.62, 2.75, 1.55, 2.90, 0.16, GLASS),    # 首层右窗
]
FRONT_HIGH = [
    (-2.70, -1.78, 4.55, 5.75, 0.14, GLASS),
    (-0.46, 0.46, 4.55, 5.75, 0.14, GLASS),
    (1.78, 2.70, 4.55, 5.75, 0.14, GLASS),
]
BACK_LOW = [
    (-0.55, 0.55, 0.44, 2.54, 0.20, WOOD),    # 后侧服务门
]
BACK_HIGH = [
    (-2.60, -1.70, 4.70, 5.70, 0.14, GLASS),
    (1.70, 2.60, 4.70, 5.70, 0.14, GLASS),
]
RIGHT_LOW = [
    (-3.30, -2.20, 1.55, 2.90, 0.16, GLASS),
    (0.40, 1.50, 1.55, 2.90, 0.16, GLASS),
]
RIGHT_HIGH = [
    (-3.20, -2.35, 4.55, 5.75, 0.14, GLASS),
    (0.30, 1.15, 4.55, 5.75, 0.14, GLASS),
    (2.00, 2.85, 4.55, 5.75, 0.14, GLASS),
]
LEFT_LOW = [
    (-3.30, -2.20, 1.55, 2.90, 0.16, GLASS),
]
LEFT_HIGH = [
    (-3.20, -2.35, 4.55, 5.75, 0.14, GLASS),
]

DESIGN = {
    "facade_side": "+X（PortStage 固定机位可见的端立面）",
    "secondary_side": "+Y（掠射可见，带窗节奏）",
    "storeys": 2,
    "storey_split_m": STOREY_Z,
    "porch": True,
    "porch_out_m": round(PORCH_X - WALL_XF, 3),
    "hanging_sign": True,
    "chimney": True,
    "chimney_top_m": CHIMNEY_TOP,
    "windows": len(FRONT_LOW) + len(FRONT_HIGH) + len(BACK_LOW) + len(BACK_HIGH)
                 + len(RIGHT_LOW) + len(RIGHT_HIGH) + len(LEFT_LOW) + len(LEFT_HIGH),
    "window_recess_m": 0.14,
    "doors": 2,
    "front_door_recess_m": 0.28,
    "service_door_recess_m": 0.20,
    "wall_thickness_m": PANEL_T,
    "roof_type": "gable_ridge_x",
    "roof_thickness_m": ROOF_T,
    "roof_overhang_m": round(ROOF_Y - WALL_Y, 3),
    "barrels": 3,
    "downpipes": 2,
    "gutters": 2,
    "pilasters": 2,
    "storey_band": True,
}

ITEMS = [(NAME, (0.0, 0.0, 0.0), TRI_BUDGET, TARGET_SIZE)]
TOTAL_BUDGET = TRI_BUDGET

class Part:
    """顶点 / 面 / 每面材质的累积器。"""

    def __init__(self):
        self.verts = []
        self.faces = []

    def add(self, verts, faces, material):
        offset = len(self.verts)
        self.verts.extend(verts)
        for face in faces:
            self.faces.append((tuple(i + offset for i in face), material))

    def add_multi(self, verts, faces):
        """faces 已是 (索引元组, 材质) 形式。"""
        offset = len(self.verts)
        self.verts.extend(verts)
        for face, material in faces:
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
    """轴对齐闭合盒；端点自动排序。"""
    x0, x1 = sorted((lo[0], hi[0]))
    y0, y1 = sorted((lo[1], hi[1]))
    z0, z1 = sorted((lo[2], hi[2]))
    return hexa(rect_pts(x0, x1, y0, y1, z0), rect_pts(x0, x1, y0, y1, z1))


def tb(x0, x1, y0, y1, z0, z1, ti=0.0):
    """收分盒：顶面相对底面四边各内收 ti（石基斜面 / 帽盖倒角）。"""
    x0, x1 = sorted((x0, x1))
    y0, y1 = sorted((y0, y1))
    return hexa(rect_pts(x0, x1, y0, y1, z0),
                rect_pts(x0 + ti, x1 - ti, y0 + ti, y1 - ti, z1))


def prism_z(pts, z0, z1):
    """XY 闭合多边形沿 Z 拉伸成闭合棱柱。"""
    n = len(pts)
    verts = [(x, y, z0) for x, y in pts] + [(x, y, z1) for x, y in pts]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    return verts, faces


def prism_x(pts, x0, x1):
    """YZ 闭合多边形沿 X 拉伸成闭合棱柱（山墙三角墙板用）。"""
    n = len(pts)
    verts = [(x0, y, z) for y, z in pts] + [(x1, y, z) for y, z in pts]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    return verts, faces


def prism_y(pts, y0, y1):
    """XZ 闭合多边形沿 Y 拉伸成闭合棱柱（檐沟 / 侧向型材用）。"""
    n = len(pts)
    verts = [(x, y0, z) for x, z in pts] + [(x, y1, z) for x, z in pts]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
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


def rod(p0, p1, r, sides=8):
    pts = [(r * math.cos(2.0 * math.pi * i / sides),
            r * math.sin(2.0 * math.pi * i / sides)) for i in range(sides)]
    return sweep(p0, p1, pts)


def vchamfer_box(x0, x1, y0, y1, z0, z1, ch):
    """四根竖直棱倒角的八边形截面盒（壁柱 / 竖梃），10 面 16 三角面。"""
    x0, x1 = sorted((x0, x1))
    y0, y1 = sorted((y0, y1))
    z0, z1 = sorted((z0, z1))
    if x1 - x0 < 2.0 * ch or y1 - y0 < 2.0 * ch:
        return box((x0, y0, z0), (x1, y1, z1))
    pts = [(x0 + ch, y0), (x1 - ch, y0), (x1, y0 + ch), (x1, y1 - ch),
           (x1 - ch, y1), (x0 + ch, y1), (x0, y1 - ch), (x0, y0 + ch)]
    return prism_z(pts, z0, z1)


def chamfer_beam(p0, p1, w, h=None, ch=0.02):
    """带 45° 倒角的矩形截面梁（粗钢梁 / 吊货梁），8 边截面。"""
    h = w if h is None else h
    a, b = w / 2.0, h / 2.0
    c = min(ch, a * 0.4, b * 0.4)
    section = [(-a + c, -b), (a - c, -b), (a, -b + c), (a, b - c),
               (a - c, b), (-a + c, b), (-a, b - c), (-a, -b + c)]
    return sweep(p0, p1, section)


def lprism_u(side, u0, u1, pts):
    """立面局部 (d, v) 闭合多边形沿 u 拉伸成闭合型材（檐口 / 线脚）。

    pts 为 [(d, v), ...]：d 为自墙外皮向内的凹深（<0 凸出），v 为世界 Z。
    """
    n = len(pts)
    verts = [lp(side, u0, v, d) for d, v in pts] + \
            [lp(side, u1, v, d) for d, v in pts]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    return verts, faces


# --------------------------------------------------------------------------- #
# 局部立面坐标系：(side) → (u, v, d)
#   u = 立面水平坐标（前后立面 = X，侧立面 = Y）
#   v = 世界 Z
#   d = 自墙外皮向内的凹深（>0 进入墙体，<0 凸出墙面）
# --------------------------------------------------------------------------- #

# _SIDE 由本文件下方的 tavern 版覆盖（参考实现里的尺寸不适用）



def lp(side, u, v, d):
    """局部 (u,v,d) → 世界坐标。"""
    axis, plane, sign = _SIDE[side]
    if axis == "y":
        return (u, plane + sign * d, v)
    return (plane + sign * d, u, v)


def lbox(side, u0, u1, v0, v1, d0, d1):
    return box(lp(side, u0, v0, d0), lp(side, u1, v1, d1))


def lhexa(side, rect_a, rect_b):
    """两个局部矩形 (u0,u1,v0,v1,d) 之间的六面体（窗台斜面等）。"""
    def pts(r):
        return [lp(side, r[0], r[2], r[4]), lp(side, r[1], r[2], r[4]),
                lp(side, r[1], r[3], r[4]), lp(side, r[0], r[3], r[4])]
    return hexa(pts(rect_a), pts(rect_b))


def lvchamfer_box(side, u0, u1, v0, v1, d0, d1, ch):
    a = lp(side, u0, v0, d0)
    b = lp(side, u1, v1, d1)
    return vchamfer_box(a[0], b[0], a[1], b[1], a[2], b[2], ch)


# --------------------------------------------------------------------------- #
# 带真实凹口的墙板
# --------------------------------------------------------------------------- #

def panel(axis, plane, sign, u0, u1, v0, v1, t, openings,
          mat_face=BRICK, mat_reveal=STONE, mat_inner=BRICK):
    """闭合厚墙板 + 矩形凹口（凹深 < 板厚）。

    openings: [(a, b, c, d, depth, back_material), ...]，均须严格位于板内。
    网格线在凹口边处切分，凹口侧壁 / 凹底按同一组网格线切分，保证闭合流形。
    """
    verts = []
    index = {}

    def pid(u, v, d):
        key = (round(u, 6), round(v, 6), round(d, 6))
        i = index.get(key)
        if i is None:
            i = len(verts)
            index[key] = i
            if axis == "y":
                verts.append((u, plane + sign * d, v))
            else:
                verts.append((plane + sign * d, u, v))
        return i

    # 网格线：板边界 + 所有凹口边界
    us = [u0, u1]
    vs = [v0, v1]
    for (a, b, c, d, _dep, _bm) in openings:
        us.extend([a, b])
        vs.extend([c, d])
    us = sorted(set(round(x, 6) for x in us))
    vs = sorted(set(round(x, 6) for x in vs))

    def in_opening(cu, cv):
        for (a, b, c, d, _dep, _bm) in openings:
            if a - 1e-9 <= cu <= b + 1e-9 and c - 1e-9 <= cv <= d + 1e-9:
                return True
        return False

    faces = []
    # 外皮（挖洞）
    for i in range(len(us) - 1):
        for j in range(len(vs) - 1):
            cu = 0.5 * (us[i] + us[i + 1])
            cv = 0.5 * (vs[j] + vs[j + 1])
            if in_opening(cu, cv):
                continue
            faces.append(((pid(us[i], vs[j], 0.0), pid(us[i + 1], vs[j], 0.0),
                           pid(us[i + 1], vs[j + 1], 0.0), pid(us[i], vs[j + 1], 0.0)),
                          mat_face))
    # 内皮（整板网格）
    for i in range(len(us) - 1):
        for j in range(len(vs) - 1):
            faces.append(((pid(us[i], vs[j], t), pid(us[i + 1], vs[j], t),
                           pid(us[i + 1], vs[j + 1], t), pid(us[i], vs[j + 1], t)),
                          mat_inner))
    # 板四周封边
    for j in range(len(vs) - 1):
        faces.append(((pid(u0, vs[j], 0.0), pid(u0, vs[j + 1], 0.0),
                       pid(u0, vs[j + 1], t), pid(u0, vs[j], t)), mat_face))
        faces.append(((pid(u1, vs[j], 0.0), pid(u1, vs[j + 1], 0.0),
                       pid(u1, vs[j + 1], t), pid(u1, vs[j], t)), mat_face))
    for i in range(len(us) - 1):
        faces.append(((pid(us[i], v0, 0.0), pid(us[i + 1], v0, 0.0),
                       pid(us[i + 1], v0, t), pid(us[i], v0, t)), mat_face))
        faces.append(((pid(us[i], v1, 0.0), pid(us[i + 1], v1, 0.0),
                       pid(us[i + 1], v1, t), pid(us[i], v1, t)), mat_face))
    # 凹口：侧壁按网格线切分 + 凹底网格
    for (a, b, c, d, depth, back_mat) in openings:
        dz = min(depth, t - 0.05)
        va = [x for x in vs if c - 1e-9 <= x <= d + 1e-9]
        ua = [x for x in us if a - 1e-9 <= x <= b + 1e-9]
        for k in range(len(va) - 1):
            faces.append(((pid(a, va[k], 0.0), pid(a, va[k + 1], 0.0),
                           pid(a, va[k + 1], dz), pid(a, va[k], dz)), mat_reveal))
            faces.append(((pid(b, va[k], 0.0), pid(b, va[k + 1], 0.0),
                           pid(b, va[k + 1], dz), pid(b, va[k], dz)), mat_reveal))
        for k in range(len(ua) - 1):
            faces.append(((pid(ua[k], c, 0.0), pid(ua[k + 1], c, 0.0),
                           pid(ua[k + 1], c, dz), pid(ua[k], c, dz)), mat_reveal))
            faces.append(((pid(ua[k], d, 0.0), pid(ua[k + 1], d, 0.0),
                           pid(ua[k + 1], d, dz), pid(ua[k], d, dz)), mat_reveal))
        for k in range(len(ua) - 1):
            for m in range(len(va) - 1):
                faces.append(((pid(ua[k], va[m], dz), pid(ua[k + 1], va[m], dz),
                               pid(ua[k + 1], va[m + 1], dz), pid(ua[k], va[m + 1], dz)),
                              back_mat))
    return verts, faces


# --------------------------------------------------------------------------- #
# 立面局部坐标系（+X 主立面 / -X 背面 / ±Y 侧墙）
# --------------------------------------------------------------------------- #
# 约定：d > 0 = 向墙内（凹），d < 0 = 凸出墙面；u = 立面水平坐标，v = 世界 Z。
_SIDE = {
    "front": ("x", WALL_XF, -1.0),   # +X 主立面（固定机位可见）
    "back": ("x", WALL_XB, 1.0),     # -X 背面（服务门 / 木桶）
    "left": ("y", -WALL_Y, 1.0),     # -Y 侧墙
    "right": ("y", WALL_Y, -1.0),    # +Y 侧墙（掠射可见）
}


# --------------------------------------------------------------------------- #
# 细部构件
# --------------------------------------------------------------------------- #

def _plinth(m):
    """石基：两级收分，顶面 9.64 × 7.64（墙脚下留 0.2 m 台沿）。"""
    m.add(*tb(-HALF_X, HALF_X, -HALF_Y, HALF_Y, 0.00, 0.24, 0.09), STONE)
    m.add(*tb(-HALF_X + 0.09, HALF_X - 0.09, -HALF_Y + 0.09, HALF_Y - 0.09,
              0.24, PLINTH_TOP, 0.09), STONE)
    # 入口石门槛（压墙脚 0.02，外挑 0.16）
    m.add(*lbox("front", -1.05, 1.05, PLINTH_TOP - 0.02, PLINTH_TOP + 0.06,
                -0.16, 0.02), STONE)


def _walls(m):
    """四面墙板：首层砖 / 二层灰泥，前后面 u 收到 ±(WALL_Y - SIDE_T) 与侧墙内嵌拼接。"""
    fu = WALL_Y - SIDE_T
    m.add_multi(*panel("x", WALL_XF, -1.0, -fu, fu, WALL_Z0, STOREY_Z, PANEL_T, FRONT_LOW,
                 mat_face=BRICK, mat_reveal=STONE, mat_inner=BRICK))
    m.add_multi(*panel("x", WALL_XF, -1.0, -fu, fu, STOREY_Z, EAVE_Z, PANEL_T, FRONT_HIGH,
                 mat_face=PLASTER, mat_reveal=STONE, mat_inner=BRICK))
    m.add_multi(*panel("x", WALL_XB, 1.0, -fu, fu, WALL_Z0, STOREY_Z, SIDE_T, BACK_LOW,
                 mat_face=BRICK, mat_reveal=STONE, mat_inner=BRICK))
    m.add_multi(*panel("x", WALL_XB, 1.0, -fu, fu, STOREY_Z, EAVE_Z, SIDE_T, BACK_HIGH,
                 mat_face=PLASTER, mat_reveal=STONE, mat_inner=BRICK))
    for side, low, high in (("right", RIGHT_LOW, RIGHT_HIGH), ("left", LEFT_LOW, LEFT_HIGH)):
        m.add_multi(*panel("y", WALL_Y if side == "right" else -WALL_Y,
                     -1.0 if side == "right" else 1.0,
                     WALL_XB, WALL_XF, WALL_Z0, STOREY_Z, SIDE_T, low,
                     mat_face=BRICK, mat_reveal=STONE, mat_inner=BRICK))
        m.add_multi(*panel("y", WALL_Y if side == "right" else -WALL_Y,
                     -1.0 if side == "right" else 1.0,
                     WALL_XB, WALL_XF, STOREY_Z, EAVE_Z, SIDE_T, high,
                     mat_face=PLASTER, mat_reveal=STONE, mat_inner=BRICK))


def _window(m, side, uc, vc, w, h, depth):
    """窗：木竖框 + 木横框 + 铁窗棂 + 石窗台（外凸 0.09 斜台）+ 石窗楣。"""
    hw, hh = w / 2.0, h / 2.0
    for s in (-1.0, 1.0):
        ua = uc + s * (hw + 0.03)
        ub = uc + s * (hw - 0.08)
        m.add(*lvchamfer_box(side, min(ua, ub), max(ua, ub), vc - hh, vc + hh,
                             -0.03, depth, 0.018), WOOD)
    m.add(*lbox(side, uc - hw + 0.04, uc + hw - 0.04, vc + hh - 0.08, vc + hh + 0.03,
                -0.03, depth), WOOD)
    m.add(*lbox(side, uc - hw + 0.04, uc + hw - 0.04, vc - hh - 0.03, vc - hh + 0.07,
                -0.03, depth), WOOD)
    m.add(*lbox(side, uc - 0.025, uc + 0.025, vc - hh, vc + hh, -0.02, depth - 0.03), IRON)
    m.add(*lbox(side, uc - hw, uc + hw, vc - 0.025, vc + 0.025, -0.02, depth - 0.03), IRON)
    m.add(*lhexa(side,
                 (uc - hw - 0.15, uc + hw + 0.15, vc - hh - 0.13, vc - hh + 0.02, -0.02),
                 (uc - hw - 0.11, uc + hw + 0.11, vc - hh - 0.09, vc - hh + 0.02, -0.10)),
          STONE)
    m.add(*lbox(side, uc - hw - 0.14, uc + hw + 0.14, vc + hh + 0.03, vc + hh + 0.16,
                -0.05, 0.02), STONE)


def _front_door(m, side, uc, v0, v1, w, depth):
    """入口双开门：木门框 + 双扇带压条 + 铁拉手 + 石门槛。"""
    hw = w / 2.0
    for s in (-1.0, 1.0):
        ua = uc + s * (hw + 0.03)
        ub = uc + s * (hw - 0.10)
        m.add(*lvchamfer_box(side, min(ua, ub), max(ua, ub), v0, v1,
                             -0.03, depth - 0.05, 0.028), WOOD)
    m.add(*lbox(side, uc - hw + 0.05, uc + hw - 0.05, v1 - 0.12, v1 + 0.04,
                -0.03, depth - 0.05), WOOD)
    for s in (-1.0, 1.0):
        ua = uc + s * 0.03
        ub = uc + s * (hw - 0.09)
        u0, u1 = min(ua, ub), max(ua, ub)
        m.add(*lbox(side, u0, u1, v0 + 0.12, v1 - 0.12, depth - 0.08, depth - 0.02), WOOD)
        for ux in (u0 + (u1 - u0) * 0.30, u0 + (u1 - u0) * 0.70):
            m.add(*lbox(side, ux - 0.04, ux + 0.04, v0 + 0.24, v1 - 0.24,
                        depth - 0.10, depth - 0.075), WOOD)
        for vz in (v0 + 0.85, v1 - 0.85):
            m.add(*lbox(side, u0 + 0.06, u1 - 0.06, vz - 0.045, vz + 0.045,
                        depth - 0.10, depth - 0.078), WOOD)
        m.add(*lbox(side, u0 + (u1 - u0) * 0.55, u0 + (u1 - u0) * 0.80,
                    v0 + 0.95, v0 + 1.02, depth - 0.13, depth - 0.05), IRON)


def _service_door(m, side, uc, v0, v1, w, depth):
    """后侧服务门：木框 + 拼板门扇 + 铁铰链 + 小铁雨棚。"""
    hw = w / 2.0
    for s in (-1.0, 1.0):
        ua = uc + s * (hw + 0.03)
        ub = uc + s * (hw - 0.08)
        m.add(*lvchamfer_box(side, min(ua, ub), max(ua, ub), v0, v1,
                             -0.03, depth - 0.04, 0.02), WOOD)
    m.add(*lbox(side, uc - hw + 0.04, uc + hw - 0.04, v1 - 0.09, v1 + 0.03,
                -0.03, depth - 0.04), WOOD)
    m.add(*lbox(side, uc - hw + 0.05, uc + hw - 0.05, v0 + 0.10, v1 - 0.09,
                depth - 0.06, depth - 0.01), WOOD)
    for vz in (v0 + 0.55, v0 + 1.35):
        m.add(*lbox(side, uc - hw + 0.03, uc - hw + 0.24, vz - 0.05, vz + 0.05,
                    -0.02, 0.02), IRON)
    m.add(*lbox(side, uc - hw - 0.16, uc + hw + 0.16, v1 + 0.05, v1 + 0.15,
                -0.26, 0.02), IRON)


def _pilaster(m, side, uc, v0, v1, w=0.34, d=0.12):
    """壁柱：八边形截面竖梃 + 石柱础 / 石柱头。"""
    m.add(*lvchamfer_box(side, uc - w / 2.0, uc + w / 2.0, v0, v1, -d, 0.02, 0.025), BRICK)
    for vz in (v0, v1):
        m.add(*lvchamfer_box(side, uc - w / 2.0 - 0.04, uc + w / 2.0 + 0.04,
                             vz - 0.06, vz + 0.10 if vz == v0 else vz + 0.06,
                             -d - 0.05, 0.02, 0.015), STONE)


def _storey_band(m):
    """层间石腰带（打断 6.6 m 高墙）+ 转角石块。"""
    fu = WALL_Y - SIDE_T
    for side, u0, u1 in (("front", -fu, fu), ("back", -fu, fu),
                         ("right", WALL_XB, WALL_XF), ("left", WALL_XB, WALL_XF)):
        m.add(*lbox(side, u0, u1, STOREY_Z - 0.02, STOREY_Z + 0.12, -0.13, 0.02), STONE)


def _cornice(m):
    """檐口：石质五级线脚（2 段倒角，最大出挑 0.22），四面一圈。"""
    profile = [(0.02, EAVE_Z - 0.44), (-0.05, EAVE_Z - 0.44), (-0.05, EAVE_Z - 0.38),
               (-0.18, EAVE_Z - 0.36), (-0.22, EAVE_Z - 0.30), (-0.16, EAVE_Z - 0.24),
               (-0.10, EAVE_Z - 0.12), (0.02, EAVE_Z - 0.08)]
    fu = WALL_Y - SIDE_T
    for side, u0, u1 in (("front", -fu, fu), ("back", -fu, fu),
                         ("right", WALL_XB, WALL_XF), ("left", WALL_XB, WALL_XF)):
        m.add(*lprism_u(side, u0, u1, profile), STONE)


def _gable(m):
    """+X 山墙三角（灰泥，厚 0.40，与主立面平齐）+ 铁拉杆 + 木百叶小窗。"""
    m.add(*prism_x([(-WALL_Y, EAVE_Z - 0.18), (WALL_Y, EAVE_Z - 0.18),
                    (WALL_Y, EAVE_Z - 0.04), (0.0, RIDGE_Z - 0.02),
                    (-WALL_Y, EAVE_Z - 0.04)],
                   WALL_XF - PANEL_T, WALL_XF), PLASTER)
    # 铁拉杆（山墙中部）
    m.add(*box((WALL_XF - 0.06, -2.30, 6.92), (WALL_XF + 0.03, 2.30, 6.98)), IRON)
    for sy in (-1.0, 1.0):
        m.add(*box((WALL_XF - 0.10, sy * 2.30 - 0.09, 6.86),
                   (WALL_XF + 0.02, sy * 2.30 + 0.09, 7.02)), IRON)
    # 山墙木百叶小窗（凸出 0.10 的真实盒子，不是贴片）
    m.add(*box((WALL_XF - 0.02, -0.36, 6.96), (WALL_XF + 0.10, 0.36, 7.42)), WOOD)
    for vz in (7.06, 7.20, 7.34):
        m.add(*box((WALL_XF + 0.02, -0.30, vz - 0.03), (WALL_XF + 0.13, 0.30, vz + 0.03)), IRON)


def _roof(m):
    """双坡屋面（脊线沿 X）：板厚 0.22 + 檐口 2 段倒角 + 脊瓦 + 立缝。"""
    for sy in (-1.0, 1.0):
        ye = sy * ROOF_Y
        zt = ROOF_EAVE_Z + ROOF_T
        pts = [(0.0, RIDGE_Z), (ye, ROOF_EAVE_Z),
               (ye, zt - 0.06),
               (ye - sy * 0.018, zt - 0.018),
               (ye - sy * 0.062, zt),
               (0.0, RIDGE_Z + ROOF_T)]
        m.add(*prism_x(pts, ROOF_XB, ROOF_XF), IRON)
    # 脊瓦
    m.add(*box((ROOF_XB, -0.28, RIDGE_Z + ROOF_T - 0.02),
               (ROOF_XF, 0.28, RIDGE_Z + ROOF_T + 0.10)), IRON)
    # 每坡 3 道立缝（压在顶皮之上）
    for sy in (-1.0, 1.0):
        for sx in (-3.40, 0.0, 3.40):
            ye = sy * (WALL_Y + 0.18)
            ze = RIDGE_Z - abs(ye) * ROOF_SLOPE + ROOF_T
            m.add(*beam((sx, ye, ze + 0.026), (sx, sy * 0.20, RIDGE_Z + ROOF_T + 0.026),
                        0.075, 0.055), IRON)


def _porch(m):
    """门廊：石地面 + 2 根木柱 + 石柱础 + 斜撑 + 单坡廊顶（挑到包围盒 +X）。"""
    # 门廊地面（压在石基压顶上 0.02）
    m.add(*box((WALL_XF, -PORCH_HALF_W, PLINTH_TOP - 0.02),
               (PORCH_X - 0.02, PORCH_HALF_W, PLINTH_TOP + 0.02)), STONE)
    # 2 根木柱 + 石柱础
    for sy in (-1.0, 1.0):
        py = sy * (PORCH_HALF_W - 0.35)
        m.add(*vchamfer_box(PORCH_X - 0.32, PORCH_X - 0.10, py - 0.11, py + 0.11,
                            PLINTH_TOP, PORCH_EAVE_Z, 0.02), WOOD)
        m.add(*vchamfer_box(PORCH_X - 0.42, PORCH_X - 0.02, py - 0.19, py + 0.19,
                            PLINTH_TOP - 0.02, PLINTH_TOP + 0.16, 0.015), STONE)
        # 斜撑（柱顶 → 墙面）
        m.add(*beam((PORCH_X - 0.24, py, PORCH_EAVE_Z - 0.62),
                    (WALL_XF + 0.02, py, PORCH_EAVE_Z - 0.04), 0.09, 0.09), WOOD)
    # 廊顶横梁（柱子之间）
    m.add(*box((PORCH_X - 0.34, -PORCH_HALF_W + 0.10, PORCH_EAVE_Z - 0.16),
               (PORCH_X - 0.08, PORCH_HALF_W - 0.10, PORCH_EAVE_Z - 0.02)), WOOD)
    # 单坡廊顶：贴墙 z 3.98 → 外沿 z 3.40，板厚 0.18，外沿 2 段倒角
    lo, hi = PORCH_EAVE_Z, PORCH_TOP_Z
    pts = [(WALL_XF + 0.02, hi), (PORCH_X, lo),
           (PORCH_X - 0.02, lo - 0.06), (PORCH_X - 0.06, lo - 0.075),
           (PORCH_X - 0.10, lo - 0.05), (WALL_XF + 0.02, hi + 0.18)]
    m.add(*prism_y([(x, z) for x, z in pts], -PORCH_HALF_W, PORCH_HALF_W), IRON)


def _chimney(m):
    """−X 端砖烟囱：方形砖身 + 石压顶 + 铁帽板，顶面正好 8.00 m（轮廓识别点）。"""
    x0, x1 = -4.55, -3.50
    y0, y1 = -1.50, -0.65
    m.add(*vchamfer_box(x0, x1, y0, y1, 6.42, CHIMNEY_TOP - 0.22, 0.035), BRICK)
    m.add(*tb(x0 - 0.07, x1 + 0.07, y0 - 0.07, y1 + 0.07,
              CHIMNEY_TOP - 0.22, CHIMNEY_TOP - 0.12, 0.05), STONE)
    m.add(*box((x0 - 0.02, y0 - 0.02, CHIMNEY_TOP - 0.12),
               (x1 + 0.02, y1 + 0.02, CHIMNEY_TOP)), IRON)
    # 烟囱与屋面相接处的泛水石
    m.add(*tb(x0 - 0.12, x1 + 0.12, y0 - 0.12, y1 + 0.12, 6.34, 6.46, 0.04), STONE)


def _sign(m):
    """悬挂空白招牌：铁托架（双悬臂 + 卷叶）+ 木牌 + 2 根吊链；无文字。"""
    yc = 2.95
    m.add(*box((WALL_XF - 0.02, yc - 0.07, 3.66), (WALL_XF + 0.62, yc + 0.07, 3.74)), IRON)
    m.add(*box((WALL_XF - 0.02, yc - 0.07, 3.16), (WALL_XF + 0.58, yc + 0.07, 3.24)), IRON)
    # 竖撑（把上下悬臂连成托架）
    m.add(*box((WALL_XF + 0.48, yc - 0.06, 3.16), (WALL_XF + 0.56, yc + 0.06, 3.74)), IRON)
    # 卷叶（八边形小柱段）
    m.add(*rod((WALL_XF + 0.12, yc, 3.24), (WALL_XF + 0.12, yc, 3.66), 0.05, 8), IRON)
    # 木牌（0.86 × 0.58 × 0.06，挂在两悬臂之间）
    bx = WALL_XF + 0.30
    m.add(*box((bx - 0.03, yc - 0.43, 3.02), (bx + 0.03, yc + 0.43, 3.60)), WOOD)
    # 吊链 / 吊杆
    for sy in (-1.0, 1.0):
        m.add(*rod((WALL_XF + 0.52, yc + sy * 0.34, 3.24),
                   (WALL_XF + 0.52, yc + sy * 0.34, 3.62), 0.018, 6), IRON)


def _downpipes(m):
    """2 根落水管：+X 立面两角，雨水斗 + 3 道管卡 + 落水口。"""
    for sy in (-1.0, 1.0):
        px = WALL_XF + 0.10
        py = sy * (WALL_Y - 0.12)
        m.add(*rod((px, py, PLINTH_TOP), (px, py, EAVE_Z - 0.30), 0.055, 8), IRON)
        for vz in (1.20, 3.10, 5.00):
            m.add(*box((px - 0.03, py - 0.025, vz - 0.04), (px + 0.10, py + 0.025, vz + 0.04)), IRON)
        # 雨水斗
        m.add(*tb(px - 0.17, px + 0.17, py - 0.17, py + 0.17, EAVE_Z - 0.34, EAVE_Z - 0.22, 0.05), IRON)
        # 落水口
        m.add(*tb(px - 0.10, px + 0.10, py - 0.10, py + 0.10, PLINTH_TOP - 0.04, PLINTH_TOP + 0.04, 0.03), IRON)


def _gutters(m):
    """2 段檐沟（沿 ±Y 檐口挂在屋面下沿，收在包围盒内）。"""
    for sy in (-1.0, 1.0):
        y0 = sy * (ROOF_Y - 0.22)
        y1 = sy * (ROOF_Y - 0.02)
        z = ROOF_EAVE_Z - 0.10
        m.add(*prism_x([(y0, z + 0.22), (y0, z + 0.02), (y1, z),
                        (y1, z + 0.20), (y1 - sy * 0.04, z + 0.22)],
                       ROOF_XB + 0.05, ROOF_XF - 0.05), IRON)


def _barrels(m):
    """3 个木桶（12 边形 + 2 道铁箍），放在 +X 立面外的石基台沿上。"""
    for i, (bx, by) in enumerate(((4.42, -2.95), (4.42, 2.95), (4.05, 3.05))):
        r = 0.28
        z0 = PLINTH_TOP
        m.add(*rod((bx, by, z0), (bx, by, z0 + 0.80), r, 12), WOOD)
        for hz in (0.18, 0.62):
            m.add(*rod((bx, by, z0 + hz), (bx, by, z0 + hz + 0.07), r + 0.012, 12), IRON)
        m.add(*rod((bx, by, z0 + 0.80), (bx, by, z0 + 0.84), r * 0.82, 12), WOOD)


def _quoins(m):
    """主立面两角的错缝石块（每角 5 块，出挑 0.04，打断 6.6 m 高的砖墙竖向节奏）。"""
    for sy in (-1.0, 1.0):
        for i in range(5):
            z0 = 0.55 + i * 1.18
            w = 0.52 if i % 2 == 0 else 0.38
            m.add(*box((WALL_XF - 0.02, sy * WALL_Y - (w if sy > 0 else 0.0),
                        z0), (WALL_XF + 0.04, sy * WALL_Y + (0.0 if sy > 0 else w),
                              z0 + 0.42)), STONE)


def _shutters(m):
    """二层三扇窗各配一对木百叶窗扇（0.30 宽、出挑 0.05，真实的闭合板）。"""
    hw = 0.48
    for uc in (-2.24, 0.0, 2.24):
        for s in (-1.0, 1.0):
            u0 = uc + s * (hw + 0.12)
            u1 = uc + s * (hw + 0.44)
            m.add(*box((WALL_XF - 0.05, min(u0, u1), 4.48), (WALL_XF + 0.03, max(u0, u1), 5.82)), WOOD)


def _porch_rail(m):
    """门廊两侧矮栏（2 道横杆 + 3 根立柱），把柱廊读成"入口"而不是空架子。"""
    py = PORCH_HALF_W - 0.35
    for sy in (-1.0, 1.0):
        m.add(*box((PORCH_X - 0.30, sy * py - 0.05, PLINTH_TOP + 0.92),
                   (PORCH_X - 0.20, sy * py + 0.05, PLINTH_TOP + 1.00)), WOOD)
        for i in range(3):
            bx = WALL_XF + 0.22 + i * 0.42
            m.add(*box((bx - 0.035, sy * py - 0.035, PLINTH_TOP + 0.02),
                       (bx + 0.035, sy * py + 0.035, PLINTH_TOP + 0.96)), WOOD)


def _lamp(m):
    """+Y 侧墙的铁灯架 + 玻璃灯箱（无发光，只做剪影细节）。"""
    y = WALL_Y
    m.add(*box((1.10, y - 0.02, 3.30), (1.22, y + 0.16, 3.40)), IRON)
    m.add(*box((1.10, y + 0.10, 3.40), (1.22, y + 0.18, 3.82)), IRON)
    m.add(*box((1.02, y + 0.08, 3.76), (1.30, y + 0.26, 3.94)), IRON)
    m.add(*box((1.06, y + 0.10, 3.44), (1.26, y + 0.24, 3.76)), GLASS)
    m.add(*box((1.00, y + 0.06, 3.40), (1.32, y + 0.28, 3.46)), IRON)


def _tie_anchor(m):
    """山墙两侧的铁锚板（结构细节，同时压住灰泥山墙边）。"""
    for sy in (-1.0, 1.0):
        m.add(*box((WALL_XF - 0.04, sy * (WALL_Y - 0.55) - 0.10, EAVE_Z - 0.02),
                   (WALL_XF + 0.04, sy * (WALL_Y - 0.55) + 0.10, EAVE_Z + 0.22)), IRON)


# --------------------------------------------------------------------------- #
# 组装
# --------------------------------------------------------------------------- #

def build_tavern():
    m = Part()
    _plinth(m)
    _walls(m)
    # 立面细节：窗 / 门 / 壁柱
    for side, low, high in (("front", FRONT_LOW, FRONT_HIGH),
                            ("back", BACK_LOW, BACK_HIGH),
                            ("right", RIGHT_LOW, RIGHT_HIGH),
                            ("left", LEFT_LOW, LEFT_HIGH)):
        for k, (u0, u1, v0, v1, dep, back) in enumerate(low + high):
            uc = 0.5 * (u0 + u1)
            vc = 0.5 * (v0 + v1)
            if back == WOOD and v0 < 1.0:
                if side == "front":
                    _front_door(m, side, uc, v0, v1, u1 - u0, dep)
                else:
                    _service_door(m, side, uc, v0, v1, u1 - u0, dep)
            else:
                _window(m, side, uc, vc, u1 - u0, v1 - v0, dep)
    # 壁柱（主立面两角）
    for uc in (-3.42, 3.42):
        _pilaster(m, "front", uc, WALL_Z0, EAVE_Z - 0.44)
    # 结构 / 屋面 / 附件
    _storey_band(m)
    _cornice(m)
    _gable(m)
    _roof(m)
    _porch(m)
    _chimney(m)
    _sign(m)
    _tie_anchor(m)
    _gutters(m)
    _downpipes(m)
    _barrels(m)
    _quoins(m)
    _shutters(m)
    _porch_rail(m)
    _lamp(m)
    return m


def build_all_geometry():
    return {NAME: build_tavern()}


# --------------------------------------------------------------------------- #
# 纯 Python 自检（不依赖 Blender）
# --------------------------------------------------------------------------- #

def self_check():
    from collections import Counter

    part = build_tavern()
    tris = sum(max(0, len(f) - 2) for f, _m in part.faces)
    xs = [v[0] for v in part.verts]
    ys = [v[1] for v in part.verts]
    zs = [v[2] for v in part.verts]
    size = [round(max(xs) - min(xs), 4), round(max(ys) - min(ys), 4),
            round(max(zs) - min(zs), 4)]
    zmin = round(min(zs), 6)
    edges = Counter()
    for face, _mat in part.faces:
        n = len(face)
        for i in range(n):
            a, b = face[i], face[(i + 1) % n]
            edges[(min(a, b), max(a, b))] += 1
    boundary = sum(1 for c in edges.values() if c == 1)
    nonman = sum(1 for c in edges.values() if c > 2)
    degen = 0
    for face, _mat in part.faces:
        if len(set(face)) != len(face):
            degen += 1
            continue
        p0 = part.verts[face[0]]
        for i in range(1, len(face) - 1):
            p1, p2 = part.verts[face[i]], part.verts[face[i + 1]]
            ux, uy, uz = (p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2])
            vx, vy, vz = (p2[0] - p0[0], p2[1] - p0[1], p2[2] - p0[2])
            cx, cy, cz = (uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx)
            if (cx * cx + cy * cy + cz * cz) ** 0.5 * 0.5 < 1e-9:
                degen += 1
                break
    slots = sorted({m for _f, m in part.faces})
    usage = Counter(m for _f, m in part.faces)
    report = {
        "asset": ASSET, "object": NAME, "tris": tris, "verts": len(part.verts),
        "faces": len(part.faces), "size": size, "target": list(TARGET_SIZE),
        "zmin": zmin, "pivot_x": round(min(xs) + max(xs), 6),
        "pivot_y": round(min(ys) + max(ys), 6),
        "bounds": [[round(min(xs), 3), round(min(ys), 3), round(min(zs), 3)],
                   [round(max(xs), 3), round(max(ys), 3), round(max(zs), 3)]],
        "boundary_edges": boundary, "non_manifold_edges": nonman,
        "degenerate_faces": degen, "slots": slots,
        "slot_usage": dict(usage), "design": DESIGN,
    }
    checks = {
        "tris_in_budget": TRI_FLOOR <= tris <= TRI_BUDGET,
        "size_matches": all(abs(size[i] - TARGET_SIZE[i]) <= 0.02 for i in range(3)),
        "grounded": abs(zmin) <= 1e-6,
        "pivot_ground_centre": abs(report["pivot_x"]) <= 1e-6 and abs(report["pivot_y"]) <= 1e-6,
        "slots_le_6": 0 < len(slots) <= 6,
        "palette_only": all(s in PALETTE for s in slots),
        "all_slots_used": len(usage) == len(slots),
        "closed_solids": boundary == 0 and nonman == 0 and degen == 0,
    }
    report["checks"] = checks
    report["all_pass"] = all(checks.values())
    print("TAVERN_CHECK " + repr(report))
    return report


if __name__ == "__main__":
    import sys

    sys.exit(0 if self_check()["all_pass"] else 1)
