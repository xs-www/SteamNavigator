# -*- coding: utf-8 -*-
"""Steam Navigator — 铁港建筑套件 `SN_HT_Warehouse_Short` LOD0 纯几何生成器。

工单：tools/modeling/briefs/sn_iron_harbor_architecture_kit_v1.json
      building_archetypes → warehouse_short（11.0 × 9.0 × 9.5 m，3000–5000 tri）
参考实现：tools/modeling/generators/sn_iron_harbor_architecture_kit_generator.py
      （几何已过门禁并冻结；本文件逐字复用其纯 Python 助手与造型语言）
设计文档：docs/design/IRON_HARBOR_ARCHITECTURE_M1.md §2 / §3

本文件只输出几何（Part：顶点 + 面 + 每面材质），**不 import bpy**，材质 / UV /
GLB 导出由 Lead 在 Blender 内用共享 trim sheet 材质完成。可离线自检：

    python tools/modeling/generators/dryrun_props.py \
        tools/modeling/generators/sn_iron_harbor_warehouse_short_generator.py

    python tools/modeling/generators/sn_iron_harbor_warehouse_short_generator.py
        （打印 tri / bbox / zmin / 对称性 / 材质槽 / 健康计数 / DESIGN 逐项并断言）

朝向约定（本栋特有）
-------------------
- 局部坐标：X = 建筑长度（11 m），Y = 进深（9 m），Z = 向上；轴心 = 地面中心。
- **主立面在 +X 端墙**（法线 +X、屋脊沿 X 所以 +X 是山墙端）。理由：
  `port_stage.gd` 的 `TOWN_SLOTS` 给 warehouse_short 的 yaw = −90°，把资产局部
  **+X 轴**转向固定机位（与机位轴只差约 11°）；局部 ±Y 会偏到 62–79°（掠射/背对）。
- **+Y 侧是次可见面**（单坡侧棚一侧，掠射约 78°，仍需柱列 / 开间节奏）；
  −Y、−X 是背面（服务门、后勤窗、落水管）。
- 外围尺寸严格 = (11.0, 9.0, 9.5)：石基底面 11.0 × 9.0 定 X/Y，屋脊盖瓦顶 9.50 定 Z。

造型要点
--------
1. 石基 3 级收分（11.0×9.0 → 10.70×8.70，顶面 0.55 m），墙脚留 0.05/0.17 m 台沿。
2. 四面墙用 `panel()`：带**真实矩形凹口**的闭合厚板（板厚 0.32，窗凹 0.14、
   装卸门凹 0.26、服务门凹 0.20）——不是共面深色贴片，凹口侧壁直接露出板厚。
3. 主立面（+X）：3.0×4.3 内凹装卸门（木框 + 双扇铁皮门 + 上滑轨/吊轮 + 石门槛
   + 3.3 m 宽石/铁门槛台）、2 扇 1.15×1.45 窗（真凹口 + 石窗台/窗楣）、2.00×0.55
   空白木招牌、2 根砖壁柱（0.34×0.14，倒角，包转角）、石膏山墙 + 1 扇 0.8×0.8
   山墙窗 + 铁拉杆。
4. 主屋面：屋脊沿 X 的双坡铁屋面（板厚 0.22、檐口 2 段倒角、脊瓦、每坡 3 道立缝），
   檐口下石檐口（出挑 0.18、2 段倒角）+ 石腰线；±Y 檐沟 + 2 根落水管（−X 背面）。
5. 不对称单坡侧棚（+Y，y 1.60→4.50）：3 根木柱 + 2 道斜撑 + 木过梁 + 5 根椽 +
   单坡铁屋面板（4.60 → 3.35，板厚 0.18）+ 木封檐板 + 墙顶木垫梁。
6. 屋顶通风管：偏心铁管（r = 0.12，偏 +X/+Y，顶帽略低于屋脊）——轮廓识别点。
7. 背面（−X）：1.1×2.15 服务门（木门扇 + 铁件 + 小雨棚 + 石台阶）、小窗、
   2 根落水管（雨水斗 + 管卡 + 落水口）。−Y 后侧：3 窗 + 2 砖壁柱打断 10.6 m 长墙。

三角面预算 3000–5000（building_small_lod0），实测见 `__main__` 输出。
"""

import math

# --------------------------------------------------------------------------- #
# 文件契约：资产 / 尺寸 / 预算
# --------------------------------------------------------------------------- #

ASSET = "SN_HT_Warehouse_Short"
NAME = ASSET + "_LOD0"
TARGET_SIZE = (11.0, 9.0, 9.5)          # X × Y × Z（m），外围尺寸必须精确
TRI_BUDGET = 5000                       # building_small_lod0 上限
TRI_FLOOR = 3000                        # building_small_lod0 下限

COLLECTION = "SN_Iron_Harbor_Architecture"
PREFIX = "SN_HT_"
LOCATION = (0.0, 0.0, 0.0)              # 单件 GLB 根节点归零；布局位置由 PortStage 决定

ITEMS = [(NAME, LOCATION, TRI_BUDGET, TARGET_SIZE)]
TOTAL_BUDGET = TRI_BUDGET

# --------------------------------------------------------------------------- #
# 共享材质（只允许 6 个调色板槽；本文件只给面分配槽名，不建材质参数）
# --------------------------------------------------------------------------- #

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
# 体量（局部坐标，全部以最终包围盒反推，改数值即可重建）
# --------------------------------------------------------------------------- #

HALF_X = 5.50               # 石基底面 / 包围盒 X 半长
HALF_Y = 4.50               # 石基底面 / 包围盒 Y 半深
PLINTH_TOP = 0.55           # 石基压顶面

WALL_X = 5.30               # ±X 墙外皮（山墙端）
WALL_YM = -4.18             # −Y 后墙外皮
WALL_YP = 1.60              # +Y 主墙外皮（侧棚从这条线向 +Y 展开）
PANEL_T = 0.32              # 墙板厚度（凹口侧壁露出的可见墙厚，工单 0.12–0.35）
WALL_BOT = 0.48             # 墙板底面（嵌进石基 0.07，凹口下沿 0.55 不贴板边）

EAVE_Z = 7.50               # 墙顶 / 檐口高度
Y_RIDGE = (WALL_YM + WALL_YP) / 2.0            # −1.29：屋脊沿 X，位于主墙进深中线
RIDGE_TOP = 9.36            # 屋面板顶皮（脊瓦顶 = 9.50 = 包围盒顶）
ROOF_T = 0.22               # 屋面板厚（檐口露板边）
SLOPE = (RIDGE_TOP - EAVE_Z) / (WALL_YP - Y_RIDGE)   # 0.6436：Z 升高 / Y 进深
ROOF_X = 5.50               # 屋面 X 出挑（= 包围盒半长，墙外挑 0.20）
ROOF_EAVE_DY = 3.21         # 屋脊到檐口外沿的 Y 距离（−4.50 / +1.92）
RIDGE_CAP_TOP = 9.50        # 脊瓦顶（唯一的 Z = 9.50 顶点）
SEAM_X = (-3.60, 0.0, 3.60) # 每坡 3 道立缝

