# -*- coding: utf-8 -*-
# @static-doc
# 作用：从批次 1/2/3 生成器的纯几何数据生成机器可读的模型素材库目录
# `tools/modeling/kit_catalog.json`（资产 / 尺寸 / tri / 材质 / socket 接口 / 装配
# 配方）。改几何后重跑本脚本即可，不再手工维护第二份尺寸表。
#
# 用法：
#     python tools/modeling/generators/gen_kit_catalog.py
# @end-static-doc

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import kit_batch1_generator as gen1  # noqa: E402
import kit_batch2_generator as gen2  # noqa: E402
import kit_batch3_generator as gen3  # noqa: E402

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
OUT = os.path.join(WORKDIR, "tools", "modeling", "kit_catalog.json")
GENERATORS = [gen1, gen2, gen3]

CATEGORY = {
    "weapon_kit": "weapons",
    "ship_parts": "ship_parts",
    "machinery_kit": "machinery",
    "cargo_kit": "cargo",
    "dock_kit": "dock",
    "architecture_kit": "architecture",
    "environment_kit": "environment",
}

RECIPES = [
    {
        "id": "naval_gun_carriage",
        "title": "火炮 + 炮架（四轮炮车）",
        "parts": ["SN_Weapon_Cannon", "SN_Weapon_GunCarriage"],
        "rule": "炮架 Root 放地面；火炮 Root 放到炮架 Root + (0, 0, 0.62)，"
                "耳轴与 SN_Weapon_GunCarriage_Trunnion_L/R 对齐；两件 +X 同向。",
        "result": "完整可推行的舰炮；炮架 Yaw_Pivot 可做整机回转（可选）。",
    },
    {
        "id": "turret_on_deck",
        "title": "炮塔 + 甲板 socket",
        "parts": ["SN_Weapon_Turret", "SN_ShipPart_Deck"],
        "rule": "炮塔 Root 对齐 SN_ShipPart_Deck_Socket_Weapon_Port（Z = 0.33）；"
                "炮塔自带的 Yaw_Pivot 负责回转，不再需要额外基座。",
        "result": "带装甲回转炮塔的甲板模块。",
    },
    {
        "id": "pedestal_on_deck",
        "title": "武器基座 + 甲板 socket",
        "parts": ["SN_Weapon_Pedestal", "SN_ShipPart_Deck"],
        "rule": "基座 Root 对齐 SN_ShipPart_Deck_Socket_Weapon_Starboard（Z = 0.33）；"
                "Collar（z=1.10）是上层武器的安装面，兼容 Medium class。",
        "result": "通用回转安装点；现有 Light/Medium 武器批次 1–2 可视觉落座。",
    },
    {
        "id": "deck_superstructure",
        "title": "甲板 + 桅杆 + 烟囱 + 货舱盖",
        "parts": ["SN_ShipPart_Deck", "SN_ShipPart_Mast",
                  "SN_ShipPart_Funnel", "SN_ShipPart_HatchCover"],
        "rule": "各子件 Root 对齐甲板对应 Socket_*（Z = 0.33）；"
                "mast→Socket_Mast、funnel→Socket_Funnel、hatch→Socket_Hatch。",
        "result": "8.4 × 6.0 m 甲板模块的完整上建演示（见 kit_assembly_deck.png）。",
    },
    # ---- 批次 2
    {
        "id": "power_train",
        "title": "动力装置 → 齿轮组 → 卷扬机",
        "parts": ["SN_Machinery_PowerUnit", "SN_Machinery_GearSet",
                  "SN_Machinery_Winch"],
        "rule": "动力装置 Shaft_Out（飞轮轴 +Y）与齿轮组 Shaft_In（−Y 侧）同轴对视，"
                "齿轮组 Shaft_Out / Crank 端接卷扬机 Drum_Pivot；三件 Root 都放地面，"
                "按轴高差做视觉对齐（本批不强制机械耦合）。",
        "result": "一条可读的蒸汽动力链（见 kit_machinery_lineup.png）。",
    },
    {
        "id": "cargo_stack",
        "title": "托盘 + 货箱堆码",
        "parts": ["SN_Cargo_Pallet", "SN_Cargo_Crate"],
        "rule": "货箱 Root 放到托盘 Stack_Top（z=0.22）；货箱再用自身 Stack_Top（z=1.02）"
                "继续向上堆。",
        "result": "可堆叠货组；托盘顶面 1.23 × 1.02 m。",
    },
    {
        "id": "dock_module_chain",
        "title": "码头结构模块沿 X 平铺",
        "parts": ["SN_Dock_Structure"],
        "rule": "相邻模块 Root 沿 X 平移 8.40 m；Module_Next（+4.20,0,3.02）与下一件的"
                "Module_Prev（−4.20,0,3.02）重合；所有 Root 放在水线高度 z=0。",
        "result": "任意长度的岸壁；顶面 z=3.02、+Y 朝水域。",
    },
    {
        "id": "dock_mooring",
        "title": "系缆设施上码头",
        "parts": ["SN_Dock_Mooring", "SN_Dock_Structure"],
        "rule": "系缆设施 Root 对齐 Socket_Mooring_1/2（±2.40,0,3.02），Root 的安装面"
                "就是码头顶面。",
        "result": "码头上的双柱缆桩 + 系缆环 + 绳圈。",
    },
    {
        "id": "dock_jetty",
        "title": "栈桥接码头",
        "parts": ["SN_Dock_Jetty", "SN_Dock_Structure"],
        "rule": "栈桥 Root = 码头 Root + (0, 2.10, 0)，绕 Z 旋转 +90°（栈桥 +X → 码头 +Y）；"
                "栈桥桥面 z=1.30 正对 Socket_Jetty（0,2.10,1.30），桩伸到水下 z=−1.30。",
        "result": "从岸壁伸向水域的木栈桥（见 kit_assembly_dock.png）。",
    },
    # ---- 批次 3
    {
        "id": "architecture_row",
        "title": "仓库 / 工坊 / 酒馆 / 厂房沿 X 平铺成街区",
        "parts": ["SN_Arch_Warehouse", "SN_Arch_Workshop",
                  "SN_Arch_Tavern", "SN_Arch_Factory"],
        "rule": "Root 全部 z=0；相邻建筑 Module_Next/Prev 对齐：仓库 8.00、工坊 8.00、"
                "酒馆 6.00、厂房 12.00 m。正立面 +X 同向；把整排绕 Z 转 90° 即正面朝街。",
        "result": "任意长度的港区街区；门口 / 雨棚 / 吊车 / 烟囱接口外露（见 kit_assembly_town.png）。",
    },
    {
        "id": "lighthouse_on_reef",
        "title": "灯塔落在礁石 Top",
        "parts": ["SN_Env_Lighthouse", "SN_Env_Reef"],
        "rule": "礁石 Root 放水线 z=0；灯塔 Root = 礁石 Root + (0.60, −0.40, 2.48)"
                "（对齐 SN_Env_Reef_Top；礁石带 4.6 m 石砌基台）。",
        "result": "礁石托起的灯塔；灯塔 Door / Gallery / Lamp 接口可用。",
    },
    {
        "id": "coast_scene",
        "title": "礁石 + 残骸 + 航标浮标",
        "parts": ["SN_Env_Reef", "SN_Env_Wreck", "SN_Env_Buoy"],
        "rule": "三件 Root 都在水线 z=0；残骸在礁石 +X 侧 6–9 m、可绕 Z 旋转 20–30°；"
                "浮标放在航道侧。",
        "result": "可复用的海岸险区小景（见 kit_assembly_coast.png）。",
    },
    {
        "id": "workshop_power_link",
        "title": "工坊 Drive_Shaft 接动力装置",
        "parts": ["SN_Arch_Workshop", "SN_Machinery_PowerUnit"],
        "rule": "工坊 Root 放地面；动力装置 Root 放到工坊 Drive_Shaft（−1.00, −3.08, 1.45）"
                "对应的飞轮轴位置（把 PowerUnit 的 Shaft_Out 对准该点）。",
        "result": "建筑外墙飞轮与蒸汽动力装置同轴，形成工坊动力接口。",
    },
]


