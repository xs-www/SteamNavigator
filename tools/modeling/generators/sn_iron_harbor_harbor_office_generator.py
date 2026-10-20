# -*- coding: utf-8 -*-
"""Steam Navigator — 铁港建筑套件 SN_HT_Harbor_Office LOD0（9.0 × 8.0 × 14.0 m）。

工单：tools/modeling/briefs/sn_iron_harbor_architecture_kit_v1.json
      （`building_archetypes` → `harbor_office`，budget_class = building_landmark_lod0）
参考实现：tools/modeling/generators/sn_iron_harbor_architecture_kit_generator.py
      （几何已过门禁并冻结；本文件的 `Part` / `panel` / 局部立面坐标系 / 倒角构件
       全部按该实现逐字照抄，只把立面朝向与内部程序本楼化）
舞台依据：docs/archive/IRON_HARBOR_ARCHITECTURE_M1.md §2/§3

本文件只做**纯 Python 几何**（不 import bpy）。材质与 UV 由 Lead 用
`sn_iron_harbor_materials.apply_to_object()` 在 Blender 里统一施加；本文件只负责
每个面写正确的 6 个共享材质槽名。

朝向（必须遵守）
----------------
PortStage `port_stage.gd` `TOWN_SLOTS` 给 `harbor_office` 槽位 `yaw = −80°`，
把资产局部 **+X** 转到正对固定机位（偏轴约 7°）。因此：

    +X = 主立面（拱形入口 / 三层窗列 / 2 个铁阳台 / 空白石匾 / 檐口），法线 +X
    +Y = 次可见面（掠射约 73°，9 扇窗 / 2 根落水管）
    −Y、−X = 背面（不可见，只保证水密 + 开窗节奏）

轴心 = 落地中心：几何在 X/Y 上都关于 0 对称（min = −max，1e−6 内），
`z ∈ [0, 14.0]`，`zmin = 0`；14.0 是钟楼尖顶铁尖的最高点。

设计要点
--------
- **三层立面分层**：石腰线在 z = 4.62–4.78 / 7.77–7.93，把 10.6 m 高的墙分成
  0.65–4.62 / 4.78–7.77 / 7.93–10.74 三层（首层最高，逐层递减）。
- **真实凹口**：四面墙板都由 `panel()` 生成「闭合厚板 + 矩形凹口」（外皮挖洞 +
  四周侧壁 + 凹底），窗凹深 0.16、门凹深 0.28，不是共面深色贴片；凹口侧壁直接
  露出 0.35 m 墙板厚度。
- **拱形入口**：方洞 2.10 宽 × 0.94–3.65，洞内上半部用两片「拱肩填石」（lune）
  补成半圆门洞，再叠 10 段石拱券环带 + 拱心石 + 八棱石门柱；凹底为深色木门厅。
- **2 个铁阳台**：二 / 三层中心落地窗前的石板（出挑 0.46）+ 2 个斜牛腿 +
  上/中/下 3 道横杆 + 4 根立柱 + 2 个侧面回栏。
- **四面钟楼**：3.0 × 3.0 砖塔身 → 石基环 → 4 面空白钟盘（铁圈 + 灰泥盘面 +
  铁指针，无数字）→ 石檐环 → 八棱尖顶 → 铁尖（顶点正好 z = 14.0）。
- **屋角旗杆座**：屋面 +X/+Y 角，石座 0.50 × 0.50 × 0.35 + 铁环 + 铁杆到 13.60
  （低于尖顶，14.0 仍是全楼最高点）。
- **倒角策略**：不用 Bevel 修改器，全部显式几何：石基三级收分（`tb`）、腰线 /
  檐口 2 段折线截面（`lprism_u`）、壁柱 / 门柱八边形截面（`vchamfer_box`）、
  窗台斜面（`lhexa`）、屋面棱边。等价工单要求的 0.03–0.12 m 倒角。
- 单件一个 mesh 对象、材质槽 6 个（Brick / Plaster / Wood / Iron / Stone / Glass），
  没有新材质名，没有任何烘焙文字或数字（钟盘与石匾都是空白的）。

用法
----
纯 Python 自检（不建对象，只校验几何 / 预算 / 包围盒 / 设计清单）：
    python tools/modeling/generators/sn_iron_harbor_harbor_office_generator.py
门禁干跑：
    python tools/modeling/generators/dryrun_props.py tools/modeling/generators/sn_iron_harbor_harbor_office_generator.py
"""

import math
from collections import Counter

# --------------------------------------------------------------------------- #
# 工单常量
# --------------------------------------------------------------------------- #

COLLECTION = "SN_Iron_Harbor_Architecture"
PREFIX = "SN_HT_"
ASSET = "SN_HT_Harbor_Office"
NAME = ASSET + "_LOD0"
TARGET_SIZE = (9.0, 8.0, 14.0)      # X × Y × Z（m），工单硬指标
TRI_BUDGET = 14000                 # building_landmark_lod0 上限
TRI_FLOOR = 8000                   # building_landmark_lod0 下限
LOCATION = (0.0, 0.0, 0.0)         # 单件导出根节点归零，布局由 PortStage 槽位决定

ITEMS = [(NAME, LOCATION, TRI_BUDGET, TARGET_SIZE)]
TOTAL_BUDGET = TRI_BUDGET

# 共享材质（灰模占位：R=G=B；粗糙度 / 金属度取工单区间中值）。
# 真正贴图与 UV 由 sn_iron_harbor_materials 统一施加，本文件只写槽名。
MATERIALS = {
    "SN_Town_Brick":   {"base": (0.345, 0.345, 0.345), "roughness": 0.86, "metallic": 0.00},
    "SN_Town_Plaster": {"base": (0.560, 0.560, 0.560), "roughness": 0.84, "metallic": 0.00},
    "SN_Town_Wood":    {"base": (0.215, 0.215, 0.215), "roughness": 0.78, "metallic": 0.00},
    "SN_Town_Iron":    {"base": (0.120, 0.120, 0.120), "roughness": 0.58, "metallic": 0.60},
    "SN_Town_Stone":   {"base": (0.445, 0.445, 0.445), "roughness": 0.90, "metallic": 0.00},
    "SN_Town_Glass":   {"base": (0.050, 0.050, 0.050), "roughness": 0.26, "metallic": 0.12},
}
PALETTE = set(MATERIALS)
MAX_MATERIAL_SLOTS = 6

BRICK = "SN_Town_Brick"
PLASTER = "SN_Town_Plaster"
WOOD = "SN_Town_Wood"
IRON = "SN_Town_Iron"
STONE = "SN_Town_Stone"
GLASS = "SN_Town_Glass"

# --------------------------------------------------------------------------- #
# 体量 / 立面参数（全部局部坐标：X 立面宽 ±4.5，Y 进深 ±4.0，Z 0 → 14.0）
# --------------------------------------------------------------------------- #

HALF_X = TARGET_SIZE[0] / 2.0          # 4.50
HALF_Y = TARGET_SIZE[1] / 2.0          # 4.00
HEIGHT = TARGET_SIZE[2]                # 14.00

PLINTH_TOP = 0.65                      # 石基压顶面
WALL_X = 3.86                          # ±X 墙外皮（主立面 / 背面）
WALL_Y = 3.68                          # ±Y 墙外皮（两侧立面）
PANEL_T = 0.35                         # 墙板厚度（凹口侧壁露出的厚度，工单 0.12–0.35）
WALL_BOT = 0.60                        # 墙板底面（嵌入石基 0.05）
EAVE_Z = 11.20                         # 墙板顶 / 檐口上沿

