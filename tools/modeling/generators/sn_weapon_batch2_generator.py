# -*- coding: utf-8 -*-
# @static-doc
# 作用：舰载特殊武器三件套（舰载弩炮 / 载人箭塔 / 蒸汽鱼叉发射器）的参数化生成器
# 与 Blender 装配入口；同时给出“不规则形态如何拼进 socket”的模型侧契约：
# 统一的 Mount 空节点 + mount_class、footprint、swept_radius、anchors 根属性。
#
# 工单：`tools/modeling/briefs/sn_weapon_batch2.json`
# 集合：每件武器一个 `SN_Weapon_<Name>_Prototype`；根节点 `SN_Weapon_<Name>_Root`
# 轴心：底座贴地面中心（z = 0），+X 为前向/炮口方向，+Z 向上，1 unit = 1 m。
# 层级：
# - 弩炮 / 鱼叉：Root → Yaw_Pivot → Pitch_Pivot；另有 Mount + 4 个 Anchor。
# - 箭塔：固定塔，无 Yaw/Pitch；Mount + 4 个 Anchor 定义底座与拉索点。
#
# 用法：
# - Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
# - 纯 Python 干跑：`python tools/modeling/generators/dryrun_weapon_batch2.py`
# - 导出 GLB：`python tools/modeling/generators/export_weapon_batch2_glb.py`
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

import weapon_kit as wk
from ship_parts.core import Part

from sn_weapon_materials import (
    ASSET_MATERIALS,
    MAT_BRASS,
    MAT_CANVAS_SHADE,
    MAT_IRON,
    MAT_IRON_RED,
    MAT_METAL,
    MAT_WOOD,
    MAT_WOOD_DARK,
    MAT_WOOD_DECK,
    colors_for,
)

ASSETS = [
    "SN_Weapon_Ballista",
    "SN_Weapon_ArrowTower",
    "SN_Weapon_HarpoonLauncher",
]

WORKBENCH_POS = {
    "SN_Weapon_Ballista": (0.0, 380.0, 0.0),
    "SN_Weapon_ArrowTower": (0.0, 400.0, 0.0),
    "SN_Weapon_HarpoonLauncher": (0.0, 420.0, 0.0),
}

SPECS = {
    "SN_Weapon_Ballista": {
        "collection": "SN_Weapon_Ballista_Prototype",
        "prefix": "SN_Weapon_Ballista_",
        "type": "ship-mounted ballista",
        "tri_budget": 4500,
        "bbox": (5.00, 3.00, 2.20),
        "tol": 0.10,
        "mount_class": "Heavy",
        "pivot_profile": "yaw_pitch",
        "base_footprint": (2.2, 2.2),
        "swept_radius": 3.2,
        "required": ("Base", "Frame", "Bow", "Bolt"),
    },
    "SN_Weapon_ArrowTower": {
        "collection": "SN_Weapon_ArrowTower_Prototype",
        "prefix": "SN_Weapon_ArrowTower_",
        "type": "manned arrow tower",
        "tri_budget": 5500,
        "bbox": (3.80, 3.80, 6.60),
        "tol": 0.12,
        "mount_class": "Tower",
        "pivot_profile": "fixed",
        "base_footprint": (3.0, 3.0),
        "swept_radius": 0.0,
        "required": ("Base", "Tower", "Platform", "Railing", "Ladder"),
    },
    "SN_Weapon_HarpoonLauncher": {
        "collection": "SN_Weapon_HarpoonLauncher_Prototype",
        "prefix": "SN_Weapon_HarpoonLauncher_",
        "type": "steam harpoon launcher",
        "tri_budget": 4500,
        "bbox": (4.60, 1.80, 2.20),
        "tol": 0.10,
        "mount_class": "Medium",
        "pivot_profile": "yaw_pitch",
        "base_footprint": (1.6, 1.6),
        "swept_radius": 3.2,
        "required": ("Base", "Frame", "Tank", "Harpoon"),
    },
}

ANCHORS = {
    "SN_Weapon_Ballista": ((-1.60, -1.10, 0.20), (-1.60, 1.10, 0.20),
                           (1.40, -1.10, 0.20), (1.40, 1.10, 0.20)),
    "SN_Weapon_ArrowTower": ((-1.60, -1.60, 0.25), (-1.60, 1.60, 0.25),
                             (1.60, -1.60, 0.25), (1.60, 1.60, 0.25)),
    "SN_Weapon_HarpoonLauncher": ((-1.20, -0.80, 0.18), (-1.20, 0.80, 0.18),
                                  (1.20, -0.80, 0.18), (1.20, 0.80, 0.18)),
}


