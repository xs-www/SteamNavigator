# `framework/ui/screens/port/auto_trade_screen.gd`

> 作用：Phase D4 自动贸易页：渲染 `auto_trade.view` 与可用策略，展示阶段、航程、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `AutoTradeScreen` | L1 |
| `command_requested (signal)` | L15 |
| `COLOR_TEXT` | L17 |
| `COLOR_MUTED` | L18 |
| `COLOR_BRASS` | L19 |
| `COLOR_RED` | L20 |
| `COLOR_GREEN` | L21 |
| `bind(view_model: Dictionary, translate: Callable) -> void` | L27 |

自动货舱、累计利润与最近日志，并把启动/停止/暂停/恢复/等待转成
`command_requested` 意图；页面本身不查询、不写状态。

## 契约与约束
- `bind(view_model, translate)` 是唯一入口；view_model 由 Shell 在
  `auto_trade.view` 基础上补 `available_policies`。
- 未启动：列出策略与启动按钮；运行中：状态徽章、货舱、日志、暂停/恢复/停止。
- 所有按钮只 emit `command_requested(command, params)`。

模块索引：[framework/ui](../../README.md)
