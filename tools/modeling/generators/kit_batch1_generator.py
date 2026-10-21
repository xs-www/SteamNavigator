# -*- coding: utf-8 -*-
# @static-doc
# 作用：模型素材库批次 1（武器套件 + 船体部件）的参数化生成器与 Blender 装配入口。
#
# 8 件模块化资产：SN_Weapon_Cannon / GunCarriage / Turret / Pedestal 与
# SN_ShipPart_Deck / Mast / Funnel / HatchCover。每件资产都提供固定的 Mount 空节点
# 与接口空节点（Trunnion / Socket / Exhaust / Hinge 等），Root 节点 extras 写
# kit_family / part_role / footprint / height，供后续搭船/搭场景按 socket 拼装。
#
# 工单：`tools/modeling/briefs/sn_kit_batch1.json`
# 约定：1 unit = 1 m；+X 前向、+Z 向上；地面类部件根在底面中心 z=0；
# 火炮是俯仰子件，根 = 耳轴轴心（Mount 在原点），由炮架 Trunnion_L/R 接收。
# 材质：共享贴图 `SN_Tex_*`（见 `sn_kit_materials.py`）+ 世界空间盒式 UV。
#
# 用法：
# - Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
# - 纯 Python 干跑：`python tools/modeling/generators/dryrun_kit_batch1.py`
# - 导出 GLB：`python tools/modeling/generators/export_kit_glb.py`
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
    box,
    hexa,
    taper_cyl,
    torus_x,
    torus_z,
    vadd,
    vcross,
    vlen,
    vmul,
    vnorm,
    vsub,
)

from sn_kit_materials import (  # noqa: E402
    ASSET_MATERIALS,
    MAT_BRASS,
    MAT_CANVAS_SHADE,
    MAT_GLASS_DARK,
    MAT_IRON,
    MAT_IRON_RED,
    MAT_METAL,
    MAT_WOOD,
    MAT_WOOD_DARK,
    MAT_WOOD_DECK,
    colors_for,
)

ASSETS = [
    "SN_Weapon_Cannon",
    "SN_Weapon_GunCarriage",
    "SN_Weapon_Turret",
    "SN_Weapon_Pedestal",
    "SN_ShipPart_Deck",
    "SN_ShipPart_Mast",
    "SN_ShipPart_Funnel",
    "SN_ShipPart_HatchCover",
]

WORKBENCH_POS = {
    "SN_Weapon_Cannon": (0.0, 440.0, 0.62),
    "SN_Weapon_GunCarriage": (5.0, 440.0, 0.0),
    "SN_Weapon_Turret": (0.0, 458.0, 0.0),
    "SN_Weapon_Pedestal": (6.0, 458.0, 0.0),
    "SN_ShipPart_Deck": (0.0, 476.0, 0.0),
    "SN_ShipPart_Mast": (0.0, 500.0, 0.0),
    "SN_ShipPart_Funnel": (0.0, 522.0, 0.0),
    "SN_ShipPart_HatchCover": (0.0, 543.0, 0.0),
}

SPECS = {
    "SN_Weapon_Cannon": {
        "collection": "SN_Weapon_Cannon_Prototype",
        "prefix": "SN_Weapon_Cannon_",
        "family": "weapon_kit",
        "role": "cannon",
        "type": "naval cannon barrel assembly",
        "tri_budget": 1400,
        "bbox": (4.00, 1.44, 0.82),
        "tol": 0.12,
        "zmin": -0.24,
        "mount_class": "Heavy",
        "base_footprint": (1.24, 0.88),
        "datum": "trunnion axis at origin; barrel axis +0.10 z; +X muzzle",
        "required": ("Barrel", "BreechBlock", "Trunnions", "Sight"),
    },
    "SN_Weapon_GunCarriage": {
        "collection": "SN_Weapon_GunCarriage_Prototype",
        "prefix": "SN_Weapon_GunCarriage_",
        "family": "weapon_kit",
        "role": "carriage",
        "type": "four-wheel naval gun carriage",
        "tri_budget": 2800,
        "bbox": (2.96, 1.79, 1.10),
        "tol": 0.12,
        "zmin": 0.0,
        "mount_class": "Heavy",
        "base_footprint": (1.30, 1.40),
        "datum": "ground z=0; trunnion sockets at z=0.62",
        "required": ("Wheels", "Axles", "Cheeks", "Trunnion_Caps", "Tools"),
    },
    "SN_Weapon_Turret": {
        "collection": "SN_Weapon_Turret_Prototype",
        "prefix": "SN_Weapon_Turret_",
        "family": "weapon_kit",
        "role": "turret",
        "type": "armoured rotating turret",
        "tri_budget": 3400,
        "bbox": (5.12, 3.44, 3.04),
        "tol": 0.12,
        "zmin": 0.0,
        "mount_class": "Heavy",
        "base_footprint": (3.44, 3.44),
        "datum": "deck surface z=0; yaw axis at z=0.22",
        "required": ("BaseRing", "Body", "Roof"),
    },
    "SN_Weapon_Pedestal": {
        "collection": "SN_Weapon_Pedestal_Prototype",
        "prefix": "SN_Weapon_Pedestal_",
        "family": "weapon_kit",
        "role": "pedestal",
        "type": "deck weapon pedestal",
        "tri_budget": 1100,
        "bbox": (1.90, 1.90, 1.20),
        "tol": 0.10,
        "zmin": 0.0,
        "mount_class": "Medium",
        "base_footprint": (1.84, 1.84),
        "datum": "deck surface z=0; collar top z=1.10",
        "required": ("BasePlate", "Column", "CollarRing", "Bearing"),
    },
    "SN_ShipPart_Deck": {
        "collection": "SN_ShipPart_Deck_Prototype",
        "prefix": "SN_ShipPart_Deck_",
        "family": "ship_parts",
        "role": "deck",
        "type": "modular deck section",
        "tri_budget": 1800,
        "bbox": (8.40, 6.00, 0.36),
        "tol": 0.10,
        "zmin": 0.0,
        "deck_height": 0.33,
        "module": (8.40, 6.00),
        "datum": "underside z=0; deck surface z=0.33",
        "required": ("Planks", "Margin", "Beams", "Scuppers"),
    },
    "SN_ShipPart_Mast": {
        "collection": "SN_ShipPart_Mast_Prototype",
        "prefix": "SN_ShipPart_Mast_",
        "family": "ship_parts",
        "role": "mast",
        "type": "full mast assembly with yards",
        "tri_budget": 2800,
        "bbox": (1.77, 6.20, 12.84),
        "tol": 0.15,
        "zmin": 0.0,
        "height": 12.84,
        "datum": "deck surface z=0; +X forward",
        "required": ("LowerMast", "Platform", "Topmast", "Yards", "Rig"),
    },
    "SN_ShipPart_Funnel": {
        "collection": "SN_ShipPart_Funnel_Prototype",
        "prefix": "SN_ShipPart_Funnel_",
        "family": "ship_parts",
        "role": "funnel",
        "type": "steam funnel with stays",
        "tri_budget": 1800,
        "bbox": (2.40, 2.00, 4.66),
        "tol": 0.12,
        "zmin": 0.0,
        "datum": "deck surface z=0; exhaust at top centre",
        "required": ("Base", "Funnel", "Cap", "Stays", "SteamPipe"),
    },
    "SN_ShipPart_HatchCover": {
        "collection": "SN_ShipPart_HatchCover_Prototype",
        "prefix": "SN_ShipPart_HatchCover_",
        "family": "ship_parts",
        "role": "hatch_cover",
        "type": "cargo hatch with twin lids",
        "tri_budget": 1400,
        "bbox": (2.72, 2.00, 0.49),
        "tol": 0.10,
        "zmin": 0.0,
        "datum": "deck surface z=0; lid hinges at z=0.40",
        "required": ("Coaming", "Grating", "Lid_Fwd", "Lid_Aft", "Hinges"),
    },
}