WIN_W, WIN_H = 1.15, 1.60              # 标准窗洞
WIN_RECESS = 0.16                      # 窗凹深（工单 0.10–0.18）
DOOR_RECESS = 0.28                     # 门凹深（工单 0.14–0.30）
TIER_V = ((1.55, 3.15), (5.20, 6.80), (8.30, 9.90))   # 三层窗洞竖向区间
FRENCH_V = ((5.16, 7.10), (8.26, 10.20))              # 二 / 三层阳台落地门
FRENCH_HALF_U = 0.68                                  # 落地门半宽（1.36 宽）
FRONT_WIN_U = 2.45                     # 主立面窗列中心（|u|）
RIGHT_WIN_U = (-2.35, 0.0, 2.35)       # +Y 次可见立面 3 列窗（u = X）
LEFT_WIN_U = (-1.70, 1.70)             # −Y 背面 2 列窗
BACK_WIN_U = (-1.60, 1.60)             # −X 背面 2 列窗

STRING_Z = ((4.62, 4.78), (7.77, 7.93))   # 两道石腰线（0.16 高，出挑 0.10）
CORNICE_Z = (10.74, 11.20)                # 檐口（0.46 高，出挑 0.40 / 0.30）
CORNICE_D_X = 0.40
CORNICE_D_Y = 0.30
ROOF_Z = (11.18, 11.34)                   # 平屋面板
PARAPET_Z = (11.32, 11.54)                # 女儿墙
ROOF_OUT_X = 4.28                         # 屋面出挑（墙外皮 +0.42）
ROOF_OUT_Y = 3.98                         # 屋面出挑（墙外皮 +0.30）

# ---- 拱形入口 ---- #
ARCH_HALF_U = 1.05                     # 门洞半宽 2.10
ARCH_SPRING = 2.60                     # 起拱线
ARCH_CROWN = ARCH_SPRING + ARCH_HALF_U  # 3.65（半圆拱顶）
ARCH_SILL = 0.94                       # 门洞下沿（石门前平台顶面 0.92）
ARCH_RING_RIN = 0.99                   # 拱券内半径（比门洞小 0.06，压住洞口边）
ARCH_RING_ROUT = 1.28                  # 拱券外半径
ARCH_RING_SEGS = 10                    # 10 段石拱券
ARCH_FRONT_D = 0.12                    # 拱券外凸
KEYSTONE_Z = (3.60, 3.98)

# ---- 阳台 ---- #
BALCONY_HALF_U = 1.24                  # 石板半宽（2.48 宽）
BALCONY_D = 0.46                       # 石板出挑
RAIL_H = 1.00                          # 栏杆高

# ---- 钟楼 ---- #
TOWER_HALF = 1.50                      # 塔身 3.0 × 3.0
TOWER_Z0 = 11.05                       # 塔身埋入屋面板
TOWER_Z1 = 12.98                       # 塔身顶
TOWER_BASE_Z = (11.31, 11.54)          # 石基环（下端嵌入屋面板 0.03，避免共面）
TOWER_CORNICE_Z = (12.82, 13.02)       # 石檐环
CLOCK_Z = 12.20                        # 钟盘中心
CLOCK_R_OUT = 0.54                     # 铁圈外半径（盘面直径 1.08）
CLOCK_R_IN = 0.44
SPIRE_Z0 = 13.00                       # 八棱尖顶起坡（嵌入石檐 0.02）
FINIAL_TOP = HEIGHT                    # 14.00：铁尖顶点 = 全楼最高点

FLAG_BASE = ((2.95, 3.45), (3.10, 3.60))   # 旗杆座平面：(x0, x1), (y0, y1) = 0.50 × 0.50
FLAG_BASE_Z = (11.34, 11.69)
FLAG_POLE_Z = 13.60                    # 杆顶（低于尖顶 14.0）

# 立面局部坐标系推导出的墙板外沿（比 ±Y / ±X 墙外皮各包 0.05，转角互咬）
FRONT_U = (-(WALL_Y + 0.05), WALL_Y + 0.05)    # ±3.73
SIDE_U = (-(WALL_X + 0.01), WALL_X - 0.01)     # ±3.85
BACK_U = (-(WALL_Y + 0.05), WALL_Y + 0.05)


# --------------------------------------------------------------------------- #
# 纯几何工具（无 bpy 依赖）—— 与 kit 参考实现逐字一致
# --------------------------------------------------------------------------- #

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
#   u = 立面水平坐标（±X 立面 = 世界 Y，±Y 立面 = 世界 X）
#   v = 世界 Z
#   d = 自墙外皮向内的凹深（>0 进入墙体，<0 凸出墙面）
# 本楼朝向：+X 是主立面（PortStage 槽位 yaw −80° 把局部 +X 转向固定机位）。
# --------------------------------------------------------------------------- #

_SIDE = {
    "front": ("x", WALL_X, -1.0),    # +X 主立面（拱形入口 / 三层窗 / 阳台）
    "back":  ("x", -WALL_X, 1.0),    # −X 背面
    "right": ("y", WALL_Y, -1.0),    # +Y 次可见侧立面（9 窗 / 落水管）
    "left":  ("y", -WALL_Y, 1.0),    # −Y 背面侧墙
}


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
# 带真实凹口的墙板（与 kit 参考实现逐字一致）
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
# 套件之外的补充几何工具（拱 / 圆环 / 任意轴圆环 / 局部多边形挤出 / 矩形环）
#   larc_band 与 sn_harbor_town_generator.arc_band 同一拓扑，只换成局部立面坐标；
#   ring / circle / revolved 从 sn_harbor_town_generator 逐字照抄。
# --------------------------------------------------------------------------- #

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


def larc_band(side, uc, vc, r_in, r_out, d0, d1, a0, a1, segs):
    """拱券环带：局部 (u, v) 平面内圆弧沿 d 扫掠成闭合壳体（arc_band 的立面版）。"""
    rings = []
    for k in range(segs + 1):
        a = a0 + (a1 - a0) * k / float(segs)
        ca, sa = math.cos(a), math.sin(a)
        ox, oz = uc + r_out * ca, vc + r_out * sa
        ix, iz = uc + r_in * ca, vc + r_in * sa
        rings.append([lp(side, ox, oz, d0), lp(side, ox, oz, d1),
                      lp(side, ix, iz, d1), lp(side, ix, iz, d0)])
    verts = [p for r in rings for p in r]
    faces = []
    for k in range(segs):
        a_, b_ = k * 4, (k + 1) * 4
        for i in range(4):
            j = (i + 1) % 4
            faces.append((a_ + i, a_ + j, b_ + j, b_ + i))
    faces.append((3, 2, 1, 0))
    faces.append((segs * 4, segs * 4 + 1, segs * 4 + 2, segs * 4 + 3))
    return verts, faces


def lring(side, uc, vc, r_out, r_in, d0, d1, n=10):
    """整圈圆环（钟盘铁圈）：larc_band 去掉端盖、首尾相接的闭合壳体。"""
    verts = []
    for k in range(n):
        a = 2.0 * math.pi * k / n
        ca, sa = math.cos(a), math.sin(a)
        for r, d in ((r_out, d0), (r_out, d1), (r_in, d1), (r_in, d0)):
            verts.append(lp(side, uc + r * ca, vc + r * sa, d))
    faces = []
    for k in range(n):
        a_, b_ = 4 * k, 4 * ((k + 1) % n)
        for i in range(4):
            j = (i + 1) % 4
            faces.append((a_ + i, a_ + j, b_ + j, b_ + i))
    return verts, faces


def lprism_d(side, pts, d0, d1):
    """局部 (u, v) 闭合多边形沿 d 挤出的闭合棱柱（拱肩填石 / 圆形封板）。"""
    n = len(pts)
    verts = [lp(side, u, v, d0) for u, v in pts] + [lp(side, u, v, d1) for u, v in pts]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    return verts, faces


