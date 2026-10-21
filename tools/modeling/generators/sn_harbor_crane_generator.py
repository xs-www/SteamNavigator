# -*- coding: utf-8 -*-
# @static-doc
# 作用：SN_Harbor_Crane 锤头式塔吊的参数化生成器（补全此前缺失的几何真源）。
#
# 工单：`tools/modeling/briefs/sn_crane_batch1.json`（塔吊条目）
# 集合：`SN_Harbor_Crane_Prototype`；根节点 `SN_Crane_Root`（工作台摆位 (0, 16, 0)）；
# 回转 Pivot `SN_Crane_Slew_Pivot`（根局部 z = 17.3）。
# 轴心：底面中心（z = 0），+X 为吊臂前方，+Z 向上，1 unit = 1 m。
# 预算：<= 4000 tri；材质：SN_Metal / SN_Wood / SN_Wood_Dark / SN_Stone。
#
# 结构：石砌基座 + 收分格构塔身（4 弦 + 横框 + 斜撑 + 爬梯）+ 回转环 / 平台
# + 20 m 水平桁架主臂 + 6 m 配重臂 + 3 块石配重 + A 字塔头与拉杆 + 司机室
# + 主副卷扬机组（卷筒 / 电机 / 齿轮 / 制动盘）+ 小车 + 吊钩组。
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


COLLECTION = "SN_Harbor_Crane_Prototype"
PREFIX = "SN_Crane_"
ROOT_NAME = "SN_Crane_Root"
WORKBENCH_POS = (0.0, 16.0, 0.0)
TRI_BUDGET = 4000
BBOX_TARGET = (26.5, 6.3, 21.47)     # 长度 / 宽度 / 高度（含主臂 / 塔头）
BBOX_TOL = 0.8

MAT_METAL = "SN_Metal"
MAT_WOOD = "SN_Wood"
MAT_WOOD_DARK = "SN_Wood_Dark"
MAT_STONE = "SN_Stone"

COLORS = {
    MAT_METAL: ((0.140, 0.150, 0.170), 0.36, 0.90),
    MAT_WOOD: ((0.200, 0.088, 0.035), 0.70, 0.00),
    MAT_WOOD_DARK: ((0.042, 0.019, 0.008), 0.64, 0.00),
    MAT_STONE: ((0.235, 0.228, 0.208), 0.90, 0.00),
}
REUSE_COLORS = dict(COLORS)

# 关键标高（根局部）
BASE_TOP = 1.2
TOWER_TOP = 17.0
PIVOT_Z = 17.3
JIB_Z = 18.20
APEX_Z = 21.30


# ---------------------------------------------------------------- 几何

def _base():
    part = Part()
    ck.add_box(part, (-3.0, -3.0, 0.0), (3.0, 3.0, BASE_TOP), MAT_STONE)
    return part


def _base_courses():
    part = Part()
    ck.add_box(part, (-2.96, -2.96, 0.55), (2.96, 2.96, 0.95), MAT_STONE)
    ck.add_box(part, (-2.72, -2.72, 0.95), (2.72, 2.72, 1.28), MAT_STONE)
    return part


def _base_plates():
    part = Part()
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            ck.add_box(part, (sx * 2.55 - 0.36, sy * 2.55 - 0.36, 0.44),
                       (sx * 2.55 + 0.36, sy * 2.55 + 0.36, 1.18), MAT_METAL)
    return part


def _base_quoins():
    part = Part()
    for sx in (-1.0, 1.0):
        ck.add_box(part, (sx * 2.55, -0.45, 0.36), (sx * 2.99, 0.45, 1.08),
                   MAT_STONE)
        ck.add_box(part, (-0.45, sx * 2.55, 0.36), (0.45, sx * 2.99, 1.08),
                   MAT_STONE)
    return part


