# -*- coding: utf-8 -*-
# @static-doc
# 作用：模型素材库批次 3（P2：建筑 / 环境）的参数化生成器与 Blender 装配入口。
#
# 8 件模块化资产：SN_Arch_Warehouse / Workshop / Tavern / Factory，SN_Env_Reef /
# Wreck / Lighthouse / Buoy。沿用批次 1–2 的契约：每件资产 Mount 空节点 + 语义接口
# （Module_Next/Prev、Door_Front、Hoist、Drive_Shaft、Gantry、Top、Lamp…），Root
# extras 写 kit_family / part_role / datum / footprint / height / waterline。
#
# 工单：`tools/modeling/briefs/sn_kit_batch3.json`
# 约定：1 unit = 1 m；+X 前向、+Z 向上；建筑根在体量底面 z=0，环境件根在水线 z=0
# （礁石到 z=-3.0、残骸船底到 z=-1.6、浮标吃水裙到 z=-0.7），灯塔由礁石 Top 托起。
# 材质：共享贴图 `SN_Tex_*`（本批不新增贴图），见 `sn_kit_materials.py`。
#
# 用法：
# - Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
# - 纯 Python 干跑：`python tools/modeling/generators/dryrun_kit_batch3.py`
# - 导出 GLB：`python tools/modeling/generators/export_kit_batch3_glb.py`
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
    prism_xy,
    revolved,
    taper_cyl,
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
    MAT_STONE,
    MAT_WOOD,
    MAT_WOOD_DARK,
    MAT_WOOD_DECK,
    colors_for,
)

ASSETS = [
    "SN_Arch_Warehouse",
    "SN_Arch_Workshop",
    "SN_Arch_Tavern",
    "SN_Arch_Factory",
    "SN_Env_Reef",
    "SN_Env_Wreck",
    "SN_Env_Lighthouse",
    "SN_Env_Buoy",
]

WORKBENCH_POS = {
    "SN_Arch_Warehouse": (30.0, 600.0, 0.0),
    "SN_Arch_Workshop": (44.0, 600.0, 0.0),
    "SN_Arch_Tavern": (56.0, 600.0, 0.0),
    "SN_Arch_Factory": (70.0, 600.0, 0.0),
    "SN_Env_Reef": (30.0, 580.0, 0.0),
    "SN_Env_Wreck": (44.0, 580.0, 0.0),
    "SN_Env_Lighthouse": (58.0, 580.0, 0.0),
    "SN_Env_Buoy": (70.0, 576.0, 0.0),
}

SPECS = {
    "SN_Arch_Warehouse": {
        "collection": "SN_Arch_Warehouse_Prototype",
        "prefix": "SN_Arch_Warehouse_",
        "family": "architecture_kit",
        "role": "warehouse",
        "type": "modular warehouse with loading canopy",
        "tri_budget": 3400,
        "bbox": (10.95, 6.95, 6.35),
        "tol": 0.15,
        "zmin": 0.0,
        "module": (8.0, 6.0),
        "datum": "ground z=0; body footprint 8x6 centred on root; +X loading front",
        "required": ("Plinth", "Walls", "Roof", "DockDoor", "Canopy", "Windows"),
    },
    "SN_Arch_Workshop": {
        "collection": "SN_Arch_Workshop_Prototype",
        "prefix": "SN_Arch_Workshop_",
        "family": "architecture_kit",
        "role": "workshop",
        "type": "workshop with monitor roof and external drive wheel",
        "tri_budget": 2900,
        "bbox": (9.32, 6.63, 7.04),
        "tol": 0.15,
        "zmin": 0.0,
        "module": (8.0, 6.0),
        "datum": "ground z=0; body footprint 8x6; drive wheel on -Y wall",
        "required": ("Plinth", "Walls", "Roof", "Smokestack", "DoubleDoor",
                     "DriveWheel"),
    },
    "SN_Arch_Tavern": {
        "collection": "SN_Arch_Tavern_Prototype",
        "prefix": "SN_Arch_Tavern_",
        "family": "architecture_kit",
        "role": "tavern",
        "type": "two-storey tavern with porch, balcony and sign",
        "tri_budget": 3400,
        "bbox": (8.67, 6.96, 7.64),
        "tol": 0.15,
        "zmin": 0.0,
        "module": (6.0, 6.0),
        "datum": "ground z=0; body footprint 6x6; porch and steps extend +X",
        "required": ("Plinth", "GroundFloor", "UpperFloor", "Roof", "Porch",
                     "SignBracket"),
    },
    "SN_Arch_Factory": {
        "collection": "SN_Arch_Factory_Prototype",
        "prefix": "SN_Arch_Factory_",
        "family": "architecture_kit",
        "role": "factory",
        "type": "sawtooth-roof factory with gantry and twin chimneys",
        "tri_budget": 4800,
        "bbox": (14.74, 8.30, 9.64),
        "tol": 0.20,
        "zmin": 0.0,
        "module": (12.0, 8.0),
        "datum": "ground z=0; body footprint 12x8; gantry and platform extend +X",
        "required": ("Plinth", "Walls", "SawtoothRoof", "Chimneys",
                     "SlidingDoors", "GantryBeam"),
    },
    "SN_Env_Reef": {
        "collection": "SN_Env_Reef_Prototype",
        "prefix": "SN_Env_Reef_",
        "family": "environment_kit",
        "role": "reef",
        "type": "rock reef cluster with lighthouse pad",
        "tri_budget": 2400,
        "bbox": (7.13, 6.44, 5.52),
        "tol": 0.20,
        "zmin": -3.0,
        "waterline": 0.0,
        "datum": "waterline z=0; rocks to z=-3.0; Top pad at highest rock",
        "required": ("Rocks", "TideShelf", "Slab", "MooringRing"),
    },
    "SN_Env_Wreck": {
        "collection": "SN_Env_Wreck_Prototype",
        "prefix": "SN_Env_Wreck_",
        "family": "environment_kit",
        "role": "wreck",
        "type": "broken wooden hull wreck",
        "tri_budget": 2800,
        "bbox": (8.62, 3.96, 4.72),
        "tol": 0.20,
        "zmin": -1.6,
        "waterline": 0.0,
        "datum": "waterline z=0; keel to z=-1.6; hull rolled about X",
        "required": ("Hull", "Ribs", "Planking", "BrokenMast", "Ballast"),
    },
    "SN_Env_Lighthouse": {
        "collection": "SN_Env_Lighthouse_Prototype",
        "prefix": "SN_Env_Lighthouse_",
        "family": "environment_kit",
        "role": "lighthouse",
        "type": "stone lighthouse with gallery and lantern",
        "tri_budget": 2600,
        "bbox": (4.62, 4.60, 13.16),
        "tol": 0.20,
        "zmin": 0.0,
        "waterline": 0.0,
        "datum": "base slab z=0; tower axis Z; door on +X",
        "required": ("Base", "Tower", "Catwalk", "Lantern", "Dome"),
    },
    "SN_Env_Buoy": {
        "collection": "SN_Env_Buoy_Prototype",
        "prefix": "SN_Env_Buoy_",
        "family": "environment_kit",
        "role": "buoy",
        "type": "steam-era lighted navigational buoy",
        "tri_budget": 1000,
        "bbox": (1.88, 1.88, 3.84),
        "tol": 0.10,
        "zmin": -0.7,
        "waterline": 0.0,
        "datum": "waterline z=0; draft skirt to z=-0.7",
        "required": ("Hull", "Skirt", "Bands", "LampFrame", "BellRig",
                     "ChainLinks"),
    },
}

SOCKETS = {
    "SN_Arch_Warehouse": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("MODULE_NEXT", "Module_Next", "ROOT", (4.00, 0.0, 0.0)),
        ("MODULE_PREV", "Module_Prev", "ROOT", (-4.00, 0.0, 0.0)),
        ("DOOR_FRONT", "Door_Front", "ROOT", (4.00, -1.60, 0.0)),
        ("HOIST", "Hoist", "ROOT", (6.30, -1.45, 3.98)),
        ("SIGN", "Sign", "ROOT", (4.05, -1.60, 4.50)),
    ],
    "SN_Arch_Workshop": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("MODULE_NEXT", "Module_Next", "ROOT", (4.00, 0.0, 0.0)),
        ("MODULE_PREV", "Module_Prev", "ROOT", (-4.00, 0.0, 0.0)),
        ("DOOR_FRONT", "Door_Front", "ROOT", (4.00, 0.0, 0.0)),
        ("DRIVE_SHAFT", "Drive_Shaft", "ROOT", (-1.00, -3.08, 1.45)),
        ("CHIMNEY", "Chimney", "ROOT", (-2.80, -2.20, 7.00)),
    ],
    "SN_Arch_Tavern": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("MODULE_NEXT", "Module_Next", "ROOT", (3.00, 0.0, 0.0)),
        ("MODULE_PREV", "Module_Prev", "ROOT", (-3.00, 0.0, 0.0)),
        ("DOOR_FRONT", "Door_Front", "ROOT", (3.00, 0.0, 0.0)),
        ("SIGN", "Sign", "ROOT", (5.00, 1.80, 3.05)),
        ("CHIMNEY", "Chimney", "ROOT", (-2.40, -2.20, 7.60)),
    ],
    "SN_Arch_Factory": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("MODULE_NEXT", "Module_Next", "ROOT", (6.00, 0.0, 0.0)),
        ("MODULE_PREV", "Module_Prev", "ROOT", (-6.00, 0.0, 0.0)),
        ("DOOR_FRONT", "Door_Front", "ROOT", (6.00, 0.0, 0.0)),
        ("GANTRY", "Gantry", "ROOT", (8.35, 0.0, 7.05)),
        ("CHIMNEY", "Chimney", "ROOT", (-5.00, 2.80, 9.60)),
    ],
    "SN_Env_Reef": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("TOP", "Top", "ROOT", (0.60, -0.40, 2.48)),
        ("MOORING_RING", "Mooring_Ring", "ROOT", (1.80, 2.36, 0.92)),
    ],
    "SN_Env_Wreck": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("DECK", "Deck", "ROOT", (-2.00, -0.15, 0.60)),
        ("MAST", "Mast", "ROOT", (0.90, -0.13, 0.53)),
    ],
    "SN_Env_Lighthouse": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("DOOR", "Door", "ROOT", (1.50, 0.0, 0.90)),
        ("GALLERY", "Gallery", "ROOT", (1.60, 0.0, 9.80)),
        ("LAMP", "Lamp", "ROOT", (0.0, 0.0, 10.60)),
    ],
    "SN_Env_Buoy": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("LAMP", "Lamp", "ROOT", (0.0, 0.0, 2.65)),
        ("BELL", "Bell", "ROOT", (0.0, -0.45, 1.85)),
        ("CHAIN", "Chain", "ROOT", (0.55, 0.0, 0.35)),
    ],
}


