# -*- coding: utf-8 -*-
# @static-doc
# 作用：SN_Wooden_Mast_Crane 木制桅杆起重机（历史港口吊）的参数化生成器。
#
# 工单：`tools/modeling/briefs/sn_crane_batch1.json`（木制桅杆起重机条目）
# 集合：`SN_Wooden_Mast_Crane_Prototype`；根节点 `SN_WM_Root`
# （工作台摆位 (30, 260, 0)）。
# 轴心：地面中心（z = 0），+X 为吊臂伸出方向，+Z 向上，1 unit = 1 m。
# 预算：<= 4000 tri；材质：SN_Wood / SN_Wood_Dark / SN_Wood_Deck / SN_Metal /
#       SN_Stone / SN_Brass / SN_Canvas_Shade。
#
# 结构：石砌台基 + 木梁底盘 + 方形木桅杆（铁箍 + 斜撑）+ 后倾木吊臂（双颊板 +
# 铁箍 + 端部滑轮）+ 桅顶四根后拉索与地锚 + 吊臂俯仰滑车组 + 手摇绞车
# （木卷筒 / 棘轮 / 摇杆）+ 吊钩组 + 桅杆爬梯 + 甲板木料与盘绳。
#
# 用法：
# - Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
# - 纯 Python 干跑：`python tools/modeling/generators/dryrun_cranes.py`
# - 导出 GLB：`python tools/modeling/generators/export_cranes_glb.py`
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

import crane_kit as ck
from ship_parts.core import Part, torus_z


COLLECTION = "SN_Wooden_Mast_Crane_Prototype"
PREFIX = "SN_WM_"
ROOT_NAME = "SN_WM_Root"
WORKBENCH_POS = (30.0, 260.0, 0.0)
TRI_BUDGET = 4000
BBOX_TARGET = (14.77, 7.0, 14.25)
BBOX_TOL = 0.8

MAT_WOOD = "SN_Wood"
MAT_WOOD_DARK = "SN_Wood_Dark"
MAT_WOOD_DECK = "SN_Wood_Deck"
MAT_METAL = "SN_Metal"
MAT_STONE = "SN_Stone"
MAT_BRASS = "SN_Brass"
MAT_ROPE = "SN_Canvas_Shade"

COLORS = {
    MAT_WOOD: ((0.200, 0.088, 0.035), 0.70, 0.00),
    MAT_WOOD_DARK: ((0.042, 0.019, 0.008), 0.64, 0.00),
    MAT_WOOD_DECK: ((0.300, 0.165, 0.072), 0.76, 0.00),
    MAT_METAL: ((0.140, 0.150, 0.170), 0.36, 0.90),
    MAT_STONE: ((0.235, 0.228, 0.208), 0.90, 0.00),
    MAT_BRASS: ((0.420, 0.270, 0.075), 0.28, 0.85),
    MAT_ROPE: ((0.540, 0.500, 0.410), 0.92, 0.00),
}
REUSE_COLORS = dict(COLORS)

DECK_Z = 1.38
MAST_TOP = 14.10
JIB_TIP = (9.00, 0.0, 10.80)
WINCH = (-2.50, 0.0, 2.65)


# ---------------------------------------------------------------- 几何

def _base():
    part = Part()
    ck.add_box(part, (-3.00, -3.00, 0.00), (3.00, 3.00, 0.70), MAT_STONE)
    ck.add_box(part, (-2.65, -2.65, 0.70), (2.65, 2.65, 0.90), MAT_STONE)
    # 四根垫木
    for sx in (-1.0, 1.0):
        ck.add_box(part, (-2.60, sx * 2.20 - 0.20, 0.90),
                   (2.60, sx * 2.20 + 0.20, 1.30), MAT_WOOD_DARK)
        ck.add_box(part, (sx * 2.20 - 0.20, -2.60, 0.90),
                   (sx * 2.20 + 0.20, 2.60, 1.30), MAT_WOOD_DARK)
    return part


def _deck():
    part = Part()
    ck.add_box(part, (-2.40, -2.40, 1.30), (2.40, 2.40, DECK_Z), MAT_WOOD_DECK)
    return part