def _tower_parts():
    corners = ((-1.32, -1.32), (1.32, -1.32), (1.32, 1.32), (-1.32, 1.32))
    chords, rings, braces = Part(), Part(), Part()
    for x, y in corners:
        ck.add_cyl(chords, (x, y, BASE_TOP), (x, y, TOWER_TOP), 0.10, 0.10,
                   MAT_METAL, 4)
    levels = 6
    for k in range(levels + 1):
        z = BASE_TOP + (TOWER_TOP - BASE_TOP) * k / levels
        pts = [(x, y, z) for x, y in corners]
        for i in range(4):
            ck.add_bar(rings, pts[i], pts[(i + 1) % 4], 0.09, MAT_METAL)
    for k in range(levels):
        z0 = BASE_TOP + (TOWER_TOP - BASE_TOP) * k / levels
        z1 = BASE_TOP + (TOWER_TOP - BASE_TOP) * (k + 1) / levels
        lo = [(x, y, z0) for x, y in corners]
        hi = [(x, y, z1) for x, y in corners]
        for i in range(4):
            j = (i + 1) % 4
            ck.add_bar(braces, lo[i], hi[j], 0.07, MAT_METAL)
    return chords, rings, braces


def _tower_ladder():
    part = Part()
    ck.ladder(part, (0.0, -1.07, 1.20), (0.0, -1.07, 15.60),
              0.45, MAT_METAL, step=0.90)
    return part


def _slew_ring():
    part = Part()
    ck.add_cyl(part, (0.0, 0.0, 16.85), (0.0, 0.0, PIVOT_Z), 1.50, 1.50,
               MAT_METAL, 12)
    return part


def _slew_platform():
    part = Part()
    ck.add_box(part, (-1.60, -1.60, PIVOT_Z), (1.60, 1.60, 17.60),
               MAT_WOOD_DARK)
    return part


def _jib_parts():
    chords, lattice, frames = ck.boom_parts(
        (0.0, 0.0, JIB_Z), (20.1, 0.0, JIB_Z), 0.85, 0.67, 13, MAT_METAL,
        r_chord=0.085, r_brace=0.050, ring_every=3)
    return chords, lattice, frames


def _jib_root():
    part = Part()
    ck.add_box(part, (0.0, -0.88, JIB_Z - 0.67), (0.60, 0.88, JIB_Z + 0.67),
               MAT_METAL)
    return part


def _jib_tip():
    part = Part()
    ck.add_box(part, (20.0, -0.40, JIB_Z - 0.36), (20.20, 0.40, JIB_Z + 0.36),
               MAT_METAL)
    return part


def _counterjib_parts():
    chords, lattice, frames = ck.boom_parts(
        (0.0, 0.0, JIB_Z), (-6.0, 0.0, JIB_Z), 0.85, 0.67, 4, MAT_METAL,
        r_chord=0.085, r_brace=0.050, ring_every=1)
    return chords, lattice, frames


def _counterjib_end():
    part = Part()
    ck.add_box(part, (-6.30, -0.88, JIB_Z - 0.62), (-5.85, 0.88, JIB_Z + 0.68),
               MAT_METAL)
    return part


def _counterjib_platform():
    part = Part()
    ck.add_box(part, (-5.60, -0.62, JIB_Z + 0.60), (-1.00, 0.62, JIB_Z + 0.72),
               MAT_WOOD_DARK)
    return part


def _counterweights():
    part = Part()
    for x in (-5.80, -5.40, -5.00):
        ck.add_box(part, (x - 0.18, -1.30, 15.30), (x + 0.18, 1.30, 16.90),
                   MAT_STONE)
        ck.add_bar(part, (x, -1.05, JIB_Z - 0.67), (x, -1.05, 16.90), 0.09,
                   MAT_METAL)
        ck.add_bar(part, (x, 1.05, JIB_Z - 0.67), (x, 1.05, 16.90), 0.09,
                   MAT_METAL)
    return part


def _head_aframe():
    part = Part()
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            ck.add_bar(part, (sx * 0.85, sy * 0.95, JIB_Z + 0.67),
                       (0.0, 0.0, APEX_Z), 0.16, MAT_METAL)
    return part