def _sockets(asset):
    prefix = SPECS[asset]["prefix"]
    return [{"key": key, "name": prefix + name, "parent": parent,
             "location": loc} for key, name, parent, loc in SOCKETS[asset]]


# ---------------------------------------------------------------- 通用工具

def _rnd(seed):
    """确定性伪随机 [0,1)：干跑 / 两次构建得到同一几何。"""
    x = math.sin(seed * 12.9898 + 78.233) * 43758.5453
    return x - math.floor(x)


def _face_box(part, c, n, t, width, height, depth, mat, z_shift=0.0):
    """贴在墙面上的盒子：c = 墙面中心，n = 外法线，t = 沿墙面宽度方向。"""
    center = (c[0] + n[0] * depth * 0.5,
              c[1] + n[1] * depth * 0.5,
              c[2] + n[2] * depth * 0.5 + z_shift)
    part.add(frame_box(center, n, t, (0.0, 0.0, 1.0),
                       depth * 0.5, width * 0.5, height * 0.5), mat)


def _slab(part, a, b, width_axis, width, thickness, mat):
    """两点中心线 + 宽度轴 + 厚度 → 闭合板（坡屋面 / 侧壳 / 皮带）。"""
    d = vnorm(vsub(b, a))
    u = vnorm(width_axis)
    w = vnorm(vcross(u, d))
    center = vmul(vadd(a, b), 0.5)
    part.add(frame_box(center, u, d, w, width * 0.5,
                       vlen(vsub(a, b)) * 0.5, thickness * 0.5), mat)


def _tri_prism(part, tri, x0, x1, mat):
    """XZ 端面上的三角形沿 X 挤出（山墙 / 破口挡板）。tri = [(y, z), ...]。"""
    verts = [(x0, y, z) for y, z in tri] + [(x1, y, z) for y, z in tri]
    faces = [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)]
    part.add((verts, faces), mat)


def _window(part, c, n, t, w, h, frame=MAT_IRON, glass=MAT_GLASS_DARK,
            mullions=1, sill=True):
    _face_box(part, c, n, t, w - 0.12, h - 0.12, 0.035, glass, z_shift=0.02)
    for s in (-1.0, 1.0):
        _face_box(part, (c[0], c[1], c[2] + s * (h * 0.5 - 0.045)),
                  n, t, w, 0.09, 0.07, frame)
        _face_box(part, (c[0] + t[0] * s * (w * 0.5 - 0.045),
                         c[1] + t[1] * s * (w * 0.5 - 0.045), c[2]),
                  n, t, 0.09, h, 0.07, frame)
    for k in range(mullions):
        off = (k - (mullions - 1) * 0.5) * (w / (mullions + 1))
        _face_box(part, (c[0] + t[0] * off, c[1] + t[1] * off, c[2]),
                  n, t, 0.06, h - 0.12, 0.075, frame)
    if sill:
        _face_box(part, (c[0], c[1], c[2] - h * 0.5 - 0.05), n, t,
                  w + 0.18, 0.10, 0.16, frame)


def _door(part, c, n, t, w, h, panel, frame, brace=None, handle=True):
    _face_box(part, c, n, t, w - 0.10, h - 0.10, 0.09, panel)
    for s in (-1.0, 1.0):
        _face_box(part, (c[0], c[1], c[2] + s * (h * 0.5 - 0.05)),
                  n, t, w, 0.10, 0.10, frame)
        _face_box(part, (c[0] + t[0] * s * (w * 0.5 - 0.05),
                         c[1] + t[1] * s * (w * 0.5 - 0.05), c[2]),
                  n, t, 0.10, h, 0.10, frame)
    if brace is not None:
        d = n[0] * 0.10
        p0 = (c[0] - t[0] * w * 0.34 + n[0] * d,
              c[1] - t[1] * w * 0.34 + n[1] * d, c[2] - h * 0.34)
        p1 = (c[0] + t[0] * w * 0.34 + n[0] * d,
              c[1] + t[1] * w * 0.34 + n[1] * d, c[2] + h * 0.34)
        part.add(bar_between(p0, p1, 0.08), brace)
    if handle:
        hc = (c[0] + n[0] * 0.13 + t[0] * w * 0.30,
              c[1] + n[1] * 0.13 + t[1] * w * 0.30, c[2])
        wk.add_cyl(part, hc, (hc[0] + n[0] * 0.10, hc[1] + n[1] * 0.10,
                              hc[2]), 0.035, 0.035, MAT_BRASS, 6)


def _rivets(part, p0, p1, count, axis, mat=MAT_BRASS, r=0.035, h=0.05):
    wk.rivet_row(part, p0, p1, count, axis, r, h, mat)


def _chimney(part, cx, cy, z0, z1, half, body, band, cap):
    wk.add_box(part, (cx - half, cy - half, z0), (cx + half, cy + half, z1),
               body)
    for f in (0.35, 0.65, 0.9):
        z = z0 + (z1 - z0) * f
        wk.add_box(part, (cx - half - 0.05, cy - half - 0.05, z - 0.06),
                   (cx + half + 0.05, cy + half + 0.05, z + 0.06), band)
    wk.add_box(part, (cx - half - 0.10, cy - half - 0.10, z1 - 0.14),
               (cx + half + 0.10, cy + half + 0.10, z1), cap)
    wk.add_box(part, (cx - half * 0.55, cy - half * 0.55, z1 - 0.02),
               (cx + half * 0.55, cy + half * 0.55, z1 + 0.04), MAT_METAL)


def _gable_roof(part, x0, x1, y_half, z_eave, z_ridge, thick,
                roof_mat, trim_mat, gable_mat, gx0, gx1):
    xc = (x0 + x1) * 0.5
    for sign in (-1.0, 1.0):
        _slab(part, (xc, sign * y_half, z_eave), (xc, 0.0, z_ridge),
              (1.0, 0.0, 0.0), x1 - x0, thick, roof_mat)
        for f in (0.3, 0.55, 0.8):
            y = sign * y_half * (1.0 - f)
            z = z_eave + (z_ridge - z_eave) * f
            wk.add_box(part, (x0 + 0.04, y - 0.045, z + 0.01),
                       (x1 - 0.04, y + 0.045, z + 0.055), trim_mat)
    for g0, g1 in ((gx0, gx0 + 0.14), (gx1 - 0.14, gx1)):
        _tri_prism(part, [(-y_half, z_eave), (y_half, z_eave),
                          (0.0, z_ridge)], g0, g1, gable_mat)
    wk.add_box(part, (x0, -0.14, z_ridge - 0.02),
               (x1, 0.14, z_ridge + 0.07), trim_mat)


def _rock(part, cx, cy, z0, height, radius, seed, mat, wet_mat=None,
          sides=7, levels=((0.0, 1.0), (0.28, 0.96), (0.58, 0.78),
                           (0.82, 0.48), (1.0, 0.14))):
    """棱角礁石：分层扰动环 + 上下封盖；水线以下面用 wet_mat 上潮痕。

    顶点表只加一次，面按材质分组追加到 Part.faces，保证整块礁石是单一闭合
    壳体（干跑的四项网格健康检查按整对象统计）。
    """
    rings = []
    for li, (lz, rf) in enumerate(levels):
        ring = []
        for i in range(sides):
            a = 2.0 * math.pi * i / sides + 0.22 * (li % 2)
            jr = 0.80 + 0.34 * _rnd(seed + i * 1.7 + li * 9.3)
            z = z0 + height * lz + 0.05 * height * _rnd(seed + i * 3.1 + li * 2.2)
            ring.append((cx + radius * rf * jr * math.cos(a),
                         cy + radius * rf * jr * math.sin(a), z))
        rings.append(ring)
    verts = []
    idx = []
    off = len(part.verts)
    for ring in rings:
        idx.append(list(range(off + len(verts), off + len(verts) + sides)))
        verts.extend(ring)
    top = off + len(verts)
    verts.append((cx, cy, max(p[2] for p in rings[-1]) + 0.06))
    bottom = off + len(verts)
    verts.append((cx, cy, z0))
    part.verts.extend(verts)
    for i in range(sides):
        j = (i + 1) % sides
        part.faces.append(((bottom, idx[0][j], idx[0][i]), mat))
    for li in range(len(rings) - 1):
        a, b = idx[li], idx[li + 1]
        use = wet_mat if (wet_mat and rings[li][0][2] < 0.03) else mat
        for i in range(sides):
            j = (i + 1) % sides
            part.faces.append(((a[i], a[j], b[j], b[i]), use))
    last = idx[-1]
    for i in range(sides):
        j = (i + 1) % sides
        part.faces.append(((last[i], last[j], top), mat))