# ---------------------------------------------------------------- socket 表
# key -> (name suffix, parent key, location)
SOCKETS = {
    "SN_Weapon_Cannon": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("PITCH", "Pivot_Pitch", "ROOT", (0.0, 0.0, 0.0)),
        ("RECOIL", "Recoil", "PITCH", (0.0, 0.0, 0.0)),
        ("TRUNNION_L", "Trunnion_L", "PITCH", (-0.15, 0.62, 0.0)),
        ("TRUNNION_R", "Trunnion_R", "PITCH", (-0.15, -0.62, 0.0)),
        ("MUZZLE", "Muzzle", "RECOIL", (1.95, 0.0, 0.10)),
        ("BREECH", "Breech", "PITCH", (-2.05, 0.0, 0.10)),
    ],
    "SN_Weapon_GunCarriage": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("YAW", "Pivot_Yaw", "ROOT", (0.0, 0.0, 0.62)),
        ("TRUNNION_L", "Trunnion_L", "ROOT", (-0.15, 0.62, 0.62)),
        ("TRUNNION_R", "Trunnion_R", "ROOT", (-0.15, -0.62, 0.62)),
    ],
    "SN_Weapon_Turret": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("YAW", "Pivot_Yaw", "ROOT", (0.0, 0.0, 0.22)),
        # Yaw 子节点写的是 **Yaw 局部坐标**（world = 0.22 + local）
        ("GUN_PORT", "GunPort", "YAW", (1.52, 0.0, 1.12)),
        ("MUZZLE", "Muzzle", "YAW", (3.38, 0.0, 1.12)),
        ("HATCH", "Hatch", "YAW", (0.0, 0.0, 2.58)),
        ("ANCHOR_1", "Anchor_1", "ROOT", (-1.06, 1.06, 0.20)),
        ("ANCHOR_2", "Anchor_2", "ROOT", (-1.06, -1.06, 0.20)),
        ("ANCHOR_3", "Anchor_3", "ROOT", (1.06, 1.06, 0.20)),
        ("ANCHOR_4", "Anchor_4", "ROOT", (1.06, -1.06, 0.20)),
    ],
    "SN_Weapon_Pedestal": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("COLLAR", "Collar", "ROOT", (0.0, 0.0, 1.10)),
        ("YAW", "Pivot_Yaw", "ROOT", (0.0, 0.0, 1.18)),
        ("ANCHOR_1", "Anchor_1", "ROOT", (-0.65, 0.65, 0.03)),
        ("ANCHOR_2", "Anchor_2", "ROOT", (-0.65, -0.65, 0.03)),
        ("ANCHOR_3", "Anchor_3", "ROOT", (0.65, 0.65, 0.03)),
        ("ANCHOR_4", "Anchor_4", "ROOT", (0.65, -0.65, 0.03)),
    ],
    "SN_ShipPart_Deck": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("SOCKET_MAST", "Socket_Mast", "ROOT", (0.0, 0.40, 0.33)),
        ("SOCKET_FUNNEL", "Socket_Funnel", "ROOT", (2.40, -0.60, 0.33)),
        ("SOCKET_HATCH", "Socket_Hatch", "ROOT", (-2.40, -0.30, 0.33)),
        ("SOCKET_WEAPON_PORT", "Socket_Weapon_Port", "ROOT",
         (2.30, 1.10, 0.33)),
        ("SOCKET_WEAPON_STARBOARD", "Socket_Weapon_Starboard", "ROOT",
         (-2.30, 1.10, 0.33)),
    ],
    "SN_ShipPart_Mast": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("TOP", "Top", "ROOT", (0.0, 0.0, 12.60)),
        ("YARD_LOWER", "Yard_Lower_Mount", "ROOT", (0.0, 0.0, 5.90)),
        ("YARD_UPPER", "Yard_Upper_Mount", "ROOT", (0.0, 0.0, 10.40)),
        ("LOOKOUT", "Lookout", "ROOT", (0.50, 0.0, 12.16)),
        ("DEADEYE_PORT", "Deadeye_Port", "ROOT", (0.0, 0.66, 1.20)),
        ("DEADEYE_STARBOARD", "Deadeye_Starboard", "ROOT", (0.0, -0.66, 1.20)),
    ],
    "SN_ShipPart_Funnel": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("EXHAUST", "Exhaust", "ROOT", (0.35, 0.0, 4.55)),
        ("STEAM_INLET", "Steam_Inlet", "ROOT", (-0.62, 0.0, 0.20)),
        ("STAY_1", "Stay_1", "ROOT", (-1.10, 0.90, 0.03)),
        ("STAY_2", "Stay_2", "ROOT", (-1.10, -0.90, 0.03)),
        ("STAY_3", "Stay_3", "ROOT", (1.10, 0.90, 0.03)),
        ("STAY_4", "Stay_4", "ROOT", (1.10, -0.90, 0.03)),
    ],
    "SN_ShipPart_HatchCover": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("HINGE_FWD", "Hinge_Fwd", "ROOT", (1.30, 0.0, 0.40)),
        ("HINGE_AFT", "Hinge_Aft", "ROOT", (-1.30, 0.0, 0.40)),
        ("OPENING", "Opening_Center", "ROOT", (0.0, 0.0, 0.32)),
        ("LID_FWD", "Lid_Pivot_Fwd", "ROOT", (1.30, 0.0, 0.40)),
        ("LID_AFT", "Lid_Pivot_Aft", "ROOT", (-1.30, 0.0, 0.40)),
    ],
}


def _sockets(asset):
    prefix = SPECS[asset]["prefix"]
    return [{"key": key, "name": prefix + name, "parent": parent,
             "location": loc} for key, name, parent, loc in SOCKETS[asset]]


# ---------------------------------------------------------------- 通用小工具

def _fbox(part, center, u, v, w, hu, hv, hw, mat):
    """以正交轴构造长方体（用于贴体板缝 / 楔块 / 斜撑）。"""
    part.add(wk.frame_box(center, u, v, w, hu, hv, hw), mat)


def _radial_band(part, cx, cy, z, radius, height, mat, sides=12, thick=0.03):
    """水平圆箍（围绕中轴的短圆柱）。"""
    wk.add_cyl(part, (cx, cy, z - height * 0.5),
               (cx, cy, z + height * 0.5), radius, radius, mat, sides)


def _bolt_ring(part, cx, cy, z, radius, count, mat, r=0.045, h=0.06, sides=6):
    wk.bolt_circle(part, (cx, cy, z), radius, count, r, h, mat)


def _vertical_seams(part, count, z0, z1, radius_fn, thickness, width, mat,
                    phase=0.0):
    for i in range(count):
        a = phase + 2.0 * math.pi * i / count
        radial = (math.cos(a), math.sin(a), 0.0)
        tangent = (-math.sin(a), math.cos(a), 0.0)
        r = radius_fn(i)
        zc = (z0 + z1) * 0.5
        _fbox(part, (radial[0] * r, radial[1] * r, zc), radial, tangent,
              (0.0, 0.0, 1.0), thickness * 0.5, width * 0.5,
              (z1 - z0) * 0.5, mat)


def _rivet_ring(part, cx, cy, z, radius, count, mat, r=0.03, h=0.05):
    _bolt_ring(part, cx, cy, z, radius, count, mat, r=r, h=h, sides=6)


def _tapered_seam(part, angle, z0, z1, r0, r1, thickness, width, mat):
    """沿收分圆周面的竖向板缝（随半径收分，不悬空）。"""
    ca, sa = math.cos(angle), math.sin(angle)
    ta, tb = -sa, ca
    hw0 = width * 0.5 / r0
    hw1 = width * 0.5 / r1
    bottom, top = [], []
    for lvl, z, r, hw in ((0, z0, r0, hw0), (1, z1, r1, hw1)):
        for (ro, wt) in ((r + thickness * 0.5, -hw), (r + thickness * 0.5, hw),
                         (r, hw), (r, -hw)):
            a = angle + wt
            bottom.append((math.cos(a) * ro, math.sin(a) * ro, z)) if lvl == 0 \
                else top.append((math.cos(a) * ro, math.sin(a) * ro, z))
    part.add(hexa(bottom, top), mat)


# ---------------------------------------------------------------- 1. 火炮

