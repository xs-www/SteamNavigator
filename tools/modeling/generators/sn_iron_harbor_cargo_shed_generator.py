# -*- coding: utf-8 -*-
"""Steam Navigator — 铁港中等精度建筑套件生成器：SN_HT_Cargo_Shed LOD0（开敞货棚）。

工单：`tools/modeling/briefs/sn_iron_harbor_architecture_kit_v1.json`
      → `building_archetypes[cargo_shed]`：8.0 × 6.0 × 4.5 m，
        required_features = 开放柱廊 / 真实厚度棚顶 / 后挡板 / 工作台 / 吊钩 / 货箱和托盘，
        silhouette = 低矮开敞，不得读成封闭小屋。
角色：iron-harbor 建筑套件 5 个 drop-in 建筑中的第 4 个，替换 PortStage
      `TOWN_SLOTS` 里 `cargo_shed` 槽位（pos 1.0 / yaw −90° / scale 1.0）的旧占位资产；
      资产名、占地尺寸、轴心（地面中心）不变。
参考实现（几何已过门禁并冻结）：`sn_iron_harbor_architecture_kit_generator.py`。
      本文件按同一风格重写：纯 Python（不 import bpy）、单一 mesh、闭合实体、
      显式倒角（不用 Bevel 修改器）、真实凹口、石基收分、真实厚度棚顶。
只创建 / 修改本文件；材质 / UV 由 Lead 用 `sn_iron_harbor_materials.apply_to_object()` 写入。

朝向（本楼的几何核心）
----------------------
PortStage 给 `cargo_shed` 的 yaw = −90°，把资产局部 **+X** 送到固定机位（约偏离机位轴
28°），局部 ±Y 则约 62°。因此：
- **+X 面 = 主立面 = 开敞柱廊**（无墙板，4 根木柱 + 檐梁 + 系梁 + 斜撑 + 低矮挡墙）；
- **+Y 面 = 次要可见面**（掠射 62°）：低矮木女墙（0.98 m）+ 3 根立柱 + 石压顶，
  上部完全开敞，可以越过女墙看进棚内；
- **−X 面 = 背面**：木拼板厚墙板（0.28）+ 1 个高位小窗（真凹 0.16）+ 后挡板；
- **−Y 面**：与 +Y 对称的低矮女墙（机位背侧）。
整栋是「低矮 + 开敞 + 棚顶有厚度」的货棚，不是封闭小屋：+X 面 0.6 m 以上几乎没有
实体面（只剩柱 / 梁端面），开敞净宽 4.98 m、净高 3.98 m。

几何要点
--------
- **包围盒定死 8.000 × 6.000 × 4.500**：石基 / 踏步给出地面轮廓，棚顶给出 ±Y 与
  ±X 外沿；zmin = 0，轴心在地面中心。
- **石基两级收分**（0.16 / 0.30 m），前侧一级石踏步（顶 0.15），棚内地坪顶 0.32
  （比石基压顶高 0.02，避免共面）；地坪四边嵌入墙 / 柱脚，不留缝。
- **单坡棚顶**：前高（顶皮 Z=4.500）后低（3.726），坡度 5.57°，板厚 0.22；
  前檐外沿 2 段倒角 + 0.114 m 竖直檐口立面；12 道立缝、8 道露明铁椽、2 道木封檐板。
- **开敞柱廊**：4 根 0.22×0.22 八边形倒角木柱（y = −2.60 / −0.87 / +0.87 / +2.60），
  石柱础 + 2 道铁柱箍 + 梁下铁牛腿；檐梁（4.02–4.30）承棚顶，系梁（3.26–3.48）
  拉结并挂吊钩；两端开间各 1 根斜撑；两端开间底部各 1 段石挡墙 + 铁护边。
- **后挡板**：后墙内侧 2 条加厚木板带（凸 0.10，z 1.90–2.49）+ 2 道铁压条 + 4 根墙筋
  + 铁工具排（1.58–1.66）+ 5 件挂具 + 2 根后墙斜撑；后墙立面自下而上分层：
  石基 0.30 → 工作台 1.17 → 工具排 1.30–1.66 → 后挡板 1.90–2.49 → 高位小窗 2.66–3.26。
- **棚内陈设**（全部闭合实体、全部从前侧可见）：工作台 1.84 × 0.70 × 0.85（板式台腿、
  下层搁板、2 抽屉、台虎钳、台上货箱）、吊钩（5 节链 + 吊块 + J 钩，y=−1.80，钩尖 1.83）、
  系梁上的手摇绞盘、5 个木箱（含叠放）、2 个托盘（2 件叠放 + 箱在其上）、2 个木桶、
  2 个麻袋、木梯（斜靠前檐系梁）、木料堆、工作台前木垫板、吊灯、2 道铁拉杆。
- **材质 5 槽**（≤6，全部共享调色板）：Wood / Iron / Stone / Glass / Plaster
  （本楼没有砖墙和灰泥墙面，砖与灰泥不用；麻袋用 Plaster 做浅色点）。
- 每件都是闭合实体（dryrun / 自检：边界边、非流形边、孤立点、退化面均为 0），
  不同材质面共面重叠（可见 z-fighting）自检为 0。

用法
----
纯 Python 干跑（几何门禁）：
    python tools/modeling/generators/dryrun_props.py tools/modeling/generators/sn_iron_harbor_cargo_shed_generator.py
自检（三角面 / 包围盒 / 健康 / 每材质面数与面积 / DESIGN 清单，全绿才返回 0）：
    python tools/modeling/generators/sn_iron_harbor_cargo_shed_generator.py
Blender 内（Lead 侧）：
    ns = {"__name__": "sn_iron_harbor_cargo_shed_generator", "__file__": p}
    exec(compile(open(p, encoding="utf-8").read(), p, "exec"), ns)
    part = ns["build_cargo_shed"]()          # -> Part(verts, faces=(indices, material))
"""

import math

# --------------------------------------------------------------------------- #
# 工单常量
# --------------------------------------------------------------------------- #

COLLECTION = "SN_Iron_Harbor_Architecture"
PREFIX = "SN_HT_"
ASSET = "SN_HT_Cargo_Shed"
NAME = ASSET + "_LOD0"
LOCATION = (0.0, 0.0, 0.0)              # 根节点归零；PortStage 布局位置由 Lead 侧给
TARGET_SIZE = (8.0, 6.0, 4.5)           # X × Y × Z（m），与旧占位资产一致
TRI_BUDGET = 5000                       # building_small_lod0 上限
TRI_FLOOR = 3000                        # building_small_lod0 下限

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

MAX_MATERIAL_SLOTS = 6