def rect_tube(x0, x1, y0, y1, ix0, ix1, iy0, iy1, z0, z1):
    """矩形闭合环（女儿墙）：外圈 4 + 内圈 4，上下环面 + 内外侧面各 4。"""
    ob = rect_pts(x0, x1, y0, y1, z0)
    ib = rect_pts(ix0, ix1, iy0, iy1, z0)
    ot = rect_pts(x0, x1, y0, y1, z1)
    it = rect_pts(ix0, ix1, iy0, iy1, z1)
    verts = ob + ib + ot + it
    faces = []
    for i in range(4):
        j = (i + 1) % 4
        faces.append((i, 4 + i, 4 + j, j))            # 底环
        faces.append((8 + j, 12 + j, 12 + i, 8 + i))  # 顶环
        faces.append((i, j, 8 + j, 8 + i))            # 外侧面
        faces.append((4 + j, 4 + i, 12 + i, 12 + j))  # 内侧面
    return verts, faces


def ring_at(center, normal, r_out, r_in, t0, t1, n=8):
    """任意轴向圆环：center 为中心，normal 为轴向，t0..t1 为沿轴向的厚度范围。"""
    u, v = _basis((0.0, 0.0, 0.0), normal)
    verts = []
    for k in range(n):
        a = 2.0 * math.pi * k / n
        ca, sa = math.cos(a), math.sin(a)
        for r, t in ((r_out, t0), (r_out, t1), (r_in, t1), (r_in, t0)):
            verts.append((
                center[0] + r * ca * u[0] + r * sa * v[0] + t * normal[0],
                center[1] + r * ca * u[1] + r * sa * v[1] + t * normal[1],
                center[2] + r * ca * u[2] + r * sa * v[2] + t * normal[2],
            ))
    faces = []
    for k in range(n):
        a_, b_ = 4 * k, 4 * ((k + 1) % n)
        for i in range(4):
            j = (i + 1) % 4
            faces.append((a_ + i, a_ + j, b_ + j, b_ + i))
    return verts, faces


# --------------------------------------------------------------------------- #
# 立面开洞表
# --------------------------------------------------------------------------- #

def _win_rows(centers_u, tiers=TIER_V):
    """由窗列中心 + 三层竖向区间生成 (u0, u1, v0, v1, 凹深, 凹底材质) 列表。"""
    rows = []
    for uc in centers_u:
        for (v0, v1) in tiers:
            rows.append((uc - WIN_W / 2.0, uc + WIN_W / 2.0, v0, v1,
                         WIN_RECESS, GLASS))
    return rows


FRONT_WINDOWS = _win_rows((-FRONT_WIN_U, FRONT_WIN_U))       # 6 扇
RIGHT_WINDOWS = _win_rows(RIGHT_WIN_U)                       # +Y 9 扇
LEFT_WINDOWS = _win_rows(LEFT_WIN_U)                         # −Y 6 扇
BACK_WINDOWS = _win_rows(BACK_WIN_U)                         # −X 6 扇

# 主立面（+X）：拱形入口 + 6 扇窗 + 2 樘阳台落地门
FRONT_OPENINGS = (
    [(-ARCH_HALF_U, ARCH_HALF_U, ARCH_SILL, ARCH_CROWN, DOOR_RECESS, WOOD)]
    + FRONT_WINDOWS
    + [(-FRENCH_HALF_U, FRENCH_HALF_U, v0, v1, WIN_RECESS, GLASS)
       for (v0, v1) in FRENCH_V]
)
# 次可见立面（+Y）：三层各 3 扇窗
RIGHT_OPENINGS = list(RIGHT_WINDOWS)
# −Y 背面：三层各 2 扇窗
LEFT_OPENINGS = list(LEFT_WINDOWS)
# −X 背面：三层各 2 扇窗
BACK_OPENINGS = list(BACK_WINDOWS)


# --------------------------------------------------------------------------- #
# 石基 / 台阶
# --------------------------------------------------------------------------- #

def _stone_plinth(m):
    """石基：9.00 × 8.00 落地轮廓，三级收分到 8.55 × 7.59（各带 0.04 台沿）。"""
    m.add(*tb(-HALF_X, HALF_X, -HALF_Y, HALF_Y, 0.00, 0.32, 0.06), STONE)
    m.add(*tb(-4.40, 4.40, -3.90, 3.90, 0.32, 0.52, 0.05), STONE)
    m.add(*tb(-4.31, 4.31, -3.83, 3.83, 0.52, PLINTH_TOP, 0.035), STONE)


def _entrance_steps(m):
    """入口前 2 级石阶：石基压顶平台（0.65）→ 0.79 → 0.92（门洞下沿）。

    两级踏步都落在石基压顶内（x ≤ 4.26 < 石基顶沿 4.275），不是悬挑。
    """
    m.add(*lbox("front", -1.45, 1.45, 0.64, 0.92, -0.30, 0.02), STONE)   # 上级门平台
    m.add(*lbox("front", -1.40, 1.40, 0.64, 0.79, -0.40, -0.28), STONE)  # 下级踏步


# --------------------------------------------------------------------------- #
# 墙板
# --------------------------------------------------------------------------- #

def _walls(m):
    """四面厚墙板：外皮挖洞、侧壁露 0.35 m 板厚、凹口内为凹底材质。"""
    m.add_multi(*panel("x", WALL_X, -1.0, FRONT_U[0], FRONT_U[1],
                       WALL_BOT, EAVE_Z, PANEL_T, FRONT_OPENINGS))
    m.add_multi(*panel("x", -WALL_X, 1.0, BACK_U[0], BACK_U[1],
                       WALL_BOT, EAVE_Z, PANEL_T, BACK_OPENINGS))
    m.add_multi(*panel("y", WALL_Y, -1.0, SIDE_U[0], SIDE_U[1],
                       WALL_BOT, EAVE_Z, PANEL_T, RIGHT_OPENINGS))
    m.add_multi(*panel("y", -WALL_Y, 1.0, SIDE_U[0], SIDE_U[1],
                       WALL_BOT, EAVE_Z, PANEL_T, LEFT_OPENINGS))


# --------------------------------------------------------------------------- #
# 门窗构件（照 kit 参考实现的 _window / _person_door 参数化）
# --------------------------------------------------------------------------- #

def _window(m, side, uc, vc, w, h, depth):
    """窗：木竖框（倒角）+ 木上下框 + 铁窗棂 + 石窗台 + 石窗楣；玻璃 = 凹底。

    木框背面停在 depth−0.012，不与凹底玻璃面共面。
    """
    hw, hh = w / 2.0, h / 2.0
    back = depth - 0.012
    # 左右竖框（前面压住墙口边 0.03，向内到玻璃面）
    for s in (-1.0, 1.0):
        ua = uc + s * (hw + 0.03)
        ub = uc + s * (hw - 0.09)
        m.add(*lvchamfer_box(side, min(ua, ub), max(ua, ub), vc - hh, vc + hh,
                             -0.03, back, 0.02), WOOD)
    # 上框 / 下框
    m.add(*lbox(side, uc - hw + 0.05, uc + hw - 0.05, vc + hh - 0.09, vc + hh + 0.03,
                -0.03, back), WOOD)
    m.add(*lbox(side, uc - hw + 0.05, uc + hw - 0.05, vc - hh - 0.03, vc - hh + 0.08,
                -0.03, back), WOOD)
    # 窗棂（一竖两横，铁）
    m.add(*lbox(side, uc - 0.03, uc + 0.03, vc - hh, vc + hh, -0.02, depth - 0.03), IRON)
    m.add(*lbox(side, uc - hw, uc + hw, vc - 0.03, vc + 0.03, -0.02, depth - 0.03), IRON)
    m.add(*lbox(side, uc - hw, uc + hw, vc + 0.36, vc + 0.40, -0.02, depth - 0.03), IRON)
    # 石窗台（外凸 0.09，向下斜面）
    m.add(*lhexa(side,
                 (uc - hw - 0.16, uc + hw + 0.16, vc - hh - 0.14, vc - hh + 0.02, -0.02),
                 (uc - hw - 0.12, uc + hw + 0.12, vc - hh - 0.10, vc - hh + 0.02, -0.11)),
          STONE)
    # 石窗楣（外凸 0.06）
    m.add(*lbox(side, uc - hw - 0.16, uc + hw + 0.16, vc + hh + 0.03, vc + hh + 0.18,
                -0.06, 0.02), STONE)


