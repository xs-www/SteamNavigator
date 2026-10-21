# -*- coding: utf-8 -*-
# @static-doc
# 作用：起重机四件套的**共享材质库**（纯 Python，不 import bpy）：材质名 → 线性色 /
# 粗糙度 / 金属度，以及每件资产允许使用的材质白名单。
#
# 设计原则：材质是与几何分离的真源。四个生成器只引用这里的材质名与参数表，
# 不各自维护颜色；Blender 侧由 `ship_parts.assembly._ensure_material()` 按名字
# 复用工作台里的共享 datablock（不存在时才用这里的参数新建），因此四台起重机
# 以及既有的船 / 道具 / 建筑共享同一套 `SN_*` 材质，不会因为新资产而复制材质。
#
# - 不新增材质：只使用工作台调色板里已有的 10 个 `SN_*` 材质。
# - 材质参数是**线性空间**值（与 Blender Principled Base Color 一致）。
# - `ASSET_MATERIALS` 是验收白名单：干跑与 GLB 自检都按它核对每件资产。
# - 改颜色只改这一处；生成器与 GLB 重新导出即可，不需要动几何代码。
# @end-static-doc

# 材质名常量（供几何生成器引用，避免字符串散落）
MAT_METAL = "SN_Metal"
MAT_IRON = "SN_Iron"
MAT_IRON_RED = "SN_Iron_Red"
MAT_WOOD = "SN_Wood"
MAT_WOOD_DARK = "SN_Wood_Dark"
MAT_WOOD_DECK = "SN_Wood_Deck"
MAT_STONE = "SN_Stone"
MAT_BRASS = "SN_Brass"
MAT_CANVAS_SHADE = "SN_Canvas_Shade"
MAT_GLASS_DARK = "SN_Glass_Dark"

# 名称 -> (线性 base color, roughness, metallic)
PALETTE = {
    MAT_METAL: ((0.140, 0.150, 0.170), 0.36, 0.90),
    MAT_IRON: ((0.072, 0.076, 0.084), 0.52, 0.62),
    MAT_IRON_RED: ((0.190, 0.035, 0.022), 0.62, 0.10),
    MAT_WOOD: ((0.200, 0.088, 0.035), 0.70, 0.00),
    MAT_WOOD_DARK: ((0.042, 0.019, 0.008), 0.64, 0.00),
    MAT_WOOD_DECK: ((0.300, 0.165, 0.072), 0.76, 0.00),
    MAT_STONE: ((0.235, 0.228, 0.208), 0.90, 0.00),
    MAT_BRASS: ((0.420, 0.270, 0.075), 0.28, 0.85),
    MAT_CANVAS_SHADE: ((0.540, 0.500, 0.410), 0.92, 0.00),
    MAT_GLASS_DARK: ((0.032, 0.042, 0.052), 0.25, 0.35),
}

# 每件资产允许使用的材质（验收白名单；同时决定 BuildConfig 的材质参数子集）
ASSET_MATERIALS = {
    "SN_Harbor_Crane": frozenset({
        MAT_METAL, MAT_WOOD, MAT_WOOD_DARK, MAT_STONE,
    }),
    "SN_Mega_Gantry": frozenset({
        MAT_METAL, MAT_IRON, MAT_IRON_RED, MAT_WOOD_DARK, MAT_BRASS,
        MAT_STONE, MAT_GLASS_DARK,
    }),
    "SN_Wooden_Mast_Crane": frozenset({
        MAT_WOOD, MAT_WOOD_DARK, MAT_WOOD_DECK, MAT_METAL, MAT_STONE,
        MAT_BRASS, MAT_CANVAS_SHADE,
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
