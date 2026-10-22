# -*- coding: utf-8 -*-
# @static-doc
# 作用：模型素材库批次 4（M1-1：architecture_kit 扩展 / 可围合基地建筑件）的参数化
# 生成器与 Blender 装配入口。
#
# 6 件模块化资产：SN_Arch_Perimeter_Wall（围墙段）/ Gate（大门门楼）/ Road（道路段）/
# Loading_Platform（装卸平台）/ Warehouse_Variant（仓库变体）/ Workshop_Annex（工坊扩建）。
# 沿用 kit 批次 1–3 的契约：每件 Root + Mount 空节点 + 语义接口（Module_Next/Prev、
# Wall_Top、Gateway、Door_Hinge_L/R、Hoist、Dock_Edge、Stair_Foot、Drive_Shaft、
# Chimney、Coal_Hatch、Sign…），Root extras 写 kit_family / part_role / datum /
# module_x/y / module_grid / base_footprint / envelope / height / tri_budget。
#
# 工单：`tools/modeling/briefs/sn_kit_batch4_architecture_extension.json`
# 约定：1 unit = 1 m；+X 前向、+Z 向上；全部为地面件，根在体量底面中心（zmin=0）。
# 材质：共享贴图 `SN_Tex_*`（本批不新增贴图），见 `sn_kit_materials.py`；
# UV 由 `sn_shared_materials.apply_collection()` 按世界空间盒式投影写入。
# 立面工具（_face_box / _slab / _window / _door / _gable_roof / _chimney / _rivets）
# 直接复用批次 3 生成器，保证与既有 4 栋建筑同一套低模语言。
#
# 用法：
# - Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
# - 纯 Python 干跑：`python tools/modeling/generators/dryrun_kit_batch4.py`
# - 导出 GLB：`python tools/modeling/generators/export_kit_batch4_glb.py`
# @end-static-doc

import math
import os
import sys


def _generator_dir():
    candidates = []
    f = globals().get("__file__")
    if f:
        candidates.append(os.path.dirname(os.path.abspath(f)))
    try:
        import bpy
        fp = getattr(bpy.data, "filepath", "") if getattr(bpy, "data", None) is not None else ""
        if fp:
            d = os.path.dirname(os.path.abspath(fp))
            for _ in range(8):
                cand = os.path.join(d, "tools", "modeling", "generators")
                if os.path.isdir(os.path.join(cand, "ship_parts")):
                    candidates.append(cand)
                    break
                parent = os.path.dirname(d)
                if parent == d:
                    break
                d = parent
    except Exception:
        pass
    candidates.append(os.path.join(os.path.abspath(os.getcwd()),
                                   "tools", "modeling", "generators"))
    for d in candidates:
        if os.path.isdir(os.path.join(d, "ship_parts")):
            return d
    return os.path.abspath(os.path.dirname(candidates[0] if candidates else "."))


GENERATOR_DIR = _generator_dir()
if GENERATOR_DIR not in sys.path:
    sys.path.insert(0, GENERATOR_DIR)

import weapon_kit as wk  # noqa: E402
from ship_parts.core import (  # noqa: E402
    Part,
    bar_between,
    frame_box,
    vadd,
    vnorm,
    vsub,
)

# 立面 / 屋面工具与批次 3 共用，保证同一套铁港建筑语言。
import kit_batch3_generator as b3  # noqa: E402
from kit_batch3_generator import (  # noqa: E402
    _door,
    _face_box,
    _gable_roof,
    _window,
)
from sn_kit_materials import (  # noqa: E402
    ASSET_MATERIALS,
    MAT_BRASS,
    MAT_CANVAS_SHADE,
    MAT_COAL,
    MAT_GLASS_DARK,
    MAT_IRON,
    MAT_IRON_RED,
    MAT_METAL,
    MAT_STONE,
    MAT_WOOD,
    MAT_WOOD_DARK,
    MAT_WOOD_DECK,
    colors_for,
)

ASSETS = [
    "SN_Arch_Perimeter_Wall",
    "SN_Arch_Gate",
    "SN_Arch_Road",
    "SN_Arch_Loading_Platform",
    "SN_Arch_Warehouse_Variant",
    "SN_Arch_Workshop_Annex",
]

# 工作台摆位：批次 3 占用 y=600 / 环境 y=576..580，本批统一 y=640 行。
WORKBENCH_POS = {
    "SN_Arch_Perimeter_Wall": (30.0, 640.0, 0.0),
    "SN_Arch_Gate": (48.0, 640.0, 0.0),
    "SN_Arch_Road": (68.0, 640.0, 0.0),
    "SN_Arch_Loading_Platform": (86.0, 640.0, 0.0),
    "SN_Arch_Warehouse_Variant": (108.0, 640.0, 0.0),
    "SN_Arch_Workshop_Annex": (128.0, 640.0, 0.0),
}

SPECS = {
    "SN_Arch_Perimeter_Wall": {
        "collection": "SN_Arch_Perimeter_Wall_Prototype",
        "prefix": "SN_Arch_Perimeter_Wall_",
        "family": "architecture_kit",
        "role": "perimeter_wall",
        "type": "riveted iron perimeter wall segment with stone plinth",
        "tri_budget": 1600,
        "bbox": (8.30, 1.44, 3.90),
        "tol": 0.15,
        "zmin": 0.0,
        "module": (8.0, 1.2),
        "datum": "ground z=0; 8 m tiling module centred on root; +X module chain",
        "required": ("Plinth", "Posts", "WallBody", "Coping", "Slits", "Lamp"),
        "enclosure": True,
    },
    "SN_Arch_Gate": {
        "collection": "SN_Arch_Gate_Prototype",
        "prefix": "SN_Arch_Gate_",
        "family": "architecture_kit",
        "role": "gate",
        "type": "gatehouse with twin doors, raised portcullis and crenellated parapet",
        "tri_budget": 3400,
        "bbox": (8.40, 2.30, 5.34),
        "tol": 0.20,
        "zmin": 0.0,
        "module": (8.0, 2.2),
        "datum": "ground z=0; gateway centred on root; 8 m tiling module",
        "required": ("Plinth", "Piers", "Lintel", "Doors", "Portcullis",
                     "Threshold", "Lamps"),
        "enclosure": True,
    },
    "SN_Arch_Road": {
        "collection": "SN_Arch_Road_Prototype",
        "prefix": "SN_Arch_Road_",
        "family": "architecture_kit",
        "role": "road",
        "type": "stone paved road tile with twin gutters and kerbs",
        "tri_budget": 1500,
        "bbox": (8.00, 8.00, 0.29),
        "tol": 0.10,
        "zmin": 0.0,
        "module": (8.0, 8.0),
        "datum": "ground z=0; 8x8 m paving tile centred on root",
        "required": ("Base", "Paving", "Gutters", "Kerbs", "Studs"),
        "enclosure": False,
    },
    "SN_Arch_Loading_Platform": {
        "collection": "SN_Arch_Loading_Platform_Prototype",
        "prefix": "SN_Arch_Loading_Platform_",
        "family": "architecture_kit",
        "role": "loading_platform",
        "type": "waterside loading platform with canopy, hoist beam and stairs",
        "tri_budget": 3400,
        "bbox": (10.95, 6.20, 5.25),
        "tol": 0.20,
        "zmin": 0.0,
        "module": (8.0, 6.0),
        "datum": "ground z=0; deck at 1.25 m; +X waterside edge; stairs on -X",
        "required": ("Plinth", "Deck", "Canopy", "HoistBeam", "Stairs",
                     "Bollards"),
        "enclosure": False,
    },
    "SN_Arch_Warehouse_Variant": {
        "collection": "SN_Arch_Warehouse_Variant_Prototype",
        "prefix": "SN_Arch_Warehouse_Variant_",
        "family": "architecture_kit",
        "role": "warehouse_variant",
        "type": "stone lower storey warehouse with timber upper storey and gable hoist",
        "tri_budget": 4600,
        "bbox": (11.80, 8.46, 8.55),
        "tol": 0.25,
        "zmin": 0.0,
        "module": (10.0, 7.0),
        "datum": "ground z=0; body 10x7 centred; +X gable front with loading doors",
        "required": ("Plinth", "StoneWalls", "UpperWalls", "GableRoof",
                     "LoadingDoors", "HoistBeam", "ExternalStair", "Windows"),
        "enclosure": False,
    },
    "SN_Arch_Workshop_Annex": {
        "collection": "SN_Arch_Workshop_Annex_Prototype",
        "prefix": "SN_Arch_Workshop_Annex_",
        "family": "architecture_kit",
        "role": "workshop_annex",
        "type": "boiler house annex with chimney, drive shaft and coal chute",
        "tri_budget": 2900,
        "bbox": (6.61, 5.74, 7.15),
        "tol": 0.20,
        "zmin": 0.0,
        "module": (6.0, 4.0),
        "datum": "ground z=0; body 6x4; drive shaft on +Y wall, chute on -Y",
        "required": ("Plinth", "Walls", "Roof", "Smokestack", "DriveShaft",
                     "CoalChute", "Gauge"),
        "enclosure": False,
    },
}

