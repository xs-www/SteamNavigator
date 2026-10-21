# `framework/ui/screens/flow/sea_chart_screen.gd`

> 作用：全屏航海图页（海图系统阶段 2 入口集成，4.3.4 / U7 重构出航流程）：

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SeaChartScreen` | L1 |
| `close_requested (signal)` | L28 |
| `departure_requested (signal)` | L30 |
| `departure_confirmed (signal)` | L32 |
| `departure_cancelled (signal)` | L34 |
| `departure_strategy_changed (signal)` | L36 |
| `purchase_clue_requested (signal)` | L38 |
| `investigate_requested (signal)` | L40 |
| `COLOR_MUTED` | L42 |
| `PANEL_WIDTH` | L43 |
| `VOYAGE_CONFIRM_SCRIPT` | L46 |
| `bind(view_model: Dictionary, translate: Callable) -> void` | L57 |
| `get_chart() -> SNSeaChartView` | L64 |
| `get_panel() -> SNSeaChartPanel` | L68 |
| `is_departure_open() -> bool` | L73 |
| `get_departure() -> Dictionary` | L77 |

左侧 `SNSeaChartView` 铺满、右侧 `SNSeaChartPanel`（320 px）展示选中港口/航线/线索，
顶部章节标题 + 关闭按钮；出航时在页内叠加 `SNVoyageConfirm` 确认弹窗。
数据只来自 `sea_chart.view`（外加 Shell 组合的 `departure` 块），经
`bind(view_model, translate)` 注入。

## 契约与约束
- 图上点击港口：视图只改选中态，面板绑定该港与当前港之间的航线数据；
  本页自身不查询、不执行命令。
- 面板「启航」/「循此线索出航」统一冒泡为 `departure_requested(kind, target_id)`
  （kind = `voyage` | `explore`），由 Shell 打开确认弹窗（预估 + 锅炉策略切换 +
  取消 / 启航），确认后才执行 `voyage.start` / `explore.start`。出航准备页已删除。
- `view_model["departure"]` 非空时本页把确认弹窗绘制为居中遮罩层；弹窗的三个意图
  信号原样转发：`departure_confirmed(kind, target_id, strategy_id)` /
  `departure_cancelled` / `departure_strategy_changed(strategy_id)`。
- `close_requested` 交给 Shell 决定返回页；`has_run=false` 时只显示提示文案。
- 选中当前港时面板只显示港口信息（无航线区、无启航按钮）。
- **线索**（探索系统 4.1）：图上点击线索 → 面板切到线索区块；面板的
  `purchase_clue_requested` / `investigate_requested` 由本页原样转发给 Shell。
  `can_buy_clue` 来自同一个 `sea_chart.view`，本页只负责塞给面板。
- **逐级调查**（4.3.2 / U2）：面板 `investigate_requested(clue_id)` 由本页原样
  转发为同名信号；Shell 执行 `clue.investigate` 后刷新海图。

模块索引：[framework/ui](../../README.md)
