# -*- coding: utf-8 -*-
# @static-doc
# 作用：模型素材库批次 5（M1-2：`base_kit` 基地生产建筑）的参数化生成器与 Blender
# 装配入口。
#
# 5 件模块化资产：SN_Base_Sawmill（锯木厂）/ Smelter（冶炼炉）/ Foundry（铸造车间）/
# Stockyard（仓库堆场）/ Defense_Tower（防御塔）。沿用批次 1–4 的契约：每件 Root +
# Mount 空节点 + 语义接口（Module_Next/Prev、Drive_Shaft、Log_Input、Timber_Output、
# Coal/Ore_Input、Molten_In/Out、Pour_Point、Hoist、Scale、Storage、Gate_In、
# Weapon_Mount、Searchlight、Flag、Magazine、Ladder_Foot、Chimney），Root extras 写
# kit_family / part_role / datum / module_x/y / module_grid / production / 体量预算。
#
# 工单：`tools/modeling/briefs/sn_kit_batch5_base_kit.json`
# 约定：1 unit = 1 m；+X 前向、+Z 向上；全部为地面件，根在体量底面中心（zmin=0）。
# 材质：共享贴图 `SN_Tex_*`（本批不新增贴图），UV 由
# `sn_shared_materials.apply_collection()` 按世界空间盒式投影写入。
# 立面 / 屋顶工具复用批次 3，基础盒体 / 壁灯复用批次 4，保证与既有 kit 同一语言。
#
# 用法：
# - Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
# - 纯 Python 干跑：`python tools/modeling/generators/dryrun_kit_batch5.py`
# - 导出 GLB：`python tools/modeling/generators/export_kit_batch5_glb.py`
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
    taper_cyl,
)

import kit_batch4_generator as b4  # noqa: E402
from kit_batch3_generator import (  # noqa: E402
    _chimney,
    _door,
    _face_box,
    _gable_roof,
    _rnd,
    _slab,
    _tri_prism,
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
    "SN_Base_Sawmill",
    "SN_Base_Smelter",
    "SN_Base_Foundry",
    "SN_Base_Stockyard",
    "SN_Base_Defense_Tower",
]

# 工作台摆位：批次 4 占用 y=640，本批统一 y=660 行。
WORKBENCH_POS = {
    "SN_Base_Sawmill": (30.0, 660.0, 0.0),
    "SN_Base_Smelter": (50.0, 660.0, 0.0),
    "SN_Base_Foundry": (74.0, 660.0, 0.0),
    "SN_Base_Stockyard": (100.0, 660.0, 0.0),
    "SN_Base_Defense_Tower": (122.0, 660.0, 0.0),
}

SPECS = {
    "SN_Base_Sawmill": {
        "collection": "SN_Base_Sawmill_Prototype",
        "prefix": "SN_Base_Sawmill_",
        "family": "base_kit",
        "role": "sawmill",
        "type": "open-sided saw shed with blade, log ramp and timber stack",
        "tri_budget": 3800,
        "bbox": (11.30, 7.54, 6.05),
        "tol": 0.25,
        "zmin": 0.0,
        "module": (8.0, 6.0),
        "production": True,
        "datum": "ground z=0; body 8x6; +X log ramp, -Y timber output, +Y drive shaft",
        "required": ("Plinth", "Walls", "Roof", "SawBlade", "Carriage",
                     "LogRamp", "TimberStack", "DriveShaft"),
    },
    "SN_Base_Smelter": {
        "collection": "SN_Base_Smelter_Prototype",
        "prefix": "SN_Base_Smelter_",
        "family": "base_kit",
        "role": "smelter",
        "type": "stone blast furnace with stoves, bins, skip hoist and chimney",
        "tri_budget": 4000,
        "bbox": (9.10, 7.72, 11.40),
        "tol": 0.30,
        "zmin": 0.0,
        "module": (8.0, 6.0),
        "production": True,
        "datum": "ground z=0; furnace axis at origin; +X taphole; -X bins; chimney at top",
        "required": ("Plinth", "Furnace", "Bands", "ChargingPlatform", "Stoves",
                     "Bins", "SkipHoist", "Stack"),
    },
    "SN_Base_Foundry": {
        "collection": "SN_Base_Foundry_Prototype",
        "prefix": "SN_Base_Foundry_",
        "family": "base_kit",
        "role": "foundry",
        "type": "foundry hall with cupola, travelling crane, ladle and mould floor",
        "tri_budget": 4600,
        "bbox": (12.95, 8.55, 9.15),
        "tol": 0.30,
        "zmin": 0.0,
        "module": (12.0, 8.0),
        "production": True,
        "datum": "ground z=0; body 12x8; +X sliding doors; cupola and chimney on -Y bay",
        "required": ("Plinth", "Walls", "Roof", "SlidingDoors", "Cupola",
                     "CraneRail", "Ladle", "MoldFloor"),
    },
    "SN_Base_Stockyard": {
        "collection": "SN_Base_Stockyard_Prototype",
        "prefix": "SN_Base_Stockyard_",
        "family": "base_kit",
        "role": "stockyard",
        "type": "fenced stockyard with stacks, gantry crane, weighbridge and hut",
        "tri_budget": 3600,
        "bbox": (13.20, 11.10, 6.20),
        "tol": 0.30,
        "zmin": 0.0,
        "module": (12.0, 10.0),
        "production": True,
        "datum": "ground z=0; 12x10 paved yard; gate on +X; gantry across Y",
        "required": ("Base", "Fence", "Gate", "Stacks", "Gantry",
                     "Weighbridge", "Hut"),
    },
    "SN_Base_Defense_Tower": {
        "collection": "SN_Base_Defense_Tower_Prototype",
        "prefix": "SN_Base_Defense_Tower_",
        "family": "base_kit",
        "role": "defense_tower",
        "type": "tapered stone defense tower with gun platform and magazine",
        "tri_budget": 3400,
        "bbox": (7.50, 7.27, 12.25),
        "tol": 0.30,
        "zmin": 0.0,
        "module": (6.0, 6.0),
        "production": False,
        "datum": "ground z=0; tower centred; gun platform 9.2 m; magazine on -Y; ladder -Y",
        "required": ("Plinth", "Tower", "Parapet", "WeaponPlatform",
                     "PowderStore", "Ladder", "Flagpole"),
    },
}

SOCKETS = {
    "SN_Base_Sawmill": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("MODULE_NEXT", "Module_Next", "ROOT", (4.00, 0.0, 0.0)),
        ("MODULE_PREV", "Module_Prev", "ROOT", (-4.00, 0.0, 0.0)),
        ("DRIVE_SHAFT", "Drive_Shaft", "ROOT", (0.0, 3.20, 1.45)),
        ("LOG_INPUT", "Log_Input", "ROOT", (6.80, 2.00, 0.0)),
        ("TIMBER_OUTPUT", "Timber_Output", "ROOT", (5.60, -2.00, 0.60)),
    ],
    "SN_Base_Smelter": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("MODULE_NEXT", "Module_Next", "ROOT", (4.00, 0.0, 0.0)),
        ("MODULE_PREV", "Module_Prev", "ROOT", (-4.00, 0.0, 0.0)),
        ("COAL_INPUT", "Coal_Input", "ROOT", (-4.35, 2.40, 1.00)),
        ("ORE_INPUT", "Ore_Input", "ROOT", (-4.35, -2.40, 1.00)),
        ("MOLTEN_OUT", "Molten_Out", "ROOT", (3.40, 0.0, 0.70)),
        ("BLOWER_SHAFT", "Blower_Shaft", "ROOT", (0.0, 3.40, 1.25)),
        ("CHIMNEY", "Chimney", "ROOT", (1.80, -1.60, 11.40)),
    ],
    "SN_Base_Foundry": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("MODULE_NEXT", "Module_Next", "ROOT", (6.00, 0.0, 0.0)),
        ("MODULE_PREV", "Module_Prev", "ROOT", (-6.00, 0.0, 0.0)),
        ("DOOR_FRONT", "Door_Front", "ROOT", (6.00, 0.0, 0.0)),
        ("HOIST", "Hoist", "ROOT", (3.60, 0.0, 6.10)),
        ("MOLTEN_IN", "Molten_In", "ROOT", (-3.40, 0.0, 1.10)),
        ("POUR_POINT", "Pour_Point", "ROOT", (1.60, 0.0, 1.10)),
        ("CHIMNEY", "Chimney", "ROOT", (-3.60, -2.40, 9.15)),
    ],
    "SN_Base_Stockyard": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("MODULE_NEXT", "Module_Next", "ROOT", (6.00, 0.0, 0.0)),
        ("MODULE_PREV", "Module_Prev", "ROOT", (-6.00, 0.0, 0.0)),
        ("GATE_IN", "Gate_In", "ROOT", (6.00, 0.0, 0.0)),
        ("HOIST", "Hoist", "ROOT", (-2.00, 0.0, 5.55)),
        ("SCALE", "Scale", "ROOT", (4.20, 0.0, 0.30)),
        ("STORAGE", "Storage", "ROOT", (0.0, -2.60, 0.0)),
    ],
    "SN_Base_Defense_Tower": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("MODULE_NEXT", "Module_Next", "ROOT", (3.00, 0.0, 0.0)),
        ("MODULE_PREV", "Module_Prev", "ROOT", (-3.00, 0.0, 0.0)),
        ("WEAPON_MOUNT", "Weapon_Mount", "ROOT", (0.0, 0.0, 9.20)),
        ("SEARCHLIGHT", "Searchlight", "ROOT", (1.60, 0.0, 9.60)),
        ("FLAG", "Flag", "ROOT", (0.0, 0.0, 12.20)),
        ("MAGAZINE", "Magazine", "ROOT", (-2.00, -2.40, 0.0)),
        ("LADDER_FOOT", "Ladder_Foot", "ROOT", (0.0, -3.05, 0.0)),
    ],
}