def _build_cannon():
    prefix = "SN_Weapon_Cannon_"
    parts = {}

    barrel = Part()
    # 主炮管：尾端粗、炮口细；5 道加强箍 + 炮口箍
    wk.barrel_x(
        barrel, -1.30, 1.90, 0.10, 0.30, 0.175, MAT_IRON, sides=12,
        rings=[
            (-0.95, 0.335, 0.14),
            (-0.35, 0.315, 0.12),
            (0.30, 0.275, 0.12),
            (0.95, 0.235, 0.11),
            (1.50, 0.205, 0.10),
        ],
        muzzle=(0.205, 0.16),
    )
    # 炮口内壁（深色）与炮口环
    wk.add_cyl(barrel, (1.88, 0.0, 0.10), (1.96, 0.0, 0.10), 0.135, 0.125,
               MAT_GLASS_DARK, 12)
    wk.add_cyl(barrel, (1.90, 0.0, 0.10), (1.95, 0.0, 0.10), 0.21, 0.21,
               MAT_BRASS, 12)
    # 炮管尾端加强箍
    wk.add_cyl(barrel, (-1.36, 0.0, 0.10), (-1.30, 0.0, 0.10), 0.315, 0.30,
               MAT_IRON_RED, 12)
    parts[prefix + "Barrel"] = (barrel, "PITCH")

    breech = Part()
    # 尾体：圆台 + 尾闩方块 + 尾环 + 尾钮
    wk.add_cyl(breech, (-1.56, 0.0, 0.10), (-1.32, 0.0, 0.10), 0.34, 0.30,
               MAT_IRON, 12)
    wk.add_box(breech, (-1.62, -0.26, -0.12), (-1.45, 0.26, 0.32), MAT_IRON)
    wk.add_torus(breech, (-1.62, 0.0, 0.10), (1.0, 0.0, 0.0), 0.20, 0.045,
                 MAT_BRASS, seg=12, tube=4)
    wk.add_cyl(breech, (-1.80, 0.0, 0.10), (-1.62, 0.0, 0.10), 0.14, 0.16,
               MAT_METAL, 10)
    wk.add_cyl(breech, (-1.96, 0.0, 0.10), (-1.80, 0.0, 0.10), 0.10, 0.14,
               MAT_BRASS, 10)
    wk.add_cyl(breech, (-2.04, 0.0, 0.10), (-1.96, 0.0, 0.10), 0.13, 0.10,
               MAT_BRASS, 10)
    # 尾钮挂环
    wk.add_torus(breech, (-1.72, 0.0, 0.10), (0.0, 1.0, 0.0), 0.10, 0.025,
                 MAT_METAL, seg=8, tube=3)
    # 火门 / 药室盖
    wk.add_cyl(breech, (-1.18, 0.0, 0.36), (-1.18, 0.0, 0.46), 0.055, 0.045,
               MAT_BRASS, 8)
    wk.add_box(breech, (-1.26, -0.10, 0.32), (-1.10, 0.10, 0.37), MAT_METAL)
    parts[prefix + "BreechBlock"] = (breech, "PITCH")

    trunnions = Part()
    for sy, suffix in ((1.0, "L"), (-1.0, "R")):
        # 本体耳轴座 + 外伸耳轴
        wk.add_cyl(trunnions, (-0.15, sy * 0.18, 0.0), (-0.15, sy * 0.62, 0.0),
                   0.135, 0.105, MAT_IRON, 10)
        wk.add_cyl(trunnions, (-0.15, sy * 0.60, 0.0), (-0.15, sy * 0.70, 0.0),
                   0.125, 0.125, MAT_BRASS, 10)
        # 耳轴盖板（铁）
        wk.add_box(trunnions, (-0.31, sy * 0.56 - 0.16, -0.16),
                   (-0.01, sy * 0.56 + 0.16, -0.04), MAT_IRON_RED)
        wk.add_box(trunnions, (-0.31, sy * 0.56 - 0.16, 0.04),
                   (-0.01, sy * 0.56 + 0.16, 0.16), MAT_IRON_RED)
        wk.add_bolt(trunnions, (-0.16, sy * 0.56, 0.18), 0.035, 0.05,
                    MAT_BRASS)
    # 炮身两侧加强板
    for sy in (-1.0, 1.0):
        wk.add_box(trunnions, (-0.45, sy * 0.29, 0.02),
                   (0.10, sy * 0.33, 0.20), MAT_METAL)
    parts[prefix + "Trunnions"] = (trunnions, "PITCH")

    sight = Part()
    # 炮尾准星 + 炮口准星
    wk.add_cyl(sight, (0.40, 0.0, 0.36), (0.40, 0.0, 0.46), 0.035, 0.030,
               MAT_BRASS, 8)
    wk.add_torus(sight, (0.40, 0.0, 0.50), (1.0, 0.0, 0.0), 0.065, 0.014,
                 MAT_BRASS, seg=8, tube=3)
    wk.add_bar(sight, (0.40, -0.07, 0.43), (0.40, 0.07, 0.43), 0.025,
               MAT_BRASS)
    wk.add_box(sight, (1.70, -0.03, 0.30), (1.78, 0.03, 0.40), MAT_BRASS)
    wk.add_box(sight, (1.74, -0.03, 0.40), (1.78, 0.03, 0.46), MAT_BRASS)
    parts[prefix + "Sight"] = (sight, "PITCH")

    return parts


# ---------------------------------------------------------------- 2. 炮架