def _mast():
    part = Part()
    ck.add_box(part, (-0.30, -0.30, DECK_Z), (0.30, 0.30, 14.00), MAT_WOOD)
    ck.add_box(part, (-0.42, -0.42, 14.00), (0.42, 0.42, 14.25), MAT_WOOD_DARK)
    # 铁箍
    for z in (2.20, 3.80, 5.40, 7.00, 8.60, 10.20, 11.80, 13.40):
        ck.add_box(part, (-0.35, -0.35, z - 0.045), (0.35, 0.35, z + 0.045),
                   MAT_METAL)
    # 桅脚四向斜撑
    for sx in (-1.0, 1.0):
        ck.add_bar(part, (sx * 0.32, 0.0, 4.50), (sx * 1.90, 0.0, DECK_Z),
                   0.20, MAT_WOOD)
        ck.add_bar(part, (0.0, sx * 0.32, 4.50), (0.0, sx * 1.90, DECK_Z),
                   0.20, MAT_WOOD)
    return part


def _jib():
    part = Part()
    p0 = (0.35, 0.0, 1.70)
    p1 = JIB_TIP
    ck.add_bar(part, p0, p1, 0.38, MAT_WOOD)
    # 双颊板（低模吊臂的加强侧板）
    for sy in (-0.22, 0.22):
        ck.add_bar(part, (p0[0], sy, p0[2]), (p1[0], sy, p1[2]), 0.20, MAT_WOOD)
    # 铁箍
    for t in (0.25, 0.50, 0.75):
        x = p0[0] + (p1[0] - p0[0]) * t
        z = p0[2] + (p1[2] - p0[2]) * t
        ck.add_box(part, (x - 0.24, -0.30, z - 0.24), (x + 0.24, 0.30, z + 0.24),
                   MAT_METAL)
    # 吊臂根部座
    ck.add_box(part, (0.15, -0.55, 1.40), (1.00, 0.55, 2.20), MAT_WOOD_DARK)
    # 端部滑轮与吊架
    ck.add_box(part, (p1[0] - 0.42, -0.30, p1[2] - 0.36),
               (p1[0] + 0.16, 0.30, p1[2] + 0.20), MAT_WOOD_DARK)
    ck.sheave(part, (p1[0] + 0.02, 0.0, p1[2] - 0.08), (0.0, 1.0, 0.0),
              0.26, 0.12, MAT_METAL)
    return part


def _stays():
    part = Part()
    top = (0.0, 0.0, MAST_TOP - 0.05)
    anchors = [(-5.00, -2.80), (-5.00, 2.80), (-1.20, -3.20), (-1.20, 3.20)]
    for x, y in anchors:
        ck.cable(part, [top, (x, y, 0.95)], 0.045, MAT_METAL, sides=4)
        ck.add_box(part, (x - 0.30, y - 0.30, 0.90), (x + 0.30, y + 0.30, 1.25),
                   MAT_STONE)
    # 桅顶铁箍与吊耳
    ck.add_box(part, (-0.40, -0.40, MAST_TOP - 0.25), (0.40, 0.40, MAST_TOP),
               MAT_METAL)
    for sy in (-0.30, 0.30):
        ck.add_box(part, (-0.50, sy - 0.06, MAST_TOP - 0.30),
                   (0.50, sy + 0.06, MAST_TOP - 0.05), MAT_METAL)
    return part


def _luff_tackle():
    part = Part()
    top = (0.0, 0.0, MAST_TOP - 0.10)
    # 吊臂端到桅顶的双股滑车绳
    ck.cable(part, [top, (JIB_TIP[0] - 0.10, 0.0, JIB_TIP[2] - 0.10)],
             0.040, MAT_ROPE, sides=4)
    ck.cable(part, [(-0.10, 0.0, MAST_TOP - 0.35),
                    (JIB_TIP[0] - 0.34, 0.0, JIB_TIP[2] - 0.26)],
             0.035, MAT_ROPE, sides=4)
    # 桅顶定滑轮
    ck.sheave(part, (0.0, 0.0, MAST_TOP - 0.35), (0.0, 1.0, 0.0),
              0.22, 0.10, MAT_METAL)
    return part