# ---------------------------------------------------------------- 舰载弩炮

def _ballista():
    prefix = "SN_Weapon_Ballista_"
    parts = {}

    root = Part()
    wk.add_box(root, (-1.80, -1.20, 0.0), (1.40, 1.20, 0.20), MAT_WOOD_DECK)
    for x in (-1.60, 1.20):
        for sy in (-1.0, 1.0):
            wk.add_box(root, (x - 0.12, sy * 1.00 - 0.12, 0.14),
                       (x + 0.12, sy * 1.00 + 0.12, 0.24), MAT_IRON)
            wk.add_bolt(root, (x, sy * 1.00, 0.27), 0.05, 0.07, MAT_BRASS)
    wk.add_cyl(root, (0.0, 0.0, 0.18), (0.0, 0.0, 0.22), 1.10, 1.10,
               MAT_IRON, 16)
    wk.add_torus(root, (0.0, 0.0, 0.23), (0.0, 0.0, 1.0), 1.10, 0.045,
                 MAT_BRASS, seg=16, tube=4)
    for i in range(4):
        a = math.radians(45.0 + i * 90.0)
        wk.add_bolt(root, (1.0 * math.cos(a), 1.0 * math.sin(a), 0.24),
                    0.045, 0.06, MAT_BRASS)
    parts[prefix + "Base"] = (root, "ROOT")

    frame = Part()
    wk.add_cyl(frame, (0.0, 0.0, 0.20), (0.0, 0.0, 0.38), 0.85, 0.80,
               MAT_IRON, 16)
    wk.add_cyl(frame, (0.0, 0.0, 0.38), (0.0, 0.0, 0.44), 0.92, 0.90,
               MAT_METAL, 16)
    for sy in (-1.0, 1.0):
        wk.add_box(frame, (-1.48, sy * 0.65, 0.44), (1.15, sy * 0.80, 0.74),
                   MAT_WOOD)
    for x in (-1.38, -0.70, 0.10, 0.90):
        wk.add_box(frame, (x - 0.08, -0.72, 0.44), (x + 0.08, 0.72, 0.56),
                   MAT_IRON)
    wk.add_cyl(frame, (-0.10, 0.0, 0.44), (-0.10, 0.0, 0.95), 0.34, 0.30,
               MAT_METAL, 10)
    wk.add_box(frame, (-0.28, -0.34, 0.95), (0.16, 0.34, 1.06), MAT_IRON)
    wk.cheek_pair(frame, -0.10, 0.68, 0.46, 0.14, 0.94, 1.36, MAT_IRON_RED)
    for sy in (-1.0, 1.0):
        wk.add_box(frame, (0.50, sy * 0.34, 0.70), (0.62, sy * 1.05, 1.48),
                   MAT_IRON_RED)
        wk.rivet_row(frame, (0.63, sy * 0.55, 0.82),
                     (0.63, sy * 0.55, 1.36), 4, (1.0, 0.0, 0.0),
                     0.030, 0.03, MAT_BRASS)
        wk.add_box(frame, (0.50, sy * 0.98, 0.68), (0.64, sy * 1.06, 2.05),
                   MAT_WOOD_DARK)
        wk.add_box(frame, (0.52, sy * 0.96, 2.02), (0.66, sy * 1.08, 2.10),
                   MAT_IRON)
    wk.add_box(frame, (0.52, -1.06, 2.02), (0.66, 1.06, 2.10), MAT_IRON)
    wk.add_cyl(frame, (0.58, 0.0, 2.10), (0.58, 0.0, 2.20), 0.035, 0.030,
               MAT_METAL, 6)
    wk.add_bar(frame, (0.50, -0.12, 2.18), (0.66, 0.12, 2.18), 0.035,
               MAT_METAL)
    parts[prefix + "Frame"] = (frame, "YAW")

    # 后部绞盘：卷筒 + 齿轮 + 摇柄
    winch = Part()
    wk.add_box(winch, (-1.50, -0.55, 0.55), (-1.10, 0.55, 0.78),
               MAT_WOOD_DARK)
    wk.add_cyl(winch, (-1.30, -0.48, 0.72), (-1.30, 0.48, 0.72), 0.16, 0.16,
               MAT_IRON, 10)
    wk.add_cyl(winch, (-1.30, -0.58, 0.72), (-1.30, -0.48, 0.72), 0.24, 0.24,
               MAT_METAL, 10)
    for i in range(6):
        a = math.radians(i * 60.0)
        wk.add_bar(winch, (-1.30, -0.53, 0.72),
                   (-1.30 + 0.22 * math.cos(a), -0.53 + 0.22 * math.sin(a),
                    0.72), 0.035, MAT_METAL)
    wk.add_bar(winch, (-1.30, -0.53, 0.72), (-1.30, -0.70, 0.92), 0.045,
               MAT_METAL)
    wk.add_cyl(winch, (-1.30, -0.70, 0.92), (-1.30, -0.70, 1.05), 0.035,
               0.035, MAT_BRASS, 6)
    wk.handwheel(winch, (-1.62, 0.0, 0.95), (0.0, 1.0, 0.0), 0.18,
                 MAT_BRASS, spokes=4, hub_r=0.05)
    wk.add_cyl(winch, (-1.50, 0.0, 0.78), (-1.50, 0.0, 0.95), 0.05, 0.05,
               MAT_METAL, 6)
    parts[prefix + "Winch"] = (winch, "YAW")

    bow = Part()
    # 弩臂：两根前伸外张的弓臂 + 扭力弹簧
    for sy in (-1.0, 1.0):
        arm = [(0.58, sy * 0.46, 1.10), (0.82, sy * 0.80, 1.18),
               (1.02, sy * 1.18, 1.28), (1.20, sy * 1.50, 1.34)]
        wk.add_tube(bow, arm, [0.095, 0.085, 0.070, 0.055], MAT_WOOD, 6)
        wk.add_cyl(bow, (0.56, sy * 0.36, 1.10), (0.56, sy * 0.62, 1.10),
                   0.15, 0.15, MAT_BRASS, 8)
        wk.add_cyl(bow, (0.50, sy * 0.36, 1.10), (0.50, sy * 0.62, 1.10),
                   0.18, 0.18, MAT_IRON, 8)
        for t in (0.35, 0.68, 0.9):
            x = 0.58 + (1.20 - 0.58) * t
            y = sy * (0.46 + (1.50 - 0.46) * t)
            z = 1.10 + 0.24 * t
            wk.add_cyl(bow, (x - 0.03, y, z), (x + 0.03, y, z), 0.075,
                       0.075, MAT_BRASS, 6)
    # 弩弦
    wk.add_tube(bow, [(1.20, -1.50, 1.34), (-0.42, 0.0, 1.10),
                      (1.20, 1.50, 1.34)], [0.020, 0.022, 0.020],
               MAT_CANVAS_SHADE, 4)
    # 发射轨
    for sy in (-1.0, 1.0):
        wk.add_box(bow, (-0.60, sy * 0.10, 1.00), (1.15, sy * 0.18, 1.10),
                   MAT_IRON)
    parts[prefix + "Bow"] = (bow, "PITCH")

    bolt = Part()
    wk.add_cyl(bolt, (-0.30, 0.0, 1.12), (3.20, 0.0, 1.12), 0.052, 0.045,
               MAT_WOOD_DARK, 8)
    wk.add_cyl(bolt, (2.88, 0.0, 1.12), (3.20, 0.0, 1.12), 0.085, 0.020,
               MAT_IRON, 6)
    for sy in (-1.0, 1.0):
        wk.add_bar(bolt, (2.90, sy * 0.06, 1.12),
                   (3.02, sy * 0.25, 1.12), 0.030, MAT_IRON)
        wk.add_bar(bolt, (-0.28, sy * 0.05, 1.12),
                   (-0.10, sy * 0.16, 1.12), 0.028, MAT_IRON)
    # 箭羽
    for angle in (0.0, 90.0):
        a = math.radians(angle)
        for sy in (-1.0, 1.0):
            dx, dy = math.cos(a) * 0.08, math.sin(a) * 0.08
            wk.add_box(bolt, (-0.34 + dx - 0.02, dy * sy - 0.02, 1.10),
                       (-0.10 + dx + 0.02, dy * sy + 0.02, 1.14),
                       MAT_CANVAS_SHADE)
    wk.add_cyl(bolt, (0.10, 0.0, 1.12), (0.10, 0.0, 1.34), 0.025, 0.025,
               MAT_METAL, 6)
    wk.add_torus(bolt, (0.10, 0.0, 1.34), (0.0, 1.0, 0.0), 0.06, 0.012,
                 MAT_BRASS, seg=10, tube=4)
    parts[prefix + "Bolt"] = (bolt, "PITCH")
    return parts


