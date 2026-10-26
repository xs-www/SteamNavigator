# `framework/ui/components/sn_sea_chart_view.gd`

> 作用：可缩放/平移的 2D 海图视图，使用 `_draw()` 在世界坐标上绘制水面与图框、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNSeaChartView` | L1 |
| `port_clicked (signal)` | L62 |
| `port_hovered (signal)` | L63 |
| `clue_clicked (signal)` | L65 |
| `COLOR_WATER` | L68 |
| `COLOR_CHART_MARGIN` | L70 |
| `COLOR_CHART_FRAME` | L71 |
| `COLOR_WATER_DEEP` | L72 |
| `COLOR_WATER_SHALLOW` | L73 |
| `COLOR_GRID_MINOR` | L74 |
| `COLOR_GRID_MAJOR` | L75 |
| `COLOR_LAND_FILL` | L76 |
| `COLOR_LAND_OUTLINE` | L77 |
| `COLOR_LAND_EXPLORED` | L79 |
| `COLOR_LAND_EXPLORED_OUTLINE` | L80 |
| `COLOR_LAND_SILHOUETTE` | L82 |
| `COLOR_LAND_SILHOUETTE_OUTLINE` | L83 |
| `COLOR_FOG_BLACK` | L84 |
| `COLOR_FOG_EXPLORED` | L85 |
| `COLOR_ROUTE_ACTIVE` | L86 |
| `COLOR_ROUTE_EXPLORED` | L87 |
| `COLOR_ROUTE_UNKNOWN` | L88 |
| `COLOR_ROUTE_LOCKED` | L91 |
| `ROUTE_LOCKED_DASH` | L92 |
| `COLOR_PORT_CURRENT` | L93 |
| `COLOR_PORT_VISITED` | L94 |
| `COLOR_PORT_DISCOVERED` | L95 |
| `COLOR_PORT_UNKNOWN` | L96 |
| `COLOR_SHIP` | L97 |
| `COLOR_SHIP_VISION` | L99 |
| `SHIP_VISION_RINGS` | L100 |
| `SHIP_VISION_MAX_ALPHA` | L101 |
| `SHIP_VISION_CORE_ALPHA` | L102 |
| `COLOR_BRASS` | L103 |
| `COLOR_INK` | L104 |
| `COLOR_CLUE` | L107 |
| `COLOR_CLUE_SELECTED` | L108 |
| `COLOR_CLUE_GLOW` | L109 |
| `CLUE_HIT_TOLERANCE` | L111 |
| `CLUE_ARROW_LENGTH` | L114 |
| `CLUE_CIRCLE_SEGMENTS` | L116 |
| `CLUE_DASH_RATIO` | L117 |
| `ZOOM_MIN` | L120 |
| `ZOOM_MAX` | L121 |
| `ZOOM_STEP` | L122 |
| `PRESENTATION_MARGIN` | L126 |
| `PRESENTATION_ZOOM_MAX` | L129 |
| `get_selected_port() -> String` | L231 |
| `select_port(port_id: String) -> void` | L235 |
| `get_selected_clue() -> String` | L246 |
| `select_clue(clue_id: String) -> void` | L251 |
| `get_clues() -> Array` | L259 |
| `clue_by_id(clue_id: String) -> Dictionary` | L265 |
| `set_ship_position(world_position: Vector2) -> void` | L275 |
| `set_ship_pose(world_position: Vector2, heading: float) -> void` | L282 |
| `get_ship_heading() -> float` | L290 |
| `has_ship_heading() -> bool` | L294 |
| `clear_ship_position() -> void` | L298 |
| `has_ship_position() -> bool` | L303 |
| `set_ship_vision(world_radius: float) -> void` | L309 |
| `get_ship_vision() -> float` | L315 |
| `has_ship_vision() -> bool` | L319 |
| `clear_ship_vision() -> void` | L323 |
| `set_unknown_destination(world_pos: Vector2, label_key: String, top_inset: float = 0.0) -> void` | L334 |
| `clear_unknown_destination() -> void` | L347 |
| `has_unknown_destination() -> bool` | L354 |
| `get_unknown_destination() -> Dictionary` | L358 |
| `is_presentation_mode() -> bool` | L375 |
| `set_frame_scale(scale: float) -> void` | L383 |
| `get_frame_scale() -> float` | L392 |
| `get_base_zoom() -> float` | L397 |
| `get_base_center() -> Vector2` | L402 |
| `center_on_port(port_id: String) -> void` | L410 |
| `get_zoom() -> float` | L422 |
| `exit_direction(port_data: Dictionary) -> Vector2` | L428 |
| `world_to_screen(world_pos: Vector2) -> Vector2` | L530 |
| `screen_to_world(screen_pos: Vector2) -> Vector2` | L534 |
| `visible_routes(routes: Array, selected_port: String) -> Array` | L722 |
| `shows_route_distance(distance: float, zoom: float) -> bool` | L738 |
| `clamp_marker_to_view(target: Vector2, view_size: Vector2, top_inset: float) -> Vector2` | L964 |
| `clue_screen_geometry(clue: Dictionary) -> Dictionary` | L1012 |
| `clue_hit_test(screen_position: Vector2, geometry: Dictionary) -> bool` | L1063 |
| `clue_arrow_endpoint(port_world: Vector2, angle: float, length: float) -> Vector2` | L1084 |
| `clue_circle_screen(center_world: Vector2, radius_world: float, zoom: float, offset: Vector2) -> Dictionary` | L1092 |
| `ship_vision_rings(radius_world: float, steps: int = SHIP_VISION_RINGS) -> Array` | L1279 |
| `ship_icon_shape(radius: float) -> PackedVector2Array` | L1342 |

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
  `ZOOM_MAX` 限制（可玩海图世界只有 160 单位见方，需要 ×9 才铺满）。
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
- **单一距离口径**（dev.3 反馈 #2 彻底修复）：海图航线 `distance` 就是该边绘制路径
  的长度，也就是 `voyage.preview` 计费的同一个数；标签直接读 `distance`，不存在
  「展示距离 / 计费距离」两套字段。
- **未测绘航线画虚线**（2026-10-26 航线解锁）：`route.unlocked == false`（物理有边、两端
  已发现但玩家还没买海图）用 `COLOR_ROUTE_LOCKED` 虚线（`_draw_dashed_polyline`）绘制，
  与已测绘实线区分；选中后右侧面板禁用启航并提示在酒馆购买海图。`unlocked` 缺省按
  true 处理（旧视图模型 / 合成数据不改变既有实线表现）。
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
