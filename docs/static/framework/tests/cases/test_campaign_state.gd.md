# `framework/tests/cases/test_campaign_state.gd`

> 作用：CampaignState 分区测试：分区惰性补齐、探索进度只追加 id、阵营声望夹取，以及分区随存档往返。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `test_sections_are_backfilled_lazily() -> void` | L19 |
| `test_world_progress_tracking() -> void` | L30 |
| `test_codex_discovery_is_idempotent() -> void` | L48 |
| `test_faction_reputation_is_clamped() -> void` | L57 |
| `test_campaign_sections_round_trip_through_save() -> void` | L70 |

## 契约与约束

- `ensure_campaign_sections()` 为 world/codex/factions 补齐默认结构；空状态也能安全读取，不抛异常。
- `mark_region_visited` / `mark_port_visited` / `discover_site` / `discover_codex` 幂等，返回是否新增；空 id 忽略。
- `set_faction_reputation` 夹取到 [-100,100]，未知阵营返回 0；空 faction id 不建条目。
- 新局 `campaign.world.generated=true` 且起始港记入 visited_port_ids；save→load 后 state.hash 与进度一致。

模块索引：[framework/tests](../README.md)