def _tri_count(part):
    return sum(max(0, len(f) - 2) for f, _m in part.faces)


def _asset_entry(gen, asset):
    spec = gen.SPECS[asset]
    parts = gen.build_geometry(asset)
    gmin = [1e18] * 3
    gmax = [-1e18] * 3
    tris = 0
    mats = set()
    for _name, (part, _parent) in parts.items():
        tris += _tri_count(part)
        for _f, mat in part.faces:
            mats.add(mat)
        for axis in range(3):
            arr = [v[axis] for v in part.verts]
            gmin[axis] = min(gmin[axis], min(arr))
            gmax[axis] = max(gmax[axis], max(arr))
    size = [round(gmax[i] - gmin[i], 3) for i in range(3)]
    category = CATEGORY[spec["family"]]
    prefix = spec["prefix"]
    v2_roles = {"Mount", "Pivot_Yaw", "Pivot_Pitch", "Recoil", "Muzzle",
                "Anchor_1", "Anchor_2", "Anchor_3", "Anchor_4",
                "Socket_Weapon_Port", "Socket_Weapon_Starboard"}
    v2 = asset.startswith("SN_Weapon_") or asset == "SN_ShipPart_Deck"
    sockets = []
    for key, name, parent, location in gen.SOCKETS[asset]:
        if v2 and name in v2_roles:
            full = "SN_" + name
        else:
            full = prefix + name
        sockets.append({
            "name": full,
            "key": key,
            "parent": "root" if parent == "ROOT" else prefix + parent,
            "location": [round(v, 3) for v in location],
        })
    cfg = gen.build_config(asset, origin=(0.0, 0.0, 0.0))
    return {
        "family": spec["family"],
        "role": spec["role"],
        "description": spec["type"],
        "collection": spec["collection"],
        "root": prefix + "Root",
        "glb": "assets/models/%s/%s.glb" % (category, asset),
        "core_glb": "dev_mods/core/assets/models/%s/%s.glb" % (category, asset),
        "shared_materials": "assets/models/%s/shared_materials" % category,
        "tri_count": tris,
        "tri_budget": spec["tri_budget"],
        "dimensions": {"x": size[0], "y": size[1], "z": size[2]},
        "datum": spec["datum"],
        "materials": sorted(mats),
        "root_extras": cfg.root_props,
        "sockets": sockets,
    }


