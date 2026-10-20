# `framework/ui/components/sn_sea_chart_view.gd`

> 作用：可缩放/平移的 2D 海图视图，使用 `_draw()` 在世界坐标上绘制水面与图框、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNSeaChartView` | L1 |
| `port_clicked (signal)` | L43 |
| `port_hovered (signal)` | L44 |
| `clue_clicked (signal)` | L46 |
| `COLOR_WATER` | L49 |
| `COLOR_CHART_MARGIN` | L51 |
| `COLOR_CHART_FRAME` | L52 |
| `COLOR_WATER_DEEP` | L53 |
| `COLOR_WATER_SHALLOW` | L54 |
| `COLOR_GRID_MINOR` | L55 |
| `COLOR_GRID_MAJOR` | L56 |
| `COLOR_LAND_FILL` | L57 |
| `COLOR_LAND_OUTLINE` | L58 |
| `COLOR_LAND_EXPLORED` | L60 |
| `COLOR_LAND_EXPLORED_OUTLINE` | L61 |
| `COLOR_LAND_SILHOUETTE` | L63 |
| `COLOR_LAND_SILHOUETTE_OUTLINE` | L64 |
| `COLOR_FOG_BLACK` | L65 |
| `COLOR_FOG_EXPLORED` | L66 |
| `COLOR_ROUTE_ACTIVE` | L67 |
| `COLOR_ROUTE_EXPLORED` | L68 |
| `COLOR_ROUTE_UNKNOWN` | L69 |
| `COLOR_PORT_CURRENT` | L70 |
| `COLOR_PORT_VISITED` | L71 |
| `COLOR_PORT_DISCOVERED` | L72 |
| `COLOR_PORT_UNKNOWN` | L73 |
| `COLOR_SHIP` | L74 |
| `COLOR_BRASS` | L75 |
| `COLOR_INK` | L76 |
| `COLOR_CLUE` | L79 |
| `COLOR_CLUE_SELECTED` | L80 |
| `COLOR_CLUE_GLOW` | L81 |
| `CLUE_HIT_TOLERANCE` | L83 |
| `CLUE_ARROW_LENGTH` | L86 |
| `CLUE_CIRCLE_SEGMENTS` | L88 |
| `CLUE_DASH_RATIO` | L89 |
| `ZOOM_MIN` | L92 |
| `ZOOM_MAX` | L93 |
| `ZOOM_STEP` | L94 |
| `PRESENTATION_MARGIN` | L98 |
| `PRESENTATION_ZOOM_MAX` | L101 |
| `get_selected_port() -> String` | L200 |
| `select_port(port_id: String) -> void` | L204 |
| `get_selected_clue() -> String` | L215 |
| `select_clue(clue_id: String) -> void` | L220 |
| `get_clues() -> Array` | L228 |
| `clue_by_id(clue_id: String) -> Dictionary` | L234 |
| `set_ship_position(world_position: Vector2) -> void` | L244 |
| `set_ship_pose(world_position: Vector2, heading: float) -> void` | L251 |
| `get_ship_heading() -> float` | L259 |
| `has_ship_heading() -> bool` | L263 |
| `clear_ship_position() -> void` | L267 |
| `has_ship_position() -> bool` | L272 |
| `set_unknown_destination(world_pos: Vector2, label_key: String, top_inset: float = 0.0) -> void` | L280 |
| `clear_unknown_destination() -> void` | L293 |
| `has_unknown_destination() -> bool` | L300 |
| `get_unknown_destination() -> Dictionary` | L304 |
| `is_presentation_mode() -> bool` | L321 |
| `set_frame_scale(scale: float) -> void` | L329 |
| `get_frame_scale() -> float` | L338 |
| `get_base_zoom() -> float` | L343 |
| `get_base_center() -> Vector2` | L348 |
| `center_on_port(port_id: String) -> void` | L356 |
| `get_zoom() -> float` | L368 |
| `exit_direction(port_data: Dictionary) -> Vector2` | L374 |
| `world_to_screen(world_pos: Vector2) -> Vector2` | L476 |
| `screen_to_world(screen_pos: Vector2) -> Vector2` | L480 |
| `clamp_marker_to_view(target: Vector2, view_size: Vector2, top_inset: float) -> Vector2` | L856 |
| `clue_screen_geometry(clue: Dictionary) -> Dictionary` | L902 |
| `clue_hit_test(screen_position: Vector2, geometry: Dictionary) -> bool` | L951 |
| `clue_arrow_endpoint(port_world: Vector2, angle: float, length: float) -> Vector2` | L972 |
| `clue_circle_screen(center_world: Vector2, radius_world: float, zoom: float, offset: Vector2) -> Dictionary` | L980 |
| `ship_icon_shape(radius: float) -> PackedVector2Array` | L1185 |

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
- 航行演出用 `set_ship_pose(position, heading)` 逐帧推船只位置与艏向（覆盖
  ViewModel 的 `ship_position`），船 icon 是带艏尖/艉迹的船形，按 heading 旋转
  ——转弯时船头跟着航线转；没有艏向数据的旧存档退回朝 +X 的静态船形。
- **演出取景**（阶段 3 验收反馈 F3）：`set_presentation_mode(enabled, route)` 切到
  cover 取景——世界按 `max(控件宽/世界宽, 控件高/世界高)` 铺满，世界外的余下画面
  画成开阔水面（不再有图表暗边）；航线包围盒（含起终港）做保底，铺满与它冲突时
  退回装得下整条航线的缩放。取景上限是 `PRESENTATION_ZOOM_MAX`，不受手动缩放的
  `ZOOM_MAX` 限制（真实对局的孪生世界可能只有 160 单位见方，需要 ×9 才铺满）。
- **演出倍数**（F2）：`set_frame_scale(scale)` 由 `VoyagePresentation.chart_zoom_scale()`
  每帧推入，`1.0` 严格等于稳态取景；>1 时以「稳态中心 → 船只 icon」连续过渡的中心
  放大，云层散开时由近拉远、入港前推近。
- **线索可视化**（探索系统 4.1）：从 `view_model["clues"]` 画线索——level 2 从参照港
  沿 `direction_angle` 画黄铜箭头，level 3 在 `circle` 画虚线圆 + 中心 `?`，level 4
  再加 `？<港口名>？`。点中箭头/圆环/圆心（12 px 容差）发 `clue_clicked(clue_id)` 并
  高亮；`select_clue()` / `get_selected_clue()` 供外部同步选中态，选中港口会清掉线索
  选中。几何换算全部走静态纯函数（`clue_arrow_endpoint` / `clue_circle_screen` /
  `clue_hit_test`），无头测试不渲染也能断言。
- **探索演出终点**：`set_unknown_destination(world_pos, label_key)` 画一条从当前船位
  到未知终点的虚线预测线 + `?` 标记（迷雾之上、船 icon 之下）；
  `clear_unknown_destination()` 在演出结束时清掉。

模块索引：[framework/ui](../README.md)