SOCKETS = {
    "SN_Arch_Perimeter_Wall": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("MODULE_NEXT", "Module_Next", "ROOT", (4.00, 0.0, 0.0)),
        ("MODULE_PREV", "Module_Prev", "ROOT", (-4.00, 0.0, 0.0)),
        ("WALL_TOP", "Wall_Top", "ROOT", (0.0, 0.0, 3.90)),
        ("LANTERN", "Lantern", "ROOT", (3.35, -0.60, 2.52)),
    ],
    "SN_Arch_Gate": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("MODULE_NEXT", "Module_Next", "ROOT", (4.00, 0.0, 0.0)),
        ("MODULE_PREV", "Module_Prev", "ROOT", (-4.00, 0.0, 0.0)),
        ("GATEWAY", "Gateway", "ROOT", (0.0, 0.0, 0.0)),
        ("DOOR_HINGE_L", "Door_Hinge_L", "ROOT", (-1.75, 0.0, 0.0)),
        ("DOOR_HINGE_R", "Door_Hinge_R", "ROOT", (1.75, 0.0, 0.0)),
        ("HOIST", "Hoist", "ROOT", (0.0, 0.0, 4.55)),
        ("SIGN", "Sign", "ROOT", (0.0, -0.78, 4.35)),
    ],
    "SN_Arch_Road": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("MODULE_NEXT", "Module_Next", "ROOT", (4.00, 0.0, 0.06)),
        ("MODULE_PREV", "Module_Prev", "ROOT", (-4.00, 0.0, 0.06)),
        ("MODULE_LEFT", "Module_Left", "ROOT", (0.0, 4.00, 0.06)),
        ("MODULE_RIGHT", "Module_Right", "ROOT", (0.0, -4.00, 0.06)),
    ],
    "SN_Arch_Loading_Platform": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("MODULE_NEXT", "Module_Next", "ROOT", (4.00, 0.0, 0.0)),
        ("MODULE_PREV", "Module_Prev", "ROOT", (-4.00, 0.0, 0.0)),
        ("HOIST", "Hoist", "ROOT", (5.00, 0.0, 4.72)),
        ("DOCK_EDGE", "Dock_Edge", "ROOT", (4.00, 0.0, 1.25)),
        ("STAIR_FOOT", "Stair_Foot", "ROOT", (-5.70, 0.0, 0.0)),
    ],
    "SN_Arch_Warehouse_Variant": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("MODULE_NEXT", "Module_Next", "ROOT", (5.00, 0.0, 0.0)),
        ("MODULE_PREV", "Module_Prev", "ROOT", (-5.00, 0.0, 0.0)),
        ("DOOR_FRONT", "Door_Front", "ROOT", (5.00, 0.0, 0.0)),
        ("HOIST", "Hoist", "ROOT", (6.10, 0.0, 6.10)),
        ("SIGN", "Sign", "ROOT", (5.05, 2.25, 5.15)),
        ("STAIR_FOOT", "Stair_Foot", "ROOT", (-5.00, -4.06, 0.0)),
    ],
    "SN_Arch_Workshop_Annex": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("MODULE_NEXT", "Module_Next", "ROOT", (3.00, 0.0, 0.0)),
        ("MODULE_PREV", "Module_Prev", "ROOT", (-3.00, 0.0, 0.0)),
        ("DRIVE_SHAFT", "Drive_Shaft", "ROOT", (0.0, 2.55, 1.45)),
        ("CHIMNEY", "Chimney", "ROOT", (1.30, -1.00, 7.15)),
        ("COAL_HATCH", "Coal_Hatch", "ROOT", (-0.55, -2.05, 2.10)),
    ],
}


def _sockets(asset):
    prefix = SPECS[asset]["prefix"]
    return [{"key": key, "name": prefix + name, "parent": parent,
             "location": loc} for key, name, parent, loc in SOCKETS[asset]]


# ---------------------------------------------------------------- 通用工具

def _box(part, x0, x1, y0, y1, z0, z1, mat):
    wk.add_box(part, (min(x0, x1), min(y0, y1), min(z0, z1)),
               (max(x0, x1), max(y0, y1), max(z0, z1)), mat)


def _band(part, x0, x1, y0, y1, z0, z1, out, mat):
    """沿体量外轮廓的一圈箍带（z 区间），out = 外扩量。"""
    _box(part, x0 - out, x1 + out, y0 - out, y1 + out, z0, z1, mat)


def _post(part, x, y, half, z0, z1, mat):
    _box(part, x - half, x + half, y - half, y + half, z0, z1, mat)


def _lamp(part, cx, cy, cz, face, mat_arm=MAT_IRON):
    """外挑壁灯：face = 外法线 (nx, ny)。cz 为灯体中心高度。"""
    nx, ny = face
    # 支臂 + 斜撑
    _box(part, cx - 0.06, cx + 0.06, cy - 0.06, cy + 0.06,
         cz + 0.14, cz + 0.20, mat_arm)
    tip = (cx + nx * 0.26, cy + ny * 0.26, cz + 0.17)
    part.add(bar_between((cx, cy, cz + 0.17), tip, 0.05), mat_arm)
    part.add(bar_between((cx, cy, cz - 0.02), tip, 0.035), mat_arm)
    lx, ly = cx + nx * 0.26, cy + ny * 0.26
    # 灯体：黄铜顶盖 + 深色玻璃 + 黄铜底盘 + 顶环
    wk.add_cyl(part, (lx, ly, cz + 0.10), (lx, ly, cz + 0.20),
               0.10, 0.03, MAT_BRASS, 8)
    wk.add_cyl(part, (lx, ly, cz - 0.02), (lx, ly, cz + 0.10),
               0.12, 0.12, MAT_GLASS_DARK, 8)
    wk.add_cyl(part, (lx, ly, cz - 0.10), (lx, ly, cz - 0.02),
               0.04, 0.14, MAT_BRASS, 8)
    wk.add_torus(part, (lx, ly, cz + 0.21), (0.0, 0.0, 1.0), 0.045, 0.016,
                 MAT_BRASS, seg=8, tube=3)


# ---------------------------------------------------------------- 1. 围墙段

