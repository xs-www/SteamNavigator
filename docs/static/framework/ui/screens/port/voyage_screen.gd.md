# `framework/ui/screens/port/voyage_screen.gd`

> 作用：出航规划页面场景：选择目的港与锅炉策略，展示完整 voyage.preview 并发出出航意图。

- 关键依赖：`SNSectionHeader`、`ClockService`、`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `VoyageScreen` | L1 |
| `selection_changed (signal)` | L5 |
| `command_requested (signal)` | L6 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L17 |

## 契约与约束

- bind(vm, translate) 接收 Shell 已查询的 preview；页面不调用 voyage.preview，不自行计算速度、消耗、风险或可行性。
- 选择变化发出 selection_changed(destination_id, strategy_id)，由 Shell 保存选择、重新查询并刷新预览。
- 出航按钮只在 preview.feasible 时可用，并发出 voyage.start command_requested，参数取当前绑定的目的港和策略。
- 阻断原因、风险来源、委托准时性与目的港设施均来自预览/组合模型，页面只格式化展示。

模块索引：[framework/ui](../../README.md)
