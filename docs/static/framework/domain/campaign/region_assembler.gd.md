# `framework/domain/campaign/region_assembler.gd`

> 作用：v2 战役的区域装配器（WORLD_SCHEMA_V2_RUNTIME §6.2 步 5）。按

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `RegionAssembler` | L1 |
| `KIND_WEIGHTS` | L25 |
| `SIZE_WEIGHTS` | L33 |
| `MIN_PORT_DENSITY_WEIGHT` | L38 |
| `assemble(world_profile: ContentDefinition,, world: Dictionary,, region_definitions: Array,, rng: RandomNumberGenerator) -> Dictionary` | L44 |

`world_profiles.region_count` 生成区域实例，起始区域由 `start_region_tags` 匹配，
其余按 `kind / size` 权重抽取；每个抽象港口归属一个 `region_id`，区域天气取
`regions.weather_profile`（缺失时回退 `world_profiles.weather_profile`）。

## 契约与约束
- 输出实例形状（写进 `campaign.world.regions[]`）：
  `{id, definition_id, kind, size, weather_profile, port_ids, site_ids}`。
  实例 id 为 `region_0..region_N-1`，`region_0` 固定是起始区域。
- 起始区域 = 按 id 排序后第一个 `has_all_tags(start_region_tags)` 的区域定义；
  没有匹配时不失败（内容问题留给 Completeness 校验），退化为排序后的第一个定义。
- 区域定义数量 < `region_count` 时允许重复实例化同一原型（每个实例仍是独立 id）。
- 港口归属：`port_0`（起始港）固定归 `region_0`；其余港口按各区域的
  `port_density` 加权抽取。权重为 0 的区域仍保留极小权重 0.01，避免"有区域没港口"。
- `world` 是 `ChartWorldProjection.from_chart` 输出的玩法世界字典（只读 `ports`）。
- **确定性**：所有随机来自调用方传入的 `STREAM_CAMPAIGN_WORLD / "regions"` 子流；
  定义数组先按 id 排序，港口按 id 数值排序。抽取序列固定（每个区域一次 randf，
  每个非起始港口一次 randf）。

模块索引：[framework/domain](../README.md)
