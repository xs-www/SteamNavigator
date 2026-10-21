# -*- coding: utf-8 -*-
# @static-doc
# 作用：模型素材库批次 2（P1：机械 / 货物 / 码头）的参数化生成器与 Blender 装配入口。
#
# 10 件模块化资产：SN_Machinery_GearSet / Winch / PowerUnit，SN_Cargo_Crate /
# CoalScuttle / Tank / Pallet，SN_Dock_Structure / Jetty / Mooring。沿用批次 1 的
# 契约：每件资产 Mount 空节点 + 语义接口（Shaft_In/Out、Drum_Pivot、Stack_Top、
# Module_Next/Prev、Socket_Mooring…），Root extras 写 kit_family / part_role /
# datum / footprint / height。
#
# 工单：`tools/modeling/briefs/sn_kit_batch2.json`
# 约定：1 unit = 1 m；+X 前向、+Z 向上；machinery/cargo 与 dock 系缆设施根在底面
# z=0；码头结构与栈桥根在水线 z=0（栈桥桩到 z=-1.30），+Y 朝水域。
# 材质：共享贴图 `SN_Tex_*`（含新增 `SN_Tex_Coal`），见 `sn_kit_materials.py`。
#
# 用法：
# - Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
# - 纯 Python 干跑：`python tools/modeling/generators/dryrun_kit_batch2.py`
# - 导出 GLB：`python tools/modeling/generators/export_kit_batch2_glb.py`
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
    box,
    frame_box,
    taper_cyl,
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
    "SN_Machinery_GearSet",
    "SN_Machinery_Winch",
    "SN_Machinery_PowerUnit",
    "SN_Cargo_Crate",
    "SN_Cargo_CoalScuttle",
    "SN_Cargo_Tank",
    "SN_Cargo_Pallet",
    "SN_Dock_Structure",
    "SN_Dock_Jetty",
    "SN_Dock_Mooring",
]

WORKBENCH_POS = {
    "SN_Machinery_GearSet": (0.0, 560.0, 0.0),
    "SN_Machinery_Winch": (3.0, 560.0, 0.0),
    "SN_Machinery_PowerUnit": (8.5, 560.0, 0.0),
    "SN_Cargo_Crate": (0.0, 580.0, 0.0),
    "SN_Cargo_CoalScuttle": (2.0, 580.0, 0.0),
    "SN_Cargo_Tank": (5.0, 580.0, 0.0),
    "SN_Cargo_Pallet": (7.0, 580.0, 0.0),
    "SN_Dock_Structure": (-6.0, 600.0, 0.0),
    "SN_Dock_Jetty": (4.5, 600.0, 0.0),
    "SN_Dock_Mooring": (12.0, 600.0, 0.0),
}

SPECS = {
    "SN_Machinery_GearSet": {
        "collection": "SN_Machinery_GearSet_Prototype",
        "prefix": "SN_Machinery_GearSet_",
        "family": "machinery_kit",
        "role": "gear_set",
        "type": "three-stage gear train",
        "tri_budget": 2400,
        "bbox": (1.90, 1.12, 1.06),
        "tol": 0.10,
        "zmin": 0.0,
        "datum": "ground z=0; +X power flow; gear axes along Y",
        "required": ("BasePlate", "Frames", "Gears", "Shafts", "HandCrank"),
    },
    "SN_Machinery_Winch": {
        "collection": "SN_Machinery_Winch_Prototype",
        "prefix": "SN_Machinery_Winch_",
        "family": "machinery_kit",
        "role": "winch",
        "type": "hand winch with rope drum",
        "tri_budget": 2600,
        "bbox": (2.24, 1.82, 1.42),
        "tol": 0.12,
        "zmin": 0.0,
        "datum": "ground z=0; drum axis along Y at z=0.95",
        "required": ("Base", "Frames", "Drum", "Ratchet", "HandCrank"),
    },
    "SN_Machinery_PowerUnit": {
        "collection": "SN_Machinery_PowerUnit_Prototype",
        "prefix": "SN_Machinery_PowerUnit_",
        "family": "machinery_kit",
        "role": "power_unit",
        "type": "horizontal steam engine",
        "tri_budget": 3600,
        "bbox": (3.78, 1.44, 2.11),
        "tol": 0.12,
        "zmin": 0.0,
        "datum": "ground z=0; flywheel axis +Y at (1.25, 0, 0.95)",
        "required": ("Skid", "Cylinder", "Flywheel", "ValveGear", "Pipes"),
    },
    "SN_Cargo_Crate": {
        "collection": "SN_Cargo_Crate_Prototype",
        "prefix": "SN_Cargo_Crate_",
        "family": "cargo_kit",
        "role": "crate",
        "type": "steampunk cargo crate",
        "tri_budget": 1000,
        "bbox": (1.26, 1.19, 1.04),
        "tol": 0.06,
        "zmin": 0.0,
        "datum": "ground z=0; stackable along +Z",
        "required": ("Body", "Lid", "Corners", "Handles"),
    },
    "SN_Cargo_CoalScuttle": {
        "collection": "SN_Cargo_CoalScuttle_Prototype",
        "prefix": "SN_Cargo_CoalScuttle_",
        "family": "cargo_kit",
        "role": "coal_scuttle",
        "type": "wheeled coal hopper",
        "tri_budget": 1500,
        "bbox": (1.48, 1.14, 1.10),
        "tol": 0.08,
        "zmin": 0.0,
        "datum": "ground z=0; fill top at z=0.95",
        "required": ("Bin", "Coal", "Wheels", "Handle", "Spout"),
    },
    "SN_Cargo_Tank": {
        "collection": "SN_Cargo_Tank_Prototype",
        "prefix": "SN_Cargo_Tank_",
        "family": "cargo_kit",
        "role": "tank",
        "type": "riveted storage tank",
        "tri_budget": 2600,
        "bbox": (3.37, 1.60, 1.95),
        "tol": 0.12,
        "zmin": 0.0,
        "datum": "ground z=0; tank axis +X at z=0.95",
        "required": ("Tank", "Saddles", "Manhole", "Valve"),
    },
    "SN_Cargo_Pallet": {
        "collection": "SN_Cargo_Pallet_Prototype",
        "prefix": "SN_Cargo_Pallet_",
        "family": "cargo_kit",
        "role": "pallet",
        "type": "wooden cargo pallet",
        "tri_budget": 600,
        "bbox": (1.23, 1.02, 0.18),
        "tol": 0.04,
        "zmin": 0.0,
        "datum": "ground z=0; stackable along +Z",
        "required": ("Bearers", "Blocks", "Deck", "Straps"),
    },
    "SN_Dock_Structure": {
        "collection": "SN_Dock_Structure_Prototype",
        "prefix": "SN_Dock_Structure_",
        "family": "dock_kit",
        "role": "dock_structure",
        "type": "8.4 x 4.2 m quay module",
        "tri_budget": 3200,
        "bbox": (8.40, 4.47, 3.16),
        "tol": 0.12,
        "zmin": 0.0,
        "module": (8.40, 4.20),
        "deck_height": 3.02,
        "datum": "waterline z=0; quay top z=3.02; +Y water side",
        "required": ("QuayCore", "StoneFace", "Paving", "TimberCap", "Fenders", "AccessLadder"),
    },
    "SN_Dock_Jetty": {
        "collection": "SN_Dock_Jetty_Prototype",
        "prefix": "SN_Dock_Jetty_",
        "family": "dock_kit",
        "role": "jetty",
        "type": "8 x 2.6 m timber jetty module",
        "tri_budget": 3000,
        "bbox": (8.03, 2.66, 2.80),
        "tol": 0.12,
        "zmin": -1.30,
        "module": (8.00, 2.60),
        "deck_height": 1.30,
        "datum": "waterline z=0; deck z=1.30; piles to z=-1.30",
        "required": ("Deck", "Stringers", "Piles", "Braces", "AccessLadder"),
    },
    "SN_Dock_Mooring": {
        "collection": "SN_Dock_Mooring_Prototype",
        "prefix": "SN_Dock_Mooring_",
        "family": "dock_kit",
        "role": "mooring",
        "type": "twin-bitt mooring point",
        "tri_budget": 1400,
        "bbox": (1.56, 1.15, 0.95),
        "tol": 0.08,
        "zmin": 0.0,
        "datum": "deck surface z=0",
        "required": ("Base", "Bitts", "Crossbar", "MooringRing", "Chain", "RopeCoil"),
    },
}

