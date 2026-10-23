# `framework/modding/core_completeness_checker.gd`

> 作用：检查官方 core 包是否提供 MVP 所需的最少内容与构筑，并在 Core 自己发布 Content

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `CoreCompletenessChecker` | L1 |
| `check(hub: RegistryHub, packages: Dictionary, order: Array[String]) -> Dictionary` | L34 |

Schema 2.0 世界内容后追加 Phase B 完整性规则（WORLD_SCHEMA_V2_RUNTIME §5.2）。

## 契约与约束
- 要求 core 存在、required=true 且进入加载顺序。
- 1.0 基线：最低数量（3 船体、≥2 boiler 模块、≥1 cargo 模块、3 策略、4 港口原型
  （`port_templates`）、≥1 起始场景（`starting_scenarios`）、5 主线、2 事件、2 岗位、
  ≥1 quest 等）、必需标签、主线 sequence 1–5、至少一套可解析为
  hull + boiler 模块 + cargo 模块的初始场景。模块数量按统一 `modules` 类型的
  `data.v2_category` 切片计数；utility / cabin 不设硬下限。`map_profiles` 已退役，
  地图调参完整性由 `map_configs` 规则承担。
- Phase B 规则用 presence gate：**Core 来源**的 `world_profiles` 至少 1 条才启用，保证 B4
  之前 Core 没有 v2 内容时基线不红，第三方单独提供的 v2 世界内容也不会触发 Core 规则。
- 硬性：world_profiles / map_configs / start_profiles / weather_profiles / regions 各 ≥1。
- 建议（warning）：route_templates / factions / sites / discoveries 各 ≥1。
- 组合：至少一个 start_profile 解析 world_profile + map_config + starting_scenario；##   start_region_tags 命中至少一个 regions.region_tags；map_config.archetypes 数量 ≥
  对应 world_profile.port_count。
- D1 战斗家族（weapons / damage_types / combat_abilities / enemy_archetypes /
  encounter_tables / loot_tables）的最低数量只统计 `source_mod == "core"` 的定义，
  第三方单独提供的战斗内容不能替代 Core 自己的完整性门槛。
- D2 舰队家族（ship_archetypes / captains / formations / fleet_doctrines）的
  最低数量同样只统计 Core 来源；没有舰队内容时启动保持基线，第三方内容不能替代
  Core 的舰队门槛。引用合法性（hull / modules / weapons / formation / captain
  可指挥船型 / ship_archetype.weapon_sockets 与 hull socket 名和 class）由
  `CrossReferenceValidator._check_fleet` 负责硬校验。

模块索引：[framework/modding](./README.md)
