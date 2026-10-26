# `framework/domain/campaign/route_assembler.gd`

> 作用：v2 战役的航路装配器（WORLD_SCHEMA_V2_RUNTIME §6.2 步 7）。为海图世界的每条边

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `RouteAssembler` | L1 |
| `assemble(routes: Array,, regions: Array,, region_for_port: Dictionary,, route_definitions: Array,, rng: RandomNumberGenerator) -> Array` | L23 |

按两端港口所属区域的 `kind` 过滤 `route_templates`，抽取一条可用模板并把
`{id, kind, distance_range, risk_range, travel_time_range, bidirectional,
encounter_table}` 写入该边的 `template` 元数据。

## 契约与约束
- **不动几何数值**：海图边的 `distance`（绘制路径折线长度）与 `base_risk`（海图生成器
  按模板 risk_range 掷出）保持原样；模板只作为声明式元数据（后续切片用于遭遇 / 时间细化）。
- 候选过滤：模板 `region_kinds` 为空 = 任意；非空时只要包含**任一端**区域的 kind
  即可用。没有候选时写入空 `template` 字典，不删边、不失败。
- 输出为输入 routes 的深拷贝数组，不修改海图世界字典。
- **确定性**：随机来自 `STREAM_CAMPAIGN_WORLD / "routes"` 子流；模板按 id 排序后
  均匀抽取（模板 schema 无 weight 字段）。

模块索引：[framework/domain](../README.md)
