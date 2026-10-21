# -*- coding: utf-8 -*-
# @static-doc
# 作用：船体帆索部件库 `rig_kit` 套件（12 件 `SN_Rig_*`）的**共享贴图材质视图**
# （纯 Python，不 import bpy）：材质名常量、每件资产的材质白名单与回退色。
#
# 与 `sn_kit_materials.py` 同构：材质真源是
# `docs/design/textures/shared_materials/shared_materials.spec.json`；Blender 侧由
# `sn_shared_materials.apply_collection()` 写节点树与盒式 UV。本模块只提供
# `MAT_*` 常量、白名单与 `colors_for()`，不另存颜色。
# @end-static-doc

MAT_METAL = "SN_Tex_Metal"
MAT_IRON = "SN_Tex_Iron"
MAT_WOOD = "SN_Tex_Wood"
MAT_WOOD_DARK = "SN_Tex_Wood_Dark"
MAT_WOOD_DECK = "SN_Tex_Wood_Deck"
MAT_BRASS = "SN_Tex_Brass"
MAT_CANVAS = "SN_Tex_Canvas_Shade"

import sn_shared_materials as shared

PALETTE = shared.palette_linear()

# 每件资产的材质白名单（干跑 / GLB 验收共用）
ASSET_MATERIALS = {
    "SN_Rig_Mast_Sail": frozenset({MAT_WOOD, MAT_WOOD_DARK, MAT_METAL, MAT_BRASS}),
    "SN_Rig_Mast_Steam": frozenset({MAT_WOOD, MAT_METAL}),
    "SN_Rig_Yard": frozenset({MAT_WOOD, MAT_WOOD_DECK, MAT_METAL}),
    "SN_Rig_Gaff": frozenset({MAT_WOOD_DARK, MAT_BRASS}),
    "SN_Rig_Boom": frozenset({MAT_WOOD_DARK, MAT_BRASS}),
    "SN_Rig_Bowsprit": frozenset({MAT_WOOD, MAT_IRON, MAT_METAL}),
    "SN_Rig_Sail_Gaff": frozenset({MAT_CANVAS, MAT_WOOD_DARK}),
    "SN_Rig_Sail_Square": frozenset({MAT_CANVAS, MAT_WOOD_DARK}),
    "SN_Rig_Sail_Jib": frozenset({MAT_CANVAS, MAT_WOOD_DARK}),
    "SN_Rig_Shrouds": frozenset({MAT_WOOD_DARK, MAT_IRON, MAT_METAL}),
    "SN_Rig_Stays": frozenset({MAT_WOOD_DARK, MAT_IRON, MAT_METAL}),
    "SN_Rig_Running": frozenset({MAT_WOOD_DARK, MAT_METAL, MAT_BRASS}),
}


def colors_for(asset):
    names = ASSET_MATERIALS[asset]
    return {name: PALETTE[name] for name in names}


def material_names(asset):
    return sorted(ASSET_MATERIALS[asset])
