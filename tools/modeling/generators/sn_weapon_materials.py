# -*- coding: utf-8 -*-
# @static-doc
# 作用：舰载武器五件套的**共享贴图材质视图**（纯 Python，不 import bpy）：材质名常量、
# 线性回退色 / 粗糙度 / 金属度、贴图 / tile_m / 运行时 URI，以及每件武器的材质白名单。
#
# 设计原则与起重机批一致：材质与模型分离、贴图与模型分离；真源是
# `docs/design/textures/shared_materials/shared_materials.spec.json`，Blender 侧由
# `sn_shared_materials.apply_collection()` 写节点树与世界空间盒式 UV。
# 本模块只给几何生成器提供 `MAT_*` 常量与每件资产的白名单，不另存颜色。
# @end-static-doc

MAT_METAL = "SN_Tex_Metal"
MAT_IRON = "SN_Tex_Iron"
MAT_IRON_RED = "SN_Tex_Iron_Red"
MAT_WOOD = "SN_Tex_Wood"
MAT_WOOD_DARK = "SN_Tex_Wood_Dark"
MAT_WOOD_DECK = "SN_Tex_Wood_Deck"
MAT_BRASS = "SN_Tex_Brass"
MAT_CANVAS_SHADE = "SN_Tex_Canvas_Shade"
MAT_GLASS_DARK = "SN_Tex_Glass_Dark"

import sn_shared_materials as shared

PALETTE = shared.palette_linear()
TEXTURES = shared.texture_names()
TILE_M = {name: float(entry["tile_m"])
          for name, entry in shared.material_specs().items()}
RUNTIME_URIS = {name: shared.runtime_uri(name) for name in shared.material_specs()}

# 每件武器允许使用的材质（验收白名单）
ASSET_MATERIALS = {
    "SN_Weapon_DeckGun": frozenset({
        MAT_IRON, MAT_METAL, MAT_IRON_RED, MAT_BRASS, MAT_WOOD_DARK,
        MAT_CANVAS_SHADE,
    }),
    "SN_Weapon_HeavyCannon": frozenset({
        MAT_IRON, MAT_METAL, MAT_IRON_RED, MAT_WOOD, MAT_WOOD_DARK,
        MAT_BRASS, MAT_CANVAS_SHADE,
    }),
    "SN_Weapon_Mortar": frozenset({
        MAT_IRON, MAT_METAL, MAT_IRON_RED, MAT_WOOD_DARK, MAT_BRASS,
        MAT_CANVAS_SHADE, MAT_GLASS_DARK,
    }),
    "SN_Weapon_Repeater": frozenset({
        MAT_IRON, MAT_METAL, MAT_IRON_RED, MAT_WOOD_DARK, MAT_BRASS,
        MAT_CANVAS_SHADE,
    }),
    "SN_Weapon_Broadside": frozenset({
        MAT_IRON, MAT_METAL, MAT_IRON_RED, MAT_WOOD, MAT_WOOD_DARK,
        MAT_BRASS, MAT_CANVAS_SHADE,
    }),
    "SN_Weapon_Ballista": frozenset({
        MAT_IRON, MAT_METAL, MAT_IRON_RED, MAT_WOOD, MAT_WOOD_DARK,
        MAT_WOOD_DECK, MAT_BRASS, MAT_CANVAS_SHADE,
    }),
    "SN_Weapon_ArrowTower": frozenset({
        MAT_IRON, MAT_METAL, MAT_IRON_RED, MAT_WOOD, MAT_WOOD_DARK,
        MAT_WOOD_DECK, MAT_BRASS, MAT_CANVAS_SHADE,
    }),
    "SN_Weapon_HarpoonLauncher": frozenset({
        MAT_IRON, MAT_METAL, MAT_IRON_RED, MAT_WOOD_DARK, MAT_BRASS,
        MAT_CANVAS_SHADE,
    }),
    # 2026-10-22：穿船壳炮（casemate gun）模块 —— 可见部分只有炮管 + 炮口箍，
    # 内膛段用 IRON；不再有炮架 / 炮盾，因此材质白名单只有 3 个。
    "SN_Weapon_CasemateGun": frozenset({
        MAT_IRON, MAT_METAL, MAT_BRASS,
    }),
}


def colors_for(asset):
    names = ASSET_MATERIALS[asset]
    return {name: PALETTE[name] for name in names}


def material_names(asset):
    return sorted(ASSET_MATERIALS[asset])