SOCKETS = {
    "SN_Machinery_GearSet": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("SHAFT_IN", "Shaft_In", "ROOT", (-0.35, -0.48, 0.58)),
        ("SHAFT_OUT", "Shaft_Out", "ROOT", (0.62, -0.48, 0.50)),
        ("CRANK", "Crank", "ROOT", (-0.35, 0.66, 0.20)),
    ],
    "SN_Machinery_Winch": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("DRUM", "Drum_Pivot", "ROOT", (0.0, 0.0, 0.95)),
        ("ROPE_OUT", "Rope_Out", "ROOT", (0.90, 0.0, 1.10)),
        ("BRAKE", "Brake", "ROOT", (0.30, 0.66, 1.30)),
    ],
    "SN_Machinery_PowerUnit": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("SHAFT_OUT", "Shaft_Out", "ROOT", (1.25, 0.40, 0.95)),
        ("STEAM_IN", "Steam_In", "ROOT", (-1.55, 0.0, 1.95)),
        ("EXHAUST", "Exhaust_Out", "ROOT", (-0.40, 0.0, 2.10)),
        ("COUPLING", "Coupling", "ROOT", (1.25, 0.0, 0.95)),
    ],
    "SN_Cargo_Crate": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("STACK_TOP", "Stack_Top", "ROOT", (0.0, 0.0, 1.035)),
        ("LIFT_L", "Lift_L", "ROOT", (0.0, 0.53, 0.62)),
        ("LIFT_R", "Lift_R", "ROOT", (0.0, -0.53, 0.62)),
    ],
    "SN_Cargo_CoalScuttle": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("FILL_TOP", "Fill_Top", "ROOT", (0.0, 0.0, 0.95)),
        ("CHUTE", "Chute", "ROOT", (0.76, 0.0, 0.38)),
    ],
    "SN_Cargo_Tank": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("FILL_TOP", "Fill_Top", "ROOT", (0.20, 0.0, 1.82)),
        ("OUTLET", "Outlet", "ROOT", (1.76, 0.0, 0.95)),
        ("VENT", "Vent", "ROOT", (-0.60, 0.0, 1.95)),
    ],
    "SN_Cargo_Pallet": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("STACK_TOP", "Stack_Top", "ROOT", (0.0, 0.0, 0.18)),
    ],
    "SN_Dock_Structure": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("MODULE_NEXT", "Module_Next", "ROOT", (4.20, 0.0, 3.02)),
        ("MODULE_PREV", "Module_Prev", "ROOT", (-4.20, 0.0, 3.02)),
        ("MOORING_1", "Socket_Mooring_1", "ROOT", (2.40, 0.0, 3.02)),
        ("MOORING_2", "Socket_Mooring_2", "ROOT", (-2.40, 0.0, 3.02)),
        ("JETTY", "Socket_Jetty", "ROOT", (0.0, 2.10, 1.30)),
    ],
    "SN_Dock_Jetty": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("MODULE_NEXT", "Module_Next", "ROOT", (4.00, 0.0, 1.30)),
        ("MODULE_PREV", "Module_Prev", "ROOT", (-4.00, 0.0, 1.30)),
        ("MOORING", "Socket_Mooring", "ROOT", (2.00, 0.0, 1.30)),
        ("LADDER", "Ladder", "ROOT", (-4.00, 0.0, 1.30)),
    ],
    "SN_Dock_Mooring": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("BITT_PORT", "Bitt_Port", "ROOT", (-0.42, 0.0, 0.95)),
        ("BITT_STARBOARD", "Bitt_Starboard", "ROOT", (0.42, 0.0, 0.95)),
        ("RING", "Ring", "ROOT", (0.0, 0.52, 0.40)),
        ("ROPE_TIE", "Rope_Tie", "ROOT", (-0.55, 0.25, 0.33)),
    ],
}


def _sockets(asset):
    prefix = SPECS[asset]["prefix"]
    return [{"key": key, "name": prefix + name, "parent": parent,
             "location": loc} for key, name, parent, loc in SOCKETS[asset]]


# ---------------------------------------------------------------- 通用工具

def _fbox(part, center, u, v, w, hu, hv, hw, mat):
    part.add(frame_box(center, u, v, w, hu, hv, hw), mat)


def _bolt_ring(part, cx, cy, z, radius, count, mat, r=0.045, h=0.06, sides=6):
    wk.bolt_circle(part, (cx, cy, z), radius, count, r, h, mat)


def _rivet_ring(part, center, axis, radius, count, mat, r=0.032, h=0.05,
                sides=6):
    wk.bolt_circle(part, center, radius, count, r, h, mat, axis=axis)


def _gear(part, center, radius, thickness, teeth, mat_face, mat_teeth,
          hub_mat, spokes=4):
    """沿 Y 轴的直齿轮：轮盘 + 齿 + 轮毂 + 辐条。"""
    cx, cy, cz = center
    r_in = radius * 0.80
    wk.add_cyl(part, (cx, cy - thickness * 0.5, cz),
               (cx, cy + thickness * 0.5, cz), r_in, r_in, mat_face, 16)
    tooth_w = 2.0 * math.pi * radius / teeth * 0.46
    for i in range(teeth):
        a = 2.0 * math.pi * i / teeth
        radial = (math.cos(a), 0.0, math.sin(a))
        tangent = (-math.sin(a), 0.0, math.cos(a))
        center_t = (cx + math.cos(a) * (r_in + radius * 0.10),
                    cy, cz + math.sin(a) * (r_in + radius * 0.10))
        _fbox(part, center_t, radial, tangent, (0.0, 1.0, 0.0),
              radius * 0.12, tooth_w * 0.5, thickness * 0.52, mat_teeth)
    wk.add_cyl(part, (cx, cy - thickness * 0.85, cz),
               (cx, cy + thickness * 0.85, cz), radius * 0.18,
               radius * 0.18, hub_mat, 10)
    for i in range(spokes):
        a = 2.0 * math.pi * i / spokes
        p = (cx + math.cos(a) * r_in * 0.92, cy,
             cz + math.sin(a) * r_in * 0.92)
        part.add(bar_between((cx, cy, cz), p, radius * 0.07), mat_face)


def _rope_coil(part, center, axis, radius, count, tube_r, mat, spacing=0.06):
    """绳圈：沿轴叠放的圆环。"""
    for i in range(count):
        p = vadd(center, vmul(vnorm(axis), (i - (count - 1) * 0.5) * spacing))
        wk.add_torus(part, p, axis, radius, tube_r, mat, seg=12, tube=4)


