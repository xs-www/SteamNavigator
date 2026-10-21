# -*- coding: utf-8 -*-
# @static-doc
# 作用：SN_Mega_Gantry 大型龙门吊（巨型钢结构 + 可读复杂传动）的参数化生成器。
#
# 工单：`tools/modeling/briefs/sn_crane_batch1.json`（龙门吊条目）
# 集合：`SN_Mega_Gantry_Prototype`；根节点 `SN_MG_Root`（工作台摆位 (-20, 260, 0)）。
# 轴心：轨道面中心（z = 0），+X 为大车运行方向，+Z 向上，1 unit = 1 m。
# 预算：<= 12000 tri；材质：SN_Metal / SN_Iron / SN_Iron_Red / SN_Wood_Dark /
#       SN_Brass / SN_Stone / SN_Glass_Dark。
#
# 结构：地面轨道 + 4 台带齿轮传动的台车（大车） + 4 条收分格构腿 + 两条顶部
# 格构横梁（顺桥向）+ 40 m 主桁架桥（双弦 + 斜腹杆 + 横框 + 走台栏杆）+
# 桥面上的小车与卷扬机构 + 桥端机械房（双卷筒 / 电机 / 齿轮箱 / 齿轮组 /
# 制动盘 / 排气管） + 双吊钩横担与吊装中的集装箱 + 爬梯 / 平台 / 栏杆。
#
# 用法：
# - Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
# - 纯 Python 干跑：`python tools/modeling/generators/dryrun_cranes.py`
# - 导出 GLB：`python tools/modeling/generators/export_cranes_glb.py`
# @end-static-doc

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

import crane_kit as ck
from ship_parts.core import Part


COLLECTION = "SN_Mega_Gantry_Prototype"
PREFIX = "SN_MG_"
ROOT_NAME = "SN_MG_Root"
WORKBENCH_POS = (-20.0, 260.0, 0.0)
TRI_BUDGET = 12000
BBOX_TARGET = (39.6, 14.8, 29.65)
BBOX_TOL = 1.0

MAT_METAL = "SN_Metal"
MAT_IRON = "SN_Iron"
MAT_RED = "SN_Iron_Red"
MAT_WOOD = "SN_Wood_Dark"
MAT_BRASS = "SN_Brass"
MAT_STONE = "SN_Stone"
MAT_GLASS = "SN_Glass_Dark"

COLORS = {
    MAT_METAL: ((0.140, 0.150, 0.170), 0.36, 0.90),
    MAT_IRON: ((0.072, 0.076, 0.084), 0.52, 0.62),
    MAT_RED: ((0.190, 0.035, 0.022), 0.62, 0.10),
    MAT_WOOD: ((0.042, 0.019, 0.008), 0.64, 0.00),
    MAT_BRASS: ((0.420, 0.270, 0.075), 0.28, 0.85),
    MAT_STONE: ((0.235, 0.228, 0.208), 0.90, 0.00),
    MAT_GLASS: ((0.032, 0.042, 0.052), 0.25, 0.35),
}
REUSE_COLORS = dict(COLORS)

RAIL_Y = 6.0
LEG_X = 18.0
LEG_TOP = 22.6
BRIDGE_Z = 24.20
BRIDGE_HALF_H = 0.90
BRIDGE_HALF_W = 2.60
TROLLEY_X = 6.5
SPREADER_Z = 6.20


# ---------------------------------------------------------------- 几何

def _tracks():
    part = Part()
    for y in (-RAIL_Y, RAIL_Y):
        ck.add_box(part, (-19.50, y - 0.09, 0.08), (19.50, y + 0.09, 0.24),
                   MAT_IRON)
    for i in range(-9, 10):
        x = i * 2.1
        ck.add_box(part, (x - 0.9, -RAIL_Y - 0.55, 0.0),
                   (x + 0.9, RAIL_Y + 0.55, 0.10), MAT_WOOD)
    return part


def _bogie(x, y):
    part = Part()
    for sx in (-0.95, 0.95):
        ck.wheel(part, (x + sx, y, 0.55), (0.0, 1.0, 0.0),
                 0.55, 0.30, MAT_IRON, 10)
    ck.add_box(part, (x - 1.55, y - 0.55, 0.52), (x + 1.55, y + 0.55, 1.32),
               MAT_METAL)
    ck.add_box(part, (x - 1.45, y - 0.70, 1.32), (x + 1.45, y + 0.70, 1.52),
               MAT_METAL)
    # 台车传动：齿轮 + 电机 + 传动轴
    ck.gear(part, (x + 0.95, y + 0.62, 0.95), (0.0, 1.0, 0.0),
            0.34, 0.10, 10, MAT_METAL)
    ck.add_cyl(part, (x - 0.55, y + 0.62, 0.95), (x + 0.45, y + 0.62, 0.95),
               0.17, 0.17, MAT_METAL, 8)
    ck.add_box(part, (x - 0.70, y + 0.40, 0.68), (x - 0.10, y + 0.84, 1.22),
               MAT_RED)
    return part