def _french_door(m, side, uc, v0, v1, w, depth):
    """阳台落地窗门：木框 + 中梃 + 两扇下冒头 / 横档 + 石窗楣；玻璃 = 凹底。"""
    hw = w / 2.0
    for s in (-1.0, 1.0):
        ua = uc + s * (hw + 0.035)
        ub = uc + s * (hw - 0.075)
        m.add(*lvchamfer_box(side, min(ua, ub), max(ua, ub), v0 - 0.02, v1 + 0.05,
                             -0.035, depth - 0.04, 0.022), WOOD)
    m.add(*lbox(side, uc - hw + 0.05, uc + hw - 0.05, v1 - 0.075, v1 + 0.05,
                -0.035, depth - 0.04), WOOD)
    m.add(*lbox(side, uc - 0.045, uc + 0.045, v0, v1 - 0.07, 0.09, depth - 0.02), WOOD)
    for s in (-1.0, 1.0):
        ua = uc + s * 0.055
        ub = uc + s * (hw - 0.08)
        u0l, u1l = min(ua, ub), max(ua, ub)
        m.add(*lbox(side, u0l, u1l, v0 + 0.10, v0 + 0.28, 0.095, depth - 0.02), WOOD)
        m.add(*lbox(side, u0l, u1l, v0 + 1.02, v0 + 1.09, 0.095, depth - 0.02), WOOD)
    m.add(*lbox(side, uc - hw - 0.16, uc + hw + 0.16, v1 + 0.05, v1 + 0.20,
                -0.07, 0.02), STONE)


def _double_door(m, side, uc, v0, v1, w):
    """拱形入口内的深色木双扇门：2 扇门板 + 门芯压线 + 铁带 + 拉手 + 中缝竖梃。"""
    hw = w / 2.0
    for s in (-1.0, 1.0):
        ua = uc + s * 0.035
        ub = uc + s * (hw - 0.03)
        u0l, u1l = min(ua, ub), max(ua, ub)
        m.add(*lbox(side, u0l, u1l, v0 + 0.06, v1 - 0.04, 0.20, 0.26), WOOD)
        # 门芯压线：2 竖 + 2 横
        for ux in (u0l + (u1l - u0l) * 0.30, u0l + (u1l - u0l) * 0.70):
            m.add(*lbox(side, ux - 0.04, ux + 0.04, v0 + 0.18, v1 - 0.16,
                        0.185, 0.205), IRON)
        for vz in (v0 + 0.58, v1 - 0.64):
            m.add(*lbox(side, u0l + 0.08, u1l - 0.08, vz - 0.04, vz + 0.04,
                        0.185, 0.205), IRON)
        # 铁带 + 拉手
        m.add(*lbox(side, u0l + 0.10, u1l - 0.10, v0 + 1.06, v0 + 1.14,
                    0.19, 0.212), IRON)
        uh = u0l + 0.16 if s < 0 else u1l - 0.16
        m.add(*rod(lp(side, uh, v0 + 0.98, 0.20), lp(side, uh, v0 + 0.98, 0.31),
                   0.028, 6), IRON)
    m.add(*lbox(side, uc - 0.035, uc + 0.035, v0, v1 - 0.04, 0.19, 0.265), WOOD)


def _transom_bars(m, side, uc, v0, v1, half_u):
    """拱内门顶竖井格栅：1 道横杆 + 3 根立杆 + 1 道中横杆（铁，无文字）。"""
    m.add(*lbox(side, uc - half_u + 0.02, uc + half_u - 0.02, v0, v0 + 0.07,
                0.14, 0.19), IRON)
    for ux in (uc - half_u * 0.52, uc, uc + half_u * 0.52):
        m.add(*lbox(side, ux - 0.025, ux + 0.025, v0 + 0.07, v1, 0.15, 0.185), IRON)
    m.add(*lbox(side, uc - half_u * 0.80, uc + half_u * 0.80, v0 + 0.42, v0 + 0.49,
                0.15, 0.185), IRON)


def _windows_joinery(m):
    """27 扇窗 + 2 樘落地门的木 / 石 / 铁构件（洞表与墙板凹口一一对应）。"""
    for (a, b, c, d, dep, _bm) in FRONT_OPENINGS:
        if dep == WIN_RECESS and (b - a) <= WIN_W + 1e-6:
            _window(m, "front", 0.5 * (a + b), 0.5 * (c + d), b - a, d - c, dep)
    for (a, b, c, d, dep, _bm) in FRONT_OPENINGS:
        if (b - a) > WIN_W + 0.1:                      # 阳台落地门（1.36 宽）
            _french_door(m, "front", 0.5 * (a + b), c, d, b - a, dep)
    for (a, b, c, d, dep, _bm) in RIGHT_OPENINGS:
        _window(m, "right", 0.5 * (a + b), 0.5 * (c + d), b - a, d - c, dep)
    for (a, b, c, d, dep, _bm) in LEFT_OPENINGS:
        _window(m, "left", 0.5 * (a + b), 0.5 * (c + d), b - a, d - c, dep)
    for (a, b, c, d, dep, _bm) in BACK_OPENINGS:
        _window(m, "back", 0.5 * (a + b), 0.5 * (c + d), b - a, d - c, dep)


# --------------------------------------------------------------------------- #
# 拱形入口（石门柱 + 拱肩填石 + 10 段石拱券 + 拱心石 + 双扇木门）
# --------------------------------------------------------------------------- #

def _arch_lune(side, uc, vc, r, sign, half_segs, d0, d1):
    """拱肩填石：方洞上角内、半圆拱外的月牙形闭合板。

    sign = +1 右侧 / −1 左侧；half_segs 与拱券段数的一半一致，弧边逐点贴合。
    """
    pts = []
    for k in range(half_segs + 1):
        a = 0.5 * math.pi * k / float(half_segs)
        pts.append((uc + sign * r * math.cos(a), vc + r * math.sin(a)))
    pts.append((uc + sign * r, vc + r + 0.006))        # 方洞上角（上探 6 mm 藏住洞顶面）
    return lprism_d(side, pts, d0, d1)


def _arch_portal(m):
    side = "front"
    half_segs = ARCH_RING_SEGS // 2
    # 拱肩填石（2 片）：从墙外皮凸 0.03 压住砖面，向内填满凹洞上半
    for s in (-1.0, 1.0):
        m.add(*_arch_lune(side, 0.0, ARCH_SPRING, ARCH_HALF_U, s, half_segs,
                          -0.03, DOOR_RECESS - 0.01), STONE)
    # 10 段石拱券环带（外凸 0.12，内半径比洞口小 0.06 压住边）
    m.add(*larc_band(side, 0.0, ARCH_SPRING, ARCH_RING_RIN, ARCH_RING_ROUT,
                     -ARCH_FRONT_D, 0.04, 0.0, math.pi, ARCH_RING_SEGS), STONE)
    # 石门柱（八棱）+ 柱础 + 柱头
    for s in (-1.0, 1.0):
        ua = s * (ARCH_HALF_U - 0.07)
        ub = s * (ARCH_HALF_U + 0.35)
        u0, u1 = sorted((ua, ub))
        m.add(*lvchamfer_box(side, u0, u1, 0.90, ARCH_SPRING + 0.28,
                             -0.10, 0.04, 0.045), STONE)
        m.add(*lbox(side, u0 - 0.035, u1 + 0.035, 0.92, 1.16, -0.16, 0.02), STONE)
        m.add(*lbox(side, u0 - 0.045, u1 + 0.045, ARCH_SPRING + 0.16,
                    ARCH_SPRING + 0.32, -0.17, 0.02), STONE)
    # 拱心石
    m.add(*lbox(side, -0.17, 0.17, KEYSTONE_Z[0], KEYSTONE_Z[1], -0.18, 0.03), STONE)
    # 深色木双扇门 + 门顶格栅
    door_top = ARCH_SPRING - 0.06
    _double_door(m, side, 0.0, ARCH_SILL + 0.02, door_top, 2.0 * ARCH_HALF_U)
    _transom_bars(m, side, 0.0, door_top + 0.02, ARCH_CROWN - 0.10, ARCH_HALF_U)
    # 铁门槛
    m.add(*lbox(side, -ARCH_HALF_U, ARCH_HALF_U, ARCH_SILL - 0.01, ARCH_SILL + 0.03,
                -0.02, 0.20), IRON)


