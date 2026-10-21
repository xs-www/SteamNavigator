# -*- coding: utf-8 -*-
# @static-doc
# 作用：舰载武器五件套（甲板速射炮 / 重型舰炮 / 曲射迫击炮 / 机关连发炮 / 侧弦炮列）
# 的参数化生成器与 Blender 装配入口。
#
# 工单：`tools/modeling/briefs/sn_weapon_batch1.json`
# 集合：每件武器一个 `SN_Weapon_<Name>_Prototype`；根节点 `SN_Weapon_<Name>_Root`
# 轴心：炮座底面中心（z = 0），+X 为炮口方向，+Z 向上，1 unit = 1 m。
# 层级：Root → Yaw_Pivot（绕 Z 回转）→ Pitch_Pivot（绕 Y 俯仰，轴心在耳轴）。
# 侧弦炮列沿 Y 排 4 门炮、共用一条回转滑轨，因此上船时绕 Z 旋转 -90° 让炮口朝舷外。
#
# 用法：
# - Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
# - 纯 Python 干跑：`python tools/modeling/generators/dryrun_weapon_batch1.py`
# - 导出 GLB：`python tools/modeling/generators/export_weapon_glb.py`
# @end-static-doc

import math
import os
import sys


def _generator_dir():
    """定位 tools/modeling/generators（dryrun / Blender MCP / runpy 通用）。"""
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

import weapon_kit as wk
from ship_parts.core import Part

from sn_weapon_materials import (
    ASSET_MATERIALS,
    MAT_BRASS,
    MAT_CANVAS_SHADE,
    MAT_GLASS_DARK,
    MAT_IRON,
    MAT_IRON_RED,
    MAT_METAL,
    MAT_WOOD,
    MAT_WOOD_DARK,
    colors_for,
)

ASSETS = [
    "SN_Weapon_DeckGun",
    "SN_Weapon_HeavyCannon",
    "SN_Weapon_Mortar",
    "SN_Weapon_Repeater",
    "SN_Weapon_Broadside",
]

WORKBENCH_POS = {
    "SN_Weapon_DeckGun": (0.0, 320.0, 0.0),
    "SN_Weapon_HeavyCannon": (0.0, 330.0, 0.0),
    "SN_Weapon_Mortar": (0.0, 340.0, 0.0),
    "SN_Weapon_Repeater": (0.0, 350.0, 0.0),
    "SN_Weapon_Broadside": (0.0, 360.0, 0.0),
}

# 每件武器：集合 / 前缀 / 根节点 / 类型 / 三角面预算 / 包围盒目标与容差 / 必含对象
SPECS = {
    "SN_Weapon_DeckGun": {
        "collection": "SN_Weapon_DeckGun_Prototype",
        "prefix": "SN_Weapon_DeckGun_",
        "type": "deck quick-firing gun",
        "tri_budget": 2600,
        "bbox": (2.80, 1.40, 1.60),
        "tol": 0.05,
        "required": ("Deck_Plate", "Pedestal", "Shield", "Barrel"),
    },
    "SN_Weapon_HeavyCannon": {
        "collection": "SN_Weapon_HeavyCannon_Prototype",
        "prefix": "SN_Weapon_HeavyCannon_",
        "type": "heavy naval cannon on slide mount",
        "tri_budget": 4000,
        "bbox": (4.80, 2.20, 2.20),
        "tol": 0.08,
        "required": ("Platform", "Slide", "Shield", "Barrel"),
    },
    "SN_Weapon_Mortar": {
        "collection": "SN_Weapon_Mortar_Prototype",
        "prefix": "SN_Weapon_Mortar_",
        "type": "high-angle mortar",
        "tri_budget": 2600,
        "bbox": (3.20, 2.20, 2.60),
        "tol": 0.08,
        "required": ("Platform", "Cradle", "Barrel", "Shell_Rack"),
    },
    "SN_Weapon_Repeater": {
        "collection": "SN_Weapon_Repeater_Prototype",
        "prefix": "SN_Weapon_Repeater_",
        "type": "steam-powered rotary repeater",
        "tri_budget": 4000,
        "bbox": (2.80, 1.60, 1.80),
        "tol": 0.08,
        "required": ("Platform", "Pedestal", "Barrels", "Hopper"),
    },
    "SN_Weapon_Broadside": {
        "collection": "SN_Weapon_Broadside_Prototype",
        "prefix": "SN_Weapon_Broadside_",
        "type": "four-gun broadside battery on shared slide",
        "tri_budget": 5500,
        "bbox": (2.20, 8.00, 2.00),
        "tol": 0.10,
        "required": ("Platform", "Rail", "Carriages", "Tool_Rack"),
    },
}

BROADSIDE_Y = (-2.70, -0.90, 0.90, 2.70)


# ---------------------------------------------------------------- 甲板速射炮

