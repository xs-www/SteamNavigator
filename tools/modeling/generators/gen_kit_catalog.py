# -*- coding: utf-8 -*-
# @static-doc
# 作用：从批次 1/2/3/4 生成器的纯几何数据生成机器可读的模型素材库目录
# `tools/modeling/kit_catalog.json`（资产 / 尺寸 / tri / 材质 / socket 接口 / 装配
# 配方），并把 M0-5 的 LOD1 计划（`lod1_kit_ships_plan.json`）合并成逐件 `lod1` 块与
# 顶层 `lod1` 汇总（路径 / LOD1 tri / 比例 / 上限 / 字节 / bbox）。
#
# 批次 4（M1-1 architecture_kit 扩展）加入 6 件可围合建筑件；配方新增「可围合基地」
# 「道路平铺」「工坊扩建接动力」「仓库变体装卸」四条。
# 批次 5（M1-2 base_kit）加入 5 件生产建筑（锯木厂 / 冶炼炉 / 铸造车间 / 仓库堆场 /
# 防御塔）；配方新增「木料生产链」「冶炼-铸造链」「堆场入库」「防御塔炮位」四条。
#
# 用法：
#     python tools/modeling/generators/gen_kit_catalog.py
#
# 约定：LOD1 段只合并 `kind == "kit"` 的 26 件（船 LOD1 在 Core manifest 登记）；
# 计划文件缺失时目录照常生成，只是没有 `lod1` 字段（向后兼容）。
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
import kit_batch4_generator as gen4  # noqa: E402
import kit_batch5_generator as gen5  # noqa: E402

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
OUT = os.path.join(WORKDIR, "tools", "modeling", "kit_catalog.json")
LOD1_PLAN = os.path.join(WORKDIR, "tools", "modeling", "lod1_kit_ships_plan.json")
GENERATORS = [gen1, gen2, gen3, gen4, gen5]