# ---------------------------------------------------------------- 1. 仓库

def _build_warehouse():
    prefix = "SN_Arch_Warehouse_"
    parts = {}

    plinth = Part()
    wk.add_box(plinth, (-4.05, -3.05, 0.0), (4.05, 3.05, 0.36), MAT_STONE)
    wk.add_box(plinth, (-4.08, -3.08, 0.32), (4.08, 3.08, 0.44), MAT_WOOD_DARK)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            wk.add_box(plinth, (sx * 3.90 - 0.18, sy * 2.90 - 0.18, 0.0),
                       (sx * 3.90 + 0.18, sy * 2.90 + 0.18, 0.52), MAT_STONE)
    wk.add_box(plinth, (4.08, -2.60, 0.0), (4.55, -0.60, 0.18), MAT_STONE)
    parts[prefix + "Plinth"] = (plinth, "ROOT")

    walls = Part()
    wk.add_box(walls, (-4.0, -3.0, 0.44), (4.0, 3.0, 4.85), MAT_IRON)
    wk.add_box(walls, (-4.04, -3.04, 0.44), (4.04, 3.04, 1.02), MAT_IRON_RED)
    wk.add_box(walls, (-4.10, -3.10, 4.68), (4.10, 3.10, 4.90), MAT_IRON)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            wk.add_box(walls, (sx * 4.0 - 0.13, sy * 3.0 - 0.13, 0.44),
                       (sx * 4.0 + 0.13, sy * 3.0 + 0.13, 4.68), MAT_METAL)
    for x in (-2.0, 0.0, 2.0):
        for sy in (-1.0, 1.0):
            y0, y1 = (3.0, 3.12) if sy > 0 else (-3.12, -3.0)
            wk.add_box(walls, (x - 0.09, y0, 0.44), (x + 0.09, y1, 4.68),
                       MAT_IRON)
            _rivets(walls, (x, y1, 0.85), (x, y1, 4.35), 5, (0.0, sy, 0.0))
    for y in (-2.0, 0.0, 2.0):
        for sx in (-1.0, 1.0):
            x0, x1 = (4.0, 4.12) if sx > 0 else (-4.12, -4.0)
            wk.add_box(walls, (x0, y - 0.09, 0.44), (x1, y + 0.09, 4.68),
                       MAT_IRON)
    parts[prefix + "Walls"] = (walls, "ROOT")

    windows = Part()
    for sy in (-1.0, 1.0):
        n = (0.0, sy, 0.0)
        for x in (-2.6, -0.9, 0.9, 2.6):
            _window(windows, (x, sy * 3.0, 3.55), n, (1.0, 0.0, 0.0),
                    1.10, 1.20, frame=MAT_IRON)
    _window(windows, (4.0, 2.05, 3.55), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0),
            1.05, 1.20)
    for y in (-1.55, 1.55):
        _window(windows, (-4.0, y, 3.55), (-1.0, 0.0, 0.0), (0.0, 1.0, 0.0),
                1.05, 1.20)
    parts[prefix + "Windows"] = (windows, "ROOT")

    dock = Part()
    n, t = (1.0, 0.0, 0.0), (0.0, 1.0, 0.0)
    for s in (-1.0, 1.0):
        _face_box(dock, (4.0, -1.60 + s * 1.10, 2.32), n, t,
                  0.20, 3.86, 0.12, MAT_IRON)
    _face_box(dock, (4.0, -1.60, 4.30), n, t, 2.42, 0.22, 0.12, MAT_IRON)
    _face_box(dock, (4.0, -1.60, 2.32), n, t, 2.00, 3.76, 0.08, MAT_IRON_RED)
    for yy in (-2.36, -1.60, -0.84):
        _face_box(dock, (4.09, yy, 2.32), n, t, 0.07, 3.60, 0.05, MAT_IRON)
    dock.add(bar_between((4.15, -2.45, 0.70), (4.15, -0.75, 3.95), 0.09),
             MAT_WOOD_DARK)
    dock.add(bar_between((4.15, -0.75, 0.70), (4.15, -2.45, 3.95), 0.09),
             MAT_WOOD_DARK)
    wk.add_box(dock, (4.0, -2.95, 4.34), (4.22, -0.25, 4.46), MAT_IRON)
    for yy in (-2.55, -0.65):
        wk.add_cyl(dock, (4.11, yy, 4.28), (4.11, yy, 4.42),
                   0.07, 0.07, MAT_BRASS, 8)
    _face_box(dock, (4.0, -1.60, 4.50), n, t, 1.50, 0.26, 0.06, MAT_WOOD_DARK)
    _face_box(dock, (4.0, -1.60, 4.50), n, t, 1.32, 0.12, 0.075, MAT_BRASS)
    _door(dock, (4.0, 1.90, 1.54), n, t, 1.00, 2.20, MAT_WOOD_DARK, MAT_IRON,
          brace=MAT_IRON_RED)
    for yy in (1.90,):
        wk.add_box(dock, (4.0, yy - 0.55, 0.36), (4.42, yy + 0.55, 0.50),
                   MAT_STONE)
    parts[prefix + "DockDoor"] = (dock, "ROOT")

    canopy = Part()
    for yy in (-2.72, -0.28):
        wk.add_box(canopy, (6.18, yy - 0.08, 0.0), (6.34, yy + 0.08, 3.40),
                   MAT_WOOD_DARK)
        wk.add_box(canopy, (6.10, yy - 0.15, 0.0), (6.42, yy + 0.15, 0.16),
                   MAT_STONE)
        canopy.add(bar_between((6.26, yy, 3.32), (4.05, yy, 4.40), 0.08),
                   MAT_IRON)
    _slab(canopy, (4.02, -1.50, 4.45), (6.48, -1.50, 3.52),
          (0.0, 1.0, 0.0), 2.90, 0.10, MAT_IRON_RED)
    for f in (0.2, 0.5, 0.8):
        x = 4.02 + (6.48 - 4.02) * f
        z = 4.45 + (3.52 - 4.45) * f
        wk.add_box(canopy, (x - 0.05, -2.92, z - 0.05),
                   (x + 0.05, -0.08, z + 0.02), MAT_IRON)
    wk.add_box(canopy, (4.0, -1.55, 4.02), (6.50, -1.35, 4.16), MAT_WOOD_DARK)
    wk.add_box(canopy, (4.0, -1.55, 3.86), (4.22, -1.35, 4.06), MAT_IRON)
    wk.add_torus(canopy, (6.30, -1.45, 3.98), (0.0, 1.0, 0.0),
                 0.13, 0.035, MAT_BRASS, seg=10, tube=3)
    wk.add_cyl(canopy, (6.30, -1.62, 3.98), (6.30, -1.28, 3.98),
               0.035, 0.035, MAT_METAL, 6)
    wk.add_cyl(canopy, (6.30, -1.45, 3.85), (6.30, -1.45, 2.15),
               0.022, 0.022, MAT_CANVAS_SHADE, 4)
    wk.add_cyl(canopy, (6.30, -1.45, 2.05), (6.30, -1.45, 1.86),
               0.05, 0.02, MAT_IRON, 6)
    wk.add_torus(canopy, (6.30, -1.45, 1.78), (1.0, 0.0, 0.0),
                 0.10, 0.025, MAT_IRON, seg=8, tube=3)
    parts[prefix + "Canopy"] = (canopy, "ROOT")

    roof = Part()
    _gable_roof(roof, -4.45, 4.45, 3.45, 4.85, 6.28, 0.14,
                MAT_IRON_RED, MAT_IRON, MAT_IRON, -4.0, 4.0)
    for x, sy in ((-2.4, 1.0), (2.4, -1.0)):
        y = sy * 1.30
        z = 4.85 + (6.28 - 4.85) * (1.0 - abs(y) / 3.45)
        wk.add_box(roof, (x - 0.30, y - 0.30, z - 0.15),
                   (x + 0.30, y + 0.30, z + 0.30), MAT_IRON)
        wk.add_cyl(roof, (x, y, z + 0.28), (x, y, z + 0.48),
                   0.26, 0.30, MAT_METAL, 8)
        wk.add_cyl(roof, (x, y, z + 0.46), (x, y, z + 0.56),
                   0.30, 0.16, MAT_IRON, 8)
    parts[prefix + "Roof"] = (roof, "ROOT")

    return parts


# ---------------------------------------------------------------- 2. 工坊