def _deck_gun():
    prefix = "SN_Weapon_DeckGun_"
    parts = {}

    root = Part()
    wk.deck_plate(root, -0.80, 0.80, -0.60, 0.60, 0.0, 0.12, MAT_IRON,
                  bolts=4, inset=0.14)
    wk.add_box(root, (-0.56, -0.40, 0.12), (0.56, 0.40, 0.17), MAT_METAL)
    for sy in (-1.0, 1.0):
        wk.add_bar(root, (-0.65, sy * 0.48, 0.12), (-0.35, sy * 0.48, 0.34),
                   0.08, MAT_IRON_RED)
    parts[prefix + "Deck_Plate"] = (root, "ROOT")

    pedestal = Part()
    wk.add_cyl(pedestal, (0.0, 0.0, 0.12), (0.0, 0.0, 0.30), 0.60, 0.51,
               MAT_IRON, 12)
    wk.add_cyl(pedestal, (0.0, 0.0, 0.30), (0.0, 0.0, 0.56), 0.43, 0.36,
               MAT_METAL, 10)
    wk.add_cyl(pedestal, (0.0, 0.0, 0.56), (0.0, 0.0, 0.84), 0.32, 0.29,
               MAT_IRON, 8)
    wk.add_box(pedestal, (-0.20, -0.28, 0.84), (0.22, 0.28, 1.00), MAT_METAL)
    wk.cheek_pair(pedestal, -0.12, 0.56, 0.42, 0.13, 0.88, 1.14, MAT_IRON)
    wk.add_box(pedestal, (-0.10, -0.34, 0.88), (0.16, 0.34, 0.97), MAT_METAL)
    wk.add_bar(pedestal, (-0.55, 0.0, 0.40), (0.46, 0.0, 0.40), 0.10, MAT_METAL)
    wk.add_cyl(pedestal, (-0.62, 0.0, 0.55), (-0.62, 0.0, 0.95), 0.07, 0.07,
               MAT_METAL, 8)
    wk.handwheel(pedestal, (-0.60, 0.56, 0.92), (0.0, 1.0, 0.0), 0.18,
                 MAT_BRASS, spokes=4, hub_r=0.05)
    wk.elevation_arc(pedestal, 0.20, 1.00, 0.52, 0.47, -10.0, 55.0, 8,
                     0.055, 0.08, 0.05, MAT_METAL)
    parts[prefix + "Pedestal"] = (pedestal, "YAW")

    shield = Part()
    for sy in (-1.0, 1.0):
        wk.add_box(shield, (-0.50, sy * 0.58, 0.40), (0.46, sy * 0.69, 1.60),
                   MAT_IRON_RED)
        wk.rivet_row(shield, (-0.44, sy * 0.695, 0.52),
                     (0.40, sy * 0.695, 0.52), 5, (0.0, 1.0, 0.0),
                     0.032, 0.02, MAT_BRASS)
        wk.add_box(shield, (-0.55, sy * 0.56, 1.50), (-0.22, sy * 0.69, 1.60),
                   MAT_IRON_RED)
    wk.add_box(shield, (-0.56, -0.69, 1.50), (-0.22, 0.69, 1.60), MAT_IRON_RED)
    parts[prefix + "Shield"] = (shield, "YAW")

    pitch = Part()
    wk.barrel_x(pitch, -0.70, 2.00, 1.00, 0.16, 0.115, MAT_IRON, sides=12,
                rings=((-0.42, 0.19, 0.10), (0.18, 0.17, 0.09),
                       (0.92, 0.14, 0.08)),
                muzzle=(0.17, 0.10))
    wk.add_cyl(pitch, (-0.30, 0.0, 1.00), (0.58, 0.0, 1.00), 0.215, 0.205,
               MAT_METAL, 10)
    for x in (-0.22, 0.10, 0.42):
        wk.add_cyl(pitch, (x - 0.025, 0.0, 1.00), (x + 0.025, 0.0, 1.00),
                   0.230, 0.230, MAT_BRASS, 10)
    wk.add_box(pitch, (-0.70, -0.28, 0.82), (-0.44, 0.28, 1.18), MAT_IRON)
    wk.add_cyl(pitch, (-0.80, 0.0, 1.00), (-0.70, 0.0, 1.00), 0.09, 0.09,
               MAT_BRASS, 8)
    wk.trunnion(pitch, 0.20, 1.00, 0.96, 0.13, MAT_METAL)
    for sy in (-1.0, 1.0):
        wk.add_box(pitch, (-0.34, sy * 0.16, 0.86), (0.92, sy * 0.26, 0.92),
                   MAT_METAL)
        wk.add_cyl(pitch, (-0.26, sy * 0.26, 0.89), (0.84, sy * 0.26, 0.89),
                   0.050, 0.050, MAT_BRASS, 6)
    wk.add_cyl(pitch, (0.44, 0.0, 1.10), (0.44, 0.0, 1.54), 0.022, 0.022,
               MAT_METAL, 6)
    wk.add_torus(pitch, (0.44, 0.0, 1.54), (0.0, 1.0, 0.0), 0.065, 0.012,
                 MAT_BRASS, seg=10, tube=4)
    for sy in (-1.0, 1.0):
        wk.add_bar(pitch, (-0.60, sy * 0.28, 1.00), (-0.44, sy * 0.28, 1.14),
                   0.05, MAT_METAL)
    parts[prefix + "Barrel"] = (pitch, "PITCH")
    return parts