def _build_perimeter_wall():
    prefix = "SN_Arch_Perimeter_Wall_"
    parts = {}

    plinth = Part()
    _box(plinth, -4.15, 4.15, -0.65, 0.65, 0.0, 0.42, MAT_STONE)
    for sx in (-1.0, 1.0):
        _box(plinth, sx * 3.70 - 0.38, sx * 3.70 + 0.38, -0.63, 0.63,
             0.0, 0.62, MAT_STONE)
        _box(plinth, sx * 3.70 - 0.30, sx * 3.70 + 0.30, -0.52, 0.52,
             0.62, 0.68, MAT_WOOD_DARK)
    _box(plinth, -0.45, 0.45, -0.60, 0.60, 0.0, 0.56, MAT_STONE)
    _box(plinth, -4.18, 4.18, -0.67, 0.67, 0.42, 0.52, MAT_WOOD_DARK)
    parts[prefix + "Plinth"] = (plinth, "ROOT")

    posts = Part()
    for sx in (-1.0, 1.0):
        px = sx * 3.75
        _post(posts, px, 0.0, 0.17, 0.52, 3.60, MAT_WOOD_DARK)
        for z in (1.15, 2.15, 3.10):
            _box(posts, px - 0.21, px + 0.21, -0.34, 0.34, z - 0.06,
                 z + 0.06, MAT_IRON)
        _box(posts, px - 0.26, px + 0.26, -0.40, 0.40, 3.60, 3.74,
             MAT_METAL)
        wk.add_cyl(posts, (px, 0.0, 3.74), (px, 0.0, 3.90), 0.10, 0.035,
                   MAT_BRASS, 8)
    parts[prefix + "Posts"] = (posts, "ROOT")

    body = Part()
    _box(body, -3.58, 3.58, -0.34, 0.34, 0.52, 3.50, MAT_IRON)
    _box(body, -3.60, 3.60, -0.37, 0.37, 0.52, 1.30, MAT_IRON_RED)
    _box(body, -3.60, 3.60, -0.37, 0.37, 2.28, 2.42, MAT_IRON)
    _box(body, -3.60, 3.60, -0.37, 0.37, 3.38, 3.50, MAT_IRON)
    for x in (-2.40, 0.0, 2.40):
        _box(body, x - 0.09, x + 0.09, -0.37, 0.37, 0.52, 3.50, MAT_METAL)
    for sy in (-1.0, 1.0):
        for z in (0.90, 3.02):
            wk.rivet_row(body, (-3.20, sy * 0.375, z), (3.20, sy * 0.375, z),
                         6, (0.0, sy, 0.0), 0.032, 0.045, MAT_BRASS)
    parts[prefix + "WallBody"] = (body, "ROOT")

    coping = Part()
    _box(coping, -4.10, 4.10, -0.62, 0.62, 3.50, 3.72, MAT_STONE)
    for sy in (-1.0, 1.0):
        _box(coping, -4.10, 4.10, min(sy * 0.62, sy * 0.72),
             max(sy * 0.62, sy * 0.72), 3.58, 3.72, MAT_IRON_RED)
    _box(coping, -4.02, 4.02, -0.50, 0.50, 3.72, 3.80, MAT_IRON)
    for x in (-2.0, 2.0):
        _box(coping, x - 0.16, x + 0.16, -0.52, 0.52, 3.80, 3.84,
             MAT_METAL)
    parts[prefix + "Coping"] = (coping, "ROOT")

    slits = Part()
    for x in (-1.70, 0.0, 1.70):
        for sy in (-1.0, 1.0):
            n = (0.0, sy, 0.0)
            _face_box(slits, (x, sy * 0.34, 2.84), n, (1.0, 0.0, 0.0),
                      0.20, 0.44, 0.05, MAT_GLASS_DARK)
            _face_box(slits, (x, sy * 0.34, 3.08), n, (1.0, 0.0, 0.0),
                      0.30, 0.08, 0.07, MAT_IRON)
            _face_box(slits, (x, sy * 0.34, 2.60), n, (1.0, 0.0, 0.0),
                      0.30, 0.08, 0.07, MAT_IRON)
            for s in (-1.0, 1.0):
                _face_box(slits, (x + s * 0.10, sy * 0.34, 2.84), n,
                          (1.0, 0.0, 0.0), 0.08, 0.44, 0.07, MAT_IRON)
    parts[prefix + "Slits"] = (slits, "ROOT")

    lantern = Part()
    _lamp(lantern, 3.35, -0.34, 2.52, (0.0, -1.0))
    _box(lantern, 3.29, 3.41, -0.40, -0.30, 2.40, 2.70, MAT_IRON)
    parts[prefix + "Lamp"] = (lantern, "ROOT")

    return parts


# ---------------------------------------------------------------- 2. 大门

def _build_gate():
    prefix = "SN_Arch_Gate_"
    parts = {}

    plinth = Part()
    for sx in (-1.0, 1.0):
        _box(plinth, sx * 4.20, sx * 1.85, -1.05, 1.05, 0.0, 0.40,
             MAT_STONE)
        _box(plinth, sx * 4.12, sx * 1.92, -0.98, 0.98, 0.40, 0.52,
             MAT_WOOD_DARK)
    _box(plinth, -1.85, 1.85, -0.95, 0.95, 0.0, 0.14, MAT_STONE)
    _box(plinth, -1.85, 1.85, -0.22, 0.22, 0.14, 0.18, MAT_IRON)
    for sx in (-1.0, 1.0):
        _box(plinth, sx * 3.95 - 0.25, sx * 3.95 + 0.25, -1.05, 1.05, 0.0,
             0.30, MAT_STONE)
    parts[prefix + "Plinth"] = (plinth, "ROOT")

    piers = Part()
    for sx in (-1.0, 1.0):
        x0, x1 = sorted((sx * 1.95, sx * 3.45))
        _box(piers, x0, x1, -0.85, 0.85, 0.40, 4.45, MAT_IRON)
        _box(piers, x0 - 0.03, x1 + 0.03, -0.88, 0.88, 0.40, 1.10,
             MAT_IRON_RED)
        for z in (2.05, 3.30):
            _box(piers, x0 - 0.04, x1 + 0.04, -0.89, 0.89, z - 0.07,
                 z + 0.07, MAT_METAL)
        for cx in (x0, x1):
            for cy in (-0.85, 0.85):
                _post(piers, cx, cy, 0.09, 0.40, 4.45, MAT_METAL)
        _box(piers, x0 - 0.07, x1 + 0.07, -0.95, 0.95, 4.45, 4.70,
             MAT_STONE)
        cx = (x0 + x1) * 0.5
        for s in (-1.0, 1.0):
            _box(piers, cx + s * 0.38 - 0.25, cx + s * 0.38 + 0.25,
                 -0.55, 0.55, 4.70, 5.10, MAT_IRON)
        wk.rivet_row(piers, (x0 + 0.25, -0.90, 2.60), (x1 - 0.25, -0.90, 2.60),
                     5, (0.0, -1.0, 0.0), 0.035, 0.05, MAT_BRASS)
        wk.rivet_row(piers, (x0 + 0.25, 0.90, 2.60), (x1 - 0.25, 0.90, 2.60),
                     5, (0.0, 1.0, 0.0), 0.035, 0.05, MAT_BRASS)
    parts[prefix + "Piers"] = (piers, "ROOT")

    lintel = Part()
    _box(lintel, -1.99, 1.99, -0.50, 0.50, 4.05, 4.55, MAT_IRON)
    _box(lintel, -1.99, 1.99, -0.55, 0.55, 4.12, 4.22, MAT_METAL)
    _box(lintel, -0.24, 0.24, -0.56, 0.56, 4.05, 4.60, MAT_METAL)
    for sx in (-1.0, 1.0):
        x0, x1 = sorted((sx * 1.55, sx * 1.99))
        _box(lintel, x0, x1, -0.52, 0.52, 3.76, 4.05, MAT_IRON)
    _box(lintel, -2.75, 2.75, -0.50, 0.50, 4.70, 4.95, MAT_IRON)
    for x in (-2.30, -1.15, 0.0, 1.15, 2.30):
        _box(lintel, x - 0.23, x + 0.23, -0.50, 0.50, 4.95, 5.34,
             MAT_IRON)
    wk.rivet_row(lintel, (-1.70, -0.56, 4.40), (1.70, -0.56, 4.40), 7,
                 (0.0, -1.0, 0.0), 0.032, 0.05, MAT_BRASS)
    # 门楼铭牌：木牌 + 黄铜边框 + 铁支架
    _box(lintel, -0.78, 0.78, -0.82, -0.74, 4.14, 4.56, MAT_WOOD_DARK)
    _box(lintel, -0.86, 0.86, -0.84, -0.80, 4.10, 4.16, MAT_BRASS)
    _box(lintel, -0.86, 0.86, -0.84, -0.80, 4.54, 4.60, MAT_BRASS)
    for sx in (-1.0, 1.0):
        _box(lintel, sx * 0.72 - 0.05, sx * 0.72 + 0.05, -0.74, -0.46,
             4.20, 4.28, MAT_IRON)
    parts[prefix + "Lintel"] = (lintel, "ROOT")

    doors = Part()
    for sx in (-1.0, 1.0):
        x0, x1 = sorted((sx * 0.02, sx * 1.80))
        _box(doors, x0, x1, -0.09, 0.09, 0.18, 3.62, MAT_WOOD_DARK)
        for z in (0.95, 1.90, 2.85):
            _box(doors, x0 + 0.03, x1 - 0.03, -0.12, 0.12, z - 0.06,
                 z + 0.06, MAT_IRON)
        doors.add(bar_between((x0 + 0.10, -0.12, 0.45),
                              (x1 - 0.10, -0.12, 3.35), 0.075), MAT_IRON)
        wk.rivet_row(doors, (x0 + 0.18, -0.13, 0.55), (x1 - 0.18, -0.13, 3.25),
                     4, (0.0, -1.0, 0.0), 0.028, 0.04, MAT_BRASS)
        hx = sx * 0.25
        wk.add_cyl(doors, (hx, -0.13, 1.52), (hx, -0.22, 1.52), 0.05, 0.05,
                   MAT_BRASS, 6)
        for z in (0.55, 1.85, 3.15):
            _box(doors, sx * 1.74 - 0.07, sx * 1.74 + 0.07, -0.15, 0.15,
                 z - 0.14, z + 0.14, MAT_IRON)
    parts[prefix + "Doors"] = (doors, "ROOT")

    portcullis = Part()
    for x in (-1.50, -0.75, 0.0, 0.75, 1.50):
        _box(portcullis, x - 0.04, x + 0.04, -0.04, 0.04, 3.78, 4.08,
             MAT_IRON)
        wk.add_cyl(portcullis, (x, 0.0, 3.78), (x, 0.0, 3.68), 0.06, 0.012,
                   MAT_METAL, 6)
    for z in (3.84, 4.02):
        _box(portcullis, -1.56, 1.56, -0.04, 0.04, z - 0.04, z + 0.04,
             MAT_IRON)
    for sx in (-1.0, 1.0):
        _box(portcullis, sx * 1.63 - 0.07, sx * 1.63 + 0.07, -0.18, 0.18,
             3.64, 4.12, MAT_METAL)
    parts[prefix + "Portcullis"] = (portcullis, "ROOT")

    threshold = Part()
    for i in range(4):
        x = -1.50 + i * 1.0
        _box(threshold, x - 0.46, x + 0.46, -0.85, 0.85, 0.14, 0.20,
             MAT_STONE)
    _box(threshold, -1.85, 1.85, -0.20, 0.20, 0.18, 0.23, MAT_IRON)
    parts[prefix + "Threshold"] = (threshold, "ROOT")

    lamps = Part()
    for sx in (-1.0, 1.0):
        _lamp(lamps, sx * 2.70, -0.85, 2.90, (0.0, -1.0))
        _box(lamps, sx * 2.70 - 0.08, sx * 2.70 + 0.08, -0.92, -0.80,
             2.76, 3.06, MAT_IRON)
    parts[prefix + "Lamps"] = (lamps, "ROOT")

    return parts


