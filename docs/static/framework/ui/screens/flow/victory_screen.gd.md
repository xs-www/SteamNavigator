# `framework/ui/screens/flow/victory_screen.gd`

> 作用：通关总结流程场景：展示种子、构筑、航次、准时率、事故、财务、债务、耐久和最终模块。

- 关键依赖：`SNSectionHeader`、`ClockService`、`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `VictoryScreen` | L1 |
| `action_requested (signal)` | L5 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L15 |

## 契约与约束

- bind(vm, translate) 只消费 victory.view，不查询通关条件或修改存档。
- 再来一局与继续游玩分别发出 play_again/keep_playing action_requested；reset_state 与会话 dismiss 由 Shell 执行。
- on_time_rate 缺失时仅按 summary 的 on_time/voyages 做展示回退，超过 1 的旧百分比值兼容除以 100。

模块索引：[framework/ui](../../README.md)