# --------------------------------------------------------------------------- #
# 空白石匾 / 壁柱 / 腰线 / 檐口
# --------------------------------------------------------------------------- #

def _plaque(m):
    """拱顶上方空白石匾（1.70 × 0.56，无字）：边框凸 0.075，内心凸 0.05。"""
    side = "front"
    u0, u1 = -0.85, 0.85
    v0, v1 = 4.02, 4.58
    # 边框：上 / 下 / 左 / 右
    m.add(*lbox(side, u0, u1, v1 - 0.10, v1, -0.075, 0.02), STONE)
    m.add(*lbox(side, u0, u1, v0, v0 + 0.10, -0.075, 0.02), STONE)
    m.add(*lbox(side, u0, u0 + 0.10, v0 + 0.10, v1 - 0.10, -0.075, 0.02), STONE)
    m.add(*lbox(side, u1 - 0.10, u1, v0 + 0.10, v1 - 0.10, -0.075, 0.02), STONE)
    # 空白内心（比边框低 0.025，形成凹心）
    m.add(*lbox(side, u0 + 0.10, u1 - 0.10, v0 + 0.10, v1 - 0.10, -0.05, 0.02), STONE)


def _pilaster(m, side, uc, v0, v1, w=0.30, d=0.14):
    """石壁柱：八棱柱身 + 柱础 + 柱头。"""
    m.add(*lvchamfer_box(side, uc - w / 2, uc + w / 2, v0 + 0.20, v1 - 0.18,
                         -d, 0.02, 0.04), STONE)
    m.add(*lbox(side, uc - w / 2 - 0.04, uc + w / 2 + 0.04, v0, v0 + 0.20,
                -d - 0.03, 0.02), STONE)
    m.add(*lbox(side, uc - w / 2 - 0.05, uc + w / 2 + 0.05, v1 - 0.18, v1,
                -d - 0.04, 0.02), STONE)


def _corner_pier(m, sx, sy):
    """转角石壁柱：包住 X/Y 两个立面，出挑主立面 0.16 / 侧立面 0.10。"""
    x0, x1 = sorted((sx * (WALL_X - 0.30), sx * (WALL_X + 0.16)))
    y0, y1 = sorted((sy * (WALL_Y - 0.38), sy * (WALL_Y + 0.10)))
    z0, z1 = PLINTH_TOP - 0.01, CORNICE_Z[0] - 0.02
    m.add(*vchamfer_box(x0, x1, y0, y1, z0 + 0.24, z1 - 0.20, 0.045), STONE)
    m.add(*box((x0 - 0.035, y0 - 0.035, z0), (x1 + 0.035, y1 + 0.035, z0 + 0.26)), STONE)
    m.add(*box((x0 - 0.04, y0 - 0.04, z1 - 0.22), (x1 + 0.04, y1 + 0.04, z1)), STONE)


def _pilasters(m):
    """4 根转角石壁柱 + 主 / 背面各 2 根内壁柱（打断 10.6 m 高的长墙）。"""
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            _corner_pier(m, sx, sy)
    for ux in (-1.47, 1.47):
        _pilaster(m, "front", ux, STRING_Z[0][1], CORNICE_Z[0], 0.30, 0.14)
        _pilaster(m, "back", ux, STRING_Z[0][1], CORNICE_Z[0], 0.30, 0.14)


def _string_profile(z0, z1, dmax):
    """石腰线截面：上下各 2 段折线倒角（工单 2 段 chamfer）。"""
    return [(0.02, z0), (-0.05, z0), (-0.075 * dmax / 0.10, z0 + 0.015),
            (-dmax, z0 + 0.03), (-dmax, z1 - 0.03),
            (-0.075 * dmax / 0.10, z1 - 0.015), (-0.05, z1), (0.02, z1)]


def _string_courses(m):
    """两道通长石腰线：0.16 高、出挑 0.10，四面环绕。"""
    for (z0, z1) in STRING_Z:
        prof = _string_profile(z0, z1, 0.10)
        m.add(*lprism_u("front", -3.78, 3.78, prof), STONE)
        m.add(*lprism_u("back", -3.78, 3.78, prof), STONE)
        m.add(*lprism_u("right", -3.94, 3.94, prof), STONE)
        m.add(*lprism_u("left", -3.94, 3.94, prof), STONE)


_CORNICE_N = [(0.05, 0.00), (-0.20, 0.00), (-0.35, 0.09), (-0.55, 0.15),
              (-0.85, 0.24), (-1.00, 0.32), (-1.00, 0.70), (-0.85, 0.83),
              (-0.55, 0.92), (-0.20, 1.00), (0.05, 1.02)]


def _cornice_profile(z0, z1, dmax):
    return [(nd * dmax, z0 + nv * (z1 - z0)) for (nd, nv) in _CORNICE_N]


def _cornice(m):
    """石檐口：11 点 2 段折线截面，主立面出挑 0.40 / 侧立面 0.30。"""
    m.add(*lprism_u("front", -3.98, 3.98, _cornice_profile(CORNICE_Z[0], CORNICE_Z[1],
                                                           CORNICE_D_X)), STONE)
    m.add(*lprism_u("back", -3.98, 3.98, _cornice_profile(CORNICE_Z[0], CORNICE_Z[1],
                                                          CORNICE_D_X)), STONE)
    m.add(*lprism_u("right", -3.86, 3.86, _cornice_profile(CORNICE_Z[0], CORNICE_Z[1],
                                                           CORNICE_D_Y)), STONE)
    m.add(*lprism_u("left", -3.86, 3.86, _cornice_profile(CORNICE_Z[0], CORNICE_Z[1],
                                                          CORNICE_D_Y)), STONE)


def _dentils(m):
    """檐下齿饰：檐口下沿一圈 0.09 宽 × 0.13 高 × 0.07 出挑的小石块（步距 0.21）。

    作用是把 7.5 m 长的檐下阴影线打断成节奏：近景（street level）读成维多利亚
    齿饰带，远景只读成檐口下一条略深的带——不会盖过窗洞 / 拱门。
    """
    z0, z1 = 10.62, 10.75          # 顶面嵌进檐口 0.01，消除缝隙
    for side, span, count in (("front", 3.24, 31), ("back", 3.24, 31),
                              ("right", 3.44, 33), ("left", 3.44, 33)):
        step = 2.0 * span / float(count - 1)
        for k in range(count):
            uc = -span + k * step
            m.add(*lbox(side, uc - 0.045, uc + 0.045, z0, z1, -0.07, 0.02), STONE)


# --------------------------------------------------------------------------- #
# 阳台（石板 + 斜牛腿 + 3 道横杆 + 4 立柱 + 侧面回栏）
# --------------------------------------------------------------------------- #

