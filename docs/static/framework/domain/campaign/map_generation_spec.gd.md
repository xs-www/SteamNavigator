# `framework/domain/campaign/map_generation_spec.gd`

> 作用：把 Content Schema 2.0 的 `world_profiles` / `map_configs` / `route_templates`

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MapGenerationSpec` | L1 |
| `MAX_PORTS_THIS_SLICE` | L30 |
| `build(world_profile: ContentDefinition,, map_config: ContentDefinition,, route_templates: Array,, start_profile: ContentDefinition = null) -> Dictionary` | L37 |

适配成世界生成的**内容蓝图**（港口数量 / 原型 / 名称 / 起始约束 / 风险范围）。
2026-10-26 起该蓝图喂给 `WorldGenerator.generate_chart`（海图即唯一世界），不再喂给
已退役的抽象拓扑生成器 `MapGenerator`。

## 契约与约束
- 输出键沿用历史生成字段：`port_count_range / archetypes /
  port_name_keys / start_archetype_tags / required_facility_tags /
  required_facility_max_edges / distance_range / route_risk_range`；
  `CampaignFactory._chart_world_profile` 再补上坐标布局（world size / landmasses /
  port slots）后交给海图生成器。
- **拓扑不在蓝图里**（2026-10-26「任意两港可通航 + 航线需解锁」）：可玩世界恒为完全图，
  生成器不再读边预算，`world_profiles.edge_density` / `edge_count_range` 已退役。
- `port_count_range` 固定为 `[port_count, port_count]`（v2 的 world profile 是目标值，
  不是区间）。D8：当前海图布局固定 5 陆地（每陆 1 港），`port_count` 超过
  `MAX_PORTS_THIS_SLICE` 时 clamp 并 `push_warning`（B4 core 的 port_count 为 5）。
- `route_risk_range` 聚合全部 active `route_templates` 的 `risk_range` 并集（下界取
  最小、上界取最大），海图生成器据此为每条边掷确定性 `base_risk`。`distance_range`
  仍被聚合输出，但**不再影响世界**：海图距离由绘制路径几何决定（见
  NAUTICAL_CHART_SYSTEM §4.1.1），该字段只作 route_template 元数据。
- `start_archetype_tags`：`start_profile.starting_port_tags` 非空时优先（更具体的战役
  起始港约束），否则用 `map_config.start_archetype_tags`。
- 本适配器不读 GameState、不生成世界、不使用 RNG；纯内容 → 纯数据的映射。

模块索引：[framework/domain](../README.md)