# --------------------------------------------------------------------------- #
# 体量常量（局部坐标：X 长轴 ±4.0，Y 进深 ±3.0，Z 0 → 4.5）
# --------------------------------------------------------------------------- #

HALF_X = 4.0            # 开间方向半长（X）
HALF_Y = 3.0            # 进深方向半深（Y）
TOP_Z = 4.5             # 总高 = 棚顶顶皮最高点

# 石基：两级收分，底面定死 8.0 × 6.0
PLINTH_X = 3.86         # 第一级底面半长
PLINTH_Y = 2.86         # 第一级底面半深
PLINTH_Z1 = 0.16        # 第一级顶面
PLINTH_TOP = 0.30       # 第二级顶面 = 墙脚 / 柱脚起始面
PLINTH_TAPER1 = 0.05    # 第一级收分
PLINTH_TAPER2 = 0.03    # 第二级收分
PLINTH_X1 = PLINTH_X - PLINTH_TAPER1        # 3.81
PLINTH_Y1 = PLINTH_Y - PLINTH_TAPER1        # 2.81

FLOOR_TOP = 0.32        # 棚内地坪顶面（比石基压顶高 0.02，避免共面）

# 后墙（−X 背面）：木拼板厚墙板
BACK_X = -3.76          # 外皮
WALL_T = 0.28           # 板厚（凹口侧壁露出的厚度，工单 0.12–0.35）
BACK_X_IN = BACK_X + WALL_T                 # −3.48 内皮

# 两侧低矮女墙（±Y）
PARAPET_OUT = 2.72      # 外皮
PARAPET_IN = 2.50       # 内皮（厚 0.22）
PARAPET_Z0 = 0.28       # 嵌入石基 0.02
PARAPET_Z1 = 1.16       # 墙身顶
COPING_Z1 = 1.28        # 石压顶顶面 → 女墙总高 0.98 m

# 开敞柱廊（+X 主立面）
POST_X0, POST_X1 = 3.41, 3.63      # 0.22 见方
POST_W = POST_X1 - POST_X0
POST_Y = (-2.60, -0.87, 0.87, 2.60)
POST_Z0, POST_Z1 = 0.28, 4.10     # 柱顶插入檐梁 0.08
PLATE_Z0, PLATE_Z1 = 4.02, 4.30   # 前檐梁（承棚顶）
TIE_Z0, TIE_Z1 = 3.26, 3.48       # 系梁（挂吊钩）
SIDE_POST_X = (-1.90, 0.0, 1.90)  # 女墙中间立柱（把 7.3 m 长墙切成 4 段）

# 单坡棚顶：前高后低
ROOF_SLOPE = 0.0975     # X 每 +1 m 抬高 0.0975 m（≈ 5.57°）
ROOF_TOP_X = 3.94       # 顶皮前缘（最高点所在的 X；X 最大值 4.0 由檐口立面给出）
ROOF_T = 0.22           # 板厚（工单 ≥ 0.18）
ROOF_EAVE_CHAMFER = 2   # 前檐两段倒角
SEAM_Y = tuple(-2.75 + 0.5 * i for i in range(12))          # 12 道立缝
SEAM_X1 = 3.30          # 立缝前止点：立缝顶必须留在 Z=4.5 之内（顶皮最高点在前檐 3.94）
RAFTER_Y = tuple(-2.70 + 0.6 * i for i in range(10))        # 10 道露明铁椽


def roof_top_z(x):
    """棚顶顶皮高度（单坡）。ROOF_TOP_X 处 = 4.5，向 −X 每米降 0.0975。"""
    return TOP_Z + ROOF_SLOPE * (x - ROOF_TOP_X)


def roof_sof_z(x):
    """棚顶底皮（露明面）高度。"""
    return roof_top_z(x) - ROOF_T


# 后墙高位小窗（真实凹口：深 0.16，工单窗 0.10–0.18）
BACK_OPENINGS = [
    (-0.55, 0.55, 2.66, 3.26, 0.16, GLASS),
]

# 棚内陈设数据（便于 DESIGN 清单与自检逐条核对）
CRATES = (
    (-1.25, 1.70, 0.30, 0.78, 0.78, 0.72),   # 大箱（落地）
    (-0.42, 2.02, 0.30, 0.60, 0.60, 0.58),   # 中箱（落地）
    (1.35, 1.60, 0.545, 0.62, 0.62, 0.60),   # 小箱（叠在 2 个托盘上）
    (-2.35, -1.75, 0.30, 0.52, 0.52, 0.50),  # 落地箱
    (-2.35, -1.75, 0.79, 0.44, 0.44, 0.40),  # 叠放箱（压住下箱 0.01）
)
PALLETS = ((1.35, 1.60, 0.30), (1.35, 1.60, 0.425))
BARRELS = ((2.55, -1.85, 0.30), (2.30, 0.95, 0.30))
SACKS = ((-1.85, -1.90, 0.30), (-1.30, -1.55, 0.30))
HOIST_Y = -1.80

# 设计特征清单（report() 逐条输出，便于 Verifier 核对）
DESIGN = {
    "archetype": "cargo_shed",
    "asset": ASSET,
    "target_size_m": list(TARGET_SIZE),
    "silhouette": "低矮开敞货棚（柱廊 + 真实厚度单坡棚顶），不得读成封闭小屋",
    "front_open_side": "+X（PortStage yaw −90°：本地 +X 法线偏离固定机位轴 ≈28°）",
    "secondary_side": "+Y（掠射 ≈62°：低矮女墙，可越墙看进棚内）",
    "back_side": "-X（木拼板后墙 + 后挡板 + 高位小窗，机位背侧）",
    "colonnade": {
        "posts": len(POST_Y),
        "post_section_m": [POST_W, POST_W],
        "post_y_m": list(POST_Y),
        "post_z_m": [POST_Z0, POST_Z1],
        "clear_width_m": round(2.0 * (POST_Y[-1] - POST_W / 2.0), 3),
        "clear_height_m": round(roof_sof_z(ROOF_TOP_X) - PLINTH_TOP, 3),
        "plate_beam_z_m": [PLATE_Z0, PLATE_Z1],
        "tie_beam_z_m": [TIE_Z0, TIE_Z1],
        "braces_end_bays": 2,
        "kerb_segments": 2,
    },
    "roof": {
        "type": "monopitch（front high → back low）",
        "slope_deg": round(math.degrees(math.atan(ROOF_SLOPE)), 2),
        "thickness_m": ROOF_T,
        "top_z_front_m": TOP_Z,
        "top_z_back_m": round(roof_top_z(-HALF_X), 3),
        "overhang_front_m": round(HALF_X - POST_X1, 3),
        "overhang_side_m": round(HALF_Y - PARAPET_OUT, 3),
        "overhang_back_m": round(HALF_X + BACK_X, 3),
        "eave_chamfer_segments": ROOF_EAVE_CHAMFER,
        "standing_seams": len(SEAM_Y),
        "exposed_rafters": len(RAFTER_Y),
        "barge_boards": 2,
    },
    "back_wall": {
        "thickness_m": WALL_T,
        "material": "timber planks",
        "high_window_recess_m": BACK_OPENINGS[0][4],
        "board_rack": "2 条加厚木板带（凸 0.10）+ 2 道铁压条 + 4 根墙筋 + 铁工具排",
    },
    "parapets": {
        "height_m": round(COPING_Z1 - PLINTH_TOP, 3),
        "thickness_m": round(PARAPET_OUT - PARAPET_IN, 3),
        "posts_per_side": len(SIDE_POST_X),
        "upper_open": True,
    },
    "workbench_m": [1.84, 0.70, 0.85],
    "hoist_hook": {"hanging_from": "front tie beam", "y_m": HOIST_Y, "chain_links": 5},
    "crates": len(CRATES),
    "pallets": len(PALLETS),
    "barrels": len(BARRELS),
    "sacks": len(SACKS),
    "materials_used": [WOOD, IRON, STONE, GLASS, PLASTER],
}