def _winch():
    part = Part()
    # A 字木架
    for sy in (-0.95, 0.95):
        ck.add_bar(part, (-1.40, sy, DECK_Z), (WINCH[0], sy, 3.40), 0.24,
                   MAT_WOOD_DARK)
        ck.add_bar(part, (-3.60, sy, DECK_Z), (WINCH[0], sy, 3.40), 0.24,
                   MAT_WOOD_DARK)
    ck.add_bar(part, (WINCH[0], -1.05, 3.40), (WINCH[0], 1.05, 3.40), 0.24,
               MAT_WOOD_DARK)
    # 卷筒 + 齿轮 + 摇杆
    ck.hand_winch(part, WINCH, (0.0, 1.0, 0.0), 0.50, 1.70, 0.62, 12,
                  MAT_WOOD_DARK, MAT_WOOD, MAT_METAL, crank=True)
    # 第二级传动齿轮
    ck.gear(part, (-2.50, 0.98, WINCH[2] - 0.55), (0.0, 1.0, 0.0),
            0.34, 0.10, 10, MAT_METAL)
    # 卷筒到吊臂滑车的绳索（沿桅杆侧面绕行，避免穿过桅杆）
    ck.cable(part, [(WINCH[0], 0.0, WINCH[2] + 0.55),
                    (0.55, 0.42, 4.20),
                    (0.55, 0.42, 10.00),
                    (JIB_TIP[0] - 0.12, 0.0, JIB_TIP[2] - 0.02)],
             0.035, MAT_ROPE, sides=4)
    return part


def _ladder():
    part = Part()
    ck.ladder(part, (0.40, 0.0, DECK_Z), (0.40, 0.0, 13.60),
              0.45, MAT_WOOD_DARK, step=0.80)
    return part


def _deck_details():
    part = Part()
    # 盘绳
    for x, y in ((1.50, -1.55), (-1.10, 1.55)):
        part.add(torus_z(x, y, DECK_Z + 0.10, 0.42, 0.085, seg=10, tube=4),
                 MAT_ROPE)
    # 木箱
    ck.add_box(part, (1.70, 0.95, DECK_Z), (2.35, 1.60, DECK_Z + 0.65),
               MAT_WOOD)
    ck.add_box(part, (1.20, 1.30, DECK_Z + 0.65), (1.75, 1.55, DECK_Z + 1.05),
               MAT_WOOD)
    # 系缆桩
    ck.add_cyl(part, (1.90, -1.20, DECK_Z), (1.90, -1.20, DECK_Z + 0.55),
               0.12, 0.10, MAT_WOOD_DARK, 6)
    ck.add_bar(part, (1.66, -1.20, DECK_Z + 0.52), (2.14, -1.20, DECK_Z + 0.52),
               0.10, MAT_WOOD_DARK)
    # 甲板小木料堆
    ck.timber_stack(part, -1.10, -1.55, DECK_Z + 0.12, 1.80, 4, 0.11,
                    MAT_WOOD, along="x")
    return part


def _hook():
    part = Part()
    ck.hook_block(part, (JIB_TIP[0], 0.0, 5.00), MAT_METAL, MAT_METAL,
                  rope_mat=MAT_ROPE,
                  rope_top=(JIB_TIP[0], 0.0, JIB_TIP[2] - 0.10))
    return part


def build_all_geometry():
    """返回 {对象名: (Part, 父级键)}；本资产无 Pivot，父级键均为 ROOT。"""
    parts = {}

    def add(name, part):
        parts[name] = (part, "ROOT")

    add(PREFIX + "Base", _base())
    add(PREFIX + "Deck", _deck())
    add(PREFIX + "Mast", _mast())
    add(PREFIX + "Jib", _jib())
    add(PREFIX + "Stays", _stays())
    add(PREFIX + "Luff_Tackle", _luff_tackle())
    add(PREFIX + "Winch", _winch())
    add(PREFIX + "Ladder", _ladder())
    add(PREFIX + "Deck_Details", _deck_details())
    add(PREFIX + "Hook", _hook())
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
            "asset": "SN_Wooden_Mast_Crane",
            "version": "1.0",
            "units": "metres",
            "pivot": "ground centre (stone base centre, z=0)",
            "forward_axis": "+X",
            "collection": COLLECTION,
            "type": "historical wooden mast crane (sheer-legs style)",
            "mast_height_m": MAST_TOP,
            "tri_budget": TRI_BUDGET,
        },
        report_title="SN_Wooden_Mast_Crane",
        tri_budget=TRI_BUDGET,
        root_size=3.0,
    )


def build_all(origin=WORKBENCH_POS):
    """在 Blender 中幂等重建木制桅杆起重机（只清理本前缀对象 / 本集合）。"""
    from ship_parts import assembly
    return assembly.build_collection(build_all_geometry(), build_config(origin))


def report(verbose=True):
    from ship_parts import assembly
    return assembly.report(build_config(), verbose=verbose)


if __name__ == "__main__":
    build_all()
    report()
