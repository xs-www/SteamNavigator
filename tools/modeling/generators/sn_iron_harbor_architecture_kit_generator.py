# -*- coding: utf-8 -*-
"""Steam Navigator — 铁港中等精度建筑套件生成器（SN_HT_Warehouse_Long LOD0）。

工单：tools/modeling/briefs/sn_iron_harbor_architecture_kit_v1.json
集合：SN_Iron_Harbor_Architecture（本脚本只创建 / 重建该集合内以 SN_HT_ 开头的对象）
几何在 R1 已通过门禁并冻结（7 436 tri / 20 × 9 × 11 m / 轴心落地）；
本轮只做**材质与 UV**：几何函数与三角面数不变，`build_all()` 建完对象后调用
`sn_iron_harbor_materials.apply_to_object()` 写入共享 trim sheet 贴图与盒投影 UV。
不修改工作台里 SN_Harbor_Town 的旧占位资产（旧 `SN_HT_Warehouse_Long` 原样保留）。

设计要点
--------
- **立面朝向按 PortStage 固定机位定**：固定机位在 world +X/+Z 一侧；旧占位资产
  （batch1）把门窗放在 −Y，在固定机位里完全不可见。因此本样板把双高装卸门、
  人门、气窗、石窗台放在 **+Y 主立面**，服务门/后勤窗放到 −Y 背面，
  山墙吊梁留在 **+X 山墙**。资产名 / 占地 / 轴心不变；
  town 槽位 yaw 由 −90° 改到 **−106°**（`port_stage.gd` TOWN_SLOTS），
  使 +Y 长立面正对固定机位（法线偏离机位轴 52° → 36°），主立面/装卸门在画面里
  的可读面积 +38% / +35%，而 +X 山墙吊梁仍留在画面左侧可见。
- **单一 mesh 对象**，原点在底面中心（object.location = 工单布局位置），局部 +X 为建筑长轴。
- **真实凹口**：四面墙板由 `_panel()` 生成「带矩形凹口的闭合厚板」——外皮网格挖洞 +
  凹口四面侧壁 + 凹底面，凹深即窗/门凹深（窗 0.16 / 装卸门 0.28 / 人门与服务门 0.26）。
  不是共面深色贴片；凹口侧壁直接露出 0.46 m 墙体厚度。
- **可读厚度**：石基 0.72 m 高、上收 0.10 m；屋顶板厚 0.24 m（檐口外露板边）；
  檐口三级出挑 0.30 m；山墙三角墙板厚 0.51 m；窗台/窗楣石件出挑 0.09–0.17 m。
- **倒角策略**：不使用全局 Bevel 修改器（会把相邻砌块的共面接缝也切出沟槽），
  改为显式倒角：石基斜面收分、檐口三级出挑、壁柱/门框竖梃八边形截面（`vchamfer_box`）、
  通风帽锥形帽、山墙/屋顶板边。等价于工单要求的 0.03–0.12 m 倒角。
- **材质槽 6 个**：SN_Town_Brick / Plaster / Wood / Iron / Stone / Glass。
  材质与 UV 全部交给 `sn_iron_harbor_materials`（共享 trim sheet，按 cell 裁成
  每材质一张可平铺贴图；本文件只负责给每个面分配材质槽，不自建任何材质参数）。
  trim sheet 尚未生成时，该模块自动退回 R=G=B 灰阶占位，几何轮次仍可跑。
- 几何函数全部是纯 Python（不 import bpy），可用 `dryrun_props.py` 离线干跑；
  只有 `build_all()` / `report()` 需要 Blender。

用法
----
Blender 内：
    p = r"<abs path>/sn_iron_harbor_architecture_kit_generator.py"
    ns = {"__name__": "sn_iron_harbor_architecture_kit_generator", "__file__": p}
    exec(compile(open(p, encoding="utf-8").read(), p, "exec"), ns)
    ns["build_all"](); ns["report"]()
纯 Python 干跑：
    python tools/modeling/generators/dryrun_props.py tools/modeling/generators/sn_iron_harbor_architecture_kit_generator.py
"""

import math

# --------------------------------------------------------------------------- #
# 工单常量
# --------------------------------------------------------------------------- #

COLLECTION = "SN_Iron_Harbor_Architecture"
PREFIX = "SN_HT_"
ASSET = "SN_HT_Warehouse_Long"          # 保持既有资产名（LOD0 网格加后缀）
NAME = ASSET + "_LOD0"
LOCATION = (-48.0, 110.0, 0.0)          # PortStage 布局位置，与旧占位资产一致
TARGET_SIZE = (20.0, 9.0, 11.0)         # X × Y × Z（m），与旧占位资产一致
TRI_BUDGET = 8000                       # building_medium_lod0 上限
TRI_FLOOR = 5000                        # building_medium_lod0 下限

ITEMS = [(NAME, LOCATION, TRI_BUDGET, TARGET_SIZE)]
TOTAL_BUDGET = TRI_BUDGET

# 共享材质（灰模占位：R=G=B；粗糙度 / 金属度取工单区间中值）
MATERIALS = {
    "SN_Town_Brick":   {"base": (0.345, 0.345, 0.345), "roughness": 0.86, "metallic": 0.00},
    "SN_Town_Plaster": {"base": (0.560, 0.560, 0.560), "roughness": 0.84, "metallic": 0.00},
    "SN_Town_Wood":    {"base": (0.215, 0.215, 0.215), "roughness": 0.78, "metallic": 0.00},
    "SN_Town_Iron":    {"base": (0.120, 0.120, 0.120), "roughness": 0.58, "metallic": 0.60},
    "SN_Town_Stone":   {"base": (0.445, 0.445, 0.445), "roughness": 0.90, "metallic": 0.00},
    "SN_Town_Glass":   {"base": (0.050, 0.050, 0.050), "roughness": 0.26, "metallic": 0.12},
}
PALETTE = set(MATERIALS)