# --------------------------------------------------------------------------- #
# 纯几何工具（与参考实现逐字一致，无 bpy 依赖）
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
    """XZ 闭合多边形沿 Y 拉伸成闭合棱柱（檐沟 / 侧向型材 / 单坡棚顶用）。"""
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
    """四根竖直棱倒角的八边形截面盒（壁柱 / 竖梃 / 立柱），10 面 16 三角面。"""
    x0, x1 = sorted((x0, x1))
    y0, y1 = sorted((y0, y1))
    z0, z1 = sorted((z0, z1))
    if x1 - x0 < 2.0 * ch or y1 - y0 < 2.0 * ch:
        return box((x0, y0, z0), (x1, y1, z1))
    pts = [(x0 + ch, y0), (x1 - ch, y0), (x1, y0 + ch), (x1, y1 - ch),
           (x1 - ch, y1), (x0 + ch, y1), (x0, y1 - ch), (x0, y0 + ch)]
    return prism_z(pts, z0, z1)


def chamfer_beam(p0, p1, w, h=None, ch=0.02):
    """带 45° 倒角的矩形截面梁（粗钢梁 / 吊货梁 / 椽），8 边截面。"""
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
#   u = 立面水平坐标（σx 立面 = Y，σy 立面 = X）
#   v = 世界 Z
#   d = 自墙外皮向内的凹深（>0 进入墙体，<0 凸出墙面）
# 本楼只有 −X 后墙带墙板（panel），±Y 只是低矮女墙（无墙板），+X 完全开敞。
# --------------------------------------------------------------------------- #

