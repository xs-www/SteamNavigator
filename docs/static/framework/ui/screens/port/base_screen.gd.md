# `framework/ui/screens/port/base_screen.gd`

> 作用：Phase D3 基地页：渲染 `base.view` 与 shell 提供的可用基地点/建筑/升级/工种/

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `BaseScreen` | L1 |
| `command_requested (signal)` | L27 |
| `bind(view_model: Dictionary, translate: Callable) -> void` | L34 |

港口仓库物品，并把占领、建造、升级、派工、雇工、生产、存取与等待时间转成
`command_requested` 意图；页面本身不查询、不写状态。

## 契约与约束
- `bind(view_model, translate)` 是唯一入口；view_model 由 Shell 在 `base.view`
  基础上补 `available_sites` / `available_buildings` / `available_upgrades` /
  `available_roles` / `warehouse_items`。
- 未占领只显示基地点与占领按钮；已占领显示建筑卡（施工/升级/订单/工人）、
  仓储存取、雇工与等待按钮；停工时显示红色提示。
- 所有按钮只 emit `command_requested(command, params)`，不在页面内执行命令或刷新。

## 外观来源（外部贴图 + SNSkin）
- 面板用 Theme 变体 `SNInsetPanel`（钢制凹槽）；状态徽标改用 `SNBadge`
  （中性 `SNBadge` 变体的纹理铭牌，13 px 字号保持旧视觉尺寸），不再返回
  PanelContainer + 内嵌 Label 的临时徽标。
- 操作按钮统一 `SNGhostButton`（30 px 高）；建造按钮额外挂
  `Button.icon = SNSkin.icon("action_add")` + `icon_max_width` 16，不新增包装容器、
  不改按钮文字（测试按文字查找）。
- 文字与状态色取 `SNSkin.color(token)`（text.light / text.muted /
  brass.highlight / state.danger）；本文件无内联十六进制色与 StyleBoxFlat。

模块索引：[framework/ui](../../README.md)