def _ladder(part, p0, p1, width, mat, rungs=0, step=0.36, rail_r=0.035,
            rung_r=0.024):
    wk.ladder(part, p0, p1, width, mat, step=step, rail_r=rail_r,
              rung_r=rung_r)


# ---------------------------------------------------------------- 1. 齿轮组

def _build_gearset():
    prefix = "SN_Machinery_GearSet_"
    parts = {}

    base = Part()
    wk.add_box(base, (-0.95, -0.42, 0.0), (0.95, 0.42, 0.14), MAT_IRON)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            wk.add_box(base, (sx * 0.82 - 0.10, sy * 0.34 - 0.08, 0.0),
                       (sx * 0.82 + 0.10, sy * 0.34 + 0.08, 0.20), MAT_IRON)
            wk.add_bolt(base, (sx * 0.82, sy * 0.34, 0.22), 0.05, 0.07,
                        MAT_BRASS)
    wk.add_box(base, (-0.86, -0.46, 0.0), (0.86, -0.42, 0.02), MAT_IRON_RED)
    parts[prefix + "BasePlate"] = (base, "ROOT")

    frames = Part()
    for sy in (-1.0, 1.0):
        y = sy * 0.34
        # 开式机架：4 根立柱 + 上下横梁，齿轮从 ±Y 侧可见
        for x in (-0.74, 0.74):
            wk.add_box(frames, (x - 0.07, y - 0.05, 0.14),
                       (x + 0.07, y + 0.05, 1.06), MAT_IRON)
        wk.add_box(frames, (-0.80, y - 0.05, 0.14), (0.80, y + 0.05, 0.24),
                   MAT_IRON)
        wk.add_box(frames, (-0.80, y - 0.05, 0.96), (0.80, y + 0.05, 1.06),
                   MAT_IRON)
        for x, z, r in ((-0.35, 0.58, 0.13), (0.28, 0.74, 0.11),
                        (0.62, 0.50, 0.10)):
            # 竖撑 + 轴承座 + 黄铜减重环
            wk.add_box(frames, (x - 0.05, y - 0.04, 0.24),
                       (x + 0.05, y + 0.04, z - r * 0.7), MAT_IRON)
            wk.add_torus(frames, (x, y, z), (0.0, 1.0, 0.0), r * 1.15,
                         0.035, MAT_BRASS, seg=8, tube=3)
            wk.add_cyl(frames, (x, y - 0.09, z), (x, y + 0.09, z), r, r,
                       MAT_METAL, 10)
    parts[prefix + "Frames"] = (frames, "ROOT")

    gears = Part()
    gear_specs = (
        (-0.35, 0.58, 0.42, 0.14, 24, MAT_IRON_RED),
        (0.28, 0.74, 0.22, 0.12, 14, MAT_METAL),
        (0.62, 0.50, 0.18, 0.12, 12, MAT_BRASS),
    )
    for x, z, r, t, teeth, mat in gear_specs:
        _gear(gears, (x, 0.0, z), r, t, teeth, mat, mat, MAT_BRASS, spokes=4)
    parts[prefix + "Gears"] = (gears, "ROOT")

    shafts = Part()
    for x, z, r in ((-0.35, 0.58, 0.055), (0.28, 0.74, 0.045),
                    (0.62, 0.50, 0.040)):
        wk.add_cyl(shafts, (x, -0.42, z), (x, 0.42, z), r, r, MAT_METAL, 8)
    parts[prefix + "Shafts"] = (shafts, "ROOT")

    crank = Part()
    # 大齿轮轴 +Y 端的手摇曲柄
    wk.add_cyl(crank, (-0.35, 0.40, 0.58), (-0.35, 0.52, 0.58), 0.075, 0.075,
               MAT_METAL, 8)
    crank.add(bar_between((-0.35, 0.52, 0.58), (-0.35, 0.52, 0.18), 0.055),
              MAT_WOOD_DARK)
    wk.add_cyl(crank, (-0.35, 0.52, 0.18), (-0.35, 0.66, 0.18), 0.045, 0.045,
               MAT_BRASS, 8)
    wk.add_box(crank, (-0.42, 0.50, 0.56), (-0.28, 0.54, 0.62), MAT_IRON)
    parts[prefix + "HandCrank"] = (crank, "ROOT")

    return parts


# ---------------------------------------------------------------- 2. 卷扬机

def _build_winch():
    prefix = "SN_Machinery_Winch_"
    parts = {}

    base = Part()
    for sy in (-1.0, 1.0):
        wk.add_box(base, (-1.10, sy * 0.35 - 0.11, 0.0),
                   (1.10, sy * 0.35 + 0.11, 0.14), MAT_WOOD_DARK)
        wk.add_box(base, (-1.12, sy * 0.35 - 0.13, 0.10),
                   (-0.98, sy * 0.35 + 0.13, 0.18), MAT_IRON)
        wk.add_box(base, (0.98, sy * 0.35 - 0.13, 0.10),
                   (1.12, sy * 0.35 + 0.13, 0.18), MAT_IRON)
    wk.add_box(base, (-0.90, -0.42, 0.0), (0.90, 0.42, 0.12), MAT_WOOD)
    for x in (-0.95, 0.0, 0.95):
        wk.add_box(base, (x - 0.06, -0.48, 0.12), (x + 0.06, 0.48, 0.20),
                   MAT_IRON)
    _bolt_ring(base, 0.0, 0.0, 0.14, 0.86, 4, MAT_BRASS, r=0.05, h=0.07)
    parts[prefix + "Base"] = (base, "ROOT")

    frames = Part()
    for sy in (-1.0, 1.0):
        # A 形侧架：两片斜板 + 顶轴承座
        wk.add_box(frames, (-0.62, sy * 0.56 - 0.05, 0.14),
                   (0.62, sy * 0.56 + 0.05, 1.24), MAT_IRON)
        for sx in (-1.0, 1.0):
            frames.add(bar_between((sx * 0.58, sy * 0.56, 0.16),
                                   (0.0, sy * 0.56, 0.98), 0.075), MAT_IRON_RED)
        wk.add_cyl(frames, (0.0, sy * 0.56 - 0.10, 0.95),
                   (0.0, sy * 0.56 + 0.10, 0.95), 0.17, 0.17, MAT_METAL, 12)
        wk.add_cyl(frames, (0.0, sy * 0.56 - 0.11, 0.95),
                   (0.0, sy * 0.56 + 0.11, 0.95), 0.09, 0.09, MAT_BRASS, 8)
    parts[prefix + "Frames"] = (frames, "ROOT")

    drum = Part()
    # 绳鼓：鼓身 + 两侧法兰 + 缠绳
    wk.add_cyl(drum, (0.0, -0.46, 0.95), (0.0, 0.46, 0.95), 0.30, 0.30,
               MAT_METAL, 14)
    for sy in (-1.0, 1.0):
        wk.add_cyl(drum, (0.0, sy * 0.46 - 0.04, 0.95),
                   (0.0, sy * 0.46 + 0.04, 0.95), 0.37, 0.37, MAT_IRON, 14)
    _rope_coil(drum, (0.0, 0.0, 0.95), (0.0, 1.0, 0.0), 0.335, 6, 0.035,
               MAT_CANVAS_SHADE, spacing=0.13)
    # 出绳 + 吊钩
    drum.add(wk.frame_box((0.25, 0.0, 1.25), (1.0, 0.0, 0.0),
                          (0.0, 1.0, 0.0), (0.0, 0.0, 1.0),
                          0.25, 0.03, 0.03), MAT_CANVAS_SHADE)
    wk.add_tube(drum, [(0.50, 0.0, 1.25), (0.82, 0.05, 1.20),
                       (0.90, 0.05, 1.10)], [0.028, 0.026, 0.024],
                MAT_CANVAS_SHADE, 4)
    wk.add_torus(drum, (0.90, 0.05, 1.04), (1.0, 0.0, 0.0), 0.055, 0.016,
                 MAT_IRON, seg=8, tube=3)
    parts[prefix + "Drum"] = (drum, "ROOT")

    ratchet = Part()
    # 棘轮（+Y 端）+ 棘爪
    _gear(ratchet, (0.0, 0.62, 0.95), 0.46, 0.10, 18, MAT_IRON_RED,
          MAT_IRON_RED, MAT_BRASS, spokes=4)
    wk.add_cyl(ratchet, (0.0, 0.56, 0.95), (0.0, 0.70, 0.95), 0.10, 0.10,
               MAT_METAL, 10)
    ratchet.add(bar_between((0.42, 0.72, 0.95), (0.30, 0.72, 0.72), 0.045),
                MAT_IRON)
    wk.add_box(ratchet, (0.22, 0.66, 0.62), (0.36, 0.78, 0.74), MAT_IRON)
    wk.add_box(ratchet, (0.36, 0.68, 0.84), (0.50, 0.76, 0.90), MAT_BRASS)
    parts[prefix + "Ratchet"] = (ratchet, "ROOT")

    crank = Part()
    # -Y 端手摇曲柄 + 木柄
    wk.add_cyl(crank, (0.0, -0.56, 0.95), (0.0, -0.68, 0.95), 0.09, 0.085,
               MAT_METAL, 10)
    crank.add(bar_between((0.0, -0.68, 0.95), (0.0, -0.68, 0.40), 0.055),
              MAT_IRON_RED)
    wk.add_cyl(crank, (0.0, -0.72, 0.40), (0.0, -0.86, 0.40), 0.045, 0.045,
               MAT_WOOD, 8)
    # 刹车带 + 手柄
    for sy in (-1.0, 1.0):
        wk.add_box(crank, (-0.28, sy * 0.18 - 0.10, 1.33),
                   (0.28, sy * 0.18 + 0.10, 1.40), MAT_IRON)
    crank.add(bar_between((0.0, 0.28, 1.36), (0.36, 0.58, 1.30), 0.040),
              MAT_IRON)
    parts[prefix + "HandCrank"] = (crank, "ROOT")

    return parts