# ---------------------------------------------------------------- 3. 道路段

def _build_road():
    prefix = "SN_Arch_Road_"
    parts = {}

    base = Part()
    _box(base, -4.0, 4.0, -4.0, 4.0, 0.0, 0.08, MAT_STONE)
    parts[prefix + "Base"] = (base, "ROOT")

    paving = Part()
    for ix in range(8):
        for iy in range(8):
            cx = -3.5 + ix
            cy = -3.5 + iy
            h = 0.08 + 0.02 * b3._rnd(ix * 11.0 + iy * 3.7 + 5.0)
            mat = MAT_STONE
            if (ix, iy) in ((1, 1), (6, 2), (2, 6), (5, 5)):
                mat = MAT_IRON_RED
            _box(paving, cx - 0.46, cx + 0.46, cy - 0.46, cy + 0.46, 0.08,
                 0.08 + h, mat)
    parts[prefix + "Paving"] = (paving, "ROOT")

    gutters = Part()
    for sy in (-1.0, 1.0):
        cy = sy * 2.55
        _box(gutters, -3.70, 3.70, cy - 0.14, cy + 0.14, 0.08, 0.105,
             MAT_IRON)
        for i in range(9):
            x = -3.30 + i * 0.825
            _box(gutters, x - 0.05, x + 0.05, cy - 0.13, cy + 0.13, 0.105,
                 0.16, MAT_METAL)
        for sx in (-1.0, 1.0):
            _box(gutters, sx * 3.62 - 0.08, sx * 3.62 + 0.08, cy - 0.16,
                 cy + 0.16, 0.08, 0.16, MAT_IRON)
    parts[prefix + "Gutters"] = (gutters, "ROOT")

    kerbs = Part()
    segments = ((-4.00, -2.02), (-1.98, 0.02), (-0.02, 1.98), (2.02, 4.00))
    for sy in (-1.0, 1.0):
        y0, y1 = sorted((sy * 3.72, sy * 4.00))
        for x0, x1 in segments:
            _box(kerbs, x0, x1, y0, y1, 0.08, 0.26, MAT_STONE)
            _box(kerbs, x0 + 0.08, x1 - 0.08, y0 + 0.02, y1 - 0.02, 0.26,
                 0.29, MAT_IRON)
    parts[prefix + "Kerbs"] = (kerbs, "ROOT")

    studs = Part()
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            wk.add_cyl(studs, (sx * 3.30, sy * 3.30, 0.08),
                       (sx * 3.30, sy * 3.30, 0.17), 0.08, 0.08, MAT_BRASS, 6)
    wk.add_cyl(studs, (0.0, 0.0, 0.08), (0.0, 0.0, 0.17), 0.10, 0.10,
               MAT_BRASS, 8)
    parts[prefix + "Studs"] = (studs, "ROOT")

    return parts


# ---------------------------------------------------------------- 4. 装卸平台