# ---------------------------------------------------------------- 重型舰炮

def _heavy_cannon():
    prefix = "SN_Weapon_HeavyCannon_"
    parts = {}

    root = Part()
    wk.add_box(root, (-1.80, -0.90, 0.0), (1.80, 0.90, 0.18), MAT_WOOD)
    for sy in (-1.0, 1.0):
        wk.add_box(root, (-1.80, sy * 0.55, 0.18), (1.80, sy * 0.68, 0.30),
                   MAT_IRON)
    for x in (-1.55, -0.75, 0.05, 0.85, 1.55):
        wk.add_box(root, (x - 0.07, -0.66, 0.18), (x + 0.07, 0.66, 0.27),
                   MAT_METAL)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            wk.add_box(root, (sx * 1.62 - 0.10, sy * 0.78 - 0.10, 0.18),
                       (sx * 1.62 + 0.10, sy * 0.78 + 0.10, 0.24), MAT_METAL)
            wk.add_bolt(root, (sx * 1.62, sy * 0.78, 0.27), 0.05, 0.07,
                        MAT_BRASS)
    parts[prefix + "Platform"] = (root, "ROOT")

    slide = Part()
    wk.add_cyl(slide, (0.0, 0.0, 0.18), (0.0, 0.0, 0.34), 0.88, 0.80,
               MAT_IRON, 12)
    for sy in (-1.0, 1.0):
        wk.add_box(slide, (-1.35, sy * 0.55, 0.35), (1.25, sy * 0.68, 0.72),
                   MAT_IRON)
    for x in (-1.25, -0.45, 0.35, 1.10):
        wk.add_box(slide, (x - 0.08, -0.66, 0.35), (x + 0.08, 0.66, 0.46),
                   MAT_METAL)
    wk.cheek_pair(slide, 0.00, 0.46, 0.70, 0.20, 0.72, 1.36, MAT_IRON_RED)
    parts[prefix + "Slide"] = (slide, "YAW")

    shield = Part()
    for sy in (-1.0, 1.0):
        wk.add_box(shield, (0.50, sy * 0.82, 0.45), (0.82, sy * 1.00, 2.00),
                   MAT_IRON_RED)
        wk.rivet_row(shield, (0.66, sy * 1.01, 0.55),
                     (0.66, sy * 1.01, 1.10), 3, (0.0, 1.0, 0.0),
                     0.030, 0.02, MAT_BRASS)
        wk.rivet_row(shield, (0.66, sy * 1.01, 1.30),
                     (0.66, sy * 1.01, 1.75), 2, (0.0, 1.0, 0.0),
                     0.030, 0.02, MAT_BRASS)
    wk.add_box(shield, (0.50, -1.00, 1.92), (0.82, 1.00, 2.02), MAT_IRON_RED)
    wk.add_box(shield, (0.50, -1.00, 0.45), (0.82, 1.00, 0.60), MAT_IRON_RED)
    wk.add_cyl(shield, (0.66, 0.0, 2.02), (0.66, 0.0, 2.20), 0.035, 0.030,
               MAT_METAL, 6)
    wk.add_bar(shield, (0.58, -0.10, 2.18), (0.74, 0.10, 2.18), 0.035,
               MAT_METAL)
    parts[prefix + "Shield"] = (shield, "YAW")

    elevation = Part()
    wk.elevation_arc(elevation, 0.20, 1.05, 0.72, 0.82, -25.0, 45.0, 9,
                     0.060, 0.085, 0.05, MAT_METAL)
    for sy in (-1.0, 1.0):
        wk.handwheel(elevation, (-0.55, sy * 1.04, 1.02), (0.0, 1.0, 0.0),
                     0.20, MAT_BRASS, spokes=4, hub_r=0.055)
        wk.add_cyl(elevation, (-0.55, sy * 0.72, 0.86),
                   (-0.55, sy * 0.72, 1.02), 0.045, 0.045, MAT_METAL, 6)
    wk.add_cyl(elevation, (-0.85, -0.55, 0.35), (-0.85, -0.55, 1.00),
               0.07, 0.07, MAT_METAL, 8)
    wk.add_cyl(elevation, (-0.85, 0.55, 0.35), (-0.85, 0.55, 1.00),
               0.07, 0.07, MAT_METAL, 8)
    for sy in (-1.0, 1.0):
        wk.rope_loop(elevation, (-1.15, sy * 0.62, 0.76), (0.0, 1.0, 0.0),
                     0.10, 0.025, MAT_CANVAS_SHADE)
    parts[prefix + "Elevation"] = (elevation, "YAW")

    pitch = Part()
    wk.barrel_x(pitch, -0.70, 3.00, 1.05, 0.30, 0.22, MAT_IRON, sides=12,
                rings=((-0.45, 0.34, 0.12), (0.35, 0.33, 0.10),
                       (1.50, 0.29, 0.09), (2.40, 0.25, 0.09)),
                muzzle=(0.34, 0.12))
    wk.add_box(pitch, (-0.95, -0.32, 0.75), (-0.68, 0.32, 1.35), MAT_IRON)
    wk.add_cyl(pitch, (-1.10, 0.0, 1.05), (-0.95, 0.0, 1.05), 0.10, 0.10,
               MAT_BRASS, 8)
    wk.trunnion(pitch, 0.20, 1.05, 1.52, 0.15, MAT_METAL)
    for sy in (-1.0, 1.0):
        wk.add_cyl(pitch, (-0.35, sy * 0.28, 0.91), (0.95, sy * 0.28, 0.91),
                   0.10, 0.10, MAT_METAL, 8)
        wk.add_cyl(pitch, (0.95, sy * 0.28, 0.91), (1.35, sy * 0.28, 0.91),
                   0.045, 0.045, MAT_BRASS, 6)
    wk.add_cyl(pitch, (-0.20, 0.0, 1.05), (0.10, 0.0, 1.05), 0.06, 0.06,
               MAT_BRASS, 6)
    parts[prefix + "Barrel"] = (pitch, "PITCH")
    return parts