def _build_workshop():
    prefix = "SN_Arch_Workshop_"
    parts = {}

    plinth = Part()
    wk.add_box(plinth, (-4.05, -3.05, 0.0), (4.05, 3.05, 0.32), MAT_STONE)
    wk.add_box(plinth, (-4.08, -3.08, 0.28), (4.08, 3.08, 0.40), MAT_WOOD_DARK)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            wk.add_box(plinth, (sx * 3.90 - 0.17, sy * 2.90 - 0.17, 0.0),
                       (sx * 3.90 + 0.17, sy * 2.90 + 0.17, 0.48), MAT_STONE)
    wk.add_box(plinth, (4.08, -1.30, 0.0), (4.50, 1.30, 0.16), MAT_STONE)
    parts[prefix + "Plinth"] = (plinth, "ROOT")

    walls = Part()
    wk.add_box(walls, (-4.0, -3.0, 0.40), (4.0, 3.0, 4.55), MAT_WOOD_DARK)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            wk.add_box(walls, (sx * 4.0 - 0.14, sy * 3.0 - 0.14, 0.40),
                       (sx * 4.0 + 0.14, sy * 3.0 + 0.14, 4.58), MAT_IRON)
    for z in (1.45, 2.75, 4.05):
        wk.add_box(walls, (-4.03, -3.05, z - 0.05), (4.03, -3.0, z + 0.05),
                   MAT_IRON)
        wk.add_box(walls, (-4.03, 3.0, z - 0.05), (4.03, 3.05, z + 0.05),
                   MAT_IRON)
        wk.add_box(walls, (4.0, -3.03, z - 0.05), (4.05, 3.03, z + 0.05),
                   MAT_IRON)
    for x in (-2.5, 0.0, 2.5):
        for sy in (-1.0, 1.0):
            wk.add_box(walls, (x - 0.08, sy * 3.0 - 0.04, 0.40),
                       (x + 0.08, sy * 3.0 + 0.06, 4.55), MAT_WOOD)
    _rivets(walls, (-4.02, 2.40, 1.0), (-4.02, 2.40, 4.2), 4,
            (-1.0, 0.0, 0.0))
    parts[prefix + "Walls"] = (walls, "ROOT")

    roof = Part()
    _gable_roof(roof, -4.35, 4.35, 3.30, 4.55, 5.25, 0.13,
                MAT_IRON_RED, MAT_IRON, MAT_WOOD_DARK, -4.0, 4.0)
    # 采光顶（monitor roof）
    wk.add_box(roof, (-2.60, -1.05, 5.20), (2.60, 1.05, 5.95), MAT_WOOD_DARK)
    for sy in (-1.0, 1.0):
        for x in (-1.8, 0.0, 1.8):
            _window(roof, (x, sy * 1.05, 5.60), (0.0, sy, 0.0),
                    (1.0, 0.0, 0.0), 1.30, 0.52, frame=MAT_IRON,
                    mullions=2, sill=False)
    _gable_roof(roof, -2.75, 2.75, 1.15, 5.95, 6.28, 0.11,
                MAT_IRON_RED, MAT_IRON, MAT_WOOD_DARK, -2.60, 2.60)
    for x in (-3.4, 3.4):
        wk.add_box(roof, (x - 0.06, -0.45, 5.24), (x + 0.06, 0.45, 6.20),
                   MAT_IRON)
    parts[prefix + "Roof"] = (roof, "ROOT")

    chimney = Part()
    _chimney(chimney, -2.80, -2.20, 4.40, 7.00, 0.44,
             MAT_IRON_RED, MAT_STONE, MAT_IRON)
    parts[prefix + "Smokestack"] = (chimney, "ROOT")

    door = Part()
    n, t = (1.0, 0.0, 0.0), (0.0, 1.0, 0.0)
    for s in (-1.0, 1.0):
        _face_box(door, (4.0, s * 1.38, 2.05), n, t, 0.20, 3.20, 0.12,
                  MAT_IRON)
    _face_box(door, (4.0, 0.0, 3.55), n, t, 3.00, 0.20, 0.12, MAT_IRON)
    for s in (-1.0, 1.0):
        _face_box(door, (4.0, s * 0.66, 1.90), n, t, 1.26, 3.00, 0.09,
                  MAT_WOOD)
        _face_box(door, (4.10, s * 0.66, 2.60), n, t, 1.18, 0.10, 0.05,
                  MAT_IRON)
        _face_box(door, (4.10, s * 0.66, 1.20), n, t, 1.18, 0.10, 0.05,
                  MAT_IRON)
        door.add(bar_between((4.15, s * 0.66 - 0.50, 0.55),
                             (4.15, s * 0.66 + 0.50, 3.25), 0.07), MAT_IRON)
        wk.add_cyl(door, (4.12, s * 0.10, 1.85), (4.22, s * 0.10, 1.85),
                   0.05, 0.05, MAT_BRASS, 6)
    _slab(door, (4.0, 0.0, 3.92), (4.95, 0.0, 3.44),
          (0.0, 1.0, 0.0), 3.50, 0.09, MAT_IRON_RED)
    for s in (-1.0, 1.0):
        door.add(bar_between((4.05, s * 1.50, 3.75), (4.88, s * 1.50, 3.48),
                             0.07), MAT_IRON)
        wk.add_box(door, (4.82, s * 1.50 - 0.06, 0.0), (4.94, s * 1.50 + 0.06,
                                                        3.42), MAT_WOOD_DARK)
    for s in (-1.0, 1.0):
        wx, wy, wz = 4.06, s * 1.95, 2.95
        wk.add_box(door, (wx, wy - 0.05, wz), (wx + 0.22, wy + 0.05, wz + 0.05),
                   MAT_IRON)
        wk.add_box(door, (wx + 0.18, wy - 0.12, wz - 0.22),
                   (wx + 0.40, wy + 0.12, wz + 0.26), MAT_GLASS_DARK)
        wk.add_box(door, (wx + 0.16, wy - 0.15, wz + 0.24),
                   (wx + 0.42, wy + 0.15, wz + 0.32), MAT_BRASS)
    _face_box(door, (4.0, 0.0, 4.05), n, t, 1.60, 0.34, 0.06, MAT_WOOD_DARK)
    _face_box(door, (4.0, 0.0, 4.05), n, t, 1.44, 0.20, 0.075, MAT_BRASS)
    parts[prefix + "DoubleDoor"] = (door, "ROOT")

    wheel = Part()
    cy = 1.45
    wy = -3.08
    wk.add_torus(wheel, (-1.0, wy, cy), (0.0, 1.0, 0.0), 1.00, 0.085,
                 MAT_IRON_RED, seg=14, tube=4)
    wk.add_torus(wheel, (-1.0, wy, cy), (0.0, 1.0, 0.0), 0.24, 0.07,
                 MAT_BRASS, seg=10, tube=3)
    for i in range(8):
        a = 2.0 * math.pi * i / 8.0
        wheel.add(bar_between((-1.0, wy, cy),
                              (-1.0 + 0.92 * math.cos(a), wy,
                               cy + 0.92 * math.sin(a)), 0.075), MAT_IRON)
    wk.add_cyl(wheel, (-1.0, wy - 0.20, cy), (-1.0, wy + 0.16, cy),
               0.14, 0.14, MAT_METAL, 8)
    wk.add_box(wheel, (-1.35, -3.02, 1.20), (-0.65, -2.94, 1.70), MAT_IRON)
    wk.add_box(wheel, (-1.20, -3.30, 0.55), (-0.80, -3.02, 0.75), MAT_IRON)
    wk.add_cyl(wheel, (-1.0, -3.06, 4.15), (-1.0, -2.98, 4.15),
               0.24, 0.24, MAT_METAL, 10)
    wk.add_box(wheel, (-1.30, -3.06, 4.02), (-0.70, -2.98, 4.28), MAT_IRON)
    p0 = (-2.02, wy, 1.45)
    p1 = (-1.20, wy, 3.96)
    p2 = (0.02, wy, 1.45)
    p3 = (-0.80, wy, 3.96)
    wheel.add(bar_between(p0, p1, 0.05), MAT_CANVAS_SHADE)
    wheel.add(bar_between(p2, p3, 0.05), MAT_CANVAS_SHADE)
    wheel.add(bar_between((-2.02, wy, 1.45), (-2.02, wy, 1.60), 0.09),
              MAT_IRON)
    parts[prefix + "DriveWheel"] = (wheel, "ROOT")

    return parts


# ---------------------------------------------------------------- 3. 酒馆