def _build_loading_platform():
    prefix = "SN_Arch_Loading_Platform_"
    parts = {}

    plinth = Part()
    _box(plinth, 3.70, 4.00, -2.75, 2.75, 0.0, 1.10, MAT_STONE)
    _box(plinth, -4.00, -3.70, -2.75, 2.75, 0.0, 1.10, MAT_STONE)
    _box(plinth, -4.00, 4.00, 2.45, 2.75, 0.0, 1.10, MAT_STONE)
    _box(plinth, -4.00, 4.00, -2.75, -2.45, 0.0, 1.10, MAT_STONE)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            _box(plinth, sx * 3.80 - 0.28, sx * 3.80 + 0.28,
                 sy * 2.55 - 0.28, sy * 2.55 + 0.28, 0.0, 1.24,
                 MAT_STONE)
    _box(plinth, -4.02, 4.02, -2.77, 2.77, 0.95, 1.10, MAT_IRON)
    for y in (-2.20, 0.0, 2.20):
        _box(plinth, 4.00, 4.17, y - 0.14, y + 0.14, 0.18, 1.32,
             MAT_WOOD_DARK)
        _box(plinth, 4.00, 4.19, y - 0.16, y + 0.16, 0.88, 1.00, MAT_IRON)
    parts[prefix + "Plinth"] = (plinth, "ROOT")

    deck = Part()
    _box(deck, -4.0, 4.0, -2.75, 2.75, 1.10, 1.19, MAT_WOOD_DECK)
    for cy in (-2.40, -1.70, -1.00, -0.30, 0.40, 1.10, 1.80, 2.50):
        _box(deck, -4.0, 4.0, cy - 0.29, cy + 0.29, 1.19, 1.25,
             MAT_WOOD_DECK)
    for sy in (-1.0, 1.0):
        _box(deck, -4.04, 4.04, sy * 2.75 - 0.12, sy * 2.75 + 0.12, 1.07,
             1.27, MAT_IRON)
    for sx in (-1.0, 1.0):
        _box(deck, sx * 4.0 - 0.12, sx * 4.0 + 0.12, -2.75, 2.75, 1.07,
             1.27, MAT_IRON)
    parts[prefix + "Deck"] = (deck, "ROOT")

    bollards = Part()
    for y in (-2.10, 2.10):
        wk.add_cyl(bollards, (3.75, y, 1.25), (3.75, y, 1.36), 0.18, 0.16,
                   MAT_IRON, 8)
        wk.add_cyl(bollards, (3.75, y, 1.36), (3.75, y, 1.82), 0.13, 0.13,
                   MAT_IRON, 8)
        wk.add_cyl(bollards, (3.75, y, 1.82), (3.75, y, 1.90), 0.18, 0.10,
                   MAT_IRON, 8)
        wk.add_torus(bollards, (3.75, y, 1.68), (0.0, 0.0, 1.0), 0.14, 0.03,
                     MAT_BRASS, seg=10, tube=3)
        wk.add_torus(bollards, (3.95, y, 1.46), (1.0, 0.0, 0.0), 0.09, 0.025,
                     MAT_METAL, seg=8, tube=3)
    parts[prefix + "Bollards"] = (bollards, "ROOT")

    canopy = Part()
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            px, py = sx * 3.40, sy * 2.40
            _box(canopy, px - 0.20, px + 0.20, py - 0.20, py + 0.20, 1.25,
                 1.35, MAT_IRON)
            _box(canopy, px - 0.10, px + 0.10, py - 0.10, py + 0.10, 1.35,
                 4.85, MAT_IRON)
            canopy.add(bar_between((px, py, 4.85 - 0.35),
                                   (px + sx * 0.55, py, 4.85 - 0.35), 0.05),
                       MAT_IRON)
            canopy.add(bar_between((px, py, 4.85 - 0.35),
                                   (px, py + sy * 0.55, 4.85 - 0.35), 0.05),
                       MAT_IRON)
    for sy in (-1.0, 1.0):
        _box(canopy, -3.50, 3.50, sy * 2.40 - 0.07, sy * 2.40 + 0.07, 4.78,
             4.92, MAT_IRON)
    for sx in (-1.0, 1.0):
        _box(canopy, sx * 3.40 - 0.07, sx * 3.40 + 0.07, -2.40, 2.40, 4.78,
             4.92, MAT_IRON)
    for x in (-2.55, -0.85, 0.85, 2.55):
        _box(canopy, x - 0.06, x + 0.06, -3.10, 3.10, 4.92, 5.02,
             MAT_IRON_RED)
    _slab = b3._slab
    _slab(canopy, (-4.30, 0.0, 5.20), (3.55, 0.0, 4.62), (0.0, 1.0, 0.0),
          6.20, 0.10, MAT_IRON_RED)
    for f in (0.25, 0.55, 0.85):
        x = -4.30 + (3.55 + 4.30) * f
        z = 5.20 + (4.62 - 5.20) * f
        _box(canopy, x - 0.05, x + 0.05, -3.08, 3.08, z - 0.05, z + 0.02,
             MAT_IRON)
    _box(canopy, -4.30, 3.55, -3.10, -3.02, 4.56, 4.68, MAT_IRON)
    _box(canopy, -4.30, 3.55, 3.02, 3.10, 4.56, 4.68, MAT_IRON)
    parts[prefix + "Canopy"] = (canopy, "ROOT")

    hoist = Part()
    _box(hoist, 3.30, 5.20, -0.16, 0.16, 5.05, 5.25, MAT_IRON)
    _box(hoist, 3.30, 5.20, -0.22, 0.22, 4.90, 5.05, MAT_IRON)
    for sy in (-1.0, 1.0):
        hoist.add(bar_between((3.40, sy * 0.18, 4.60),
                              (5.00, sy * 0.18, 4.95), 0.07), MAT_IRON)
    _box(hoist, 4.30, 4.66, -0.22, 0.22, 4.70, 4.90, MAT_METAL)
    wk.add_torus(hoist, (5.00, 0.0, 4.72), (0.0, 1.0, 0.0), 0.16, 0.05,
                 MAT_BRASS, seg=10, tube=4)
    wk.add_cyl(hoist, (5.00, 0.0, 4.72), (5.00, 0.0, 2.35), 0.022, 0.022,
               MAT_CANVAS_SHADE, 4)
    _box(hoist, 4.88, 5.12, -0.09, 0.09, 2.18, 2.38, MAT_IRON)
    wk.add_torus(hoist, (5.00, 0.0, 2.06), (0.0, 1.0, 0.0), 0.10, 0.03,
                 MAT_IRON, seg=8, tube=3)
    wk.add_cyl(hoist, (5.00, 0.0, 1.96), (5.00, 0.0, 2.02), 0.05, 0.02,
               MAT_IRON, 6)
    parts[prefix + "HoistBeam"] = (hoist, "ROOT")

    stairs = Part()
    for i in range(5):
        x0 = -5.70 + i * 0.34
        x1 = x0 + 0.34
        top = 0.25 * (i + 1)
        _box(stairs, x0, x1, -0.90, 0.90, 0.0, top - 0.04, MAT_WOOD_DARK)
        _box(stairs, x0, x1, -0.90, 0.90, top - 0.04, top, MAT_IRON)
    for sy in (-1.0, 1.0):
        s = sy * 0.94
        bar = bar_between((-5.70, s, 0.10), (-4.00, s, 1.42), 0.10)
        stairs.add(bar, MAT_IRON)
        for i in range(3):
            t = i / 2.0
            px = -5.70 + 1.70 * t
            pz = 0.10 + 1.32 * t
            _box(stairs, px - 0.04, px + 0.04, s - 0.04, s + 0.04, pz,
                 pz + 0.92, MAT_IRON)
        stairs.add(bar_between((-5.70, s, 1.02), (-4.00, s, 2.34), 0.045),
                   MAT_WOOD_DARK)
    parts[prefix + "Stairs"] = (stairs, "ROOT")

    return parts


# ---------------------------------------------------------------- 5. 仓库变体