# ---------------------------------------------------------------- 曲射迫击炮

def _mortar():
    prefix = "SN_Weapon_Mortar_"
    parts = {}

    platform = Part()
    wk.add_box(platform, (-1.60, -1.10, 0.0), (1.60, 1.10, 0.22),
               MAT_WOOD_DARK)
    wk.add_box(platform, (-1.05, -1.00, 0.22), (1.05, 1.00, 0.32), MAT_IRON)
    wk.bolt_circle(platform, (0.0, 0.0, 0.32), 0.88, 8, 0.05, 0.07, MAT_BRASS)
    for sy in (-1.0, 1.0):
        wk.add_box(platform, (-1.50, sy * 0.92, 0.22), (1.50, sy * 1.05, 0.34),
                   MAT_IRON_RED)
    parts[prefix + "Platform"] = (platform, "ROOT")

    rack = Part()
    for sy in (-1.0, 1.0):
        for x in (-1.52, -1.18):
            wk.add_box(rack, (x - 0.04, sy * 0.70 - 0.04, 0.22),
                       (x + 0.04, sy * 0.70 + 0.04, 1.05), MAT_METAL)
    wk.add_box(rack, (-1.56, -0.74, 0.62), (-1.14, 0.74, 0.68), MAT_METAL)
    wk.add_box(rack, (-1.56, -0.74, 0.92), (-1.14, 0.74, 0.98), MAT_IRON)
    for y in (-0.48, 0.0, 0.48):
        wk.shell(rack, (-1.35, y, 0.68), 0.30, 0.115, MAT_IRON,
                 axis=(0.0, 0.0, 1.0))
        wk.add_cyl(rack, (-1.35, y, 0.68), (-1.35, y, 0.74), 0.115, 0.115,
                   MAT_BRASS, 8)
    parts[prefix + "Shell_Rack"] = (rack, "ROOT")

    yaw = Part()
    wk.add_cyl(yaw, (0.0, 0.0, 0.32), (0.0, 0.0, 0.46), 0.72, 0.66, MAT_IRON, 12)
    wk.cheek_pair(yaw, -0.45, 0.45, 0.62, 0.18, 0.46, 1.58, MAT_IRON_RED)
    wk.trunnion(yaw, 0.0, 1.45, 1.30, 0.16, MAT_METAL)
    wk.elevation_arc(yaw, 0.0, 1.45, 0.70, 0.72, 20.0, 70.0, 8,
                     0.060, 0.085, 0.05, MAT_METAL)
    wk.add_box(yaw, (-0.90, -0.24, 0.32), (-0.70, 0.24, 0.44), MAT_METAL)
    wk.add_cyl(yaw, (-0.80, 0.0, 0.44), (-0.80, 0.0, 1.30), 0.065, 0.065,
               MAT_METAL, 8)
    wk.handwheel(yaw, (-0.80, 0.42, 1.27), (0.0, 1.0, 0.0), 0.18, MAT_BRASS,
                 spokes=4, hub_r=0.05)
    wk.add_bar(yaw, (-0.80, -0.40, 1.30), (-0.34, -0.40, 1.47), 0.07,
               MAT_METAL)
    # 蒸汽助力筒：横置在摇架侧面，给高角俯仰提供助力
    wk.add_cyl(yaw, (-0.55, -0.50, 0.62), (0.30, -0.50, 0.62), 0.11, 0.09,
               MAT_BRASS, 8)
    wk.add_cyl(yaw, (0.30, -0.50, 0.62), (0.40, -0.50, 0.62), 0.055, 0.055,
               MAT_METAL, 6)
    wk.add_cyl(yaw, (-0.55, -0.50, 0.62), (-0.65, -0.50, 0.62), 0.055, 0.055,
               MAT_METAL, 6)
    for sy in (-1.0, 1.0):
        wk.add_box(yaw, (-0.46, sy * 0.60, 1.45), (0.46, sy * 0.74, 1.57),
                   MAT_IRON)
    parts[prefix + "Cradle"] = (yaw, "YAW")

    tube = Part()
    wk.barrel_x(tube, -0.95, 1.10, 0.0, 0.36, 0.30, MAT_IRON, sides=14,
                rings=((-0.70, 0.40, 0.12), (0.55, 0.34, 0.10)),
                muzzle=(0.44, 0.12))
    wk.add_box(tube, (-1.10, -0.20, -0.18), (-0.95, 0.20, 0.18), MAT_IRON)
    wk.add_cyl(tube, (-1.22, 0.0, 0.0), (-1.10, 0.0, 0.0), 0.09, 0.09,
               MAT_BRASS, 8)
    # 炮口内膛：深色玻璃圆盘 + 黄铜口沿，低模下读出“洞口”
    wk.add_cyl(tube, (1.10, 0.0, 0.0), (1.12, 0.0, 0.0), 0.30, 0.30,
               MAT_GLASS_DARK, 12)
    wk.add_torus(tube, (1.12, 0.0, 0.0), (1.0, 0.0, 0.0), 0.33, 0.030,
                 MAT_BRASS, seg=12, tube=4)
    pitch = wk.transform(tube, rot_y_deg=-60.0, offset=(0.0, 0.0, 1.45))
    wk.add_cyl(pitch, (0.0, -0.62, 1.45), (0.0, 0.62, 1.45), 0.16, 0.16,
               MAT_METAL, 8)
    wk.add_cyl(pitch, (0.95, -0.06, 2.35), (0.95, 0.06, 2.35), 0.04, 0.04,
               MAT_BRASS, 6)
    parts[prefix + "Barrel"] = (pitch, "PITCH")
    return parts


