# -*- coding: utf-8 -*-
# @static-doc
# 作用：起重机四件套的**共享贴图材质视图**（纯 Python，不 import bpy）：材质名 →
# 线性回退色 / 粗糙度 / 金属度、贴图 / tile_m / 运行时 URI，以及每件资产的材质白名单。
#
# 设计原则：材质与模型分离，贴图与模型分离。
# - 真源是 `docs/design/textures/shared_materials/shared_materials.spec.json` 与
#   `tools/art/gen_shared_material_textures.py` 产出的 10 张 512² 无缝贴图；
#   本模块只从 `sn_shared_materials` 读取参数，不另存一份颜色。
# - 材质名用 `SN_Tex_*`：旧资产的 `SN_Metal` / `SN_Wood` 等**纯色材质被 160+ 个旧对象共用**，
#   不能原地改成贴图；新资产用 `SN_Tex_*` 贴图材质，旧资产完成 UV 迁移后再逐批切换。
# - Blender 侧由 `sn_shared_materials.apply_collection()` 写节点树与 UV；`assembly`
#   只负责建对象 / 材质槽，不再决定最终材质外观。
# - `ASSET_MATERIALS` 是验收白名单：干跑、GLB 自检与 Godot 验收都按它核对。
# - 改颜色 / 贴图只改 spec 与贴图生成器，几何代码与生成器不动。
# @end-static-doc

# 材质名常量（供几何生成器引用，避免字符串散落）
MAT_METAL = "SN_Tex_Metal"
MAT_IRON = "SN_Tex_Iron"
MAT_IRON_RED = "SN_Tex_Iron_Red"
MAT_WOOD = "SN_Tex_Wood"
MAT_WOOD_DARK = "SN_Tex_Wood_Dark"
MAT_WOOD_DECK = "SN_Tex_Wood_Deck"
MAT_STONE = "SN_Tex_Stone"
MAT_BRASS = "SN_Tex_Brass"
MAT_CANVAS_SHADE = "SN_Tex_Canvas_Shade"
MAT_GLASS_DARK = "SN_Tex_Glass_Dark"

# 材质参数与贴图都来自共享材质贴图库（spec = 唯一真源）：
# `docs/design/textures/shared_materials/shared_materials.spec.json`
import sn_shared_materials as shared

# 名称 -> (线性 base color, roughness, metallic)，由 spec 的贴图均值换算而来，
# 只在 Blender 里材质尚不存在时作为回退；正常渲染由贴图驱动。
PALETTE = shared.palette_linear()

# 名称 -> 贴图名 / tile_m / 运行时 URI，供干跑与文档引用。
TEXTURES = shared.texture_names()
TILE_M = {name: float(entry["tile_m"])
          for name, entry in shared.material_specs().items()}
RUNTIME_URIS = {name: shared.runtime_uri(name) for name in shared.material_specs()}

# 每件资产允许使用的材质（验收白名单；同时决定 BuildConfig 的材质参数子集）
ASSET_MATERIALS = {
    "SN_Harbor_Crane": frozenset({
        MAT_METAL, MAT_WOOD, MAT_WOOD_DARK, MAT_STONE,
    }),
    "SN_Mega_Gantry": frozenset({
        MAT_METAL, MAT_IRON, MAT_IRON_RED, MAT_WOOD_DARK, MAT_BRASS,
        MAT_GLASS_DARK,
    }),
    "SN_Wooden_Mast_Crane": frozenset({
        MAT_WOOD, MAT_WOOD_DARK, MAT_WOOD_DECK, MAT_METAL, MAT_STONE,
        MAT_CANVAS_SHADE,
    }),
    "SN_Hand_Jib_Crane": frozenset({
        MAT_METAL, MAT_IRON, MAT_WOOD_DARK, MAT_STONE, MAT_BRASS,
        MAT_CANVAS_SHADE,
    }),
}


def colors_for(asset):
    """返回某件资产用到的材质参数子集（name -> spec），供 BuildConfig 使用。"""
    names = ASSET_MATERIALS[asset]
    return {name: PALETTE[name] for name in names}


def material_names(asset):
    """返回排序后的材质名列表（报告 / 验收用）。"""
    return sorted(ASSET_MATERIALS[asset])