CATEGORY = {
    "weapon_kit": "weapons",
    "ship_parts": "ship_parts",
    "machinery_kit": "machinery",
    "cargo_kit": "cargo",
    "dock_kit": "dock",
    "architecture_kit": "architecture",
    "environment_kit": "environment",
    "base_kit": "base",
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
    # ---- 批次 4（M1-1 architecture_kit 扩展）
    {
        "id": "enclosed_base",
        "title": "可围合基地：围墙 + 大门 + 道路",
        "parts": ["SN_Arch_Road", "SN_Arch_Perimeter_Wall", "SN_Arch_Gate"],
        "rule": "道路 Root 放地面（8x8 平铺）；围墙 Module_Next/Prev 按 ±4.0 m 首尾相接；"
                "大门 Gateway 朝外、Module_Next/Prev 接围墙两端（墙顶 z=3.90 对齐）；"
                "围墙 Wall_Top 可再叠垛口装饰。",
        "result": "任意长宽的基地边界，门洞净宽 3.7 m、净高 3.8 m（见 preview 拼装图）。",
    },
    {
        "id": "base_road_grid",
        "title": "道路四向平铺",
        "parts": ["SN_Arch_Road"],
        "rule": "单块 8x8 m；Module_Next/Prev 沿 X、Module_Left/Right 沿 Y，间距 8 m；"
                "顶面 z=0.29，道路边缘路缘带在 ±Y 两侧（沿 Y 相接时作街口/路缘线）。",
        "result": "基地主干道与广场铺装；凹凸面全部贴地，无需额外地基。",
    },
    {
        "id": "annex_power_link",
        "title": "工坊扩建接工坊动力",
        "parts": ["SN_Arch_Workshop_Annex", "SN_Arch_Workshop"],
        "rule": "扩建放在工坊 −Y 侧（module 6x4 对齐）；扩建 Drive_Shaft (+Y 墙, z=1.45) "
                "与工坊 Drive_Shaft (−Y 墙, z=1.45) 同轴；Chimney 朝向天空、Coal_Hatch 临煤场。",
        "result": "锅炉房扩建，烟囱与送煤槽成型，传动轴把动力送回工坊飞轮。",
    },
    {
        "id": "warehouse_loading",
        "title": "仓库变体装卸位",
        "parts": ["SN_Arch_Warehouse_Variant", "SN_Arch_Loading_Platform"],
        "rule": "仓库变体 +X 山墙装载门（Door_Front, z=0）对接装卸平台 Dock_Edge "
                "(z=1.25) 或月台；平台 Hoist 吊索在临水/临轨边外挑；"
                "仓库外楼梯 14 级通上层侧门（z=3.48）。",
        "result": "山墙吊货门 + 月台吊货梁 + 上层外楼梯的完整装卸节点。",
    },
    # ---- 批次 5（M1-2 base_kit 生产建筑）
    {
        "id": "timber_chain",
        "title": "木料生产链：锯木厂 + 动力装置",
        "parts": ["SN_Base_Sawmill", "SN_Machinery_PowerUnit"],
        "rule": "锯木厂 Root 放地面；PowerUnit 的 Shaft_Out 对准锯木厂 Drive_Shaft "
                "(0, 3.20, 1.45)；原木从 Log_Input 上料，木料在 Timber_Output 出料。",
        "result": "蒸汽动力驱动的锯木厂，原木坡道 + 锯盘 + 木料堆成型。",
    },
    {
        "id": "smelt_foundry_chain",
        "title": "冶炼 → 铸造：冶炼炉 + 铸造车间",
        "parts": ["SN_Base_Smelter", "SN_Base_Foundry"],
        "rule": "冶炼炉 Molten_Out (3.40, 0, 0.70) 与铸造车间 Molten_In (-3.40, 0, 1.10) "
                "按 4 m 网格对齐（铁水沟可跨接）；冶炼炉 Coal_Input / Ore_Input 接料仓；"
                "铸造车间 Hoist 为行车吊点、Pour_Point 为浇注位。",
        "result": "从矿石到铸件的完整冶炼-铸造链，冲天炉/行车/浇包/模具区可读。",
    },
    {
        "id": "stockyard_intake",
        "title": "堆场入库：仓库堆场 + 货物套件",
        "parts": ["SN_Base_Stockyard", "SN_Cargo_Crate", "SN_Cargo_Pallet",
                  "SN_Cargo_Tank"],
        "rule": "堆场 Root 放地面；Gate_In 朝道路；Scale 为地磅台面（z=0.18）；"
                "Gantry Hoist 为吊装点，Storage 为堆场中心；货物 Root 落在堆场铺面上。",
        "result": "带围栏、堆垛、龙门吊、地磅与门卫亭的基地入库/堆存节点。",
    },
    {
        "id": "defense_tower_gun",
        "title": "防御塔炮位：防御塔 + 武器基座",
        "parts": ["SN_Base_Defense_Tower", "SN_Weapon_Pedestal"],
        "rule": "防御塔 Root 放地面；Weapon_Mount 在炮位平台中心（0, 0, 9.20）；"
                "武器基座 Root 对齐 Weapon_Mount，Searchlight/Flag 为附属接口；"
                "Magazine 为弹药库、Ladder_Foot 为登塔落点。",
        "result": "基地防御节点：炮位平台 + 弹药库 + 探照灯 + 旗杆 + 登塔梯。",
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


def _load_lod1_plan(assets):
    """Merge the M0-5 LOD1 plan into the catalog (machine-readable LOD1 paths)."""
    if not os.path.exists(LOD1_PLAN):
        return {}, None
    with open(LOD1_PLAN, encoding="utf-8") as handle:
        plan = json.load(handle)
    merged = {}
    for row in plan.get("assets", []):
        asset = row.get("asset")
        if row.get("kind") != "kit" or asset not in assets:
            continue
        merged[asset] = {
            "glb": row["lod1_glb"],
            "core_glb": row["lod1_core_glb"],
            "tri_count": row["lod1_tri"],
            "ratio": row["lod1_ratio"],
            "cap_ratio": row["lod1_cap_ratio"],
            "cap_tri": row["lod1_cap_tri"],
            "bytes": row["lod1_bytes"],
            "materials": row["materials"],
            "bbox_size": row["bbox_size"],
            "bbox_min": row["bbox_min"],
        }
    kit_rows = [row for row in plan.get("assets", []) if row.get("kind") == "kit"]
    summary = {
        "schema": plan.get("schema"),
        "generator": plan.get("generator"),
        "verifier": plan.get("verifier"),
        "plan": os.path.relpath(LOD1_PLAN, WORKDIR).replace("\\", "/"),
        "caps": plan.get("caps"),
        "assets": len(kit_rows),
        "lod0_tri": sum(int(row["lod0_tri"]) for row in kit_rows),
        "lod1_tri": sum(int(row["lod1_tri"]) for row in kit_rows),
        "lod1_bytes": sum(int(row["lod1_bytes"]) for row in kit_rows),
    }
    return merged, summary


def main():
    assets = {}
    for gen in GENERATORS:
        for asset in gen.ASSETS:
            assets[asset] = _asset_entry(gen, asset)
    lod1_assets, lod1_summary = _load_lod1_plan(assets)
    for asset, entry in lod1_assets.items():
        assets[asset]["lod1"] = entry
    catalog = {
        "schema": "steam-navigator/model-kit-catalog@1",
        "version": "1.5",
        "units": "metres",
        "axes": {"up": "+Z", "forward": "+X"},
        "source_generators": [
            "tools/modeling/generators/kit_batch1_generator.py",
            "tools/modeling/generators/kit_batch2_generator.py",
            "tools/modeling/generators/kit_batch3_generator.py",
            "tools/modeling/generators/kit_batch4_generator.py",
            "tools/modeling/generators/kit_batch5_generator.py",
        ],
        "briefs": [
            "tools/modeling/briefs/sn_kit_batch1.json",
            "tools/modeling/briefs/sn_kit_batch2.json",
            "tools/modeling/briefs/sn_kit_batch3.json",
            "tools/modeling/briefs/sn_kit_batch4_architecture_extension.json",
            "tools/modeling/briefs/sn_kit_batch5_base_kit.json",
        ],
        "contract": "docs/design/KIT_ASSET_LIBRARY.md",
        "lod1_generator": "tools/modeling/generators/sn_lod1_kit_ships_generator.py",
        "lod1": lod1_summary,
        "families": {
            "weapon_kit": "舰载武器可拼装件：火炮 / 炮架 / 炮塔 / 武器基座",
            "ship_parts": "船体可拼装件：甲板 / 桅杆 / 烟囱 / 货舱盖",
            "machinery_kit": "机械可拼装件：齿轮组 / 卷扬机 / 动力装置",
            "cargo_kit": "货物可拼装件：货箱 / 煤斗 / 储罐 / 托盘",
            "dock_kit": "码头可拼装件：码头结构 / 栈桥 / 系缆设施",
            "architecture_kit": "建筑可拼装件：仓库 / 工坊 / 酒馆 / 厂房 + 围墙 / 大门 / 道路 / 装卸平台 / 仓库变体 / 工坊扩建（批次 4）",
            "environment_kit": "环境可拼装件：礁石 / 沉船残骸 / 灯塔 / 航标浮标",
            "base_kit": "基地生产建筑：锯木厂 / 冶炼炉 / 铸造车间 / 仓库堆场 / 防御塔（批次 5）",
        },
        "total_tri": sum(entry["tri_count"] for entry in assets.values()),
        "total_lod1_tri": lod1_summary["lod1_tri"] if lod1_summary else 0,
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
