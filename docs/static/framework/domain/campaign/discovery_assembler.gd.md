# `framework/domain/campaign/discovery_assembler.gd`

> 作用：v2 战役的图鉴装配器（WORLD_SCHEMA_V2_RUNTIME §6.2 步 9）。按

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `DiscoveryAssembler` | L1 |
| `MAX_CANDIDATES_PER_SITE` | L23 |
| `RARITY_WEIGHTS` | L24 |
| `UNDISCOVERED_AT_TIME` | L31 |
| `assemble(discovery_definitions: Array,, sites: Array,, regions: Array,, site_definitions_by_id: Dictionary,, region_definitions_by_id: Dictionary,, rng: RandomNumberGenerator) -> Dictionary` | L37 |

`weight / rarity / source_site_kinds / region_kinds / requires_tags` 为每个地点挂
发现候选（`site.discovery_ids`），并把候选对应的来源站点写进
`campaign.codex.entries`（`{site_id, at_time:-1.0}` 表示「尚未发现」的候选来源）。

## 契约与约束
- `campaign.codex` 形状保持 §6.3：`{discovered_ids: [], entries: {}}`。生成期
  `discovered_ids` 恒为空；`entries` 预填候选 discovery → 来源站点（`at_time = -1.0`
  是「未发现」哨兵），真正发现时由领域层写 `at_time` 并加入 `discovered_ids`。
- 每个地点最多挂 `MAX_CANDIDATES_PER_SITE` 个候选；同一 discovery 可被多个地点引用时
  `entries` 只保留第一个来源（其余仍出现在 site.discovery_ids）。
- 过滤：`source_site_kinds` / `region_kinds` 非空时必须匹配；`requires_tags` 必须
  同时满足**地点定义 tags ∪ 区域定义 tags**。候选为空的地点不挂 discovery_ids。
- `weight` 与 `rarity` 共同决定候选权重（common 1.0 / uncommon 0.6 / rare 0.3 /
  unique 0.1）；无可用候选时不抽取、不消耗随机数。
- **确定性**：随机来自 `STREAM_CAMPAIGN_WORLD / "discoveries"` 子流；定义按 id 排序；
  站点按数组顺序（即 `site_0..M-1`）遍历。

模块索引：[framework/domain](../README.md)
