# `framework/tests/cases/test_save_migration.gd`

> 作用：存档 Schema 2.0 迁移与内容版本表（B5）测试：v1 payload 升级、v2 往返、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `test_v1_save_migrates_to_v2_campaign() -> void` | L64 |
| `test_v2_save_round_trips_campaign_without_migration() -> void` | L91 |
| `test_missing_campaign_is_backfilled_in_v2_payload() -> void` | L124 |
| `test_new_save_snapshots_content_versions() -> void` | L140 |
| `test_v2_save_without_content_versions_is_backfilled() -> void` | L164 |
| `test_content_version_drift_warns_without_reordering_the_world() -> void` | L184 |
| `test_v2_campaign_save_round_trips_content_versions_and_ids() -> void` | L213 |
| `test_unsupported_save_schema_is_rejected() -> void` | L247 |

`campaign.setup.content_versions` 快照/推断/漂移警告，以及旧档不重排世界。

## 契约与约束
- 1.0 payload 加载后 save_schema/state_schema → 2.0，campaign 元数据/分区回填，
  `content_versions` 推断 `starting_builds/map_profiles → 1.0` 并用当前注册表补齐。
- v2 缺失 `content_versions` 时加载补齐并产生 warning；已有版本与运行时不一致时
  只产生 `content version drift` warning，存档仍可读。
- 新存档必须写全 `ContentTypes.SCHEMA_VERSIONS` 快照；v2 战役的
  `map_config_id` / `world_profile_id` / `start_profile_id` 与空 `map_profile_id` 往返保持。
- 同一存档多次加载 world/hash 不变（不重新生成世界）；3.0 等未知版本拒绝。

模块索引：[framework/tests](../README.md)