def _sockets(asset):
    prefix = SPECS[asset]["prefix"]
    return [{"key": key, "name": prefix + name, "parent": parent,
             "location": loc} for key, name, parent, loc in SOCKETS[asset]]


# ---------------------------------------------------------------- 通用工具

_box = b4._box
_band = b4._band
_post = b4._post
_lamp = b4._lamp


def _tank(part, cx, cy, z0, z1, r, mat, sides=10, bands=3, band_mat=None,
          cap_mat=None):
    """立式圆筒罐：筒身 + 上下封盖 + 环箍。"""
    band_mat = band_mat or MAT_IRON
    cap_mat = cap_mat or MAT_METAL
    wk.add_cyl(part, (cx, cy, z0), (cx, cy, z1), r, r, mat, sides)
    wk.add_cyl(part, (cx, cy, z0 - 0.06), (cx, cy, z0 + 0.06), r + 0.08,
               r + 0.08, cap_mat, sides)
    wk.add_cyl(part, (cx, cy, z1 - 0.06), (cx, cy, z1 + 0.08), r + 0.06,
               r + 0.04, cap_mat, sides)
    for i in range(bands):
        f = (i + 1.0) / (bands + 1.0)
        z = z0 + (z1 - z0) * f
        wk.add_cyl(part, (cx, cy, z - 0.05), (cx, cy, z + 0.05), r + 0.035,
                   r + 0.035, band_mat, sides)


def _ladder_vertical(part, x, y, z0, z1, width=0.55, mat=MAT_IRON,
                     cage=False, cage_mat=MAT_METAL):
    """垂直铁梯：双立柱 + 横档（+ 可选护笼环）。"""
    for sx in (-1.0, 1.0):
        wk.add_cyl(part, (x + sx * width * 0.5, y, z0),
                   (x + sx * width * 0.5, y, z1), 0.05, 0.05, mat, 6)
    count = max(2, int((z1 - z0) / 0.32))
    for i in range(count + 1):
        z = z0 + 0.12 + (z1 - z0 - 0.12) * i / float(count)
        wk.add_cyl(part, (x - width * 0.5, y, z), (x + width * 0.5, y, z),
                   0.03, 0.03, mat, 5)
    if cage:
        for i in range(int((z1 - z0) / 1.6)):
            z = z0 + 0.9 + i * 1.6
            if z > z1 - 0.4:
                break
            wk.add_torus(part, (x, y - 0.30, z), (0.0, 0.0, 1.0), 0.30, 0.035,
                         cage_mat, seg=10, tube=3)
            for sx in (-1.0, 1.0):
                wk.add_cyl(part, (x + sx * 0.27, y, z),
                           (x + sx * 0.27, y - 0.30, z), 0.03, 0.03,
                           cage_mat, 4)


def _gable_roof_at(part, x0, x1, cy, y_half, z_eave, z_ridge, thick,
                   roof_mat, trim_mat, gable_mat, gx0, gx1):
    """任意 Y 中心的双坡屋顶（批次 3 的 _gable_roof 固定在 y=0）。"""
    xc = (x0 + x1) * 0.5
    for sign in (-1.0, 1.0):
        _slab(part, (xc, cy + sign * y_half, z_eave),
              (xc, cy, z_ridge), (1.0, 0.0, 0.0), x1 - x0, thick, roof_mat)
        for f in (0.3, 0.55, 0.8):
            y = cy + sign * y_half * (1.0 - f)
            z = z_eave + (z_ridge - z_eave) * f
            _box(part, x0 + 0.04, x1 - 0.04, y - 0.045, y + 0.045,
                 z + 0.01, z + 0.055, trim_mat)
    tri = [(cy - y_half, z_eave), (cy + y_half, z_eave), (cy, z_ridge)]
    for g0, g1 in ((gx0, gx0 + 0.14), (gx1 - 0.14, gx1)):
        _tri_prism(part, tri, g0, g1, gable_mat)
    _box(part, x0, x1, cy - 0.14, cy + 0.14, z_ridge - 0.02,
         z_ridge + 0.07, trim_mat)


def _railing_rect(part, x0, x1, y0, y1, z, height=1.05, mat=MAT_IRON,
                  step=1.2):
    corners = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    for i in range(4):
        a = corners[i]
        b = corners[(i + 1) % 4]
        length = math.hypot(b[0] - a[0], b[1] - a[1])
        count = max(1, int(length / step))
        for k in range(count + 1):
            t = k / float(count)
            px = a[0] + (b[0] - a[0]) * t
            py = a[1] + (b[1] - a[1]) * t
            wk.add_cyl(part, (px, py, z), (px, py, z + height), 0.035, 0.035,
                       mat, 5)
        for hz in (height * 0.55, height):
            part.add(bar_between((a[0], a[1], z + hz), (b[0], b[1], z + hz),
                                 0.035), mat)


# ---------------------------------------------------------------- 1. 锯木厂

