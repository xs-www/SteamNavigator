# -*- coding: utf-8 -*-
# @static-doc
# 作用：M0-4 `rig_kit` 船体帆索部件库的**独立套件生成器**（12 件 `SN_Rig_*`）与
# Blender 装配入口。几何全部来自 `rig_kit.py` 的同一份部件函数（与 3 艘船共源），
# 本文件只提供「套件布局」：每件资产的尺寸参数、材质白名单、Root datum、
# `SN_Mount` / `SN_Socket_Mast|Yard|Sail` 接口点与 Root extras。
#
# 套件清单：
#   SN_Rig_Mast_Sail（帆船桅杆，含桅顶平台/横担/帆箍）
#   SN_Rig_Mast_Steam（蒸汽船桅杆）
#   SN_Rig_Yard（横桁 + 收帆卷）
#   SN_Rig_Gaff（斜桁） / SN_Rig_Boom（帆杠）
#   SN_Rig_Bowsprit（艏斜桁）
#   SN_Rig_Sail_Gaff / SN_Rig_Sail_Square / SN_Rig_Sail_Jib（三种帆面）
#   SN_Rig_Shrouds（侧支索绳梯） / SN_Rig_Stays（前后支索） / SN_Rig_Running（动索）
#
# 契约：`docs/design/RIG_KIT_CONTRACT.md`；工单 `tools/modeling/briefs/sn_rig_kit_batch1.json`。
# 约定：1 unit = 1 m；+X 前向、+Z 向上；材质只用共享贴图 `SN_Tex_*`。
# GLB 导出后由 `glb_rig_kit.standardize()` 把带前缀的接口节点归一化为
# `SN_Mount` / `SN_Socket_*`，并把 socket 名单写进 Root extras（Blender IDProperty
# 不支持字符串数组）。
#
# 用法：
# - Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
# - 纯 Python 干跑：`python tools/modeling/generators/dryrun_rig_kit.py`
# - 导出 GLB：`runpy.run_path(export_rig_kit_glb.py)`
# @end-static-doc

import os
import sys


def _generator_dir():
    candidates = []
    here = globals().get("__file__")
    if here:
        candidates.append(os.path.dirname(os.path.abspath(here)))
    try:
        import bpy
        fp = getattr(bpy.data, "filepath", "") if getattr(bpy, "data", None) else ""
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

import rig_kit  # noqa: E402
from ship_parts.core import Part  # noqa: E402
from sn_rig_materials import ASSET_MATERIALS, colors_for  # noqa: E402


ASSETS = [
    "SN_Rig_Mast_Sail",
    "SN_Rig_Mast_Steam",
    "SN_Rig_Yard",
    "SN_Rig_Gaff",
    "SN_Rig_Boom",
    "SN_Rig_Bowsprit",
    "SN_Rig_Sail_Gaff",
    "SN_Rig_Sail_Square",
    "SN_Rig_Sail_Jib",
    "SN_Rig_Shrouds",
    "SN_Rig_Stays",
    "SN_Rig_Running",
]

# 工作台摆位：接在 kit 批次 3 的 y=543 之后，避免与既有集合重叠
WORKBENCH_POS = {
    "SN_Rig_Mast_Sail": (0.0, 566.0, 0.0),
    "SN_Rig_Mast_Steam": (6.0, 566.0, 0.0),
    "SN_Rig_Yard": (12.0, 566.0, 0.0),
    "SN_Rig_Gaff": (-3.0, 590.0, 0.0),
    "SN_Rig_Boom": (4.0, 590.0, 0.0),
    "SN_Rig_Bowsprit": (12.0, 590.0, 0.0),
    "SN_Rig_Sail_Gaff": (-3.0, 604.0, 0.0),
    "SN_Rig_Sail_Square": (6.0, 604.0, 0.0),
    "SN_Rig_Sail_Jib": (14.0, 604.0, 0.0),
    "SN_Rig_Shrouds": (0.0, 618.0, 0.0),
    "SN_Rig_Stays": (8.0, 618.0, 0.0),
    "SN_Rig_Running": (16.0, 618.0, 0.0),
}