def _build_tavern():
    prefix = "SN_Arch_Tavern_"
    parts = {}

    plinth = Part()
    wk.add_box(plinth, (-3.05, -3.05, 0.0), (3.05, 3.05, 0.35), MAT_STONE)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            wk.add_box(plinth, (sx * 2.90 - 0.16, sy * 2.90 - 0.16, 0.0),
                       (sx * 2.90 + 0.16, sy * 2.90 + 0.16, 0.50), MAT_STONE)
    for i, (x0, x1, h) in enumerate(((3.05, 3.35, 0.10), (3.35, 3.62, 0.06))):
        wk.add_box(plinth, (x0, -1.20, 0.0), (x1, 1.20, h), MAT_STONE)
    parts[prefix + "Plinth"] = (plinth, "ROOT")

    ground = Part()
    wk.add_box(ground, (-3.0, -3.0, 0.35), (3.0, 3.0, 2.95), MAT_STONE)
    for y in (-2.0, 0.0, 2.0):
        wk.add_box(ground, (2.97, y - 0.30, 0.35), (3.02, y + 0.30, 2.90),
                   MAT_STONE)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            wk.add_box(ground, (sx * 2.96 - 0.13, sy * 2.96 - 0.13, 0.35),
                       (sx * 2.96 + 0.13, sy * 2.96 + 0.13, 2.90), MAT_STONE)
    n, t = (1.0, 0.0, 0.0), (0.0, 1.0, 0.0)
    _door(ground, (3.0, 0.0, 1.45), n, t, 1.30, 2.20, MAT_WOOD_DARK, MAT_WOOD,
          brace=MAT_IRON_RED)
    for yy in (-1.95, 1.95):
        _window(ground, (3.0, yy, 1.70), n, t, 1.10, 1.40,
                frame=MAT_WOOD_DARK, mullions=2)
    for sy in (-1.0, 1.0):
        for x in (-1.6, 1.6):
            _window(ground, (x, sy * 3.0, 1.70), (0.0, sy, 0.0),
                    (1.0, 0.0, 0.0), 1.10, 1.40, frame=MAT_WOOD_DARK,
                    mullions=2)
    for y in (-1.5, 1.5):
        _window(ground, (-3.0, y, 1.70), (-1.0, 0.0, 0.0), (0.0, 1.0, 0.0),
                1.10, 1.40, frame=MAT_WOOD_DARK, mullions=2)
    parts[prefix + "GroundFloor"] = (ground, "ROOT")

    upper = Part()
    wk.add_box(upper, (-3.25, -3.25, 2.90), (3.25, 3.25, 5.15), MAT_WOOD_DARK)
    wk.add_box(upper, (-3.30, -3.30, 5.05), (3.30, 3.30, 5.22), MAT_WOOD)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            wk.add_box(upper, (sx * 3.22 - 0.12, sy * 3.22 - 0.12, 2.90),
                       (sx * 3.22 + 0.12, sy * 3.22 + 0.12, 5.20), MAT_WOOD)
    for x in (-2.0, -0.7, 0.7, 2.0):
        for sy in (-1.0, 1.0):
            wk.add_box(upper, (x - 0.07, sy * 3.25 - 0.05, 2.96),
                       (x + 0.07, sy * 3.25 + 0.06, 5.10), MAT_WOOD)
    for sx in (-1.0, 1.0):
        for y in (-2.0, 0.0, 2.0):
            wk.add_box(upper, (sx * 3.25 - 0.05, y - 0.07, 2.96),
                       (sx * 3.25 + 0.06, y + 0.07, 5.10), MAT_WOOD)
    for yy in (-1.55, 1.75):
        _window(upper, (3.25, yy, 4.10), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0),
                1.00, 1.30, frame=MAT_WOOD_DARK, mullions=2)
    _door(upper, (3.25, -0.55, 4.52), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0),
          0.95, 1.85, MAT_WOOD, MAT_WOOD_DARK, brace=MAT_IRON_RED)
    for sy in (-1.0, 1.0):
        for x in (-1.8, 1.8):
            _window(upper, (x, sy * 3.25, 4.05), (0.0, sy, 0.0),
                    (1.0, 0.0, 0.0), 0.95, 1.20, frame=MAT_WOOD_DARK)
    for y in (-1.5, 1.5):
        _window(upper, (-3.25, y, 4.05), (-1.0, 0.0, 0.0), (0.0, 1.0, 0.0),
                0.95, 1.20, frame=MAT_WOOD_DARK)
    parts[prefix + "UpperFloor"] = (upper, "ROOT")

    roof = Part()
    _gable_roof(roof, -3.45, 3.45, 3.45, 5.15, 6.85, 0.14,
                MAT_WOOD_DARK, MAT_WOOD, MAT_WOOD_DARK, -3.25, 3.25)
    _window(roof, (3.25, 0.0, 5.95), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0),
            0.85, 0.95, frame=MAT_WOOD_DARK)
    parts[prefix + "Roof"] = (roof, "ROOT")

    chimney = Part()
    _chimney(chimney, -2.40, -2.20, 4.60, 7.60, 0.40,
             MAT_STONE, MAT_IRON, MAT_IRON)
    parts[prefix + "Smokestack"] = (chimney, "ROOT")

    porch = Part()
    for yy in (-2.35, 2.35):
        wk.add_box(porch, (4.65, yy - 0.09, 0.0), (4.83, yy + 0.09, 3.55),
                   MAT_WOOD_DARK)
        wk.add_box(porch, (4.58, yy - 0.14, 0.0), (4.90, yy + 0.14, 0.22),
                   MAT_STONE)
        porch.add(bar_between((4.74, yy, 3.45), (3.30, yy, 3.60), 0.08),
                  MAT_WOOD_DARK)
    wk.add_box(porch, (3.05, -2.60, 3.42), (4.90, 2.60, 3.58), MAT_WOOD_DECK)
    wk.add_box(porch, (3.05, -2.60, 0.0), (4.90, 2.60, 0.22), MAT_WOOD_DECK)
    for yy in (-2.60, 2.60):
        wk.railing(porch, [(3.10, yy, 3.58), (4.86, yy, 3.58)], 1.05,
                   MAT_WOOD_DARK, post_step=0.9)
    wk.railing(porch, [(4.86, -2.58, 3.58), (4.86, 2.58, 3.58)], 1.05,
               MAT_WOOD_DARK, post_step=0.9)
    for x, z in ((3.05, 3.58), (4.86, 3.58)):
        wk.add_box(porch, (x - 0.06, -2.62, z - 0.12),
                   (x + 0.06, 2.62, z - 0.02), MAT_WOOD_DARK)
    parts[prefix + "Porch"] = (porch, "ROOT")

    sign = Part()
    bx, by, bz = 4.90, 1.90, 3.45
    wk.add_box(sign, (bx - 0.06, by - 0.06, bz), (bx + 0.06, by + 0.06,
                                                  bz + 0.10), MAT_IRON)
    sign.add(bar_between((bx, by, bz + 0.08), (5.16, by, bz + 0.08), 0.06),
              MAT_IRON)
    for dx in (-0.14, 0.14):
        wk.add_cyl(sign, (5.06 + dx, by, bz + 0.04),
                   (5.06 + dx, by, bz - 0.52), 0.018, 0.018,
                   MAT_METAL, 4)
    wk.add_box(sign, (4.72, by - 0.42, 1.92), (5.16, by + 0.42, 2.98),
               MAT_WOOD_DARK)
    wk.add_box(sign, (4.70, by - 0.46, 2.90), (5.18, by + 0.46, 2.98),
               MAT_BRASS)
    wk.add_box(sign, (4.70, by - 0.46, 1.92), (5.18, by + 0.46, 2.00),
               MAT_BRASS)
    wk.add_box(sign, (5.14, by - 0.20, 2.30), (5.18, by + 0.20, 2.60),
               MAT_BRASS)
    parts[prefix + "SignBracket"] = (sign, "ROOT")

    return parts


# ---------------------------------------------------------------- 4. 厂房

