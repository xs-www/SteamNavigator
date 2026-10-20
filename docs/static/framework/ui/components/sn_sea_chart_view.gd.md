# `framework/ui/components/sn_sea_chart_view.gd`

> 作用：可缩放/平移的 2D 海图视图，使用 `_draw()` 在世界坐标上绘制水面、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNSeaChartView` | L1 |
| `port_clicked (signal)` | L19 |
| `port_hovered (signal)` | L20 |
| `COLOR_WATER` | L23 |
| `COLOR_WATER_DEEP` | L24 |
| `COLOR_WATER_SHALLOW` | L25 |
| `COLOR_GRID_MINOR` | L26 |
| `COLOR_GRID_MAJOR` | L27 |
| `COLOR_LAND_FILL` | L28 |
| `COLOR_LAND_OUTLINE` | L29 |
| `COLOR_LAND_EXPLORED` | L30 |
| `COLOR_LAND_EXPLORED_OUTLINE` | L31 |
| `COLOR_FOG_BLACK` | L32 |
| `COLOR_FOG_EXPLORED` | L33 |
| `COLOR_ROUTE_ACTIVE` | L34 |
| `COLOR_ROUTE_EXPLORED` | L35 |
| `COLOR_ROUTE_UNKNOWN` | L36 |
| `COLOR_PORT_CURRENT` | L37 |
| `COLOR_PORT_VISITED` | L38 |
| `COLOR_PORT_DISCOVERED` | L39 |
| `COLOR_PORT_UNKNOWN` | L40 |
| `COLOR_SHIP` | L41 |
| `COLOR_BRASS` | L42 |
| `COLOR_INK` | L43 |
| `ZOOM_MIN` | L46 |
| `ZOOM_MAX` | L47 |
| `ZOOM_STEP` | L48 |
| `bind(vm: Dictionary) -> void` | L69 |
| `get_selected_port() -> String` | L85 |
| `select_port(port_id: String) -> void` | L89 |
| `get_zoom() -> float` | L96 |
| `world_to_screen(world_pos: Vector2) -> Vector2` | L127 |
| `screen_to_world(screen_pos: Vector2) -> Vector2` | L131 |

陆地多边形、贝塞尔航线、港口图标、迷雾网格、船只标记、罗盘、图例与缩放指示。

- 关键依赖：`sea_chart.view` 查询输出的视图模型（`bind(vm)` 注入）。

## 契约与约束
- 输入仅为 `sea_chart.view` 的输出；点击港口时发出 `port_clicked(port_id)`，
  hover 时发出 `port_hovered(port_id)`，不执行导航或查询。
- 世界↔屏幕坐标由 `_zoom` 和 `_offset` 线性变换；缩放以鼠标位置为不动点。
- 陆地多边形在迷雾未探索时使用暗色（explored 态），已探索时使用亮色（fill + outline）。
- 迷雾网格按 cell 绘制带状态的半透明矩形；BLACK 与 EXPLORED 用不同基色，VISIBLE 跳过。
- 港口图标半径随 `sqrt(_zoom)` 缩放，当前港带脉冲；选中港用黄铜弧线高亮。
- 滚轮缩放、左键拖拽、`Esc` 取消选中、`+/-` 键缩放。

模块索引：[framework/ui](../README.md)