# ---------------------------------------------------------------- 机关连发炮

def _repeater():
    prefix = "SN_Weapon_Repeater_"
    parts = {}

    root = Part()
    wk.deck_plate(root, -1.40, 0.60, -0.80, 0.80, 0.0, 0.15, MAT_IRON,
                  bolts=4, inset=0.16)
    wk.add_box(root, (-1.40, -0.35, 0.15), (-0.74, 0.35, 0.95), MAT_IRON_RED)
    for x in (-1.28, -1.02, -0.86):
        wk.rivet_row(root, (x, -0.36, 0.30), (x, -0.36, 0.86), 4,
                     (0.0, -1.0, 0.0), 0.026, 0.03, MAT_BRASS)
    wk.add_box(root, (-1.34, -0.28, 0.95), (-0.80, 0.28, 1.02), MAT_METAL)
    wk.add_cyl(root, (-1.24, 0.0, 1.02), (-1.24, 0.0, 1.26), 0.055, 0.045,
               MAT_METAL, 8)
    wk.add_cyl(root, (-1.24, 0.0, 1.26), (-1.24, 0.0, 1.32), 0.075, 0.075,
               MAT_IRON, 8)
    wk.spoked_wheel(root, (-1.10, -0.50, 0.56), (0.0, 1.0, 0.0), 0.34, 0.10,
                    MAT_METAL, spokes=6, rim_r=0.05)
    wk.add_cyl(root, (-1.10, -0.35, 0.56), (-1.10, -0.55, 0.56), 0.06, 0.06,
               MAT_IRON, 8)
    wk.add_cyl(root, (0.0, 0.0, 0.15), (0.0, 0.0, 0.28), 0.55, 0.50, MAT_IRON,
               12)
    parts[prefix + "Platform"] = (root, "ROOT")

    yaw = Part()
    wk.add_cyl(yaw, (0.0, 0.0, 0.28), (0.0, 0.0, 1.05), 0.22, 0.20, MAT_METAL,
               10)
    for sy in (-1.0, 1.0):
        wk.add_bar(yaw, (0.0, 0.0, 0.62), (0.0, sy * 0.52, 0.28), 0.09,
                   MAT_IRON)
    wk.add_bar(yaw, (0.0, 0.0, 0.62), (0.46, 0.0, 0.28), 0.09, MAT_IRON)
    wk.add_bar(yaw, (0.0, 0.0, 0.62), (-0.46, 0.0, 0.28), 0.09, MAT_IRON)
    wk.cheek_pair(yaw, -0.26, 0.22, 0.45, 0.14, 0.88, 1.26, MAT_IRON_RED)
    wk.add_box(yaw, (-0.28, -0.52, 0.96), (0.24, 0.52, 1.04), MAT_METAL)
    wk.steam_pipe(yaw, [(-1.24, 0.0, 1.02), (-0.90, 0.30, 1.20),
                        (-0.34, 0.30, 1.14), (-0.18, 0.28, 1.18)],
                  0.045, MAT_BRASS)
    parts[prefix + "Pedestal"] = (yaw, "YAW")

    barrels = Part()
    for i in range(6):
        ang = math.radians(i * 60.0)
        y = 0.16 * math.cos(ang)
        z = 1.05 + 0.16 * math.sin(ang)
        wk.add_cyl(barrels, (-0.25, y, z), (1.34, y, z), 0.055, 0.052,
                   MAT_IRON, 8)
        wk.add_cyl(barrels, (1.26, y, z), (1.34, y, z), 0.070, 0.070,
                   MAT_BRASS, 8)
        wk.add_cyl(barrels, (-0.20, y, z), (-0.12, y, z), 0.070, 0.070,
                   MAT_METAL, 8)
    wk.add_cyl(barrels, (-0.42, 0.0, 1.05), (1.30, 0.0, 1.05), 0.09, 0.09,
               MAT_METAL, 8)
    wk.add_cyl(barrels, (-0.52, 0.0, 1.05), (0.12, 0.0, 1.05), 0.32, 0.30,
               MAT_BRASS, 12)
    wk.add_cyl(barrels, (1.10, 0.0, 1.05), (1.18, 0.0, 1.05), 0.28, 0.28,
               MAT_IRON, 12)
    wk.add_torus(barrels, (1.34, 0.0, 1.05), (1.0, 0.0, 0.0), 0.24, 0.025,
                 MAT_IRON, seg=12, tube=4)
    wk.add_cyl(barrels, (0.45, 0.0, 1.10), (0.45, 0.0, 1.80), 0.020, 0.020,
               MAT_METAL, 6)
    wk.add_torus(barrels, (0.45, 0.0, 1.80), (0.0, 1.0, 0.0), 0.055, 0.010,
                 MAT_BRASS, seg=10, tube=4)
    wk.add_cyl(barrels, (-0.12, 0.35, 1.05), (-0.12, 0.66, 1.05), 0.040,
               0.040, MAT_METAL, 6)
    wk.add_bar(barrels, (-0.12, 0.66, 1.05), (-0.12, 0.66, 1.28), 0.05,
               MAT_METAL)
    wk.add_cyl(barrels, (-0.12, 0.66, 1.28), (-0.12, 0.64, 1.34), 0.04, 0.04,
               MAT_BRASS, 6)
    parts[prefix + "Barrels"] = (barrels, "PITCH")

    hopper = Part()
    wk.add_frustum(hopper, 1.30, 1.48, 0.20, 0.28, MAT_IRON_RED,
                   center=(0.15, 0.0))
    wk.add_box(hopper, (-0.08, -0.30, 1.48), (0.38, 0.30, 1.53), MAT_BRASS)
    wk.add_box(hopper, (0.10, -0.18, 1.20), (0.20, 0.18, 1.30), MAT_IRON)
    parts[prefix + "Hopper"] = (hopper, "PITCH")
    return parts


