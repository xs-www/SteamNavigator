# `framework/services/save_migrations.gd`

> 作用：存档 payload 版本迁移与内容版本表（B5）：1.x → 2.0、campaign 元数据回填、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SaveMigrations` | L1 |
| `CURRENT_SAVE_SCHEMA` | L23 |
| `CURRENT_STATE_SCHEMA` | L24 |
| `migrate(payload: Dictionary) -> Dictionary` | L28 |
| `prepare_for_save(state: Dictionary) -> void` | L112 |

`campaign.setup.content_versions` 快照/推断/漂移警告，以及保存前的版本快照。

## 契约与约束
- `save_schema`/`state_schema` 当前 2.0；1.x 只做兼容增量，保留 run/world/ship 字段。
- D3：新档由 `prepare_for_save()` 从 `ContentTypes.SCHEMA_VERSIONS` 快照全部类型版本；
  旧档缺表时用当前注册表补齐缺失类型（C4 起 `starting_scenarios` / `map_configs` 均为
  2.0，`map_profiles` 已退役，不再做 1.0 类型推断）。
- 存档里已记录的版本与当前运行时不符时只写 `content version drift: <type> save=... current=...`
  warning；存档仍可读，不重排世界、不重新随机。
- 缺失的 campaign 分区由 `GameState.ensure_campaign_sections` 逐段回填并写入 warnings；
  未知主版本直接拒绝。

模块索引：[framework/services](./README.md)
