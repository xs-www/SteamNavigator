# `framework/tests`

> 无头测试与冒烟脚本。覆盖加载链、确定性、经济、航行、存档、ZIP 与框架约束。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `cases/test_contract_flow.gd` | 按主题拆分的 40 个测试。 | 本页 |
| `cases/test_events_effects.gd` | 按主题拆分的 40 个测试。 | 本页 |
| `cases/test_map_constraints.gd` | 按主题拆分的 40 个测试。 | 本页 |
| `cases/test_market_trade.gd` | 按主题拆分的 40 个测试。 | 本页 |
| `cases/test_mod_loading.gd` | 按主题拆分的 40 个测试。 | 本页 |
| `cases/test_no_core_ids.gd` | 按主题拆分的 40 个测试。 | 本页 |
| `cases/test_patches.gd` | 按主题拆分的 40 个测试。 | 本页 |
| `cases/test_registry.gd` | 按主题拆分的 40 个测试。 | 本页 |
| `cases/test_rng.gd` | 按主题拆分的 40 个测试。 | 本页 |
| `cases/test_run_pipeline.gd` | 按主题拆分的 40 个测试。 | 本页 |
| `cases/test_save_load.gd` | 按主题拆分的 40 个测试。 | 本页 |
| `cases/test_schema_validator.gd` | 按主题拆分的 40 个测试。 | 本页 |
| `cases/test_semver_range.gd` | 按主题拆分的 40 个测试。 | 本页 |
| `cases/test_ship_upgrade.gd` | 按主题拆分的 40 个测试。 | 本页 |
| `cases/test_zip_pack.gd` | 按主题拆分的 40 个测试。 | 本页 |
| `smoke_load.gd` | 手动冒烟：加载 Core 并打印启动报告。 | 本页 |
| `smoke_play.gd` | 手动冒烟：开局、预览、出航、事件选择。 | 本页 |
| `test_case.gd` | 测试断言与 Core bootstrap 辅助。 | 本页 |
| `test_runner.gd` | 无头测试发现、执行、汇总与退出码。 | 本页 |

## 模块契约

- 测试入口：`godot --headless --path . --script res://framework/tests/test_runner.gd`。
- `test_case.gd` 提供断言与 Core 启动辅助；每个用例独立 bootstrap。
- 测试源码可以引用 `core:*` ID；`test_no_core_ids.gd` 只扫描非测试框架代码。
