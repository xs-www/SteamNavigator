# `framework/domain/campaign/map_generation_spec.gd`

> 作用：把 Content Schema 2.0 的 `world_profiles` / `map_configs` / `route_templates`

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MapGenerationSpec` | L1 |
| `MAX_PORTS_THIS_SLICE` | L27 |
| `EDGE_DENSITY_MAX_EXTRA` | L29 |
| `build(world_profile: ContentDefinition,, map_config: ContentDefinition,, route_templates: Array,, start_profile: ContentDefinition = null) -> Dictionary` | L35 |

适配成 `MapGenerator.generate_spec()` 的输入字典，让 v2 战役复用 1.0 抽象海图生成器
而无需给生成器塞一个已退役的 map-profile 定义。

## 契约与约束
- 输出键沿用历史生成字段：`port_count_range / archetypes /
  port_name_keys / start_archetype_tags / required_facility_tags /
  required_facility_max_edges / edge_count_range / distance_range / route_risk_range`，
  因此 `MapGenerator` 的 `_build_graph` / `_try_generate` 逻辑与旧路径完全一致。
- `port_count_range` 固定为 `[port_count, port_count]`（v2 的 world profile 是目标值，
  不是区间）。D8：Phase B 首个切片孪生世界固定 5 陆地布局，`port_count` 超过
  `MAX_PORTS_THIS_SLICE` 时 clamp 并 `push_warning`（B4 core 的 port_count 为 5）。
- `edge_density` 存在时派生 `edge_count_range`：最小边 = 港口数（生成树 N-1 加一条
  分叉边，保证"至少一个环"硬约束），最多再加 `round(density × 3)` 条；缺失时**不写**
  该键，交由 `MapGenerator._build_graph` 的 1.0 默认逻辑 `[port_count, port_count+2]`。
- `distance_range` / `route_risk_range` 聚合全部 active `route_templates` 的并集
  （下界取最小、上界取最大）；没有可用模板时不写该键，沿用 1.0 默认值。
- `start_archetype_tags`：`start_profile.starting_port_tags` 非空时优先（更具体的战役
  起始港约束），否则用 `map_config.start_archetype_tags`。
- 本适配器不读 GameState、不生成世界、不使用 RNG；纯内容 → 纯数据的映射。

模块索引：[framework/domain](../README.md)