# ---------------------------------------------------------------- 侧弦炮列

def _broadside_gun(prefix, index, gun_y):
    pitch = Part()
    wk.barrel_x(pitch, -0.55, 1.50, 0.90, 0.18, 0.145, MAT_IRON, sides=10,
                rings=((-0.38, 0.21, 0.08), (0.42, 0.19, 0.07)),
                muzzle=(0.21, 0.08))
    wk.add_box(pitch, (-0.55, -0.22, 0.72), (-0.34, 0.22, 1.08), MAT_IRON)
    wk.add_cyl(pitch, (-0.68, 0.0, 0.90), (-0.55, 0.0, 0.90), 0.075, 0.075,
               MAT_BRASS, 8)
    wk.trunnion(pitch, 0.10, 0.90, 0.76, 0.10, MAT_METAL)
    wk.add_cyl(pitch, (-0.20, 0.0, 0.76), (0.42, 0.0, 0.76), 0.06, 0.06,
               MAT_METAL, 8)
    wk.add_cyl(pitch, (0.42, 0.0, 0.76), (0.58, 0.0, 0.76), 0.035, 0.035,
               MAT_BRASS, 6)
    wk.add_bar(pitch, (-0.30, 0.0, 1.04), (0.10, 0.0, 1.10), 0.05, MAT_METAL)
    pitch = wk.transform(pitch, rot_y_deg=0.0, offset=(0.0, gun_y, 0.0))
    return {prefix + "Gun_%d_Barrel" % index: (pitch, "PITCH_%d" % index)}