# 桅杆 / 帆 / 桁参数（与 3 艘船共用同一套 rig_kit 函数，仅数值不同）
MAST_SAIL = dict(lower=10.8, top=17.0, gallant=21.3,
                 r_lower=(0.375, 0.245), r_top=(0.220, 0.122),
                 r_gal=(0.095, 0.040))
MAST_STEAM = dict(x=0.0, z0=0.0, z_low=9.4, z_top=11.0)
YARD = dict(x=-0.30, yard_z=0.0, yard_w=6.8, sail_w=5.6)
GAFF = dict(heel=(0.0, 0.0, 0.0), peak=(5.2, 0.0, 1.9), r0=0.085, r1=0.058)
BOOM = dict(tack=(0.0, 0.0, 0.0), clew=(6.0, 0.0, -0.35), r0=0.100, r1=0.065)
BOWSPRIT = dict(x0=0.0, z0=1.05, x1=4.4, z1=2.55, r0=0.26, r1=0.10,
                gammon_lo=(0.0, -0.26, 0.75), gammon_hi=(0.42, 0.26, 1.35))
SAIL_GAFF = dict(tack=(0.0, 0.0, 0.0), throat=(0.0, 0.0, 5.8),
                 peak=(-5.8, 0.0, 8.2), clew=(-5.2, 0.0, 0.7),
                 camber=0.60, roach=0.40)
SAIL_SQUARE = dict(x_base=0.0, z_head=5.6, z_foot=0.0, half_head=3.0,
                   half_foot=2.6, camber=0.60)
SAIL_JIB = dict(head=(0.0, 0.0, 7.2), tack=(0.0, 0.0, 0.0),
                clew=(5.0, 0.0, 1.2), camber=0.50, roach=0.30)
SHROUD = dict(top=(0.0, 0.0, 7.2), side_y=1.2, anchors_x=(-1.2, -0.4, 0.4, 1.2),
              rows=9)
STAYS = dict(top=(0.0, 0.0, 7.2),
             lines=(((4.6, 0.0, 0.6), 0.034), ((3.2, 0.0, 0.7), 0.030),
                    ((-4.2, 1.4, 0.5), 0.026), ((-4.2, -1.4, 0.5), 0.026)))
RUNNING = dict(top=(0.0, 0.0, 7.2),
               lines=(((0.0, 0.0, 7.2), (0.0, 0.0, 0.0), 0.026),
                      ((0.0, 0.0, 7.2), (-5.0, 0.0, 6.4), 0.024),
                      ((0.0, 0.0, 7.2), (-4.6, 0.0, 4.2), 0.022),
                      ((0.0, 3.4, 4.4), (-1.2, 1.6, 0.6), 0.022),
                      ((0.0, -3.4, 4.4), (-1.2, -1.6, 0.6), 0.022)))