# ---------------------------------------------------------------- 3. 动力装置

def _build_powerunit():
    prefix = "SN_Machinery_PowerUnit_"
    parts = {}

    skid = Part()
    for sy in (-1.0, 1.0):
        wk.add_box(skid, (-1.80, sy * 0.60 - 0.10, 0.0),
                   (1.80, sy * 0.60 + 0.10, 0.16), MAT_WOOD_DARK)
        wk.add_box(skid, (-1.84, sy * 0.60 - 0.12, 0.10),
                   (-1.66, sy * 0.60 + 0.12, 0.18), MAT_IRON)
        wk.add_box(skid, (1.66, sy * 0.60 - 0.12, 0.10),
                   (1.84, sy * 0.60 + 0.12, 0.18), MAT_IRON)
    for x in (-1.45, -0.40, 0.65, 1.55):
        wk.add_box(skid, (x - 0.10, -0.70, 0.0), (x + 0.10, 0.70, 0.10),
                   MAT_WOOD)
    parts[prefix + "Skid"] = (skid, "ROOT")

    cylinder = Part()
    wk.add_cyl(cylinder, (-1.60, 0.0, 0.95), (-0.28, 0.0, 0.95), 0.40, 0.40,
               MAT_IRON_RED, 16)
    for x in (-1.62, -0.26):
        wk.add_cyl(cylinder, (x - 0.04, 0.0, 0.95), (x + 0.04, 0.0, 0.95),
                   0.47, 0.47, MAT_METAL, 16)
        _rivet_ring(cylinder, (x, 0.0, 0.95), (1.0, 0.0, 0.0), 0.40, 10,
                    MAT_BRASS, r=0.03, h=0.05)
    # 活塞杆 + 十字头 + 导轨
    wk.add_cyl(cylinder, (-0.26, 0.0, 0.95), (0.38, 0.0, 0.95), 0.065, 0.060,
               MAT_METAL, 10)
    wk.add_box(cylinder, (0.38, -0.16, 0.82), (0.60, 0.16, 1.08), MAT_IRON)
    for sy in (-1.0, 1.0):
        wk.add_cyl(cylinder, (0.20, sy * 0.20, 0.95),
                   (0.78, sy * 0.20, 0.95), 0.035, 0.035, MAT_METAL, 8)
    # 连杆到曲柄销
    cylinder.add(bar_between((0.56, 0.0, 0.95), (1.50, 0.0, 1.20), 0.055),
                 MAT_METAL)
    parts[prefix + "Cylinder"] = (cylinder, "ROOT")

    flywheel = Part()
    fx, fz = 1.25, 0.95
    wk.add_cyl(flywheel, (fx, -0.16, fz), (fx, 0.16, fz), 0.15, 0.15,
               MAT_IRON, 12)
    wk.add_torus(flywheel, (fx, 0.0, fz), (0.0, 1.0, 0.0), 0.62, 0.070,
                 MAT_IRON, seg=16, tube=4)
    for i in range(8):
        a = 2.0 * math.pi * i / 8.0
        p = (fx + math.cos(a) * 0.56, 0.0, fz + math.sin(a) * 0.56)
        flywheel.add(bar_between((fx, 0.0, fz), p, 0.055), MAT_IRON)
    # 皮带槽
    for sy in (-0.06, 0.06):
        wk.add_torus(flywheel, (fx, sy, fz), (0.0, 1.0, 0.0), 0.585, 0.028,
                     MAT_BRASS, seg=16, tube=3)
    # 曲柄销
    wk.add_cyl(flywheel, (1.50, -0.10, 1.20), (1.50, 0.10, 1.20), 0.055,
               0.055, MAT_BRASS, 8)
    # 飞轮轴 + 两侧轴承座/立柱，下方加承梁落到纵梁，避免飞轮悬空
    wk.add_cyl(flywheel, (fx, -0.44, fz), (fx, 0.44, fz), 0.070, 0.070,
               MAT_METAL, 10)
    wk.add_box(flywheel, (1.05, -0.70, 0.0), (1.45, 0.70, 0.16),
               MAT_WOOD_DARK)
    wk.add_box(flywheel, (1.05, -0.72, 0.10), (1.45, 0.72, 0.16), MAT_IRON)
    for sy in (-1.0, 1.0):
        wk.add_box(flywheel, (fx - 0.14, sy * 0.30 - 0.05, 0.16),
                   (fx + 0.14, sy * 0.30 + 0.05, 0.90), MAT_IRON_RED)
        wk.add_box(flywheel, (fx - 0.17, sy * 0.24 - 0.09, 0.88),
                   (fx + 0.17, sy * 0.24 + 0.09, 1.02), MAT_METAL)
        wk.add_cyl(flywheel, (fx, sy * 0.22, fz), (fx, sy * 0.42, fz),
                   0.12, 0.11, MAT_METAL, 10)
        wk.add_bolt(flywheel, (fx, sy * 0.24, 1.05), 0.035, 0.05, MAT_BRASS)
    parts[prefix + "Flywheel"] = (flywheel, "ROOT")

    valve = Part()
    # 阀箱 + 阀杆 + 手轮
    wk.add_box(valve, (-1.48, -0.20, 1.30), (-0.80, 0.20, 1.58), MAT_IRON)
    wk.add_cyl(valve, (-1.14, 0.0, 1.58), (-1.14, 0.0, 1.80), 0.045, 0.040,
               MAT_METAL, 8)
    wk.handwheel(valve, (-1.14, 0.0, 1.82), (0.0, 0.0, 1.0), 0.15, MAT_BRASS,
                 spokes=4, hub_r=0.05)
    # 压力表
    wk.add_cyl(valve, (-1.30, 0.22, 1.40), (-1.30, 0.34, 1.40), 0.11, 0.11,
               MAT_BRASS, 12)
    wk.add_cyl(valve, (-1.30, 0.34, 1.40), (-1.30, 0.36, 1.40), 0.085, 0.085,
               MAT_GLASS_DARK, 12)
    # 调速器：立柱从汽缸顶（z=1.35）升起，带法兰底座，不再悬空
    wk.add_cyl(valve, (-0.60, 0.0, 1.35), (-0.60, 0.0, 1.58), 0.090, 0.075,
               MAT_IRON, 8)
    wk.add_cyl(valve, (-0.60, 0.0, 1.52), (-0.60, 0.0, 1.58), 0.130, 0.120,
               MAT_METAL, 8)
    wk.add_cyl(valve, (-0.60, 0.0, 1.58), (-0.60, 0.0, 1.96), 0.035, 0.030,
               MAT_METAL, 8)
    for sx in (-1.0, 1.0):
        valve.add(bar_between((-0.60, 0.0, 1.90),
                             (-0.60 + sx * 0.20, 0.0, 1.70), 0.030), MAT_BRASS)
        wk.add_cyl(valve, (-0.60 + sx * 0.20, -0.04, 1.66),
                   (-0.60 + sx * 0.20, 0.04, 1.66), 0.070, 0.070,
                   MAT_BRASS, 8)
    parts[prefix + "ValveGear"] = (valve, "ROOT")

    pipes = Part()
    # 进汽管 + 排气管 + 法兰
    wk.add_cyl(pipes, (-1.60, 0.0, 1.30), (-1.60, 0.0, 1.95), 0.11, 0.10,
               MAT_BRASS, 10)
    wk.add_cyl(pipes, (-1.60, 0.0, 1.95), (-1.30, 0.0, 2.02), 0.10, 0.10,
               MAT_BRASS, 10)
    for z in (1.40, 1.80):
        wk.add_cyl(pipes, (-1.60, 0.0, z - 0.035), (-1.60, 0.0, z + 0.035),
                   0.14, 0.14, MAT_IRON, 10)
    wk.add_cyl(pipes, (-0.40, 0.0, 1.36), (-0.40, 0.0, 2.02), 0.10, 0.09,
               MAT_IRON, 10)
    wk.add_cyl(pipes, (-0.40, 0.0, 2.02), (-0.40, 0.0, 2.10), 0.16, 0.14,
               MAT_IRON, 10)
    for z in (1.55, 1.90):
        wk.add_cyl(pipes, (-0.40, 0.0, z - 0.035), (-0.40, 0.0, z + 0.035),
                   0.13, 0.13, MAT_BRASS, 10)
    parts[prefix + "Pipes"] = (pipes, "ROOT")

    return parts