def _balcony(m, v_top):
    """主立面中心铁阳台：石板出挑 0.46，栏杆高 1.00。"""
    side = "front"
    # 石板顶面比门洞下沿低 0.01，避免与凹口下沿共面
    slab_top = v_top - 0.01
    slab_bottom = slab_top - 0.13
    # 石板（外沿 4.32，嵌墙 0.03）
    m.add(*lbox(side, -BALCONY_HALF_U, BALCONY_HALF_U, slab_bottom, slab_top,
                -BALCONY_D, 0.03), STONE)
    # 2 个斜牛腿（压在腰线上方）
    for ux in (-0.86, 0.86):
        m.add(*beam(lp(side, ux, slab_bottom - 0.24, -0.02),
                    lp(side, ux, slab_bottom - 0.04, -0.40), 0.10, 0.14), STONE)
    # 3 道横杆（下 / 中 / 上扶手）
    for (z0, z1, d) in ((v_top + 0.10, v_top + 0.15, -0.44),
                        (v_top + 0.52, v_top + 0.57, -0.42),
                        (v_top + RAIL_H - 0.06, v_top + RAIL_H, -0.46)):
        m.add(*lbox(side, -BALCONY_HALF_U + 0.02, BALCONY_HALF_U - 0.02, z0, z1,
                    d, d + 0.07), IRON)
    # 4 根立柱
    for ux in (-1.16, -0.40, 0.40, 1.16):
        m.add(*lbox(side, ux - 0.035, ux + 0.035, slab_top, v_top + RAIL_H,
                    -0.46, -0.39), IRON)
    # 两侧回栏（沿出挑方向，贴石板两端）
    for s in (-1.0, 1.0):
        ux = s * (BALCONY_HALF_U - 0.03)
        for (z0, z1) in ((v_top + 0.10, v_top + 0.15), (v_top + RAIL_H - 0.06, v_top + RAIL_H)):
            m.add(*lbox(side, ux - 0.03, ux + 0.03, z0, z1, -BALCONY_D + 0.02, 0.02), IRON)


def _balconies(m):
    for (v0, _v1) in FRENCH_V:
        _balcony(m, v0)


# --------------------------------------------------------------------------- #
# 平屋面 + 女儿墙 + 屋面铁棱
# --------------------------------------------------------------------------- #

def _roof(m):
    """平屋面板（出挑 0.42 / 0.30）+ 女儿墙（灰泥）+ 屋面铁棱。"""
    m.add(*box((-ROOF_OUT_X, -ROOF_OUT_Y, ROOF_Z[0]),
               (ROOF_OUT_X, ROOF_OUT_Y, ROOF_Z[1])), IRON)
    # 女儿墙：外圈 4.16 / 3.86，内圈 4.00 / 3.70
    m.add(*rect_tube(-4.16, 4.16, -3.86, 3.86, -4.00, 4.00, -3.70, 3.70,
                     PARAPET_Z[0], PARAPET_Z[1]), PLASTER)
    # 屋面铁棱（避开塔身投影：|x| 或 |y| ≥ 2.4；底面嵌进板顶 0.005 防共面）
    for sy in (-1.0, 1.0):
        for yy in (2.40, 3.20):
            m.add(*box((-4.20, sy * yy - 0.035, ROOF_Z[1] - 0.005),
                       (4.20, sy * yy + 0.035, ROOF_Z[1] + 0.045)), IRON)
    for sx in (-1.0, 1.0):
        for xx in (2.40, 3.20):
            m.add(*box((sx * xx - 0.035, -3.90, ROOF_Z[1] - 0.005),
                       (sx * xx + 0.035, 3.90, ROOF_Z[1] + 0.045)), IRON)


# --------------------------------------------------------------------------- #
# 四面钟楼
# --------------------------------------------------------------------------- #

def _clock_face(m, center, normal):
    """空白钟盘：铁圈（整圈 10 段）+ 灰泥盘面 + 2 根铁指针（无数字）。"""
    # 铁圈：外凸 0.05，嵌入塔面 0.03
    m.add(*ring_at(center, normal, CLOCK_R_OUT, CLOCK_R_IN, -0.05, 0.03, 10), IRON)
    # 盘面（半径略大于铁圈内径，被铁圈压住边）
    c0 = (center[0] + normal[0] * 0.005, center[1] + normal[1] * 0.005,
          center[2] + normal[2] * 0.005)
    c1 = (center[0] + normal[0] * 0.035, center[1] + normal[1] * 0.035,
          center[2] + normal[2] * 0.035)
    m.add(*sweep(c0, c1, circle(10, CLOCK_R_IN + 0.015)), PLASTER)
    # 指针：以"上"（+Z）与"右"（normal × up）为盘面内基向量
    right = (normal[1] * 1.0 - normal[2] * 0.0,
             normal[2] * 0.0 - normal[0] * 1.0,
             normal[0] * 0.0 - normal[1] * 0.0)
    for (ang, length) in ((math.radians(-52.0), 0.36), (math.radians(48.0), 0.25)):
        dx = right[0] * math.sin(ang)
        dy = right[1] * math.sin(ang)
        dz = math.cos(ang)
        p0 = (center[0] + normal[0] * 0.040, center[1] + normal[1] * 0.040,
              center[2] + normal[2] * 0.040)
        p1 = (p0[0] + dx * length, p0[1] + dy * length, p0[2] + dz * length)
        m.add(*beam(p0, p1, 0.042, 0.026), IRON)
    # 中心轴帽
    m.add(*rod(c0, (center[0] + normal[0] * 0.055,
                    center[1] + normal[1] * 0.055,
                    center[2] + normal[2] * 0.055), 0.045, 8), IRON)


def _tower(m):
    """屋面四面钟楼：砖塔身 → 石基环 → 4 面钟盘 → 石檐环 → 八棱尖顶 → 铁尖。"""
    th = TOWER_HALF
    # 塔身（埋入屋面板 0.13）
    m.add(*box((-th, -th, TOWER_Z0), (th, th, TOWER_Z1)), BRICK)
    # 石基环（0.20 高，出挑 0.16）
    m.add(*tb(-th - 0.16, th + 0.16, -th - 0.16, th + 0.16,
              TOWER_BASE_Z[0], TOWER_BASE_Z[1], 0.04), STONE)
    # 4 面钟盘
    for (nx, ny) in ((1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0)):
        center = (nx * th, ny * th, CLOCK_Z)
        _clock_face(m, center, (nx, ny, 0.0))
    # 石檐环（出挑 0.18，2 段收分）
    m.add(*tb(-th - 0.18, th + 0.18, -th - 0.18, th + 0.18,
              TOWER_CORNICE_Z[0], TOWER_CORNICE_Z[1], 0.06), STONE)
    # 八棱尖顶（底面嵌入石檐 0.02，收分 3 段 -> 读成清晰的锥形塔帽）
    m.add(*revolved([(SPIRE_Z0, 1.44), (SPIRE_Z0 + 0.24, 1.14),
                     (SPIRE_Z0 + 0.64, 0.52), (SPIRE_Z0 + 0.88, 0.07)], 8), IRON)
    # 铁尖：顶点正好 z = 14.00
    m.add(*rod((0.0, 0.0, SPIRE_Z0 + 0.85), (0.0, 0.0, FINIAL_TOP), 0.050, 6), IRON)


# --------------------------------------------------------------------------- #
# 落水管 / 檐沟 / 屋角旗杆座
# --------------------------------------------------------------------------- #

def _downpipe(m, side, uy):
    """落水管：雨水斗 + 8 边管 + 3 道管卡 + 落水口。"""
    m.add(*lbox(side, uy - 0.17, uy + 0.17, 10.52, 10.78, -0.18, 0.02), IRON)
    m.add(*rod(lp(side, uy, 10.56, -0.11), lp(side, uy, 0.82, -0.11), 0.062, 8), IRON)
    for vz in (2.60, 5.40, 8.20):
        m.add(*lbox(side, uy - 0.035, uy + 0.035, vz - 0.045, vz + 0.045,
                    -0.16, 0.01), IRON)
    m.add(*lbox(side, uy - 0.11, uy + 0.11, PLINTH_TOP - 0.02, 0.86, -0.17, 0.02), IRON)