def _head_apex():
    part = Part()
    ck.add_box(part, (-0.20, -0.20, APEX_Z), (0.20, 0.20, APEX_Z + 0.17),
               MAT_METAL)
    return part


def _tie_rods():
    part = Part()
    top = (0.0, 0.0, APEX_Z - 0.02)
    for x in (7.6, 16.0):
        for sy in (-0.85, 0.85):
            ck.add_cyl(part, top, (x, sy, JIB_Z + 0.67), 0.045, 0.045,
                       MAT_METAL, 4)
    for sy in (-0.55, 0.55):
        ck.add_cyl(part, top, (-5.0, sy, JIB_Z + 0.67), 0.045, 0.045,
                   MAT_METAL, 4)
    return part


def _cab():
    part = Part()
    ck.add_box(part, (1.55, 1.00, 17.00), (3.55, 3.20, 19.40), MAT_WOOD)
    return part


def _cab_roof():
    part = Part()
    ck.add_box(part, (1.45, 0.90, 19.40), (3.65, 3.30, 19.56), MAT_METAL)
    return part


def _hoist_drum():
    part = Part()
    ck.drum(part, (-2.60, 0.0, 19.20), (0.0, 1.0, 0.0),
            0.45, 1.50, MAT_WOOD_DARK, 10)
    return part


def _hoist_drive():
    part = Part()
    # 电机 + 联轴器
    ck.add_cyl(part, (-3.40, 1.15, 19.20), (-3.40, 2.15, 19.20),
               0.32, 0.32, MAT_METAL, 8)
    ck.add_box(part, (-3.70, 1.00, 18.90), (-3.10, 1.25, 19.50), MAT_METAL)
    # 齿轮箱
    ck.add_box(part, (-4.00, 0.20, 18.72), (-3.05, 1.15, 19.62), MAT_METAL)
    # 齿轮组
    ck.gear(part, (-3.55, 0.20, 19.20), (0.0, 1.0, 0.0), 0.42, 0.10, 12,
            MAT_METAL)
    ck.gear(part, (-3.00, 0.55, 19.20), (0.0, 1.0, 0.0), 0.26, 0.10, 10,
            MAT_METAL)
    # 制动盘
    ck.drum(part, (-2.60, -0.95, 19.20), (0.0, 1.0, 0.0), 0.28, 0.10,
            MAT_METAL, 10, flanges=False)
    # 传动轴
    ck.add_cyl(part, (-3.55, -0.90, 19.20), (-2.60, -0.90, 19.20),
               0.055, 0.055, MAT_METAL, 6)
    return part


def _trolley():
    part = Part()
    ck.add_box(part, (11.40, -0.88, 17.60), (12.60, 0.88, 18.25), MAT_METAL)
    for sx in (-0.45, 0.45):
        for sy in (-1.0, 1.0):
            ck.wheel(part, (12.0 + sx, sy * 1.02, 18.05),
                     (0.0, 1.0, 0.0), 0.12, 0.08, MAT_METAL, 6)
    ck.sheave(part, (12.0, 0.0, 17.62), (0.0, 1.0, 0.0), 0.20, 0.10,
              MAT_METAL)
    return part


def _hook_rope():
    part = Part()
    ck.cable(part, [(12.0, 0.0, 17.55), (12.0, 0.0, 5.45)], 0.035, MAT_METAL)
    return part


def _hook_block():
    part = Part()
    ck.hook_block(part, (12.0, 0.0, 5.45), MAT_METAL, MAT_METAL)
    return part