def _build_gun_carriage():
    prefix = "SN_Weapon_GunCarriage_"
    parts = {}

    wheels = Part()
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            cx, cy, cz = 0.95 * sx, 0.72 * sy, 0.36
            wk.spoked_wheel(wheels, (cx, cy, cz), (0.0, 1.0, 0.0), 0.30, 0.10,
                            MAT_WOOD_DARK, spokes=6, rim_r=0.055)
            # 铁轮箍 + 黄铜轮毂盖
            wk.add_torus(wheels, (cx, cy, cz), (0.0, 1.0, 0.0), 0.295, 0.035,
                         MAT_IRON, seg=12, tube=4)
            wk.add_cyl(wheels, (cx, cy - 0.075, cz), (cx, cy + 0.075, cz),
                       0.085, 0.085, MAT_BRASS, 8)
    parts[prefix + "Wheels"] = (wheels, "ROOT")

    axles = Part()
    for sx in (-1.0, 1.0):
        wk.add_cyl(axles, (0.95 * sx, -0.84, 0.36), (0.95 * sx, 0.84, 0.36),
                   0.065, 0.065, MAT_METAL, 8)
        for sy in (-1.0, 1.0):
            wk.add_box(axles, (0.95 * sx - 0.14, sy * 0.72 - 0.12, 0.28),
                       (0.95 * sx + 0.14, sy * 0.72 + 0.12, 0.46),
                       MAT_METAL)
    parts[prefix + "Axles"] = (axles, "ROOT")

    cheeks = Part()
    for sy in (-1.0, 1.0):
        # 颊板
        wk.add_box(cheeks, (-1.18, sy * 0.52 - 0.07, 0.50),
                   (1.06, sy * 0.52 + 0.07, 0.74), MAT_WOOD)
        # 颊板铁包角（4 处）
        for x in (-1.02, -0.35, 0.34, 0.90):
            wk.add_box(cheeks, (x - 0.055, sy * 0.52 - 0.085, 0.49),
                       (x + 0.055, sy * 0.52 + 0.085, 0.75), MAT_IRON)
            wk.add_rivet(cheeks, (x, sy * 0.60, 0.62), (0.0, 1.0, 0.0),
                         0.028, 0.04, MAT_BRASS)
        # 尾部上翘的架尾
        wk.add_box(cheeks, (-1.58, sy * 0.40 - 0.06, 0.30),
                   (-1.10, sy * 0.40 + 0.06, 0.52), MAT_WOOD_DARK)
        wk.add_box(cheeks, (-1.62, sy * 0.40 - 0.08, 0.30),
                   (-1.52, sy * 0.40 + 0.08, 0.38), MAT_IRON)
    # 3 道横梁 + 铁包条
    for x in (-0.95, 0.0, 0.92):
        wk.add_box(cheeks, (x - 0.10, -0.56, 0.54), (x + 0.10, 0.56, 0.68),
                   MAT_WOOD_DARK)
        wk.add_box(cheeks, (x - 0.11, -0.58, 0.66), (x + 0.11, 0.58, 0.70),
                   MAT_IRON)
    # 架尾横档（推炮把手）
    wk.add_box(cheeks, (-1.66, -0.50, 0.30), (-1.52, 0.50, 0.36),
               MAT_WOOD_DARK)
    parts[prefix + "Cheeks"] = (cheeks, "ROOT")

    caps = Part()
    for sy in (-1.0, 1.0):
        # 耳轴座：在 z=0.62 的 U 形铁座上
        wk.add_box(caps, (-0.34, sy * 0.62 - 0.13, 0.48),
                   (0.04, sy * 0.62 + 0.13, 0.62), MAT_IRON_RED)
        wk.add_box(caps, (-0.34, sy * 0.62 - 0.13, 0.62),
                   (-0.20, sy * 0.62 - 0.02, 0.77), MAT_IRON_RED)
        wk.add_box(caps, (-0.34, sy * 0.62 + 0.02, 0.62),
                   (-0.20, sy * 0.62 + 0.13, 0.77), MAT_IRON_RED)
        wk.add_box(caps, (-0.34, sy * 0.62 - 0.13, 0.72),
                   (-0.20, sy * 0.62 + 0.13, 0.78), MAT_IRON)
        wk.add_bolt(caps, (-0.27, sy * 0.62, 0.80), 0.035, 0.05, MAT_BRASS)
    # 俯仰螺杆 + 手轮 + 楔块
    wk.add_box(caps, (-1.18, -0.16, 0.60), (-0.98, 0.16, 0.66), MAT_METAL)
    wk.add_cyl(caps, (-1.08, 0.0, 0.64), (-1.08, 0.0, 1.02), 0.05, 0.045,
               MAT_METAL, 8)
    wk.handwheel(caps, (-1.08, 0.0, 1.04), (0.0, 0.0, 1.0), 0.18, MAT_BRASS,
                 spokes=4, hub_r=0.055)
    wk.add_box(caps, (-0.90, -0.24, 0.60), (-0.58, 0.24, 0.74), MAT_WOOD_DARK)
    wk.add_box(caps, (-0.86, -0.20, 0.72), (-0.62, 0.20, 0.77), MAT_METAL)
    parts[prefix + "Trunnion_Caps"] = (caps, "ROOT")

    tools = Part()
    # 侧挂炮刷 / 推弹杆
    wk.add_cyl(tools, (-1.10, 0.80, 0.78), (1.00, 0.80, 0.78), 0.030, 0.030,
               MAT_WOOD_DARK, 6)
    wk.add_cyl(tools, (0.86, 0.80, 0.78), (1.18, 0.80, 0.78), 0.075, 0.060,
               MAT_CANVAS_SHADE, 8)
    wk.add_cyl(tools, (-1.22, 0.80, 0.78), (-1.10, 0.80, 0.78), 0.045, 0.030,
               MAT_METAL, 6)
    for x in (-0.70, 0.55):
        wk.add_box(tools, (x - 0.05, 0.70, 0.68), (x + 0.05, 0.86, 0.86),
                   MAT_IRON)
    # 备用轮楔 + 木桶
    wk.add_box(tools, (1.02, -0.92, 0.0), (1.28, -0.68, 0.10), MAT_WOOD_DARK)
    parts[prefix + "Tools"] = (tools, "ROOT")

    return parts


# ---------------------------------------------------------------- 3. 炮塔

def _build_turret():
    prefix = "SN_Weapon_Turret_"
    parts = {}

    base = Part()
    wk.add_cyl(base, (0.0, 0.0, 0.0), (0.0, 0.0, 0.18), 1.72, 1.66, MAT_IRON,
               12)
    wk.add_cyl(base, (0.0, 0.0, 0.18), (0.0, 0.0, 0.22), 1.55, 1.52,
               MAT_IRON_RED, 12)
    _rivet_ring(base, 0.0, 0.0, 0.10, 1.62, 12, MAT_BRASS, r=0.045, h=0.05)
    _bolt_ring(base, 0.0, 0.0, 0.18, 1.38, 12, MAT_METAL, r=0.055, h=0.09)
    # 基座环上的检修门与黄铜铭牌
    wk.add_box(base, (1.36, -0.32, 0.05), (1.48, 0.32, 0.17), MAT_METAL)
    wk.add_box(base, (1.40, -0.16, 0.09), (1.44, 0.16, 0.14), MAT_BRASS)
    parts[prefix + "BaseRing"] = (base, "ROOT")

    body = Part()
    wk.add_cyl(body, (0.0, 0.0, 0.22), (0.0, 0.0, 2.35), 1.50, 1.22, MAT_IRON,
               12)
    # 3 道装甲板带 + 12 条竖向板缝
    for z, r in ((0.88, 1.44), (1.58, 1.34), (2.16, 1.25)):
        wk.add_cyl(body, (0.0, 0.0, z - 0.05), (0.0, 0.0, z + 0.05), r, r,
                   MAT_IRON_RED, 12)
    for i in range(12):
        _tapered_seam(body, math.pi / 12.0 + 2.0 * math.pi * i / 12.0,
                      0.28, 2.30, 1.495, 1.225, 0.03, 0.075, MAT_IRON_RED)
    # 炮口盾 + 开口框 + 深色炮口
    wk.add_box(body, (1.24, -0.62, 0.98), (1.50, 0.62, 1.72), MAT_IRON_RED)
    wk.add_box(body, (1.30, -0.46, 1.04), (1.56, 0.46, 1.16), MAT_IRON)
    wk.add_box(body, (1.30, -0.46, 1.54), (1.56, 0.46, 1.66), MAT_IRON)
    wk.add_box(body, (1.30, -0.46, 1.16), (1.56, -0.34, 1.54), MAT_IRON)
    wk.add_box(body, (1.30, 0.34, 1.16), (1.56, 0.46, 1.54), MAT_IRON)
    wk.add_box(body, (1.48, -0.32, 1.18), (1.51, 0.32, 1.52), MAT_GLASS_DARK)
    # 观察缝（前左 / 前右 / 后）
    for ang in (math.radians(48.0), math.radians(-48.0), math.radians(180.0)):
        radial = (math.cos(ang), math.sin(ang), 0.0)
        tangent = (-math.sin(ang), math.cos(ang), 0.0)
        center = (radial[0] * 1.33, radial[1] * 1.33, 1.86)
        _fbox(body, center, radial, tangent, (0.0, 0.0, 1.0), 0.035, 0.22,
              0.075, MAT_IRON)
        _fbox(body, (radial[0] * 1.36, radial[1] * 1.36, 1.86), radial,
              tangent, (0.0, 0.0, 1.0), 0.020, 0.16, 0.040, MAT_GLASS_DARK)
    # 炮管（从炮口盾伸出）
    wk.add_cyl(body, (1.30, 0.0, 1.34), (3.36, 0.0, 1.34), 0.20, 0.155,
               MAT_IRON, 12)
    wk.add_cyl(body, (1.84, 0.0, 1.34), (1.96, 0.0, 1.34), 0.225, 0.225,
               MAT_BRASS, 12)
    wk.add_cyl(body, (2.60, 0.0, 1.34), (2.70, 0.0, 1.34), 0.185, 0.185,
               MAT_BRASS, 12)
    wk.add_cyl(body, (3.20, 0.0, 1.34), (3.34, 0.0, 1.34), 0.195, 0.195,
               MAT_IRON_RED, 12)
    wk.add_cyl(body, (3.34, 0.0, 1.34), (3.40, 0.0, 1.34), 0.135, 0.125,
               MAT_GLASS_DARK, 12)
    parts[prefix + "Body"] = (body, "YAW")

    roof = Part()
    wk.add_cyl(roof, (0.0, 0.0, 2.35), (0.0, 0.0, 2.66), 1.22, 0.62, MAT_IRON,
               12)
    wk.add_cyl(roof, (0.0, 0.0, 2.66), (0.0, 0.0, 2.74), 0.60, 0.54,
               MAT_IRON_RED, 12)
    _rivet_ring(roof, 0.0, 0.0, 2.72, 0.56, 10, MAT_BRASS, r=0.03, h=0.04)
    # 顶部舱盖 + 铰链 + 提环
    wk.add_cyl(roof, (-0.02, 0.0, 2.74), (-0.02, 0.0, 2.80), 0.36, 0.34,
               MAT_WOOD_DARK, 8)
    wk.add_torus(roof, (-0.02, 0.0, 2.80), (0.0, 0.0, 1.0), 0.34, 0.03,
                 MAT_IRON, seg=8, tube=3)
    for sy in (-1.0, 1.0):
        wk.add_box(roof, (0.18, sy * 0.24 - 0.06, 2.74),
                   (0.36, sy * 0.24 + 0.06, 2.84), MAT_IRON)
        wk.add_cyl(roof, (0.18, sy * 0.24 - 0.07, 2.78),
                   (0.18, sy * 0.24 + 0.07, 2.78), 0.035, 0.035, MAT_METAL, 6)
    wk.add_torus(roof, (-0.26, 0.0, 2.84), (1.0, 0.0, 0.0), 0.075, 0.018,
                 MAT_BRASS, seg=8, tube=3)
    # 潜望镜 / 通风帽
    wk.add_cyl(roof, (0.26, 0.0, 2.74), (0.26, 0.0, 2.98), 0.065, 0.055,
               MAT_METAL, 8)
    wk.add_box(roof, (0.22, -0.075, 2.98), (0.34, 0.075, 3.04),
               MAT_GLASS_DARK)
    for sx in (-1.0, 1.0):
        wk.add_cyl(roof, (0.42 * sx, 0.30, 2.62), (0.42 * sx, 0.30, 2.82),
                   0.13, 0.11, MAT_METAL, 8)
        wk.add_cyl(roof, (0.42 * sx, 0.30, 2.82), (0.42 * sx, 0.30, 2.88),
                   0.16, 0.16, MAT_IRON, 8)
    parts[prefix + "Roof"] = (roof, "YAW")

    return parts


