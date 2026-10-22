# `framework/domain/campaign/faction_assembler.gd`

> 作用：v2 战役的阵营装配器（WORLD_SCHEMA_V2_RUNTIME §6.2 步 8）。按

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `FactionAssembler` | L1 |
| `DEFAULT_HOSTILE_BELOW` | L20 |
| `DEFAULT_FRIENDLY_AT` | L21 |
| `assemble(world_profile: ContentDefinition,, start_profile: ContentDefinition,, faction_definitions: Array,, rng: RandomNumberGenerator) -> Dictionary` | L26 |
| `attitude_for(reputation: int, raw_thresholds: Variant) -> String` | L61 |

`world_profiles.faction_count` 从 active `factions` 定义中实例化 ≤N 个阵营，写
`campaign.factions`：初始声望 = `start_profiles.starting_reputation` +
`factions.starting_reputation`，`attitude` 由 `attitude_thresholds` 派生。

## 契约与约束
- 输出形状（每个 faction id 一项，与 `GameState.FACTION_ENTRY_DEFAULTS` 一致）：
  `{reputation, attitude, discovered:false, met_at:0.0}`。
- `reputation` clamp 到 [-100, 100]；`attitude`：`reputation < hostile_below` →
  `"hostile"`；`reputation >= friendly_at` → `"friendly"`；否则 `"neutral"`。
  （阈值来自内容；缺失时用 -30 / 30 的防御兜底，不写死在框架数值里参与调参。）
- 定义数量 > faction_count 时用确定性无放回抽样；≤ 时按 id 顺序全取。
- **确定性**：随机来自 `STREAM_CAMPAIGN_WORLD / "factions"` 子流；定义按 id 排序。
- 1.0 旧档不经过本装配器；`ensure_campaign_sections()` 会给旧条目惰性补齐字段。

模块索引：[framework/domain](../README.md)
