# -*- coding: utf-8 -*-
# @static-doc
# 作用：**穿船壳炮（casemate gun）独立模块** `SN_Weapon_CasemateGun` 的参数化生成器
# 与 Blender 装配入口 —— 把铁甲舰舷侧炮从船体网格里拆出来，改为可挂到任意带炮门
# （`SN_Socket_GunPort_*`）的船体上的独立 GLB。
#
# ## 轴心 / 朝向（与甲板武器的“炮座底面 z=0”不同）
# - 根节点原点 = **炮门平面中心**（炮膛轴线与船壳面的交点），不是甲板；
# - 局部 `+X` = 炮膛轴线，指向舷外；`+Z` 向上；`+Y` 沿船体纵轴（左舷侧）；
# - 可见几何全部在 `x >= 0`（门外），`x < 0` 是藏在船壳暗板后面的隐藏段
#   （炮尾 / 耳轴 / 内膛遮挡件），后坐与俯仰都不应让它们露出来。
#
# ## 层级（武器装配规范 v2 + `port_pitch` profile）
# ```text
# SN_Weapon_CasemateGun_Root
#   SN_Mount            安装帧（=根，原点在炮门平面中心）
#     SN_Pivot_Pitch    耳轴（x=-0.15，在门内）
#       SN_Recoil       后坐节点（沿 -X 平移）
#         SN_Muzzle     炮口端面中心
# ```
# 没有 Yaw（固定舷炮）。炮管 / 炮口箍 / 炮尾 / 耳轴网格都挂 `SN_Recoil`。
#
# ## 与船体的配合
# - 船体保留“炮门框 + 深色炮口板 + 上翻炮门盖”，本模块只提供门外炮管；
#   深色炮口板同时是隐藏段的遮挡面（空载时炮门读作暗腔，装炮后炮管从暗腔里伸出）。
# - 几何取自 `sn_ironclad_generator.py` 的同一组参数（`GUN_*` / `gun_port_pose()`），
#   因此装到铁甲舰 12 个炮门上时与拆炮前的烘焙炮管**逐顶点重合**（dryrun 断言）。
# - 材质走共享贴图 `SN_Tex_*`（仅 Metal / Brass / Iron 3 个槽）。
#
# 用法：
# - Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
# - 纯 Python 干跑：`python tools/modeling/generators/dryrun_casemate_gun.py`
# - 导出 GLB：`python tools/modeling/generators/export_casemate_glb.py`（Blender 内）
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

from ship_parts.core import Part, box  # noqa: E402

import sn_ironclad_generator as ironclad  # noqa: E402
from sn_weapon_materials import (  # noqa: E402
    ASSET_MATERIALS,
    MAT_BRASS,
    MAT_IRON,
    MAT_METAL,
    colors_for,
)

ASSET = "SN_Weapon_CasemateGun"
COLLECTION = ASSET + "_Prototype"
PREFIX = ASSET + "_"
ROOT = PREFIX + "Root"
WORKBENCH_POS = (0.0, 430.0, 0.0)
TRI_BUDGET = 400

# 炮门平面在烘焙炮管轴线上的位置（炮尾起点内缩 0.40 m / 轴线的舷向分量）。
PLANE_OFFSET = ironclad.GUN_INBOARD / abs(ironclad.gun_bore_dir(1)[1])
BARREL_INBOARD = -PLANE_OFFSET                       # 局部 x：炮尾端（负 = 门内）
BARREL_OUTBOARD = ironclad.GUN_LENGTH - PLANE_OFFSET  # 局部 x：炮口端（= 门外外露长度）
BAND_IN = ironclad.GUN_MUZZLE_BAND_FROM - PLANE_OFFSET
BAND_OUT = BARREL_OUTBOARD
BAND_R = ironclad.GUN_MUZZLE_BAND_R
BREECH_REAR = -0.95                    # 隐藏段尾端（内膛遮挡件）
BREECH_HALF = 0.24
TRUNNION_X = -0.15                      # 耳轴位置（门内）
TRUNNION_R = 0.09
TRUNNION_HALF_LEN = 0.24

