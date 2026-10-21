# -*- coding: utf-8 -*-
# @static-doc
# 作用：SN_Hand_Jib_Crane 手摇悬臂吊（码头小型回转吊）的参数化生成器。
#
# 工单：`tools/modeling/briefs/sn_crane_batch1.json`（手摇悬臂吊条目）
# 集合：`SN_Hand_Jib_Crane_Prototype`；根节点 `SN_HJ_Root`
# （工作台摆位 (55, 260, 0)）。
# 轴心：地面中心（z = 0），+X 为悬臂伸出方向，+Z 向上，1 unit = 1 m。
# 预算：<= 1500 tri；材质：SN_Metal / SN_Iron / SN_Wood_Dark / SN_Stone /
#       SN_Brass / SN_Canvas_Shade。
#
# 结构：石砌基座 + 木垫板 + 立柱（铁箍 / 柱帽）+ 收分悬臂 + 拉杆与斜撑 +
# 手摇绞车（卷筒 / 棘轮 / 摇柄）+ 导向滑轮 + 吊钩组 + 立柱踏步。
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


COLLECTION = "SN_Hand_Jib_Crane_Prototype"
PREFIX = "SN_HJ_"
ROOT_NAME = "SN_HJ_Root"
WORKBENCH_POS = (55.0, 260.0, 0.0)
TRI_BUDGET = 1500
BBOX_TARGET = (4.6, 1.7, 5.17)
BBOX_TOL = 0.5

MAT_METAL = "SN_Metal"
MAT_IRON = "SN_Iron"
MAT_WOOD_DARK = "SN_Wood_Dark"
MAT_STONE = "SN_Stone"
MAT_BRASS = "SN_Brass"
MAT_ROPE = "SN_Canvas_Shade"

COLORS = {
    MAT_METAL: ((0.140, 0.150, 0.170), 0.36, 0.90),
    MAT_IRON: ((0.072, 0.076, 0.084), 0.52, 0.62),
    MAT_WOOD_DARK: ((0.042, 0.019, 0.008), 0.64, 0.00),
    MAT_STONE: ((0.235, 0.228, 0.208), 0.90, 0.00),
    MAT_BRASS: ((0.420, 0.270, 0.075), 0.28, 0.85),
    MAT_ROPE: ((0.540, 0.500, 0.410), 0.92, 0.00),
}
REUSE_COLORS = dict(COLORS)

POST_TOP = 4.55
JIB_TIP = (3.30, 0.0, 5.05)
WINCH_Z = 1.85


# ---------------------------------------------------------------- 几何

def _base():
    part = Part()
    ck.add_box(part, (-0.85, -0.85, 0.00), (0.85, 0.85, 0.40), MAT_STONE)
    ck.add_box(part, (-0.70, -0.70, 0.40), (0.70, 0.70, 0.55), MAT_STONE)
    ck.add_box(part, (-0.62, -0.62, 0.55), (0.62, 0.62, 0.65), MAT_WOOD_DARK)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            ck.add_box(part, (sx * 0.55 - 0.07, sy * 0.55 - 0.07, 0.55),
                       (sx * 0.55 + 0.07, sy * 0.55 + 0.07, 0.86), MAT_IRON)
    return part


def _post():
    part = Part()
    ck.add_cyl(part, (0.0, 0.0, 0.65), (0.0, 0.0, POST_TOP),
               0.17, 0.12, MAT_METAL, 8)
    # 柱脚法兰与柱帽
    ck.add_cyl(part, (0.0, 0.0, 0.65), (0.0, 0.0, 0.92), 0.24, 0.24,
               MAT_IRON, 8)
    ck.add_box(part, (-0.18, -0.18, POST_TOP), (0.18, 0.18, POST_TOP + 0.14),
               MAT_BRASS)
    # 中部铁箍
    ck.add_cyl(part, (0.0, 0.0, 3.10), (0.0, 0.0, 3.22), 0.16, 0.16,
               MAT_IRON, 8)
    return part