def _build_warehouse_variant():
    prefix = "SN_Arch_Warehouse_Variant_"
    parts = {}

    plinth = Part()
    _box(plinth, -5.15, 5.15, -3.65, 3.65, 0.0, 0.55, MAT_STONE)
    _box(plinth, -5.08, 5.08, -3.58, 3.58, 0.55, 0.65, MAT_WOOD_DARK)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            _box(plinth, sx * 4.90 - 0.26, sx * 4.90 + 0.26,
                 sy * 3.40 - 0.26, sy * 3.40 + 0.26, 0.0, 0.72, MAT_STONE)
    for y in (-1.60, 1.60):
        _box(plinth, 5.15, 6.20, y - 0.55, y + 0.55, 0.0, 0.18, MAT_STONE)
    parts[prefix + "Plinth"] = (plinth, "ROOT")

    stone = Part()
    _box(stone, -5.0, 5.0, -3.5, 3.5, 0.65, 3.40, MAT_STONE)
    _box(stone, -5.04, 5.04, -3.54, 3.54, 3.28, 3.48, MAT_IRON)
    for sx in (-1.0, 1.0):
        for y in (-3.5, -1.75, 0.0, 1.75, 3.5):
            _box(stone, sx * 5.0 - 0.10, sx * 5.0 + 0.10, y - 0.13, y + 0.13,
                 0.65, 3.40, MAT_STONE)
    for sy in (-1.0, 1.0):
        for x in (-3.75, -1.25, 1.25, 3.75):
            _box(stone, x - 0.13, x + 0.13, sy * 3.5 - 0.10,
                 sy * 3.5 + 0.10, 0.65, 3.40, MAT_STONE)
    wk.rivet_row(stone, (-4.60, -3.56, 1.30), (4.60, -3.56, 1.30), 11,
                 (0.0, -1.0, 0.0), 0.035, 0.05, MAT_BRASS)
    wk.rivet_row(stone, (-4.60, 3.56, 1.30), (4.60, 3.56, 1.30), 11,
                 (0.0, 1.0, 0.0), 0.035, 0.05, MAT_BRASS)
    parts[prefix + "StoneWalls"] = (stone, "ROOT")

    upper = Part()
    _box(upper, -5.0, 5.0, -3.5, 3.5, 3.48, 6.20, MAT_WOOD_DARK)
    for sy in (-1.0, 1.0):
        y = sy * 3.5
        for x in (-4.55, -3.15, -1.75, -0.35, 1.05, 2.45, 3.85):
            _box(upper, x - 0.10, x + 0.10, y - 0.08, y + 0.08, 3.48, 6.20,
                 MAT_WOOD)
        _box(upper, -5.0, 5.0, y - 0.07, y + 0.07, 4.80, 4.96, MAT_WOOD)
        _box(upper, -5.0, 5.0, y - 0.07, y + 0.07, 3.48, 3.62, MAT_WOOD)
        for x in (-3.85, -2.45, -1.05, 0.35, 1.75, 3.15):
            upper.add(bar_between((x - 0.55, y - 0.09, 3.62),
                                  (x + 0.55, y - 0.09, 4.80), 0.06),
                      MAT_IRON)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            _post(upper, sx * 5.0, sy * 3.5, 0.14, 3.48, 6.20, MAT_IRON)
    parts[prefix + "UpperWalls"] = (upper, "ROOT")

    roof = Part()
    b3._gable_roof(roof, -5.40, 5.40, 3.80, 6.20, 8.10, 0.13,
                   MAT_IRON_RED, MAT_IRON, MAT_WOOD_DARK, -5.0, 5.0)
    _box(roof, -0.75, 0.75, -0.65, 0.65, 8.05, 8.35, MAT_WOOD_DARK)
    for sy in (-1.0, 1.0):
        _box(roof, -0.80, 0.80, min(sy * 0.65, sy * 0.72),
             max(sy * 0.65, sy * 0.72), 8.10, 8.32, MAT_IRON)
    _box(roof, -0.90, 0.90, -0.80, 0.80, 8.35, 8.45, MAT_IRON)
    _box(roof, -0.20, 0.20, -0.20, 0.20, 8.45, 8.55, MAT_BRASS)
    parts[prefix + "GableRoof"] = (roof, "ROOT")

    doors = Part()
    # 正立面（+X 山墙）双扇装载门：门扇在 YZ 平面，x 5.00..5.10
    for s in (-1.0, 1.0):
        y0, y1 = sorted((s * 0.02, s * 1.74))
        _box(doors, 5.00, 5.10, y0, y1, 0.65, 3.80, MAT_WOOD_DARK)
        for z in (1.30, 2.25, 3.20):
            _box(doors, 5.10, 5.15, y0 + 0.03, y1 - 0.03, z - 0.07,
                 z + 0.07, MAT_IRON)
        doors.add(bar_between((5.12, y0 + 0.12, 0.92),
                              (5.12, y1 - 0.12, 3.52), 0.07), MAT_IRON)
        doors.add(bar_between((5.12, y1 - 0.12, 0.92),
                              (5.12, y0 + 0.12, 3.52), 0.07), MAT_IRON)
        for z in (0.98, 2.24, 3.50):
            _box(doors, 5.06, 5.13, s * 1.72 - 0.09, s * 1.72 + 0.09,
                 z - 0.13, z + 0.13, MAT_IRON)
    _box(doors, 4.96, 5.16, -1.92, -1.78, 0.65, 3.92, MAT_IRON)
    _box(doors, 4.96, 5.16, 1.78, 1.92, 0.65, 3.92, MAT_IRON)
    _box(doors, 4.96, 5.16, -1.92, 1.92, 3.80, 4.02, MAT_IRON)
    _box(doors, 5.16, 5.22, -1.84, 1.84, 3.86, 3.96, MAT_BRASS)
    # 山墙上层吊货门（YZ 平面）
    _box(doors, 4.98, 5.06, -1.10, 1.10, 4.55, 6.02, MAT_WOOD_DARK)
    _box(doors, 5.06, 5.12, -1.20, 1.20, 6.02, 6.12, MAT_IRON)
    _box(doors, 5.06, 5.12, -1.20, 1.20, 4.45, 4.55, MAT_IRON)
    for s in (-1.0, 1.0):
        _box(doors, 5.06, 5.12, s * 1.12 - 0.08, s * 1.12 + 0.08, 4.45,
             6.12, MAT_IRON)
    # 上层侧门（-Y 墙，接外楼梯平台 z=3.48；门宽落在平台面内）
    _box(doors, -1.06, 0.04, -3.54, -3.46, 3.48, 5.00, MAT_WOOD_DARK)
    _box(doors, -1.14, 0.12, -3.56, -3.44, 5.00, 5.10, MAT_IRON)
    for x in (-1.14, 0.04):
        _box(doors, x, x + 0.08, -3.56, -3.44, 3.48, 5.00, MAT_IRON)
    _box(doors, -0.98, -0.04, -3.58, -3.44, 3.80, 3.90, MAT_IRON)
    _box(doors, -0.98, -0.04, -3.58, -3.44, 4.60, 4.70, MAT_IRON)
    wk.add_cyl(doors, (-0.12, -3.58, 4.22), (-0.12, -3.67, 4.22), 0.05, 0.05,
               MAT_BRASS, 6)
    parts[prefix + "LoadingDoors"] = (doors, "ROOT")

    hoist = Part()
    _box(hoist, 5.00, 6.40, -0.15, 0.15, 6.42, 6.60, MAT_IRON)
    _box(hoist, 5.00, 6.40, -0.20, 0.20, 6.28, 6.42, MAT_IRON)
    for sy in (-1.0, 1.0):
        hoist.add(bar_between((5.10, sy * 0.18, 5.50),
                              (6.20, sy * 0.18, 6.30), 0.07), MAT_IRON)
    _box(hoist, 5.72, 6.05, -0.20, 0.20, 6.05, 6.28, MAT_METAL)
    wk.add_torus(hoist, (6.10, 0.0, 6.10), (0.0, 1.0, 0.0), 0.15, 0.045,
                 MAT_BRASS, seg=10, tube=4)
    wk.add_cyl(hoist, (6.10, 0.0, 6.10), (6.10, 0.0, 4.62), 0.022, 0.022,
               MAT_CANVAS_SHADE, 4)
    _box(hoist, 5.98, 6.22, -0.08, 0.08, 4.48, 4.66, MAT_IRON)
    wk.add_torus(hoist, (6.10, 0.0, 4.36), (0.0, 1.0, 0.0), 0.09, 0.028,
                 MAT_IRON, seg=8, tube=3)
    parts[prefix + "HoistBeam"] = (hoist, "ROOT")

    stair = Part()
    steps = 14
    rise = 3.48 / steps
    run = 4.20 / steps
    for i in range(steps):
        x0 = -5.00 + i * run
        x1 = x0 + run
        top = rise * (i + 1)
        _box(stair, x0, x1, -4.60, -3.52, 0.0, top - 0.04, MAT_WOOD_DARK)
        _box(stair, x0, x1, -4.60, -3.52, top - 0.04, top, MAT_IRON)
    # 上层平台（实心支撑到地，兼作楼梯落地端；顶面与最后一级踏面同高 3.48）
    _box(stair, -1.16, 0.04, -4.60, -3.52, 0.0, 3.48, MAT_WOOD_DARK)
    for y in (-4.64, -3.50):
        stair.add(bar_between((-5.00, y, 0.10), (-0.80, y, 3.58), 0.09),
                  MAT_IRON)
        for i in range(5):
            t = i / 4.0
            px = -5.00 + 4.20 * t
            pz = 0.10 + 3.48 * t
            _box(stair, px - 0.04, px + 0.04, y - 0.04, y + 0.04, pz,
                 pz + 0.96, MAT_IRON)
        stair.add(bar_between((-5.00, y, 1.06), (-0.80, y, 4.54), 0.045),
                  MAT_WOOD_DARK)
    parts[prefix + "ExternalStair"] = (stair, "ROOT")

    windows = Part()
    sign_y = 2.25
    for sy in (-1.0, 1.0):
        y = sy * 3.5
        for x in (-3.60, -1.80, 0.0, 1.80, 3.60):
            _window(windows, (x, y, 2.20), (0.0, sy, 0.0), (1.0, 0.0, 0.0),
                    1.05, 1.55, frame=MAT_IRON)
            _box(windows, x - 0.62, x + 0.62, y - 0.10, y + 0.10, 2.98,
                 3.06, MAT_STONE)
        for x in (-3.60, 0.0, 3.60):
            _window(windows, (x, y, 4.20), (0.0, sy, 0.0), (1.0, 0.0, 0.0),
                    0.90, 0.95, frame=MAT_IRON)
    for sy in (-1.0, 1.0):
        _window(windows, (5.0, sy * 2.20, 2.20), (1.0, 0.0, 0.0),
                (0.0, 1.0, 0.0), 1.05, 1.55, frame=MAT_IRON)
        _box(windows, 5.0, 5.10, sy * 2.20 - 0.62, sy * 2.20 + 0.62, 2.98,
             3.06, MAT_STONE)
    # 招牌：木牌 + 黄铜边框（+X 上层立面）
    _box(windows, 5.02, 5.10, sign_y - 0.75, sign_y + 0.75, 4.78, 5.48,
         MAT_WOOD_DARK)
    _box(windows, 5.10, 5.14, sign_y - 0.82, sign_y + 0.82, 4.72, 4.80,
         MAT_BRASS)
    _box(windows, 5.10, 5.14, sign_y - 0.82, sign_y + 0.82, 5.46, 5.54,
         MAT_BRASS)
    parts[prefix + "Windows"] = (windows, "ROOT")

    return parts