PORT_CLASS = "Medium"
PORT_W = 1.90
PORT_H = 1.90
SILL_Z = ironclad.GUN_Z0
DECK_Z = ironclad.DECK_Z
ELEV_MIN, ELEV_MAX = -6.0, 12.0  # 俯仰极限：保证炮口箍不顶出 1.9×1.9 炮门开口


def build_geometry():
    """返回 {对象名: (Part, 父级键)}；父级键 RECOIL = 挂在 SN_Recoil 下。"""
    barrel = Part()
    barrel.add(ironclad.taper_cyl((BARREL_INBOARD, 0.0, 0.0), (BARREL_OUTBOARD, 0.0, 0.0),
                            ironclad.GUN_R_BREECH, ironclad.GUN_R_MUZZLE, 8), MAT_METAL)
    barrel.add(ironclad.taper_cyl((BAND_IN, 0.0, 0.0), (BAND_OUT, 0.0, 0.0),
                         BAND_R, BAND_R, 8), MAT_BRASS)

    breech = Part()
    # 炮尾 / 内膛遮挡件：整块都在炮门平面以内，正常视角不可见
    breech.add(box((BREECH_REAR, -BREECH_HALF, -BREECH_HALF),
                   (BARREL_INBOARD - 0.02, BREECH_HALF, BREECH_HALF)), MAT_IRON)
    # 双耳轴（俯仰轴）：插在耳轴座里，同样在门内
    for sy in (-1.0, 1.0):
        breech.add(ironclad.taper_cyl((TRUNNION_X, sy * TRUNNION_R, 0.0),
                             (TRUNNION_X, sy * TRUNNION_HALF_LEN, 0.0),
                             TRUNNION_R, TRUNNION_R, 6), MAT_IRON)

    return {
        PREFIX + "Barrel": (barrel, "RECOIL"),
        PREFIX + "Breech": (breech, "RECOIL"),
    }


def _pivot_specs():
    return [
        {"key": "MOUNT", "name": PREFIX + "Mount", "parent": "ROOT",
         "location": (0.0, 0.0, 0.0)},
        {"key": "PITCH", "name": PREFIX + "Pivot_Pitch", "parent": "MOUNT",
         "location": (TRUNNION_X, 0.0, 0.0)},
        {"key": "RECOIL", "name": PREFIX + "Recoil", "parent": "PITCH",
         "location": (0.0, 0.0, 0.0), "origin": (TRUNNION_X, 0.0, 0.0)},
        {"key": "MUZZLE", "name": PREFIX + "Muzzle", "parent": "RECOIL",
         "location": (BARREL_OUTBOARD - TRUNNION_X, 0.0, 0.0)},
    ]


def envelope():
    """模块局部包围盒（米）。"""
    return {
        "x": (BREECH_REAR, BARREL_OUTBOARD),
        "y": (-max(ironclad.GUN_R_BREECH, BAND_R, BREECH_HALF),
              max(ironclad.GUN_R_BREECH, BAND_R, BREECH_HALF)),
        "z": (-max(ironclad.GUN_R_BREECH, BAND_R), max(ironclad.GUN_R_BREECH, BAND_R)),
    }


