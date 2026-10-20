# `framework/ui/screens/flow/settlement_screen.gd`

> 作用：抵达结算流程场景：展示航次收入、准时率、延误、剩余资源、交付明细与伤员。

- 关键依赖：`SNBadge`、`SNSectionHeader`、`ClockService`、`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SettlementScreen` | L1 |
| `navigation_requested (signal)` | L5 |
| `TEXT` | L7 |
| `MUTED` | L8 |
| `BRASS` | L9 |
| `RED` | L10 |
| `GREEN` | L11 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L15 |

## 契约与约束

- bind(vm, translate) 接收 Shell 保存的 settlement summary、当前 ship/money 与已解析目的港/委托名称。
- 页面只读展示结算结果；进入港口仅发出 overview navigation_requested。
- 准时、赔付、延误和资源数值不在页面重算领域结果，只做汇总与格式化。

模块索引：[framework/ui](../../README.md)