# ---------------------------------------------------------------- 4. 武器基座

def _build_pedestal():
    prefix = "SN_Weapon_Pedestal_"
    parts = {}

    plate = Part()
    wk.add_cyl(plate, (0.0, 0.0, 0.0), (0.0, 0.0, 0.10), 0.95, 0.92, MAT_IRON,
               8)
    wk.add_cyl(plate, (0.0, 0.0, 0.10), (0.0, 0.0, 0.13), 0.80, 0.78,
               MAT_IRON_RED, 8)
    for i in range(4):
        a = math.radians(45.0 + 90.0 * i)
        radial = (math.cos(a), math.sin(a), 0.0)
        tangent = (-math.sin(a), math.cos(a), 0.0)
        _fbox(plate, (radial[0] * 0.80, radial[1] * 0.80, 0.20), radial,
              tangent, (0.0, 0.0, 1.0), 0.09, 0.035, 0.12, MAT_IRON)
    _bolt_ring(plate, 0.0, 0.0, 0.13, 0.72, 8, MAT_BRASS, r=0.05, h=0.07)
    parts[prefix + "BasePlate"] = (plate, "ROOT")

    column = Part()
    wk.add_cyl(column, (0.0, 0.0, 0.10), (0.0, 0.0, 1.00), 0.62, 0.44,
               MAT_METAL, 12)
    _radial_band(column, 0.0, 0.0, 0.34, 0.615, 0.11, MAT_IRON, 12)
    _radial_band(column, 0.0, 0.0, 0.72, 0.505, 0.10, MAT_IRON, 12)
    # 锁定销 + 手柄 + 黄油嘴
    wk.add_cyl(column, (0.44, 0.0, 0.88), (0.58, 0.0, 0.88), 0.045, 0.040,
               MAT_IRON, 8)
    wk.add_bar(column, (0.58, 0.0, 0.88), (0.76, 0.0, 0.98), 0.045,
               MAT_BRASS)
    wk.add_cyl(column, (0.30, 0.24, 0.86), (0.30, 0.24, 0.94), 0.045, 0.035,
               MAT_BRASS, 6)
    wk.add_box(column, (-0.30, -0.50, 0.44), (-0.14, -0.42, 0.66), MAT_IRON)
    parts[prefix + "Column"] = (column, "ROOT")

    collar = Part()
    wk.add_cyl(collar, (0.0, 0.0, 0.98), (0.0, 0.0, 1.08), 0.82, 0.82,
               MAT_BRASS, 12)
    wk.add_torus(collar, (0.0, 0.0, 1.08), (0.0, 0.0, 1.0), 0.82, 0.045,
                 MAT_BRASS, seg=12, tube=4)
    _bolt_ring(collar, 0.0, 0.0, 1.08, 0.66, 8, MAT_METAL, r=0.045, h=0.05)
    parts[prefix + "CollarRing"] = (collar, "ROOT")

    bearing = Part()
    wk.add_cyl(bearing, (0.0, 0.0, 1.08), (0.0, 0.0, 1.14), 0.58, 0.55,
               MAT_METAL, 12)
    wk.add_cyl(bearing, (0.0, 0.0, 1.14), (0.0, 0.0, 1.18), 0.46, 0.42,
               MAT_IRON, 12)
    wk.add_torus(bearing, (0.0, 0.0, 1.14), (0.0, 0.0, 1.0), 0.55, 0.03,
                 MAT_BRASS, seg=12, tube=3)
    wk.add_box(bearing, (-0.10, -0.10, 1.18), (0.10, 0.10, 1.20), MAT_BRASS)
    parts[prefix + "Bearing"] = (bearing, "ROOT")

    return parts


# ---------------------------------------------------------------- 5. 甲板模块

def _build_deck():
    prefix = "SN_ShipPart_Deck_"
    parts = {}

    slab = Part()
    wk.add_box(slab, (-3.95, -2.75, 0.12), (3.95, 2.75, 0.30), MAT_WOOD_DARK)
    for i in range(24):
        y0 = -2.75 + i * (5.5 / 24.0)
        wk.add_box(slab, (-3.95, y0 + 0.004, 0.30),
                   (3.95, y0 + (5.5 / 24.0) - 0.004, 0.33), MAT_WOOD_DECK)
    parts[prefix + "Planks"] = (slab, "ROOT")

    margin = Part()
    # 四边压条 / 边板（比铺板高 1 cm）
    wk.add_box(margin, (-4.20, -2.75, 0.30), (-3.95, 2.75, 0.34), MAT_WOOD_DARK)
    wk.add_box(margin, (3.95, -2.75, 0.30), (4.20, 2.75, 0.34), MAT_WOOD_DARK)
    wk.add_box(margin, (-4.20, -3.00, 0.30), (4.20, -2.75, 0.34), MAT_WOOD_DARK)
    wk.add_box(margin, (-4.20, 2.75, 0.30), (4.20, 3.00, 0.34), MAT_WOOD_DARK)
    # 四角黄铜护角（收在 8.4 x 6.0 m 模块尺寸内）
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            x_outer, y_outer = sx * 4.20, sy * 3.00
            wk.add_box(margin, (x_outer - sx * 0.14, y_outer - sy * 0.14, 0.30),
                       (x_outer, y_outer, 0.355), MAT_BRASS)
    parts[prefix + "Margin"] = (margin, "ROOT")

    beams = Part()
    for x in (-2.80, 0.0, 2.80):
        wk.add_box(beams, (x - 0.11, -3.00, 0.0), (x + 0.11, 3.00, 0.12),
                   MAT_WOOD_DARK)
        # 横梁两端的铁包脚
        for sy in (-1.0, 1.0):
            wk.add_box(beams, (x - 0.13, sy * 2.92 - 0.08, 0.0),
                       (x + 0.13, sy * 2.92 + 0.08, 0.14), MAT_IRON)
    parts[prefix + "Beams"] = (beams, "ROOT")

    scuppers = Part()
    for x in (-2.60, 0.0, 2.60):
        for sy in (-1.0, 1.0):
            wk.add_box(scuppers, (x - 0.14, sy * 2.90 - 0.10, 0.335),
                       (x + 0.14, sy * 2.90 + 0.10, 0.355), MAT_IRON)
    parts[prefix + "Scuppers"] = (scuppers, "ROOT")

    return parts


# ---------------------------------------------------------------- 6. 桅杆