# ---------------------------------------------------------------- 6. 工坊扩建

def _build_workshop_annex():
    prefix = "SN_Arch_Workshop_Annex_"
    parts = {}

    plinth = Part()
    _box(plinth, -3.10, 3.10, -2.10, 2.10, 0.0, 0.35, MAT_STONE)
    _box(plinth, -3.04, 3.04, -2.04, 2.04, 0.35, 0.42, MAT_WOOD_DARK)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            _box(plinth, sx * 2.95 - 0.22, sx * 2.95 + 0.22,
                 sy * 1.95 - 0.22, sy * 1.95 + 0.22, 0.0, 0.50, MAT_STONE)
    parts[prefix + "Plinth"] = (plinth, "ROOT")

    walls = Part()
    _box(walls, -3.0, 3.0, -2.0, 2.0, 0.42, 4.30, MAT_IRON)
    _box(walls, -3.03, 3.03, -2.03, 2.03, 0.42, 1.10, MAT_IRON_RED)
    for z in (2.15, 3.55):
        _box(walls, -3.04, 3.04, -2.04, 2.04, z - 0.06, z + 0.06, MAT_METAL)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            _post(walls, sx * 3.0, sy * 2.0, 0.10, 0.42, 4.30, MAT_METAL)
    for x in (-1.6, 0.6):
        _box(walls, x - 0.09, x + 0.09, -2.04, -1.98, 0.42, 4.30, MAT_IRON)
    wk.rivet_row(walls, (-2.80, 2.05, 2.30), (2.80, 2.05, 2.30), 8,
                 (0.0, 1.0, 0.0), 0.032, 0.045, MAT_BRASS)
    wk.rivet_row(walls, (-2.80, -2.05, 2.30), (2.80, -2.05, 2.30), 8,
                 (0.0, -1.0, 0.0), 0.032, 0.045, MAT_BRASS)
    # 前门 + 窗
    _door(walls, (3.0, 0.70, 1.55), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0),
          1.15, 2.20, MAT_WOOD_DARK, MAT_IRON, brace=MAT_IRON_RED)
    _window(walls, (-2.05, -2.0, 2.95), (0.0, -1.0, 0.0), (1.0, 0.0, 0.0),
            1.10, 1.10, frame=MAT_IRON)
    _window(walls, (1.85, 2.0, 2.95), (0.0, 1.0, 0.0), (1.0, 0.0, 0.0),
            1.10, 1.10, frame=MAT_IRON)
    _window(walls, (-3.0, 0.0, 2.95), (-1.0, 0.0, 0.0), (0.0, 1.0, 0.0),
            0.95, 1.00, frame=MAT_IRON)
    parts[prefix + "Walls"] = (walls, "ROOT")

    roof = Part()
    b3._gable_roof(roof, -3.30, 3.30, 2.10, 4.30, 5.30, 0.12,
                   MAT_IRON_RED, MAT_IRON, MAT_WOOD_DARK, -3.0, 3.0)
    _box(roof, -0.55, 0.55, -0.45, 0.45, 5.20, 5.55, MAT_IRON)
    for sy in (-1.0, 1.0):
        _box(roof, -0.60, 0.60, min(sy * 0.45, sy * 0.52),
             max(sy * 0.45, sy * 0.52), 5.25, 5.50, MAT_IRON)
    parts[prefix + "Roof"] = (roof, "ROOT")

    chimney = Part()
    _box(chimney, 0.82, 1.78, -1.48, -0.52, 4.55, 6.70, MAT_STONE)
    for z in (5.30, 5.90, 6.45):
        _box(chimney, 0.76, 1.84, -1.54, -0.46, z - 0.07, z + 0.07,
             MAT_IRON)
    _box(chimney, 0.72, 1.88, -1.58, -0.42, 6.70, 6.92, MAT_IRON)
    wk.add_cyl(chimney, (1.30, -1.00, 6.92), (1.30, -1.00, 7.15), 0.42, 0.30,
               MAT_METAL, 10)
    # 汽管：从烟囱根弯进墙体
    wk.add_cyl(chimney, (1.30, -1.00, 4.55), (1.30, -1.00, 3.55), 0.14, 0.14,
               MAT_IRON, 8)
    wk.add_cyl(chimney, (1.30, -1.00, 3.55), (1.30, -2.00, 3.55), 0.14, 0.14,
               MAT_IRON, 8)
    wk.add_torus(chimney, (1.30, -1.00, 3.55), (1.0, 0.0, 0.0), 0.14, 0.035,
                 MAT_BRASS, seg=8, tube=3)
    parts[prefix + "Smokestack"] = (chimney, "ROOT")

    shaft = Part()
    _box(shaft, -0.55, 0.55, 1.98, 2.16, 0.42, 0.80, MAT_IRON)
    for sx in (-1.0, 1.0):
        shaft.add(bar_between((sx * 0.42, 2.16, 0.70),
                              (-0.10, 2.16, 1.32), 0.07), MAT_IRON)
    _box(shaft, -0.34, 0.34, 2.14, 2.42, 1.12, 1.78, MAT_METAL)
    wk.add_cyl(shaft, (0.0, 1.98, 1.45), (0.0, 2.58, 1.45), 0.10, 0.10,
               MAT_METAL, 8)
    wk.add_cyl(shaft, (0.0, 2.44, 1.45), (0.0, 2.58, 1.45), 0.20, 0.20,
               MAT_IRON, 8)
    wk.add_torus(shaft, (0.0, 2.36, 1.45), (0.0, 1.0, 0.0), 0.32, 0.055,
                 MAT_BRASS, seg=12, tube=4)
    for i in range(6):
        a = 2.0 * math.pi * i / 6.0
        wk.add_bolt(shaft, (0.20 * math.cos(a), 2.40,
                            1.45 + 0.20 * math.sin(a)),
                    0.035, 0.06, MAT_BRASS, axis=(0.0, 1.0, 0.0))
    _box(shaft, -0.46, 0.46, 2.06, 2.10, 1.80, 2.02, MAT_IRON)
    parts[prefix + "DriveShaft"] = (shaft, "ROOT")

    chute = Part()
    _slab = b3._slab
    _slab(chute, (-0.55, -2.02, 2.06), (-0.55, -3.05, 0.12),
          (1.0, 0.0, 0.0), 0.86, 0.09, MAT_IRON_RED)
    for s in (-1.0, 1.0):
        x = -0.55 + s * 0.45
        _slab(chute, (x, -2.02, 2.12), (x, -3.05, 0.18),
              (1.0, 0.0, 0.0), 0.07, 0.24, MAT_IRON)
    # 送煤口：框 + 翻板 + 铰链
    _box(chute, -1.05, -0.05, -2.10, -2.00, 1.82, 2.38, MAT_IRON)
    _box(chute, -0.98, -0.12, -2.16, -2.08, 1.90, 2.30, MAT_WOOD_DARK)
    wk.add_torus(chute, (-1.00, -2.12, 2.30), (0.0, 1.0, 0.0), 0.045, 0.015,
                 MAT_BRASS, seg=6, tube=3)
    # 槽脚煤堆
    for i, (x0, x1, z1) in enumerate(((-1.10, 0.05, 0.30),
                                      (-0.95, -0.10, 0.42),
                                      (-0.80, -0.20, 0.22))):
        _box(chute, x0, x1, -3.05, -2.35, 0.0, z1, MAT_COAL)
    parts[prefix + "CoalChute"] = (chute, "ROOT")

    gauge = Part()
    # 压力表：黄铜表壳 + 深色表面 + 指针
    wk.add_cyl(gauge, (3.02, -0.55, 2.60), (3.16, -0.55, 2.60), 0.22, 0.22,
               MAT_BRASS, 10)
    wk.add_cyl(gauge, (3.16, -0.55, 2.60), (3.18, -0.55, 2.60), 0.18, 0.18,
               MAT_GLASS_DARK, 10)
    _box(gauge, 3.17, 3.20, -0.56, -0.54, 2.60, 2.72, MAT_GLASS_DARK)
    _box(gauge, 3.10, 3.13, -0.66, -0.44, 2.38, 2.42, MAT_IRON)
    # 蒸汽管 + 阀门
    wk.add_cyl(gauge, (3.0, -1.30, 1.85), (3.14, -1.30, 1.85), 0.07, 0.07,
               MAT_IRON, 6)
    wk.add_cyl(gauge, (3.14, -1.30, 1.85), (3.14, -1.30, 3.55), 0.07, 0.07,
               MAT_IRON, 6)
    wk.add_cyl(gauge, (3.14, -1.30, 3.55), (3.0, -1.30, 3.55), 0.07, 0.07,
               MAT_IRON, 6)
    wk.add_torus(gauge, (3.14, -1.30, 2.30), (0.0, 0.0, 1.0), 0.13, 0.035,
                 MAT_BRASS, seg=8, tube=3)
    wk.add_cyl(gauge, (3.14, -1.30, 2.30), (3.14, -1.30, 2.55), 0.035, 0.035,
               MAT_BRASS, 5)
    parts[prefix + "Gauge"] = (gauge, "ROOT")

    return parts


