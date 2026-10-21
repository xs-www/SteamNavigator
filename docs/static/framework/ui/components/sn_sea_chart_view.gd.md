# `framework/ui/components/sn_sea_chart_view.gd`

> 作用：可缩放/平移的 2D 海图视图，使用 `_draw()` 在世界坐标上绘制水面与图框、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNSeaChartView` | L1 |
| `port_clicked (signal)` | L55 |
| `port_hovered (signal)` | L56 |
| `clue_clicked (signal)` | L58 |
| `COLOR_WATER` | L61 |
| `COLOR_CHART_MARGIN` | L63 |
| `COLOR_CHART_FRAME` | L64 |
| `COLOR_WATER_DEEP` | L65 |
| `COLOR_WATER_SHALLOW` | L66 |
| `COLOR_GRID_MINOR` | L67 |
| `COLOR_GRID_MAJOR` | L68 |
| `COLOR_LAND_FILL` | L69 |
| `COLOR_LAND_OUTLINE` | L70 |
| `COLOR_LAND_EXPLORED` | L72 |
| `COLOR_LAND_EXPLORED_OUTLINE` | L73 |
| `COLOR_LAND_SILHOUETTE` | L75 |
| `COLOR_LAND_SILHOUETTE_OUTLINE` | L76 |
| `COLOR_FOG_BLACK` | L77 |
| `COLOR_FOG_EXPLORED` | L78 |
| `COLOR_ROUTE_ACTIVE` | L79 |
| `COLOR_ROUTE_EXPLORED` | L80 |
| `COLOR_ROUTE_UNKNOWN` | L81 |
| `COLOR_PORT_CURRENT` | L82 |
| `COLOR_PORT_VISITED` | L83 |
| `COLOR_PORT_DISCOVERED` | L84 |
| `COLOR_PORT_UNKNOWN` | L85 |
| `COLOR_SHIP` | L86 |
| `COLOR_SHIP_VISION` | L88 |
| `SHIP_VISION_RINGS` | L89 |
| `SHIP_VISION_MAX_ALPHA` | L90 |
| `SHIP_VISION_CORE_ALPHA` | L91 |
| `COLOR_BRASS` | L92 |
| `COLOR_INK` | L93 |
| `COLOR_CLUE` | L96 |
| `COLOR_CLUE_SELECTED` | L97 |
| `COLOR_CLUE_GLOW` | L98 |
| `CLUE_HIT_TOLERANCE` | L100 |
| `CLUE_ARROW_LENGTH` | L103 |
| `CLUE_CIRCLE_SEGMENTS` | L105 |
| `CLUE_DASH_RATIO` | L106 |
| `ZOOM_MIN` | L109 |
| `ZOOM_MAX` | L110 |
| `ZOOM_STEP` | L111 |
| `PRESENTATION_MARGIN` | L115 |
| `PRESENTATION_ZOOM_MAX` | L118 |
| `get_selected_port() -> String` | L220 |
| `select_port(port_id: String) -> void` | L224 |
| `get_selected_clue() -> String` | L235 |
| `select_clue(clue_id: String) -> void` | L240 |
| `get_clues() -> Array` | L248 |
| `clue_by_id(clue_id: String) -> Dictionary` | L254 |
| `set_ship_position(world_position: Vector2) -> void` | L264 |
| `set_ship_pose(world_position: Vector2, heading: float) -> void` | L271 |
| `get_ship_heading() -> float` | L279 |
| `has_ship_heading() -> bool` | L283 |
| `clear_ship_position() -> void` | L287 |
| `has_ship_position() -> bool` | L292 |
| `set_ship_vision(world_radius: float) -> void` | L298 |
| `get_ship_vision() -> float` | L304 |
| `has_ship_vision() -> bool` | L308 |
| `clear_ship_vision() -> void` | L312 |
| `set_unknown_destination(world_pos: Vector2, label_key: String, top_inset: float = 0.0) -> void` | L323 |
| `clear_unknown_destination() -> void` | L336 |
| `has_unknown_destination() -> bool` | L343 |
| `get_unknown_destination() -> Dictionary` | L347 |
| `is_presentation_mode() -> bool` | L364 |
| `set_frame_scale(scale: float) -> void` | L372 |
| `get_frame_scale() -> float` | L381 |
| `get_base_zoom() -> float` | L386 |
| `get_base_center() -> Vector2` | L391 |
| `center_on_port(port_id: String) -> void` | L399 |
| `get_zoom() -> float` | L411 |
| `exit_direction(port_data: Dictionary) -> Vector2` | L417 |
| `world_to_screen(world_pos: Vector2) -> Vector2` | L519 |
| `screen_to_world(screen_pos: Vector2) -> Vector2` | L523 |
| `visible_routes(routes: Array, selected_port: String) -> Array` | L711 |
| `shows_route_distance(distance: float, zoom: float) -> bool` | L727 |
| `clamp_marker_to_view(target: Vector2, view_size: Vector2, top_inset: float) -> Vector2` | L937 |
| `clue_screen_geometry(clue: Dictionary) -> Dictionary` | L985 |
| `clue_hit_test(screen_position: Vector2, geometry: Dictionary) -> bool` | L1036 |
| `clue_arrow_endpoint(port_world: Vector2, angle: float, length: float) -> Vector2` | L1057 |
| `clue_circle_screen(center_world: Vector2, radius_world: float, zoom: float, offset: Vector2) -> Dictionary` | L1065 |
| `ship_vision_rings(radius_world: float, steps: int = SHIP_VISION_RINGS) -> Array` | L1252 |
| `ship_icon_shape(radius: float) -> PackedVector2Array` | L1315 |

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
- **航线只在选中港口时显示**（4.3 / U5）：普通航线只画与 `_selected_port` 相邻的
  那些，未选中港口（包括选中线索）时一条都不画；演出模式下普通航线全部隐藏，只
  保留 `_focus_points` 画出的计划航线。过滤逻辑在纯函数 `visible_routes()` 里。
  距离标签跟随**所有可见航线**（`shows_route_distance()`），选中非当前港时其相邻
  航线也能读到里程；与当前港相连的航线用金色，其余用暗色，避免误读为当前可选航线。
- **探索演出终点**：`set_unknown_destination(world_pos, label_key)` 画一条从当前船位
  到未知终点的虚线预测线 + `?` 标记（迷雾之上、船 icon 之下）；
  `clear_unknown_destination()` 在演出结束时清掉。
- **随船照亮**（4.3.3 / U4）：`set_ship_vision(world_radius)` 在船位周围画多层
  同心软圆（内亮外暗，无 shader / 新资产）。半径是世界单位、随 `_zoom` 缩放；
  它只是表现，不写领域状态。图层在迷雾与已探索陆地剪影之上、航线/港口图标之下，
  不遮挡船 icon 与线索。`ship_vision_rings()` 是纯函数，测试可直接断言衰减。
- **货物行情线索不画几何**（4.4）：`type = port_goods` 的目标是已发现港口、没有
  搜索区，`clue_screen_geometry()` 直接返回 `{}`，海图上不会出现方向箭头 / 虚线圆；
  行情通过右侧面板与线索列表页展示。

模块索引：[framework/ui](../README.md)