def _build_mast():
    prefix = "SN_ShipPart_Mast_"
    parts = {}

    lower = Part()
    # 桅座 / 楔块 / 下桅 / 铁箍
    wk.add_cyl(lower, (0.0, 0.0, 0.0), (0.0, 0.0, 0.12), 0.42, 0.40,
               MAT_WOOD_DARK, 12)
    for i in range(12):
        a = 2.0 * math.pi * i / 12.0
        radial = (math.cos(a), math.sin(a), 0.0)
        tangent = (-math.sin(a), math.cos(a), 0.0)
        _fbox(lower, (radial[0] * 0.34, radial[1] * 0.34, 0.18), radial,
              tangent, (0.0, 0.0, 1.0), 0.055, 0.045, 0.07, MAT_WOOD)
    wk.add_cyl(lower, (0.0, 0.0, 0.12), (0.0, 0.0, 8.00), 0.30, 0.22,
               MAT_WOOD, 12)
    for z, r in ((1.20, 0.29), (3.20, 0.265), (5.20, 0.245), (7.40, 0.225)):
        wk.add_cyl(lower, (0.0, 0.0, z - 0.06), (0.0, 0.0, z + 0.06), r, r,
                   MAT_IRON, 12)
    # 桅盘下的 cross trees（承托桅帽；驻人瞭望台放到桅顶）
    for sy in (-1.0, 1.0):
        wk.add_box(lower, (-0.72, sy * 0.86 - 0.06, 7.80),
                   (0.72, sy * 0.86 + 0.06, 7.90), MAT_WOOD_DARK)
    for sx in (-1.0, 1.0):
        wk.add_box(lower, (sx * 0.72 - 0.06, -0.92, 7.80),
                   (sx * 0.72 + 0.06, 0.92, 7.90), MAT_WOOD_DARK)
    # 桅帽
    wk.add_box(lower, (-0.36, -0.28, 8.00), (0.36, 0.28, 8.18), MAT_WOOD_DARK)
    wk.add_box(lower, (-0.38, -0.30, 8.02), (0.38, -0.20, 8.16), MAT_IRON)
    wk.add_box(lower, (-0.38, 0.20, 8.02), (0.38, 0.30, 8.16), MAT_IRON)
    parts[prefix + "LowerMast"] = (lower, "ROOT")

    platform = Part()
    # 瞭望台（桅顶 z≈12.1）：中央留出上桅穿过的方孔，-X 侧留登台梯口
    for lo_x, hi_x, lo_y, hi_y in (
            (0.22, 0.80, -0.70, 0.70),
            (-0.80, -0.22, 0.18, 0.70),
            (-0.80, -0.22, -0.70, -0.18),
            (-0.22, 0.22, 0.22, 0.70),
            (-0.22, 0.22, -0.70, -0.22)):
        wk.add_box(platform, (lo_x, lo_y, 12.08), (hi_x, hi_y, 12.16),
                   MAT_WOOD_DECK)
    for lo_x, hi_x, lo_y, hi_y in (
            (0.74, 0.80, -0.70, 0.70),
            (-0.80, -0.74, 0.20, 0.70),
            (-0.80, -0.74, -0.70, -0.20),
            (-0.80, 0.80, 0.64, 0.70),
            (-0.80, 0.80, -0.70, -0.64)):
        wk.add_box(platform, (lo_x, lo_y, 12.16), (hi_x, hi_y, 12.19),
                   MAT_WOOD_DARK)
    # 4 根斜撑：台底撑到上桅
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            wk.add_bar(platform, (sx * 0.62, sy * 0.50, 12.08),
                       (sx * 0.13, sy * 0.11, 11.62), 0.045, MAT_IRON)
    # 三面半栏杆，-X 侧留梯口
    rail_segments = [
        [(0.78, -0.66, 12.16), (0.78, 0.66, 12.16)],
        [(0.78, 0.66, 12.16), (-0.78, 0.66, 12.16)],
        [(-0.78, 0.66, 12.16), (-0.78, 0.20, 12.16)],
        [(-0.78, -0.20, 12.16), (-0.78, -0.66, 12.16)],
        [(-0.78, -0.66, 12.16), (0.78, -0.66, 12.16)],
    ]
    for seg in rail_segments:
        wk.railing(platform, seg, 0.52, MAT_WOOD_DARK, post_step=0.9,
                   bar_r=0.030)
    # 登台长梯（-X 梯口，下端落到上横桁 z=10.40） + 3 道支撑
    wk.ladder(platform, (-0.50, 0.0, 10.44), (-0.50, 0.0, 12.10), 0.30,
              MAT_WOOD_DARK, step=0.26, rail_r=0.030, rung_r=0.022)
    for z in (10.58, 11.48, 11.92):
        for sy in (-1.0, 1.0):
            wk.add_bar(platform, (-0.50, sy * 0.15, z),
                       (-0.10, sy * 0.10, z), 0.032, MAT_IRON)
    # 梯脚落到上横桁的 2 个固定卡箍
    for sy in (-1.0, 1.0):
        wk.add_cyl(platform, (-0.50, sy * 0.15, 10.36),
                   (-0.50, sy * 0.15, 10.44), 0.045, 0.045, MAT_METAL, 6)
    # 台上固定一架黄铜单筒望远镜（+X 朝前）
    wk.add_cyl(platform, (0.58, 0.0, 12.16), (0.58, 0.0, 12.28), 0.048, 0.040,
               MAT_METAL, 6)
    wk.add_cyl(platform, (0.40, 0.0, 12.32), (0.96, 0.0, 12.32), 0.038, 0.030,
               MAT_BRASS, 8)
    for x in (0.52, 0.80):
        wk.add_cyl(platform, (x - 0.012, 0.0, 12.32),
                   (x + 0.012, 0.0, 12.32), 0.050, 0.050, MAT_BRASS, 6)
    parts[prefix + "Platform"] = (platform, "ROOT")

    topmast = Part()
    wk.add_cyl(topmast, (0.0, 0.0, 8.18), (0.0, 0.0, 12.42), 0.16, 0.075,
               MAT_WOOD, 12)
    for z, r in ((9.60, 0.15), (11.00, 0.12), (12.20, 0.095)):
        wk.add_cyl(topmast, (0.0, 0.0, z - 0.055), (0.0, 0.0, z + 0.055),
                   r, r, MAT_IRON, 12)
    wk.add_cyl(topmast, (0.0, 0.0, 12.42), (0.0, 0.0, 12.66), 0.075, 0.055,
               MAT_WOOD_DARK, 12)
    wk.add_cyl(topmast, (0.0, 0.0, 12.66), (0.0, 0.0, 12.72), 0.14, 0.13,
               MAT_BRASS, 12)
    wk.add_cyl(topmast, (0.0, 0.0, 12.72), (0.0, 0.0, 12.84), 0.11, 0.05,
               MAT_BRASS, 12)
    parts[prefix + "Topmast"] = (topmast, "ROOT")

    yards = Part()
    for z, half, r in ((5.90, 3.00, 0.095), (10.40, 2.40, 0.070)):
        wk.add_cyl(yards, (0.0, -half, z), (0.0, half, z), r * 0.55, r * 0.55,
                   MAT_WOOD_DARK, 10)
        wk.add_cyl(yards, (0.0, -0.52, z), (0.0, 0.52, z), r * 1.35,
                   r * 1.35, MAT_WOOD_DARK, 10)
        for sy in (-1.0, 1.0):
            wk.add_cyl(yards, (0.0, sy * half - 0.10, z),
                       (0.0, sy * half + 0.10, z), r * 0.85, r * 0.85,
                       MAT_BRASS, 8)
            wk.add_cyl(yards, (0.0, sy * 0.55, z), (0.0, sy * 1.55, z),
                       r * 0.55, r * 0.42, MAT_WOOD, 8)
    wk.add_torus(yards, (0.0, 0.0, 5.90), (0.0, 0.0, 1.0), 0.30, 0.035,
                 MAT_IRON, seg=12, tube=3)
    wk.add_torus(yards, (0.0, 0.0, 10.40), (0.0, 0.0, 1.0), 0.19, 0.030,
                 MAT_IRON, seg=12, tube=3)
    parts[prefix + "Yards"] = (yards, "ROOT")

    rig = Part()
    # 左右各 3 个支索眼板 / 卸扣 / 绳环
    for sy in (-1.0, 1.0):
        for x in (-0.42, 0.0, 0.42):
            wk.add_box(rig, (x - 0.07, sy * 0.30, 1.02),
                       (x + 0.07, sy * 0.50, 1.10), MAT_IRON)
            wk.add_cyl(rig, (x, sy * 0.52, 1.02), (x, sy * 0.60, 1.02),
                       0.030, 0.030, MAT_METAL, 6)
            wk.add_torus(rig, (x, sy * 0.64, 1.10), (1.0, 0.0, 0.0), 0.075,
                         0.022, MAT_IRON, seg=8, tube=3)
        # 侧支索通道板
        wk.add_box(rig, (-0.10, sy * 0.58, 1.00), (0.10, sy * 0.76, 1.06),
                   MAT_WOOD_DARK)
    parts[prefix + "Rig"] = (rig, "ROOT")

    return parts