def _build_sawmill():
    prefix = "SN_Base_Sawmill_"
    parts = {}

    plinth = Part()
    _box(plinth, -4.15, 4.15, -3.15, 3.15, 0.0, 0.32, MAT_STONE)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            _box(plinth, sx * 3.95 - 0.22, sx * 3.95 + 0.22,
                 sy * 2.95 - 0.22, sy * 2.95 + 0.22, 0.0, 0.50, MAT_STONE)
    _box(plinth, 4.15, 6.95, 1.45, 2.55, 0.0, 0.18, MAT_STONE)
    _box(plinth, 3.30, 6.95, -3.05, -1.35, 0.0, 0.18, MAT_STONE)
    parts[prefix + "Plinth"] = (plinth, "ROOT")

    walls = Part()
    _box(walls, -4.0, -3.78, -3.0, 3.0, 0.32, 4.55, MAT_IRON)
    _box(walls, -4.03, -3.75, -3.0, 3.0, 0.32, 1.05, MAT_IRON_RED)
    wk.rivet_row(walls, (-3.76, -2.60, 1.60), (-3.76, -2.60, 4.20), 6,
                 (1.0, 0.0, 0.0), 0.032, 0.045, MAT_BRASS)
    for sy in (-1.0, 1.0):
        _box(walls, -4.0, -1.20, sy * 3.0 - 0.11, sy * 3.0 + 0.11, 0.32, 4.55,
             MAT_IRON)
        _box(walls, -4.0, -1.20, sy * 2.86, sy * 3.0, 0.32, 1.05, MAT_IRON_RED)
        _box(walls, -1.20, -1.02, sy * 3.0 - 0.14, sy * 3.0 + 0.14, 0.32,
             4.55, MAT_WOOD_DARK)
    _box(walls, -4.05, -1.06, -3.05, 3.05, 4.42, 4.62, MAT_IRON)
    # 前开敞：四根立柱
    for sy in (-1.0, 1.0):
        for x in (1.0, 3.95):
            _post(walls, x, sy * 2.95, 0.15, 0.32, 4.55, MAT_WOOD_DARK)
            _box(walls, x - 0.22, x + 0.22, sy * 2.95 - 0.22,
                 sy * 2.95 + 0.22, 4.42, 4.62, MAT_IRON)
    _box(walls, -0.10, 0.10, -2.95, 2.95, 4.42, 4.62, MAT_IRON)
    parts[prefix + "Walls"] = (walls, "ROOT")

    roof = Part()
    _gable_roof(roof, -4.35, 4.20, 3.30, 4.55, 5.75, 0.12, MAT_IRON_RED,
                MAT_IRON, MAT_WOOD_DARK, -4.0, 4.0)
    _box(roof, -0.60, 0.60, -0.55, 0.55, 5.70, 6.02, MAT_IRON)
    _box(roof, -0.66, 0.66, -0.60, 0.60, 6.02, 6.05, MAT_METAL)
    for sy in (-1.0, 1.0):
        _box(roof, -0.70, 0.70, min(sy * 0.55, sy * 0.62),
             max(sy * 0.55, sy * 0.62), 5.78, 6.0, MAT_IRON_RED)
    parts[prefix + "Roof"] = (roof, "ROOT")

    blade = Part()
    bz = 1.90
    wk.add_torus(blade, (-0.60, 0.0, bz), (0.0, 1.0, 0.0), 1.28, 0.05,
                 MAT_METAL, seg=20, tube=3)
    wk.add_cyl(blade, (-0.60, -0.035, bz), (-0.60, 0.035, bz), 1.24, 1.24,
               MAT_METAL, 20)
    for i in range(20):
        a = 2.0 * math.pi * i / 20.0
        tx = -0.60 + 1.36 * math.cos(a)
        tz = bz + 1.36 * math.sin(a)
        blade.add(bar_between((-0.60 + 1.20 * math.cos(a), 0.0,
                               bz + 1.20 * math.sin(a)),
                              (tx, 0.0, tz), 0.09), MAT_IRON)
    wk.add_cyl(blade, (-0.60, -1.05, bz), (-0.60, 1.05, bz), 0.11, 0.11,
               MAT_IRON, 8)
    for sy in (-1.0, 1.0):
        _box(blade, -0.82, -0.38, sy * 0.88 - 0.16, sy * 0.88 + 0.16, 1.48,
             2.32, MAT_METAL)
        wk.add_cyl(blade, (-0.60, sy * 0.80, bz), (-0.60, sy * 1.05, bz),
                   0.07, 0.07, MAT_BRASS, 6)
    # 上半圈护罩
    for i in range(7):
        a = math.radians(15.0 + i * 25.0)
        cx = -0.60 + 1.55 * math.cos(a)
        cz = bz + 1.40 * math.sin(a)
        _box(blade, cx - 0.30, cx + 0.30, -0.42, 0.42, cz - 0.12, cz + 0.12,
             MAT_IRON_RED)
    _box(blade, -0.80, -0.40, -0.45, 0.45, 3.05, 3.30, MAT_IRON)
    wk.add_cyl(blade, (-0.60, -0.30, 3.30), (-0.60, 0.30, 3.30), 0.24, 0.18,
               MAT_METAL, 8)
    parts[prefix + "SawBlade"] = (blade, "ROOT")

    carriage = Part()
    _box(carriage, -2.80, 2.20, -0.72, 0.72, 1.42, 1.62, MAT_WOOD_DECK)
    for sy in (-1.0, 1.0):
        _box(carriage, -3.10, 3.05, sy * 0.92 - 0.07, sy * 0.92 + 0.07, 1.30,
             1.44, MAT_IRON)
        for x in (-2.6, -0.6, 1.4, 2.6):
            _box(carriage, x - 0.14, x + 0.14, sy * 0.92 - 0.20,
                 sy * 0.92 + 0.20, 0.32, 1.32, MAT_WOOD_DARK)
    for x in (-2.10, 1.50):
        _box(carriage, x - 0.18, x + 0.18, -0.85, 0.85, 1.62, 2.05,
             MAT_IRON)
        for sy in (-1.0, 1.0):
            wk.add_cyl(carriage, (x, sy * 0.80, 1.85), (x, sy * 0.45, 1.85),
                       0.16, 0.16, MAT_METAL, 8)
    wk.add_cyl(carriage, (-1.90, 0.0, 1.98), (1.30, 0.0, 1.98), 0.25, 0.25,
               MAT_WOOD, 10)
    _box(carriage, -2.90, 2.30, -0.10, 0.10, 1.34, 1.42, MAT_IRON)
    parts[prefix + "Carriage"] = (carriage, "ROOT")

    ramp = Part()
    for sy in (-1.0, 1.0):
        rails = []
        for f in (0.0, 0.2, 0.4, 0.6, 0.8, 1.0):
            x = 4.45 + 2.45 * f
            z = 1.42 - 1.20 * f
            rails.append((x, sy * 2.00, z))
        for i in range(len(rails) - 1):
            part = bar_between(rails[i], rails[i + 1], 0.09)
            ramp.add(part, MAT_IRON)
        for i in range(4):
            f = i / 3.0
            x = 4.65 + 2.05 * f
            z = 1.30 - 1.00 * f
            wk.add_cyl(ramp, (x, sy * 1.55, z), (x, sy * 2.45, z), 0.12, 0.12,
                       MAT_WOOD_DARK, 8)
            for sy2 in (-1.0, 1.0):
                _box(ramp, x - 0.10, x + 0.10, sy2 * 1.55 - 0.10,
                     sy2 * 1.55 + 0.10, 0.18, z - 0.05, MAT_WOOD_DARK)
        for x, z in ((5.10, 0.92), (6.20, 0.44)):
            _box(ramp, x - 0.10, x + 0.10, sy * 1.92, sy * 2.08, 0.18, z,
                 MAT_IRON)
    _box(ramp, 4.20, 4.60, 1.65, 2.35, 0.32, 1.30, MAT_WOOD_DARK)
    parts[prefix + "LogRamp"] = (ramp, "ROOT")

    stack = Part()
    z = 0.18
    for layer in range(5):
        count = 4 - (layer % 2)
        span = 2.55 - layer * 0.18
        for i in range(count):
            y = -2.20 + (i - (count - 1) * 0.5) * 0.60
            _box(stack, 3.55 - span * 0.5, 3.55 + span * 0.5, y - 0.26,
                 y + 0.26, z, z + 0.22, MAT_WOOD_DECK)
        z += 0.22
    for sy in (-1.0, 1.0):
        _box(stack, 2.20, 2.42, sy * 2.05 - 0.26, sy * 2.05 + 0.26, 0.18, 1.42,
             MAT_WOOD_DARK)
    parts[prefix + "TimberStack"] = (stack, "ROOT")

    shaft = Part()
    _box(shaft, -0.35, 0.35, 2.88, 3.22, 0.55, 1.05, MAT_IRON)
    _box(shaft, -0.24, 0.24, 3.10, 3.42, 1.12, 1.78, MAT_METAL)
    wk.add_cyl(shaft, (0.0, 2.95, 1.45), (0.0, 4.10, 1.45), 0.10, 0.10,
               MAT_METAL, 8)
    wk.add_torus(shaft, (0.0, 3.80, 1.45), (0.0, 1.0, 0.0), 0.40, 0.05,
                 MAT_IRON_RED, seg=14, tube=4)
    wk.add_cyl(shaft, (0.0, 3.74, 1.45), (0.0, 3.92, 1.45), 0.12, 0.12,
               MAT_BRASS, 8)
    for i in range(5):
        a = 2.0 * math.pi * i / 5.0
        wk.add_cyl(shaft, (0.28 * math.cos(a), 3.84,
                           1.45 + 0.28 * math.sin(a)),
                   (0.28 * math.cos(a), 3.78,
                    1.45 + 0.28 * math.sin(a)), 0.03, 0.03, MAT_BRASS, 4)
    _box(shaft, -0.16, 0.16, 4.10, 4.18, 1.36, 1.54, MAT_METAL)
    # 锯屑槽 + 屑箱
    _box(shaft, -0.30, 0.30, -2.30, -1.40, 0.18, 1.10, MAT_IRON)
    _box(shaft, -0.55, 0.55, -2.62, -1.22, 0.18, 0.82, MAT_WOOD_DARK)
    parts[prefix + "DriveShaft"] = (shaft, "ROOT")

    return parts


# ---------------------------------------------------------------- 2. 冶炼炉