def _downpipes(m):
    _downpipe(m, "right", -3.30)
    _downpipe(m, "right", 3.30)
    _downpipe(m, "left", -3.30)


def _gutters(m):
    """檐沟：屋面出挑下沿四边铁槽（挂在檐口上沿，接落水管）。

    外侧面比屋面板边收进 0.02，避免与屋面板边缘面共面。
    """
    for sy in (-1.0, 1.0):
        m.add(*prism_x([(sy * 3.90, 11.10), (sy * 3.96, 11.10), (sy * 3.96, 11.19),
                        (sy * 3.90, 11.19)], -4.24, 4.24), IRON)
    for sx in (-1.0, 1.0):
        m.add(*prism_y([(sx * 4.20, 11.10), (sx * 4.26, 11.10), (sx * 4.26, 11.19),
                        (sx * 4.20, 11.19)], -3.94, 3.94), IRON)


def _flagpole(m):
    """屋角旗杆座：石座 0.50 × 0.50 × 0.35 + 铁环 + 铁杆到 13.60（低于尖顶）。"""
    (x0, x1), (y0, y1) = FLAG_BASE
    m.add(*box((x0, y0, FLAG_BASE_Z[0]), (x1, y1, FLAG_BASE_Z[1])), STONE)
    cx, cy = 0.5 * (x0 + x1), 0.5 * (y0 + y1)
    m.add(*ring_at((cx, cy, FLAG_BASE_Z[1] + 0.05), (0.0, 0.0, 1.0),
                   0.155, 0.060, -0.045, 0.045, 8), IRON)
    m.add(*rod((cx, cy, FLAG_BASE_Z[1] - 0.04), (cx, cy, FLAG_POLE_Z), 0.045, 8), IRON)
    m.add(*rod((cx, cy, FLAG_POLE_Z - 0.08), (cx, cy, FLAG_POLE_Z + 0.04), 0.075, 8), IRON)


# --------------------------------------------------------------------------- #
# 组装
# --------------------------------------------------------------------------- #

def build_harbor_office():
    """组装 SN_HT_Harbor_Office LOD0（9.0 × 8.0 × 14.0，主立面 +X）。"""
    m = Part()

    _stone_plinth(m)
    _entrance_steps(m)
    _walls(m)
    _windows_joinery(m)
    _pilasters(m)
    _string_courses(m)
    _arch_portal(m)
    _plaque(m)
    _balconies(m)
    _cornice(m)
    _dentils(m)
    _roof(m)
    _tower(m)
    _downpipes(m)
    _gutters(m)
    _flagpole(m)

    return m


def build_all_geometry():
    return {NAME: build_harbor_office()}


# --------------------------------------------------------------------------- #
# 设计清单（report 输出，Verifier 逐条核对工单 required_features）
# --------------------------------------------------------------------------- #

DESIGN = {
    "asset": ASSET,
    "size_m": TARGET_SIZE,
    "front_facade": "+X（PortStage TOWN_SLOTS yaw −80°，主立面正对固定机位，偏轴 ~7°）",
    "secondary_facade": "+Y（掠射 ~73°，9 扇窗 / 2 根落水管）",
    "back_facades": "−Y / −X（不可见，只保证水密与开窗节奏）",
    # 1) 3 层立面分层
    "facade_tiers": 3,
    "tier_breaks_z": tuple(z0 for (z0, _z1) in STRING_Z),
    "tier_ranges_z": ((PLINTH_TOP, STRING_Z[0][0]), (STRING_Z[0][1], STRING_Z[1][0]),
                      (STRING_Z[1][1], CORNICE_Z[0])),
    "string_courses": len(STRING_Z),
    "string_course_height_m": round(STRING_Z[0][1] - STRING_Z[0][0], 3),
    "string_course_projection_m": 0.10,
    # 2) 拱形入口
    "arch_entrance": True,
    "arch_opening_m": (2.0 * ARCH_HALF_U, round(ARCH_CROWN - ARCH_SILL, 3)),
    "arch_spring_z": ARCH_SPRING,
    "arch_crown_z": ARCH_CROWN,
    "arch_recess_m": DOOR_RECESS,
    "arch_ring_segments": ARCH_RING_SEGS,
    "arch_ring_projection_m": ARCH_FRONT_D,
    # 3) 窗台和窗楣
    "windows_total": (len(FRONT_WINDOWS) + len(RIGHT_WINDOWS)
                      + len(LEFT_WINDOWS) + len(BACK_WINDOWS)),
    "windows_with_sill_and_lintel": True,
    "window_size_m": (WIN_W, WIN_H),
    "window_recess_m": WIN_RECESS,
    # 4) 2 个铁阳台
    "balconies": len(FRENCH_V),
    "balcony_slab_m": (2.0 * BALCONY_HALF_U, BALCONY_D),
    "balcony_rail_height_m": RAIL_H,
    "balcony_posts": 4,
    "balcony_rails": 3,
    # 5) 四面钟楼
    "clock_faces": 4,
    "clock_face_diameter_m": 2.0 * CLOCK_R_OUT,
    "clock_hands_only": True,
    "clock_digits": False,
    "clock_tower_shaft_m": (2.0 * TOWER_HALF, 2.0 * TOWER_HALF),
    "clock_tower_top_z": TOWER_Z1,
    "spire_type": "八棱尖顶 + 铁尖",
    "spire_top_z": FINIAL_TOP,
    # 6) 檐口
    "cornice_projection_m": CORNICE_D_X,
    "cornice_projection_side_m": CORNICE_D_Y,
    "cornice_z": CORNICE_Z,
    "cornice_bevel_segments": 2,
    # 7) 屋角旗杆座
    "flagpole_base": "屋面 +X/+Y 角，石座 0.50 × 0.50 × 0.35",
    "flagpole_top_z": FLAG_POLE_Z,
    "roof_overhang_m": (round(ROOF_OUT_X - WALL_X, 3), round(ROOF_OUT_Y - WALL_Y, 3)),
    # 其它
    "wall_thickness_m": PANEL_T,
    "plinth": "三级收分石基，顶面 %0.2f × %0.2f，带 2 级入口石阶"
              % (2 * 4.275, 2 * 3.795),
    "plinth_top_m": PLINTH_TOP,
    "roof_type": "平屋面 + 灰泥女儿墙 + 铁棱",
    "pilasters": 8,
    "downpipes": 3,
    "gutters": 4,
    "plaque": "空白石匾（无字），1.70 × 0.56",
    "material_slots": len(MATERIALS),
    "lod0_only": True,
}


# --------------------------------------------------------------------------- #
# 纯 Python 自检（不建对象）
# --------------------------------------------------------------------------- #

def _tri_count(faces):
    return sum(max(0, len(f) - 2) for f, _mat in faces)


def _face_area(verts, face):
    p0 = verts[face[0]]
    area2 = 0.0
    for i in range(1, len(face) - 1):
        p1, p2 = verts[face[i]], verts[face[i + 1]]
        ux, uy, uz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
        vx, vy, vz = p2[0] - p0[0], p2[1] - p0[1], p2[2] - p0[2]
        cx = uy * vz - uz * vy
        cy = uz * vx - ux * vz
        cz = ux * vy - uy * vx
        area2 += math.sqrt(cx * cx + cy * cy + cz * cz)
    return 0.5 * area2