# ---------------------------------------------------------------- 载人箭塔

def _arrow_tower():
    prefix = "SN_Weapon_ArrowTower_"
    parts = {}

    root = Part()
    wk.add_box(root, (-1.90, -1.90, 0.0), (1.90, 1.90, 0.25), MAT_WOOD_DECK)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            wk.add_box(root, (sx * 1.72 - 0.12, sy * 1.72 - 0.12, 0.18),
                       (sx * 1.72 + 0.12, sy * 1.72 + 0.12, 0.30), MAT_IRON)
            wk.add_bolt(root, (sx * 1.72, sy * 1.72, 0.33), 0.05, 0.07,
                        MAT_BRASS)
    wk.add_box(root, (-1.55, -1.55, 0.25), (1.55, 1.55, 0.30), MAT_IRON)
    for i in range(4):
        a = math.radians(45.0 + i * 90.0)
        wk.add_bolt(root, (1.35 * math.cos(a), 1.35 * math.sin(a), 0.33),
                    0.05, 0.07, MAT_BRASS)
    parts[prefix + "Base"] = (root, "ROOT")

    tower = Part()
    # 四角塔柱 + 铁箍 + 横梁 + 斜撑
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            wk.add_box(tower, (sx * 1.60 - 0.13, sy * 1.60 - 0.13, 0.25),
                       (sx * 1.60 + 0.13, sy * 1.60 + 0.13, 4.80),
                       MAT_WOOD)
            for z in (1.1, 2.2, 3.3, 4.4):
                wk.add_box(tower, (sx * 1.60 - 0.16, sy * 1.60 - 0.16, z),
                           (sx * 1.60 + 0.16, sy * 1.60 + 0.16, z + 0.10),
                           MAT_IRON)
    for z in (1.2, 2.4, 3.6, 4.55):
        for sx in (-1.0, 1.0):
            wk.add_box(tower, (sx * 1.60 - 0.10, -1.55, z),
                       (sx * 1.60 + 0.10, 1.55, z + 0.12), MAT_IRON)
        for sy in (-1.0, 1.0):
            wk.add_box(tower, (-1.55, sy * 1.60 - 0.10, z),
                       (1.55, sy * 1.60 + 0.10, z + 0.12), MAT_IRON)
    for z0, z1 in ((0.45, 1.2), (1.3, 2.4), (2.5, 3.6), (3.7, 4.55)):
        for sy in (-1.0, 1.0):
            wk.add_bar(tower, (-1.55, sy * 1.60, z0), (1.55, sy * 1.60, z1),
                       0.08, MAT_WOOD_DARK)
            wk.add_bar(tower, (1.55, sy * 1.60, z0), (-1.55, sy * 1.60, z1),
                       0.08, MAT_WOOD_DARK)
        for sx in (-1.0, 1.0):
            wk.add_bar(tower, (sx * 1.60, -1.55, z0), (sx * 1.60, 1.55, z1),
                       0.08, MAT_WOOD_DARK)
            wk.add_bar(tower, (sx * 1.60, 1.55, z0), (sx * 1.60, -1.55, z1),
                       0.08, MAT_WOOD_DARK)
    parts[prefix + "Tower"] = (tower, "ROOT")

    platform = Part()
    # 平台 + 支撑梁
    wk.add_box(platform, (-1.55, -1.55, 4.80), (1.55, 1.55, 5.00),
               MAT_WOOD_DECK)
    for sy in (-1.0, 1.0):
        wk.add_box(platform, (-1.55, sy * 1.10, 4.62), (1.55, sy * 1.30, 4.80),
                   MAT_WOOD_DARK)
    wk.add_box(platform, (1.10, -1.55, 4.62), (1.30, 1.55, 4.80),
               MAT_WOOD_DARK)
    parts[prefix + "Platform"] = (platform, "ROOT")

    rail = Part()
    # 三面完整栏杆，+X 面留出梯口
    wk.railing(rail, [(1.45, 1.45, 5.00), (-1.45, 1.45, 5.00),
                      (-1.45, -1.45, 5.00), (0.30, -1.45, 5.00)], 1.00,
               MAT_WOOD_DARK, post_step=0.9)
    wk.railing(rail, [(1.45, 1.45, 5.00), (1.45, -1.45, 5.00)], 1.00,
               MAT_WOOD_DARK, post_step=0.9)
    wk.railing(rail, [(-0.30, -1.45, 5.00), (1.45, -1.45, 5.00)], 1.00,
               MAT_WOOD_DARK, post_step=0.9)
    # 箭塔上部的四角柱 + 帆布顶
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            wk.add_box(rail, (sx * 1.42 - 0.08, sy * 1.42 - 0.08, 5.00),
                       (sx * 1.42 + 0.08, sy * 1.42 + 0.08, 6.05),
                       MAT_WOOD)
    wk.add_box(rail, (-1.55, -1.55, 6.05), (1.55, 1.55, 6.16),
               MAT_CANVAS_SHADE)
    wk.add_box(rail, (-1.62, -1.62, 6.16), (1.62, 1.62, 6.20),
               MAT_WOOD_DARK)
    wk.add_cyl(rail, (0.0, 0.0, 6.20), (0.0, 0.0, 6.55), 0.055, 0.040,
               MAT_BRASS, 8)
    wk.add_torus(rail, (0.0, 0.0, 6.50), (0.0, 0.0, 1.0), 0.10, 0.020,
                 MAT_BRASS, seg=10, tube=4)
    # 三面箭窗板（中间留竖向箭缝）
    for cx, cy, along_x in ((0.0, -1.52, True), (1.52, 0.0, False),
                            (-1.52, 0.0, False)):
        for sign in (-1.0, 1.0):
            if along_x:
                wk.add_box(rail, (cx + sign * 0.30 - 0.22, cy - 0.04,
                                  5.10), (cx + sign * 0.30 + 0.22,
                                          cy + 0.04, 6.02), MAT_IRON_RED)
            else:
                wk.add_box(rail, (cx - 0.04, cy + sign * 0.30 - 0.22, 5.10),
                           (cx + 0.04, cy + sign * 0.30 + 0.22, 6.02),
                           MAT_IRON_RED)
        if along_x:
            wk.add_box(rail, (cx - 0.08, cy - 0.05, 5.10),
                       (cx + 0.08, cy + 0.05, 6.02), MAT_IRON)
        else:
            wk.add_box(rail, (cx - 0.05, cy - 0.08, 5.10),
                       (cx + 0.05, cy + 0.08, 6.02), MAT_IRON)
        for dx, dy in ((-0.38, 0.0), (0.38, 0.0)):
            if along_x:
                wk.add_bolt(rail, (cx + dx, cy - 0.05, 5.25), 0.028, 0.02,
                            MAT_BRASS, axis=(0.0, 1.0, 0.0))
            else:
                wk.add_bolt(rail, (cx - 0.05, cy + dy, 5.25), 0.028, 0.02,
                            MAT_BRASS, axis=(1.0, 0.0, 0.0))
    # 平台上的箭袋 / 盾牌 / 铜钟
    for sx in (-1.0, 1.0):
        wk.add_box(rail, (sx * 1.20 - 0.18, 1.10 - 0.18, 5.00),
                   (sx * 1.20 + 0.18, 1.10 + 0.18, 5.50), MAT_WOOD_DARK)
        for i in range(6):
            x = sx * 1.20 - 0.12 + (i % 3) * 0.12
            y = 1.10 - 0.10 + (i // 3) * 0.10
            wk.add_cyl(rail, (x, y, 5.35), (x, y, 5.85), 0.018, 0.018,
                       MAT_WOOD_DARK, 4)
            wk.add_box(rail, (x - 0.03, y - 0.03, 5.78),
                       (x + 0.03, y + 0.03, 5.85), MAT_CANVAS_SHADE)
        wk.add_box(rail, (sx * 0.85 - 0.30, -1.58, 5.05),
                   (sx * 0.85 + 0.30, -1.50, 5.95), MAT_IRON_RED)
        wk.add_cyl(rail, (sx * 0.85, -1.60, 5.50), (sx * 0.85, -1.52, 5.50),
                   0.10, 0.10, MAT_BRASS, 8)
    wk.add_cyl(rail, (0.0, 0.0, 5.55), (0.0, 0.0, 5.80), 0.14, 0.10,
               MAT_BRASS, 10)
    wk.add_cyl(rail, (0.0, 0.0, 5.80), (0.0, 0.0, 5.84), 0.10, 0.10,
               MAT_BRASS, 10)
    wk.add_cyl(rail, (0.0, 0.0, 5.48), (0.0, 0.0, 5.55), 0.03, 0.03,
               MAT_METAL, 6)
    parts[prefix + "Railing"] = (rail, "ROOT")

    ladder = Part()
    wk.ladder(ladder, (1.72, 0.0, 0.25), (1.72, 0.0, 4.80), 0.50,
              MAT_WOOD_DARK, step=0.32)
    for z in (0.30, 2.50, 4.75):
        wk.add_box(ladder, (1.62, -0.32, z), (1.82, 0.32, z + 0.08),
                   MAT_IRON)
    parts[prefix + "Ladder"] = (ladder, "ROOT")

    anchor = Part()
    for i, (x, y, z) in enumerate(ANCHORS["SN_Weapon_ArrowTower"]):
        wk.add_box(anchor, (x - 0.18, y - 0.18, z), (x + 0.18, y + 0.18,
                                                     z + 0.10), MAT_IRON)
        wk.add_bolt(anchor, (x, y, z + 0.15), 0.04, 0.06, MAT_BRASS)
        wk.add_tube(anchor, [(x, y, z + 0.10), (x * 0.72, y * 0.72, z + 0.55),
                             (x * 0.45, y * 0.45, z + 0.62)],
                    [0.035, 0.030, 0.026], MAT_IRON, 4)
        wk.rope_loop(anchor, (x * 0.60, y * 0.60, z + 0.62),
                     (0.0, 0.0, 1.0), 0.10, 0.020, MAT_CANVAS_SHADE)
    parts[prefix + "Anchors"] = (anchor, "ROOT")
    return parts


# ---------------------------------------------------------------- 蒸汽鱼叉发射器

def _harpoon():
    prefix = "SN_Weapon_HarpoonLauncher_"
    parts = {}

    root = Part()
    wk.add_box(root, (-1.40, -0.90, 0.0), (1.20, 0.90, 0.18), MAT_IRON)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            wk.add_box(root, (sx * 1.20 - 0.10, sy * 0.72 - 0.10, 0.12),
                       (sx * 1.20 + 0.10, sy * 0.72 + 0.10, 0.22), MAT_IRON)
            wk.add_bolt(root, (sx * 1.20, sy * 0.72, 0.25), 0.05, 0.06,
                        MAT_BRASS)
    wk.add_cyl(root, (0.0, 0.0, 0.14), (0.0, 0.0, 0.22), 0.80, 0.80,
               MAT_METAL, 16)
    wk.add_torus(root, (0.0, 0.0, 0.23), (0.0, 0.0, 1.0), 0.80, 0.04,
                 MAT_BRASS, seg=16, tube=4)
    for i in range(4):
        a = math.radians(45.0 + i * 90.0)
        wk.add_bolt(root, (0.72 * math.cos(a), 0.72 * math.sin(a), 0.24),
                    0.04, 0.06, MAT_BRASS)
    parts[prefix + "Base"] = (root, "ROOT")

    frame = Part()
    wk.add_cyl(frame, (0.0, 0.0, 0.18), (0.0, 0.0, 0.36), 0.65, 0.60,
               MAT_IRON, 14)
    wk.add_cyl(frame, (0.0, 0.0, 0.36), (0.0, 0.0, 0.96), 0.30, 0.26,
               MAT_METAL, 10)
    wk.cheek_pair(frame, -0.22, 0.42, 0.45, 0.14, 0.92, 1.30, MAT_IRON_RED)
    wk.add_box(frame, (-0.26, -0.52, 0.96), (0.18, 0.52, 1.04), MAT_IRON)
    parts[prefix + "Frame"] = (frame, "YAW")

    tank = Part()
    # 压力罐（黄铜）+ 箍 + 阀门/压力表
    wk.add_cyl(tank, (-1.30, -0.55, 0.86), (0.20, -0.55, 0.86), 0.23, 0.23,
               MAT_BRASS, 12)
    for x in (-1.22, -0.86, -0.50, -0.14):
        wk.add_cyl(tank, (x - 0.04, -0.55, 0.86), (x + 0.04, -0.55, 0.86),
                   0.27, 0.27, MAT_IRON, 12)
    wk.add_cyl(tank, (-1.34, -0.55, 0.86), (-1.30, -0.55, 0.86), 0.16, 0.16,
               MAT_IRON, 10)
    wk.add_cyl(tank, (0.20, -0.55, 0.86), (0.26, -0.55, 0.86), 0.14, 0.14,
               MAT_IRON, 10)
    wk.add_cyl(tank, (-0.92, -0.55, 0.86), (-0.92, -0.55, 1.12), 0.055,
               0.055, MAT_BRASS, 8)
    wk.add_torus(tank, (-0.92, -0.55, 1.12), (0.0, 1.0, 0.0), 0.11, 0.022,
                 MAT_BRASS, seg=10, tube=4)
    wk.handwheel(tank, (-1.14, -0.55, 1.10), (0.0, 0.0, 1.0), 0.15,
                 MAT_BRASS, spokes=4, hub_r=0.04)
    wk.steam_pipe(tank, [(-0.20, -0.55, 0.86), (-0.08, -0.38, 1.00),
                         (0.02, -0.16, 1.04)], 0.045, MAT_METAL)
    # 后部绞盘 + 链条（放在 -Y 相机侧，避开压力罐与摇架）
    wk.add_box(tank, (-1.34, -0.92, 0.40), (-1.08, -0.66, 0.58),
               MAT_WOOD_DARK)
    wk.add_cyl(tank, (-1.20, -0.90, 0.66), (-1.20, -0.66, 0.66), 0.13, 0.13,
               MAT_IRON, 10)
    wk.add_cyl(tank, (-1.20, -0.94, 0.66), (-1.20, -0.90, 0.66), 0.19, 0.19,
               MAT_METAL, 10)
    wk.add_bar(tank, (-1.20, -0.66, 0.66), (-1.20, -0.54, 0.84), 0.045,
               MAT_METAL)
    wk.add_cyl(tank, (-1.20, -0.54, 0.84), (-1.20, -0.54, 0.96), 0.035,
               0.035, MAT_BRASS, 6)
    wk.add_box(tank, (-1.30, -0.66, 0.52), (-1.10, -0.50, 0.64), MAT_IRON)
    wk.add_tube(tank, [(-1.20, -0.78, 0.70), (-0.94, -0.52, 0.80),
                       (-0.60, -0.20, 0.92)], [0.025, 0.023, 0.020],
               MAT_IRON, 4)
    parts[prefix + "Tank"] = (tank, "YAW")

    pitch = Part()
    for sy in (-1.0, 1.0):
        wk.add_box(pitch, (-0.60, sy * 0.12, 0.96), (2.00, sy * 0.19, 1.06),
                   MAT_IRON)
        wk.add_cyl(pitch, (-0.20, sy * 0.22, 0.90), (0.60, sy * 0.22, 0.90),
                   0.06, 0.06, MAT_METAL, 8)
    wk.add_box(pitch, (-0.70, -0.26, 0.84), (-0.24, 0.26, 1.20), MAT_IRON)
    wk.add_cyl(pitch, (-0.84, 0.0, 1.02), (-0.70, 0.0, 1.02), 0.09, 0.09,
               MAT_BRASS, 8)
    wk.trunnion(pitch, 0.30, 1.00, 1.12, 0.12, MAT_METAL)
    wk.handwheel(pitch, (-0.10, 0.48, 1.18), (0.0, 1.0, 0.0), 0.14,
                 MAT_BRASS, spokes=4, hub_r=0.04)
    parts[prefix + "Cradle"] = (pitch, "PITCH")

    harpoon = Part()
    # 鱼叉：长杆 + 倒钩 + 尾环
    wk.add_cyl(harpoon, (-0.30, 0.0, 1.05), (3.20, 0.0, 1.05), 0.052, 0.045,
               MAT_WOOD_DARK, 8)
    wk.add_cyl(harpoon, (2.90, 0.0, 1.05), (3.20, 0.0, 1.05), 0.10, 0.020,
               MAT_IRON, 8)
    for sy in (-1.0, 1.0):
        wk.add_bar(harpoon, (2.86, sy * 0.07, 1.05),
                   (3.00, sy * 0.30, 1.05), 0.032, MAT_IRON)
        wk.add_bar(harpoon, (3.00, sy * 0.30, 1.05),
                   (3.10, sy * 0.16, 1.05), 0.028, MAT_IRON)
    wk.add_torus(harpoon, (-0.30, 0.0, 1.05), (1.0, 0.0, 0.0), 0.10, 0.020,
                 MAT_BRASS, seg=10, tube=4)
    wk.add_tube(harpoon, [(-0.30, 0.0, 1.05), (-0.52, 0.0, 1.00)],
                [0.020, 0.020], MAT_IRON, 4)
    wk.add_cyl(harpoon, (0.58, 0.0, 1.06), (0.58, 0.0, 2.20), 0.022, 0.022,
               MAT_METAL, 6)
    wk.add_torus(harpoon, (0.58, 0.0, 2.20), (0.0, 1.0, 0.0), 0.07, 0.012,
                 MAT_BRASS, seg=10, tube=4)
    parts[prefix + "Harpoon"] = (harpoon, "PITCH")
    return parts


GEOMETRY_BUILDERS = {
    "SN_Weapon_Ballista": _ballista,
    "SN_Weapon_ArrowTower": _arrow_tower,
    "SN_Weapon_HarpoonLauncher": _harpoon,
}


def build_geometry(asset):
    parts = GEOMETRY_BUILDERS[asset]()
    # 装配规范 v2：炮身 / 弩臂 / 鱼叉挂到 Recoil
    out = {}
    for name, (part, parent) in parts.items():
        if parent == "PITCH":
            parent = "RECOIL"
        out[name] = (part, parent)
    return out


# ---------------------------------------------------------------- 装配配置

def _muzzle_tip(parts, parent_key):
    best = None
    for _name, (part, parent) in parts.items():
        if parent != parent_key:
            continue
        for v in part.verts:
            if best is None or v[0] > best[0]:
                best = v
    return best


def _pivot_specs(asset):
    """武器装配规范 v2：标准节点名 + 可选装配层。"""
    prefix = SPECS[asset]["prefix"]
    parts = build_geometry(asset)
    profile = SPECS[asset]["pivot_profile"]
    specs = [{"key": "MOUNT", "name": prefix + "Mount", "parent": "ROOT",
              "location": (0.0, 0.0, 0.0)}]
    if profile == "yaw_pitch":
        pitch_loc = ((0.20, 0.0, 1.10) if asset == "SN_Weapon_Ballista"
                     else (0.30, 0.0, 1.00))
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
                      "location": (tip[0] - pitch_loc[0],
                                   tip[1] - pitch_loc[1],
                                   tip[2] - pitch_loc[2])})
    for i, loc in enumerate(ANCHORS[asset], start=1):
        specs.append({"key": "ANCHOR_%d" % i, "name": prefix + "Anchor_%d" % i,
                      "parent": "ROOT", "location": loc})
    return specs