# 套件规格：bbox / tri 预算 / datum / 是否闭合 / 接口点
# bbox 是纯几何世界尺寸（x,y,z）；zmin/zmax 是装配基准检查（米，含容差）
SPECS = {
    "SN_Rig_Mast_Sail": dict(
        collection="SN_Rig_Mast_Sail_Prototype", prefix="SN_Rig_Mast_Sail_",
        role="mast_sail", type="sail-plan mast assembly",
        tri_budget=700, bbox=(1.87, 2.90, 21.50), tol=0.10,
        z_range=(0.0, 21.50), closed=True,
        datum="deck base at z=0; +Z mast up",
        base_footprint=(0.62, 0.62), footprint_kind="deck_pad",
        extra={"mast_class": "Sail", "rig_spec": "rig-kit@1",
               "mast_height": 21.30}),
    "SN_Rig_Mast_Steam": dict(
        collection="SN_Rig_Mast_Steam_Prototype", prefix="SN_Rig_Mast_Steam_",
        role="mast_steam", type="steam-plan mast assembly",
        tri_budget=300, bbox=(0.72, 0.72, 11.18), tol=0.10,
        z_range=(0.0, 11.18), closed=True,
        datum="deck base at z=0; +Z mast up",
        base_footprint=(0.72, 0.60), footprint_kind="deck_pad",
        extra={"mast_class": "Steam", "rig_spec": "rig-kit@1",
               "mast_height": 11.00}),
    "SN_Rig_Yard": dict(
        collection="SN_Rig_Yard_Prototype", prefix="SN_Rig_Yard_",
        role="yard", type="square yard with furled sail",
        tri_budget=300, bbox=(0.48, 6.94, 0.48), tol=0.10,
        z_range=(-0.33, 0.15), closed=True,
        datum="yard centre at (0,0,0); spar along Y",
        base_footprint=(0.0, 0.0), footprint_kind="none",
        extra={"rig_spec": "rig-kit@1", "yard_length": 6.80,
               "sail_area_m2": 0.0, "stowed": True}),
    "SN_Rig_Gaff": dict(
        collection="SN_Rig_Gaff_Prototype", prefix="SN_Rig_Gaff_",
        role="gaff", type="gaff spar with jaws and brass bands",
        tri_budget=250, bbox=(5.46, 0.50, 2.06), tol=0.08,
        z_range=(-0.11, 1.947), closed=True,
        datum="heel/jaws at origin; peak toward +X",
        base_footprint=(0.0, 0.0), footprint_kind="none",
        extra={"rig_spec": "rig-kit@1", "spar_length": 5.54}),
    "SN_Rig_Boom": dict(
        collection="SN_Rig_Boom_Prototype", prefix="SN_Rig_Boom_",
        role="boom", type="boom spar with jaws and brass bands",
        tri_budget=250, bbox=(6.24, 0.50, 0.52), tol=0.08,
        z_range=(-0.406, 0.11), closed=True,
        datum="tack/jaws at origin; clew toward +X",
        base_footprint=(0.0, 0.0), footprint_kind="none",
        extra={"rig_spec": "rig-kit@1", "spar_length": 6.01}),
    "SN_Rig_Bowsprit": dict(
        collection="SN_Rig_Bowsprit_Prototype", prefix="SN_Rig_Bowsprit_",
        role="bowsprit", type="bowsprit with gammon and iron cap",
        tri_budget=250, bbox=(4.52, 0.52, 2.65), tol=0.08,
        z_range=(0.0, 2.645), closed=True,
        datum="deck mount at z=0; spar rises toward +X",
        base_footprint=(0.45, 0.60), footprint_kind="deck_pad",
        extra={"rig_spec": "rig-kit@1", "bowsprit_length": 4.40}),
    "SN_Rig_Sail_Gaff": dict(
        collection="SN_Rig_Sail_Gaff_Prototype", prefix="SN_Rig_Sail_Gaff_",
        role="sail_gaff", type="gaff sail (single-layer cloth, double-sided)",
        tri_budget=1000, bbox=(5.98, 0.64, 8.24), tol=0.15,
        z_range=(-0.021, 8.219), closed=False,
        datum="tack at origin; head/throat toward +Z, clew toward -X",
        base_footprint=(0.0, 0.0), footprint_kind="none",
        extra={"rig_spec": "rig-kit@1", "sail_area_m2": 40.6,
               "cloth": "single_layer_static"}),
    "SN_Rig_Sail_Square": dict(
        collection="SN_Rig_Sail_Square_Prototype",
        prefix="SN_Rig_Sail_Square_", role="sail_square",
        type="square sail (single-layer cloth, double-sided)",
        tri_budget=900, bbox=(0.62, 6.04, 5.64), tol=0.15,
        z_range=(-0.021, 5.621), closed=False,
        datum="foot centre at origin; head toward +Z, span along Y",
        base_footprint=(0.0, 0.0), footprint_kind="none",
        extra={"rig_spec": "rig-kit@1", "sail_area_m2": 32.0,
               "cloth": "single_layer_static"}),
    "SN_Rig_Sail_Jib": dict(
        collection="SN_Rig_Sail_Jib_Prototype", prefix="SN_Rig_Sail_Jib_",
        role="sail_jib", type="jib / headsail (single-layer, double-sided)",
        tri_budget=800, bbox=(5.04, 0.47, 7.24), tol=0.15,
        z_range=(-0.020, 7.215), closed=False,
        datum="tack at origin; head toward +Z, clew toward +X",
        base_footprint=(0.0, 0.0), footprint_kind="none",
        extra={"rig_spec": "rig-kit@1", "sail_area_m2": 18.0,
               "cloth": "single_layer_static"}),
    "SN_Rig_Shrouds": dict(
        collection="SN_Rig_Shrouds_Prototype", prefix="SN_Rig_Shrouds_",
        role="shrouds", type="shroud ladders with ratlines and chainplates",
        tri_budget=1400, bbox=(2.59, 2.55, 7.26), tol=0.15,
        z_range=(-0.052, 7.207), closed=True,
        datum="deck chainplate feet at z=0; mast top toward +Z",
        base_footprint=(2.40, 2.60), footprint_kind="deck_pad",
        extra={"rig_spec": "rig-kit@1", "shroud_rows": 9, "shrouds_per_side": 4}),
    "SN_Rig_Stays": dict(
        collection="SN_Rig_Stays_Prototype", prefix="SN_Rig_Stays_",
        role="stays", type="fore/back stays with turnbuckles",
        tri_budget=400, bbox=(9.00, 2.94, 7.26), tol=0.15,
        z_range=(0.0, 7.260), closed=True,
        datum="mast-top eye at (0,0,7.2); lower ends at deck",
        base_footprint=(0.0, 0.0), footprint_kind="none",
        extra={"rig_spec": "rig-kit@1", "stay_count": 4}),
    "SN_Rig_Running": dict(
        collection="SN_Rig_Running_Prototype", prefix="SN_Rig_Running_",
        role="running", type="running rigging with blocks",
        tri_budget=500, bbox=(5.09, 6.83, 7.22), tol=0.15,
        z_range=(0.0, 7.224), closed=True,
        datum="mast-top eye at (0,0,7.2); falls toward deck",
        base_footprint=(0.0, 0.0), footprint_kind="none",
        extra={"rig_spec": "rig-kit@1", "line_count": 5, "block_count": 3}),
}

