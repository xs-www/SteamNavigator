# `framework/services/save_migrations.gd`

> 作用：存档 payload 版本迁移：当前 save schema 2.0，支持 1.x → 2.0 并回填持久战役元数据。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SaveMigrations` | L1 |

## 契约与约束

- `save_schema` 描述 payload 包装，`state_schema` 描述 GameState 数据；2.0 之前旧档的 content_schema 实际存放 state schema。
- 1.x → 2.0 只做兼容增量：保留既有 run/world/ship 字段，补 campaign、schema_version、state_schema 与 content_schema。
- campaign id 从 seed 确定性生成；created_at 优先沿用 payload/run 时间；playtime 取 game_time。
- 缺失的 campaign 分区（world/codex/factions）由 `GameState.ensure_campaign_sections` 回填，并逐段写入 warnings。
- 未知主版本直接拒绝；迁移结果携带 warnings 供 UI/日志显示。

模块索引：[framework/services](./README.md)