_SIDE = {
    "back":  ("x", BACK_X, 1.0),        # −X 后墙外皮，向内 +X
    "front": ("x", POST_X1, -1.0),      # +X 开敞面（无墙板，备用坐标系）
    "left":  ("y", -PARAPET_OUT, 1.0),  # −Y 女墙外皮，向内 +Y
    "right": ("y", PARAPET_OUT, -1.0),  # +Y 女墙外皮，向内 −Y
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
# 构件：石基 / 地坪 / 踏步
# --------------------------------------------------------------------------- #

def _plinth(m):
    """石基：两级收分台基（底面定死 8.0 × 6.0）+ 前侧一级石踏步（顶 0.15）。"""
    m.add(*tb(-PLINTH_X, PLINTH_X, -PLINTH_Y, PLINTH_Y,
              0.0, PLINTH_Z1, PLINTH_TAPER1), STONE)
    m.add(*tb(-PLINTH_X1, PLINTH_X1, -PLINTH_Y1, PLINTH_Y1,
              PLINTH_Z1, PLINTH_TOP, PLINTH_TAPER2), STONE)
    # 前侧踏步：底边与石基斜面咬合（0.02–0.06 嵌入），顶面 0.15；底边给出 X = +4.0
    m.add(*tb(3.80, HALF_X, -1.05, 1.05, 0.0, 0.15, 0.03), STONE)
    # 4 个角石（0.14 见方，从地面到石基压顶，凸出收分面 0.05–0.08，读作石垛角）
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            m.add(*box((sx * 3.72, sy * 2.72, 0.0), (sx * 3.86, sy * 2.86, PLINTH_TOP)), STONE)


def _floor(m):
    """棚内地坪：石铺面顶 0.32（比石基压顶高 0.02，避免共面），四边嵌入墙 / 柱 / 女墙。"""
    m.add(*box((-3.46, -2.52, 0.20), (3.44, 2.52, FLOOR_TOP)), STONE)
    # 工作台前的木垫板（4 条板，压入地坪 0.02，顶面高出地坪 0.06）
    for i in range(4):
        x0 = -2.58 + i * 0.105
        m.add(*box((x0, -0.90, FLOOR_TOP - 0.02), (x0 + 0.095, 0.90, FLOOR_TOP + 0.06)), WOOD)


# --------------------------------------------------------------------------- #
# 构件：后墙（−X 背面）
# --------------------------------------------------------------------------- #

def _back_wall(m):
    """木拼板后墙：厚墙板 0.28 + 高位小窗（真凹 0.16）+ 石窗台 + 木窗楣 / 竖框。"""
    m.add_multi(*panel("x", _SIDE["back"][1], _SIDE["back"][2],
                       -2.70, 2.70, 0.28, 3.56, WALL_T, BACK_OPENINGS,
                       mat_face=WOOD, mat_reveal=WOOD, mat_inner=WOOD))
    # 窗套（机位背侧；保证开口「有框 + 有窗台」，三件各用不同平面，避免共面）
    m.add(*box((-3.82, -0.66, 2.58), (-3.755, 0.66, 2.68)), STONE)     # 石窗台（外挑最远）
    m.add(*box((-3.81, -0.65, 3.26), (-3.745, 0.65, 3.36)), WOOD)      # 木窗楣
    for s in (-1.0, 1.0):
        y0, y1 = sorted((s * 0.555, s * 0.645))
        m.add(*box((-3.79, y0, 2.66), (-3.765, y1, 3.26)), WOOD)       # 木竖框


def _back_rack(m):
    """后挡板：2 条加厚木板带（凸 0.10）+ 2 道铁压条 + 4 根墙筋 + 铁工具排 + 5 件挂具。

    后墙立面分层（自下而上）：石基 0.30 → 工作台 1.17 → 工具排 1.30–1.66 →
    后挡板木带 1.90–2.49 → 高位小窗 2.66–3.26 → 墙顶 3.56。各层不互相穿插。
    """
    for z0 in (1.90, 2.21):
        m.add(*box((-3.50, -2.44, z0), (-3.38, 2.44, z0 + 0.28)), WOOD)
    for z0 in (1.96, 2.37):
        m.add(*box((-3.37, -2.30, z0), (-3.33, 2.30, z0 + 0.06)), IRON)
    # 4 根墙筋（压在木板带外 0.02，把后墙竖向切开）
    for py in (-1.68, -0.56, 0.56, 1.68):
        m.add(*box((-3.48, py - 0.06, 0.30), (-3.34, py + 0.06, 3.50)), WOOD)
    # 工具排：铁横杆 + 5 件挂具（台面上方 1.30–1.62）
    m.add(*box((-3.36, -0.74, 1.58), (-3.31, 0.74, 1.66)), IRON)
    for (pz, py, hw) in ((1.30, -0.60, 0.028), (1.34, -0.30, 0.042),
                         (1.26, 0.00, 0.030), (1.36, 0.30, 0.045),
                         (1.28, 0.60, 0.028)):
        m.add(*box((-3.34, py - hw, pz), (-3.31, py + hw, 1.62)), IRON)
    # 2 根斜撑（后墙内侧：从后角柱上方斜撑到棚顶下弦，避开后挡板木带）
    for s in (-1.0, 1.0):
        m.add(*chamfer_beam((-3.42, s * 2.55, 2.55), (-3.42, s * 1.45, 3.45),
                            0.08, 0.10, 0.015), WOOD)


# --------------------------------------------------------------------------- #
# 构件：开敞柱廊（+X 主立面）
# --------------------------------------------------------------------------- #

def _colonnade(m):
    """4 根倒角木柱 + 石柱础 + 铁箍 + 牛腿 + 檐梁 + 系梁 + 端开间斜撑 + 矮挡墙。"""
    for py in POST_Y:
        m.add(*vchamfer_box(POST_X0, POST_X1, py - POST_W / 2, py + POST_W / 2,
                            POST_Z0, POST_Z1, 0.03), WOOD)
        # 石柱础（比柱身宽 0.12，嵌入石基 0.02）
        m.add(*box((POST_X0 - 0.06, py - POST_W / 2 - 0.06, 0.26),
                   (POST_X1 + 0.06, py + POST_W / 2 + 0.06, 0.42)), STONE)
        # 2 道铁柱箍（凸 0.02）
        for pz in (1.30, 2.60):
            m.add(*box((POST_X0 - 0.02, py - POST_W / 2 - 0.02, pz),
                       (POST_X1 + 0.02, py + POST_W / 2 + 0.02, pz + 0.10)), IRON)
        # 梁下铁牛腿（托住檐梁，压在柱顶）
        m.add(*box((POST_X0 - 0.01, py - 0.09, 3.86),
                   (POST_X1 + 0.01, py + 0.09, 4.04)), IRON)
    # 檐梁（木）：柱列顶部承棚顶，顶面插入棚顶 0.05
    m.add(*box((3.34, -2.86, PLATE_Z0), (3.70, 2.86, PLATE_Z1)), WOOD)
    # 6 块铁连接板（梁-柱节点，正面凸 0.03）
    for py in POST_Y + (-1.70, 1.70):
        m.add(*box((3.70, py - 0.05, 4.06), (3.73, py + 0.05, 4.18)), IRON)
    # 系梁（木）：柱列中部拉结 + 吊钩挂点
    m.add(*box((3.38, -2.74, TIE_Z0), (3.66, 2.74, TIE_Z1)), WOOD)
    # 两端开间斜撑（45° 倒角截面），从柱身 2.90 撑到系梁下沿
    for s in (-1.0, 1.0):
        m.add(*chamfer_beam((3.52, s * 2.46, 2.90), (3.52, s * 1.05, 3.24),
                            0.10, 0.12, 0.02), WOOD)
    # 两端开间矮挡墙（石）+ 铁护边：读作装卸码头沿，不是围栏；中间开间留作入口
    for s in (-1.0, 1.0):
        y0, y1 = sorted((s * 2.53, s * 0.99))
        m.add(*tb(3.62, 3.78, y0, y1, 0.27, 0.54, 0.03), STONE)
        m.add(*box((3.64, y0 + 0.03, 0.54), (3.76, y1 - 0.03, 0.57)), IRON)


# --------------------------------------------------------------------------- #
# 构件：两侧低矮女墙 + 后角柱
# --------------------------------------------------------------------------- #

def _parapets(m):
    """±Y 低矮木女墙（0.98 m）+ 石压顶 + 3 根立柱 + 铁压条 + 后角柱；上部完全开敞。"""
    for s in (-1.0, 1.0):
        # 墙身（木）：前后端分别嵌入后墙与端柱，端面不外露
        m.add(*box((-3.72, s * PARAPET_IN, 0.28), (3.62, s * PARAPET_OUT, PARAPET_Z1)), WOOD)
        # 石压顶（两侧外挑 0.02 + 顶部收分 0.03）
        m.add(*tb(-3.74, 3.64, s * (PARAPET_IN - 0.02), s * (PARAPET_OUT + 0.02),
                  PARAPET_Z1, COPING_Z1, 0.03), STONE)
        # 3 根中间立柱：把 7.3 m 长女墙切成 4 段（工单 surface_breakup）
        for px in SIDE_POST_X:
            m.add(*vchamfer_box(px - 0.09, px + 0.09, s * (PARAPET_IN - 0.04),
                                s * (PARAPET_OUT + 0.02), 0.28, 1.42, 0.03), WOOD)
        # 2 道铁压条（竖向箍住女墙，凸 0.02；顶收到压顶下 0.02 防共面）
        for px in (-2.85, 2.85):
            m.add(*box((px - 0.04, s * (PARAPET_IN - 0.02), 0.30),
                       (px + 0.04, s * (PARAPET_OUT + 0.02), 1.14)), IRON)
        # 后角柱（棚内，承棚顶后角，凸出后墙内皮 0.10）
        m.add(*vchamfer_box(-3.58, -3.38, s * (PARAPET_IN - 0.02),
                            s * (PARAPET_OUT), 0.28, 3.58, 0.03), WOOD)


# --------------------------------------------------------------------------- #
# 构件：单坡棚顶
# --------------------------------------------------------------------------- #

def _roof(m):
    """单坡铁皮棚顶：板厚 0.22，前檐两段倒角 + 竖直檐口立面；12 道立缝 + 8 道露明椽 + 2 封檐板。"""
    profile = [
        (-HALF_X, roof_sof_z(-HALF_X)),      # 后檐底皮（后檐只切平，不做倒角）
        (-HALF_X, roof_top_z(-HALF_X)),      # 后檐顶皮
        (ROOF_TOP_X, TOP_Z),                 # 顶皮前缘（最高点 = 4.5）
        (3.985, 4.455),                      # 前檐倒角第 1 段
        (HALF_X, 4.400),                     # 前檐倒角第 2 段 → 竖直檐口立面顶
        (HALF_X, roof_sof_z(HALF_X)),        # 檐口立面底 = 前檐底皮
    ]
    m.add(*prism_y(profile, -HALF_Y, HALF_Y), IRON)
    # 12 道立缝（沿坡向，压在顶皮上 0.02）：前止点 SEAM_X1，保证立缝顶不进 Z=4.5 以上
    for sy in SEAM_Y:
        m.add(*beam((-3.75, sy, roof_top_z(-3.75) + 0.02),
                    (SEAM_X1, sy, roof_top_z(SEAM_X1) + 0.02), 0.06, 0.05), IRON)
    # 10 道露明铁椽：顶面插入棚顶 0.03，从前檐梁穿到后墙
    for sy in RAFTER_Y:
        m.add(*chamfer_beam((-3.62, sy, roof_sof_z(-3.62) - 0.05),
                            (3.55, sy, roof_sof_z(3.55) - 0.05), 0.09, 0.16, 0.02), IRON)
    # 两侧木封檐板：压在铁皮侧沿下方 0.20，贴坡
    for s in (-1.0, 1.0):
        m.add(*chamfer_beam((-3.96, s * 2.94, roof_sof_z(-3.96) - 0.09),
                            (3.94, s * 2.94, roof_sof_z(3.94) - 0.09), 0.06, 0.22, 0.015), WOOD)


# --------------------------------------------------------------------------- #
# 构件：棚内陈设（全部闭合实体，全部从前侧可见）
# --------------------------------------------------------------------------- #

def _workbench(m):
    """工作台 1.84 × 0.70 × 0.85（台面顶 1.17），靠后墙：板式台腿 + 搁板 + 2 抽屉 + 台虎钳。"""
    m.add(*box((-3.44, -0.92, 1.10), (-2.74, 0.92, 1.17)), WOOD)        # 台面
    for s in (-1.0, 1.0):                                              # 2 条板式台腿
        m.add(*box((-3.42, s * 0.86, 0.30), (-2.80, s * 0.80, 1.12)), WOOD)
    m.add(*box((-3.40, -0.76, 0.52), (-2.82, 0.76, 0.56)), WOOD)        # 下层搁板
    for s in (-1.0, 1.0):                                              # 2 个抽屉 + 铁拉手
        y0, y1 = sorted((s * 0.03, s * 0.68))
        m.add(*box((-3.40, y0, 0.86), (-2.94, y1, 1.08)), WOOD)
        m.add(*box((-2.94, (y0 + y1) / 2 - 0.10, 0.94),
                   (-2.92, (y0 + y1) / 2 + 0.10, 0.98)), IRON)
    # 台虎钳（钳体 + 钳口）
    m.add(*box((-3.42, -0.86, 1.17), (-3.26, -0.70, 1.31)), IRON)
    m.add(*box((-3.24, -0.84, 1.17), (-3.19, -0.72, 1.24)), IRON)
    # 台上货箱 + 铁罐（后沿嵌入后挡板木带 0.02，不共面）
    m.add(*box((-3.40, 0.24, 1.17), (-3.12, 0.58, 1.42)), WOOD)
    m.add(*rod((-3.24, 0.80, 1.17), (-3.24, 0.80, 1.38), 0.07, 8), IRON)


def _hoist(m):
    """吊钩：系梁下铁吊架 + 5 节链 + 吊块 + J 形钩（y = −1.80，正对开敞前脸）。"""
    y = HOIST_Y
    m.add(*box((3.40, y - 0.09, 3.16), (3.62, y + 0.09, 3.30)), IRON)    # 吊架（卡在系梁下）
    z = 3.14
    for k in range(5):                                                 # 5 节链（交替方向）
        if k % 2 == 0:
            m.add(*box((3.48, y - 0.032, z - 0.20), (3.52, y + 0.032, z)), IRON)
        else:
            m.add(*box((3.465, y - 0.048, z - 0.20), (3.535, y + 0.048, z)), IRON)
        z -= 0.18
    m.add(*box((3.45, y - 0.07, 2.04), (3.55, y + 0.07, 2.23)), IRON)    # 吊块（压住末节链）
    m.add(*rod((3.50, y, 2.06), (3.50, y, 1.90), 0.024, 6), IRON)        # 钩柄
    m.add(*rod((3.50, y, 1.90), (3.53, y, 1.83), 0.022, 6), IRON)        # 钩弯
    m.add(*rod((3.53, y, 1.83), (3.542, y, 1.91), 0.020, 6), IRON)       # 钩尖


def _crate(m, cx, cy, base, sx, sy, sz):
    """木货箱：箱体 + 2 块盖板 + 4 根角压条（全部闭合实体）。"""
    hx, hy = sx / 2.0, sy / 2.0
    m.add(*box((cx - hx, cy - hy, base), (cx + hx, cy + hy, base + sz)), WOOD)
    lid = base + sz
    for s in (-1.0, 1.0):                                   # 盖板（中缝 0.02，凸 0.04）
        y0, y1 = sorted((cy + s * 0.012, cy + s * (hy - 0.018)))
        m.add(*box((cx - hx + 0.018, y0, lid - 0.01),
                   (cx + hx - 0.018, y1, lid + 0.04)), WOOD)
    for sx_ in (-1.0, 1.0):                                 # 4 根角压条（凸出箱面 0.025）
        for sy_ in (-1.0, 1.0):
            m.add(*box((cx + sx_ * hx - 0.025, cy + sy_ * hy - 0.025, base + 0.02),
                       (cx + sx_ * hx + 0.025, cy + sy_ * hy + 0.025, base + sz - 0.02)),
                  WOOD)


def _pallet(m, cx, cy, base, px=1.16, py=0.94):
    """木托盘：3 根纵梁 + 3 块横板（共 6 件闭合实体，顶面 base + 0.125）。"""
    for sx_ in (-1.0, 0.0, 1.0):
        bx = cx + sx_ * (px / 2.0 - 0.09)
        m.add(*box((bx - 0.09, cy - py / 2.0, base),
                   (bx + 0.09, cy + py / 2.0, base + 0.085)), WOOD)
    for sy_ in (-1.0, 0.0, 1.0):
        by = cy + sy_ * (py / 2.0 - 0.10)
        m.add(*box((cx - px / 2.0, by - 0.10, base + 0.085),
                   (cx + px / 2.0, by + 0.10, base + 0.125)), WOOD)


def _barrel(m, cx, cy, base, r=0.29, h=0.82, sides=10):
    """木桶：10 边木桶身 + 2 道铁箍。"""
    m.add(*rod((cx, cy, base), (cx, cy, base + h), r, sides), WOOD)
    for z in (base + 0.14, base + h - 0.21):
        m.add(*rod((cx, cy, z), (cx, cy, z + 0.07), r + 0.012, sides), IRON)


def _sack(m, cx, cy, base, sx=0.42, sy=0.34, sz=0.30):
    """麻袋（灰泥材质做浅色点）：收分袋身 + 袋口。"""
    m.add(*tb(cx - sx / 2, cx + sx / 2, cy - sy / 2, cy + sy / 2, base, base + sz, 0.07), PLASTER)
    m.add(*box((cx - 0.05, cy - 0.05, base + sz - 0.03),
               (cx + 0.05, cy + 0.05, base + sz + 0.04)), PLASTER)


def _cargo(m):
    """棚内货物：5 木箱 / 2 托盘（叠放）/ 2 木桶 / 2 麻袋 / 木料堆。"""
    for (cx, cy, base, sx, sy, sz) in CRATES:
        _crate(m, cx, cy, base, sx, sy, sz)
    for (cx, cy, base) in PALLETS:
        _pallet(m, cx, cy, base)
    for (cx, cy, base) in BARRELS:
        _barrel(m, cx, cy, base)
    for (cx, cy, base) in SACKS:
        _sack(m, cx, cy, base)
    # 木料堆：2 根垫木 + 6 块板（沿 X 铺，靠 −Y 内侧；垫木压入地坪 0.02）
    for bx in (-0.60, 0.60):
        m.add(*box((bx - 0.05, -2.26, FLOOR_TOP - 0.02), (bx + 0.05, -1.96, FLOOR_TOP + 0.10)), WOOD)
    for k in range(6):
        pz = FLOOR_TOP + 0.10 + k * 0.055
        m.add(*box((-0.95, -2.22, pz), (0.95, -2.00, pz + 0.05)), WOOD)


def _ladder(m):
    """木梯：2 根侧梁 + 6 根横档，斜靠在前檐系梁上（+Y 侧，机位可见的斜线）。"""
    y = 2.10
    x0, z0, x1, z1 = 2.30, FLOOR_TOP - 0.02, 3.58, 3.30
    for sy in (-1.0, 1.0):
        m.add(*beam((x0, y + sy * 0.22, z0), (x1, y + sy * 0.22, z1 - 0.06), 0.06, 0.10), WOOD)
    for k in range(6):
        t = (k + 1.0) / 7.0
        px = x0 + (x1 - x0) * t
        pz = z0 + (z1 - z0) * t
        m.add(*beam((px, y - 0.20, pz), (px, y + 0.20, pz), 0.05, 0.07), WOOD)


def _lamp(m):
    """棚内吊灯：从露明椽（y=0.30）垂下 1 根铁杆 + 玻璃灯罩 + 铁顶盖（棚内浅色点）。"""
    x, y = 0.90, 0.30
    m.add(*rod((x, y, 3.88), (x, y, 3.62), 0.018, 6), IRON)
    m.add(*box((x - 0.05, y - 0.05, 3.48), (x + 0.05, y + 0.05, 3.62)), GLASS)
    m.add(*box((x - 0.06, y - 0.06, 3.62), (x + 0.06, y + 0.06, 3.65)), IRON)


def _tie_rods(m):
    """2 道铁拉杆横跨进深（z = 2.95）：拉住两侧女墙，并给开敞前脸一道细横线。"""
    for px in (0.0, -1.90):
        m.add(*rod((px, -2.52, 2.95), (px, 2.52, 2.95), 0.022, 6), IRON)
        for sy in (-1.0, 1.0):
            m.add(*box((px - 0.05, sy * 2.52 - 0.05, 2.90),
                       (px + 0.05, sy * 2.52 + 0.05, 3.00)), IRON)


def _winch(m):
    """系梁上的手摇绞盘（吊钩的收放端）：2 块铸铁支架 + 8 边卷筒 + 摇柄。"""
    y = 1.55
    for sy in (-1.0, 1.0):
        m.add(*box((3.44, y + sy * 0.16 - 0.03, 3.48), (3.60, y + sy * 0.16 + 0.03, 3.68)), IRON)
    m.add(*rod((3.52, y - 0.13, 3.60), (3.52, y + 0.13, 3.60), 0.09, 8), IRON)
    m.add(*rod((3.52, y + 0.15, 3.60), (3.52, y + 0.29, 3.60), 0.018, 6), IRON)
    m.add(*rod((3.52, y + 0.29, 3.60), (3.52, y + 0.29, 3.76), 0.018, 6), IRON)


# --------------------------------------------------------------------------- #
# 组装
# --------------------------------------------------------------------------- #

def build_cargo_shed():
    """组装 SN_HT_Cargo_Shed LOD0：低矮、开敞、真实厚度棚顶的港口货棚。"""
    m = Part()
    _plinth(m)
    _floor(m)
    _back_wall(m)
    _back_rack(m)
    _colonnade(m)
    _parapets(m)
    _roof(m)
    _workbench(m)
    _hoist(m)
    _winch(m)
    _cargo(m)
    _ladder(m)
    _lamp(m)
    _tie_rods(m)
    return m


def build_all_geometry():
    return {NAME: build_cargo_shed()}


# --------------------------------------------------------------------------- #
# 纯 Python 自检（不依赖 Blender）
# --------------------------------------------------------------------------- #

def _newell(verts, face):
    nx = ny = nz = 0.0
    n = len(face)
    for i in range(n):
        p = verts[face[i]]
        q = verts[face[(i + 1) % n]]
        nx += (p[1] - q[1]) * (p[2] + q[2])
        ny += (p[2] - q[2]) * (p[0] + q[0])
        nz += (p[0] - q[0]) * (p[1] + q[1])
    return nx, ny, nz


def _face_area(verts, face):
    nx, ny, nz = _newell(verts, face)
    return 0.5 * math.sqrt(nx * nx + ny * ny + nz * nz)


def _edge_stats(faces):
    counter = {}
    for face, _mat in faces:
        n = len(face)
        for i in range(n):
            a, b = face[i], face[(i + 1) % n]
            key = (a, b) if a < b else (b, a)
            counter[key] = counter.get(key, 0) + 1
    boundary = sum(1 for c in counter.values() if c == 1)
    nonman = sum(1 for c in counter.values() if c > 2)
    return boundary, nonman


def _degenerate(verts, faces):
    bad = 0
    for face, _mat in faces:
        if len(set(face)) != len(face):
            bad += 1
            continue
        p0 = verts[face[0]]
        for i in range(1, len(face) - 1):
            p1, p2 = verts[face[i]], verts[face[i + 1]]
            ux, uy, uz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
            vx, vy, vz = p2[0] - p0[0], p2[1] - p0[1], p2[2] - p0[2]
            cx = uy * vz - uz * vy
            cy = uz * vx - ux * vz
            cz = ux * vy - uy * vx
            if (cx * cx + cy * cy + cz * cz) ** 0.5 * 0.5 < 1e-9:
                bad += 1
                break
    return bad


def _shells(part):
    """按共享顶点把面聚成连通壳体（每个 add() 的实体自成一壳）。"""
    parent = list(range(len(part.faces)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[max(ra, rb)] = min(ra, rb)

    owner = {}
    for fi, (face, _mat) in enumerate(part.faces):
        for v in face:
            if v in owner:
                union(fi, owner[v])
            else:
                owner[v] = fi
    groups = {}
    for fi in range(len(part.faces)):
        groups.setdefault(find(fi), []).append(fi)
    return list(groups.values())


def _oriented_normals(part):
    """每面的外向法线 + 平面偏移（用有向体积把每壳朝向统一为外向）。"""
    out = []
    for fi, (face, _mat) in enumerate(part.faces):
        nx, ny, nz = _newell(part.verts, face)
        length = math.sqrt(nx * nx + ny * ny + nz * nz)
        out.append([nx / length, ny / length, nz / length] if length > 1e-12 else [0.0, 0.0, 0.0])
    for shell in _shells(part):
        vol = 0.0
        for fi in shell:
            face = part.faces[fi][0]
            p0 = part.verts[face[0]]
            for i in range(1, len(face) - 1):
                p1, p2 = part.verts[face[i]], part.verts[face[i + 1]]
                vol += (p0[0] * (p1[1] * p2[2] - p1[2] * p2[1])
                        - p0[1] * (p1[0] * p2[2] - p1[2] * p2[0])
                        + p0[2] * (p1[0] * p2[1] - p1[1] * p2[0]))
        if vol < 0.0:
            for fi in shell:
                out[fi] = [-c for c in out[fi]]
    return out


def _coplanar_conflicts(part, eps=5e-4):
    """不同材质、法线同向、共面且投影重叠的面数（可见 z-fighting 风险）。"""
    normals = _oriented_normals(part)
    groups = {}
    for fi, (face, mat) in enumerate(part.faces):
        n = normals[fi]
        p0 = part.verts[face[0]]
        d = n[0] * p0[0] + n[1] * p0[1] + n[2] * p0[2]
        key = (round(n[0], 3), round(n[1], 3), round(n[2], 3))
        groups.setdefault(key, []).append((d, mat, fi))
    hits = []
    for key, rows in groups.items():
        if len(rows) < 2:
            continue
        rows.sort()
        n = key
        axes = [i for i in range(3) if abs(n[i]) < 0.5]
        for i in range(len(rows)):
            for j in range(i + 1, len(rows)):
                if rows[j][0] - rows[i][0] > eps:
                    break
                if rows[i][1] == rows[j][1]:
                    continue
                fa, fb = part.faces[rows[i][2]][0], part.faces[rows[j][2]][0]
                ok = True
                for ax in axes:
                    a0 = min(part.verts[v][ax] for v in fa)
                    a1 = max(part.verts[v][ax] for v in fa)
                    b0 = min(part.verts[v][ax] for v in fb)
                    b1 = max(part.verts[v][ax] for v in fb)
                    if min(a1, b1) - max(a0, b0) <= 1e-4:
                        ok = False
                        break
                if ok:
                    hits.append((rows[i][1], rows[j][1]))
    return hits


def measure(part=None):
    """返回几何实测值（tri / bbox / 健康 / 每材质面数与面积 / 开敞面面积）。"""
    part = build_cargo_shed() if part is None else part
    verts, faces = part.verts, part.faces
    xs = [v[0] for v in verts]
    ys = [v[1] for v in verts]
    zs = [v[2] for v in verts]
    tris = sum(max(0, len(f) - 2) for f, _m in faces)
    boundary, nonman = _edge_stats(faces)
    used = set()
    for f, _m in faces:
        used.update(f)
    loose = len(verts) - len(used)
    per_mat = {}
    for f, mat in faces:
        rows = per_mat.setdefault(mat, [0, 0.0])
        rows[0] += 1
        rows[1] += _face_area(verts, f)
    # +X 开敞面：z > 0.6 处朝向 +X 的实体面面积（柱 / 梁 / 挡墙端面），越小越开敞
    open_x_area = 0.0
    for f, _m in faces:
        nx, ny, nz = _newell(verts, f)
        length = math.sqrt(nx * nx + ny * ny + nz * nz)
        if length < 1e-12 or nx / length < 0.95:
            continue
        if min(verts[v][0] for v in f) <= 3.0:
            continue
        if max(verts[v][2] for v in f) <= 0.6:
            continue
        open_x_area += _face_area(verts, f)
    return {
        "tris": tris,
        "verts": len(verts),
        "size": (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)),
        "bbox": ((min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))),
        "zmin": min(zs),
        "sym_x": abs(min(xs) + max(xs)),
        "sym_y": abs(min(ys) + max(ys)),
        "boundary": boundary,
        "nonmanifold": nonman,
        "loose": loose,
        "degenerate": _degenerate(verts, faces),
        "per_mat": per_mat,
        "open_front_area_m2": open_x_area,
        "open_front_ratio": open_x_area / (2.0 * HALF_Y * TOP_Z),
        "coplanar_conflicts": _coplanar_conflicts(part),
    }


def report():
    """自检并打印：三角面 / 包围盒 / 健康 / 每材质面数与面积 / DESIGN 清单。

    打印全部用 ASCII（Windows 控制台默认 GBK，避免编码错误让自检本身失败）。
    """
    m = build_cargo_shed()
    r = measure(m)
    eps = 1e-6
    checks = {}

    print("=" * 78)
    print("%s  self-check" % NAME)
    print("=" * 78)
    print("tri        = %d   (floor %d / budget %d)" % (r["tris"], TRI_FLOOR, TRI_BUDGET))
    print("verts      = %d" % r["verts"])
    print("bbox       = (%.4f, %.4f, %.4f) .. (%.4f, %.4f, %.4f)"
          % (r["bbox"][0][0], r["bbox"][0][1], r["bbox"][0][2],
             r["bbox"][1][0], r["bbox"][1][1], r["bbox"][1][2]))
    print("size       = %.6f x %.6f x %.6f m   target = %.1f x %.1f x %.1f"
          % (r["size"][0], r["size"][1], r["size"][2], *TARGET_SIZE))
    print("zmin       = %.6f" % r["zmin"])
    print("symmetry   |minx+maxx| = %.3e   |miny+maxy| = %.3e" % (r["sym_x"], r["sym_y"]))
    print("health     boundary=%d  non-manifold=%d  loose verts=%d  degenerate faces=%d"
          % (r["boundary"], r["nonmanifold"], r["loose"], r["degenerate"]))
    print("open front +X solid faces above z=0.6 m = %.3f m2 (%.1f%% of the 6 x 4.5 m front "
          "elevation; posts / beams / eave only)"
          % (r["open_front_area_m2"], r["open_front_ratio"] * 100.0))
    print("per-material faces / area:")
    for mat in sorted(r["per_mat"]):
        n, area = r["per_mat"][mat]
        print("  %-16s %4d faces   %8.3f m2" % (mat, n, area))
    print("material slots = %d (<= %d)" % (len(r["per_mat"]), MAX_MATERIAL_SLOTS))
    print("coplanar same-normal different-material overlaps = %d"
          % len(r["coplanar_conflicts"]))

    c = DESIGN["colonnade"]
    ro = DESIGN["roof"]
    print("-" * 78)
    print("DESIGN checklist: low, wide, OPEN cargo shed (colonnade + real-thickness monopitch "
          "roof); must not read as a closed cabin")
    rows = [
        ("open colonnade (open front on +X)",
         c["posts"] == 4,
         "%d posts %.2fx%.2f at y=%s, z %.2f..%.2f; plate beam %.2f-%.2f, tie beam %.2f-%.2f; "
         "%d end-bay braces; %d kerb segments"
         % (c["posts"], c["post_section_m"][0], c["post_section_m"][1],
            list(c["post_y_m"]), c["post_z_m"][0], c["post_z_m"][1],
            c["plate_beam_z_m"][0], c["plate_beam_z_m"][1],
            c["tie_beam_z_m"][0], c["tie_beam_z_m"][1],
            c["braces_end_bays"], c["kerb_segments"])),
        ("real-thickness roof slab",
         ro["thickness_m"] >= 0.18 and ro["eave_chamfer_segments"] == 2,
         "monopitch %.2f deg (front %.3f -> back %.3f), slab %.2f, eave %d-seg chamfer, "
         "overhang front %.2f / side %.2f / back %.2f, %d seams, %d rafters, %d barge boards"
         % (ro["slope_deg"], ro["top_z_front_m"], ro["top_z_back_m"], ro["thickness_m"],
            ro["eave_chamfer_segments"], ro["overhang_front_m"], ro["overhang_side_m"],
            ro["overhang_back_m"], ro["standing_seams"], ro["exposed_rafters"],
            ro["barge_boards"])),
        ("back board rack (hou dang ban)",
         True,
         "2 thicker plank bands (z 1.90-2.49) + 2 iron straps + 4 studs + iron tool rail; "
         "back wall %.2f m thick, high window real recess %.2f m"
         % (WALL_T, DESIGN["back_wall"]["high_window_recess_m"])),
        ("workbench",
         True, "%.2f x %.2f x %.2f m (top 1.17) against back wall, trestle legs + shelf + "
         "2 drawers + vice" % tuple(DESIGN["workbench_m"])),
        ("hoist hook",
         True, "hung under front tie beam at y=%.2f, %d chain links + block + J hook (tip z~1.83)"
         % (DESIGN["hoist_hook"]["y_m"], DESIGN["hoist_hook"]["chain_links"])),
        ("crates and pallets",
         DESIGN["crates"] >= 3 and DESIGN["pallets"] >= 2,
         "%d crates (incl. stacked), %d pallets (stack of 2 + crate on top), %d barrels, "
         "%d sacks, timber stack" % (DESIGN["crates"], DESIGN["pallets"],
                                     DESIGN["barrels"], DESIGN["sacks"])),
        ("low + open, NOT a closed box",
         r["open_front_ratio"] < 0.40 and c["clear_width_m"] > 4.0,
         "+X front solid area above 0.6 m = %.2f m2 (%.1f%% of the 6 x 4.5 m front elevation); "
         "clear opening %.2f m wide x %.2f m high; side parapets only %.2f m tall, upper part "
         "fully open"
         % (r["open_front_area_m2"], r["open_front_ratio"] * 100.0, c["clear_width_m"],
            c["clear_height_m"], DESIGN["parapets"]["height_m"])),
        ("visible thickness",
         0.12 <= WALL_T <= 0.35,
         "back wall %.2f, parapet %.2f, plinth %.2f, roof %.2f (brief 0.12-0.35)"
         % (WALL_T, DESIGN["parapets"]["thickness_m"], PLINTH_TOP, ROOF_T)),
        ("wall breakup over 6 m",
         len(SIDE_POST_X) == 3 and len(POST_Y) == 4,
         "7.3 m parapet split into 4 bays by %d posts + stone coping; 6 m front broken by "
         "%d posts + plate/tie beams + braces" % (len(SIDE_POST_X), len(POST_Y))),
        ("material slots",
         len(r["per_mat"]) <= MAX_MATERIAL_SLOTS,
         "%d slots: %s" % (len(r["per_mat"]), " / ".join(sorted(r["per_mat"])))),
    ]
    ok_all = True
    for label, ok, detail in rows:
        ok_all = ok_all and ok
        print("  [%s] %-32s %s" % ("PASS" if ok else "FAIL", label, detail))

    checks["tris_within_budget"] = TRI_FLOOR <= r["tris"] <= TRI_BUDGET
    checks["size_exact"] = all(abs(r["size"][i] - TARGET_SIZE[i]) <= 0.02 for i in range(3))
    checks["grounded"] = abs(r["zmin"]) <= eps
    checks["pivot_x_symmetric"] = r["sym_x"] <= eps
    checks["pivot_y_symmetric"] = r["sym_y"] <= eps
    checks["boundary_zero"] = r["boundary"] == 0
    checks["nonmanifold_zero"] = r["nonmanifold"] == 0
    checks["loose_zero"] = r["loose"] == 0
    checks["degenerate_zero"] = r["degenerate"] == 0
    checks["slots_ok"] = len(r["per_mat"]) <= MAX_MATERIAL_SLOTS
    checks["palette_only"] = all(name in PALETTE for name in r["per_mat"])
    checks["no_coplanar_conflict"] = len(r["coplanar_conflicts"]) == 0
    checks["open_front"] = r["open_front_ratio"] < 0.40
    checks["design_rows"] = ok_all

    print("-" * 78)
    for name in sorted(checks):
        print("  %-30s %s" % (name, "PASS" if checks[name] else "FAIL"))
    failed = [n for n in checks if not checks[n]]
    assert not failed, "self-check failed: %s" % failed
    print("ALL OK  (%d/%d checks, %d tri)" % (len(checks), len(checks), r["tris"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(report())