def _build_smelter():
    prefix = "SN_Base_Smelter_"
    parts = {}

    plinth = Part()
    _box(plinth, -4.45, 4.45, -3.80, 3.80, 0.0, 0.60, MAT_STONE)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            _box(plinth, sx * 4.20 - 0.24, sx * 4.20 + 0.24,
                 sy * 3.55 - 0.24, sy * 3.55 + 0.24, 0.0, 0.78, MAT_STONE)
    _box(plinth, -4.50, 4.50, -3.86, 3.86, 0.60, 0.74, MAT_IRON)
    parts[prefix + "Plinth"] = (plinth, "ROOT")

    furnace = Part()
    profile = ((0.60, 2.55), (2.10, 2.40), (3.80, 2.10), (5.60, 1.80),
               (6.80, 1.55))
    for i in range(len(profile) - 1):
        z0, r0 = profile[i]
        z1, r1 = profile[i + 1]
        wk.add_cyl(furnace, (0.0, 0.0, z0), (0.0, 0.0, z1), r0, r1,
                   MAT_STONE, 10)
    wk.add_cyl(furnace, (0.0, 0.0, 6.80), (0.0, 0.0, 6.90), 1.55, 1.42,
               MAT_IRON, 10)
    # 出渣口 / 出铁口
    _box(furnace, 2.35, 2.75, -0.45, 0.45, 0.95, 1.45, MAT_IRON)
    _box(furnace, 2.55, 2.95, -0.25, 0.25, 0.95, 1.20, MAT_IRON_RED)
    parts[prefix + "Furnace"] = (furnace, "ROOT")

    bands = Part()
    for z, r in ((1.35, 2.52), (2.95, 2.25), (4.55, 1.97), (6.15, 1.70)):
        wk.add_torus(bands, (0.0, 0.0, z), (0.0, 0.0, 1.0), r + 0.04, 0.06,
                     MAT_IRON, seg=14, tube=3)
        for i in range(6):
            a = 2.0 * math.pi * i / 6.0
            wk.add_cyl(bands, (r * math.cos(a), r * math.sin(a), z - 0.14),
                       (r * math.cos(a), r * math.sin(a), z + 0.14), 0.04,
                       0.04, MAT_METAL, 4)
    for i in range(4):
        a = 2.0 * math.pi * i / 4.0 + math.pi / 4.0
        wk.add_cyl(bands, (2.36 * math.cos(a), 2.36 * math.sin(a), 1.90),
                   (1.62 * math.cos(a), 1.62 * math.sin(a), 2.10), 0.11, 0.08,
                   MAT_BRASS, 6)
    wk.add_torus(bands, (2.36 * math.cos(0.0), 0.0, 1.90), (0.0, 1.0, 0.0),
                 0.10, 0.03, MAT_BRASS, seg=8, tube=3)
    parts[prefix + "Bands"] = (bands, "ROOT")

    platform = Part()
    _box(platform, -1.95, 1.95, -1.95, 1.95, 6.90, 7.05, MAT_IRON)
    _railing_rect(platform, -1.90, 1.90, -1.90, 1.90, 7.05, 1.05, MAT_IRON,
                  step=1.3)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            _post(platform, sx * 1.80, sy * 1.80, 0.10, 6.90, 7.05, MAT_METAL)
    _box(platform, -0.55, 0.55, -0.35, 0.35, 7.05, 7.25, MAT_IRON_RED)
    _box(platform, -0.20, 0.20, -0.20, 0.20, 7.25, 7.45, MAT_METAL)
    parts[prefix + "ChargingPlatform"] = (platform, "ROOT")

    stoves = Part()
    for sy in (-1.0, 1.0):
        cy = sy * 2.55
        _tank(stoves, 3.05, cy, 0.60, 4.30, 0.62, MAT_IRON, bands=4,
              band_mat=MAT_IRON_RED, cap_mat=MAT_METAL)
        wk.add_cyl(stoves, (3.05, cy, 4.30), (3.05, cy, 4.62), 0.62, 0.20,
                   MAT_METAL, 10)
        _box(stoves, 2.70, 3.40, cy - 0.35, cy + 0.35, 0.60, 0.86, MAT_STONE)
        # 热风管接入炉体
        wk.add_cyl(stoves, (3.05, cy - sy * 0.62, 2.60),
                   (1.60, cy - sy * 1.05, 2.60), 0.14, 0.14, MAT_IRON, 8)
        wk.add_torus(stoves, (1.62, cy - sy * 1.05, 2.60),
                     (0.0, 0.0, 1.0), 0.14, 0.04, MAT_BRASS, seg=8, tube=3)
        wk.add_torus(stoves, (3.05, cy, 3.10), (0.0, 0.0, 1.0), 0.72, 0.04,
                     MAT_BRASS, seg=12, tube=3)
    parts[prefix + "Stoves"] = (stoves, "ROOT")

    bins = Part()
    for sy, mat in ((1.0, MAT_COAL), (-1.0, MAT_IRON_RED)):
        cy = sy * 2.42
        for sx in (-1.0, 1.0):
            for sy2 in (-1.0, 1.0):
                _box(bins, -3.60 + sx * 0.80 - 0.09,
                     -3.60 + sx * 0.80 + 0.09,
                     cy + sy2 * 0.72 - 0.09, cy + sy2 * 0.72 + 0.09,
                     0.60, 2.20, MAT_IRON)
        _box(bins, -4.55, -2.65, cy - 0.90, cy + 0.90, 2.20, 3.35, MAT_IRON)
        _box(bins, -4.50, -2.70, cy - 0.85, cy + 0.85, 2.55, 3.28, mat)
        wk.add_cyl(bins, (-3.60, cy, 1.55), (-3.60, cy, 2.20), 0.75, 0.95,
                   MAT_IRON, 8)
        _box(bins, -4.40, -2.80, cy - 0.32, cy + 0.32, 2.30, 2.55, MAT_METAL)
        _slab(bins, (-3.60, cy, 1.55), (-4.40, cy, 0.85), (1.0, 0.0, 0.0),
              0.30, 0.08, MAT_IRON_RED)
        for sy3 in (-1.0, 1.0):
            _box(bins, -4.48, -4.38, cy + sy3 * 0.32 - 0.05,
                 cy + sy3 * 0.32 + 0.05, 0.85, 1.55, MAT_IRON)
    parts[prefix + "Bins"] = (bins, "ROOT")

    skip = Part()
    for sy in (-1.0, 1.0):
        ramp_pts = [(2.90, -3.40, 0.05), (1.85, -2.55, 3.20),
                    (0.95, -1.70, 6.85)]
        for i in range(len(ramp_pts) - 1):
            skip.add(bar_between(ramp_pts[i], ramp_pts[i + 1], 0.10),
                     MAT_IRON)
        for p in ramp_pts[1:]:
            _box(skip, p[0] - 0.10, p[0] + 0.10, p[1] - 0.10, p[1] + 0.10,
                 0.60, p[2] - 0.06, MAT_IRON)
    _box(skip, 2.55, 3.20, -3.55, -2.95, 0.30, 1.05, MAT_IRON_RED)
    _box(skip, 2.62, 3.13, -3.48, -3.02, 1.02, 1.16, MAT_WOOD_DARK)
    wk.add_cyl(skip, (2.60, -3.10, 1.10), (0.95, -1.90, 6.80), 0.035, 0.035,
               MAT_CANVAS_SHADE, 4)
    wk.add_cyl(skip, (0.95, -1.70, 6.85), (0.95, -1.70, 7.15), 0.20, 0.20,
               MAT_METAL, 8)
    parts[prefix + "SkipHoist"] = (skip, "ROOT")

    chimney = Part()
    _box(chimney, 1.45, 2.15, -1.95, -1.25, 6.95, 11.08, MAT_STONE)
    for z in (7.60, 8.60, 9.60, 10.58):
        _box(chimney, 1.40, 2.20, -2.00, -1.20, z - 0.06, z + 0.06,
             MAT_IRON)
    _box(chimney, 1.36, 2.24, -2.04, -1.16, 11.08, 11.28, MAT_IRON)
    wk.add_cyl(chimney, (1.80, -1.60, 11.28), (1.80, -1.60, 11.40), 0.44, 0.32,
               MAT_METAL, 10)
    wk.add_cyl(chimney, (0.40, -0.60, 7.05), (1.80, -1.60, 7.05), 0.26, 0.26,
               MAT_IRON, 8)
    wk.add_cyl(chimney, (1.80, -1.60, 7.05), (1.80, -1.60, 8.10), 0.26, 0.26,
               MAT_IRON, 8)
    wk.add_torus(chimney, (1.80, -1.60, 7.05), (1.0, 0.0, 0.0), 0.26, 0.06,
                 MAT_BRASS, seg=8, tube=3)
    parts[prefix + "Stack"] = (chimney, "ROOT")

    # 出铁沟（+X）
    trough = Part()
    _box(trough, 2.30, 4.35, -0.32, 0.32, 0.60, 0.74, MAT_IRON_RED)
    for sy in (-1.0, 1.0):
        _box(trough, 2.30, 4.35, sy * 0.32 - 0.06, sy * 0.32 + 0.06, 0.74,
             0.92, MAT_IRON)
    _box(trough, 4.10, 4.55, -0.42, 0.42, 0.60, 0.80, MAT_IRON)
    parts[prefix + "Taphole"] = (trough, "ROOT")

    return parts


# ---------------------------------------------------------------- 3. 铸造车间