def _jib():
    part = Part()
    ck.add_cyl(part, (0.0, 0.0, 4.10), JIB_TIP, 0.14, 0.085, MAT_METAL, 6)
    # 悬臂根部座与端部滑轮
    ck.add_box(part, (-0.10, -0.22, 3.95), (0.55, 0.22, 4.35), MAT_IRON)
    ck.add_box(part, (JIB_TIP[0] - 0.26, -0.18, JIB_TIP[2] - 0.22),
               (JIB_TIP[0] + 0.06, 0.18, JIB_TIP[2] + 0.12), MAT_IRON)
    ck.sheave(part, (JIB_TIP[0] - 0.02, 0.0, JIB_TIP[2] - 0.10),
              (0.0, 1.0, 0.0), 0.18, 0.09, MAT_METAL)
    # 拉杆与斜撑
    ck.add_bar(part, (0.0, 0.0, POST_TOP - 0.05), (1.55, 0.0, 4.62), 0.075,
               MAT_METAL)
    ck.add_bar(part, (0.0, 0.0, 2.30), (2.45, 0.0, 4.72), 0.075, MAT_METAL)
    return part


def _winch():
    part = Part()
    ck.hand_winch(part, (0.0, 0.0, WINCH_Z), (0.0, 1.0, 0.0),
                  0.30, 0.85, 0.42, 10, MAT_IRON, MAT_WOOD_DARK, MAT_BRASS,
                  crank=True)
    return part


def _rope():
    part = Part()
    ck.cable(part, [(0.0, 0.0, WINCH_Z + 0.32),
                    (JIB_TIP[0] - 0.02, 0.0, JIB_TIP[2] - 0.10)],
             0.030, MAT_ROPE, sides=4)
    ck.hook_block(part, (JIB_TIP[0] - 0.02, 0.0, 2.60), MAT_METAL, MAT_METAL,
                  rope_mat=MAT_ROPE,
                  rope_top=(JIB_TIP[0] - 0.02, 0.0, JIB_TIP[2] - 0.10))
    return part


def _details():
    part = Part()
    # 立柱踏步
    for i in range(4):
        z = 1.05 + i * 0.55
        ck.add_bar(part, (-0.02, 0.16, z), (0.24, 0.16, z), 0.05, MAT_IRON)
    # 基座铭牌（空白）
    ck.add_box(part, (-0.30, -0.03, 0.58), (0.30, 0.03, 0.62), MAT_BRASS)
    return part


def build_all_geometry():
    """返回 {对象名: (Part, 父级键)}；本资产无 Pivot，父级键均为 ROOT。"""
    parts = {}

    def add(name, part):
        parts[name] = (part, "ROOT")

    add(PREFIX + "Base", _base())
    add(PREFIX + "Post", _post())
    add(PREFIX + "Jib", _jib())
    add(PREFIX + "Winch", _winch())
    add(PREFIX + "Rope_Hook", _rope())
    add(PREFIX + "Details", _details())
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
            "asset": "SN_Hand_Jib_Crane",
            "version": "1.0",
            "units": "metres",
            "pivot": "ground centre (base centre, z=0)",
            "forward_axis": "+X",
            "collection": COLLECTION,
            "type": "hand-cranked jib crane",
            "height_m": 5.1,
            "tri_budget": TRI_BUDGET,
        },
        report_title="SN_Hand_Jib_Crane",
        tri_budget=TRI_BUDGET,
        root_size=1.5,
    )


def build_all(origin=WORKBENCH_POS):
    """在 Blender 中幂等重建手摇悬臂吊（只清理本前缀对象 / 本集合）。"""
    from ship_parts import assembly
    return assembly.build_collection(build_all_geometry(), build_config(origin))


def report(verbose=True):
    from ship_parts import assembly
    return assembly.report(build_config(), verbose=verbose)


if __name__ == "__main__":
    build_all()
    report()