# ---------------------------------------------------------------- 4. 货箱

def _build_crate():
    prefix = "SN_Cargo_Crate_"
    parts = {}

    body = Part()
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            wk.add_box(body, (sx * 0.52 - 0.08, sy * 0.42 - 0.08, 0.0),
                       (sx * 0.52 + 0.08, sy * 0.42 + 0.08, 0.10), MAT_IRON)
    # 6 片箱板（底板 + 4 侧板 + 盖板）
    wk.add_box(body, (-0.61, -0.51, 0.10), (0.61, 0.51, 0.20), MAT_WOOD)
    for sy in (-1.0, 1.0):
        wk.add_box(body, (-0.61, sy * 0.45, 0.20), (0.61, sy * 0.51, 0.92),
                   MAT_WOOD)
    for sx in (-1.0, 1.0):
        wk.add_box(body, (sx * 0.55, -0.45, 0.20), (sx * 0.61, 0.45, 0.92),
                   MAT_WOOD)
    # 表面板条（竖向板缝）
    for sy in (-1.0, 1.0):
        for x in (-0.38, -0.12, 0.14, 0.40):
            wk.add_box(body, (x - 0.055, sy * 0.51, 0.22),
                       (x + 0.055, sy * 0.515, 0.90), MAT_WOOD_DARK)
    parts[prefix + "Body"] = (body, "ROOT")

    lid = Part()
    wk.add_box(lid, (-0.63, -0.53, 0.92), (0.63, 0.53, 1.00), MAT_WOOD_DECK)
    for sy in (-1.0, 1.0):
        for x in (-0.40, -0.14, 0.14, 0.40):
            wk.add_box(lid, (x - 0.06, sy * 0.53, 1.00),
                       (x + 0.06, sy * 0.535, 1.02), MAT_WOOD_DARK)
    # 盖板提手
    for sx in (-1.0, 1.0):
        wk.add_box(lid, (sx * 0.36 - 0.05, -0.08, 1.00),
                   (sx * 0.36 + 0.05, 0.08, 1.035), MAT_IRON)
    parts[prefix + "Lid"] = (lid, "ROOT")

    corners = Part()
    # 8 个铁包角 + 4 道铁带
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            x_in, x_out = sorted((sx * 0.55, sx * 0.63))
            y_in, y_out = sorted((sy * 0.45, sy * 0.53))
            wk.add_box(corners, (x_in, y_in, 0.10), (x_out, y_out, 0.28),
                       MAT_IRON)
            wk.add_box(corners, (x_in, y_in, 0.84), (x_out, y_out, 1.02),
                       MAT_IRON)
    for x in (-0.34, 0.34):
        wk.add_box(corners, (x - 0.04, -0.52, 0.20), (x + 0.04, 0.52, 0.92),
                   MAT_IRON)
    # 黄铜铭牌
    wk.add_box(corners, (-0.16, 0.53, 0.52), (0.16, 0.545, 0.70), MAT_BRASS)
    wk.add_box(corners, (-0.10, 0.545, 0.56), (0.10, 0.55, 0.66),
               MAT_GLASS_DARK)
    parts[prefix + "Corners"] = (corners, "ROOT")

    handles = Part()
    for sy in (-1.0, 1.0):
        wk.add_torus(handles, (0.0, sy * 0.50, 0.62), (1.0, 0.0, 0.0), 0.075,
                     0.020, MAT_CANVAS_SHADE, seg=10, tube=3)
        wk.add_box(handles, (-0.14, sy * 0.51, 0.50), (0.14, sy * 0.515, 0.74),
                   MAT_IRON)
        for sx in (-1.0, 1.0):
            wk.add_box(handles, (sx * 0.10 - 0.03, sy * 0.51, 0.50),
                       (sx * 0.10 + 0.03, sy * 0.54, 0.55), MAT_METAL)
    parts[prefix + "Handles"] = (handles, "ROOT")

    return parts


# ---------------------------------------------------------------- 5. 煤斗