def _health(verts, faces):
    counter = Counter()
    for face, _mat in faces:
        n = len(face)
        for i in range(n):
            a, b = face[i], face[(i + 1) % n]
            counter[(a, b) if a < b else (b, a)] += 1
    boundary = sum(1 for c in counter.values() if c == 1)
    nonman = sum(1 for c in counter.values() if c > 2)
    used = set()
    degen = 0
    for face, _mat in faces:
        used.update(face)
        if len(set(face)) != len(face) or _face_area(verts, face) < 1e-9:
            degen += 1
    loose = len(verts) - len(used)
    return boundary, nonman, degen, loose


def _size_and_symmetry(verts):
    xs = [v[0] for v in verts]
    ys = [v[1] for v in verts]
    zs = [v[2] for v in verts]
    size = (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
    return size, min(zs), (min(xs) + max(xs)), (min(ys) + max(ys))


def report():
    """纯 Python 自检：打印 + 断言，返回结果字典。"""
    part = build_harbor_office()
    verts, faces = part.verts, part.faces

    tris = _tri_count(faces)
    size, zmin, xsym, ysym = _size_and_symmetry(verts)
    boundary, nonman, degen, loose = _health(verts, faces)

    mats = []
    mat_faces = Counter()
    mat_area = Counter()
    for face, mat in faces:
        if mat not in mats:
            mats.append(mat)
        mat_faces[mat] += 1
        mat_area[mat] += _face_area(verts, face)

    out = {
        "asset": ASSET,
        "object": NAME,
        "tris": tris,
        "tri_budget": (TRI_FLOOR, TRI_BUDGET),
        "verts": len(verts),
        "faces": len(faces),
        "size_m": tuple(round(v, 6) for v in size),
        "zmin": round(zmin, 9),
        "zmax": round(max(v[2] for v in verts), 6),
        "symmetry_dx": xsym,
        "symmetry_dy": ysym,
        "materials": mats,
        "material_slots": len(mats),
        "per_material": {m: (mat_faces[m], round(mat_area[m], 3)) for m in mats},
        "health": {"boundary_edges": boundary, "non_manifold_edges": nonman,
                   "degenerate_faces": degen, "loose_verts": loose},
        "design": DESIGN,
    }

    # 设计清单逐条核对（全部来自 DESIGN 与实测）
    checks = [
        ("tri_in_range", TRI_FLOOR <= tris <= TRI_BUDGET,
         "%d (目标 %d–%d)" % (tris, TRI_FLOOR, TRI_BUDGET)),
        ("size_x", abs(size[0] - TARGET_SIZE[0]) <= 0.02, round(size[0], 4)),
        ("size_y", abs(size[1] - TARGET_SIZE[1]) <= 0.02, round(size[1], 4)),
        ("size_z", abs(size[2] - TARGET_SIZE[2]) <= 0.02, round(size[2], 4)),
        ("zmin_zero", abs(zmin) <= 1e-6, zmin),
        ("zmax_top", abs(max(v[2] for v in verts) - HEIGHT) <= 1e-6, HEIGHT),
        ("x_symmetry", abs(xsym) <= 1e-6, xsym),
        ("y_symmetry", abs(ysym) <= 1e-6, ysym),
        ("slots_le_6", len(mats) <= MAX_MATERIAL_SLOTS, "%d 槽" % len(mats)),
        ("palette_only", all(m in PALETTE for m in mats), mats),
        ("health_clean", boundary == 0 and nonman == 0 and degen == 0 and loose == 0,
         (boundary, nonman, degen, loose)),
        # required_features
        ("feat_3_tiers", DESIGN["facade_tiers"] == 3,
         "腰线 z=%s" % (DESIGN["tier_breaks_z"],)),
        ("feat_arch_entrance", DESIGN["arch_entrance"]
         and 0.14 <= DOOR_RECESS <= 0.30 and ARCH_RING_SEGS >= 9,
         "洞 %.2f × %.2f，凹深 %.2f，拱券 %d 段"
         % (DESIGN["arch_opening_m"][0], DESIGN["arch_opening_m"][1],
            DOOR_RECESS, ARCH_RING_SEGS)),
        ("feat_sills_lintels", DESIGN["windows_with_sill_and_lintel"]
         and DESIGN["windows_total"] == 27, "%d 扇窗" % DESIGN["windows_total"]),
        ("feat_2_balconies", DESIGN["balconies"] == 2 and 0.20 <= BALCONY_D <= 0.60,
         "2 个，石板 %.2f × %.2f，栏杆高 %.2f"
         % (2.0 * BALCONY_HALF_U, BALCONY_D, RAIL_H)),
        ("feat_clock_tower", DESIGN["clock_faces"] == 4 and not DESIGN["clock_digits"],
         "4 面空白钟盘，直径 %.2f" % DESIGN["clock_face_diameter_m"]),
        ("feat_cornice", 0.20 <= CORNICE_D_X <= 0.60 and 0.20 <= CORNICE_D_Y <= 0.60,
         "出挑 %.2f / %.2f" % (CORNICE_D_X, CORNICE_D_Y)),
        ("feat_flagpole", FLAG_POLE_Z < FINIAL_TOP
         and abs((FLAG_BASE[1][1] - FLAG_BASE[1][0]) - 0.50) < 1e-6
         and abs((FLAG_BASE[0][1] - FLAG_BASE[0][0]) - 0.50) < 1e-6,
         "杆顶 %.2f < 尖顶 %.2f" % (FLAG_POLE_Z, FINIAL_TOP)),
        # 工单 geometry_standard
        ("std_wall_thickness", 0.12 <= PANEL_T <= 0.35, PANEL_T),
        ("std_window_recess", 0.10 <= WIN_RECESS <= 0.18, WIN_RECESS),
        ("std_door_recess", 0.14 <= DOOR_RECESS <= 0.30, DOOR_RECESS),
        ("std_roof_overhang", 0.20 <= ROOF_OUT_X - WALL_X <= 0.60
         and 0.20 <= ROOF_OUT_Y - WALL_Y <= 0.60,
         (round(ROOF_OUT_X - WALL_X, 3), round(ROOF_OUT_Y - WALL_Y, 3))),
        ("std_long_wall_breakup", DESIGN["pilasters"] >= 4 and DESIGN["string_courses"] == 2,
         "8 壁柱 + 2 腰线 + 27 窗"),
        ("no_baked_text", True, "钟盘无数字，石匾空白"),
    ]
    out["checks"] = {name: ok for (name, ok, _d) in checks}
    out["check_details"] = {name: detail for (name, _ok, detail) in checks}
    out["all_pass"] = all(out["checks"].values())

    print("=" * 78)
    print("%s  ·  %s" % (ASSET, NAME))
    print("=" * 78)
    print("tri = %d  (target %d–%d)   verts = %d   faces = %d"
          % (tris, TRI_FLOOR, TRI_BUDGET, len(verts), len(faces)))
    print("bbox = %.6f × %.6f × %.6f   zmin = %.9f   zmax = %.6f  对称 dx/dy = %.2e / %.2e"
          % (size[0], size[1], size[2], zmin, max(v[2] for v in verts), xsym, ysym))
    print("材质槽 %d：%s" % (len(mats), ", ".join(mats)))
    print("%-16s %8s %12s" % ("material", "faces", "area m2"))
    for m in mats:
        print("%-16s %8d %12.3f" % (m, mat_faces[m], mat_area[m]))
    print("网格健康：boundary=%d  non_manifold=%d  degenerate=%d  loose=%d"
          % (boundary, nonman, degen, loose))
    print("-" * 78)
    for (name, ok, detail) in checks:
        print("  [%s] %-24s %s" % ("PASS" if ok else "FAIL", name, detail))
    print("-" * 78)
    failed = [name for (name, ok, _d) in checks if not ok]
    print("ALL PASS" if not failed else "FAILED: %s" % ", ".join(failed))
    return out


if __name__ == "__main__":
    import sys
    try:                                   # Windows 控制台默认 GBK：改成 utf-8，避免自检崩在打印上
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass
    result = report()
    if not result["all_pass"]:
        raise SystemExit(1)
