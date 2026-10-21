# -*- coding: utf-8 -*-
# @static-doc
# 作用：模型素材库（批次 1 武器套件/船体部件 + 批次 2 机械/货物/码头套件 +
# 批次 3 建筑/环境套件）的**共享贴图材质视图**（纯 Python，不 import bpy）：
# 材质名常量、每件资产的材质白名单与回退色。
#
# 与 `sn_weapon_materials.py` 同构：材质与模型分离、贴图与模型分离；真源是
# `docs/design/textures/shared_materials/shared_materials.spec.json`，Blender 侧由
# `sn_shared_materials.apply_collection()` 写节点树与世界空间盒式 UV。
# 本模块只给几何生成器提供 `MAT_*` 常量与每件资产的材质白名单，不另存颜色。
# 批次 2 新增 `SN_Tex_Coal`（碎煤），用于煤斗 / 煤堆；批次 3 不新增贴图。
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
MAT_STONE = "SN_Tex_Stone"
MAT_COAL = "SN_Tex_Coal"

import sn_shared_materials as shared

PALETTE = shared.palette_linear()
TEXTURES = shared.texture_names()
TILE_M = {name: float(entry["tile_m"])
          for name, entry in shared.material_specs().items()}
RUNTIME_URIS = {name: shared.runtime_uri(name) for name in shared.material_specs()}

