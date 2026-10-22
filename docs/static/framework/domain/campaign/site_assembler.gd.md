# `framework/domain/campaign/site_assembler.gd`

> 作用：v2 战役的地点装配器（WORLD_SCHEMA_V2_RUNTIME §6.2 步 6）。每个区域按

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SiteAssembler` | L1 |
| `assemble(world_profile: ContentDefinition,, regions: Array,, site_definitions: Array,, rng: RandomNumberGenerator) -> Array` | L28 |

`world_profiles.sites_per_region` 生成地点实例，按 `weight` + `region_kinds` 过滤抽取
`sites` 定义，写入实例 id / region / port / kind / loot / encounter 引用，并把
`site_ids` 回填到所属区域。

## 契约与约束
- 输出实例形状（写进 `campaign.world.sites[]`）：
  `{id, definition_id, region_id, port_id, kind, discovered:false, repeatable,
  loot_table, encounter_table}`；实例 id 为 `site_0..site_M-1`（跨区域连续编号）。
- 每个区域**恰好** `sites_per_region` 个（本切片按任务契约的固定数量；内容侧的
  `site_density` 留给后续切片在「区域地图」层细化）。
- 候选过滤：`sites.region_kinds` 为空 = 任意区域；非空时必须含该区域 `kind`。
  若区域类型把所有候选都过滤掉，退化为全量候选（内容缺失不静默失败），仍无候选
  则跳过该区域。
- `port_id`：区域内港口按 id 数值排序后轮转（`site_index % port_ids.size()`）；
  区域没有港口时留空字符串。
- **确定性**：随机来自 `STREAM_CAMPAIGN_WORLD / "sites"` 子流；定义数组按 id 排序；
  每个地点一次加权 randf，抽取顺序固定（区域顺序 → 地点序号）。

模块索引：[framework/domain](../README.md)
