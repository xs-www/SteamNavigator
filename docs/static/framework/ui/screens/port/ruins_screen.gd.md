# `framework/ui/screens/port/ruins_screen.gd`

> 作用：Phase D5 遗迹远征页：渲染 `expedition.view` 与可用遗迹原型，展示房间进度、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `RuinsScreen` | L1 |
| `command_requested (signal)` | L15 |
| `COLOR_TEXT` | L17 |
| `COLOR_MUTED` | L18 |
| `COLOR_BRASS` | L19 |
| `COLOR_RED` | L20 |
| `bind(view_model: Dictionary, translate: Callable) -> void` | L26 |

当前事件选项、奖励日志与永久遗物，并把开始/进入/选择/撤退转成
`command_requested` 意图；页面本身不查询、不写状态。

## 契约与约束
- `bind(view_model, translate)` 是唯一入口；view_model 由 Shell 在
  `expedition.view` 基础上补 `available_ruins`。
- 未开始：列出遗迹与开始按钮；进行中：房间进度、进入/选项/撤退按钮、日志。
- 所有按钮只 emit `command_requested(command, params)`。

模块索引：[framework/ui](../../README.md)