def build_config(origin=None):
    from ship_parts.assembly import BuildConfig, PivotSpec

    box_env = envelope()
    length = round(box_env["x"][1] - box_env["x"][0], 4)
    width = round(box_env["y"][1] - box_env["y"][0], 4)
    height = round(box_env["z"][1] - box_env["z"][0], 4)
    pivots = [PivotSpec(p["key"], p["name"], p["location"], parent=p["parent"])
              for p in _pivot_specs()]
    origins = {p["key"]: p.get("origin", p["location"]) for p in _pivot_specs()}
    root_props = {
        "asset": ASSET,
        "version": "1.0",
        "units": "metres",
        "assembly_spec": "weapon-assembly@2",
        "weapon_class": PORT_CLASS,
        "assembly_profile": "port_pitch",
        "socket": "SN_Socket_GunPort",
        "mount": "SN_Mount",
        "pivot_yaw": "",
        "pivot_pitch": "SN_Pivot_Pitch",
        "recoil": "SN_Recoil",
        "muzzle": "SN_Muzzle",
        "has_yaw": False,
        "has_pitch": True,
        "has_recoil": True,
        "has_muzzle": True,
        "yaw_axis": "",
        "pitch_axis": "Y",
        "recoil_axis": "-X",
        "muzzle_count": 1,
        "pivot": "port plane centre (x=0), +X = bore axis (outboard)",
        "forward_axis": "+X (bore direction, outboard)",
        "port_spec": "gun-port@1",
        "port_class": PORT_CLASS,
        "port_w": PORT_W,
        "port_h": PORT_H,
        "sill_z": SILL_Z,
        "deck_z": DECK_Z,
        "muzzle_protrusion": round(BARREL_OUTBOARD, 4),
        "breech_depth": round(-BREECH_REAR, 4),
        "barrel_diameter": round(ironclad.GUN_R_BREECH * 2.0, 4),
        "trunnion_offset": round(-TRUNNION_X, 4),
        "elev_min_deg": ELEV_MIN,
        "elev_max_deg": ELEV_MAX,
        "traverse_limit_deg": 0.0,
        "base_footprint_x": PORT_W,
        "base_footprint_y": PORT_H,
        "envelope_x": length,
        "envelope_y": width,
        "height": height,
        "collection": COLLECTION,
        "type": "casemate gun (hull-port cannon, barrel-only module)",
        "tri_budget": TRI_BUDGET,
        "bbox_target": "%.2f x %.2f x %.2f m" % (length, width, height),
    }
    return BuildConfig(
        collection=COLLECTION,
        prefix=PREFIX,
        root_name=ROOT,
        workbench_pos=origin if origin is not None else WORKBENCH_POS,
        material_colors=colors_for(ASSET),
        material_reuse=colors_for(ASSET),
        root_props=root_props,
        pivots=pivots,
        origins=origins,
        report_title=ASSET,
        tri_budget=TRI_BUDGET,
        root_size=1.0,
    )


def build_all():
    """在 Blender 工作台里幂等重建 casemate 炮模块集合。"""
    from ship_parts import assembly
    import sn_shared_materials as shared

    collection = assembly.build_collection(build_geometry(), build_config())
    materials = shared.apply_collection(collection)
    if materials.get("failures"):
        raise RuntimeError("%s shared material apply failed: %r" % (
            ASSET, materials["failures"]))
    print("TEXTURED %s: %d 对象 / %d 材质 / UV loops=%d" % (
        collection.name, materials["objects"], len(materials["materials"]),
        materials["uv_loops"]))
    return collection


def report(verbose=True):
    import bpy
    from ship_parts import assembly
    import sn_shared_materials as shared

    cfg = build_config()
    info = assembly.report(cfg, verbose=verbose)
    verification = shared.verify_collection(bpy.data.collections[cfg.collection])
    print("共享贴图验收 %s: %s (%d 网格, 失败 %d)" % (
        ASSET, "PASS" if verification["ok"] else "FAIL",
        verification["meshes"], len(verification["failures"])))
    for failure in verification["failures"]:
        print("  - " + failure)
    info["textures"] = verification
    if not verification["ok"]:
        raise RuntimeError("%s shared material verification failed" % ASSET)
    if info["tris"] > cfg.tri_budget:
        raise RuntimeError("%s over tri budget: %d > %d" % (
            ASSET, info["tris"], cfg.tri_budget))
    print("CASEMATE_GUN_REPORT %r" % {"tris": info["tris"], "bbox": info["bbox"]})
    return info


if __name__ == "__main__":
    build_all()