def _build_coal_scuttle():
    prefix = "SN_Cargo_CoalScuttle_"
    parts = {}

    bin_part = Part()
    # 收分煤斗：上宽下窄
    wk.add_frustum(bin_part, 0.28, 0.92, 0.40, 0.55, MAT_IRON_RED)
    wk.add_box(bin_part, (-0.46, -0.36, 0.22), (0.46, 0.36, 0.30), MAT_IRON)
    # 上口沿
    for sy in (-1.0, 1.0):
        wk.add_box(bin_part, (-0.56, sy * 0.50, 0.90), (0.56, sy * 0.57, 0.96),
                   MAT_IRON)
    for sx in (-1.0, 1.0):
        wk.add_box(bin_part, (sx * 0.52, -0.50, 0.90), (sx * 0.59, 0.50, 0.96),
                   MAT_IRON)
    # 侧壁加强条
    for sy in (-1.0, 1.0):
        for z in (0.45, 0.68):
            wk.add_box(bin_part, (-0.52, sy * 0.48, z),
                       (0.52, sy * 0.505, z + 0.05), MAT_IRON)
    # 出料口 + 挡板
    wk.add_box(bin_part, (0.46, -0.24, 0.34), (0.62, 0.24, 0.56), MAT_METAL)
    wk.add_box(bin_part, (0.60, -0.20, 0.38), (0.64, 0.20, 0.52),
               MAT_GLASS_DARK)
    parts[prefix + "Bin"] = (bin_part, "ROOT")

    coal = Part()
    # 顶部碎煤堆（锥体 + 几块散煤）
    wk.add_cyl(coal, (0.0, 0.0, 0.88), (0.0, 0.0, 1.10), 0.43, 0.08,
               MAT_COAL, 10)
    for (x, y, z, s) in ((-0.28, 0.22, 1.02, 0.10), (0.25, -0.20, 1.00, 0.09),
                         (0.05, 0.30, 0.96, 0.08), (-0.30, -0.24, 0.95, 0.07)):
        coal.add(frame_box((x, y, z), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0),
                           (0.0, 0.0, 1.0), s, s * 0.8, s * 0.7), MAT_COAL)
    parts[prefix + "Coal"] = (coal, "ROOT")

    wheels = Part()
    for sy in (-1.0, 1.0):
        cx, cy, cz = -0.28, sy * 0.46, 0.22
        wk.add_cyl(wheels, (cx, cy - 0.05, cz), (cx, cy + 0.05, cz), 0.20,
                   0.20, MAT_WOOD_DARK, 12)
        wk.add_cyl(wheels, (cx, cy - 0.06, cz), (cx, cy + 0.06, cz), 0.21,
                   0.21, MAT_IRON, 12)
        wk.add_cyl(wheels, (cx, cy - 0.08, cz), (cx, cy + 0.08, cz), 0.06,
                   0.06, MAT_BRASS, 8)
    wk.add_cyl(wheels, (-0.28, -0.52, 0.22), (-0.28, 0.52, 0.22), 0.05, 0.05,
               MAT_METAL, 8)
    parts[prefix + "Wheels"] = (wheels, "ROOT")

    handle_part = Part()
    for sy in (-1.0, 1.0):
        handle_part.add(bar_between((0.40, sy * 0.34, 0.60),
                                    (0.86, sy * 0.30, 0.82), 0.045),
                        MAT_IRON)
    wk.add_cyl(handle_part, (0.84, -0.32, 0.82), (0.84, 0.32, 0.82), 0.045,
               0.045, MAT_WOOD, 8)
    # 前支腿
    for sy in (-1.0, 1.0):
        wk.add_box(handle_part, (0.40, sy * 0.30 - 0.06, 0.0),
                   (0.52, sy * 0.30 + 0.06, 0.30), MAT_IRON)
    parts[prefix + "Handle"] = (handle_part, "ROOT")

    chute = Part()
    # 出料滑槽（斜口）
    chute.add(frame_box((0.78, 0.0, 0.34), (0.85, 0.0, -0.53),
                        (0.0, 1.0, 0.0), (0.53, 0.0, 0.85),
                        0.10, 0.22, 0.05), MAT_IRON)
    wk.add_box(chute, (0.66, -0.20, 0.44), (0.72, 0.20, 0.50), MAT_METAL)
    parts[prefix + "Spout"] = (chute, "ROOT")

    return parts


# ---------------------------------------------------------------- 6. 储罐

def _build_tank():
    prefix = "SN_Cargo_Tank_"
    parts = {}

    tank = Part()
    wk.add_cyl(tank, (-1.50, 0.0, 0.95), (1.50, 0.0, 0.95), 0.72, 0.72,
               MAT_IRON, 16)
    for sx in (-1.0, 1.0):
        wk.add_cyl(tank, (sx * 1.50 - 0.05, 0.0, 0.95),
                   (sx * 1.50 + 0.05, 0.0, 0.95), 0.80, 0.72, MAT_IRON_RED, 16)
        _rivet_ring(tank, (sx * 1.50, 0.0, 0.95), (1.0, 0.0, 0.0), 0.68, 12,
                    MAT_BRASS, r=0.03, h=0.05)
    for x in (-0.75, 0.0, 0.75):
        wk.add_torus(tank, (x, 0.0, 0.95), (1.0, 0.0, 0.0), 0.735, 0.050,
                     MAT_IRON_RED, seg=16, tube=4)
    # 侧面铭牌
    wk.add_box(tank, (-0.30, -0.735, 0.80), (0.30, -0.745, 1.05), MAT_BRASS)
    parts[prefix + "Tank"] = (tank, "ROOT")

    saddles = Part()
    for sx in (-1.0, 1.0):
        wk.add_box(saddles, (sx * 0.90 - 0.28, -0.72, 0.0),
                   (sx * 0.90 + 0.28, 0.72, 0.52), MAT_STONE)
        wk.add_box(saddles, (sx * 0.90 - 0.30, -0.74, 0.0),
                   (sx * 0.90 + 0.30, 0.74, 0.10), MAT_STONE)
        for sy in (-1.0, 1.0):
            wk.add_box(saddles, (sx * 0.90 - 0.20, sy * 0.68, 0.46),
                       (sx * 0.90 + 0.20, sy * 0.72, 0.54), MAT_IRON)
    parts[prefix + "Saddles"] = (saddles, "ROOT")

    manhole = Part()
    wk.add_cyl(manhole, (0.20, 0.0, 1.60), (0.20, 0.0, 1.76), 0.30, 0.30,
               MAT_IRON_RED, 12)
    wk.add_cyl(manhole, (0.20, 0.0, 1.76), (0.20, 0.0, 1.82), 0.34, 0.32,
               MAT_METAL, 12)
    _bolt_ring(manhole, 0.20, 0.0, 1.78, 0.28, 8, MAT_BRASS, r=0.03, h=0.05)
    wk.add_cyl(manhole, (0.20, 0.0, 1.82), (0.20, 0.0, 1.88), 0.30, 0.28,
               MAT_IRON, 12)
    wk.add_torus(manhole, (0.20, 0.0, 1.88), (0.0, 0.0, 1.0), 0.25, 0.022,
                 MAT_BRASS, seg=10, tube=3)
    wk.add_box(manhole, (0.14, -0.16, 1.88), (0.26, 0.16, 1.92), MAT_BRASS)
    parts[prefix + "Manhole"] = (manhole, "ROOT")

    valve = Part()
    wk.add_cyl(valve, (1.50, 0.0, 0.95), (1.76, 0.0, 0.95), 0.11, 0.10,
               MAT_BRASS, 10)
    wk.add_cyl(valve, (1.70, 0.0, 0.95), (1.72, 0.0, 0.95), 0.16, 0.16,
               MAT_IRON, 10)
    wk.handwheel(valve, (1.76, 0.0, 0.95), (1.0, 0.0, 0.0), 0.16,
                 MAT_BRASS, spokes=4, hub_r=0.05)
    wk.add_cyl(valve, (1.60, 0.0, 0.95), (1.60, 0.0, 1.10), 0.05, 0.045,
               MAT_METAL, 6)
    # 排气管
    wk.add_cyl(valve, (-0.60, 0.0, 1.60), (-0.60, 0.0, 1.92), 0.075, 0.065,
               MAT_BRASS, 8)
    wk.add_cyl(valve, (-0.60, 0.0, 1.92), (-0.60, 0.0, 1.95), 0.13, 0.11,
               MAT_IRON, 8)
    parts[prefix + "Valve"] = (valve, "ROOT")

    return parts


