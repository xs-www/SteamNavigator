# `framework/ui/components/sn_sea_chart_view.gd`

> 作用：可缩放/平移的 2D 海图视图，使用 `_draw()` 在世界坐标上绘制水面与图框、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNSeaChartView` | L1 |
| `port_clicked (signal)` | L23 |
| `port_hovered (signal)` | L24 |
| `COLOR_WATER` | L27 |
| `COLOR_CHART_MARGIN` | L29 |
| `COLOR_CHART_FRAME` | L30 |
| `COLOR_WATER_DEEP` | L31 |
| `COLOR_WATER_SHALLOW` | L32 |
| `COLOR_GRID_MINOR` | L33 |
| `COLOR_GRID_MAJOR` | L34 |
| `COLOR_LAND_FILL` | L35 |
| `COLOR_LAND_OUTLINE` | L36 |
| `COLOR_LAND_EXPLORED` | L38 |
| `COLOR_LAND_EXPLORED_OUTLINE` | L39 |
| `COLOR_LAND_SILHOUETTE` | L41 |
| `COLOR_LAND_SILHOUETTE_OUTLINE` | L42 |
| `COLOR_FOG_BLACK` | L43 |
| `COLOR_FOG_EXPLORED` | L44 |
| `COLOR_ROUTE_ACTIVE` | L45 |
| `COLOR_ROUTE_EXPLORED` | L46 |
| `COLOR_ROUTE_UNKNOWN` | L47 |
| `COLOR_PORT_CURRENT` | L48 |
| `COLOR_PORT_VISITED` | L49 |
| `COLOR_PORT_DISCOVERED` | L50 |
| `COLOR_PORT_UNKNOWN` | L51 |
| `COLOR_SHIP` | L52 |
| `COLOR_BRASS` | L53 |
| `COLOR_INK` | L54 |
| `ZOOM_MIN` | L57 |
| `ZOOM_MAX` | L58 |
| `ZOOM_STEP` | L59 |
| `get_selected_port() -> String` | L125 |
| `select_port(port_id: String) -> void` | L129 |
| `center_on_port(port_id: String) -> void` | L137 |
| `get_zoom() -> float` | L145 |
| `world_to_screen(world_pos: Vector2) -> Vector2` | L176 |
| `screen_to_world(screen_pos: Vector2) -> Vector2` | L180 |

陆地、航线、港口图标、迷雾、船只标记、罗盘、图例与缩放指示。

- 关键依赖：`sea_chart.view` 查询输出的视图模型（`bind(vm, translate)` 注入）。

## 契约与约束
- 输入仅为 `sea_chart.view` 的输出；点击港口发 `port_clicked(port_id)`，hover 发
  `port_hovered(port_id)`；不执行导航、不查询后端、不调 CommandBus。
- `bind(vm, translate)` 可带本地化回调；缺失时标签回退为键名（不渲染空串）。
- 世界↔屏幕由 `_zoom`/`_offset` 线性变换；缩放以鼠标位置为不动点；首次有尺寸时
  才做一次自动取景（`_needs_fit`），绑定早于布局不会留下 zoom=1 的错误取景。
- 迷雾烘焙成每格 1 texel 的 RGBA 纹理（`_build_fog_texture`）+ 线性过滤，一次绘制，
  格边插值平滑；BLACK 不透明、EXPLORED 半透明、VISIBLE 全透明。
- 陆地分两趟画：未探索的在迷雾之下（被黑雾遮住），已探索的在迷雾之上画暗淡剪影；
  "是否已探索"按海岸采样 ≥25% 已揭示判定，而不是只看质心。
- `select_port()` 只改选中态、**不移动视图**；需要移动时显式调 `center_on_port()`。
- `departure_angle` 是弧度，直接用于 cos/sin。

模块索引：[framework/ui](../README.md)