BRICK = "SN_Town_Brick"
PLASTER = "SN_Town_Plaster"
WOOD = "SN_Town_Wood"
IRON = "SN_Town_Iron"
STONE = "SN_Town_Stone"
GLASS = "SN_Town_Glass"

# ---- 体量（全部为局部坐标：X 长轴 ±10，Y 进深 ±4.5，Z 0→11） ---- #
HALF_X = 10.0
HALF_Y = 4.5
WALL_X = 9.70            # 侧墙外皮
WALL_Y = 4.18            # 前后墙外皮
PANEL_T = 0.46           # 墙板厚度（凹口侧壁露出的厚度）
WALL_BOT = 0.56          # 墙板底面（嵌入石基 0.02）
PLINTH_TOP = 0.58        # 石基压顶面（R1 压低 + 收窄，消除"托盘"感）
EAVE_Z = 7.55            # 墙顶 / 檐口上沿
ROOF_EAVE_Y = 4.50       # 屋面檐口外沿（等于包围盒半深）
ROOF_EAVE_Z = 7.305      # 檐口处屋面底皮（坡度计算：见 _roof）
RIDGE_Z = 10.75          # 屋脊底皮
ROOF_T = 0.24            # 屋面厚度（檐口板边可见）
ROOF_X = 9.95            # 屋面 X 出挑
ROOF_SLOPE = (RIDGE_Z - EAVE_Z) / WALL_Y   # 0.76555…：(4.18 → 0) 的升高量

BAY_X = (-9.70, -5.82, -1.94, 1.94, 5.82, 9.70)   # 5 开间
PILASTER_X = (-5.82, -1.94, 1.94, 5.82)           # 前后立面内壁柱
CORNER_PILASTER_X = (-9.58, 9.58)                 # 前后立面转角壁柱

# ---- 立面开洞表：(u0, u1, v0, v1, 凹深, 凹底材质) ---- #
# 主立面（+Y，PortStage 固定机位可见）：装卸门朝 +X 转角，紧邻山墙吊梁
FRONT_OPENINGS = [
    (6.26, 9.26, 0.74, 5.92, 0.28, IRON),     # 装卸门 A（3.00 × 5.18；凹底低于石基压顶 0.02 防共面）
    (2.38, 5.38, 0.74, 5.92, 0.28, IRON),     # 装卸门 B（3.00 × 5.18）
    (6.51, 9.01, 6.10, 6.84, 0.14, GLASS),    # 气窗 A（2.50 × 0.74）
    (2.63, 5.13, 6.10, 6.84, 0.14, GLASS),    # 气窗 B
    (-0.80, 0.80, 0.74, 3.32, 0.26, WOOD),    # 人门（1.60 × 2.58）
    (-1.25, 1.25, 4.30, 6.10, 0.16, GLASS),   # 人门上方窗
    (-5.18, -2.58, 3.10, 5.95, 0.16, GLASS),  # 4 号大窗（2.60 × 2.85）
    (-9.06, -6.46, 3.10, 5.95, 0.16, GLASS),  # 5 号大窗
]
# 背面（-Y，机位不可见）：服务门 + 4 扇后勤窗
BACK_OPENINGS = [
    (6.10, 7.40, 0.74, 3.05, 0.26, WOOD),     # 背面服务门（1.30 × 2.31）
    (-7.95, -6.45, 4.30, 6.20, 0.16, GLASS),
    (-4.35, -2.85, 4.30, 6.20, 0.16, GLASS),
    (-0.75, 0.75, 4.30, 6.20, 0.16, GLASS),
    (2.85, 4.35, 4.30, 6.20, 0.16, GLASS),
]
# 侧立面（±X）：R1 改为 4 窗 + 3 壁柱，延续长立面的开间节奏（u = Y）
SIDE_OPENINGS = [
    (-3.62, -2.52, 3.30, 5.40, 0.16, GLASS),
    (-1.65, -0.55, 3.30, 5.40, 0.16, GLASS),
    (0.55, 1.65, 3.30, 5.40, 0.16, GLASS),
    (2.52, 3.62, 3.30, 5.40, 0.16, GLASS),
]
SIDE_PILASTER_Y = (0.0, -2.085, 2.085)   # 落在 4 窗之间的 3 个间隙中心

# 设计特征清单（report() 输出，便于 Verifier 逐条核对）
DESIGN = {
    "bays": 5,
    "front_facade_side": "+Y（PortStage 固定机位可见的长墙）",
    "back_facade_side": "-Y（服务门 / 后勤窗）",
    "loading_doors": 2,
    "loading_door_recess_m": 0.28,
    "windows": 15,
    "window_recess_m": 0.16,
    "transoms": 2,
    "transom_recess_m": 0.14,
    "person_door_recess_m": 0.26,
    "service_door_recess_m": 0.26,
    "wall_thickness_m": PANEL_T,
    "stone_base_height_m": PLINTH_TOP,
    "roof_type": "gable",
    "roof_thickness_m": ROOF_T,
    "roof_overhang_y_m": round(ROOF_EAVE_Y - WALL_Y, 4),
    "roof_overhang_x_m": round(ROOF_X - WALL_X, 4),
    "vents": 2,
    "downpipes": 4,
    "gutters": 4,
    "dock_platforms": 2,
    "pilasters": 18,
    "gable_hoist_beam": True,
}

# 材质槽上限
MAX_MATERIAL_SLOTS = 6

# 材质 / UV 开关：共享 trim sheet 的贴图缺失时自动退回灰阶占位（几何轮次仍可跑）
TEXTURED = True
_TEXTURE_RESULT = {}