# ---------------------------------------------------------------- 7. 托盘

def _build_pallet():
    prefix = "SN_Cargo_Pallet_"
    parts = {}

    bearers = Part()
    for y in (-0.42, 0.0, 0.42):
        wk.add_box(bearers, (-0.61, y - 0.08, 0.0), (0.61, y + 0.08, 0.10),
                   MAT_WOOD_DARK)
    parts[prefix + "Bearers"] = (bearers, "ROOT")

    blocks = Part()
    for x in (-0.52, 0.0, 0.52):
        wk.add_box(blocks, (x - 0.08, -0.50, 0.10), (x + 0.08, 0.50, 0.14),
                   MAT_WOOD)
    parts[prefix + "Blocks"] = (blocks, "ROOT")

    deck = Part()
    for i in range(7):
        x = -0.54 + i * 0.18
        wk.add_box(deck, (x - 0.075, -0.51, 0.14), (x + 0.075, 0.51, 0.18),
                   MAT_WOOD_DECK)
    parts[prefix + "Deck"] = (deck, "ROOT")

    straps = Part()
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            x0 = sx * 0.50 - 0.06 if sx > 0 else sx * 0.50 - 0.06
            y0 = sy * 0.42 - 0.06 if sy > 0 else sy * 0.42 - 0.06
            wk.add_box(straps, (x0, y0, 0.14), (x0 + 0.12, y0 + 0.12, 0.18),
                       MAT_IRON)
            wk.add_cyl(straps, (x0 + 0.06, y0 + 0.06, 0.175),
                       (x0 + 0.06, y0 + 0.06, 0.18), 0.045, 0.045,
                       MAT_BRASS, 8)
    parts[prefix + "Straps"] = (straps, "ROOT")

    return parts


# ---------------------------------------------------------------- 8. 码头结构

def _build_dock_structure():
    prefix = "SN_Dock_Structure_"
    parts = {}

    core = Part()
    wk.add_box(core, (-4.20, -2.10, 0.0), (4.20, 1.88, 2.90), MAT_STONE)
    parts[prefix + "QuayCore"] = (core, "ROOT")

    face = Part()
    # 6 层 × 10 列石砌墙面（朝 +Y 水域）
    for row in range(6):
        z0 = row * 0.48
        for col in range(10):
            x0 = -4.20 + col * 0.84
            wk.add_box(face, (x0 + 0.015, 1.88, z0 + 0.015),
                       (x0 + 0.825, 2.08, z0 + 0.455), MAT_STONE)
    # 顶部压顶石
    for col in range(10):
        x0 = -4.20 + col * 0.84
        wk.add_box(face, (x0 + 0.01, 1.86, 2.90), (x0 + 0.83, 2.12, 3.02),
                   MAT_STONE)
    parts[prefix + "StoneFace"] = (face, "ROOT")

    paving = Part()
    for sx in (-1.0, 1.0):
        for sy in (-1, 0, 1):
            wk.add_box(paving, (sx * 2.10 - 2.08, sy * 1.40 - 0.66, 2.90),
                       (sx * 2.10 + 2.08, sy * 1.40 + 0.66, 3.02), MAT_STONE)
    parts[prefix + "Paving"] = (paving, "ROOT")

    cap = Part()
    # 木压顶（沿 +Y 水侧）
    for x in (-4.20, -1.40, 1.40):
        wk.add_box(cap, (x, 1.86, 3.02), (x + 2.80, 2.22, 3.14), MAT_WOOD_DARK)
    for x in (-4.20, -1.40, 1.40):
        wk.add_box(cap, (x, 1.84, 3.02), (x + 2.80, 1.88, 3.16), MAT_IRON)
    parts[prefix + "TimberCap"] = (cap, "ROOT")

    fenders = Part()
    for x in (-3.0, -1.0, 1.0, 3.0):
        wk.add_box(fenders, (x - 0.13, 2.10, 0.18), (x + 0.13, 2.34, 2.82),
                   MAT_WOOD_DARK)
        for z in (0.55, 1.65, 2.60):
            wk.add_box(fenders, (x - 0.15, 2.08, z - 0.05),
                       (x + 0.15, 2.36, z + 0.05), MAT_IRON)
    # 系缆环
    for x in (-2.4, 2.4):
        wk.add_torus(fenders, (x, 2.22, 2.45), (0.0, 1.0, 0.0), 0.17, 0.035,
                     MAT_IRON, seg=10, tube=4)
        wk.add_box(fenders, (x - 0.12, 2.10, 2.32), (x + 0.12, 2.16, 2.58),
                   MAT_IRON)
    parts[prefix + "Fenders"] = (fenders, "ROOT")

    ladder = Part()
    # 贴墙爬梯：梯柱垂直、横档沿 X（与墙面平行）
    for sx in (-1.0, 1.0):
        wk.add_cyl(ladder, (sx * 0.18, 2.16, 0.02),
                   (sx * 0.18, 2.16, 2.86), 0.030, 0.030, MAT_WOOD_DARK, 6)
    for i in range(9):
        z = 0.18 + i * 0.32
        wk.add_cyl(ladder, (-0.18, 2.16, z), (0.18, 2.16, z), 0.022, 0.022,
                   MAT_WOOD_DARK, 6)
    for z in (0.55, 1.55, 2.55):
        wk.add_box(ladder, (-0.20, 2.10, z - 0.03), (0.20, 2.16, z + 0.03),
                   MAT_IRON)
    parts[prefix + "AccessLadder"] = (ladder, "ROOT")

    return parts


# ---------------------------------------------------------------- 9. 栈桥