def _legs():
    chords, rings, braces = Part(), Part(), Part()
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            c0, r0, b0 = ck.column_parts(
                (sx * LEG_X, sy * RAIL_Y, 1.52),
                (sx * LEG_X, sy * RAIL_Y, LEG_TOP),
                1.15, 0.90, 5, MAT_METAL, r_chord=0.11, r_brace=0.055)
            chords.merge(c0)
            rings.merge(r0)
            braces.merge(b0)
    return chords, rings, braces


def _sill_beams():
    chords, lattice, frames = Part(), Part(), Part()
    for sx in (-1.0, 1.0):
        c0, l0, f0 = ck.boom_parts(
            (sx * LEG_X, -RAIL_Y, LEG_TOP), (sx * LEG_X, RAIL_Y, LEG_TOP),
            0.90, 0.55, 3, MAT_METAL, r_chord=0.10, r_brace=0.055, ring_every=1)
        chords.merge(c0)
        lattice.merge(l0)
        frames.merge(f0)
    return chords, lattice, frames


def _bridge_supports():
    part = Part()
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            ck.add_box(part, (sx * LEG_X - 0.55, sy * 1.55 - 0.35, LEG_TOP - 0.30),
                       (sx * LEG_X + 0.55, sy * 1.55 + 0.35, BRIDGE_Z - 0.55),
                       MAT_METAL)
    return part


def _bridge():
    chords, lattice, frames = ck.boom_parts(
        (-19.5, 0.0, BRIDGE_Z), (19.5, 0.0, BRIDGE_Z),
        BRIDGE_HALF_W, BRIDGE_HALF_H, 14, MAT_METAL,
        r_chord=0.12, r_brace=0.060, ring_every=2)
    return chords, lattice, frames


def _walkway():
    part = Part()
    top = BRIDGE_Z + BRIDGE_HALF_H
    ck.add_box(part, (-19.20, -0.85, top), (19.20, 0.85, top + 0.12), MAT_WOOD)
    # 小车行走轨（双轨）
    for y in (-1.10, 1.10):
        ck.add_box(part, (-19.50, y - 0.09, top), (19.50, y + 0.09, top + 0.20),
                   MAT_IRON)
    for y in (-2.60, 2.60):
        ck.railing(part, [(-19.20, y, top), (19.20, y, top)],
                   1.00, MAT_METAL, post_step=3.0)
    return part


def _machinery_house():
    part = Part()
    top = BRIDGE_Z + BRIDGE_HALF_H
    ck.add_box(part, (-15.60, -1.85, top), (-10.40, 1.85, top + 2.60), MAT_METAL)
    ck.add_box(part, (-15.80, -2.00, top + 2.60), (-10.20, 2.00, top + 2.80),
               MAT_IRON)
    # 侧窗与门
    for x in (-14.80, -13.00, -11.20):
        ck.add_box(part, (x - 0.55, 1.84, top + 1.20), (x + 0.55, 1.90, top + 2.10),
                   MAT_GLASS)
    ck.add_box(part, (-14.60, -1.90, top, ), (-13.20, -1.84, top + 1.90),
               MAT_RED)
    # 排气筒 / 通风帽
    ck.add_cyl(part, (-11.00, -0.90, top + 2.80), (-11.00, -0.90, top + 4.30),
               0.22, 0.22, MAT_IRON, 8)
    ck.add_cyl(part, (-11.00, -0.90, top + 4.30), (-11.00, -0.90, top + 4.55),
               0.30, 0.30, MAT_RED, 8)
    ck.add_box(part, (-15.00, -1.40, top + 2.80), (-14.20, -0.60, top + 3.20),
               MAT_IRON)
    # 铭牌（空白）
    ck.add_box(part, (-15.30, 1.84, top + 0.55), (-14.40, 1.90, top + 1.05),
               MAT_BRASS)
    return part