def _broadside():
    prefix = "SN_Weapon_Broadside_"
    parts = {}

    root = Part()
    wk.deck_plate(root, -0.70, 0.70, -4.00, 4.00, 0.0, 0.20, MAT_WOOD,
                  bolts=8, bolt_r=0.06, inset=0.10)
    for sy in (-1.0, 1.0):
        wk.add_box(root, (-0.70, sy * 3.40, 0.20), (0.70, sy * 3.70, 0.62),
                   MAT_IRON_RED)
        wk.add_box(root, (-0.62, sy * 3.72, 0.20), (0.62, sy * 3.80, 0.52),
                   MAT_IRON)
        for sx in (-1.0, 1.0):
            wk.add_bolt(root, (sx * 0.50, sy * 3.55, 0.62), 0.05, 0.07,
                        MAT_BRASS)
    parts[prefix + "Platform"] = (root, "ROOT")

    rail = Part()
    wk.add_box(rail, (-0.45, -3.90, 0.20), (0.45, 3.90, 0.40), MAT_IRON)
    wk.add_box(rail, (-0.30, -3.90, 0.32), (0.30, 3.90, 0.38), MAT_METAL)
    parts[prefix + "Rail"] = (rail, "YAW")

    carriages = Part()
    for y in BROADSIDE_Y:
        wk.add_box(carriages, (-0.50, y - 0.42, 0.40), (0.50, y + 0.42, 0.78),
                   MAT_WOOD_DARK)
        wk.add_box(carriages, (-0.54, y - 0.30, 0.40), (-0.46, y + 0.30, 0.72),
                   MAT_IRON)
        wk.cheek_pair(carriages, -0.30, 0.34, 0.34, 0.12, 0.72, 1.04,
                      MAT_IRON_RED, y_center=y)
        wk.add_box(carriages, (-0.20, y - 0.30, 0.78), (0.16, y + 0.30, 0.86),
                   MAT_METAL)
        for sy in (-1.0, 1.0):
            wk.add_bar(carriages, (-0.44, y + sy * 0.34, 0.52),
                       (-0.72, y + sy * 0.34, 0.32), 0.05, MAT_METAL)
            wk.rope_loop(carriages, (-0.55, y + sy * 0.34, 0.58),
                         (0.0, 1.0, 0.0), 0.075, 0.020, MAT_CANVAS_SHADE)
        wk.elevation_arc(carriages, 0.10, 0.90, 0.48, y + 0.40, -10.0, 45.0,
                         6, 0.045, 0.065, 0.04, MAT_METAL)
    parts[prefix + "Carriages"] = (carriages, "YAW")

    shields = Part()
    for y in BROADSIDE_Y:
        for sy in (-1.0, 1.0):
            wk.add_box(shields, (0.36, y + sy * 0.18, 0.55),
                       (0.46, y + sy * 0.40, 1.25), MAT_IRON_RED)
            wk.rivet_row(shields, (0.47, y + sy * 0.22, 0.70),
                         (0.47, y + sy * 0.36, 0.70), 2, (1.0, 0.0, 0.0),
                         0.018, 0.02, MAT_BRASS)
    parts[prefix + "Gun_Shields"] = (shields, "YAW")

    tool_rack = Part()
    for y in (-3.82, -3.64):
        wk.add_box(tool_rack, (-0.34, y - 0.03, 0.40), (-0.28, y + 0.03, 1.90),
                   MAT_METAL)
    wk.add_box(tool_rack, (-0.36, -3.86, 1.84), (-0.26, -3.60, 1.90),
               MAT_METAL)
    wk.add_box(tool_rack, (-0.36, -3.86, 1.18), (-0.26, -3.60, 1.24),
               MAT_METAL)
    for y, length in ((-3.73, 1.10), (-3.66, 0.86)):
        wk.add_cyl(tool_rack, (-0.31, y, 0.55), (-0.31, y, 0.55 + length),
                   0.035, 0.035, MAT_WOOD_DARK, 6)
    parts[prefix + "Tool_Rack"] = (tool_rack, "YAW")

    for i, y in enumerate(BROADSIDE_Y, start=1):
        sub = _broadside_gun(prefix, i, y)
        parts.update(sub)
    # 2 号炮的瞄准具拉到 2.0 m，保证总高目标
    y = BROADSIDE_Y[1]
    pitch = Part()
    wk.add_cyl(pitch, (0.42, y, 1.10), (0.42, y, 2.00), 0.020, 0.020,
               MAT_METAL, 6)
    wk.add_torus(pitch, (0.42, y, 2.00), (0.0, 1.0, 0.0), 0.050, 0.010,
                 MAT_BRASS, seg=10, tube=4)
    parts[prefix + "Sight"] = (pitch, "PITCH_2")
    return parts


GEOMETRY_BUILDERS = {
    "SN_Weapon_DeckGun": _deck_gun,
    "SN_Weapon_HeavyCannon": _heavy_cannon,
    "SN_Weapon_Mortar": _mortar,
    "SN_Weapon_Repeater": _repeater,
    "SN_Weapon_Broadside": _broadside,
}


def build_geometry(asset):
    parts = GEOMETRY_BUILDERS[asset]()
    # 装配规范 v2：炮身 / 炮管挂到 Recoil，固定舷侧炮去掉 Yaw 层
    out = {}
    for name, (part, parent) in parts.items():
        if parent.startswith("PITCH"):
            parent = "RECOIL" + parent[len("PITCH"):]
        if asset == "SN_Weapon_Broadside" and parent == "YAW":
            parent = "ROOT"
        out[name] = (part, parent)
    return out


# ---------------------------------------------------------------- 装配配置

PITCH_LOCATIONS = {
    "SN_Weapon_DeckGun": (0.20, 0.0, 1.00),
    "SN_Weapon_HeavyCannon": (0.20, 0.0, 1.05),
    "SN_Weapon_Mortar": (0.0, 0.0, 1.45),
    "SN_Weapon_Repeater": (0.0, 0.0, 1.05),
}


def _muzzle_tip(parts, parent_key):
    """取挂在该 pivot 下的炮身网格里 X 最大的顶点（炮口端面中心）。"""
    best = None
    for _name, (part, parent) in parts.items():
        if parent != parent_key:
            continue
        for v in part.verts:
            if best is None or v[0] > best[0]:
                best = v
    return best