def build_config(asset, origin=None):
    from ship_parts.assembly import BuildConfig, PivotSpec

    spec = SPECS[asset]
    prefix = spec["prefix"]
    pivots = [PivotSpec(p["key"], p["name"], p["location"],
                        parent=p["parent"]) for p in _pivot_specs(asset)]
    origins = {p["key"]: p.get("origin", p["location"])
               for p in _pivot_specs(asset)}
    pos = origin if origin is not None else WORKBENCH_POS[asset]
    return BuildConfig(
        collection=spec["collection"],
        prefix=prefix,
        root_name=prefix + "Root",
        workbench_pos=pos,
        material_colors=colors_for(asset),
        material_reuse=colors_for(asset),
        root_props={
            "asset": asset,
            "version": "2.0",
            "units": "metres",
            "assembly_spec": "weapon-assembly@2",
            "weapon_class": spec["mount_class"],
            "assembly_profile": spec["pivot_profile"],
            "socket": "SN_Socket_Weapon",
            "mount": "SN_Mount",
            "pivot_yaw": ("SN_Pivot_Yaw" if spec["pivot_profile"] == "yaw_pitch"
                          else ""),
            "pivot_pitch": ("SN_Pivot_Pitch" if spec["pivot_profile"] == "yaw_pitch"
                            else ""),
            "recoil": "SN_Recoil" if spec["pivot_profile"] == "yaw_pitch" else "",
            "muzzle": "SN_Muzzle" if spec["pivot_profile"] == "yaw_pitch" else "",
            "has_yaw": spec["pivot_profile"] == "yaw_pitch",
            "has_pitch": spec["pivot_profile"] == "yaw_pitch",
            "has_recoil": spec["pivot_profile"] == "yaw_pitch",
            "has_muzzle": spec["pivot_profile"] == "yaw_pitch",
            "yaw_axis": "Z",
            "pitch_axis": "Y",
            "recoil_axis": "-X",
            "muzzle_count": 1,
            "pivot": "mount base centre (z=0), +X forward",
            "pivot_profile": spec["pivot_profile"],
            "mount_class": spec["mount_class"],
            "mount_frame": "SN_Mount at base centre z=0",
            "base_footprint_x": float(spec["base_footprint"][0]),
            "base_footprint_y": float(spec["base_footprint"][1]),
            "envelope_x": float(spec["bbox"][0]),
            "envelope_y": float(spec["bbox"][1]),
            "height": float(spec["bbox"][2]),
            "swept_radius": float(spec["swept_radius"]),
            "anchor_count": 4,
            "collection": spec["collection"],
            "type": spec["type"],
            "tri_budget": spec["tri_budget"],
            "bbox_target": "%.2f x %.2f x %.2f m" % spec["bbox"],
        },
        pivots=pivots,
        origins=origins,
        report_title=asset,
        tri_budget=spec["tri_budget"],
        root_size=1.2,
    )


# ---------------------------------------------------------------- Blender 装配

def build_all_weapons():
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
    print("WEAPON_BATCH2_REPORT %r" % {
        "assets": {asset: out[asset]["tris"] for asset in ASSETS},
        "total_tris": sum(v["tris"] for v in out.values()),
    })
    return out


if __name__ == "__main__":
    build_all_weapons()
    report()