# 每件资产允许使用的材质（干跑 / GLB 验收白名单）
ASSET_MATERIALS = {
    # ---- weapon kit
    "SN_Weapon_Cannon": frozenset({
        MAT_IRON, MAT_METAL, MAT_IRON_RED, MAT_BRASS, MAT_GLASS_DARK,
    }),
    "SN_Weapon_GunCarriage": frozenset({
        MAT_IRON, MAT_METAL, MAT_IRON_RED, MAT_WOOD, MAT_WOOD_DARK,
        MAT_WOOD_DECK, MAT_BRASS, MAT_CANVAS_SHADE,
    }),
    "SN_Weapon_Turret": frozenset({
        MAT_IRON, MAT_METAL, MAT_IRON_RED, MAT_WOOD_DARK, MAT_BRASS,
        MAT_GLASS_DARK,
    }),
    "SN_Weapon_Pedestal": frozenset({
        MAT_IRON, MAT_METAL, MAT_IRON_RED, MAT_BRASS, MAT_WOOD_DARK,
    }),
    # ---- ship parts
    "SN_ShipPart_Deck": frozenset({
        MAT_WOOD, MAT_WOOD_DARK, MAT_WOOD_DECK, MAT_IRON, MAT_METAL,
        MAT_BRASS,
    }),
    "SN_ShipPart_Mast": frozenset({
        MAT_WOOD, MAT_WOOD_DARK, MAT_WOOD_DECK, MAT_IRON, MAT_METAL,
        MAT_BRASS,
    }),
    "SN_ShipPart_Funnel": frozenset({
        MAT_IRON, MAT_IRON_RED, MAT_METAL, MAT_WOOD_DARK, MAT_BRASS,
    }),
    "SN_ShipPart_HatchCover": frozenset({
        MAT_WOOD, MAT_WOOD_DARK, MAT_WOOD_DECK, MAT_IRON, MAT_METAL,
        MAT_BRASS,
    }),
    # ---- machinery kit（批次 2）
    "SN_Machinery_GearSet": frozenset({
        MAT_IRON, MAT_METAL, MAT_IRON_RED, MAT_BRASS, MAT_WOOD_DARK,
    }),
    "SN_Machinery_Winch": frozenset({
        MAT_IRON, MAT_METAL, MAT_IRON_RED, MAT_WOOD, MAT_WOOD_DARK,
        MAT_BRASS, MAT_CANVAS_SHADE,
    }),
    "SN_Machinery_PowerUnit": frozenset({
        MAT_IRON, MAT_METAL, MAT_IRON_RED, MAT_BRASS, MAT_GLASS_DARK,
        MAT_WOOD, MAT_WOOD_DARK, MAT_CANVAS_SHADE,
    }),
    # ---- cargo kit（批次 2）
    "SN_Cargo_Crate": frozenset({
        MAT_WOOD, MAT_WOOD_DARK, MAT_WOOD_DECK, MAT_IRON, MAT_METAL,
        MAT_BRASS, MAT_GLASS_DARK, MAT_CANVAS_SHADE,
    }),
    "SN_Cargo_CoalScuttle": frozenset({
        MAT_IRON, MAT_METAL, MAT_IRON_RED, MAT_BRASS, MAT_COAL,
        MAT_WOOD, MAT_WOOD_DARK, MAT_GLASS_DARK, MAT_CANVAS_SHADE,
    }),
    "SN_Cargo_Tank": frozenset({
        MAT_IRON, MAT_METAL, MAT_IRON_RED, MAT_BRASS, MAT_GLASS_DARK,
        MAT_WOOD_DARK, MAT_STONE,
    }),
    "SN_Cargo_Pallet": frozenset({
        MAT_WOOD, MAT_WOOD_DARK, MAT_WOOD_DECK, MAT_IRON, MAT_BRASS,
    }),
    # ---- dock kit（批次 2）
    "SN_Dock_Structure": frozenset({
        MAT_STONE, MAT_IRON, MAT_METAL, MAT_IRON_RED, MAT_WOOD_DARK,
        MAT_WOOD, MAT_BRASS,
    }),
    "SN_Dock_Jetty": frozenset({
        MAT_WOOD, MAT_WOOD_DARK, MAT_WOOD_DECK, MAT_IRON, MAT_METAL,
        MAT_BRASS, MAT_CANVAS_SHADE,
    }),
    "SN_Dock_Mooring": frozenset({
        MAT_IRON, MAT_METAL, MAT_BRASS, MAT_WOOD_DARK, MAT_CANVAS_SHADE,
        MAT_STONE,
    }),
    # ---- architecture kit（批次 3）
    "SN_Arch_Warehouse": frozenset({
        MAT_STONE, MAT_IRON, MAT_IRON_RED, MAT_WOOD, MAT_WOOD_DARK,
        MAT_WOOD_DECK, MAT_BRASS, MAT_GLASS_DARK, MAT_METAL, MAT_CANVAS_SHADE,
    }),
    "SN_Arch_Workshop": frozenset({
        MAT_STONE, MAT_IRON, MAT_IRON_RED, MAT_WOOD, MAT_WOOD_DARK,
        MAT_WOOD_DECK, MAT_BRASS, MAT_GLASS_DARK, MAT_METAL, MAT_CANVAS_SHADE,
    }),
    "SN_Arch_Tavern": frozenset({
        MAT_STONE, MAT_IRON, MAT_IRON_RED, MAT_WOOD, MAT_WOOD_DARK,
        MAT_WOOD_DECK, MAT_BRASS, MAT_GLASS_DARK, MAT_METAL, MAT_CANVAS_SHADE,
    }),
    "SN_Arch_Factory": frozenset({
        MAT_STONE, MAT_IRON, MAT_IRON_RED, MAT_WOOD, MAT_WOOD_DARK,
        MAT_WOOD_DECK, MAT_BRASS, MAT_GLASS_DARK, MAT_METAL, MAT_CANVAS_SHADE,
    }),
    # ---- environment kit（批次 3）
    "SN_Env_Reef": frozenset({
        MAT_STONE, MAT_WOOD_DARK, MAT_IRON, MAT_METAL,
    }),
    "SN_Env_Wreck": frozenset({
        MAT_WOOD, MAT_WOOD_DARK, MAT_WOOD_DECK, MAT_IRON, MAT_METAL,
        MAT_BRASS, MAT_STONE, MAT_GLASS_DARK,
    }),
    "SN_Env_Lighthouse": frozenset({
        MAT_STONE, MAT_IRON, MAT_IRON_RED, MAT_BRASS, MAT_GLASS_DARK,
        MAT_METAL, MAT_WOOD_DARK,
    }),
    "SN_Env_Buoy": frozenset({
        MAT_IRON, MAT_IRON_RED, MAT_METAL, MAT_BRASS, MAT_GLASS_DARK,
        MAT_WOOD_DARK,
    }),
}


def colors_for(asset):
    names = ASSET_MATERIALS[asset]
    return {name: PALETTE[name] for name in names}


def material_names(asset):
    return sorted(ASSET_MATERIALS[asset])