def _hoist_winches():
    part = Part()
    top = BRIDGE_Z + BRIDGE_HALF_H
    base_z = top + 0.55
    for x in (-14.20, -12.30):
        ck.drum(part, (x, -2.65, base_z), (0.0, 1.0, 0.0),
                0.52, 1.40, MAT_WOOD, 10)
        ck.gear(part, (x, -3.48, base_z), (0.0, 1.0, 0.0),
                0.44, 0.10, 12, MAT_METAL)
        ck.add_cyl(part, (x, -3.48, base_z), (x, -2.65, base_z),
                   0.10, 0.10, MAT_METAL, 6)
        # 电机（沿 X 挂在机械房外侧）
        ck.add_cyl(part, (x - 1.55, -2.65, base_z), (x - 0.95, -2.65, base_z),
                   0.24, 0.24, MAT_IRON, 8)
        ck.add_box(part, (x - 1.70, -2.95, base_z - 0.32),
                   (x - 1.40, -2.35, base_z + 0.32), MAT_RED)
        # 轴承座
        ck.add_box(part, (x - 0.28, -3.78, base_z - 0.55),
                   (x + 0.28, -3.18, base_z - 0.25), MAT_METAL)
        # 制动盘（卷筒另一端）
        ck.drum(part, (x, -1.90, base_z), (0.0, 1.0, 0.0),
                0.30, 0.10, MAT_IRON, 10, flanges=False)
    # 中间传动轴 + 换向齿轮
    ck.add_cyl(part, (-14.20, -3.48, base_z), (-12.30, -3.48, base_z),
               0.09, 0.09, MAT_METAL, 6)
    ck.gear(part, (-13.25, -3.48, base_z), (0.0, 1.0, 0.0),
            0.58, 0.12, 14, MAT_METAL)
    return part


def _trolley():
    part = Part()
    top = BRIDGE_Z + BRIDGE_HALF_H
    ck.add_box(part, (TROLLEY_X - 1.90, -1.10, top), (TROLLEY_X + 1.90, 1.10,
                                                      top + 1.05), MAT_METAL)
    ck.add_box(part, (TROLLEY_X - 1.60, -1.40, top + 1.05),
               (TROLLEY_X + 1.60, 1.40, top + 1.30), MAT_WOOD)
    for sx in (-1.3, 1.3):
        for sy in (-1.0, 1.0):
            ck.wheel(part, (TROLLEY_X + sx, sy * 1.10, top + 0.20),
                     (0.0, 1.0, 0.0), 0.22, 0.14, MAT_METAL, 8)
    # 小车卷筒 + 电机
    ck.drum(part, (TROLLEY_X - 0.75, 0.0, top + 0.65), (1.0, 0.0, 0.0),
            0.34, 1.20, MAT_WOOD, 10)
    ck.add_cyl(part, (TROLLEY_X + 0.55, 0.0, top + 0.65),
               (TROLLEY_X + 1.15, 0.0, top + 0.65), 0.22, 0.22, MAT_IRON, 8)
    ck.gear(part, (TROLLEY_X - 0.75, 0.62, top + 0.65), (0.0, 1.0, 0.0),
            0.40, 0.10, 12, MAT_METAL)
    # 吊绳滑轮
    for sy in (-0.55, 0.55):
        ck.sheave(part, (TROLLEY_X, sy, top - 0.06), (0.0, 1.0, 0.0),
                  0.24, 0.10, MAT_METAL)
    return part


def _hoist_cables():
    part = Part()
    top = BRIDGE_Z + BRIDGE_HALF_H
    for sy in (-1.0, 1.0):
        ck.cable(part, [(TROLLEY_X, sy * 0.55, top - 0.20),
                        (TROLLEY_X + sy * 3.2, sy * 1.6, SPREADER_Z + 0.55)],
                 0.035, MAT_METAL)
    return part


def _spreader():
    part = Part()
    ck.add_box(part, (TROLLEY_X - 3.90, -0.62, SPREADER_Z),
               (TROLLEY_X + 3.90, 0.62, SPREADER_Z + 0.60), MAT_RED)
    for sx in (-3.60, 3.60):
        ck.add_box(part, (TROLLEY_X + sx - 0.45, -0.75, SPREADER_Z + 0.60),
                   (TROLLEY_X + sx + 0.45, 0.75, SPREADER_Z + 0.85), MAT_METAL)
    # 横担下的两只吊钩
    for sx in (-2.90, 2.90):
        ck.hook_block(part, (TROLLEY_X + sx, 0.0, SPREADER_Z),
                      MAT_METAL, MAT_METAL, rope_top=None)
    # 吊装中的集装箱
    ck.add_box(part, (TROLLEY_X - 3.05, -1.22, 2.60),
               (TROLLEY_X + 3.05, 1.22, 5.20), MAT_RED)
    for x in (TROLLEY_X - 3.05, TROLLEY_X + 3.05):
        for y in (-1.22, 1.22):
            ck.add_box(part, (x - 0.06, y - 0.06, 2.60), (x + 0.06, y + 0.06, 5.20),
                       MAT_IRON)
    return part