# ---------------------------------------------------------------- 7. 烟囱

FUNNEL_BASE = (0.0, 0.0, 0.12)
FUNNEL_TOP = (0.35, 0.0, 4.40)


def _funnel_axis():
    return vnorm(vsub(FUNNEL_TOP, FUNNEL_BASE))


def _funnel_length():
    return vlen(vsub(FUNNEL_TOP, FUNNEL_BASE))


def _funnel_at(t):
    return vadd(FUNNEL_BASE, vmul(_funnel_axis(), _funnel_length() * t))


def _funnel_radius(t):
    return 0.48 + (0.40 - 0.48) * t


def _build_funnel():
    prefix = "SN_ShipPart_Funnel_"
    parts = {}

    base = Part()
    wk.add_cyl(base, (0.0, 0.0, 0.0), (0.0, 0.0, 0.12), 0.72, 0.70, MAT_IRON,
               8)
    wk.add_cyl(base, (0.0, 0.0, 0.12), (0.0, 0.0, 0.18), 0.60, 0.58,
               MAT_IRON_RED, 8)
    _bolt_ring(base, 0.0, 0.0, 0.12, 0.60, 8, MAT_BRASS, r=0.045, h=0.07)
    for i in range(4):
        a = math.radians(45.0 + 90.0 * i)
        radial = (math.cos(a), math.sin(a), 0.0)
        tangent = (-math.sin(a), math.cos(a), 0.0)
        _fbox(base, (radial[0] * 0.48, radial[1] * 0.48, 0.19), radial,
              tangent, (0.0, 0.0, 1.0), 0.11, 0.035, 0.07, MAT_IRON)
    parts[prefix + "Base"] = (base, "ROOT")

    funnel = Part()
    d = _funnel_axis()
    length = _funnel_length()
    wk.add_cyl(funnel, FUNNEL_BASE, FUNNEL_TOP, 0.48, 0.40, MAT_IRON, 12)
    # 3 道铁箍 + 1 道黄铜顶箍
    for t, mat, extra in ((0.22, MAT_IRON, 0.03), (0.55, MAT_IRON, 0.03),
                          (0.84, MAT_IRON, 0.03), (1.0, MAT_BRASS, 0.02)):
        center = _funnel_at(t)
        width = 0.10 if mat == MAT_IRON else 0.12
        radius = _funnel_radius(t) + extra
        wk.add_cyl(funnel, vadd(center, vmul(d, -width * 0.5)),
                   vadd(center, vmul(d, width * 0.5)), radius, radius, mat, 12)
    # 12 条竖向板缝
    for i in range(12):
        a = 2.0 * math.pi * i / 12.0
        radial = (math.cos(a), math.sin(a), 0.0)
        tangent = (-math.sin(a), math.cos(a), 0.0)
        center = vadd(vadd(FUNNEL_BASE, vmul(d, length * 0.5)),
                      vmul(radial, 0.445))
        _fbox(funnel, center, radial, tangent, d, 0.022, 0.035,
              length * 0.45, MAT_IRON_RED)
    # 顶部挡檐 + 防雨帽
    top = _funnel_at(1.0)
    wk.add_cyl(funnel, vadd(top, vmul(d, -0.02)), vadd(top, vmul(d, 0.10)),
               0.52, 0.30, MAT_IRON, 12)
    wk.add_cyl(funnel, vadd(top, vmul(d, 0.10)), vadd(top, vmul(d, 0.16)),
               0.30, 0.26, MAT_BRASS, 12)
    for i in range(4):
        a = math.radians(45.0 + 90.0 * i)
        radial = (math.cos(a), math.sin(a), 0.0)
        _fbox(funnel, (radial[0] * 0.40, radial[1] * 0.40, 4.54), radial,
              (-math.sin(a), math.cos(a), 0.0), d, 0.035, 0.035, 0.11,
              MAT_IRON)
    parts[prefix + "Funnel"] = (funnel, "ROOT")

    cap = Part()
    wk.add_cyl(cap, (0.35, 0.0, 4.56), (0.35, 0.0, 4.62), 0.40, 0.16,
               MAT_IRON, 12)
    wk.add_cyl(cap, (0.35, 0.0, 4.62), (0.35, 0.0, 4.66), 0.16, 0.13,
               MAT_BRASS, 10)
    parts[prefix + "Cap"] = (cap, "ROOT")

    stays = Part()
    for i in range(4):
        a = math.radians(45.0 + 90.0 * i)
        radial = (math.cos(a), math.sin(a), 0.0)
        anchor = (1.10 * math.copysign(1.0, radial[0]),
                  0.90 * math.copysign(1.0, radial[1]), 0.03)
        attach = vadd(_funnel_at(0.80),
                      vmul((radial[0], radial[1], 0.0), 0.42))
        wk.add_bar(stays, anchor, attach, 0.032, MAT_METAL)
        # 花篮螺栓
        middle = tuple((anchor[i] + attach[i]) * 0.5 for i in range(3))
        wk.add_cyl(stays, (middle[0] - 0.07, middle[1], middle[2]),
                   (middle[0] + 0.07, middle[1], middle[2]), 0.045, 0.045,
                   MAT_BRASS, 6)
        # 甲板眼板
        wk.add_box(stays, (anchor[0] - 0.10, anchor[1] - 0.10, 0.0),
                   (anchor[0] + 0.10, anchor[1] + 0.10, 0.06), MAT_IRON)
        wk.add_torus(stays, (anchor[0], anchor[1], 0.08), (0.0, 0.0, 1.0),
                     0.06, 0.018, MAT_BRASS, seg=8, tube=3)
    parts[prefix + "Stays"] = (stays, "ROOT")

    steam = Part()
    # 蒸汽管：从甲板立起，弯向烟囱下段
    wk.add_cyl(steam, (-0.62, 0.0, 0.10), (-0.62, 0.0, 2.20), 0.075, 0.070,
               MAT_BRASS, 8)
    wk.add_cyl(steam, (-0.62, 0.0, 2.20), (-0.20, 0.0, 2.55), 0.070, 0.065,
               MAT_BRASS, 8)
    wk.add_cyl(steam, (-0.62, 0.0, 0.10), (-0.62, 0.0, 0.20), 0.11, 0.10,
               MAT_IRON, 8)
    for z in (0.80, 1.50):
        wk.add_cyl(steam, (-0.62, 0.0, z - 0.04), (-0.62, 0.0, z + 0.04),
                   0.10, 0.10, MAT_IRON, 8)
    wk.handwheel(steam, (-0.62, 0.16, 1.15), (0.0, 1.0, 0.0), 0.14, MAT_BRASS,
                 spokes=4, hub_r=0.045)
    wk.add_cyl(steam, (-0.62, 0.0, 1.15), (-0.62, 0.16, 1.15), 0.045, 0.040,
               MAT_METAL, 6)
    parts[prefix + "SteamPipe"] = (steam, "ROOT")

    return parts


# ---------------------------------------------------------------- 8. 货舱盖

