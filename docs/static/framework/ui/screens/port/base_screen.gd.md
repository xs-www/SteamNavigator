# `framework/ui/screens/port/base_screen.gd`

> 作用：Phase D3 基地页：渲染 `base.view` 与 shell 提供的可用基地点/建筑/升级/工种/

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `BaseScreen` | L1 |
| `command_requested (signal)` | L17 |
| `COLOR_TEXT` | L19 |
| `COLOR_MUTED` | L20 |
| `COLOR_BRASS` | L21 |
| `COLOR_RED` | L22 |
| `bind(view_model: Dictionary, translate: Callable) -> void` | L28 |

港口仓库物品，并把占领、建造、升级、派工、雇工、生产、存取与等待时间转成
`command_requested` 意图；页面本身不查询、不写状态。

## 契约与约束
- `bind(view_model, translate)` 是唯一入口；view_model 由 Shell 在 `base.view`
  基础上补 `available_sites` / `available_buildings` / `available_upgrades` /
  `available_roles` / `warehouse_items`。
- 未占领只显示基地点与占领按钮；已占领显示建筑卡（施工/升级/订单/工人）、
  仓储存取、雇工与等待按钮；停工时显示红色提示。
- 所有按钮只 emit `command_requested(command, params)`，不在页面内执行命令或刷新。

模块索引：[framework/ui](../../README.md)