# ---------------------------------------------------------------- 装配配置

BUILDERS = {
    "SN_Arch_Perimeter_Wall": _build_perimeter_wall,
    "SN_Arch_Gate": _build_gate,
    "SN_Arch_Road": _build_road,
    "SN_Arch_Loading_Platform": _build_loading_platform,
    "SN_Arch_Warehouse_Variant": _build_warehouse_variant,
    "SN_Arch_Workshop_Annex": _build_workshop_annex,
}


def build_geometry(asset):
    """纯 Python：返回 {对象名: (Part, 父级 key)}；不 import bpy。"""
    return BUILDERS[asset]()


def build_config(asset, origin=None):
    from ship_parts.assembly import BuildConfig, PivotSpec

    spec = SPECS[asset]
    prefix = spec["prefix"]
    sockets = _sockets(asset)
    pivots = [PivotSpec(s["key"], s["name"], s["location"],
                        parent=s["parent"]) for s in sockets]
    origins = {s["key"]: s["location"] for s in sockets}
    pos = origin if origin is not None else WORKBENCH_POS[asset]
    footprint = spec.get("module") or (spec["bbox"][0], spec["bbox"][1])
    root_props = {
        "asset": asset,
        "version": "1.0",
        "units": "metres",
        "kit_family": spec["family"],
        "part_role": spec["role"],
        "forward": "+X",
        "up": "+Z",
        "datum": spec["datum"],
        "mount_frame": "%sMount at origin" % prefix,
        "base_footprint_x": float(footprint[0]),
        "base_footprint_y": float(footprint[1]),
        "envelope_x": float(spec["bbox"][0]),
        "envelope_y": float(spec["bbox"][1]),
        "height": float(spec["bbox"][2]),
        "tri_budget": spec["tri_budget"],
        "bbox_target": "%.2f x %.2f x %.2f m" % spec["bbox"],
        "collection": spec["collection"],
        "type": spec["type"],
        "module_grid": 4.0,
        "enclosure": bool(spec.get("enclosure", False)),
    }
    if "module" in spec:
        root_props["module_x"] = float(spec["module"][0])
        root_props["module_y"] = float(spec["module"][1])
    return BuildConfig(
        collection=spec["collection"],
        prefix=prefix,
        root_name=prefix + "Root",
        workbench_pos=pos,
        material_colors=colors_for(asset),
        material_reuse=colors_for(asset),
        root_props=root_props,
        pivots=pivots,
        origins=origins,
        report_title=asset,
        tri_budget=spec["tri_budget"],
        root_size=1.0,
    )


def build_all_kits():
    from ship_parts import assembly
    import sn_shared_materials as shared

    collections = []
    for asset in ASSETS:
        collection = assembly.build_collection(build_geometry(asset),
                                               build_config(asset))
        materials = shared.apply_collection(collection)
        if materials["failures"]:
            raise RuntimeError("%s shared material apply failed: %r" % (
                asset, materials["failures"]))
        collections.append(collection)
        print("TEXTURED %s: %d objects / %d materials / uv loops=%d" % (
            collection.name, materials["objects"],
            len(materials["materials"]), materials["uv_loops"]))
    return collections


def report(verbose=True):
    import bpy
    from ship_parts import assembly
    import sn_shared_materials as shared

    out = {}
    for asset in ASSETS:
        cfg = build_config(asset)
        info = assembly.report(cfg, verbose=verbose)
        verification = shared.verify_collection(
            bpy.data.collections[cfg.collection])
        print("SHARED TEXTURE CHECK %s: %s (%d meshes, %d failures)" % (
            asset, "PASS" if verification["ok"] else "FAIL",
            verification["meshes"], len(verification["failures"])))
        for failure in verification["failures"]:
            print("  - " + failure)
        info["textures"] = verification
        out[asset] = info
        if not verification["ok"]:
            raise RuntimeError("%s shared material verification failed" % asset)
        if info["tris"] > cfg.tri_budget:
            raise RuntimeError("%s over tri budget: %d > %d" % (
                asset, info["tris"], cfg.tri_budget))
    print("KIT_BATCH4_REPORT %r" % {
        "assets": {asset: out[asset]["tris"] for asset in ASSETS},
        "total_tris": sum(v["tris"] for v in out.values()),
    })
    return out


if __name__ == "__main__":
    build_all_kits()
    report()