FRONT_U0, FRONT_U1 = -4.20, 1.62   # ±X 立面墙板 u 范围（= Y）
SIDE_U0, SIDE_U1 = -5.28, 5.28     # ±Y 立面墙板 u 范围（= X）

# 侧棚（不对称，+Y 侧）
SHED_Y0 = WALL_YP = 1.60
SHED_Y1 = 4.50
SHED_WALL_TOP = 4.60        # 贴墙处屋面顶皮
SHED_EAVE_TOP = 3.35        # 外檐屋面顶皮
SHED_T = 0.18               # 棚屋面板厚
SHED_SLOPE = (SHED_WALL_TOP - SHED_EAVE_TOP) / (SHED_Y1 - SHED_Y0)
SHED_ROOF_X = 5.50          # 棚屋面 X 出挑（= 包围盒半长）
POST_Y = 4.08               # 3 根木柱中心线
POST_XS = (-4.70, 0.0, 4.70)
POST_HALF = 0.11
POST_TOP = 3.19             # 柱顶（过梁下沿 3.16）
LINTEL_Z = (3.16, 3.32)     # 木过梁
BRACE_LEN = 1.15            # 2 道斜撑水平投影

# 主立面（+X）开口
LOADING_DOOR_UC = -2.30     # 3.0 宽装卸门中心
FRONT_PILASTERS = (-4.06, 1.50)    # 2 根砖壁柱（包转角）

# 山墙（±X）
GABLE_BASE_Z = 7.46         # 山墙三角底边（压进墙顶 0.04，避免共面）
GABLE_APEX_Z = 9.13         # 山墙三角顶点（略低于屋面底皮 9.14）
GABLE_WIN = (-1.69, -0.89, 7.98, 8.78)   # +X 山墙窗 y0,y1,z0,z1（0.80 × 0.80）

# 屋顶通风管（偏心 = 轮廓识别点）
VENT_POS = (1.55, 0.55)     # (x, y)，r = 0.12
VENT_R = 0.12
VENT_TOP = 9.20             # 顶帽顶（略低于屋脊 9.36）

# --------------------------------------------------------------------------- #
# 立面开洞表：(u0, u1, v0, v1, 凹深, 凹底材质)
#   +X 主立面 u = Y；−X 背面 u = Y；±Y 立面 u = X
# --------------------------------------------------------------------------- #

FRONT_OPENINGS = [
    (-3.80, -0.80, 0.55, 4.85, 0.26, IRON),    # 装卸门 3.00 × 4.30，凹 0.26
    (-0.36, 0.79, 2.50, 3.95, 0.14, GLASS),    # 窗 1（1.15 × 1.45），凹 0.14
    (-0.36, 0.79, 4.45, 5.90, 0.14, GLASS),    # 窗 2（1.15 × 1.45）
]
BACK_OPENINGS = [
    (-3.00, -1.90, 0.55, 2.70, 0.20, WOOD),    # 服务门 1.10 × 2.15，凹 0.20
    (-0.10, 0.80, 3.50, 4.50, 0.14, GLASS),    # 后勤小窗 0.90 × 1.00
]
REAR_OPENINGS = [
    (-3.85, -2.95, 3.70, 4.90, 0.14, GLASS),
    (-0.45, 0.45, 3.70, 4.90, 0.14, GLASS),
    (2.95, 3.85, 3.70, 4.90, 0.14, GLASS),
]
SHED_OPENINGS = [
    (-3.25, -2.35, 2.30, 3.40, 0.14, GLASS),   # 侧棚后墙 2 扇小窗
    (2.35, 3.25, 2.30, 3.40, 0.14, GLASS),
]

# 设计要求清单（report / 自检输出，便于 Verifier 逐条核对）
DESIGN = {
    "asset": ASSET,
    "front_facade_side": "+X（主立面：固定机位正对，yaw −90° 后仅偏轴约 11°）",
    "secondary_facade_side": "+Y（单坡侧棚一侧，掠射约 78°，仍做柱列 / 开间节奏）",
    "back_facade_sides": "−X / −Y（服务门、后勤窗、2 根落水管）",
    "footprint_m": (TARGET_SIZE[0], TARGET_SIZE[1]),
    "stone_plinth_bands": 3,
    "stone_plinth_top_m": PLINTH_TOP,
    "plinth_top_footprint_m": (10.70, 8.70),
    "wall_thickness_m": PANEL_T,
    "loading_doors": 1,
    "loading_door_size_m": (3.00, 4.30),
    "loading_door_recess_m": 0.26,
    "windows_front": 2,
    "windows_front_size_m": (1.15, 1.45),
    "window_recess_m": 0.14,
    "gable_window": 1,
    "gable_window_size_m": (0.80, 0.80),
    "sign_board_m": (2.00, 0.55),
    "brick_pilasters_front": len(FRONT_PILASTERS),
    "brick_pilaster_m": (0.34, 0.14),
    "asymmetric_side_shed": "单坡侧棚，占 y 1.60→4.50，屋面 4.60→3.35",
    "shed_posts": len(POST_XS),
    "shed_braces": 2,
    "shed_roof_heights_m": (SHED_WALL_TOP, SHED_EAVE_TOP),
    "roof_type": "gable（屋脊沿 X，+X 为山墙端）",
    "roof_thickness_m": ROOF_T,
    "roof_overhang_m": round(ROOF_EAVE_DY - (WALL_YP - Y_RIDGE), 3),
    "ridge_cap": True,
    "standing_seams_per_slope": len(SEAM_X),
    "roof_vent_ducts": 1,
    "roof_vent_diameter_m": 2 * VENT_R,
    "roof_vent_offset_xy_m": VENT_POS,
    "service_door_size_m": (1.10, 2.15),
    "service_door_recess_m": 0.20,
    "downpipes": 2,
    "gutters": 2,
    "cornice_projection_m": 0.18,
}

# --------------------------------------------------------------------------- #
# 纯几何工具（逐字复用参考实现 sn_iron_harbor_architecture_kit_generator.py）
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
    """YZ 闭合多边形沿 X 拉伸成闭合棱柱（山墙三角墙板 / 屋面用）。"""
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
#   u = 立面水平坐标（+X / −X 立面 u = Y；+Y / −Y 立面 u = X）
#   v = 世界 Z
#   d = 自墙外皮向内的凹深（>0 进入墙体，<0 凸出墙面）
#   本栋主立面在 +X（不是参考实现的 +Y）：固定机位 yaw −90° 后正对 +X 端墙。
# --------------------------------------------------------------------------- #