def _build_foundry():
    prefix = "SN_Base_Foundry_"
    parts = {}

    plinth = Part()
    _box(plinth, -6.15, 6.15, -4.15, 4.15, 0.0, 0.45, MAT_STONE)
    _box(plinth, 6.15, 6.55, -2.60, 2.60, 0.0, 0.18, MAT_STONE)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            _box(plinth, sx * 5.95 - 0.24, sx * 5.95 + 0.24,
                 sy * 3.95 - 0.24, sy * 3.95 + 0.24, 0.0, 0.70, MAT_STONE)
    parts[prefix + "Plinth"] = (plinth, "ROOT")

    walls = Part()
    _box(walls, -6.0, 6.0, -4.0, 4.0, 0.45, 6.0, MAT_WOOD_DARK)
    for sx in (-1.0, 1.0):
        _box(walls, sx * 6.0 - 0.13, sx * 6.0 + 0.13, -4.0, 4.0, 0.45, 6.0,
             MAT_IRON)
        _box(walls, sx * 6.03, sx * 6.03 - 0.10 * sx, -4.0, 4.0, 0.45, 1.20,
             MAT_IRON_RED)
    for sy in (-1.0, 1.0):
        _box(walls, -6.0, 6.0, sy * 4.0 - 0.11, sy * 4.0 + 0.11, 0.45, 6.0,
             MAT_IRON)
        _box(walls, -6.0, 6.0, sy * 4.03, sy * 4.03 - 0.10 * sy, 0.45, 1.20,
             MAT_IRON_RED)
    for x in (-4.0, -2.0, 0.0, 2.0, 4.0):
        for sy in (-1.0, 1.0):
            _box(walls, x - 0.10, x + 0.10, sy * 4.0 - 0.20,
                 sy * 4.0 + 0.02, 0.45, 6.0, MAT_WOOD)
    wk.rivet_row(walls, (-5.70, 4.10, 1.50), (5.70, 4.10, 1.50), 13,
                 (0.0, 1.0, 0.0), 0.032, 0.045, MAT_BRASS)
    # 石腰线：把整面铁板墙分段，避免远处读成一个大黑盒
    for sy in (-1.0, 1.0):
        _box(walls, -6.02, 6.02, sy * 4.0 - 0.16, sy * 4.0 + 0.16, 2.55, 2.85,
             MAT_STONE)
    _box(walls, 6.13, 6.24, -4.02, 4.02, 2.55, 2.85, MAT_STONE)
    for sy in (-1.0, 1.0):
        for x in (-4.2, -1.4, 1.4, 4.2):
            _window(walls, (x, sy * 4.0, 4.70), (0.0, sy, 0.0),
                    (1.0, 0.0, 0.0), 1.30, 1.00, frame=MAT_IRON, mullions=2)
    parts[prefix + "Walls"] = (walls, "ROOT")

    roof = Part()
    _gable_roof(roof, -6.40, 6.40, 4.25, 6.0, 7.80, 0.13, MAT_IRON_RED,
                MAT_IRON, MAT_WOOD_DARK, -6.0, 6.0)
    # 采光顶（monitor roof）
    _box(roof, -3.60, 3.60, -1.30, 1.30, 7.10, 7.90, MAT_WOOD_DARK)
    for sy in (-1.0, 1.0):
        for x in (-2.5, -0.8, 0.8, 2.5):
            _window(roof, (x, sy * 1.30, 7.55), (0.0, sy, 0.0),
                    (1.0, 0.0, 0.0), 1.20, 0.50, frame=MAT_IRON, mullions=2,
                    sill=False)
    _gable_roof(roof, -3.75, 3.75, 1.40, 7.90, 8.30, 0.10, MAT_IRON_RED,
                MAT_IRON, MAT_WOOD_DARK, -3.60, 3.60)
    for x in (-4.2, 4.2):
        _box(roof, x - 0.06, x + 0.06, -1.20, 1.20, 7.10, 8.10, MAT_IRON)
    parts[prefix + "Roof"] = (roof, "ROOT")

    doors = Part()
    n, t = (1.0, 0.0, 0.0), (0.0, 1.0, 0.0)
    # 正立面构件全部在 +X 铁板墙外皮（x=6.13）之外，避免被墙吞掉。
    for s in (-1.0, 1.0):
        _face_box(doors, (6.14, s * 2.55, 2.75), n, t, 0.24, 4.90, 0.14,
                  MAT_IRON)
    _face_box(doors, (6.14, 0.0, 5.05), n, t, 5.30, 0.24, 0.14, MAT_IRON)
    for s in (-1.0, 1.0):
        _face_box(doors, (6.15, s * 1.25, 2.60), n, t, 2.35, 4.40, 0.10,
                  MAT_WOOD)
        for z in (1.40, 2.60, 3.80):
            _face_box(doors, (6.25, s * 1.25, z), n, t, 2.25, 0.10, 0.05,
                      MAT_IRON)
        doors.add(bar_between((6.27, s * 1.25 - 0.90, 0.80),
                              (6.27, s * 1.25 + 0.90, 4.20), 0.07), MAT_IRON)
        wk.add_cyl(doors, (6.25, s * 0.25, 2.20), (6.35, s * 0.25, 2.20),
                   0.05, 0.05, MAT_BRASS, 6)
        # 门顶吊挂件：门板 4.80 -> 轨道 5.05
        for yy in (s * 0.60, s * 1.85):
            _box(doors, 6.18, 6.30, yy - 0.06, yy + 0.06, 4.78, 5.06,
                 MAT_IRON)
    # 石门套：两侧门垛 + 门楣，让门洞在深色墙面里可读
    for s in (-1.0, 1.0):
        _face_box(doors, (6.13, s * 2.72, 2.72), n, t, 0.42, 4.55, 0.22,
                  MAT_STONE)
    _face_box(doors, (6.13, 0.0, 4.95), n, t, 5.90, 0.42, 0.24, MAT_STONE)
    # 门楣下黄铜条（外移到门楣外皮之外）
    _box(doors, 6.38, 6.46, -2.72, 2.72, 4.70, 4.78, MAT_BRASS)
    # 门头招牌：木牌 + 黄铜边框 + 铆钉（挂在石门楣正面）
    _face_box(doors, (6.37, 0.0, 4.95), n, t, 3.20, 0.34, 0.06,
              MAT_WOOD_DARK)
    for z in (4.80, 5.10):
        _face_box(doors, (6.43, 0.0, z), n, t, 3.30, 0.06, 0.04, MAT_BRASS)
    for s in (-1.0, 1.0):
        _face_box(doors, (6.43, s * 1.63, 4.95), n, t, 0.06, 0.34, 0.04,
                  MAT_BRASS)
    wk.rivet_row(doors, (6.45, -1.45, 4.95), (6.45, 1.45, 4.95), 8,
                 (1.0, 0.0, 0.0), 0.028, 0.04, MAT_BRASS)
    _box(doors, 6.14, 6.34, -2.75, 2.75, 5.05, 5.30, MAT_IRON)
    # 中缝盖板（astragal）
    _box(doors, 6.24, 6.30, -0.09, 0.09, 0.65, 4.80, MAT_WOOD_DARK)
    for s in (-1.0, 1.0):
        wk.add_cyl(doors, (6.22, s * 2.55, 5.18), (6.22, s * 0.30, 5.18),
                   0.05, 0.05, MAT_METAL, 5)
    parts[prefix + "SlidingDoors"] = (doors, "ROOT")

    cupola = Part()
    _box(cupola, -4.45, -2.75, -3.25, -1.55, 0.45, 1.00, MAT_STONE)
    for i, (z0, z1, r0, r1) in enumerate(((1.00, 2.20, 0.82, 0.86),
                                          (2.20, 4.20, 0.86, 0.78),
                                          (4.20, 5.60, 0.78, 0.70))):
        wk.add_cyl(cupola, (-3.60, -2.40, z0), (-3.60, -2.40, z1), r0, r1,
                   MAT_IRON, 10)
    _box(cupola, -3.98, -3.22, -2.78, -2.02, 2.30, 3.05, MAT_IRON_RED)
    _box(cupola, -3.90, -3.30, -2.72, -2.08, 2.38, 2.98, MAT_GLASS_DARK)
    for sy in (-1.0, 1.0):
        wk.add_cyl(cupola, (-3.60, -2.40 + sy * 0.80, 1.55),
                   (-3.60, -2.40 + sy * 1.20, 1.55), 0.10, 0.08, MAT_BRASS, 6)
    wk.add_cyl(cupola, (-3.60, -2.40, 1.05), (-3.10, -2.40, 0.95), 0.16, 0.12,
               MAT_IRON_RED, 8)
    _box(cupola, -3.40, -3.20, -2.55, -2.25, 0.70, 1.05, MAT_IRON)
    parts[prefix + "Cupola"] = (cupola, "ROOT")

    crane = Part()
    for sy in (-1.0, 1.0):
        _box(crane, -5.95, -5.75, sy * 4.0 - 0.10, sy * 4.0 + 0.10, 5.55,
             5.85, MAT_IRON)
        _box(crane, 5.75, 5.95, sy * 4.0 - 0.10, sy * 4.0 + 0.10, 5.55, 5.85,
             MAT_IRON)
    _box(crane, -5.90, 5.90, -0.14, 0.14, 5.85, 6.10, MAT_IRON)
    _box(crane, -5.90, 5.90, -0.22, 0.22, 5.70, 5.85, MAT_IRON)
    for x in (-5.0, 0.0, 5.0):
        crane.add(bar_between((x, 0.0, 5.80), (x, 0.0, 6.00), 0.06), MAT_METAL)
    _box(crane, 3.25, 3.95, -0.28, 0.28, 5.42, 5.72, MAT_METAL)
    wk.add_torus(crane, (3.60, 0.0, 5.30), (0.0, 1.0, 0.0), 0.14, 0.04,
                 MAT_BRASS, seg=10, tube=4)
    wk.add_cyl(crane, (3.60, 0.0, 5.30), (3.60, 0.0, 4.35), 0.02, 0.02,
               MAT_CANVAS_SHADE, 4)
    _box(crane, 3.48, 3.72, -0.10, 0.10, 4.20, 4.38, MAT_IRON)
    wk.add_torus(crane, (3.60, 0.0, 4.09), (0.0, 1.0, 0.0), 0.09, 0.026,
                 MAT_IRON, seg=8, tube=3)
    parts[prefix + "CraneRail"] = (crane, "ROOT")

    ladle = Part()
    _box(ladle, 3.48, 3.72, -0.10, 0.10, 4.05, 4.25, MAT_IRON)
    for sy in (-1.0, 1.0):
        ladle.add(bar_between((3.60, sy * 0.35, 4.15),
                              (3.60, sy * 0.45, 2.95), 0.05), MAT_IRON)
        ladle.add(bar_between((3.20, sy * 0.45, 2.95),
                              (4.00, sy * 0.45, 2.95), 0.04), MAT_IRON)
    wk.add_cyl(ladle, (3.60, 0.0, 1.70), (3.60, 0.0, 2.95), 0.55, 0.72,
               MAT_IRON, 10)
    wk.add_cyl(ladle, (3.60, 0.0, 1.55), (3.60, 0.0, 1.70), 0.40, 0.55,
               MAT_IRON_RED, 10)
    _box(ladle, 4.10, 4.42, -0.22, 0.22, 2.67, 2.87, MAT_IRON)
    wk.add_torus(ladle, (3.60, 0.0, 2.80), (0.0, 0.0, 1.0), 0.66, 0.04,
                 MAT_BRASS, seg=12, tube=3)
    parts[prefix + "Ladle"] = (ladle, "ROOT")

    molds = Part()
    _box(molds, -1.40, 4.80, -2.30, 2.30, 0.45, 0.55, MAT_STONE)
    for i, (cx, cy) in enumerate(((-0.30, -1.40), (1.20, -1.30), (-0.20, 1.30),
                                  (1.40, 1.20))):
        for sx in (-1.0, 1.0):
            for sy in (-1.0, 1.0):
                _box(molds, cx + sx * 0.72 - 0.07, cx + sx * 0.72 + 0.07,
                     cy + sy * 0.52 - 0.07, cy + sy * 0.52 + 0.07, 0.55, 0.95,
                     MAT_IRON)
        _box(molds, cx - 0.80, cx + 0.80, cy - 0.60, cy + 0.60, 0.95, 1.05,
             MAT_WOOD_DARK)
    _box(molds, -1.75, -1.05, 0.60, 1.30, 0.95, 1.09, MAT_IRON_RED)
    _box(molds, 3.40, 4.60, -0.60, 0.60, 0.55, 1.40, MAT_WOOD_DARK)
    for sy in (-1.0, 1.0):
        for x in (3.60, 4.40):
            _box(molds, x - 0.07, x + 0.07, sy * 0.52 - 0.07,
                 sy * 0.52 + 0.07, 1.40, 1.46, MAT_IRON)
    _box(molds, -5.80, -5.20, 1.40, 2.60, 0.45, 2.10, MAT_WOOD_DARK)
    for sy in (-1.0, 1.0):
        _box(molds, -5.85, -5.15, sy * 2.05 - 0.08, sy * 2.05 + 0.08, 0.45,
             2.10, MAT_WOOD)
    parts[prefix + "MoldFloor"] = (molds, "ROOT")

    chimney = Part()
    _box(chimney, -4.05, -3.15, -2.85, -1.95, 5.40, 8.95, MAT_STONE)
    for z in (6.10, 7.00, 7.90, 8.60):
        _box(chimney, -4.10, -3.10, -2.90, -1.90, z - 0.06, z + 0.06,
             MAT_IRON)
    _box(chimney, -4.12, -3.08, -2.92, -1.88, 8.95, 9.12, MAT_IRON)
    wk.add_cyl(chimney, (-3.60, -2.40, 9.12), (-3.60, -2.40, 9.15), 0.46, 0.34,
               MAT_METAL, 10)
    wk.add_cyl(chimney, (-3.60, -2.40, 5.55), (-3.60, -2.40, 6.00), 0.34, 0.34,
               MAT_IRON, 8)
    parts[prefix + "Stack"] = (chimney, "ROOT")

    return parts