def _build_factory():
    prefix = "SN_Arch_Factory_"
    parts = {}

    plinth = Part()
    wk.add_box(plinth, (-6.05, -4.05, 0.0), (6.05, 4.05, 0.45), MAT_STONE)
    wk.add_box(plinth, (-6.08, -4.08, 0.40), (6.08, 4.08, 0.50), MAT_IRON)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            wk.add_box(plinth, (sx * 5.90 - 0.20, sy * 3.90 - 0.20, 0.0),
                       (sx * 5.90 + 0.20, sy * 3.90 + 0.20, 0.60), MAT_STONE)
    parts[prefix + "Plinth"] = (plinth, "ROOT")

    walls = Part()
    wk.add_box(walls, (-6.0, -4.0, 0.50), (6.0, 4.0, 6.60), MAT_IRON)
    wk.add_box(walls, (-6.04, -4.04, 0.50), (6.04, 4.04, 1.45), MAT_IRON_RED)
    wk.add_box(walls, (-6.10, -4.10, 6.45), (6.10, 4.10, 6.66), MAT_IRON)
    for x in (-4.2, -2.1, 0.0, 2.1, 4.2):
        for sy in (-1.0, 1.0):
            y0, y1 = (4.0, 4.13) if sy > 0 else (-4.13, -4.0)
            wk.add_box(walls, (x - 0.10, y0, 0.50), (x + 0.10, y1, 6.45),
                       MAT_METAL)
            _rivets(walls, (x, y1, 1.0), (x, y1, 6.0), 6, (0.0, sy, 0.0))
    for y in (-2.6, 0.0, 2.6):
        wk.add_box(walls, (5.96, y - 0.10, 0.50), (6.09, y + 0.10, 6.45),
                   MAT_METAL)
    parts[prefix + "Walls"] = (walls, "ROOT")

    roof = Part()
    teeth = 4
    x0, x1 = -6.0, 6.0
    step = (x1 - x0) / teeth
    z_eave, z_high = 6.60, 8.30
    for i in range(teeth):
        xa = x0 + i * step
        xb = xa + step
        # 北向采光玻璃（竖面）
        wk.add_box(roof, (xa + 0.02, -4.0, z_eave + 0.05),
                   (xa + 0.10, 4.0, z_high - 0.05), MAT_GLASS_DARK)
        for y in (-3.0, -1.0, 1.0, 3.0):
            wk.add_box(roof, (xa - 0.02, y - 0.05, z_eave),
                       (xa + 0.14, y + 0.05, z_high), MAT_IRON)
        # 坡屋面（沿 X 从高到低）
        _slab(roof, (xa, 0.0, z_high), (xb, 0.0, z_eave),
              (0.0, 1.0, 0.0), 8.0, 0.12, MAT_IRON_RED)
        wk.add_box(roof, (xa - 0.05, -4.0, z_high - 0.05),
                   (xa + 0.05, 4.0, z_high + 0.10), MAT_IRON)
    for y in (-3.0, -1.5, 0.0, 1.5, 3.0):
        wk.add_box(roof, (-6.0, y - 0.05, 8.20), (6.0, y + 0.05, 8.36),
                   MAT_IRON)
    parts[prefix + "SawtoothRoof"] = (roof, "ROOT")

    chimneys = Part()
    _chimney(chimneys, -5.00, -3.00, 6.40, 9.60, 0.52,
             MAT_IRON_RED, MAT_IRON, MAT_STONE)
    _chimney(chimneys, -5.00, 2.80, 6.40, 9.40, 0.44,
             MAT_IRON_RED, MAT_IRON, MAT_STONE)
    for i in range(3):
        x = -2.0 + i * 2.0
        wk.add_box(chimneys, (x - 0.24, -0.60, 8.10), (x + 0.24, -0.10, 8.60),
                   MAT_METAL)
        wk.add_cyl(chimneys, (x, -0.35, 8.52), (x, -0.35, 8.78),
                   0.22, 0.12, MAT_IRON, 8)
    parts[prefix + "Chimneys"] = (chimneys, "ROOT")

    doors = Part()
    n, t = (1.0, 0.0, 0.0), (0.0, 1.0, 0.0)
    for yc in (-2.40, 2.00):
        for s in (-1.0, 1.0):
            _face_box(doors, (6.0, yc + s * 1.62, 2.90), n, t,
                      0.22, 4.80, 0.14, MAT_IRON)
        _face_box(doors, (6.0, yc, 5.42), n, t, 3.46, 0.24, 0.14, MAT_IRON)
        _face_box(doors, (6.0, yc, 2.90), n, t, 3.10, 4.60, 0.10,
                  MAT_IRON_RED)
        for s in (-1.0, 1.0):
            _face_box(doors, (6.10, yc + s * 0.80, 2.90), n, t,
                      0.09, 4.40, 0.06, MAT_IRON)
        doors.add(bar_between((6.16, yc - 1.45, 0.80),
                              (6.16, yc + 1.45, 4.95), 0.09), MAT_IRON)
        doors.add(bar_between((6.16, yc + 1.45, 0.80),
                              (6.16, yc - 1.45, 4.95), 0.09), MAT_IRON)
        wk.add_box(doors, (6.0, yc - 1.75, 5.56), (6.24, yc + 1.75, 5.70),
                   MAT_IRON)
        for yy in (yc - 1.35, yc + 1.35):
            wk.add_cyl(doors, (6.12, yy, 5.44), (6.12, yy, 5.58),
                       0.08, 0.08, MAT_BRASS, 8)
        _face_box(doors, (6.0, yc, 5.92), n, t, 1.90, 0.30, 0.07,
                  MAT_WOOD_DARK)
        _face_box(doors, (6.0, yc, 5.92), n, t, 1.70, 0.16, 0.085,
                  MAT_BRASS)
    _door(doors, (6.0, 0.0, 1.55), n, t, 1.10, 2.30, MAT_IRON,
          MAT_IRON_RED, brace=MAT_IRON)
    parts[prefix + "SlidingDoors"] = (doors, "ROOT")

    gantry = Part()
    for sy in (-1.0, 1.0):
        y = sy * 2.80
        wk.add_box(gantry, (8.22, y - 0.14, 0.0), (8.50, y + 0.14, 7.15),
                   MAT_IRON)
        wk.add_box(gantry, (8.08, y - 0.40, 0.0), (8.64, y + 0.40, 0.18),
                   MAT_IRON)
        for z in (2.0, 4.5):
            gantry.add(bar_between((6.10, y, z + 1.20), (8.36, y, z), 0.09),
                       MAT_IRON)
        wk.add_bolt(gantry, (8.42, y, 0.10), 0.09, 0.10, MAT_BRASS)
    wk.add_box(gantry, (8.10, -3.10, 7.02), (8.62, 3.10, 7.36), MAT_IRON)
    wk.add_box(gantry, (6.02, -0.16, 7.06), (8.20, 0.16, 7.34), MAT_IRON)
    wk.add_box(gantry, (8.18, -3.30, 7.02), (8.54, 3.30, 7.20),
               MAT_IRON_RED)
    for sy in (-1.0, 1.0):
        wk.add_box(gantry, (8.16, sy * 3.30, 7.00), (8.56, sy * 3.38, 7.70),
                   MAT_IRON_RED)
    wk.add_box(gantry, (8.16, -0.34, 6.70), (8.56, 0.34, 7.02),
               MAT_IRON_RED)
    for sy in (-1.0, 1.0):
        wk.add_cyl(gantry, (8.24, sy * 0.22, 6.86), (8.48, sy * 0.22, 6.86),
                   0.10, 0.10, MAT_METAL, 8)
    wk.add_cyl(gantry, (8.36, 0.0, 6.70), (8.36, 0.0, 3.30),
               0.03, 0.03, MAT_METAL, 4)
    wk.add_cyl(gantry, (8.36, 0.0, 3.42), (8.36, 0.0, 3.18),
               0.07, 0.05, MAT_IRON, 6)
    wk.add_torus(gantry, (8.36, 0.0, 3.06), (0.0, 1.0, 0.0),
                 0.13, 0.035, MAT_IRON, seg=8, tube=3)
    # 装卸平台
    wk.add_box(gantry, (6.05, -4.00, 0.0), (8.40, 4.00, 1.10), MAT_STONE)
    wk.add_box(gantry, (6.05, -4.00, 1.06), (8.40, 4.00, 1.20), MAT_WOOD_DECK)
    for y in (-4.00, 4.00):
        wk.add_box(gantry, (6.05, y - 0.06, 0.0), (8.40, y, 1.20),
                   MAT_WOOD_DARK)
    for i in range(3):
        wk.add_box(gantry, (8.40, -3.0 + i * 3.0, 0.0),
                   (8.62, -2.2 + i * 3.0, 0.20), MAT_STONE)
    parts[prefix + "GantryBeam"] = (gantry, "ROOT")

    return parts


# ---------------------------------------------------------------- 5. 礁石

def _build_reef():
    prefix = "SN_Env_Reef_"
    parts = {}

    rocks = Part()
    specs = (
        (-1.40, 0.70, -3.00, 3.60, 1.50, 11.0, None),
        (-0.20, -1.30, -2.70, 3.10, 1.30, 23.0, None),
        (0.60, -0.40, -1.60, 3.30, 2.45, 37.0,
         ((0.0, 1.0), (0.35, 0.99), (0.65, 0.97), (0.88, 0.92),
          (1.0, 0.62))),
        (2.00, 1.30, -2.80, 3.20, 1.10, 51.0, None),
        (-2.20, -1.00, -3.00, 2.90, 1.00, 67.0, None),
        (0.90, 1.70, -2.60, 2.60, 0.90, 83.0, None),
        # 基台四周的礁岩扶壁：把石鼓边缘垫实，避免“蘑菇顶”悬挑感
        (2.20, 0.70, -1.80, 3.30, 1.15, 97.0, None),
        (-1.20, 1.55, -2.00, 3.10, 1.15, 109.0, None),
        (-1.60, -1.70, -2.40, 2.90, 1.20, 127.0, None),
        (2.20, -1.60, -2.20, 2.70, 1.05, 139.0, None),
    )
    for cx, cy, z0, h, r, seed, levels in specs:
        if levels is None:
            _rock(rocks, cx, cy, z0, h, r, seed, MAT_STONE,
                  wet_mat=MAT_WOOD_DARK)
        else:
            _rock(rocks, cx, cy, z0, h, r, seed, MAT_STONE,
                  wet_mat=MAT_WOOD_DARK, levels=levels)
    # 石鼓外圈的礁岩裙：16 块密排（角向谷距小于岩石有效半径），确保 360° 实体承托
    for i in range(16):
        a = 2.0 * math.pi * i / 16.0 + math.pi / 16.0
        _rock(rocks, 0.60 + 2.25 * math.cos(a), -0.40 + 2.25 * math.sin(a),
              -2.00, 4.20, 1.10, 200.0 + i * 13.0, MAT_STONE,
              wet_mat=MAT_WOOD_DARK, sides=6,
              levels=((0.0, 1.0), (0.48, 0.92), (0.80, 0.66), (1.0, 0.30)))
    #  lighthouse 石砌基台：宽平礁顶 + 等径石鼓 + 0.04 m 压顶沿
    wk.add_cyl(rocks, (0.60, -0.40, 1.20), (0.60, -0.40, 2.16),
               2.66, 2.66, MAT_STONE, 10)
    wk.add_cyl(rocks, (0.60, -0.40, 2.16), (0.60, -0.40, 2.48),
               2.70, 2.66, MAT_STONE, 10)
    for i in range(8):
        a = 2.0 * math.pi * i / 8.0
        wk.add_rivet(rocks, (0.60 + 2.56 * math.cos(a),
                             -0.40 + 2.56 * math.sin(a), 2.48),
                     (0.0, 0.0, 1.0), 0.05, 0.07, MAT_IRON, 5)
    parts[prefix + "Rocks"] = (rocks, "ROOT")

    shelf = Part()
    _rock(shelf, -0.60, 0.60, -0.30, 1.10, 1.35, 121.0, MAT_STONE,
          wet_mat=MAT_WOOD_DARK)
    _rock(shelf, 2.10, -0.90, -0.45, 0.95, 0.95, 131.0, MAT_STONE,
          wet_mat=MAT_WOOD_DARK)
    parts[prefix + "TideShelf"] = (shelf, "ROOT")

    slab = Part()
    _slab(slab, (0.05, 1.05, 0.45), (2.95, 1.55, 1.10),
          (0.0, 1.0, 0.0), 1.70, 0.30, MAT_STONE)
    _slab(slab, (-0.60, 1.35, 0.35), (0.90, 1.65, 0.85),
          (0.0, 1.0, 0.0), 1.10, 0.24, MAT_STONE)
    parts[prefix + "Slab"] = (slab, "ROOT")

    ring = Part()
    wk.add_box(ring, (1.62, 2.12, 0.70), (1.98, 2.30, 1.10), MAT_IRON)
    wk.add_torus(ring, (1.80, 2.36, 0.92), (0.0, 1.0, 0.0),
                 0.20, 0.045, MAT_IRON, seg=10, tube=3)
    for z in (0.78, 1.06):
        wk.add_bolt(ring, (1.80, 2.32, z), 0.05, 0.07, MAT_IRON,
                    axis=(0.0, 1.0, 0.0))
    parts[prefix + "MooringRing"] = (ring, "ROOT")

    return parts