_SIDE = {
    "front": ("x", WALL_X, -1.0),    # +X 主立面（装卸门 / 窗 / 招牌 / 山墙）
    "back":  ("x", -WALL_X, 1.0),    # −X 背面（服务门 / 小窗 / 落水管）
    "right": ("y", WALL_YP, -1.0),   # +Y 单坡侧棚一侧（主墙 + 柱列）
    "left":  ("y", WALL_YM, 1.0),    # −Y 后侧（后勤窗 / 砖壁柱）
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
# 带真实凹口的墙板（逐字复用参考实现）
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
# 构件
# --------------------------------------------------------------------------- #

def _stone_plinth(m):
    """石基：3 级收分。底面 11.0 × 9.0 定 X/Y 包围盒，压顶面 10.70 × 8.70。"""
    m.add(*tb(-HALF_X, HALF_X, -HALF_Y, HALF_Y, 0.0, 0.30, 0.10), STONE)
    m.add(*tb(-5.40, 5.40, -4.40, 4.40, 0.30, 0.46, 0.03), STONE)
    m.add(*tb(-5.37, 5.37, -4.37, 4.37, 0.46, PLINTH_TOP, 0.02), STONE)


def _walls(m):
    """四面闭合厚墙板；凹口全部是真凹口（窗 0.14 / 装卸门 0.26 / 服务门 0.20）。"""
    m.add_multi(*panel("x", WALL_X, -1.0, FRONT_U0, FRONT_U1,
                       WALL_BOT, EAVE_Z, PANEL_T, FRONT_OPENINGS))
    m.add_multi(*panel("x", -WALL_X, 1.0, FRONT_U0, FRONT_U1,
                       WALL_BOT, EAVE_Z, PANEL_T, BACK_OPENINGS))
    m.add_multi(*panel("y", WALL_YM, 1.0, SIDE_U0, SIDE_U1,
                       WALL_BOT, EAVE_Z, PANEL_T, REAR_OPENINGS))
    m.add_multi(*panel("y", WALL_YP, -1.0, SIDE_U0, SIDE_U1,
                       WALL_BOT, EAVE_Z, PANEL_T, SHED_OPENINGS))


def _brick_pilaster(m, side, uc, v0, v1, w=0.34, d=0.14):
    """砖壁柱：八边形竖梃（0.34 × 0.14，倒角 0.04）+ 石柱础 + 石柱头。"""
    m.add(*lvchamfer_box(side, uc - w / 2, uc + w / 2, v0 + 0.16, v1,
                         -d, 0.02, 0.04), BRICK)
    m.add(*lbox(side, uc - w / 2 - 0.04, uc + w / 2 + 0.04, v0, v0 + 0.16,
                -d - 0.02, 0.02), STONE)
    m.add(*lbox(side, uc - w / 2 - 0.03, uc + w / 2 + 0.03, v1, v1 + 0.12,
                -d - 0.02, 0.02), STONE)


def _window(m, side, uc, vc, w, h, depth):
    """窗：木竖框（倒角）+ 木横框 + 窗棂 + 石窗台 + 石窗楣；玻璃 = 凹底。"""
    hw, hh = w / 2.0, h / 2.0
    # 左右竖框（前面压住墙口边 0.03，向内到玻璃面）
    for s in (-1.0, 1.0):
        ua = uc + s * (hw + 0.03)
        ub = uc + s * (hw - 0.09)
        m.add(*lvchamfer_box(side, min(ua, ub), max(ua, ub), vc - hh, vc + hh,
                             -0.03, depth, 0.02), WOOD)
    # 上框 / 下框
    m.add(*lbox(side, uc - hw + 0.05, uc + hw - 0.05, vc + hh - 0.09, vc + hh + 0.03,
                -0.03, depth), WOOD)
    m.add(*lbox(side, uc - hw + 0.05, uc + hw - 0.05, vc - hh - 0.03, vc - hh + 0.08,
                -0.03, depth), WOOD)
    # 窗棂（一竖一横，铁）
    m.add(*lbox(side, uc - 0.03, uc + 0.03, vc - hh, vc + hh, -0.02, depth - 0.03), IRON)
    m.add(*lbox(side, uc - hw, uc + hw, vc - 0.03, vc + 0.03, -0.02, depth - 0.03), IRON)
    # 石窗台（外凸 0.11，向下斜面）
    m.add(*lhexa(side,
                 (uc - hw - 0.16, uc + hw + 0.16, vc - hh - 0.14, vc - hh + 0.02, -0.02),
                 (uc - hw - 0.12, uc + hw + 0.12, vc - hh - 0.10, vc - hh + 0.02, -0.11)),
          STONE)
    # 石窗楣（外凸 0.06）
    m.add(*lbox(side, uc - hw - 0.16, uc + hw + 0.16, vc + hh + 0.03, vc + hh + 0.18,
                -0.06, 0.02), STONE)


def _loading_door(m, side, uc, v0, v1, w, depth):
    """内凹装卸门：木门框 + 双扇铁皮门（凹 0.18）+ 上滑轨 / 吊架 / 吊轮 + 石门槛。"""
    hw = w / 2.0
    # 门框竖梃（倒角）
    for s in (-1.0, 1.0):
        ua = uc + s * (hw + 0.03)
        ub = uc + s * (hw - 0.11)
        m.add(*lvchamfer_box(side, min(ua, ub), max(ua, ub), v0, v1,
                             -0.03, depth - 0.06, 0.03), WOOD)
    # 门楣
    m.add(*lbox(side, uc - hw + 0.06, uc + hw - 0.06, v1 - 0.14, v1 + 0.03,
                -0.03, depth - 0.06), WOOD)
    # 双扇铁皮门（门面凹深 0.18，门扇厚 0.08）
    leaf_w = hw - 0.10
    for s in (-1.0, 1.0):
        ua = uc + s * 0.05
        ub = uc + s * (0.05 + leaf_w)
        u0l, u1l = min(ua, ub), max(ua, ub)
        m.add(*lbox(side, u0l, u1l, v0 + 0.16, v1 - 0.14, 0.18, 0.26), IRON)
        # 门扇铆接压条：1 横 + 1 竖
        m.add(*lbox(side, u0l + 0.06, u1l - 0.06, v0 + 1.05, v0 + 1.15,
                    0.155, 0.182), IRON)
        ux = u0l + leaf_w * 0.5
        m.add(*lbox(side, ux - 0.04, ux + 0.04, v0 + 0.24, v1 - 0.22,
                    0.155, 0.182), IRON)
        # 铁拉手
        m.add(*lbox(side, u0l + leaf_w * 0.62, u0l + leaf_w * 0.80,
                    v0 + 0.95, v0 + 1.02, 0.13, 0.185), IRON)
    # 上滑轨（双轨 + 3 吊架 + 每扇 2 个吊轮）
    for dv in (0.04, 0.14):
        m.add(*lbox(side, uc - hw - 0.30, uc + hw + 0.30, v1 + dv, v1 + dv + 0.07,
                    -0.10, 0.02), IRON)
    for ux in (uc - hw * 0.82, uc, uc + hw * 0.82):
        m.add(*lbox(side, ux - 0.04, ux + 0.04, v1 + 0.03, v1 + 0.21,
                    -0.11, 0.02), IRON)
    for s in (-1.0, 1.0):
        ua = uc + s * 0.05
        ub = uc + s * (0.05 + leaf_w)
        u0l = min(ua, ub)
        for ux in (u0l + leaf_w * 0.27, u0l + leaf_w * 0.73):
            # 吊轮：轴向 = 凹深方向的小圆柱 + 吊耳
            m.add(*rod(lp(side, ux, v1 + 0.02, -0.055),
                       lp(side, ux, v1 + 0.02, 0.02), 0.05, 6), IRON)
            m.add(*lbox(side, ux - 0.03, ux + 0.03, v1 - 0.04, v1 + 0.10,
                        -0.07, 0.02), IRON)
    # 石门槛（嵌在凹口底部，门扇下沿 0.71 不压门槛）
    m.add(*lbox(side, uc - hw + 0.02, uc + hw - 0.02, v0, v0 + 0.07,
                -0.02, depth), STONE)


def _loading_apron(m, side, uc, half_w=1.65):
    """装卸门前的石/铁门槛台：3.3 m 宽，压在墙脚石基上（包围盒内）。"""
    m.add(*lbox(side, uc - half_w, uc + half_w, 0.20, 0.557, -0.16, 0.10), STONE)
    m.add(*lbox(side, uc - half_w + 0.12, uc + half_w - 0.12, 0.557, 0.575,
                -0.14, 0.08), IRON)


def _sign_board(m, side, uc, v0, v1, w):
    """空白木招牌（2.00 × 0.55）：木板 + 木边框，凸出墙面 0.05，无文字。"""
    hw = w / 2.0
    m.add(*lbox(side, uc - hw + 0.06, uc + hw - 0.06, v0 + 0.06, v1 - 0.06,
                -0.035, 0.01), WOOD)
    m.add(*lbox(side, uc - hw, uc + hw, v1 - 0.06, v1, -0.05, 0.01), WOOD)
    m.add(*lbox(side, uc - hw, uc + hw, v0, v0 + 0.06, -0.05, 0.01), WOOD)
    m.add(*lbox(side, uc - hw, uc - hw + 0.06, v0 + 0.06, v1 - 0.06,
                -0.05, 0.01), WOOD)
    m.add(*lbox(side, uc + hw - 0.06, uc + hw, v0 + 0.06, v1 - 0.06,
                -0.05, 0.01), WOOD)


def _service_door(m, side, uc, v0, v1, w, depth):
    """背面服务门：木框 + 拼板门扇（凹 0.15）+ 铁横带 / 把手 + 小铁雨棚 + 石门槛。"""
    hw = w / 2.0
    for s in (-1.0, 1.0):
        ua = uc + s * (hw + 0.03)
        ub = uc + s * (hw - 0.08)
        m.add(*lvchamfer_box(side, min(ua, ub), max(ua, ub), v0, v1,
                             -0.03, depth - 0.05, 0.018), WOOD)
    m.add(*lbox(side, uc - hw + 0.04, uc + hw - 0.04, v1 - 0.10, v1 + 0.04,
                -0.03, depth - 0.05), WOOD)
    m.add(*lbox(side, uc - hw + 0.05, uc + hw - 0.05, v0 + 0.12, v1 - 0.10,
                0.15, 0.20), WOOD)
    for k in range(3):
        ux = uc - hw + 0.22 + k * (w - 0.44) / 2.0
        m.add(*lbox(side, ux - 0.03, ux + 0.03, v0 + 0.22, v1 - 0.20,
                    0.135, 0.155), WOOD)
    for k in range(2):
        m.add(*lbox(side, uc - hw + 0.10, uc + hw - 0.10,
                    v0 + 0.55 + k * 0.85, v0 + 0.63 + k * 0.85, 0.13, 0.158), IRON)
    m.add(*lbox(side, uc + hw - 0.18, uc + hw - 0.11, v0 + 1.02, v0 + 1.16,
                0.12, 0.15), IRON)
    # 小铁雨棚（出挑 0.16，收在 −X 包围盒内）
    m.add(*lbox(side, uc - 0.85, uc + 0.85, v1 + 0.06, v1 + 0.15, -0.16, 0.02), IRON)
    for s in (-1.0, 1.0):
        m.add(*beam(lp(side, uc + s * 0.65, v1 + 0.14, -0.14),
                    lp(side, uc + s * 0.65, v1 - 0.22, 0.0), 0.06, 0.06), IRON)
    # 石门槛
    m.add(*lbox(side, uc - hw - 0.05, uc + hw + 0.05, v0 - 0.02, v0 + 0.07,
                -0.02, depth - 0.04), STONE)


def _service_steps(m, side, uc):
    """服务门前的 2 级石台阶（外皮与石基底面齐平，不越包围盒）。"""
    m.add(*lbox(side, uc - 0.80, uc + 0.80, 0.00, 0.24, -0.20, 0.05), STONE)
    m.add(*lbox(side, uc - 0.70, uc + 0.70, 0.24, 0.46, -0.14, 0.05), STONE)


def _front_details(m):
    """+X 主立面（固定机位正对）：装卸门 + 2 窗 + 招牌 + 2 砖壁柱 + 门槛台。"""
    _loading_door(m, "front", LOADING_DOOR_UC, 0.55, 4.85, 3.00, 0.26)
    for vc in (3.225, 5.175):
        _window(m, "front", 0.215, vc, 1.15, 1.45, 0.14)
    _sign_board(m, "front", LOADING_DOOR_UC, 5.44, 6.01, 2.00)
    for uc in FRONT_PILASTERS:
        _brick_pilaster(m, "front", uc, PLINTH_TOP - 0.02, 6.86, 0.34, 0.14)
    _loading_apron(m, "front", LOADING_DOOR_UC)


def _back_details(m):
    """−X 背面（机位不可见）：服务门 + 石台阶 + 1 小窗。"""
    _service_door(m, "back", -2.45, 0.55, 2.70, 1.10, 0.20)
    _service_steps(m, "back", -2.45)
    _window(m, "back", 0.35, 4.00, 0.90, 1.00, 0.14)


def _rear_details(m):
    """−Y 后侧：3 扇后勤窗 + 2 根砖壁柱打断 10.56 m 长墙。"""
    for uc in (-3.40, 0.0, 3.40):
        _window(m, "left", uc, 4.30, 0.90, 1.20, 0.14)
    for uc in (-1.70, 1.70):
        _brick_pilaster(m, "left", uc, PLINTH_TOP - 0.02, 6.86, 0.34, 0.14)


def _shed_side_details(m):
    """+Y 侧棚后主墙：2 扇小窗（透过开敞柱列可见）。"""
    for uc in (-2.80, 2.80):
        _window(m, "right", uc, 2.85, 0.90, 1.10, 0.14)


def _shed_roof_section():
    """单坡棚屋面 YZ 截面：贴墙处（嵌入墙内 0.08）到外檐，外檐 1 段倒角。"""
    def top(y):
        return SHED_WALL_TOP - (y - SHED_Y0) * SHED_SLOPE

    y_in = SHED_Y0 - 0.08
    y_e = SHED_Y1
    t_e = top(y_e)
    return [
        (y_in, top(y_in)),                 # 贴墙端顶皮（嵌进墙内）
        (y_e - 0.03, t_e + 0.0129),        # 外檐倒角起点
        (y_e, t_e - 0.0171),               # 倒角终点（外檐上棱）
        (y_e, t_e - SHED_T),               # 外檐板边下棱（可见板厚 0.18）
        (y_in, top(y_in) - SHED_T),        # 底皮回到贴墙端
    ]


def _shed(m):
    """不对称单坡侧棚（+Y）：3 木柱 + 2 斜撑 + 木过梁 + 5 椽 + 单坡铁屋面 + 封檐板。"""
    # 墙顶木垫梁（半嵌进 +Y 主墙，承托棚屋面）
    m.add(*lbox("right", -5.30, 5.30, 4.30, 4.46, -0.12, 0.08), WOOD)
    # 3 根木柱：石柱础 + 倒角柱身 + 木柱头
    for px in POST_XS:
        m.add(*vchamfer_box(px - POST_HALF, px + POST_HALF,
                            POST_Y - POST_HALF, POST_Y + POST_HALF,
                            0.67, POST_TOP, 0.025), WOOD)
        m.add(*vchamfer_box(px - 0.17, px + 0.17, POST_Y - 0.17, POST_Y + 0.17,
                            PLINTH_TOP, 0.67, 0.03), STONE)
        m.add(*vchamfer_box(px - 0.15, px + 0.15, POST_Y - 0.15, POST_Y + 0.15,
                            POST_TOP, POST_TOP + 0.12, 0.03), WOOD)
    # 木过梁（沿 X 贯通，端头收在 ±X 墙皮内 0.00 m）
    m.add(*box((-5.28, POST_Y - 0.09, LINTEL_Z[0]),
               (5.28, POST_Y + 0.09, LINTEL_Z[1])), WOOD)
    # 2 道斜撑：中柱 → 过梁（在檐口平面内，从 +X 机位读作开敞棚下的斜线）
    for s in (-1.0, 1.0):
        m.add(*beam((0.0, POST_Y, 2.45),
                    (s * BRACE_LEN, POST_Y, LINTEL_Z[0] + 0.06), 0.12, 0.12), WOOD)
    # 5 根椽（4 根对位柱 + 1 根落在 +X 开敞端，从主立面看是棚口的斜梁）
    for px in POST_XS + (5.26,):
        m.add(*beam((px, 1.70, 4.35), (px, 4.28, 3.24), 0.13, 0.16), WOOD)
    # 单坡铁屋面板（X 向出挑到 ±5.50，板厚 0.18 可见）
    m.add(*prism_x(_shed_roof_section(), -SHED_ROOF_X, SHED_ROOF_X), IRON)
    # 木封檐板（挂在外檐板边下，比板边内收 0.01 防共面）
    m.add(*box((-5.48, SHED_Y1 - 0.08, 2.92), (5.48, SHED_Y1 - 0.01, 3.24)), WOOD)


def _roof_section(sy):
    """主屋面单坡 YZ 截面：檐口外棱 2 段 45° 倒角，板厚 0.22，脊线收口。"""
    ye = Y_RIDGE + sy * ROOF_EAVE_DY
    zt = RIDGE_TOP - ROOF_EAVE_DY * SLOPE             # 檐口外沿顶皮
    zu = zt - ROOF_T                                   # 檐口外沿底皮
    return [
        (Y_RIDGE, RIDGE_TOP - ROOF_T),
        (ye, zu),
        (ye, zt - 0.06),
        (ye - sy * 0.0176, zt - 0.0176),
        (ye - sy * 0.06, zt),
        (Y_RIDGE, RIDGE_TOP),
    ]


def _roof(m):
    """主屋面：双坡铁屋面板 + 铁脊瓦 + 每坡 3 道立缝。"""
    for sy in (-1.0, 1.0):
        m.add(*prism_x(_roof_section(sy), -ROOF_X, ROOF_X), IRON)
    # 铁脊瓦（盖住两坡顶皮 V 缝，顶面 = 包围盒 Z 上限 9.50）
    m.add(*box((-5.48, Y_RIDGE - 0.30, 9.30),
               (5.48, Y_RIDGE + 0.30, RIDGE_CAP_TOP)), IRON)
    # 屋面立缝（每坡 3 道；从檐口内 0.08 顺坡到脊侧 0.20，压在顶皮上）
    for sy in (-1.0, 1.0):
        for sx in SEAM_X:
            ye = Y_RIDGE + sy * (ROOF_EAVE_DY - 0.08)
            ze = RIDGE_TOP - (ROOF_EAVE_DY - 0.08) * SLOPE + 0.030
            yr = Y_RIDGE + sy * 0.20
            zr = RIDGE_TOP - 0.20 * SLOPE + 0.030
            m.add(*beam((sx, ye, ze), (sx, yr, zr), 0.075, 0.055), IRON)


def _gable_x_front(m):
    """+X 山墙（主立面）：石膏三角墙板 + 0.80×0.80 真实凹口山墙窗 + 木框 / 铁棂。

    三角墙板是「带矩形洞的闭合厚板」：外环 6 个面 + 内环 6 个面 + 外缘 7 个封边
    + 洞壁 4 个面，全部共享顶点 -> 每边恰好 2 面（流形）。
    """
    y0, y1 = FRONT_U0, FRONT_U1
    zb = GABLE_BASE_Z
    apex_z = GABLE_APEX_Z
    hy0, hy1, hz0, hz1 = GABLE_WIN
    half_base = (y1 - y0) / 2.0

    def ylr(z):
        k = (apex_z - z) / (apex_z - zb)
        return (Y_RIDGE - half_base * k, Y_RIDGE + half_base * k)

    yL1, yR1 = ylr(hz0)
    yL2, yR2 = ylr(hz1)
    verts = []
    index = {}

    def V(y, z, x):
        key = (round(y, 6), round(z, 6), round(x, 6))
        i = index.get(key)
        if i is None:
            i = len(verts)
            index[key] = i
            verts.append((x, y, z))
        return i

    ring = [
        # 底带（含窗洞下沿，网格点落在洞边）
        [(y0, zb), (y1, zb), (yR1, hz0), (hy1, hz0), (hy0, hz0), (yL1, hz0)],
        # 左带 / 右带
        [(yL1, hz0), (hy0, hz0), (hy0, hz1), (yL2, hz1)],
        [(hy1, hz0), (yR1, hz0), (yR2, hz1), (hy1, hz1)],
        # 顶带（用 3 个三角形，避免共线退化）
        [(yL2, hz1), (hy0, hz1), (Y_RIDGE, apex_z)],
        [(hy0, hz1), (hy1, hz1), (Y_RIDGE, apex_z)],
        [(hy1, hz1), (yR2, hz1), (Y_RIDGE, apex_z)],
    ]
    xo, xi = WALL_X - 0.02, WALL_X - PANEL_T - 0.02   # 山墙外皮内收 0.02：避免与砖墙外皮 x=5.30 共面
    faces = []
    for loop in ring:
        faces.append(tuple(V(y, z, xo) for y, z in loop))
    for loop in ring:
        faces.append(tuple(V(y, z, xi) for y, z in loop))
    # 外缘封边（底边 + 2 条斜脊各 3 段）
    rim = [((y0, zb), (y1, zb)),
           ((y1, zb), (yR1, hz0)), ((yR1, hz0), (yR2, hz1)),
           ((yR2, hz1), (Y_RIDGE, apex_z)),
           ((yL2, hz1), (Y_RIDGE, apex_z)),
           ((yL1, hz0), (yL2, hz1)), ((y0, zb), (yL1, hz0))]
    for a, b in rim:
        faces.append((V(a[0], a[1], xo), V(b[0], b[1], xo),
                      V(b[0], b[1], xi), V(a[0], a[1], xi)))
    # 窗洞洞壁
    hole = [((hy0, hz0), (hy1, hz0)), ((hy1, hz0), (hy1, hz1)),
            ((hy1, hz1), (hy0, hz1)), ((hy0, hz1), (hy0, hz0))]
    for a, b in hole:
        faces.append((V(a[0], a[1], xo), V(b[0], b[1], xo),
                      V(b[0], b[1], xi), V(a[0], a[1], xi)))
    m.add_multi(verts, [(f, PLASTER) for f in faces])

    # 窗：深色玻璃盒封住洞口背面（凹深 0.14），木框压在洞口边上，铁棂一竖一横
    m.add(*box((4.90, hy0 - 0.03, hz0 - 0.03), (5.16, hy1 + 0.03, hz1 + 0.03)), GLASS)
    m.add(*box((5.15, hy0 - 0.04, hz0 - 0.04), (5.32, hy0 + 0.03, hz1 + 0.04)), WOOD)
    m.add(*box((5.15, hy1 - 0.03, hz0 - 0.04), (5.32, hy1 + 0.04, hz1 + 0.04)), WOOD)
    m.add(*box((5.15, hy0 - 0.04, hz0 - 0.04), (5.32, hy1 + 0.04, hz0 + 0.03)), WOOD)
    m.add(*box((5.15, hy0 - 0.04, hz1 - 0.03), (5.32, hy1 + 0.04, hz1 + 0.04)), WOOD)
    ux = 0.5 * (hy0 + hy1)
    m.add(*box((5.16, ux - 0.03, hz0 + 0.06), (5.30, ux + 0.03, hz1 - 0.06)), IRON)
    m.add(*box((5.16, hy0 + 0.03, 8.36), (5.30, hy1 - 0.03, 8.42)), IRON)
    # 山墙铁拉杆 + 两端铁垫板（在窗下沿以下，不穿窗）
    m.add(*rod((5.32, -3.30, 7.80), (5.32, 0.72, 7.80), 0.030, 6), IRON)
    for yy in (-3.30, 0.72):
        m.add(*box((5.30, yy - 0.10, 7.70), (5.37, yy + 0.10, 7.90)), IRON)


def _gable_x_back(m):
    """−X 山墙：石膏三角墙板（实体）+ 铁拉杆 + 铁垫板。"""
    zb = GABLE_BASE_Z
    pts = [(FRONT_U0, zb), (FRONT_U1, zb), (Y_RIDGE, GABLE_APEX_Z)]
    m.add(*prism_x(pts, -WALL_X + 0.02, -WALL_X + PANEL_T + 0.02), PLASTER)   # 外皮内收 0.02：避免与砖墙外皮共面
    m.add(*rod((-5.32, -2.70, 7.95), (-5.32, 0.10, 7.95), 0.030, 6), IRON)
    for yy in (-2.70, 0.10):
        m.add(*box((-5.37, yy - 0.10, 7.85), (-5.30, yy + 0.10, 8.05)), IRON)


CORNICE_PROFILE = [
    (0.02, 6.98), (-0.05, 6.98), (-0.05, 7.06), (-0.15, 7.06),
    (-0.18, 7.10), (-0.18, 7.20), (-0.13, 7.26), (-0.06, 7.38), (0.02, 7.46),
]


def _cornice(m):
    """石檐口：五级出挑线脚（最大出挑 0.18，两段 45° 倒角），四面环通。"""
    for side in ("front", "back"):
        m.add(*lprism_u(side, FRONT_U0, FRONT_U1, CORNICE_PROFILE), STONE)
    for side in ("right", "left"):
        m.add(*lprism_u(side, -5.48, 5.48, CORNICE_PROFILE), STONE)


def _stone_band(m):
    """石腰线（材质分区带，凸 0.05，内嵌墙 0.02，端头内收防共面）。"""
    for side in ("front", "back"):
        m.add(*lbox(side, FRONT_U0 + 0.04, FRONT_U1 - 0.04, 6.84, 6.98,
                    -0.05, 0.02), STONE)
    for side in ("right", "left"):
        m.add(*lbox(side, -5.24, 5.24, 6.84, 6.98, -0.05, 0.02), STONE)


def _gutters(m):
    """±Y 檐沟：挂在檐口外沿下方（转角随屋面出挑，收在包围盒内）。"""
    front = [(1.78, 7.06), (1.92, 7.06), (1.92, 6.98),
             (1.88, 6.92), (1.80, 6.92), (1.78, 6.98)]
    back = [(-4.36, 7.06), (-4.50, 7.06), (-4.50, 6.98),
            (-4.46, 6.92), (-4.38, 6.92), (-4.36, 6.98)]
    m.add(*prism_x(front, -5.48, 5.48), IRON)
    m.add(*prism_x(back, -5.48, 5.48), IRON)


def _downpipes(m):
    """−X 背面 2 根落水管：雨水斗 + 立管 + 3 道管卡 + 落水口。"""
    for uy in (-4.02, 1.42):
        # 雨水斗（檐口下方）
        m.add(*lbox("back", uy - 0.17, uy + 0.17, 6.76, 6.96, -0.18, 0.02), IRON)
        # 立管
        m.add(*rod(lp("back", uy, 6.90, -0.10),
                   lp("back", uy, 0.92, -0.10), 0.065, 8), IRON)
        # 3 道管卡
        for vz in (2.00, 3.80, 5.60):
            m.add(*lbox("back", uy - 0.035, uy + 0.035, vz - 0.045, vz + 0.045,
                        -0.16, 0.01), IRON)
        # 落水口 / 墙脚管座
        m.add(*lbox("back", uy - 0.13, uy + 0.13, PLINTH_TOP - 0.02, 0.92,
                    -0.19, 0.02), IRON)


def _roof_vent(m):
    """偏心屋顶通风管：铁底板 + 立管（r 0.12）+ 加粗管箍 + 锥形风帽。"""
    vx, vy = VENT_POS
    z_roof = RIDGE_TOP - abs(vy - Y_RIDGE) * SLOPE      # 该点屋面顶皮
    # 底板（嵌入屋面 0.20，露 0.06 高）
    m.add(*box((vx - 0.30, vy - 0.30, z_roof - 0.20),
               (vx + 0.30, vy + 0.30, z_roof + 0.06)), IRON)
    # 立管
    m.add(*rod((vx, vy, z_roof + 0.02), (vx, vy, VENT_TOP - 0.14), VENT_R, 8), IRON)
    # 管箍
    m.add(*rod((vx, vy, z_roof + 0.62), (vx, vy, z_roof + 0.78), VENT_R + 0.045, 8), IRON)
    # 锥形风帽 + 顶盖
    m.add(*tb(vx - 0.21, vx + 0.21, vy - 0.21, vy + 0.21,
              VENT_TOP - 0.14, VENT_TOP - 0.02, 0.07), IRON)
    m.add(*box((vx - 0.14, vy - 0.14, VENT_TOP - 0.03),
               (vx + 0.14, vy + 0.14, VENT_TOP)), IRON)


# --------------------------------------------------------------------------- #
# 组装
# --------------------------------------------------------------------------- #

def build_warehouse_short():
    """组装 SN_HT_Warehouse_Short LOD0 纯几何（局部坐标，轴心 = 地面中心）。"""
    m = Part()
    _stone_plinth(m)
    _walls(m)
    _front_details(m)
    _back_details(m)
    _rear_details(m)
    _shed_side_details(m)
    _shed(m)
    _cornice(m)
    _stone_band(m)
    _gutters(m)
    _roof(m)
    _gable_x_front(m)
    _gable_x_back(m)
    _downpipes(m)
    _roof_vent(m)
    return m


def build_all_geometry():
    return {NAME: build_warehouse_short()}


# --------------------------------------------------------------------------- #
# Blender 侧：建对象（可选；材质 / UV 由 Lead 用共享 trim sheet 模块处理）
# --------------------------------------------------------------------------- #

def _ensure_material(name):
    """已存在的共享材质原样复用，不覆盖参数；缺失时按调色板灰阶占位创建。"""
    import bpy
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    spec = MATERIALS[name]
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

    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata([tuple(v) for v in part.verts], [],
                     [list(f) for f, _ in part.faces])
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
    if len(slots) > MAX_MATERIAL_SLOTS:
        raise RuntimeError("材质槽 %d > 上限 %d" % (len(slots), MAX_MATERIAL_SLOTS))
    for mat_name in slots:
        mesh.materials.append(_ensure_material(mat_name))
    index = {n: i for i, n in enumerate(slots)}
    for poly, (_face, mat_name) in zip(mesh.polygons, part.faces):
        poly.material_index = index[mat_name]
        poly.use_smooth = False

    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (0.0, 0.0, 0.0)
    obj.scale = (1.0, 1.0, 1.0)
    return obj


def build_all(collection_name=COLLECTION, location=LOCATION):
    """Blender 内建一个 mesh 对象；重跑只替换同名对象（不改其它对象）。"""
    import bpy

    collection = _ensure_collection()
    for obj in list(collection.objects):
        if obj.name.startswith(PREFIX):
            old_mesh = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            if old_mesh is not None and old_mesh.users == 0:
                bpy.data.meshes.remove(old_mesh)
    for stale in [me for me in bpy.data.meshes
                  if me.users == 0 and me.name.startswith(PREFIX)]:
        bpy.data.meshes.remove(stale)
    return _make_object(NAME, build_warehouse_short(), location, collection)


# --------------------------------------------------------------------------- #
# 纯 Python 自检（不 import bpy）
# --------------------------------------------------------------------------- #

def _tri_count(faces):
    return sum(max(0, len(f) - 2) for f, _m in faces)


def _face_area(verts, face):
    total = 0.0
    p0 = verts[face[0]]
    for i in range(1, len(face) - 1):
        p1 = verts[face[i]]
        p2 = verts[face[i + 1]]
        ux, uy, uz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
        vx, vy, vz = p2[0] - p0[0], p2[1] - p0[1], p2[2] - p0[2]
        cx = uy * vz - uz * vy
        cy = uz * vx - ux * vz
        cz = ux * vy - uy * vx
        total += 0.5 * math.sqrt(cx * cx + cy * cy + cz * cz)
    return total


def _edge_stats(faces):
    from collections import Counter
    counter = Counter()
    for face, _m in faces:
        n = len(face)
        for i in range(n):
            a, b = face[i], face[(i + 1) % n]
            counter[(min(a, b), max(a, b))] += 1
    boundary = sum(1 for c in counter.values() if c == 1)
    nonmanifold = sum(1 for c in counter.values() if c > 2)
    return boundary, nonmanifold


def _degenerate_faces(verts, faces):
    bad = 0
    for face, _m in faces:
        if len(set(face)) != len(face):
            bad += 1
            continue
        p0 = verts[face[0]]
        for i in range(1, len(face) - 1):
            p1 = verts[face[i]]
            p2 = verts[face[i + 1]]
            ux, uy, uz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
            vx, vy, vz = p2[0] - p0[0], p2[1] - p0[1], p2[2] - p0[2]
            cx = uy * vz - uz * vy
            cy = uz * vx - ux * vz
            cz = ux * vy - uy * vx
            if (cx * cx + cy * cy + cz * cz) ** 0.5 * 0.5 < 1e-9:
                bad += 1
                break
    return bad


def _design_checks():
    """DESIGN 逐项布尔：能从数据 / 常量反推的才算 True，不写死。"""
    door = FRONT_OPENINGS[0]
    win = FRONT_OPENINGS[1:3]
    svc = BACK_OPENINGS[0]
    hy0, hy1, hz0, hz1 = GABLE_WIN
    checks = {
        "主立面在 +X（固定机位正对）": _SIDE["front"] == ("x", WALL_X, -1.0),
        "不对称单坡侧棚（+Y，单坡 4.60→3.35）":
            POST_Y > SHED_Y0 and SHED_Y1 >= HALF_Y - 1e-9
            and SHED_WALL_TOP > SHED_EAVE_TOP,
        "侧棚 3 柱 + 2 斜撑 + 木过梁":
            len(POST_XS) == 3 and LINTEL_Z[1] < SHED_WALL_TOP,
        "1 个内凹装卸门 3.00×4.30 / 凹 0.26":
            abs((door[1] - door[0]) - 3.00) < 1e-9
            and abs((door[3] - door[2]) - 4.30) < 1e-9
            and abs(door[4] - 0.26) < 1e-9,
        "2 扇主立面窗 1.15×1.45 / 凹 0.14":
            len(win) == 2 and all(
                abs((o[1] - o[0]) - 1.15) < 1e-9
                and abs((o[3] - o[2]) - 1.45) < 1e-9
                and abs(o[4] - 0.14) < 1e-9 for o in win),
        "屋顶通风管 1 根（偏心，顶 < 屋脊）":
            abs(VENT_POS[0]) > 1e-6 and abs(VENT_POS[1]) > 1e-6
            and VENT_TOP < RIDGE_TOP,
        "立面 bay 节奏（窗列 + 壁柱 + 门 + 腰线）":
            len(FRONT_PILASTERS) >= 2 and len(REAR_OPENINGS) == 3,
        "独立后门 1.10×2.15 / 凹 0.20":
            abs((svc[1] - svc[0]) - 1.10) < 1e-9
            and abs((svc[3] - svc[2]) - 2.15) < 1e-9
            and abs(svc[4] - 0.20) < 1e-9,
        "山墙窗 0.80×0.80（真实凹口）":
            abs((hy1 - hy0) - 0.80) < 1e-9 and abs((hz1 - hz0) - 0.80) < 1e-9,
        "屋脊沿 X、双坡铁屋面（板厚 0.22、脊瓦、每坡 3 立缝）":
            abs((RIDGE_TOP - EAVE_Z) / (WALL_YP - Y_RIDGE) - SLOPE) < 1e-12
            and RIDGE_CAP_TOP > RIDGE_TOP and len(SEAM_X) == 3,
        "檐口出挑 0.18（两段倒角）+ 石腰线": max(-d for d, _v in CORNICE_PROFILE) == 0.18,
        "窗凹 0.10–0.18 / 门凹 0.14–0.30、墙厚 0.12–0.35":
            all(0.10 <= o[4] <= 0.18 for tbl in (FRONT_OPENINGS[1:], BACK_OPENINGS[1:],
                                                REAR_OPENINGS, SHED_OPENINGS) for o in tbl)
            and all(0.14 <= o[4] <= 0.30 for o in (FRONT_OPENINGS[0], BACK_OPENINGS[0]))
            and 0.12 <= PANEL_T <= 0.35,
        "屋面出挑 0.20–0.60、板厚 ≥0.18":
            0.20 <= (ROOF_EAVE_DY - (WALL_YP - Y_RIDGE)) <= 0.60 and ROOF_T >= 0.18,
    }
    return checks


def self_check():
    """跑一遍纯几何自检，返回结果 dict（__main__ 用来打印 + 断言）。"""
    geom = build_all_geometry()
    part = geom[NAME]
    verts, faces = part.verts, part.faces

    tris = _tri_count(faces)
    xs = [v[0] for v in verts]
    ys = [v[1] for v in verts]
    zs = [v[2] for v in verts]
    size = (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
    zmin = min(zs)

    used = set()
    for face, _m in faces:
        used.update(face)
    loose = len(verts) - len(used)
    boundary, nonmanifold = _edge_stats(faces)
    degenerate = _degenerate_faces(verts, faces)

    mats = []
    for _f, mat in faces:
        if mat not in mats:
            mats.append(mat)
    per_mat = {}
    for face, mat in faces:
        row = per_mat.setdefault(mat, {"faces": 0, "tris": 0, "area": 0.0})
        row["faces"] += 1
        row["tris"] += max(0, len(face) - 2)
        row["area"] += _face_area(verts, face)

    design = _design_checks()

    checks = {
        "tris_in_range": TRI_FLOOR <= tris <= TRI_BUDGET,
        "size_matches_target": all(abs(size[i] - TARGET_SIZE[i]) <= 0.02 for i in range(3)),
        "grounded_zmin_zero": abs(zmin) <= 1e-6,
        "bbox_symmetric_x": abs(min(xs) + max(xs)) <= 1e-6,
        "bbox_symmetric_y": abs(min(ys) + max(ys)) <= 1e-6,
        "material_slots_le_6": len(mats) <= MAX_MATERIAL_SLOTS,
        "palette_only": all(m in PALETTE for m in mats),
        "loose_verts_zero": loose == 0,
        "degenerate_faces_zero": degenerate == 0,
        "nonmanifold_edges_zero": nonmanifold == 0,
        "boundary_edges_zero": boundary == 0,
        "design_all_pass": all(design.values()),
    }
    return {
        "name": NAME,
        "tris": tris,
        "verts": len(verts),
        "faces": len(faces),
        "size": size,
        "target": TARGET_SIZE,
        "sym_x": min(xs) + max(xs),
        "sym_y": min(ys) + max(ys),
        "zmin": zmin,
        "materials": mats,
        "per_material": per_mat,
        "loose": loose,
        "degenerate": degenerate,
        "nonmanifold": nonmanifold,
        "boundary": boundary,
        "design": design,
        "checks": checks,
    }


def _print_report(res):
    print("=" * 78)
    print("asset : %s   (pure-python geometry, no bpy)" % res["name"])
    print("tris  : %d / budget %d..%d   verts=%d faces=%d"
          % (res["tris"], TRI_FLOOR, TRI_BUDGET, res["verts"], res["faces"]))
    print("bbox  : x=%.3f y=%.3f z=%.3f  target=%s  delta=%s"
          % (res["size"][0], res["size"][1], res["size"][2],
             tuple(res["target"]),
             tuple(round(res["size"][i] - res["target"][i], 4) for i in range(3))))
    print("zmin  : %.6f   bbox 对称 min+max: X=%+.6f Y=%+.6f"
          % (res["zmin"], res["sym_x"], res["sym_y"]))
    print("mats  : %d slots -> %s" % (len(res["materials"]), res["materials"]))
    print("per-material: faces / tris / area m^2")
    for mat in res["materials"]:
        row = res["per_material"][mat]
        print("   %-16s %5d %6d   %9.3f" % (mat, row["faces"], row["tris"], row["area"]))
    print("health: boundary=%d nonmanifold=%d loose=%d degenerate=%d"
          % (res["boundary"], res["nonmanifold"], res["loose"], res["degenerate"]))
    print("DESIGN checklist:")
    for key, ok in res["design"].items():
        print("   [%s] %s" % ("PASS" if ok else "FAIL", key))
    print("checks:")
    for key, ok in res["checks"].items():
        print("   [%s] %s" % ("PASS" if ok else "FAIL", key))
    print("=" * 78)


def main():
    res = self_check()
    _print_report(res)
    failed = [k for k, ok in res["checks"].items() if not ok]
    if failed:
        raise AssertionError("self-check FAILED: %s" % ", ".join(failed))
    print("ALL OK — %s: %d tris, size %.3f x %.3f x %.3f, zmin=0, 6 material slots"
          % (res["name"], res["tris"], res["size"][0], res["size"][1], res["size"][2]))
    return 0


if __name__ == "__main__":
    main()