# ---------------------------------------------------------------- 4. 仓库堆场

def _build_stockyard():
    prefix = "SN_Base_Stockyard_"
    parts = {}

    base = Part()
    _box(base, -6.60, 6.60, -5.50, 5.50, 0.0, 0.18, MAT_STONE)
    for i in range(5):
        x = -5.60 + i * 2.8
        for sy in (-1.0, 1.0):
            _box(base, x - 0.90, x + 0.90, sy * 5.10 - 0.20,
                 sy * 5.10 + 0.20, 0.18, 0.24, MAT_IRON)
    for sy in (-1.0, 1.0):
        _box(base, -6.55, 6.55, sy * 5.42, sy * 5.50, 0.18, 0.28, MAT_IRON)
    parts[prefix + "Base"] = (base, "ROOT")

    fence = Part()
    posts = []
    for y in (-5.30, -2.70, 0.0, 2.70, 5.30):
        posts.append((-6.45, y))
    for x in (-4.30, -2.20, -0.10, 2.00, 4.10, 6.20):
        posts.append((x, -5.30))
        posts.append((x, 5.30))
    for px, py in posts:
        _box(fence, px - 0.09, px + 0.09, py - 0.09, py + 0.09, 0.18, 2.55,
             MAT_IRON)
        _box(fence, px - 0.13, px + 0.13, py - 0.13, py + 0.13, 2.55, 2.68,
             MAT_METAL)
        wk.add_cyl(fence, (px, py, 2.68), (px, py, 2.80), 0.09, 0.03,
                   MAT_BRASS, 6)
    segments = [
        ((-6.45, -5.30), (-6.45, 5.30)),
        ((-6.45, -5.30), (6.20, -5.30)),
        ((-6.45, 5.30), (6.20, 5.30)),
    ]
    for a, b in segments:
        for z in (0.70, 1.45, 2.20):
            _box(fence, min(a[0], b[0]), max(a[0], b[0]) if a[0] != b[0]
                 else a[0] + 0.08,
                 min(a[1], b[1]), max(a[1], b[1]) if a[1] != b[1]
                 else a[1] + 0.08, z - 0.05, z + 0.05, MAT_IRON)
    parts[prefix + "Fence"] = (fence, "ROOT")

    gate = Part()
    for sy in (-1.0, 1.0):
        _box(gate, 6.20, 6.44, sy * 2.15 - 0.12, sy * 2.15 + 0.12, 0.18, 2.90,
             MAT_IRON)
        wk.add_cyl(gate, (6.32, sy * 2.15, 2.90), (6.32, sy * 2.15, 3.04),
                   0.12, 0.04, MAT_BRASS, 6)
        _box(gate, 6.06, 6.26, sy * 2.15 - 0.66, sy * 2.15 + 0.66, 0.18, 2.55,
             MAT_WOOD_DARK)
        for z in (0.75, 1.50, 2.25):
            _box(gate, 6.00, 6.30, sy * 2.15 - 0.66, sy * 2.15 + 0.66,
                 z - 0.05, z + 0.05, MAT_IRON)
        gate.add(bar_between((6.02, sy * 2.15 - 0.55, 0.55),
                             (6.02, sy * 2.15 + 0.55, 2.40), 0.06), MAT_IRON)
    _box(gate, 6.20, 6.44, -2.27, 2.27, 2.62, 2.78, MAT_IRON)
    parts[prefix + "Gate"] = (gate, "ROOT")

    stacks = Part()
    # 木材堆
    z = 0.18
    for layer in range(5):
        count = 5 - (layer % 2)
        for i in range(count):
            x = 2.20 + (i - (count - 1) * 0.5) * 0.58
            _box(stacks, x - 0.27, x + 0.27, 2.05, 4.65, z, z + 0.24,
                 MAT_WOOD_DECK)
        z += 0.24
    for x in (1.02, 3.38):
        _box(stacks, x - 0.10, x + 0.10, 1.95, 1.98, 0.18, 1.46, MAT_WOOD_DARK)
    # 木箱堆
    for layer in range(3):
        for i in range(3):
            cx = 1.45 + i * 0.95
            cy = -4.10 + layer * 0.02
            _box(stacks, cx - 0.42, cx + 0.42, cy - 0.42, cy + 0.42,
                 0.18 + layer * 0.86, 0.18 + (layer + 1) * 0.86, MAT_WOOD)
            _box(stacks, cx - 0.44, cx + 0.44, cy - 0.44, cy + 0.44,
                 0.18 + (layer + 1) * 0.86 - 0.06,
                 0.18 + (layer + 1) * 0.86, MAT_IRON)
    # 煤堆（分层收顶）
    levels = ((0.18, 1.10, 1.80), (0.60, 1.00, 1.55), (1.05, 0.72, 1.20),
              (1.40, 0.38, 0.75))
    for z0, hx, hy in levels:
        _box(stacks, -1.05 - hx, -1.05 + hx, 1.00, 1.00 + 1.80 * hy, z0,
             z0 + 0.42, MAT_COAL)
    _box(stacks, -1.10, 0.05, 1.00, 3.00, 1.72, 1.82, MAT_COAL)
    # 矿石堆
    for i, (cx, cy, r) in enumerate(((4.55, 3.95, 0.62), (5.15, 4.45, 0.55),
                                     (4.85, 3.15, 0.48))):
        wk.add_cyl(stacks, (cx, cy, 0.18), (cx, cy, 0.18 + 0.45), r, r * 0.55,
                   MAT_IRON_RED, 7)
        for k in range(5):
            a = 2.0 * math.pi * k / 5.0 + i
            _box(stacks, cx + r * 0.55 * math.cos(a) - 0.11,
                 cx + r * 0.55 * math.cos(a) + 0.11,
                 cy + r * 0.55 * math.sin(a) - 0.11,
                 cy + r * 0.55 * math.sin(a) + 0.11, 0.18, 0.55,
                 MAT_STONE)
    parts[prefix + "Stacks"] = (stacks, "ROOT")

    gantry = Part()
    for sy in (-1.0, 1.0):
        leg_y = sy * 4.60
        for sx in (-1.0, 1.0):
            _box(gantry, -2.00 + sx * 0.30 - 0.09, -2.00 + sx * 0.30 + 0.09,
                 leg_y - 0.09, leg_y + 0.09, 0.18, 5.20, MAT_IRON)
            _box(gantry, -2.00 + sx * 0.90 - 0.10, -2.00 + sx * 0.90 + 0.10,
                 leg_y - 0.10, leg_y + 0.10, 0.18, 1.10, MAT_IRON)
        gantry.add(bar_between((-2.60, leg_y, 1.00), (-2.30, leg_y, 4.90),
                               0.07), MAT_IRON)
        gantry.add(bar_between((-1.40, leg_y, 1.00), (-1.70, leg_y, 4.90),
                               0.07), MAT_IRON)
        _box(gantry, -2.70, -1.30, leg_y - 0.12, leg_y + 0.12, 4.95, 5.20,
             MAT_IRON)
    _box(gantry, -2.12, -1.88, -5.00, 5.00, 5.20, 5.46, MAT_IRON)
    _box(gantry, -2.20, -1.80, -5.00, 5.00, 5.46, 5.56, MAT_METAL)
    for sy in (-1.0, 1.0):
        gantry.add(bar_between((-2.00, sy * 4.90, 5.36),
                               (-2.00, sy * 4.90, 5.00), 0.05), MAT_IRON)
    _box(gantry, -2.30, -1.70, -0.46, 0.46, 5.16, 5.44, MAT_METAL)
    wk.add_torus(gantry, (-2.00, 0.0, 5.08), (0.0, 1.0, 0.0), 0.14, 0.04,
                 MAT_BRASS, seg=10, tube=4)
    wk.add_cyl(gantry, (-2.00, 0.0, 5.08), (-2.00, 0.0, 2.55), 0.02, 0.02,
               MAT_CANVAS_SHADE, 4)
    _box(gantry, -2.12, -1.88, -0.10, 0.10, 2.38, 2.55, MAT_IRON)
    wk.add_torus(gantry, (-2.00, 0.0, 2.26), (0.0, 1.0, 0.0), 0.10, 0.03,
                 MAT_IRON, seg=8, tube=3)
    parts[prefix + "Gantry"] = (gantry, "ROOT")

    scale = Part()
    _box(scale, 3.00, 5.40, -1.10, 1.10, 0.18, 0.26, MAT_IRON)
    _box(scale, 2.90, 5.50, -1.20, 1.20, 0.26, 0.30, MAT_METAL)
    for sy in (-1.0, 1.0):
        _box(scale, 3.00, 5.40, sy * 1.20 - 0.05, sy * 1.20 + 0.05, 0.18,
             0.30, MAT_IRON)
    _box(scale, 5.40, 5.72, -0.30, 0.30, 0.30, 2.05, MAT_WOOD_DARK)
    _box(scale, 5.36, 5.76, -0.34, 0.34, 2.05, 2.22, MAT_IRON)
    wk.add_cyl(scale, (5.56, -0.18, 1.65), (5.58, 0.18, 1.65), 0.30, 0.30,
               MAT_BRASS, 10)
    _box(scale, 5.57, 5.62, -0.20, 0.20, 1.62, 1.68, MAT_GLASS_DARK)
    for sy in (-1.0, 1.0):
        _box(scale, 5.50, 5.62, sy * 0.95 - 0.08, sy * 0.95 + 0.08, 0.18, 2.05,
             MAT_IRON)
    parts[prefix + "Weighbridge"] = (scale, "ROOT")

    hut = Part()
    _box(hut, -6.10, -3.70, 3.10, 5.10, 0.18, 2.65, MAT_WOOD_DARK)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            _post(hut, -4.90 + sx * 1.08, 4.10 + sy * 0.88, 0.10, 0.18, 2.65,
                  MAT_IRON)
    _gable_roof_at(hut, -6.25, -3.55, 4.10, 1.15, 2.65, 3.35, 0.09,
                   MAT_IRON_RED, MAT_IRON, MAT_WOOD_DARK, -6.10, -3.70)
    _door(hut, (-4.90, 3.10, 1.42), (0.0, 1.0, 0.0), (1.0, 0.0, 0.0),
          0.95, 1.90, MAT_WOOD, MAT_IRON, brace=MAT_IRON_RED)
    _window(hut, (-5.55, 5.10, 1.75), (0.0, 1.0, 0.0), (1.0, 0.0, 0.0),
            0.80, 0.70, frame=MAT_IRON)
    _lamp(hut, -6.10, 4.10, 2.35, (-1.0, 0.0))
    _box(hut, -6.32, -6.22, 1.55, 1.95, 0.18, 2.50, MAT_IRON)
    parts[prefix + "Hut"] = (hut, "ROOT")

    lamp = Part()
    for px, py in ((6.35, 2.70), (-6.35, -2.90)):
        _box(lamp, px - 0.07, px + 0.07, py - 0.07, py + 0.07, 0.18, 6.10,
             MAT_IRON)
        _box(lamp, px - 0.16, px + 0.16, py - 0.16, py + 0.16, 6.10, 6.20,
             MAT_IRON)
        wk.add_cyl(lamp, (px, py, 5.75), (px, py, 6.05), 0.13, 0.13,
                   MAT_GLASS_DARK, 8)
        wk.add_cyl(lamp, (px, py, 6.05), (px, py, 6.20), 0.16, 0.05,
                   MAT_BRASS, 8)
    parts[prefix + "Lamp"] = (lamp, "ROOT")

    return parts