def build_all_geometry():
    """返回 {对象名: (Part, 父级键)}；父级键 = ROOT / SLEW。"""
    parts = {}

    def add(name, part, parent="ROOT"):
        parts[name] = (part, parent)

    add(PREFIX + "Base", _base())
    add(PREFIX + "Base_Courses", _base_courses())
    add(PREFIX + "Base_Plates", _base_plates())
    add(PREFIX + "Base_Quoins", _base_quoins())

    chords, rings, braces = _tower_parts()
    add(PREFIX + "Tower_Posts", chords)
    add(PREFIX + "Tower_Rings", rings)
    add(PREFIX + "Tower_Braces", braces)
    add(PREFIX + "Tower_Ladder", _tower_ladder())

    add(PREFIX + "Slew_Ring", _slew_ring())
    add(PREFIX + "Slew_Platform", _slew_platform())

    chords, lattice, frames = _jib_parts()
    add(PREFIX + "Jib_Chords", chords, "SLEW")
    add(PREFIX + "Jib_Lattice", lattice, "SLEW")
    add(PREFIX + "Jib_Verticals", frames, "SLEW")
    add(PREFIX + "Jib_Root", _jib_root(), "SLEW")
    add(PREFIX + "Jib_Tip", _jib_tip(), "SLEW")

    chords, lattice, frames = _counterjib_parts()
    add(PREFIX + "Counterjib_Chords", chords, "SLEW")
    add(PREFIX + "Counterjib_Lattice", lattice, "SLEW")
    add(PREFIX + "Counterjib_Verticals", frames, "SLEW")
    add(PREFIX + "Counterjib_End", _counterjib_end(), "SLEW")
    add(PREFIX + "Counterjib_Platform", _counterjib_platform(), "SLEW")
    add(PREFIX + "Counterweights", _counterweights(), "SLEW")

    add(PREFIX + "Head_Aframe", _head_aframe(), "SLEW")
    add(PREFIX + "Head_Apex", _head_apex(), "SLEW")
    add(PREFIX + "Tie_Rods", _tie_rods(), "SLEW")
    add(PREFIX + "Cab", _cab(), "SLEW")
    add(PREFIX + "Cab_Roof", _cab_roof(), "SLEW")
    add(PREFIX + "Hoist_Drum", _hoist_drum(), "SLEW")
    add(PREFIX + "Hoist_Drive", _hoist_drive(), "SLEW")
    add(PREFIX + "Trolley", _trolley(), "SLEW")
    add(PREFIX + "Hook_Rope", _hook_rope(), "SLEW")
    add(PREFIX + "Hook_Block", _hook_block(), "SLEW")
    return parts


# ---------------------------------------------------------------- Blender 装配

def build_config(origin=WORKBENCH_POS):
    from ship_parts.assembly import BuildConfig, PivotSpec
    return BuildConfig(
        collection=COLLECTION,
        prefix=PREFIX,
        root_name=ROOT_NAME,
        workbench_pos=origin,
        material_colors=COLORS,
        material_reuse=REUSE_COLORS,
        root_props={
            "asset": "SN_Harbor_Crane",
            "version": "2.1",
            "units": "metres",
            "pivot": "ground centre (base centre, z=0)",
            "forward_axis": "+X",
            "collection": COLLECTION,
            "type": "hammerhead tower crane",
            "jib_reach_m": 20.1,
            "height_m": APEX_Z + 0.17,
            "tri_budget": TRI_BUDGET,
        },
        pivots=[
            PivotSpec("SLEW", PREFIX + "Slew_Pivot", (0.0, 0.0, PIVOT_Z),
                      size=1.4),
        ],
        origins={"ROOT": (0.0, 0.0, 0.0), "SLEW": (0.0, 0.0, PIVOT_Z)},
        report_title="SN_Harbor_Crane",
        tri_budget=TRI_BUDGET,
        root_size=3.0,
    )


def build_all(origin=WORKBENCH_POS):
    """在 Blender 中幂等重建塔吊（只清理本前缀对象 / 本集合）。"""
    from ship_parts import assembly
    return assembly.build_collection(build_all_geometry(), build_config(origin))


def report(verbose=True):
    from ship_parts import assembly
    return assembly.report(build_config(), verbose=verbose)


if __name__ == "__main__":
    build_all()
    report()