def _ladders_platforms():
    part = Part()
    # 两条腿上的爬梯
    for sx in (-1.0, 1.0):
        ck.ladder(part, (sx * (LEG_X + 1.70), RAIL_Y + 1.10, 1.52),
                  (sx * (LEG_X + 1.70), RAIL_Y + 1.10, LEG_TOP - 0.30),
                  0.48, MAT_METAL, step=1.10)
    # 顶部检修平台 + 栏杆（前后两条腿）
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            ck.platform(part, sx * LEG_X, sy * RAIL_Y, LEG_TOP,
                        2.80, 2.80, 0.16, MAT_WOOD)
    for sx in (-1.0, 1.0):
        y = RAIL_Y + 1.35
        ck.railing(part, [(sx * LEG_X - 1.35, y, LEG_TOP + 0.16),
                          (sx * LEG_X + 1.35, y, LEG_TOP + 0.16)],
                   0.95, MAT_METAL, post_step=1.35)
    # 机械房侧小爬梯
    top = BRIDGE_Z + BRIDGE_HALF_H
    ck.ladder(part, (-10.55, 1.95, top), (-10.55, 1.95, top + 2.55),
              0.45, MAT_METAL, step=0.64)
    return part


def build_all_geometry():
    """返回 {对象名: (Part, 父级键)}；本资产无 Pivot，所有父级键均为 ROOT。"""
    parts = {}

    def add(name, part):
        parts[name] = (part, "ROOT")

    add(PREFIX + "Tracks", _tracks())

    bogies = Part()
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            bogies.merge(_bogie(sx * LEG_X, sy * RAIL_Y))
    add(PREFIX + "Bogies", bogies)

    chords, rings, braces = _legs()
    add(PREFIX + "Legs_Chords", chords)
    add(PREFIX + "Legs_Rings", rings)
    add(PREFIX + "Legs_Braces", braces)

    chords, lattice, frames = _sill_beams()
    add(PREFIX + "Sill_Chords", chords)
    add(PREFIX + "Sill_Lattice", lattice)
    add(PREFIX + "Sill_Frames", frames)
    add(PREFIX + "Bridge_Supports", _bridge_supports())

    chords, lattice, frames = _bridge()
    add(PREFIX + "Bridge_Chords", chords)
    add(PREFIX + "Bridge_Lattice", lattice)
    add(PREFIX + "Bridge_Frames", frames)
    add(PREFIX + "Walkway", _walkway())

    add(PREFIX + "Machinery_House", _machinery_house())
    add(PREFIX + "Hoist_Winches", _hoist_winches())
    add(PREFIX + "Trolley", _trolley())
    add(PREFIX + "Hoist_Cables", _hoist_cables())
    add(PREFIX + "Spreader_Load", _spreader())
    add(PREFIX + "Ladders_Platforms", _ladders_platforms())
    return parts


# ---------------------------------------------------------------- Blender 装配

def build_config(origin=WORKBENCH_POS):
    from ship_parts.assembly import BuildConfig
    return BuildConfig(
        collection=COLLECTION,
        prefix=PREFIX,
        root_name=ROOT_NAME,
        workbench_pos=origin,
        material_colors=COLORS,
        material_reuse=REUSE_COLORS,
        root_props={
            "asset": "SN_Mega_Gantry",
            "version": "1.0",
            "units": "metres",
            "pivot": "rail plane, centre of span (z=0)",
            "forward_axis": "+X",
            "collection": COLLECTION,
            "type": "mega gantry crane (double girder, travelling trolley)",
            "span_m": LEG_X * 2.0,
            "height_m": 29.3,
            "tri_budget": TRI_BUDGET,
        },
        report_title="SN_Mega_Gantry",
        tri_budget=TRI_BUDGET,
        root_size=5.0,
    )


def build_all(origin=WORKBENCH_POS):
    """在 Blender 中幂等重建龙门吊（只清理本前缀对象 / 本集合）。"""
    from ship_parts import assembly
    return assembly.build_collection(build_all_geometry(), build_config(origin))


def report(verbose=True):
    from ship_parts import assembly
    return assembly.report(build_config(), verbose=verbose)


if __name__ == "__main__":
    build_all()
    report()