# ---------------------------------------------------------------- 6. 残骸

def _rot_x(part, deg, cy=0.0, cz=0.0):
    ca, sa = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    for i, (x, y, z) in enumerate(part.verts):
        dy, dz = y - cy, z - cz
        part.verts[i] = (x, cy + dy * ca - dz * sa, cz + dy * sa + dz * ca)


def _build_wreck():
    prefix = "SN_Env_Wreck_"
    parts = {}
    length = 8.10
    x_mid = -0.10

    hull = Part()
    # 龙骨 + 船底（龙骨顶面比内底下沉 2 cm，避免共面 z-fighting）
    wk.add_box(hull, (-4.30, -0.16, -1.50), (4.10, 0.16, -1.22), MAT_WOOD_DARK)
    _slab(hull, (x_mid, -0.70, -1.28), (x_mid, 0.70, -1.28),
          (1.0, 0.0, 0.0), length, 0.16, MAT_WOOD)
    # 左舷完整外板（沿 Z 收分）
    _slab(hull, (x_mid, -0.72, -1.20), (x_mid, -1.85, 0.55),
          (1.0, 0.0, 0.0), length, 0.11, MAT_WOOD_DARK)
    # 右舷只剩下部两条
    _slab(hull, (x_mid, 0.72, -1.20), (x_mid, 1.05, -0.60),
          (1.0, 0.0, 0.0), length, 0.11, MAT_WOOD_DARK)
    _slab(hull, (x_mid, 1.05, -0.60), (x_mid, 1.30, -0.15),
          (1.0, 0.0, 0.0), length, 0.11, MAT_WOOD_DARK)
    # 艉板（破损上缘）
    wk.add_box(hull, (4.02, -1.30, -1.10), (4.20, 1.30, 0.30), MAT_WOOD_DARK)
    wk.add_box(hull, (4.05, -0.70, 0.30), (4.22, 0.55, 0.85), MAT_WOOD_DARK)
    # 艏部横向挡板
    _slab(hull, (-4.05, 0.0, -1.10), (-4.05, 0.0, 0.60),
          (0.0, 1.0, 0.0), 1.40, 0.18, MAT_WOOD_DARK)
    wk.add_box(hull, (-4.40, -0.10, -1.30), (-4.00, 0.10, -0.95),
               MAT_WOOD_DARK)
    # 铁箍
    for x in (-2.20, 1.20):
        _slab(hull, (x, -0.74, -1.18), (x, -1.83, 0.52),
              (0.0, 0.0, 1.0), 0.16, 0.05, MAT_IRON)
    # 舷窗
    wk.add_torus(hull, (-2.60, -1.62, 0.28), (0.0, 1.0, 0.0),
                 0.17, 0.045, MAT_BRASS, seg=10, tube=3)
    wk.add_cyl(hull, (-2.60, -1.60, 0.28), (-2.60, -1.56, 0.28),
               0.15, 0.15, MAT_GLASS_DARK, 8)
    parts[prefix + "Hull"] = (hull, "ROOT")

    ribs = Part()
    for x in (-3.20, -2.30, -1.40, -0.50, 0.40, 1.30):
        pts = [(x, 0.55, -1.18), (x, 0.95, -0.55), (x, 1.22, 0.10),
               (x, 1.34, 0.62)]
        for i in range(len(pts) - 1):
            ribs.add(bar_between(pts[i], pts[i + 1], 0.10), MAT_WOOD)
        wk.add_box(ribs, (x - 0.05, 0.50, -1.30), (x + 0.05, 0.62, -1.15),
                   MAT_WOOD_DARK)
    # 断掉的框架上端
    for x in (-2.30, -0.50, 1.30):
        ribs.add(bar_between((x, 1.34, 0.62), (x + 0.10, 1.50, 1.05), 0.08),
                 MAT_WOOD)
    parts[prefix + "Ribs"] = (ribs, "ROOT")

    planking = Part()
    for i, y in enumerate((-1.05, -0.62, -0.18, 0.26, 0.70)):
        wk.add_box(planking, (-3.95, y - 0.18, 0.48), (-0.65, y + 0.18, 0.58),
                   MAT_WOOD_DECK)
    wk.add_box(planking, (-0.72, -1.25, 0.42), (-0.58, 1.25, 0.60),
               MAT_WOOD_DARK)
    for x in (-3.95, -2.75, -1.55, -0.70):
        wk.add_box(planking, (x - 0.07, -1.28, 0.46), (x + 0.07, 1.28, 0.60),
                   MAT_WOOD_DARK)
    # 散落外板 / 断裂板
    planking.add(bar_between((0.60, 1.45, -0.30), (2.60, 1.90, 0.10), 0.14),
                 MAT_WOOD_DARK)
    planking.add(bar_between((1.20, 1.60, 0.05), (2.20, 2.10, 0.55), 0.12),
                 MAT_WOOD)
    for x, y in ((1.90, 1.90), (2.60, 1.50)):
        wk.add_cyl(planking, (x - 0.35, y, 0.18), (x + 0.35, y, 0.24),
                   0.10, 0.10, MAT_WOOD_DARK, 6)
    parts[prefix + "Planking"] = (planking, "ROOT")

    mast = Part()
    # 断桅穿过甲板直落龙骨：桅脚在船底、桅座横梁连接两舷
    wk.add_box(mast, (0.68, -0.20, -1.24), (1.12, 0.20, -1.02), MAT_WOOD_DARK)
    wk.add_cyl(mast, (0.90, 0.0, -1.16), (-0.15, 0.24, 2.95),
               0.24, 0.11, MAT_WOOD_DARK, 8)
    wk.add_box(mast, (0.52, -1.28, 0.44), (1.28, 1.28, 0.60), MAT_WOOD_DARK)
    for sy in (-1.0, 1.0):
        wk.add_cyl(mast, (0.90, sy * 0.10, 0.62), (0.90, sy * 1.24, 0.62),
                   0.07, 0.07, MAT_WOOD_DARK, 6)
    for i in range(3):
        a = 2.0 * math.pi * i / 3.0
        wk.add_cyl(mast, (-0.15 + 0.10 * math.cos(a), 0.24 + 0.10 * math.sin(a),
                          2.90),
                   (-0.15 + 0.32 * math.cos(a), 0.24 + 0.32 * math.sin(a),
                    3.18), 0.045, 0.015, MAT_WOOD_DARK, 4)
    mast.add(bar_between((-0.15, 0.24, 2.30), (0.30, 1.55, 2.10), 0.10),
             MAT_WOOD_DARK)
    wk.add_cyl(mast, (-0.15, 0.24, 2.28), (-0.15, 0.24, 2.42),
               0.14, 0.14, MAT_IRON, 8)
    parts[prefix + "BrokenMast"] = (mast, "ROOT")

    ballast = Part()
    # 逐颗按船底内底平面（13° 横倾后仍为平面）落座，目标 gap=-0.01（轻嵌 1 cm）
    for i, (x, y, z) in enumerate(((1.60, 0.30, -1.214), (2.10, -0.20, -1.225),
                                   (2.60, 0.35, -1.213), (3.00, -0.30, -1.223),
                                   (3.30, 0.10, -1.216))):
        _rock(ballast, x, y, z, 0.38, 0.34, 151.0 + i * 7.0, MAT_STONE,
              sides=5, levels=((0.0, 1.0), (0.55, 0.85), (1.0, 0.3)))
    parts[prefix + "Ballast"] = (ballast, "ROOT")

    for part in parts.values():
        _rot_x(part[0], 13.0)
    return parts


# ---------------------------------------------------------------- 7. 灯塔

