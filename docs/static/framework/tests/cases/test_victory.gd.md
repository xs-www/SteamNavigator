# `framework/tests/cases/test_victory.gd`

> 作用：迭代 1 通关测试：门槛、幂等颁奖、summary 完整性与安装触发。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `test_victory_blocked_before_main_chain_complete() -> void` | L91 |
| `test_victory_requires_shipyard_large_hull_boiler_and_cargo() -> void` | L114 |
| `test_victory_awards_once_with_complete_summary() -> void` | L158 |
| `test_stats_track_income_expense_and_profit() -> void` | L236 |
| `test_shipyard_install_triggers_victory_once() -> void` | L321 |

## 契约与约束

- 主线未全完成或缺少大型船体/锅炉/货舱/造船厂时 check 不颁奖。
- 满足时写入 victory 且再次 check 不重复颁奖；summary 含 §3.4 全字段。
- 真实流程覆盖合同收入、工资、交易、情报与借款不计收入的统计口径。
- ship.install_module 成功安装大型船体时触发一次 run.victory_achieved。

模块索引：[framework/tests](../README.md)