def main():
    assets = {}
    for gen in GENERATORS:
        for asset in gen.ASSETS:
            assets[asset] = _asset_entry(gen, asset)
    catalog = {
        "schema": "steam-navigator/model-kit-catalog@1",
        "version": "1.2",
        "units": "metres",
        "axes": {"up": "+Z", "forward": "+X"},
        "source_generators": [
            "tools/modeling/generators/kit_batch1_generator.py",
            "tools/modeling/generators/kit_batch2_generator.py",
            "tools/modeling/generators/kit_batch3_generator.py",
        ],
        "briefs": [
            "tools/modeling/briefs/sn_kit_batch1.json",
            "tools/modeling/briefs/sn_kit_batch2.json",
            "tools/modeling/briefs/sn_kit_batch3.json",
        ],
        "contract": "docs/design/KIT_ASSET_LIBRARY.md",
        "families": {
            "weapon_kit": "舰载武器可拼装件：火炮 / 炮架 / 炮塔 / 武器基座",
            "ship_parts": "船体可拼装件：甲板 / 桅杆 / 烟囱 / 货舱盖",
            "machinery_kit": "机械可拼装件：齿轮组 / 卷扬机 / 动力装置",
            "cargo_kit": "货物可拼装件：货箱 / 煤斗 / 储罐 / 托盘",
            "dock_kit": "码头可拼装件：码头结构 / 栈桥 / 系缆设施",
            "architecture_kit": "建筑可拼装件：仓库 / 工坊 / 酒馆 / 厂房",
            "environment_kit": "环境可拼装件：礁石 / 沉船残骸 / 灯塔 / 航标浮标",
        },
        "total_tri": sum(entry["tri_count"] for entry in assets.values()),
        "assets": assets,
        "recipes": RECIPES,
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as handle:
        json.dump(catalog, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    print("KIT_CATALOG_WRITTEN %s assets=%d total_tri=%d" % (
        os.path.relpath(OUT, WORKDIR), len(assets), catalog["total_tri"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