def _build_lighthouse():
    prefix = "SN_Env_Lighthouse_"
    parts = {}

    base = Part()
    base.add(prism_xy([(2.49 * math.cos(math.pi / 8 + i * math.pi / 4),
                        2.49 * math.sin(math.pi / 8 + i * math.pi / 4))
                       for i in range(8)], 0.0, 0.80), MAT_STONE)
    base.add(prism_xy([(2.10 * math.cos(math.pi / 8 + i * math.pi / 4),
                        2.10 * math.sin(math.pi / 8 + i * math.pi / 4))
                       for i in range(8)], 0.78, 0.92), MAT_STONE)
    for i, (x0, x1, h) in enumerate(((2.12, 2.20, 0.10), (2.20, 2.32, 0.06))):
        wk.add_box(base, (x0, -0.75, 0.0), (x1, 0.75, h), MAT_STONE)
    for i in range(8):
        a = math.pi / 8 + i * math.pi / 4
        c = (2.30 * math.cos(a), 2.30 * math.sin(a), 0.82)
        _face_box(base, c, (math.cos(a), math.sin(a), 0.0),
                  (-math.sin(a), math.cos(a), 0.0), 0.34, 0.20, 0.10, MAT_IRON)
    parts[prefix + "Base"] = (base, "ROOT")

    tower = Part()
    tower.add(revolved([(0.80, 1.55), (3.00, 1.42), (5.60, 1.28),
                        (7.80, 1.16), (9.60, 1.05)], sides=12), MAT_STONE)
    for z in (1.02, 3.10, 5.70, 8.30):
        wk.add_cyl(tower, (0.0, 0.0, z), (0.0, 0.0, z + 0.12),
                   1.56, 1.56, MAT_IRON, 12)
    # 入口门
    n, t = (1.0, 0.0, 0.0), (0.0, 1.0, 0.0)
    _door(tower, (1.52, 0.0, 1.85), n, t, 1.00, 1.75, MAT_WOOD_DARK,
          MAT_IRON, brace=MAT_IRON)
    _face_box(tower, (1.50, 0.0, 2.82), n, t, 1.40, 0.20, 0.22, MAT_STONE)
    _face_box(tower, (1.52, 0.0, 2.72), n, t, 1.10, 0.12, 0.26, MAT_IRON)
    # 4 个小窗
    for ang, z, r in ((0.0, 3.80, 1.36), (90.0, 5.10, 1.30),
                      (180.0, 6.40, 1.24), (270.0, 7.70, 1.17)):
        a = math.radians(ang)
        _window(tower, (r * math.cos(a), r * math.sin(a), z),
                (math.cos(a), math.sin(a), 0.0),
                (-math.sin(a), math.cos(a), 0.0), 0.62, 0.86,
                frame=MAT_IRON, mullions=0)
    parts[prefix + "Tower"] = (tower, "ROOT")

    gallery = Part()
    wk.add_cyl(gallery, (0.0, 0.0, 9.56), (0.0, 0.0, 9.76),
               1.78, 1.78, MAT_IRON, 12)
    for i in range(8):
        a = 2.0 * math.pi * i / 8.0
        p = (1.10 * math.cos(a), 1.10 * math.sin(a), 9.40)
        q = (1.70 * math.cos(a), 1.70 * math.sin(a), 9.56)
        gallery.add(bar_between(p, q, 0.13), MAT_IRON)
    for i in range(12):
        a = 2.0 * math.pi * i / 12.0
        wk.add_cyl(gallery, (1.66 * math.cos(a), 1.66 * math.sin(a), 9.76),
                   (1.66 * math.cos(a), 1.66 * math.sin(a), 10.62),
                   0.032, 0.032, MAT_IRON, 5)
    for z in (10.58, 10.16):
        wk.add_torus(gallery, (0.0, 0.0, z), (0.0, 0.0, 1.0),
                     1.66, 0.032, MAT_BRASS, seg=12, tube=3)
    parts[prefix + "Catwalk"] = (gallery, "ROOT")

    lantern = Part()
    wk.add_cyl(lantern, (0.0, 0.0, 9.74), (0.0, 0.0, 11.30),
               1.12, 1.12, MAT_GLASS_DARK, 12)
    for i in range(12):
        a = 2.0 * math.pi * i / 12.0
        wk.add_cyl(lantern, (1.14 * math.cos(a), 1.14 * math.sin(a), 9.74),
                   (1.14 * math.cos(a), 1.14 * math.sin(a), 11.30),
                   0.045, 0.045, MAT_BRASS, 5)
    for z in (9.72, 11.28):
        wk.add_cyl(lantern, (0.0, 0.0, z), (0.0, 0.0, z + 0.10),
                   1.24, 1.24, MAT_BRASS, 12)
    wk.add_cyl(lantern, (0.0, 0.0, 10.00), (0.0, 0.0, 10.95),
               0.52, 0.52, MAT_BRASS, 10)
    wk.add_cyl(lantern, (0.0, 0.0, 10.95), (0.0, 0.0, 11.10),
               0.52, 0.28, MAT_GLASS_DARK, 10)
    parts[prefix + "Lantern"] = (lantern, "ROOT")

    dome = Part()
    dome.add(revolved([(11.30, 1.36), (11.58, 1.30), (11.92, 1.06),
                       (12.24, 0.66), (12.42, 0.20)], sides=12), MAT_IRON_RED)
    wk.add_cyl(dome, (0.0, 0.0, 12.40), (0.0, 0.0, 12.66),
               0.16, 0.10, MAT_BRASS, 8)
    wk.add_cyl(dome, (0.0, 0.0, 12.62), (0.0, 0.0, 13.16),
               0.035, 0.012, MAT_METAL, 5)
    wk.add_torus(dome, (0.0, 0.0, 12.92), (0.0, 0.0, 1.0),
                 0.10, 0.022, MAT_BRASS, seg=8, tube=3)
    parts[prefix + "Dome"] = (dome, "ROOT")

    return parts


# ---------------------------------------------------------------- 8. 航标浮标

def _build_buoy():
    prefix = "SN_Env_Buoy_"
    parts = {}

    hull = Part()
    hull.add(revolved([(-0.02, 0.66), (0.16, 0.90), (0.50, 0.94),
                       (0.86, 0.76), (1.18, 0.54), (1.38, 0.42)],
                      sides=10), MAT_IRON_RED)
    wk.add_cyl(hull, (0.0, 0.0, 1.36), (0.0, 0.0, 1.46),
               0.44, 0.40, MAT_IRON, 10)
    for i in range(8):
        a = 2.0 * math.pi * i / 8.0
        wk.add_rivet(hull, (0.91 * math.cos(a), 0.91 * math.sin(a), 0.34),
                     (math.cos(a), math.sin(a), 0.0), 0.035, 0.05,
                     MAT_BRASS, 5)
    parts[prefix + "Hull"] = (hull, "ROOT")

    skirt = Part()
    wk.add_cyl(skirt, (0.0, 0.0, -0.66), (0.0, 0.0, 0.02),
               0.36, 0.58, MAT_IRON, 10)
    wk.add_box(skirt, (-0.10, -0.10, -0.74), (0.10, 0.10, -0.60), MAT_IRON)
    parts[prefix + "Skirt"] = (skirt, "ROOT")

    bands = Part()
    for z, r in ((0.20, 0.90), (0.62, 0.84)):
        wk.add_torus(bands, (0.0, 0.0, z), (0.0, 0.0, 1.0),
                     r, 0.04, MAT_IRON, seg=10, tube=3)
    for i in range(4):
        a = 2.0 * math.pi * i / 4.0 + math.pi / 4.0
        wk.add_box(bands, (0.62 * math.cos(a) - 0.05, 0.62 * math.sin(a) - 0.05,
                           1.00),
                   (0.62 * math.cos(a) + 0.05, 0.62 * math.sin(a) + 0.05,
                    1.36), MAT_IRON)
    parts[prefix + "Bands"] = (bands, "ROOT")

    lamp = Part()
    for i in range(3):
        a = 2.0 * math.pi * i / 3.0
        lamp.add(bar_between((0.36 * math.cos(a), 0.36 * math.sin(a), 1.42),
                             (0.20 * math.cos(a), 0.20 * math.sin(a), 2.34),
                             0.07), MAT_IRON)
    wk.add_cyl(lamp, (0.0, 0.0, 2.30), (0.0, 0.0, 2.36),
               0.36, 0.36, MAT_BRASS, 8)
    wk.add_cyl(lamp, (0.0, 0.0, 2.36), (0.0, 0.0, 2.86),
               0.24, 0.22, MAT_GLASS_DARK, 8)
    for i in range(4):
        a = 2.0 * math.pi * i / 4.0
        wk.add_cyl(lamp, (0.245 * math.cos(a), 0.245 * math.sin(a), 2.36),
                   (0.245 * math.cos(a), 0.245 * math.sin(a), 2.86),
                   0.022, 0.022, MAT_BRASS, 4)
    wk.add_cyl(lamp, (0.0, 0.0, 2.86), (0.0, 0.0, 3.06),
               0.28, 0.04, MAT_BRASS, 8)
    wk.add_cyl(lamp, (0.0, 0.0, 3.02), (0.0, 0.0, 3.10),
               0.05, 0.02, MAT_BRASS, 5)
    parts[prefix + "LampFrame"] = (lamp, "ROOT")

    bell = Part()
    bell.add(bar_between((0.0, -0.36, 2.33), (0.0, -0.45, 2.02), 0.05),
             MAT_IRON)
    wk.add_cyl(bell, (0.0, -0.45, 1.86), (0.0, -0.45, 2.00),
               0.19, 0.11, MAT_BRASS, 6)
    wk.add_cyl(bell, (0.0, -0.45, 1.80), (0.0, -0.45, 1.86),
               0.10, 0.15, MAT_BRASS, 6)
    wk.add_cyl(bell, (0.0, -0.45, 1.72), (0.0, -0.45, 1.80),
               0.03, 0.05, MAT_METAL, 5)
    parts[prefix + "BellRig"] = (bell, "ROOT")

    chain = Part()
    wk.add_torus(chain, (0.52, 0.0, 0.36), (1.0, 0.0, 0.0),
                 0.075, 0.022, MAT_IRON, seg=6, tube=3)
    for i in range(2):
        z = 0.24 - i * 0.17
        wk.add_torus(chain, (0.56, 0.0, z), (0.0, 1.0, 0.0),
                     0.075, 0.022, MAT_IRON, seg=6, tube=3)
    wk.add_box(chain, (0.50, -0.10, 0.30), (0.62, 0.10, 0.42), MAT_IRON)
    parts[prefix + "ChainLinks"] = (chain, "ROOT")

    return parts


# ---------------------------------------------------------------- 装配配置

BUILDERS = {
    "SN_Arch_Warehouse": _build_warehouse,
    "SN_Arch_Workshop": _build_workshop,
    "SN_Arch_Tavern": _build_tavern,
    "SN_Arch_Factory": _build_factory,
    "SN_Env_Reef": _build_reef,
    "SN_Env_Wreck": _build_wreck,
    "SN_Env_Lighthouse": _build_lighthouse,
    "SN_Env_Buoy": _build_buoy,
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
    }
    if "module" in spec:
        root_props["module_x"] = float(spec["module"][0])
        root_props["module_y"] = float(spec["module"][1])
    if "waterline" in spec:
        root_props["waterline"] = float(spec["waterline"])
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
    print("KIT_BATCH3_REPORT %r" % {
        "assets": {asset: out[asset]["tris"] for asset in ASSETS},
        "total_tris": sum(v["tris"] for v in out.values()),
    })
    return out


if __name__ == "__main__":
    build_all_kits()
    report()