def _build_hatch():
    prefix = "SN_ShipPart_HatchCover_"
    parts = {}

    coaming = Part()
    wk.add_box(coaming, (1.18, -0.94, 0.0), (1.30, 0.94, 0.32), MAT_WOOD)
    wk.add_box(coaming, (-1.30, -0.94, 0.0), (-1.18, 0.94, 0.32), MAT_WOOD)
    wk.add_box(coaming, (-1.30, 0.82, 0.0), (1.30, 0.94, 0.32), MAT_WOOD)
    wk.add_box(coaming, (-1.30, -0.94, 0.0), (1.30, -0.82, 0.32), MAT_WOOD)
    # 顶沿压条
    wk.add_box(coaming, (1.14, -0.98, 0.32), (1.34, 0.98, 0.36), MAT_WOOD_DARK)
    wk.add_box(coaming, (-1.34, -0.98, 0.32), (-1.14, 0.98, 0.36),
               MAT_WOOD_DARK)
    wk.add_box(coaming, (-1.14, 0.86, 0.32), (1.14, 0.98, 0.36),
               MAT_WOOD_DARK)
    wk.add_box(coaming, (-1.14, -0.98, 0.32), (1.14, -0.86, 0.36),
               MAT_WOOD_DARK)
    # 四角角铁 + 8 个地脚螺栓
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            wk.add_box(coaming, (sx * 1.30 - 0.06, sy * 0.94 - 0.06, 0.0),
                       (sx * 1.30 + 0.06, sy * 0.94 + 0.06, 0.34), MAT_IRON)
            wk.add_bolt(coaming, (sx * 1.18, sy * 0.80, 0.36), 0.045, 0.05,
                        MAT_BRASS)
            wk.add_bolt(coaming, (sx * 1.18, sy * 0.30, 0.36), 0.045, 0.05,
                        MAT_BRASS)
    parts[prefix + "Coaming"] = (coaming, "ROOT")

    grating = Part()
    for i in range(8):
        y = -0.75 + i * 0.24
        wk.add_box(grating, (-1.14, y - 0.045, 0.20), (1.14, y + 0.045, 0.25),
                   MAT_WOOD_DARK)
    for x in (-0.62, 0.62):
        wk.add_box(grating, (x - 0.05, -0.94, 0.20), (x + 0.05, 0.94, 0.25),
                   MAT_WOOD_DARK)
    parts[prefix + "Grating"] = (grating, "ROOT")

    # 双开盖板：各自挂在自己的铰链 Pivot 下（世界坐标建模，装配时减原点）
    for sign, suffix, pivot_key in ((1.0, "Lid_Fwd", "LID_FWD"),
                                    (-1.0, "Lid_Aft", "LID_AFT")):
        lid = Part()
        x_inner = 0.06 * sign
        x_outer = 1.24 * sign
        lo_x, hi_x = min(x_inner, x_outer), max(x_inner, x_outer)
        wk.add_box(lid, (lo_x, -0.94, 0.34), (hi_x, 0.94, 0.40), MAT_WOOD_DECK)
        # 铁包条（横跨盖板）
        for x in (0.34, 0.72, 1.06):
            xx = x * sign
            wk.add_box(lid, (xx - 0.05, -0.90, 0.40), (xx + 0.05, 0.90, 0.415),
                       MAT_IRON)
        # 纵向压板 + 提环
        wk.add_box(lid, (lo_x, -0.06, 0.40), (hi_x, 0.06, 0.425),
                   MAT_WOOD_DARK)
        wk.add_torus(lid, (0.66 * sign, 0.0, 0.44), (0.0, 0.0, 1.0), 0.065,
                     0.017, MAT_BRASS, seg=8, tube=3)
        # 内侧搭扣
        wk.add_box(lid, (0.02 * sign, -0.16, 0.40), (0.10 * sign, 0.16, 0.45),
                   MAT_IRON)
        parts[prefix + suffix] = (lid, pivot_key)

    hinges = Part()
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            cx = 1.30 * sx
            cy = 0.55 * sy
            wk.add_cyl(hinges, (cx, cy - 0.08, 0.40), (cx, cy + 0.08, 0.40),
                       0.035, 0.035, MAT_METAL, 6)
            wk.add_box(hinges, (cx - 0.09 * sx - 0.04, cy - 0.06, 0.36),
                       (cx - 0.09 * sx + 0.04, cy + 0.06, 0.40), MAT_IRON)
    # 中央搭扣 / 锁扣
    for sy in (-1.0, 1.0):
        wk.add_box(hinges, (-0.05, sy * 0.52 - 0.04, 0.40),
                   (0.05, sy * 0.52 + 0.04, 0.46), MAT_IRON)
        wk.add_box(hinges, (-0.03, sy * 0.52 - 0.02, 0.46),
                   (0.03, sy * 0.52 + 0.02, 0.49), MAT_BRASS)
    parts[prefix + "Hinges"] = (hinges, "ROOT")

    return parts


BUILDERS = {
    "SN_Weapon_Cannon": _build_cannon,
    "SN_Weapon_GunCarriage": _build_gun_carriage,
    "SN_Weapon_Turret": _build_turret,
    "SN_Weapon_Pedestal": _build_pedestal,
    "SN_ShipPart_Deck": _build_deck,
    "SN_ShipPart_Mast": _build_mast,
    "SN_ShipPart_Funnel": _build_funnel,
    "SN_ShipPart_HatchCover": _build_hatch,
}


def build_geometry(asset):
    """纯 Python：返回 {对象名: (Part, 父级 key)}；不 import bpy。"""
    parts = BUILDERS[asset]()
    if asset == "SN_Weapon_Cannon":
        # 炮管 / 炮尾随 Recoil 后坐，耳轴与瞄准具留在 Pitch
        out = {}
        for name, (part, parent) in parts.items():
            if parent == "PITCH" and any(k in name for k in ("Barrel", "BreechBlock")):
                parent = "RECOIL"
            out[name] = (part, parent)
        return out
    return parts


# ---------------------------------------------------------------- 装配配置

def build_config(asset, origin=None):
    from ship_parts.assembly import BuildConfig, PivotSpec

    spec = SPECS[asset]
    prefix = spec["prefix"]
    sockets = _sockets(asset)
    pivots = [PivotSpec(s["key"], s["name"], s["location"],
                        parent=s["parent"]) for s in sockets]
    origins = {s["key"]: s["location"] for s in sockets}
    pos = origin if origin is not None else WORKBENCH_POS[asset]
    footprint = spec.get("base_footprint") or spec.get("module") or (
        spec["bbox"][0], spec["bbox"][1])
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
    }
    if "mount_class" in spec:
        root_props["mount_class"] = spec["mount_class"]
    # 武器装配规范 v2（kit 武器部件同样使用标准节点名）
    weapon_profiles = {
        "SN_Weapon_Cannon": ("pitch_only", False, True, True, True),
        "SN_Weapon_GunCarriage": ("base_only", True, False, False, False),
        "SN_Weapon_Turret": ("yaw_only", True, False, False, True),
        "SN_Weapon_Pedestal": ("base_only", True, False, False, False),
    }
    if asset in weapon_profiles:
        profile, has_yaw, has_pitch, has_recoil, has_muzzle = \
            weapon_profiles[asset]
        root_props.update({
            "assembly_spec": "weapon-assembly@2",
            "weapon_class": "Modular",
            "assembly_profile": profile,
            "socket": "SN_Socket_Weapon",
            "mount": "SN_Mount",
            "pivot_yaw": "SN_Pivot_Yaw" if has_yaw else "",
            "pivot_pitch": "SN_Pivot_Pitch" if has_pitch else "",
            "recoil": "SN_Recoil" if has_recoil else "",
            "muzzle": "SN_Muzzle" if has_muzzle else "",
            "has_yaw": has_yaw,
            "has_pitch": has_pitch,
            "has_recoil": has_recoil,
            "has_muzzle": has_muzzle,
            "yaw_axis": "Z",
            "pitch_axis": "Y",
            "recoil_axis": "-X",
            "muzzle_count": 1,
        })
    if asset == "SN_ShipPart_Deck":
        root_props["weapon_sockets"] = [
            "SN_Socket_Weapon_Port", "SN_Socket_Weapon_Starboard"]
        root_props["socket_class"] = "Medium"
    if spec["family"] == "ship_parts":
        root_props["deck_height"] = float(spec.get("deck_height", 0.0))
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


# ---------------------------------------------------------------- Blender 装配

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
    print("KIT_BATCH1_REPORT %r" % {
        "assets": {asset: out[asset]["tris"] for asset in ASSETS},
        "total_tris": sum(v["tris"] for v in out.values()),
    })
    return out


if __name__ == "__main__":
    build_all_kits()
    report()