# 接口点：key -> (role 后缀, 父级 key, 局部坐标)
# BLEND 内名字 = prefix + role（避免同工作台重名），GLB 归一化为 SN_Mount / SN_Socket_*
SOCKETS = {
    "SN_Rig_Mast_Sail": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("YARD_LOWER", "Socket_Yard_Lower", "ROOT", (0.0, 0.0, 10.30)),
        ("YARD_UPPER", "Socket_Yard_Upper", "ROOT", (0.0, 0.0, 16.50)),
        ("SAIL_HEAD", "Socket_Sail_Head", "ROOT", (0.0, 0.0, 10.60)),
        ("SAIL_TACK", "Socket_Sail_Tack", "ROOT", (0.0, 0.0, 0.50)),
        ("DEADEYE_PORT", "Socket_Deadeye_Port", "ROOT", (0.0, 0.66, 1.20)),
        ("DEADEYE_STAR", "Socket_Deadeye_Starboard", "ROOT", (0.0, -0.66, 1.20)),
    ],
    "SN_Rig_Mast_Steam": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("YARD", "Socket_Yard", "ROOT", (0.0, 0.0, 8.20)),
        ("STAY_FORE", "Socket_Stay_Fore", "ROOT", (0.0, 0.0, 10.80)),
        ("STAY_AFT", "Socket_Stay_Aft", "ROOT", (0.0, 0.0, 10.80)),
    ],
    "SN_Rig_Yard": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("SAIL", "Socket_Sail", "ROOT", (0.0, 0.0, -0.09)),
        ("BRACE_PORT", "Socket_Brace_Port", "ROOT", (0.0, 3.40, 0.0)),
        ("BRACE_STAR", "Socket_Brace_Starboard", "ROOT", (0.0, -3.40, 0.0)),
    ],
    "SN_Rig_Gaff": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("SAIL_PEAK", "Socket_Sail_Peak", "ROOT", (5.20, 0.0, 1.90)),
        ("HALYARD", "Socket_Halyard", "ROOT", (0.60, 0.0, 0.15)),
    ],
    "SN_Rig_Boom": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("SAIL_CLEW", "Socket_Sail_Clew", "ROOT", (6.00, 0.0, -0.35)),
        ("SHEET", "Socket_Sheet", "ROOT", (6.00, 0.0, -0.35)),
    ],
    "SN_Rig_Bowsprit": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("JIB_TACK", "Socket_Jib_Tack", "ROOT", (4.40, 0.0, 2.55)),
        ("STAY_FORE", "Socket_Stay_Fore", "ROOT", (4.40, 0.0, 2.55)),
    ],
    "SN_Rig_Sail_Gaff": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("SAIL_HEAD", "Socket_Sail_Head", "ROOT", (0.0, 0.0, 5.80)),
        ("SAIL_PEAK", "Socket_Sail_Peak", "ROOT", (-5.80, 0.0, 8.20)),
        ("SAIL_CLEW", "Socket_Sail_Clew", "ROOT", (-5.20, 0.0, 0.70)),
    ],
    "SN_Rig_Sail_Square": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("YARD", "Socket_Yard", "ROOT", (0.0, 0.0, 5.60)),
        ("SHEET_PORT", "Socket_Sheet_Port", "ROOT", (0.0, 2.60, 0.0)),
        ("SHEET_STAR", "Socket_Sheet_Starboard", "ROOT", (0.0, -2.60, 0.0)),
    ],
    "SN_Rig_Sail_Jib": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("SAIL_HEAD", "Socket_Sail_Head", "ROOT", (0.0, 0.0, 7.20)),
        ("SAIL_CLEW", "Socket_Sail_Clew", "ROOT", (5.00, 0.0, 1.20)),
    ],
    "SN_Rig_Shrouds": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("MAST_TOP", "Socket_Mast_Top", "ROOT", (0.0, 0.0, 7.20)),
        ("CHAIN_PORT", "Socket_Chainplate_Port", "ROOT", (0.0, 1.20, 0.0)),
        ("CHAIN_STAR", "Socket_Chainplate_Starboard", "ROOT", (0.0, -1.20, 0.0)),
    ],
    "SN_Rig_Stays": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("MAST_TOP", "Socket_Mast_Top", "ROOT", (0.0, 0.0, 7.20)),
        ("BOWSPRIT_TIP", "Socket_Bowsprit_Tip", "ROOT", (4.60, 0.0, 0.60)),
    ],
    "SN_Rig_Running": [
        ("MOUNT", "Mount", "ROOT", (0.0, 0.0, 0.0)),
        ("MAST_TOP", "Socket_Mast_Top", "ROOT", (0.0, 0.0, 7.20)),
        ("CLEW", "Socket_Sail_Clew", "ROOT", (-5.00, 0.0, 6.40)),
    ],
}