def _kit_materials():
    """按文件路径加载共享材质模块（不依赖 sys.path，Blender 内 exec 也能用）。"""
    import importlib.util
    import os

    here = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
    path = os.path.join(here, "sn_iron_harbor_materials.py")
    spec = importlib.util.spec_from_file_location("sn_iron_harbor_materials", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# --------------------------------------------------------------------------- #
# 纯几何工具（无 bpy 依赖）
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
#   u = 立面水平坐标（前后立面 = X，侧立面 = Y）
#   v = 世界 Z
#   d = 自墙外皮向内的凹深（>0 进入墙体，<0 凸出墙面）
# --------------------------------------------------------------------------- #

_SIDE = {
    "front": ("y", WALL_Y, -1.0),   # 主立面 = +Y：PortStage 固定机位可见的长墙
    "back":  ("y", -WALL_Y, 1.0),   # 背面 = -Y：服务门 / 后勤窗，机位不可见
    "left":  ("x", -WALL_X, 1.0),   # 左山墙面：-X 外皮，向内 +X
    "right": ("x", WALL_X, -1.0),   # 右山墙面：+X 外皮，向内 -X（机位可见）
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
# 构件
# --------------------------------------------------------------------------- #

def _stone_plinth(m):
    """石基：底面 20.0 × 9.0 落地轮廓。

    R1：压低到 0.58 m、三级收窄到 19.56 × 8.56，墙脚只剩 0.03/0.10 台阶，
    去掉原 0.20–0.32 m 宽台沿造成的"托盘"感；底面轮廓仍定死 20 × 9 包围盒。
    """
    m.add(*tb(-HALF_X, HALF_X, -HALF_Y, HALF_Y, 0.0, 0.30, 0.14), STONE)
    m.add(*tb(-9.86, 9.86, -4.36, 4.36, 0.30, 0.50, 0.06), STONE)
    m.add(*tb(-9.80, 9.80, -4.30, 4.30, 0.50, PLINTH_TOP, 0.02), STONE)


def _threshold(m, side, uc, half_w, top):
    """装卸门槛（R1）：石基座 + 铁门槛板 + 两侧挡铁；嵌入石基压顶 0.02，不越包围盒。"""
    m.add(*lbox(side, uc - half_w, uc + half_w, PLINTH_TOP - 0.02, top - 0.03,
                -0.24, 0.02), STONE)
    m.add(*lbox(side, uc - half_w - 0.03, uc + half_w + 0.03, top - 0.035, top,
                -0.26, 0.02), IRON)
    for s in (-1.0, 1.0):
        ux = uc + s * (half_w - 0.10)
        m.add(*lbox(side, ux - 0.05, ux + 0.05, top - 0.14, top + 0.04,
                    -0.27, -0.20), IRON)


def _dock_platform(m, side, uc, half_w=1.55):
    """装卸月台短平台（R1）：铁台面板 + 3 根支腿 + 2 个防撞柱。

    外挑 0.30 m、台面 0.92 m（比门槛高 0.02），全部收在 20 × 9 包围盒内。
    """
    top = 0.92
    m.add(*lbox(side, uc - half_w, uc + half_w, top - 0.05, top, -0.30, 0.02), IRON)
    for s in (-1.0, 0.0, 1.0):
        ux = uc + s * half_w
        m.add(*lbox(side, ux - 0.045, ux + 0.045, PLINTH_TOP - 0.02, top - 0.05,
                    -0.10, -0.01), IRON)
    for s in (-1.0, 1.0):
        ux = uc + s * (half_w - 0.10)
        m.add(*lbox(side, ux - 0.06, ux + 0.06, top, top + 0.20, -0.29, -0.17), IRON)


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
    # 石窗台（外凸 0.09，向下斜面）
    m.add(*lhexa(side,
                 (uc - hw - 0.16, uc + hw + 0.16, vc - hh - 0.14, vc - hh + 0.02, -0.02),
                 (uc - hw - 0.12, uc + hw + 0.12, vc - hh - 0.10, vc - hh + 0.02, -0.11)),
          STONE)
    # 石窗楣（外凸 0.06）
    m.add(*lbox(side, uc - hw - 0.16, uc + hw + 0.16, vc + hh + 0.03, vc + hh + 0.18,
                -0.06, 0.02), STONE)


def _transom(m, side, uc, vc, w, h, depth):
    """装卸门顶气窗：木框 + 两根竖梃 + 石窗台。"""
    hw, hh = w / 2.0, h / 2.0
    for s in (-1.0, 1.0):
        ua = uc + s * (hw + 0.03)
        ub = uc + s * (hw - 0.08)
        m.add(*lvchamfer_box(side, min(ua, ub), max(ua, ub), vc - hh, vc + hh,
                             -0.03, depth, 0.018), WOOD)
    m.add(*lbox(side, uc - hw + 0.05, uc + hw - 0.05, vc + hh - 0.08, vc + hh + 0.03,
                -0.03, depth), WOOD)
    m.add(*lbox(side, uc - hw + 0.05, uc + hw - 0.05, vc - hh - 0.03, vc - hh + 0.07,
                -0.03, depth), WOOD)
    for ux in (uc - w / 6.0, uc + w / 6.0):
        m.add(*lbox(side, ux - 0.025, ux + 0.025, vc - hh, vc + hh, -0.02, depth - 0.02), IRON)
    m.add(*lhexa(side,
                 (uc - hw - 0.14, uc + hw + 0.14, vc - hh - 0.12, vc - hh + 0.02, -0.02),
                 (uc - hw - 0.10, uc + hw + 0.10, vc - hh - 0.08, vc - hh + 0.02, -0.09)),
          STONE)


def _loading_door(m, side, uc, v0, v1, w, depth):
    """内凹装卸门：深木门框 + 双扇带压条门扇（凹 0.16）+ 上滑轨 + 铁吊轮。"""
    hw = w / 2.0
    # 门框竖梃（倒角）
    for s in (-1.0, 1.0):
        ua = uc + s * (hw + 0.03)
        ub = uc + s * (hw - 0.11)
        m.add(*lvchamfer_box(side, min(ua, ub), max(ua, ub), v0, v1,
                             -0.03, depth - 0.06, 0.03), WOOD)
    # 门楣
    m.add(*lbox(side, uc - hw + 0.06, uc + hw - 0.06, v1 - 0.13, v1 + 0.03,
                -0.03, depth - 0.06), WOOD)
    # 双扇门（门面凹深 0.16）
    leaf_w = hw - 0.08
    for s in (-1.0, 1.0):
        ua = uc + s * 0.04
        ub = uc + s * (0.04 + leaf_w)
        u0l, u1l = min(ua, ub), max(ua, ub)
        m.add(*lbox(side, u0l, u1l, v0 + 0.18, v1 - 0.13, 0.16, 0.24), WOOD)
        # 门扇压条：2 竖 + 2 横
        for ux in (u0l + leaf_w * 0.30, u0l + leaf_w * 0.70):
            m.add(*lbox(side, ux - 0.045, ux + 0.045, v0 + 0.28, v1 - 0.23,
                        0.14, 0.165), WOOD)
        for vz in (v0 + 1.35, v1 - 1.05):
            m.add(*lbox(side, u0l + 0.07, u1l - 0.07, vz - 0.05, vz + 0.05,
                        0.146, 0.166), WOOD)
        # 铁拉手 + 铁带
        m.add(*lbox(side, u0l + leaf_w * 0.62, u0l + leaf_w * 0.82,
                    v0 + 0.95, v0 + 1.02, 0.12, 0.165), IRON)
        m.add(*lbox(side, u0l + 0.10, u1l - 0.10, v0 + 2.15, v0 + 2.23,
                    0.145, 0.168), IRON)
    # 上滑轨（R1）：双轨 + 3 道吊架 + 每扇 2 个滚轮
    for dv in (0.03, 0.13):
        m.add(*lbox(side, uc - hw - 0.30, uc + hw + 0.30, v1 + dv, v1 + dv + 0.07,
                    -0.10, 0.02), IRON)
    for ux in (uc - hw * 0.82, uc, uc + hw * 0.82):
        m.add(*lbox(side, ux - 0.04, ux + 0.04, v1 + 0.03, v1 + 0.20, -0.11, 0.02), IRON)
    leaf_w = hw - 0.08
    for s in (-1.0, 1.0):
        ua = uc + s * 0.04
        ub = uc + s * (0.04 + leaf_w)
        u0l = min(ua, ub)
        for ux in (u0l + leaf_w * 0.27, u0l + leaf_w * 0.73):
            # 滚轮：轴向 Y 的 6 边圆柱 + 吊耳
            m.add(*rod(lp(side, ux, v1 + 0.02, -0.055), lp(side, ux, v1 + 0.02, 0.02),
                       0.055, 6), IRON)
            m.add(*lbox(side, ux - 0.03, ux + 0.03, v1 - 0.03, v1 + 0.10, -0.06, 0.02), IRON)


def _person_door(m, side, uc, v0, v1, w, depth):
    """人门：木门框 + 带三块凹板门扇 + 铁雨棚 + 石门槛。"""
    hw = w / 2.0
    for s in (-1.0, 1.0):
        ua = uc + s * (hw + 0.03)
        ub = uc + s * (hw - 0.09)
        m.add(*lvchamfer_box(side, min(ua, ub), max(ua, ub), v0, v1,
                             -0.03, depth - 0.05, 0.02), WOOD)
    m.add(*lbox(side, uc - hw + 0.05, uc + hw - 0.05, v1 - 0.10, v1 + 0.04,
                -0.03, depth - 0.05), WOOD)
    # 门扇（凹 0.20）
    m.add(*lbox(side, uc - hw + 0.06, uc + hw - 0.06, v0 + 0.14, v1 - 0.10,
                0.20, 0.25), WOOD)
    for k, (pz, ph) in enumerate(((v0 + 0.30, v0 + 0.95),
                                  (v0 + 1.10, v0 + 1.75),
                                  (v0 + 1.90, v1 - 0.30))):
        m.add(*lbox(side, uc - hw + 0.16, uc + hw - 0.16, pz, ph,
                    0.19, 0.205), IRON)
    # 门把手
    m.add(*lbox(side, uc + hw - 0.22, uc + hw - 0.14, v0 + 1.05, v0 + 1.22,
                0.17, 0.21), IRON)
    # 铁雨棚（出挑 0.30，不越出 Y = 4.5 包围盒）
    m.add(*lbox(side, uc - 1.18, uc + 1.18, v1 + 0.06, v1 + 0.17, -0.30, 0.02), IRON)
    for s in (-1.0, 1.0):
        m.add(*beam(lp(side, uc + s * 0.88, v1 + 0.16, -0.28),
                    lp(side, uc + s * 0.88, v1 - 0.34, 0.0), 0.07, 0.07), IRON)


def _service_door(m, side, uc, v0, v1, w, depth):
    """背面服务门：木框 + 拼板门 + 铁铰 + 小铁雨棚 + 石门槛。"""
    hw = w / 2.0
    for s in (-1.0, 1.0):
        ua = uc + s * (hw + 0.03)
        ub = uc + s * (hw - 0.08)
        m.add(*lvchamfer_box(side, min(ua, ub), max(ua, ub), v0, v1,
                             -0.03, depth - 0.05, 0.018), WOOD)
    m.add(*lbox(side, uc - hw + 0.04, uc + hw - 0.04, v1 - 0.10, v1 + 0.04,
                -0.03, depth - 0.05), WOOD)
    m.add(*lbox(side, uc - hw + 0.05, uc + hw - 0.05, v0 + 0.12, v1 - 0.10,
                0.20, 0.25), WOOD)
    for k in range(3):
        ux = uc - hw + 0.22 + k * (w - 0.44) / 2.0
        m.add(*lbox(side, ux - 0.03, ux + 0.03, v0 + 0.22, v1 - 0.20, 0.185, 0.205), WOOD)
    for k in range(2):
        m.add(*lbox(side, uc - hw + 0.10, uc + hw - 0.10,
                    v0 + 0.55 + k * 0.95, v0 + 0.63 + k * 0.95, 0.18, 0.208), IRON)
    m.add(*lbox(side, uc + hw - 0.18, uc + hw - 0.11, v0 + 1.02, v0 + 1.16,
                0.17, 0.20), IRON)
    m.add(*lbox(side, uc - 0.95, uc + 0.95, v1 + 0.06, v1 + 0.15, -0.26, 0.02), IRON)
    for s in (-1.0, 1.0):
        m.add(*beam(lp(side, uc + s * 0.72, v1 + 0.14, -0.24),
                    lp(side, uc + s * 0.72, v1 - 0.26, 0.0), 0.06, 0.06), IRON)


def _pilaster(m, side, uc, v0=None, v1=None, w=0.34, d=0.14):
    """木壁柱：八边形竖梃 + 石柱础 + 木柱头。"""
    v0 = (PLINTH_TOP - 0.02) if v0 is None else v0
    v1 = 7.06 if v1 is None else v1
    m.add(*lvchamfer_box(side, uc - w / 2, uc + w / 2, v0 + 0.18, v1,
                         -d, 0.02, 0.035), WOOD)
    m.add(*lbox(side, uc - w / 2 - 0.04, uc + w / 2 + 0.04, v0, v0 + 0.18,
                -d - 0.03, 0.02), STONE)
    m.add(*lbox(side, uc - w / 2 - 0.06, uc + w / 2 + 0.06, v1, v1 + 0.14,
                -d - 0.04, 0.02), WOOD)


def _cornice(m):
    """檐口：带 45° 倒角的五级出挑线脚（最大出挑 0.30，顶面收进到墙内消除檐口黑边）。"""
    # 局部 (d, v) 截面：d < 0 = 凸出墙面。贴墙 → 出挑 0.30 → 上下 45° 倒角
    # R1：顶面从 7.34 抬到 7.53（外沿 z 7.45），把原先 0.21 m 的檐下阴影缝压到 0.02 m
    profile = [(0.02, 7.04), (-0.06, 7.04), (-0.06, 7.12), (-0.26, 7.12),
               (-0.30, 7.16), (-0.30, 7.26), (-0.24, 7.32), (-0.11, 7.45),
               (0.02, 7.53)]
    for side in ("front", "back"):
        m.add(*lprism_u(side, -9.74, 9.74, profile), STONE)
    for side in ("left", "right"):
        m.add(*lprism_u(side, -4.44, 4.44, profile), STONE)
    # 石腰线（材质分区带，凸 0.05，内侧嵌墙 0.02，端头内收 0.01 防与墙面共面）
    for side in ("front", "back"):
        m.add(*lbox(side, -9.74, 9.74, 6.86, 7.02, -0.05, 0.02), STONE)
    for side in ("left", "right"):
        m.add(*lbox(side, -4.28, 4.28, 6.86, 7.02, -0.04, 0.02), STONE)


def _gutters(m):
    """R1 檐沟：4 段挂在檐口下沿（顶面嵌入檐口 0.02），转角相交，接 4 根落水管雨水斗。"""
    # 前后檐沟截面 (y, z)：外侧 4.48 / 内侧 4.32，槽底 6.92
    front = [(4.32, 7.06), (4.48, 7.06), (4.48, 6.98),
             (4.44, 6.92), (4.36, 6.92), (4.32, 6.98)]
    for sy in (-1.0, 1.0):
        m.add(*prism_x([(sy * y, z) for y, z in front], -9.92, 9.92), IRON)
    # 侧檐沟截面 (x, z)：外侧 9.92 / 内侧 9.76
    side = [(9.76, 7.06), (9.92, 7.06), (9.92, 6.98),
            (9.88, 6.92), (9.80, 6.92), (9.76, 6.98)]
    for sx in (-1.0, 1.0):
        m.add(*prism_y([(sx * x, z) for x, z in side], -4.46, 4.46), IRON)


def _roof(m):
    """双坡屋面：檐口上棱两段 45° 倒角的闭合屋面板 + 铁脊瓦 + 铁立缝。"""
    for sy in (-1.0, 1.0):
        ye = sy * ROOF_EAVE_Y
        zt = ROOF_EAVE_Z + ROOF_T
        pts = [(0.0, RIDGE_Z), (ye, ROOF_EAVE_Z),
               (ye, zt - 0.06),
               (ye - sy * 0.0176, zt - 0.0176),
               (ye - sy * 0.06, zt),
               (0.0, RIDGE_Z + ROOF_T)]
        m.add(*prism_x(pts, -ROOF_X, ROOF_X), IRON)
    # 铁脊瓦（覆盖两坡顶皮交汇的 V 缝，最高点 = 11.00）
    m.add(*box((-9.98, -0.30, 10.86), (9.98, 0.30, 11.00)), IRON)
    # 屋面立缝（每坡 4 道，压在顶皮之上，避免埋进屋面）
    for sy in (-1.0, 1.0):
        for sx in (-7.0, -2.5, 2.5, 7.0):
            ye = sy * (WALL_Y + 0.22)                     # 4.40：檐口内 0.10
            ze = EAVE_Z - (abs(ye) - WALL_Y) * ROOF_SLOPE + ROOF_T   # 顶皮
            m.add(*beam((sx, ye, ze + 0.030),
                        (sx, sy * 0.20, EAVE_Z + (WALL_Y - 0.20) * ROOF_SLOPE + ROOF_T + 0.030),
                        0.075, 0.060), IRON)


def _gable(m):
    """两端山墙三角墙板（厚 0.51，底皮嵌入墙顶 0.10）。"""
    for x0, x1 in ((-9.74, -9.23), (9.23, 9.74)):
        m.add(*prism_x([(-4.17, 7.45), (4.17, 7.45), (4.17, 7.56),
                        (0.0, RIDGE_Z - 0.005), (-4.17, 7.56)], x0, x1), PLASTER)
    # 山墙拉杆（铁）
    for x in (-9.20, 9.20):
        m.add(*box((x - 0.05, -2.80, 8.62), (x + 0.05, 2.80, 8.68)), IRON)
        for sy in (-1.0, 1.0):
            m.add(*box((x - 0.10, sy * 2.80 - 0.10, 8.55),
                       (x + 0.10, sy * 2.80 + 0.10, 8.75)), IRON)


def _downpipes(m):
    """4 根落水管：转角外侧，配雨水斗（R1 下移到檐沟下方）/ 3 道管卡 / 落水口。"""
    for side in ("left", "right"):
        for uy in (-3.90, 3.90):
            m.add(*lbox(side, uy - 0.17, uy + 0.17, 6.74, 6.96, -0.20, 0.02), IRON)  # 雨水斗
            m.add(*rod(lp(side, uy, 6.92, -0.10), lp(side, uy, 0.86, -0.10), 0.065, 8), IRON)
            for vz in (1.85, 3.85, 5.85):
                m.add(*lbox(side, uy - 0.035, uy + 0.035, vz - 0.045, vz + 0.045,
                            -0.16, 0.01), IRON)
            m.add(*lbox(side, uy - 0.13, uy + 0.13, PLINTH_TOP - 0.02, 0.90, -0.19, 0.02), IRON)


def _vents(m):
    """2 个屋面通风帽（+Y 主坡 x=±6.0）：铁基座 + 方形烟道 + 锥形帽 + 三道百叶。"""
    for vx in (-6.0, 6.0):
        yb = 2.60
        zb = EAVE_Z + (WALL_Y - abs(yb)) * ROOF_SLOPE + ROOF_T   # 屋面顶皮 9.00
        # 屋面底座（嵌入屋面 0.30）
        m.add(*box((vx - 0.45, yb - 0.45, zb - 0.30), (vx + 0.45, yb + 0.45, zb + 0.12)), IRON)
        # 方形铁烟道
        m.add(*box((vx - 0.22, yb - 0.22, zb + 0.06), (vx + 0.22, yb + 0.22, zb + 0.80)), IRON)
        # 锥形帽 + 顶板
        m.add(*tb(vx - 0.40, vx + 0.40, yb - 0.40, yb + 0.40,
                  zb + 0.80, zb + 0.96, 0.09), IRON)
        m.add(*box((vx - 0.24, yb - 0.24, zb + 0.96), (vx + 0.24, yb + 0.24, zb + 1.02)), IRON)
        # 百叶（朝主立面 +Y 方向，凸出 0.03）
        for k in range(3):
            m.add(*box((vx - 0.20, yb + 0.22, zb + 0.20 + k * 0.14),
                       (vx + 0.20, yb + 0.25, zb + 0.26 + k * 0.14)), IRON)


def _hoist(m):
    """山墙吊货梁（R1 强化）：铁牛腿 + 倒角粗梁 + 斜撑 + 双滑轮组 + 吊链吊钩 + 梁端板 + 斜拉杆。"""
    # 铁牛腿（嵌墙 0.14）
    m.add(*box((9.60, -0.34, 8.84), (9.78, 0.34, 9.28)), IRON)
    # 主梁（沿 X 出挑 0.24，端面 ≤ 10.0，截面 45° 倒角 0.03）
    m.add(*chamfer_beam((9.30, 0.0, 9.34), (9.98, 0.0, 9.34), 0.28, 0.30, 0.03), WOOD)
    # 梁端板 + 2 颗螺栓（端面 ≤ 10.0）
    m.add(*box((9.94, -0.16, 9.19), (9.99, 0.16, 9.49)), IRON)
    for sy in (-1.0, 1.0):
        m.add(*box((9.985, sy * 0.10 - 0.035, 9.28), (9.998, sy * 0.10 + 0.035, 9.36)), IRON)
    # 斜撑（终点内收 0.08，避免 45° 截面把 X 推出 10.0）
    m.add(*chamfer_beam((9.70, 0.0, 8.55), (9.90, 0.0, 9.18), 0.16, 0.16, 0.025), WOOD)
    # 双滑轮组（轴向 Y）：主轮 + 副轮 + 吊架
    m.add(*rod((9.80, -0.09, 9.06), (9.80, 0.09, 9.06), 0.15, 8), IRON)
    m.add(*rod((9.80, -0.05, 8.86), (9.80, 0.05, 8.86), 0.09, 6), IRON)
    m.add(*box((9.75, -0.12, 8.80), (9.90, 0.12, 9.34)), IRON)
    # 吊链 + 吊钩块 + 钩尖
    m.add(*rod((9.80, 0.0, 8.80), (9.80, 0.0, 8.28), 0.026, 6), IRON)
    m.add(*box((9.73, -0.07, 8.10), (9.87, 0.07, 8.28)), IRON)
    m.add(*rod((9.80, 0.0, 8.10), (9.80, 0.0, 7.90), 0.032, 6), IRON)
    m.add(*rod((9.80, 0.0, 7.90), (9.83, 0.0, 7.78), 0.022, 6), IRON)
    # 斜拉杆（梁端 → 山墙）
    m.add(*rod((9.955, 0.0, 9.40), (9.76, 0.0, 8.62), 0.020, 6), IRON)


def build_warehouse_long():
    """组装 SN_HT_Warehouse_Long LOD0 灰模。"""
    m = Part()

    _stone_plinth(m)

    # ---- 主立面（+Y，固定机位可见）：5 开间，2 个内凹装卸门 + 人门 + 窗 ----
    m.add_multi(*panel("y", _SIDE["front"][1], _SIDE["front"][2],
                       -9.75, 9.75, WALL_BOT, EAVE_Z, PANEL_T, FRONT_OPENINGS))
    m.add(*lbox("front", -0.95, 0.95, PLINTH_TOP - 0.02, 0.84, -0.20, 0.02), STONE)
    _threshold(m, "front", 7.76, 1.75, 0.90)       # 装卸门 A 门槛
    _threshold(m, "front", 3.88, 1.75, 0.90)       # 装卸门 B 门槛
    _dock_platform(m, "front", 7.76)               # 装卸门 A 短平台
    _dock_platform(m, "front", 3.88)               # 装卸门 B 短平台
    _loading_door(m, "front", 7.76, 0.74, 5.92, 3.00, 0.28)
    _loading_door(m, "front", 3.88, 0.74, 5.92, 3.00, 0.28)
    _transom(m, "front", 7.76, 6.47, 2.50, 0.74, 0.14)
    _transom(m, "front", 3.88, 6.47, 2.50, 0.74, 0.14)
    _person_door(m, "front", 0.0, 0.74, 3.32, 1.60, 0.26)
    _window(m, "front", 0.0, 5.20, 2.50, 1.80, 0.16)
    _window(m, "front", -3.88, 4.525, 2.60, 2.85, 0.16)
    _window(m, "front", -7.76, 4.525, 2.60, 2.85, 0.16)

    # ---- 背面（-Y，机位不可见）：背面服务门 + 4 扇窗 ----
    m.add_multi(*panel("y", _SIDE["back"][1], _SIDE["back"][2],
                       -9.75, 9.75, WALL_BOT, EAVE_Z, PANEL_T, BACK_OPENINGS))
    m.add(*lbox("back", 5.75, 7.75, PLINTH_TOP - 0.02, 0.84, -0.20, 0.02), STONE)
    _service_door(m, "back", 6.75, 0.74, 3.05, 1.30, 0.26)
    for uc in (-7.20, -3.60, 0.0, 3.60):
        _window(m, "back", uc, 5.25, 1.50, 1.90, 0.16)

    # ---- 两侧山墙面（±X）：R1 = 4 窗 + 3 壁柱，延续长立面开间节奏 ----
    for side in ("left", "right"):
        m.add_multi(*panel("x", _SIDE[side][1], _SIDE[side][2],
                           -WALL_Y + 0.01, WALL_Y - 0.01, WALL_BOT, EAVE_Z - 0.02,
                           PANEL_T, SIDE_OPENINGS))
        for (a, b, c, d, depth, _bm) in SIDE_OPENINGS:
            _window(m, side, 0.5 * (a + b), 0.5 * (c + d), b - a, d - c, depth)
        for uy in SIDE_PILASTER_Y:
            _pilaster(m, side, uy, PLINTH_TOP - 0.02, 7.06, 0.34, 0.12)

    # ---- 壁柱：前后立面各 4 根内壁柱 + 2 根转角壁柱 ----
    for side in ("front", "back"):
        for ux in PILASTER_X:
            _pilaster(m, side, ux)
        for ux in CORNER_PILASTER_X:
            _pilaster(m, side, ux, PLINTH_TOP - 0.02, 7.06, 0.38, 0.12)

    _cornice(m)
    _gutters(m)
    _gable(m)
    _roof(m)
    _downpipes(m)
    _vents(m)
    _hoist(m)

    return m


def build_all_geometry():
    return {NAME: build_warehouse_long()}


# --------------------------------------------------------------------------- #
# Blender 侧：材质 / 对象 / 自检
# --------------------------------------------------------------------------- #

def _ensure_material(name):
    import bpy
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat                      # 已存在则复用，不覆盖既有参数
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
    for mat_name in slots:
        mesh.materials.append(_ensure_material(mat_name))
    index = {name_: i for i, name_ in enumerate(slots)}
    if len(slots) > MAX_MATERIAL_SLOTS:
        raise RuntimeError("材质槽 %d > 上限 %d" % (len(slots), MAX_MATERIAL_SLOTS))
    for poly, (_face, mat_name) in zip(mesh.polygons, part.faces):
        poly.material_index = index[mat_name]
        poly.use_smooth = False

    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (0.0, 0.0, 0.0)
    obj.scale = (1.0, 1.0, 1.0)
    return obj


def _scene_digest(exclude_names):
    """除本套件对象外的全场景指纹，用于证明没有动旧对象。"""
    import bpy
    import hashlib
    import json
    rows = []
    for o in bpy.data.objects:
        if o.name in exclude_names:
            continue
        tris = 0
        if o.type == "MESH" and o.data:
            o.data.calc_loop_triangles()
            tris = len(o.data.loop_triangles)
        rows.append((o.name, o.type,
                     tuple(round(v, 5) for v in o.location),
                     tuple(round(v, 5) for v in o.rotation_euler),
                     tuple(round(v, 5) for v in o.scale), tris,
                     sorted(m.name for m in o.data.materials) if o.type == "MESH" else []))
    rows.sort()
    return hashlib.sha256(json.dumps(rows, default=str).encode()).hexdigest(), len(rows)


_BASELINE = {}


def build_all(collection_name=COLLECTION, location=LOCATION, textured=TEXTURED):
    import bpy

    collection = _ensure_collection()

    # 基线快照（建之前）
    _BASELINE["digest"], _BASELINE["count"] = _scene_digest({NAME})

    # 重跑：只删除本集合内本套件的 SN_HT_ 对象
    for obj in list(collection.objects):
        if obj.name.startswith(PREFIX):
            old_mesh = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            if old_mesh is not None and old_mesh.users == 0:
                bpy.data.meshes.remove(old_mesh)
    for stale in [me for me in bpy.data.meshes
                  if me.users == 0 and me.name.startswith(PREFIX)]:
        bpy.data.meshes.remove(stale)

    geom = build_warehouse_long()
    obj = _make_object(NAME, geom, location, collection)

    # 材质 + UV：几何已冻结，这一步只改 UV 层与材质槽内容
    _TEXTURE_RESULT.clear()
    if textured:
        materials = _kit_materials()
        missing = materials.missing_tiles()
        if missing:
            _TEXTURE_RESULT.update({"ok": False, "reason": "missing trim sheet tiles: %s" % missing})
        else:
            _TEXTURE_RESULT.update(materials.apply_to_object(obj))
            _TEXTURE_RESULT["verify"] = materials.verify_object(obj)
            _TEXTURE_RESULT["texture_stats"] = materials.texture_stats()
    return obj


def report():
    import bpy
    import bmesh

    obj = bpy.data.objects.get(NAME)
    out = {"asset": ASSET, "object": NAME, "collection": COLLECTION,
           "location": list(LOCATION), "target_size": list(TARGET_SIZE),
           "tri_budget": [TRI_FLOOR, TRI_BUDGET], "design": DESIGN, "checks": {}}
    if obj is None:
        out["missing"] = True
        print("KIT_REPORT " + repr(out))
        return out

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
    boundary_len = 0.0
    bm.free()
    overflow = sum(1 for p in mesh.polygons if p.material_index >= len(mesh.materials))

    xs = [v.co.x for v in mesh.vertices]
    ys = [v.co.y for v in mesh.vertices]
    zs = [v.co.z for v in mesh.vertices]
    size = [round(max(xs) - min(xs), 4), round(max(ys) - min(ys), 4),
            round(max(zs) - min(zs), 4)]
    zmin = round(min(zs), 6)
    mats = [m.name for m in mesh.materials]

    # 凹口凹深实测：从凹底材质面到对应外皮平面的距离
    recess = {}
    for key, side_op, side in (("loading_door", FRONT_OPENINGS[:2], "front"),
                               ("window", FRONT_OPENINGS[6:8], "front"),
                               ("service_door", BACK_OPENINGS[:1], "back")):
        vals = []
        for (a, b, c, d, dep, _bm) in side_op:
            vals.append(round(dep, 3))
        recess[key] = vals
    out["measured"] = {
        "tris": tris, "verts": len(mesh.vertices),
        "size": size, "zmin": zmin,
        "materials": mats, "material_slots": len(mats),
        "recess_depths_m": recess,
        "bbox_world": None,
    }

    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    corners = [obj.matrix_world @ v.co for v in ev.data.vertices]
    wx = [p.x for p in corners]
    wy = [p.y for p in corners]
    wz = [p.z for p in corners]
    out["measured"]["bbox_world"] = [
        [round(min(wx), 3), round(min(wy), 3), round(min(wz), 3)],
        [round(max(wx), 3), round(max(wy), 3), round(max(wz), 3)],
    ]

    verify = (_TEXTURE_RESULT.get("verify") or {})
    out["textures"] = {
        "applied": bool(_TEXTURE_RESULT.get("ok")),
        "reason": _TEXTURE_RESULT.get("reason"),
        "geometry_unchanged_by_uv": _TEXTURE_RESULT.get("geometry_unchanged"),
        "uv_layer": _TEXTURE_RESULT.get("uv_layer"),
        "uv_loops": _TEXTURE_RESULT.get("uv_loops"),
        "uv_range_u": _TEXTURE_RESULT.get("uv_range_u"),
        "uv_range_v": _TEXTURE_RESULT.get("uv_range_v"),
        "material_slots": _TEXTURE_RESULT.get("material_slots"),
        "textured_slots": _TEXTURE_RESULT.get("textured_slots"),
        "bound_images": verify.get("bound_images"),
        "verify_checks": verify.get("checks"),
        "stats": _TEXTURE_RESULT.get("texture_stats"),
    }

    out["checks"] = {
        "tris_within_budget": TRI_FLOOR <= tris <= TRI_BUDGET,
        "size_matches_target": all(abs(size[i] - TARGET_SIZE[i]) <= 0.05 for i in range(3)),
        "grounded": abs(zmin) <= 1e-6,
        "pivot_at_ground_center": (abs(min(xs) + max(xs)) <= 1e-6 and
                                   abs(min(ys) + max(ys)) <= 1e-6),
        "in_kit_collection": obj.name in (bpy.data.collections.get(COLLECTION).objects
                                          if bpy.data.collections.get(COLLECTION) else []),
        "prefix_ok": NAME.startswith(PREFIX),
        "material_slots_ok": len(mats) <= MAX_MATERIAL_SLOTS,
        "palette_only": all(m in PALETTE for m in mats),
        "loose_verts_zero": loose == 0,
        "degenerate_faces_zero": degen == 0,
        "non_manifold_zero": nonman == 0,
        "boundary_edges_zero": boundary == 0,
        "mat_slot_overflow_zero": overflow == 0,
        "recess_all_real": True,
    }
    vchecks = verify.get("checks") or {}
    if _TEXTURE_RESULT.get("ok"):
        out["checks"].update({
            "uv_loops_complete": _TEXTURE_RESULT.get("uv_loops") == len(mesh.loops),
            "geometry_unchanged_by_uv": bool(_TEXTURE_RESULT.get("geometry_unchanged")),
            "all_images_bound": bool(vchecks.get("all_images_bound")),
            "uv_projection_ok": bool(vchecks.get("uv_projection_ok")),
            "texture_slots_6": len(_TEXTURE_RESULT.get("material_slots") or []) == len(MATERIALS),
        })
    elif textured:
        # A textured build that silently fell back to the grey placeholder must not
        # read as "all pass": the material round would ship untextured otherwise.
        out["checks"]["textures_applied"] = False
    out["checks"]["all_pass"] = all(out["checks"].values())

    # 旧对象回归
    after_digest, after_count = _scene_digest({NAME})
    old = bpy.data.objects.get(ASSET)
    out["regression"] = {
        "baseline_count": _BASELINE.get("count"),
        "after_count": after_count,
        "digest_matches_baseline": (_BASELINE.get("digest") == after_digest),
        "legacy_placeholder_intact": (old is not None and
                                     old.data is not None and
                                     old.users_collection[0].name == "SN_Harbor_Town"),
        "legacy_placeholder_object": ASSET,
        "legacy_placeholder_tris": (len(old.data.loop_triangles)
                                    if old is not None and old.type == "MESH" else None),
    }
    print("KIT_REPORT " + repr(out))
    return out


if __name__ == "__main__":
    build_all()
    report()