def _build_jetty():
    prefix = "SN_Dock_Jetty_"
    parts = {}

    piles = Part()
    pile_positions = [(-3.40, -0.90), (-3.40, 0.90), (-1.10, -0.90),
                      (-1.10, 0.90), (1.10, -0.90), (1.10, 0.90),
                      (3.40, -0.90), (3.40, 0.90)]
    for x, y in pile_positions:
        wk.add_cyl(piles, (x, y, -1.30), (x, y, 1.14), 0.15, 0.13,
                   MAT_WOOD_DARK, 10)
        wk.add_cyl(piles, (x, y, 0.60), (x, y, 0.72), 0.16, 0.16, MAT_IRON, 10)
        wk.add_cyl(piles, (x, y, -0.90), (x, y, -0.80), 0.16, 0.16,
                   MAT_IRON, 10)
    parts[prefix + "Piles"] = (piles, "ROOT")

    stringers = Part()
    for y in (-0.78, 0.78):
        wk.add_box(stringers, (-3.95, y - 0.09, 1.02), (3.95, y + 0.09, 1.20),
                   MAT_WOOD_DARK)
    for x in (-3.40, -1.10, 1.10, 3.40):
        wk.add_box(stringers, (x - 0.10, -1.10, 1.02), (x + 0.10, 1.10, 1.20),
                   MAT_WOOD)
    parts[prefix + "Stringers"] = (stringers, "ROOT")

    deck = Part()
    for i in range(21):
        x = -3.80 + i * 0.38
        wk.add_box(deck, (x - 0.17, -1.20, 1.22), (x + 0.17, 1.20, 1.30),
                   MAT_WOOD_DECK)
    for sy in (-1.0, 1.0):
        wk.add_box(deck, (-4.00, sy * 1.20 - 0.06, 1.18),
                   (4.00, sy * 1.20 + 0.06, 1.32), MAT_WOOD_DARK)
    parts[prefix + "Deck"] = (deck, "ROOT")

    braces = Part()
    for x in (-3.40, -1.10, 1.10, 3.40):
        for sy in (-1.0, 1.0):
            braces.add(bar_between((x, sy * 0.90, 0.35),
                                   (x, sy * 1.06, 1.02), 0.065), MAT_WOOD)
    for sy in (-1.0, 1.0):
        braces.add(bar_between((-3.40, sy * 0.90, 0.45),
                               (-1.10, sy * 0.90, 1.02), 0.060), MAT_WOOD)
        braces.add(bar_between((1.10, sy * 0.90, 0.45),
                               (3.40, sy * 0.90, 1.02), 0.060), MAT_WOOD)
    # 边缘系缆板
    for x in (-2.0, 0.0, 2.0):
        wk.add_box(braces, (x - 0.18, 1.20, 1.30), (x + 0.18, 1.34, 1.38),
                   MAT_IRON)
        wk.add_cyl(braces, (x, 1.34, 1.38), (x, 1.34, 1.50), 0.06, 0.06,
                   MAT_BRASS, 8)
    parts[prefix + "Braces"] = (braces, "ROOT")

    ladder = Part()
    # 端部爬梯：贴在 -X 端面，梯柱垂直、横档沿 Y
    for sy in (-1.0, 1.0):
        wk.add_cyl(ladder, (-4.00, sy * 0.17, 0.02),
                   (-4.00, sy * 0.17, 1.30), 0.030, 0.030, MAT_WOOD_DARK, 6)
    for i in range(6):
        z = 0.10 + i * 0.24
        wk.add_cyl(ladder, (-4.00, -0.17, z), (-4.00, 0.17, z), 0.022,
                   0.022, MAT_WOOD_DARK, 6)
    for sy in (-1.0, 1.0):
        wk.add_box(ladder, (-4.00, sy * 0.17 - 0.04, 1.16),
                   (-3.90, sy * 0.17 + 0.04, 1.22), MAT_IRON)
    parts[prefix + "AccessLadder"] = (ladder, "ROOT")

    return parts


# ---------------------------------------------------------------- 10. 系缆设施

def _build_mooring():
    prefix = "SN_Dock_Mooring_"
    parts = {}

    base = Part()
    wk.add_box(base, (-0.72, -0.36, 0.0), (0.72, 0.36, 0.12), MAT_STONE)
    wk.add_box(base, (-0.78, -0.40, 0.10), (0.78, 0.40, 0.18), MAT_IRON)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            wk.add_bolt(base, (sx * 0.56, sy * 0.28, 0.20), 0.05, 0.06,
                        MAT_BRASS)
    parts[prefix + "Base"] = (base, "ROOT")

    bitts = Part()
    for sx in (-1.0, 1.0):
        cx = sx * 0.42
        wk.add_cyl(bitts, (cx, 0.0, 0.18), (cx, 0.0, 0.86), 0.15, 0.12,
                   MAT_IRON, 10)
        wk.add_cyl(bitts, (cx, 0.0, 0.82), (cx, 0.0, 0.95), 0.14, 0.13,
                   MAT_BRASS, 10)
        wk.add_cyl(bitts, (cx, 0.0, 0.56), (cx, 0.0, 0.62), 0.16, 0.16,
                   MAT_IRON, 10)
        wk.add_box(bitts, (cx - 0.14, -0.14, 0.12), (cx + 0.14, 0.14, 0.20),
                   MAT_IRON)
    parts[prefix + "Bitts"] = (bitts, "ROOT")

    crossbar = Part()
    wk.add_box(crossbar, (-0.58, -0.10, 0.68), (0.58, 0.10, 0.80),
               MAT_WOOD_DARK)
    for sx in (-1.0, 1.0):
        wk.add_box(crossbar, (sx * 0.46 - 0.04, -0.12, 0.66),
                   (sx * 0.46 + 0.04, 0.12, 0.82), MAT_IRON)
    parts[prefix + "Crossbar"] = (crossbar, "ROOT")

    ring = Part()
    wk.add_box(ring, (-0.10, 0.34, 0.16), (0.10, 0.44, 0.48), MAT_IRON)
    wk.add_torus(ring, (0.0, 0.52, 0.36), (0.0, 1.0, 0.0), 0.16, 0.035,
                 MAT_IRON, seg=10, tube=4)
    parts[prefix + "MooringRing"] = (ring, "ROOT")

    chain = Part()
    for i in range(3):
        y = 0.52 + i * 0.08
        wk.add_torus(chain, (0.0, y, 0.30), (1.0, 0.0, 0.0), 0.050, 0.016,
                     MAT_IRON, seg=8, tube=3)
    parts[prefix + "Chain"] = (chain, "ROOT")

    coil = Part()
    _rope_coil(coil, (-0.55, 0.25, 0.28), (0.0, 0.0, 1.0), 0.16, 3, 0.030,
               MAT_CANVAS_SHADE, spacing=0.055)
    wk.add_box(coil, (0.50, 0.34, 0.0), (0.76, 0.58, 0.60), MAT_WOOD_DARK)
    for z in (0.12, 0.46):
        wk.add_box(coil, (0.48, 0.32, z), (0.78, 0.60, z + 0.05), MAT_IRON)
    parts[prefix + "RopeCoil"] = (coil, "ROOT")

    return parts


BUILDERS = {
    "SN_Machinery_GearSet": _build_gearset,
    "SN_Machinery_Winch": _build_winch,
    "SN_Machinery_PowerUnit": _build_powerunit,
    "SN_Cargo_Crate": _build_crate,
    "SN_Cargo_CoalScuttle": _build_coal_scuttle,
    "SN_Cargo_Tank": _build_tank,
    "SN_Cargo_Pallet": _build_pallet,
    "SN_Dock_Structure": _build_dock_structure,
    "SN_Dock_Jetty": _build_jetty,
    "SN_Dock_Mooring": _build_mooring,
}


def build_geometry(asset):
    """纯 Python：返回 {对象名: (Part, 父级 key)}；不 import bpy。"""
    return BUILDERS[asset]()


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
    if "module" in spec:
        root_props["module_x"] = float(spec["module"][0])
        root_props["module_y"] = float(spec["module"][1])
    if "deck_height" in spec:
        root_props["deck_height"] = float(spec["deck_height"])
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
    print("KIT_BATCH2_REPORT %r" % {
        "assets": {asset: out[asset]["tris"] for asset in ASSETS},
        "total_tris": sum(v["tris"] for v in out.values()),
    })
    return out


if __name__ == "__main__":
    build_all_kits()
    report()