def _builder(part):
    """套件几何统一用共享贴图材质 + ship_parts.core 基本体。"""
    return rig_kit.builder(part, _core(), materials=rig_kit.KIT_MATERIALS)


def _core():
    from ship_parts import core
    return core


def build_geometry(asset):
    """纯 Python：返回 {对象名: (Part, 父级 key)}。"""
    part = Part()
    b = _builder(part)
    p = b.prims
    prefix = SPECS[asset]["prefix"]
    if asset == "SN_Rig_Mast_Sail":
        rig_kit.schooner_mast(b, MAST_SAIL, foot=0.0)
    elif asset == "SN_Rig_Mast_Steam":
        rig_kit.steamer_mast(b, MAST_STEAM)
    elif asset == "SN_Rig_Yard":
        rig_kit.steamer_yard(b, YARD)
    elif asset == "SN_Rig_Gaff":
        rig_kit.spar(b, GAFF["heel"], GAFF["peak"], GAFF["r0"], GAFF["r1"])
        rig_kit.spar_jaws(b, 0.0, half_x=0.24, half_y=0.25, half_z=0.11)
        rig_kit.brass_band(b, (5.05, 0.0, 1.85), 0.080)
        rig_kit.brass_band(b, (0.30, 0.0, 0.11), 0.110)
    elif asset == "SN_Rig_Boom":
        rig_kit.spar(b, BOOM["tack"], BOOM["clew"], BOOM["r0"], BOOM["r1"])
        rig_kit.spar_jaws(b, 0.0, half_x=0.24, half_y=0.25, half_z=0.11)
        rig_kit.brass_band(b, (5.85, 0.0, -0.32), 0.085)
        rig_kit.brass_band(b, (0.30, 0.0, -0.02), 0.120)
    elif asset == "SN_Rig_Bowsprit":
        rig_kit.steamer_bowsprit(b, BOWSPRIT)
        # 甲板安装块：把 gammon 铁箱承到 z=0，独立摆放时不悬空
        b.add(p.box((0.05, -0.22, 0.0), (0.40, 0.22, 0.80)), b.mat("wood"))
    elif asset == "SN_Rig_Sail_Gaff":
        rig_kit.gaff_sail(b, SAIL_GAFF["tack"], SAIL_GAFF["throat"],
                          SAIL_GAFF["peak"], SAIL_GAFF["clew"],
                          SAIL_GAFF["camber"], SAIL_GAFF["roach"],
                          nu=12, nv=10)
    elif asset == "SN_Rig_Sail_Square":
        rig_kit.square_sail(b, SAIL_SQUARE["x_base"], SAIL_SQUARE["z_head"],
                            SAIL_SQUARE["z_foot"], SAIL_SQUARE["half_head"],
                            SAIL_SQUARE["half_foot"], SAIL_SQUARE["camber"],
                            nu=12, nv=8)
    elif asset == "SN_Rig_Sail_Jib":
        rig_kit.tri_sail(b, SAIL_JIB["head"], SAIL_JIB["tack"],
                         SAIL_JIB["clew"], SAIL_JIB["camber"],
                         SAIL_JIB["roach"], nu=10, nv=10)
    elif asset == "SN_Rig_Shrouds":
        for side in (1, -1):
            anchors = [(x, side * SHROUD["side_y"], 0.0)
                       for x in SHROUD["anchors_x"]]
            top = (SHROUD["top"][0], side * 0.12, SHROUD["top"][2])
            rig_kit.schooner_shroud_fan(
                b, top, anchors, SHROUD["rows"], top_offsets=(-0.083, 0.083))
            for x in SHROUD["anchors_x"]:
                b.add(p.box((x - 0.06, side * 1.20 - 0.06, 0.0),
                            (x + 0.06, side * 1.20 + 0.06, 0.16)),
                      b.mat("iron"))
    elif asset == "SN_Rig_Stays":
        top = STAYS["top"]
        b.add(p.box((top[0] - 0.10, top[1] - 0.10, top[2] - 0.06),
                    (top[0] + 0.10, top[1] + 0.10, top[2] + 0.06)),
              b.mat("metal"))
        for end, radius in STAYS["lines"]:
            rig_kit.rope(b, top, end, radius=radius, material="wood_dark")
            b.add(p.taper_cyl((end[0] + 0.10, end[1], end[2] - 0.02),
                              (end[0] - 0.10, end[1], end[2] - 0.02),
                              0.055, 0.055, 6), b.mat("metal"))
            # 甲板眼板 / 花篮螺栓座：把下端承到 z=0
            b.add(p.box((end[0] - 0.07, end[1] - 0.07, 0.0),
                        (end[0] + 0.07, end[1] + 0.07, end[2])), b.mat("iron"))
    elif asset == "SN_Rig_Running":
        for start, end, radius in RUNNING["lines"]:
            rig_kit.rope(b, start, end, radius=radius, material="wood_dark")
        for center in ((0.0, 0.0, 6.9), (0.0, 0.0, 0.6), (-1.2, 1.6, 0.6)):
            rig_kit.block(b, center, size=0.18)
        # 两舷帆脚索的甲板羊角：把索端承到 z=0
        for end in ((-1.2, 1.6, 0.6), (-1.2, -1.6, 0.6)):
            b.add(p.box((end[0] - 0.07, end[1] - 0.07, 0.0),
                        (end[0] + 0.07, end[1] + 0.07, end[2])), b.mat("metal"))
    else:
        raise KeyError(asset)
    return {prefix + "Body": (part, "ROOT")}


