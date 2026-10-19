# `framework/tests/cases/test_save_migration.gd`

> 作用：存档 Schema 2.0 迁移测试：v1 payload 加载为持久战役状态，v2 往返不迁移，缺失 campaign 回填，未知版本拒绝。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `test_v1_save_migrates_to_v2_campaign() -> void` | L48 |
| `test_v2_save_round_trips_campaign_without_migration() -> void` | L71 |
| `test_missing_campaign_is_backfilled_in_v2_payload() -> void` | L103 |
| `test_unsupported_save_schema_is_rejected() -> void` | L119 |

## 契约与约束

- 手写 1.0 payload 验证 save_schema → 2.0、state schema → 2.0、campaign/id/created_at/playtime 回填与 migrated_from 记录。
- 验证 v2 写入/读取的 save_schema、state_schema、content_schema 与 state hash 往返一致。
- 验证缺 campaign 的 2.0 payload 惰性补齐并产生 warning；3.0 等未知版本返回结构化错误。

模块索引：[framework/tests](../README.md)
