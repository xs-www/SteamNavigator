# `framework/ui/screens/port/contracts_screen.gd`

> 作用：委托页面场景：按可接/进行中分组渲染主线与普通委托卡，并发出接取或规划出航意图。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ContractsScreen` | L1 |
| `command_requested (signal)` | L22 |
| `navigation_requested (signal)` | L23 |
| `bind(view_model: Dictionary, translate: Callable) -> void` | L29 |

Contract board presentation screen.

Reachability and definition names are composed by the shell. This scene only
renders the board and emits command/navigation intent.

## 外观来源（外部贴图 + SNSkin）
- 委托卡是公告板上的纸面：Theme 变体 `SNParchmentPanel`；卡内正文一律改用 ink
  token（`ink.primary` / `paper.ink_muted` / `brass.shadow`），危险期限仍用
  `state.danger`，保证纸面可读性。任务追踪 / 持有上限 / 已完成面板保持钢制面板。
- 「接受」按钮用 `SNPrimaryButton` + `Button.icon = SNSkin.icon("action_confirm")`
  （`icon_max_width` 16）；按钮 `text` 不变，测试仍按文字查找。
- 其余文字颜色取 `SNSkin.color(token)`；无内联十六进制色与 StyleBoxFlat。
- 尺寸约束：卡片两列网格 16 px 间距、标题最多 2 行、`_button` 高度 38、
  所有节点结构与信号（contract.accept / sea_chart 导航）不变。

模块索引：[framework/ui](../../README.md)
