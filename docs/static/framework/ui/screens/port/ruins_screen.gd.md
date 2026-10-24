# `framework/ui/screens/port/ruins_screen.gd`

> 作用：Phase D5 遗迹远征页：渲染 `expedition.view` 与可用遗迹原型，展示房间进度、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `RuinsScreen` | L1 |
| `command_requested (signal)` | L23 |
| `bind(view_model: Dictionary, translate: Callable) -> void` | L30 |

当前事件选项、奖励日志与永久遗物，并把开始/进入/选择/撤退转成
`command_requested` 意图；页面本身不查询、不写状态。

## 契约与约束
- `bind(view_model, translate)` 是唯一入口；view_model 由 Shell 在
  `expedition.view` 基础上补 `available_ruins`。
- 未开始：列出遗迹与开始按钮；进行中：房间进度、进入/选项/撤退按钮、日志。
- 所有按钮只 emit `command_requested(command, params)`。

## 外观来源（外部贴图 + SNSkin）
- 面板用 Theme 变体 `SNInsetPanel`（钢制凹槽）；状态徽标改用 `SNBadge`
  （13 px 中性纹理铭牌）。开始 / 进入按钮挂
  `Button.icon = SNSkin.icon("status_route")` + `icon_max_width` 16（远征路线语义），
  其余操作仍是 30 px 高的 `SNGhostButton`；按钮 `text` 不变。
- 文字色取 `SNSkin.color(token)`（text.light / text.muted / brass.highlight）；
  本文件无内联十六进制色与 StyleBoxFlat。

模块索引：[framework/ui](../../README.md)
