# `framework/ui/screens/port/auto_trade_screen.gd`

> 作用：Phase D4 自动贸易页：渲染 `auto_trade.view` 与可用策略，展示阶段、航程、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `AutoTradeScreen` | L1 |
| `command_requested (signal)` | L23 |
| `bind(view_model: Dictionary, translate: Callable) -> void` | L30 |

自动货舱、累计利润与最近日志，并把启动/停止/暂停/恢复/等待转成
`command_requested` 意图；页面本身不查询、不写状态。

## 契约与约束
- `bind(view_model, translate)` 是唯一入口；view_model 由 Shell 在
  `auto_trade.view` 基础上补 `available_policies`。
- 未启动：列出策略与启动按钮；运行中：状态徽章、货舱、日志、暂停/恢复/停止。
- 所有按钮只 emit `command_requested(command, params)`。

## 外观来源（外部贴图 + SNSkin）
- 面板用 Theme 变体 `SNInsetPanel`（钢制凹槽）；摘要徽标改用 `SNBadge`
  （13 px 中性纹理铭牌），不再返回 PanelContainer + Label 的临时徽标。
- 启停按钮挂 `Button.icon = SNSkin.icon("status_route")` + `icon_max_width` 16
  （航线语义），其余操作仍是 `SNGhostButton`（30 px 高）；按钮 `text` 不变。
- 文字色取 `SNSkin.color(token)`（text.light / text.muted / brass.highlight）；
  本文件无内联十六进制色与 StyleBoxFlat。

模块索引：[framework/ui](../../README.md)