def socket_roles(asset):
    """GLB 标准接口名（SN_Mount / SN_Socket_*）。"""
    out = []
    for _key, role, _parent, _loc in SOCKETS[asset]:
        out.append("SN_Mount" if role == "Mount" else "SN_" + role)
    return out


def socket_entries(asset):
    prefix = SPECS[asset]["prefix"]
    return [{"key": key, "name": prefix + role, "parent": parent,
             "location": loc, "glb": "SN_Mount" if role == "Mount" else "SN_" + role}
            for key, role, parent, loc in SOCKETS[asset]]


def build_config(asset, origin=None):
    from ship_parts.assembly import BuildConfig, PivotSpec

    spec = SPECS[asset]
    prefix = spec["prefix"]
    sockets = socket_entries(asset)
    pivots = [PivotSpec(s["key"], s["name"], s["location"], parent=s["parent"])
              for s in sockets]
    origins = {s["key"]: s["location"] for s in sockets}
    pos = origin if origin is not None else WORKBENCH_POS[asset]
    footprint = spec["base_footprint"]
    root_props = {
        "asset": asset,
        "version": "1.0",
        "units": "metres",
        "kit_family": "rig_kit",
        "part_role": spec["role"],
        "forward": "+X",
        "up": "+Z",
        "datum": spec["datum"],
        "mount_frame": "%sMount at origin" % prefix,
        "base_footprint_x": float(footprint[0]),
        "base_footprint_y": float(footprint[1]),
        "footprint_kind": spec["footprint_kind"],
        "envelope_x": float(spec["bbox"][0]),
        "envelope_y": float(spec["bbox"][1]),
        "height": float(spec["bbox"][2]),
        "tri_budget": spec["tri_budget"],
        "bbox_target": "%.2f x %.2f x %.2f m" % spec["bbox"],
        "collection": spec["collection"],
        "type": spec["type"],
        "socket_spec": "rig-sockets@1",
        "socket_count": len(sockets),
    }
    root_props.update(spec.get("extra", {}))
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


def build_all_assets():
    from ship_parts import assembly
    import sn_shared_materials as shared

    collections = []
    for asset in ASSETS:
        collection = assembly.build_collection(build_geometry(asset),
                                               build_config(asset))
        materials = shared.apply_collection(collection)
        if materials["failures"]:
            raise RuntimeError("%s shared material apply failed: %r"
                               % (asset, materials["failures"]))
        print("TEXTURED %s: %d objects / %d materials / uv loops=%d" % (
            collection.name, materials["objects"],
            len(materials["materials"]), materials["uv_loops"]))
        collections.append(collection)
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
            raise RuntimeError("%s over tri budget: %d > %d"
                               % (asset, info["tris"], cfg.tri_budget))
    print("RIG_KIT_REPORT %r" % {
        "assets": {asset: out[asset]["tris"] for asset in ASSETS},
        "total_tris": sum(v["tris"] for v in out.values()),
    })
    return out


if __name__ == "__main__":
    build_all_assets()
    report()