# ---------------------------------------------------------------- 5. 防御塔

def _build_defense_tower():
    prefix = "SN_Base_Defense_Tower_"
    parts = {}

    plinth = Part()
    _box(plinth, -3.50, 3.50, -3.50, 3.50, 0.0, 0.40, MAT_STONE)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            _box(plinth, sx * 3.20 - 0.30, sx * 3.20 + 0.30,
                 sy * 3.20 - 0.30, sy * 3.20 + 0.30, 0.0, 2.10, MAT_STONE)
    _box(plinth, -3.58, 3.58, -3.58, 3.58, 0.36, 0.50, MAT_IRON)
    _box(plinth, 3.10, 3.62, -0.70, 0.70, 0.0, 0.22, MAT_STONE)
    _box(plinth, 3.62, 3.92, -0.70, 0.70, 0.0, 0.12, MAT_STONE)
    parts[prefix + "Plinth"] = (plinth, "ROOT")

    tower = Part()
    levels = ((0.40, 3.50, 3.00), (3.50, 6.30, 2.76), (6.30, 9.00, 2.52))
    for z0, z1, half in levels:
        _box(tower, -half, half, -half, half, z0, z1, MAT_STONE)
        _box(tower, -half - 0.05, half + 0.05, -half - 0.05, half + 0.05,
             z0, z0 + 0.14, MAT_IRON)
        for sx in (-1.0, 1.0):
            for sy in (-1.0, 1.0):
                _box(tower, sx * half - 0.14, sx * half + 0.14,
                     sy * half - 0.14, sy * half + 0.14, z0, z1, MAT_STONE)
    for z in (3.50, 6.30):
        _box(tower, -2.86, 2.86, -2.86, 2.86, z - 0.10, z + 0.10, MAT_IRON)
    for z0, z1, half in levels:
        for sy in (-1.0, 1.0):
            for x in (-1.20, 1.20):
                _face_box(tower, (x, sy * (half - 0.02), (z0 + z1) * 0.5),
                          (0.0, sy, 0.0), (1.0, 0.0, 0.0), 0.26,
                          min(1.20, z1 - z0 - 0.6), 0.06, MAT_GLASS_DARK)
    # 底层门（+X）与台阶
    n, t = (1.0, 0.0, 0.0), (0.0, 1.0, 0.0)
    _face_box(tower, (2.98, 0.0, 1.55), n, t, 1.80, 2.50, 0.10, MAT_IRON)
    _door(tower, (3.04, 0.0, 1.40), n, t, 1.30, 2.20, MAT_WOOD_DARK,
          MAT_IRON, brace=MAT_IRON_RED)
    for i in range(3):
        _box(tower, 3.08 + i * 0.14, 3.34 + i * 0.14, -0.80, 0.80, 0.0,
             0.22 - i * 0.06, MAT_STONE)
    parts[prefix + "Tower"] = (tower, "ROOT")

    parapet = Part()
    _box(parapet, -2.92, 2.92, -2.92, 2.92, 9.00, 9.20, MAT_IRON)
    for i in range(8):
        a = 2.0 * math.pi * i / 8.0 + math.pi / 8.0
        cx = 2.70 * math.cos(a)
        cy = 2.70 * math.sin(a)
        _box(parapet, cx - 0.42, cx + 0.42, cy - 0.42, cy + 0.42, 9.20,
             9.95, MAT_STONE)
    for i in range(8):
        a = 2.0 * math.pi * i / 8.0 + math.pi / 8.0
        cx = 2.70 * math.cos(a)
        cy = 2.70 * math.sin(a)
        _box(parapet, cx - 0.30, cx + 0.30, cy - 0.30, cy + 0.30, 9.95,
             10.05, MAT_IRON)
    parts[prefix + "Parapet"] = (parapet, "ROOT")

    platform = Part()
    _box(platform, -2.78, 2.78, -2.78, 2.78, 9.00, 9.20, MAT_STONE)
    for i in range(8):
        a = 2.0 * math.pi * i / 8.0 + math.pi / 8.0
        x = 2.48 * math.cos(a)
        y = 2.48 * math.sin(a)
        _box(platform, x - 0.20, x + 0.20, y - 0.20, y + 0.20, 8.74, 9.00,
             MAT_STONE)
    for i in range(8):
        a = 2.0 * math.pi * i / 8.0
        x = 2.10 * math.cos(a)
        y = 2.10 * math.sin(a)
        _box(platform, x - 0.10, x + 0.10, y - 0.10, y + 0.10, 9.20, 9.36,
             MAT_IRON)
    wk.add_cyl(platform, (0.0, 0.0, 9.20), (0.0, 0.0, 9.36), 0.62, 0.55,
               MAT_IRON, 12)
    wk.add_cyl(platform, (0.0, 0.0, 9.36), (0.0, 0.0, 9.42), 0.70, 0.70,
               MAT_METAL, 12)
    for i in range(8):
        a = 2.0 * math.pi * i / 8.0
        wk.add_bolt(platform, (0.52 * math.cos(a), 0.52 * math.sin(a), 9.43),
                    0.045, 0.05, MAT_BRASS, axis=(0.0, 0.0, 1.0))
    # 弹箱 / 装填台
    _box(platform, -1.90, -0.90, 1.30, 2.20, 9.20, 9.90, MAT_WOOD_DARK)
    _box(platform, -1.94, -0.86, 1.26, 2.24, 9.90, 9.98, MAT_IRON)
    parts[prefix + "WeaponPlatform"] = (platform, "ROOT")

    magazine = Part()
    _box(magazine, -3.30, -0.70, -3.60, -1.30, 0.0, 1.70, MAT_STONE)
    _box(magazine, -3.36, -0.64, -3.66, -1.24, 1.70, 1.90, MAT_IRON)
    _gable_roof_at(magazine, -3.36, -0.64, -2.45, 1.10, 1.90, 2.55, 0.10,
                   MAT_IRON_RED, MAT_IRON, MAT_STONE, -3.30, -0.70)
    _box(magazine, -2.20, -1.80, -3.62, -3.56, 0.10, 1.50, MAT_IRON)
    _box(magazine, -2.14, -1.86, -3.66, -3.58, 0.30, 1.30, MAT_WOOD_DARK)
    wk.add_cyl(magazine, (-2.00, -3.64, 1.05), (-1.80, -3.64, 1.05), 0.04,
               0.04, MAT_BRASS, 6)
    _box(magazine, -1.60, -1.20, -3.30, -1.60, 0.0, 0.55, MAT_WOOD_DARK)
    parts[prefix + "PowderStore"] = (magazine, "ROOT")

    ladder = Part()
    _ladder_vertical(ladder, 0.0, -3.05, 0.0, 9.32, width=0.55, cage=True)
    for z in (2.20, 4.60, 7.00):
        _box(ladder, -0.34, 0.34, -3.20, -2.96, z - 0.06, z + 0.06,
             MAT_IRON)
        ladder.add(bar_between((0.0, -3.05, z), (0.0, -2.55, z), 0.07),
                   MAT_IRON)
    _box(ladder, -0.52, 0.52, -3.40, -2.55, 9.20, 9.32, MAT_IRON)
    for sx in (-1.0, 1.0):
        wk.add_cyl(ladder, (sx * 0.48, -3.36, 9.20), (sx * 0.48, -3.36, 9.95),
                   0.03, 0.03, MAT_IRON, 5)
    parts[prefix + "Ladder"] = (ladder, "ROOT")

    flag = Part()
    wk.add_cyl(flag, (0.0, 0.0, 9.20), (0.0, 0.0, 12.20), 0.065, 0.05,
               MAT_IRON, 8)
    wk.add_cyl(flag, (0.0, 0.0, 9.20), (0.0, 0.0, 9.34), 0.18, 0.12,
               MAT_BRASS, 8)
    wk.add_cyl(flag, (0.0, 0.0, 12.20), (0.0, 0.0, 12.25), 0.09, 0.02,
               MAT_BRASS, 6)
    _box(flag, 0.06, 1.05, -0.03, 0.03, 11.45, 12.00, MAT_CANVAS_SHADE)
    _box(flag, 0.06, 1.05, -0.035, 0.035, 11.42, 11.45, MAT_IRON_RED)
    wk.add_cyl(flag, (0.0, 0.0, 11.35), (0.0, 0.0, 11.95), 0.012, 0.012,
               MAT_CANVAS_SHADE, 4)
    parts[prefix + "Flagpole"] = (flag, "ROOT")

    search = Part()
    _box(search, 1.36, 1.74, -0.20, 0.20, 9.20, 9.26, MAT_IRON)
    wk.add_cyl(search, (1.55, 0.0, 9.26), (1.55, 0.0, 9.60), 0.08, 0.08,
               MAT_IRON, 8)
    _box(search, 1.20, 1.60, -0.14, 0.14, 9.60, 9.74, MAT_IRON)
    wk.add_cyl(search, (1.55, 0.0, 9.48), (1.55, 0.0, 9.70), 0.08, 0.08,
               MAT_IRON, 8)
    search.add(bar_between((1.55, 0.0, 9.60), (1.95, 0.0, 9.72), 0.06),
               MAT_IRON)
    wk.add_cyl(search, (2.05, 0.0, 9.68), (2.62, 0.0, 9.68), 0.20, 0.24,
               MAT_METAL, 10)
    wk.add_cyl(search, (2.62, 0.0, 9.68), (2.66, 0.0, 9.68), 0.24, 0.24,
               MAT_GLASS_DARK, 10)
    wk.add_torus(search, (2.05, 0.0, 9.68), (1.0, 0.0, 0.0), 0.20, 0.04,
                 MAT_BRASS, seg=10, tube=3)
    parts[prefix + "Lamp"] = (search, "ROOT")

    return parts


# ---------------------------------------------------------------- 装配配置

BUILDERS = {
    "SN_Base_Sawmill": _build_sawmill,
    "SN_Base_Smelter": _build_smelter,
    "SN_Base_Foundry": _build_foundry,
    "SN_Base_Stockyard": _build_stockyard,
    "SN_Base_Defense_Tower": _build_defense_tower,
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
        "production": bool(spec.get("production", False)),
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
    print("KIT_BATCH5_REPORT %r" % {
        "assets": {asset: out[asset]["tris"] for asset in ASSETS},
        "total_tris": sum(v["tris"] for v in out.values()),
    })
    return out


if __name__ == "__main__":
    build_all_kits()
    report()