def _pivot_specs(asset):
    """武器装配规范 v2 的标准节点（Blender 内用资产前缀避免重名，导出 GLB 时归一为标准名）。"""
    prefix = SPECS[asset]["prefix"]
    parts = build_geometry(asset)
    specs = [{"key": "MOUNT", "name": prefix + "Mount", "parent": "ROOT",
              "location": (0.0, 0.0, 0.0)}]
    if asset == "SN_Weapon_Broadside":
        for i, y in enumerate(BROADSIDE_Y, start=1):
            loc = (0.10, y, 0.90)
            specs.append({"key": "PITCH_%d" % i,
                          "name": prefix + "Pivot_Pitch_%d" % i,
                          "parent": "ROOT", "location": loc})
            specs.append({"key": "RECOIL_%d" % i,
                          "name": prefix + "Recoil_%d" % i,
                          "parent": "PITCH_%d" % i,
                          "location": (0.0, 0.0, 0.0),
                          "origin": loc})
            tip = _muzzle_tip(parts, "RECOIL_%d" % i) or loc
            specs.append({"key": "MUZZLE_%d" % i,
                          "name": prefix + "Muzzle_%d" % i,
                          "parent": "RECOIL_%d" % i,
                          "location": (tip[0] - loc[0], tip[1] - loc[1],
                                       tip[2] - loc[2])})
        return specs
    pitch_loc = PITCH_LOCATIONS[asset]
    specs.extend([
        {"key": "YAW", "name": prefix + "Pivot_Yaw", "parent": "ROOT",
         "location": (0.0, 0.0, 0.0)},
        {"key": "PITCH", "name": prefix + "Pivot_Pitch", "parent": "YAW",
         "location": pitch_loc},
        {"key": "RECOIL", "name": prefix + "Recoil", "parent": "PITCH",
         "location": (0.0, 0.0, 0.0), "origin": pitch_loc},
    ])
    tip = _muzzle_tip(parts, "RECOIL") or pitch_loc
    specs.append({"key": "MUZZLE", "name": prefix + "Muzzle", "parent": "RECOIL",
                  "location": (tip[0] - pitch_loc[0], tip[1] - pitch_loc[1],
                               tip[2] - pitch_loc[2])})
    return specs


MOUNT_CLASS = {
    "SN_Weapon_DeckGun": "Light",
    "SN_Weapon_HeavyCannon": "Heavy",
    "SN_Weapon_Mortar": "Heavy",
    "SN_Weapon_Repeater": "Medium",
    "SN_Weapon_Broadside": "Side",
}


def build_config(asset, origin=None):
    from ship_parts.assembly import BuildConfig, PivotSpec

    spec = SPECS[asset]
    prefix = spec["prefix"]
    pivots = [PivotSpec(p["key"], p["name"], p["location"],
                        parent=p["parent"]) for p in _pivot_specs(asset)]
    origins = {p["key"]: p.get("origin", p["location"])
               for p in _pivot_specs(asset)}
    pos = origin if origin is not None else WORKBENCH_POS[asset]
    broadside = asset == "SN_Weapon_Broadside"
    root_props = {
        "asset": asset,
        "version": "2.0",
        "units": "metres",
        "assembly_spec": "weapon-assembly@2",
        "weapon_class": MOUNT_CLASS[asset],
        "assembly_profile": "pitch_only" if broadside else "yaw_pitch",
        "socket": "SN_Socket_Weapon",
        "mount": "SN_Mount",
        "pivot_yaw": "" if broadside else "SN_Pivot_Yaw",
        "pivot_pitch": "SN_Pivot_Pitch_1..4" if broadside else "SN_Pivot_Pitch",
        "recoil": "SN_Recoil_1..4" if broadside else "SN_Recoil",
        "muzzle": "SN_Muzzle_1..4" if broadside else "SN_Muzzle",
        "has_yaw": not broadside,
        "has_pitch": True,
        "has_recoil": True,
        "has_muzzle": True,
        "yaw_axis": "Z",
        "pitch_axis": "Y",
        "recoil_axis": "-X",
        "muzzle_count": 4 if broadside else 1,
        "pivot": "mount base centre (z=0), +X forward",
        "forward_axis": "+X (muzzle direction)",
        "collection": spec["collection"],
        "type": spec["type"],
        "tri_budget": spec["tri_budget"],
        "bbox_target": "%.2f x %.2f x %.2f m" % spec["bbox"],
        "base_footprint_x": float(spec["bbox"][0]),
        "base_footprint_y": float(spec["bbox"][1]),
        "envelope_x": float(spec["bbox"][0]),
        "envelope_y": float(spec["bbox"][1]),
        "height": float(spec["bbox"][2]),
    }
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

def build_all_weapons():
    """在 Blender 工作台里幂等重建五件武器集合；返回集合列表。"""
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
        print("TEXTURED %s: %d 对象 / %d 材质 / UV loops=%d" % (
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
        verification = shared.verify_collection(bpy.data.collections[cfg.collection])
        print("共享贴图验收 %s: %s (%d 网格, 失败 %d)" % (
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
    print("WEAPON_BATCH1_REPORT %r" % {
        "assets": {asset: out[asset]["tris"] for asset in ASSETS},
        "total_tris": sum(v["tris"] for v in out.values()),
    })
    return out


if __name__ == "__main__":
    build_all_weapons()
    report()
