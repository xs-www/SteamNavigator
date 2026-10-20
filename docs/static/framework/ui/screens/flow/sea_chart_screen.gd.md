# `framework/ui/screens/flow/sea_chart_screen.gd`

> 作用：全屏航海图页（海图系统阶段 2 入口集成）：左侧 `SNSeaChartView` 铺满、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SeaChartScreen` | L1 |
| `close_requested (signal)` | L17 |
| `voyage_requested (signal)` | L18 |
| `COLOR_MUTED` | L20 |
| `PANEL_WIDTH` | L21 |
| `bind(view_model: Dictionary, translate: Callable) -> void` | L29 |

右侧 `SNSeaChartPanel`（320 px）展示选中港口与航线，顶部章节标题 + 关闭按钮。
数据只来自 `sea_chart.view`，经 `bind(view_model, translate)` 注入。

## 契约与约束
- 图上点击港口：视图只改选中态，面板绑定该港与当前港之间的航线数据；
  本页自身不查询、不执行命令。
- 面板「启航」冒泡为 `voyage_requested(port_id)`，由 Shell 路由到出航页并
  预选目的港（锅炉策略仍在出航页确认后才发 `voyage.start`）。
- `close_requested` 交给 Shell 决定返回页；`has_run=false` 时只显示提示文案。
- 选中当前港时面板只显示港口信息（无航线区、无启航按钮）。

模块索引：[framework/ui](../../README.md)
