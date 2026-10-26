class_name SNSeaChartView
extends Control
## @static-doc
## 作用：可缩放/平移的 2D 海图视图，使用 `_draw()` 在世界坐标上绘制水面与图框、
## 陆地、航线、港口图标、迷雾、船只标记、罗盘、图例与缩放指示。
##
## - 关键依赖：`sea_chart.view` 查询输出的视图模型（`bind(vm, translate)` 注入）。
##
## ## 契约与约束
## - 输入仅为 `sea_chart.view` 的输出；点击港口发 `port_clicked(port_id)`，hover 发
##   `port_hovered(port_id)`；不执行导航、不查询后端、不调 CommandBus。
## - `bind(vm, translate)` 可带本地化回调；缺失时标签回退为键名（不渲染空串）。
## - 世界↔屏幕由 `_zoom`/`_offset` 线性变换；缩放以鼠标位置为不动点；首次有尺寸时
##   才做一次自动取景（`_needs_fit`），绑定早于布局不会留下 zoom=1 的错误取景。
## - 迷雾烘焙成每格 1 texel 的 RGBA 纹理（`_build_fog_texture`）+ 线性过滤，一次绘制，
##   格边插值平滑；BLACK 不透明、EXPLORED 半透明、VISIBLE 全透明。
## - 陆地分两趟画：未探索的在迷雾之下（被黑雾遮住），已探索的在迷雾之上画暗淡剪影；
##   "是否已探索"按海岸采样 ≥25% 已揭示判定，而不是只看质心。
## - `select_port()` 只改选中态、**不移动视图**；需要移动时显式调 `center_on_port()`。
## - `departure_angle` 是弧度，直接用于 cos/sin。
## - 航行演出用 `set_ship_pose(position, heading)` 逐帧推船只位置与艏向（覆盖
##   ViewModel 的 `ship_position`），船 icon 是带艏尖/艉迹的船形，按 heading 旋转
##   ——转弯时船头跟着航线转；没有艏向数据的旧存档退回朝 +X 的静态船形。
## - **演出取景**（阶段 3 验收反馈 F3）：`set_presentation_mode(enabled, route)` 切到
##   cover 取景——世界按 `max(控件宽/世界宽, 控件高/世界高)` 铺满，世界外的余下画面
##   画成开阔水面（不再有图表暗边）；航线包围盒（含起终港）做保底，铺满与它冲突时
##   退回装得下整条航线的缩放。取景上限是 `PRESENTATION_ZOOM_MAX`，不受手动缩放的
##   `ZOOM_MAX` 限制（可玩海图世界只有 160 单位见方，需要 ×9 才铺满）。
## - **演出倍数**（F2）：`set_frame_scale(scale)` 由 `VoyagePresentation.chart_zoom_scale()`
##   每帧推入，`1.0` 严格等于稳态取景；>1 时以「稳态中心 → 船只 icon」连续过渡的中心
##   放大，云层散开时由近拉远、入港前推近。
## - **线索可视化**（探索系统 4.1）：从 `view_model["clues"]` 画线索——level 2 从参照港
##   沿 `direction_angle` 画黄铜箭头，level 3 在 `circle` 画虚线圆 + 中心 `?`，level 4
##   再加 `？<港口名>？`。点中箭头/圆环/圆心（12 px 容差）发 `clue_clicked(clue_id)` 并
##   高亮；`select_clue()` / `get_selected_clue()` 供外部同步选中态，选中港口会清掉线索
##   选中。几何换算全部走静态纯函数（`clue_arrow_endpoint` / `clue_circle_screen` /
##   `clue_hit_test`），无头测试不渲染也能断言。
## - **航线只在选中港口时显示**（4.3 / U5）：普通航线只画与 `_selected_port` 相邻的
##   那些，未选中港口（包括选中线索）时一条都不画；演出模式下普通航线全部隐藏，只
##   保留 `_focus_points` 画出的计划航线。过滤逻辑在纯函数 `visible_routes()` 里。
##   距离标签跟随**所有可见航线**（`shows_route_distance()`），选中非当前港时其相邻
##   航线也能读到里程；与当前港相连的航线用金色，其余用暗色，避免误读为当前可选航线。
## - **单一距离口径**（dev.3 反馈 #2 彻底修复）：海图航线 `distance` 就是该边绘制路径
##   的长度，也就是 `voyage.preview` 计费的同一个数；标签直接读 `distance`，不存在
##   「展示距离 / 计费距离」两套字段。
## - **未测绘航线画虚线**（2026-10-26 航线解锁）：`route.unlocked == false`（物理有边、两端
##   已发现但玩家还没买海图）用 `COLOR_ROUTE_LOCKED` 虚线（`_draw_dashed_polyline`）绘制，
##   与已测绘实线区分；选中后右侧面板禁用启航并提示在酒馆购买海图。`unlocked` 缺省按
##   true 处理（旧视图模型 / 合成数据不改变既有实线表现）。
## - **探索演出终点**：`set_unknown_destination(world_pos, label_key)` 画一条从当前船位
##   到未知终点的虚线预测线 + `?` 标记（迷雾之上、船 icon 之下）；
##   `clear_unknown_destination()` 在演出结束时清掉。
## - **随船照亮**（4.3.3 / U4）：`set_ship_vision(world_radius)` 在船位周围画多层
##   同心软圆（内亮外暗，无 shader / 新资产）。半径是世界单位、随 `_zoom` 缩放；
##   它只是表现，不写领域状态。图层在迷雾与已探索陆地剪影之上、航线/港口图标之下，
##   不遮挡船 icon 与线索。`ship_vision_rings()` 是纯函数，测试可直接断言衰减。
## - **货物行情线索不画几何**（4.4）：`type = port_goods` 的目标是已发现港口、没有
##   搜索区，`clue_screen_geometry()` 直接返回 `{}`，海图上不会出现方向箭头 / 虚线圆；
##   行情通过右侧面板与线索列表页展示。
## @end-static-doc

signal port_clicked(port_id: String)
signal port_hovered(port_id: String)
## 点中线索图形（箭头 / 虚线圆 / 圆心）。`clue_id` 是 `view_model["clues"][].id`。
signal clue_clicked(clue_id: String)

# ── Visual constants ──
const COLOR_WATER := Color("0b2428")
## Chart table outside the mapped world (uncharted margin).
const COLOR_CHART_MARGIN := Color("071418")
const COLOR_CHART_FRAME := Color(0.35, 0.55, 0.52, 0.28)
const COLOR_WATER_DEEP := Color(0.04, 0.12, 0.14, 0.12)
const COLOR_WATER_SHALLOW := Color(0.12, 0.28, 0.30, 0.06)
const COLOR_GRID_MINOR := Color(0.38, 0.58, 0.58, 0.06)
const COLOR_GRID_MAJOR := Color(0.46, 0.68, 0.66, 0.12)
const COLOR_LAND_FILL := Color(0.22, 0.38, 0.24, 0.85)
const COLOR_LAND_OUTLINE := Color(0.35, 0.55, 0.35, 0.95)
## Unexplored land, drawn under the fog (mostly hidden by opaque black cells).
const COLOR_LAND_EXPLORED := Color(0.16, 0.27, 0.19, 0.75)
const COLOR_LAND_EXPLORED_OUTLINE := Color(0.28, 0.44, 0.30, 0.8)
## Charted land, drawn above the fog: dim silhouette so a mapped island reads whole.
const COLOR_LAND_SILHOUETTE := Color(0.20, 0.34, 0.23, 0.55)
const COLOR_LAND_SILHOUETTE_OUTLINE := Color(0.42, 0.62, 0.42, 0.75)
const COLOR_FOG_BLACK := Color(0.02, 0.06, 0.08, 1.0)
const COLOR_FOG_EXPLORED := Color(0.05, 0.12, 0.14, 0.5)
const COLOR_ROUTE_ACTIVE := Color(0.88, 0.76, 0.44, 0.86)
const COLOR_ROUTE_EXPLORED := Color(0.45, 0.68, 0.68, 0.62)
const COLOR_ROUTE_UNKNOWN := Color(0.4, 0.5, 0.5, 0.22)
## 未测绘航线（2026-10-26 航线解锁）：两端已发现但玩家还没买海图解锁。用低饱和暖灰
## 虚线画，和「已探索」实线区分，玩家一眼看出「这条边存在但走不了」。
const COLOR_ROUTE_LOCKED := Color(0.55, 0.47, 0.36, 0.55)
const ROUTE_LOCKED_DASH := 7.0
const COLOR_PORT_CURRENT := Color("f0c674")
const COLOR_PORT_VISITED := Color("7fc8e8")
const COLOR_PORT_DISCOVERED := Color("8fd694")
const COLOR_PORT_UNKNOWN := Color(0.46, 0.54, 0.58)
const COLOR_SHIP := Color(0.95, 0.85, 0.45)
## 随船照亮的暖光（4.3.3 / U4）：多层同心软圆叠加，中心最亮、边缘衰减到 0。
const COLOR_SHIP_VISION := Color(0.95, 0.87, 0.58)
const SHIP_VISION_RINGS := 6
const SHIP_VISION_MAX_ALPHA := 0.16
const SHIP_VISION_CORE_ALPHA := 0.16
const COLOR_BRASS := Color("e1c487")
const COLOR_INK := Color("d7e3ea")
## 线索图形用黄铜色系：普通 = 半透明，选中 = 亮黄铜。与港口图标的蓝绿/金色区分开，
## 让"待追查的传闻"在海图上一眼可认。
const COLOR_CLUE := Color(0.88, 0.77, 0.53, 0.78)
const COLOR_CLUE_SELECTED := Color("f6dc9b")
const COLOR_CLUE_GLOW := Color(0.95, 0.83, 0.48, 0.12)
## 线索点击容差（屏幕像素，箭头线段 / 虚线圆环 / 圆心都适用）。
const CLUE_HIT_TOLERANCE := 12.0
## level 2 方向箭头的世界长度。世界单位而不是屏幕像素：缩放时箭头跟着海图一起缩，
## 与港口的定位关系保持稳定。
const CLUE_ARROW_LENGTH := 46.0
## 虚线圆的分段数（每段再按 `CLUE_DASH_RATIO` 留出空隙）。
const CLUE_CIRCLE_SEGMENTS := 40
const CLUE_DASH_RATIO := 0.55

# ── Zoom constraints ──
const ZOOM_MIN := 0.15
const ZOOM_MAX := 5.0
const ZOOM_STEP := 1.15
## 航行演出取景（阶段 3 验收反馈 F3）：世界按 cover 比例铺满控件，视野裁掉世界
## 边界外的空白；但航线包围盒（含起终港）必须留在稳态取景里，绝不为了铺满把
## 正在走的航线裁掉。这个余量只用于航线包围盒，不用于铺满比例。
const PRESENTATION_MARGIN := 24.0
## 演出取景的缩放下限/上限与图表页不同：可玩海图世界只有 160 单位见方，铺满
## 1440 px 需要 ×9，`ZOOM_MAX`（手动缩放的手感上限）不能把演出取景卡成留白。
const PRESENTATION_ZOOM_MAX := 64.0

# ── State ──
var view_model: Dictionary = {}
var _zoom: float = 1.0
var _offset: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _drag_offset_start: Vector2 = Vector2.ZERO
var _hovered_port: String = ""
var _selected_port: String = ""
## 当前选中的线索 id；选中线索时清掉港口选中，反之亦然。
var _selected_clue: String = ""
var _hovered_clue: String = ""
## 探索演出的未知终点（`{x, y, label_key}`）。空字典 = 没有未知终点。
var _unknown_destination: Dictionary = {}
var _time: float = 0.0
var _world_bounds: Rect2 = Rect2(0, 0, 400, 400)
var _translate: Callable = Callable()
## Set on bind/resize while the control still has no layout size; the first draw
## with a real size then frames the world once (binding before layout must not
## leave the chart at zoom 1 offset 0).
var _needs_fit: bool = true
## `center_on_port()` requested before layout; applied right after the first fit.
var _pending_center: String = ""
## Fog baked to one texel per cell; drawn with linear filtering so cell borders
## interpolate instead of reading as hard rectangles.
var _fog_texture: ImageTexture = null
var _fog_rect_world: Rect2 = Rect2()
## Live ship position pushed by the voyage presentation; `null` means "use the
## ViewModel's `ship_position`" (the in-port / restored-save case).
var _ship_override: Variant = null
## Heading (radians, world space) the ship icon points along. The at-sea page
## feeds the route tangent every frame, so the icon always faces the direction it
## is actually moving; saves without route data keep the last known heading.
var _ship_heading: float = 0.0
var _has_ship_heading: bool = false
## 随船照亮半径（世界单位，0 = 关闭）。航行页每帧从 `fog_radii.vision` 推入；
## 纯表现数据，不进领域状态。
var _ship_vision_radius: float = 0.0
## 航行演出取景模式：cover 铺满 + 航线包围盒保底（验收反馈 F3）。
var _presentation_mode: bool = false
## 演出取景倍数：1 = 稳态取景，>1 = 近景（验收反馈 F2）。
var _frame_scale: float = 1.0
## 本段航线的路点，仅用于计算稳态取景（保证航线与起终港可见）。
var _focus_points: PackedVector2Array = PackedVector2Array()
## 稳态取景（`_frame_scale == 1` 时生效）：缩放与保持居中的世界点。
var _base_zoom: float = 1.0
var _base_center: Vector2 = Vector2.ZERO


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(_on_resized)


func bind(vm: Dictionary, translate: Callable = Callable()) -> void:
	view_model = vm
	_translate = translate
	if vm.is_empty():
		return
	var bounds: Dictionary = vm.get("world_bounds", {})
	_world_bounds = Rect2(
		float(bounds.get("x", 0.0)),
		float(bounds.get("y", 0.0)),
		float(bounds.get("w", 400.0)),
		float(bounds.get("h", 400.0))
	)
	_needs_fit = true
	_build_fog_texture(vm.get("fog", {}))
	# 重绑后旧选中线索可能已解决/作废（买线索会重建视图模型），不能在图上继续高亮。
	if not _selected_clue.is_empty() and clue_by_id(_selected_clue).is_empty():
		_selected_clue = ""
	_try_fit()
	queue_redraw()


func _on_resized() -> void:
	# 演出取景要一直铺满：窗口尺寸变了就重新取景，不能停留在旧缩放下留白。
	if _needs_fit or (_presentation_mode and not view_model.is_empty()):
		_fit_to_view()
		_needs_fit = false
		queue_redraw()


## Frames the world once, as soon as the control actually has a size.
func _try_fit() -> void:
	if not _needs_fit:
		return
	if size.x <= 1.0 or size.y <= 1.0 or view_model.is_empty():
		return
	_fit_to_view()
	_needs_fit = false
	# A centre request that arrived before layout is applied now, after framing.
	if not _pending_center.is_empty():
		_center_on_port(_pending_center)
		_pending_center = ""


func get_selected_port() -> String:
	return _selected_port


func select_port(port_id: String) -> void:
	# Selecting must not move the chart: re-centring on click would yank the map out
	# from under the cursor. Callers that want to travel to a port use `center_on_port()`.
	_selected_port = port_id
	# 港口与线索的选中态互斥：图上面板一次只展示一种对象。
	if not port_id.is_empty():
		_selected_clue = ""
	queue_redraw()


## 当前选中的线索 id（空串 = 没有选中线索）。
func get_selected_clue() -> String:
	return _selected_clue


## 选中一条线索并高亮；会清掉港口选中（面板随之切到线索区块）。
func select_clue(clue_id: String) -> void:
	_selected_clue = clue_id
	if not clue_id.is_empty():
		_selected_port = ""
	queue_redraw()


## 视图模型里的线索列表（只读；没有 clues 字段时为空）。
func get_clues() -> Array:
	var clues: Variant = view_model.get("clues", [])
	return clues if clues is Array else []


## 按 id 找线索；找不到返回空字典。
func clue_by_id(clue_id: String) -> Dictionary:
	for entry in get_clues():
		if entry is Dictionary and String((entry as Dictionary).get("id", "")) == clue_id:
			return entry
	return {}


## Overrides the drawn ship position (world coordinates) without re-binding the
## whole ViewModel. Used by the at-sea presentation to animate the ship along the
## route one frame at a time; `clear_ship_position()` returns to the ViewModel's.
func set_ship_position(world_position: Vector2) -> void:
	_ship_override = world_position
	queue_redraw()


## 与 `set_ship_position()` 相同，但附带艏向（世界弧度，0 = +X，图表 +Y 朝下）：
## 航行页每帧传入航线切线，船 icon 才会朝着实际移动方向，而不是固定形状。
func set_ship_pose(world_position: Vector2, heading: float) -> void:
	_ship_override = world_position
	_ship_heading = heading
	_has_ship_heading = true
	queue_redraw()


## 当前船 icon 的艏向（世界弧度）；没有显式 pose 时退回 ViewModel 的船位朝向。
func get_ship_heading() -> float:
	return _ship_heading


func has_ship_heading() -> bool:
	return _has_ship_heading


func clear_ship_position() -> void:
	_ship_override = null
	queue_redraw()


func has_ship_position() -> bool:
	return _ship_override != null


## 演出中的随船照亮（4.3.3 / U4）：在船位周围画多层同心软圆，半径 `world_radius`
## 是世界单位（随 `_zoom` 缩放）。它只是表现，不写领域状态；0 表示关闭。
func set_ship_vision(world_radius: float) -> void:
	_ship_vision_radius = maxf(0.0, world_radius)
	queue_redraw()


## 当前随船照亮半径（世界单位）；0 = 没有照亮。
func get_ship_vision() -> float:
	return _ship_vision_radius


func has_ship_vision() -> bool:
	return _ship_vision_radius > 0.0


func clear_ship_vision() -> void:
	if _ship_vision_radius <= 0.0:
		return
	_ship_vision_radius = 0.0
	queue_redraw()


## 探索演出的未知终点：世界坐标 + 本地化标签键（通常 `ui.label.unknown_destination`）。
## 海图画一条从当前船位到它的虚线预测线，并画 `?` 标记。它不参与航线数据，只表示
## "玩家还不知道目的港在哪"。`top_inset` 是海图上方的固定 chrome 高度：标记被顶栏/
## 状态条挡住时会被 clamp 到可见区（见 `clamp_marker_to_view`）。
func set_unknown_destination(
	world_pos: Vector2, label_key: String, top_inset: float = 0.0
) -> void:
	_unknown_destination = {
		"x": world_pos.x,
		"y": world_pos.y,
		"label_key": label_key,
		"top_inset": maxf(0.0, top_inset),
	}
	queue_redraw()


## 清掉未知终点（演出结束 / 换成普通航行时）。
func clear_unknown_destination() -> void:
	if _unknown_destination.is_empty():
		return
	_unknown_destination = {}
	queue_redraw()


func has_unknown_destination() -> bool:
	return not _unknown_destination.is_empty()


func get_unknown_destination() -> Dictionary:
	return _unknown_destination.duplicate()


## 航行演出取景（验收反馈 F3）：世界按 cover 比例铺满控件、世界边界外画成开阔
## 水面；同时用 `focus_points`（本段航线路点）的包围盒做保底取景，铺满不能以
## 裁掉正在走的航线或起终港为代价。`bind()` 之前/之后调用都可以，真正的取景
## 仍等控件拿到布局尺寸后由 `_try_fit()` 完成。
func set_presentation_mode(enabled: bool, focus_points: PackedVector2Array = PackedVector2Array()) -> void:
	_presentation_mode = enabled
	_focus_points = focus_points
	_frame_scale = 1.0
	_needs_fit = true
	_try_fit()
	queue_redraw()


func is_presentation_mode() -> bool:
	return _presentation_mode


## 演出取景倍数（1 = 稳态）。由 `VoyagePresentation.chart_zoom_scale()` 每帧推入：
## 云层刚散开时 >1（近景），随云层散尽回到 1；入港前从 1 推近，云层盖满时最近。
## 缩放围绕「世界中心 → 船只 icon」连续过渡的中心，`1.0` 时严格回到稳态取景，
## 因此不会在动画结束那一帧跳一下。
func set_frame_scale(scale: float) -> void:
	var clamped := clampf(scale, 0.25, 8.0)
	if is_equal_approx(clamped, _frame_scale):
		return
	_frame_scale = clamped
	_apply_framing()
	queue_redraw()


func get_frame_scale() -> float:
	return _frame_scale


## 稳态取景缩放（不含演出倍数），测试用它验证「铺满 + 航线可见」的取景选择。
func get_base_zoom() -> float:
	return _base_zoom


## 稳态取景保持居中的世界点（航线包围盒中心；无航线数据时是世界中心）。
func get_base_center() -> Vector2:
	return _base_center


## Explicitly pans the chart so `port_id` sits in the middle (entry animation, "show me").
## Before the control has a size there is nothing to pan, so the request is queued and
## applied by `_try_fit()` once layout lands (otherwise it would frame at zoom 0 and
## lock `_needs_fit` off).
func center_on_port(port_id: String) -> void:
	if port_id.is_empty():
		return
	if size.x <= 1.0 or size.y <= 1.0:
		_pending_center = port_id
		_needs_fit = true
		return
	_center_on_port(port_id)
	_needs_fit = false
	queue_redraw()


func get_zoom() -> float:
	return _zoom


## Unit vector a port's departure tick points along. `departure_angle` is radians;
## this seam exists so the unit handling itself is testable without rendering.
func exit_direction(port_data: Dictionary) -> Vector2:
	var angle := float(port_data.get("departure_angle", 0.0))
	return Vector2(cos(angle), sin(angle))


func _fit_to_view() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	# 重新取景 = 回到稳态；演出倍数由 `set_frame_scale()` 在取景之后重新施加。
	_frame_scale = 1.0
	if _presentation_mode:
		_fit_presentation()
	else:
		_fit_table()
	_apply_framing()


## 常驻海图（港口内 M 键页）的取景：整幅世界放进控件，留出图表边距。
func _fit_table() -> void:
	var margin := 60.0
	var available := Vector2(size.x - margin * 2.0, size.y - margin * 2.0)
	if available.x <= 0.0 or available.y <= 0.0:
		return
	var zoom_x := available.x / maxf(1.0, _world_bounds.size.x)
	var zoom_y := available.y / maxf(1.0, _world_bounds.size.y)
	_base_zoom = clampf(minf(zoom_x, zoom_y), ZOOM_MIN, ZOOM_MAX)
	_base_center = _world_bounds.position + _world_bounds.size * 0.5


## 航行演出的取景（验收反馈 F3）：先按 cover 铺满（世界边界外由 `_draw_water`
## 画成开阔水面，不再是暗色留白），再用航线包围盒保底——航线太长、铺满会裁掉
## 起终港时退回能装下整条航线的缩放。水平/垂直方向各取所需，所以 16:9 窗口里
## 看不到「中间一块方形」；航线在边缘时只平移到「刚好装得下它」的最小偏移。
func _fit_presentation() -> void:
	var cover_zoom := maxf(
		size.x / maxf(1.0, _world_bounds.size.x),
		size.y / maxf(1.0, _world_bounds.size.y)
	)
	var world_center := _world_bounds.position + _world_bounds.size * 0.5
	var zoom := cover_zoom
	var route_bounds := Rect2()
	var has_route := _focus_points.size() >= 2
	if has_route:
		route_bounds = _bounds_of_points(_focus_points)
		var route_zoom := minf(
			size.x / maxf(1.0, route_bounds.size.x + PRESENTATION_MARGIN * 2.0),
			size.y / maxf(1.0, route_bounds.size.y + PRESENTATION_MARGIN * 2.0)
		)
		zoom = minf(cover_zoom, route_zoom)
	_base_zoom = clampf(zoom, ZOOM_MIN, PRESENTATION_ZOOM_MAX)
	# 稳态尽量把世界放在正中；航线贴近世界边缘时只偏移到「航线 + 余量刚好在
	# 视野内」的位置，这样铺满与「起终港不可裁」两个要求同时成立。
	var center := world_center
	if has_route:
		var half := size * 0.5 / _base_zoom
		var margin_world := Vector2(PRESENTATION_MARGIN, PRESENTATION_MARGIN) / _base_zoom
		var low := route_bounds.end - half + margin_world
		var high := route_bounds.position + half - margin_world
		center = Vector2(
			clampf(world_center.x, minf(low.x, high.x), maxf(low.x, high.x)),
			clampf(world_center.y, minf(low.y, high.y), maxf(low.y, high.y))
		)
	_base_center = center


## 稳态取景 + 演出倍数 → 实际的 zoom/offset。倍数 > 1 时视野中心从稳态中心
## 连续过渡到船只 icon，船不会在推近时被推到画面外。
func _apply_framing() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var zoom := maxf(_base_zoom * _frame_scale, ZOOM_MIN)
	_zoom = zoom
	var center := _framing_center()
	_offset = size * 0.5 - center * _zoom


func _framing_center() -> Vector2:
	if _frame_scale <= 1.0001 or _ship_override == null:
		return _base_center
	var weight := clampf((_frame_scale - 1.0) / 0.4, 0.0, 1.0)
	return _base_center.lerp(_ship_override, weight)


static func _bounds_of_points(points: PackedVector2Array) -> Rect2:
	var rect := Rect2(points[0], Vector2.ZERO)
	for index in range(1, points.size()):
		rect = rect.expand(points[index])
	return rect


func _center_on_port(port_id: String) -> void:
	var ports: Array = view_model.get("ports", [])
	for port_data in ports:
		if String(port_data.get("id", "")) == port_id:
			var px := float(port_data.get("x", 0.0))
			var py := float(port_data.get("y", 0.0))
			_offset = size * 0.5 - Vector2(px, py) * _zoom
			return


# ── World ↔ Screen transforms ──

func world_to_screen(world_pos: Vector2) -> Vector2:
	return world_pos * _zoom + _offset


func screen_to_world(screen_pos: Vector2) -> Vector2:
	if _zoom <= 0.001:
		return Vector2.ZERO
	return (screen_pos - _offset) / _zoom


# ── Process ──

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if view_model.is_empty():
		return
	_time += delta
	# Only redraw when needed (current port pulse, ship movement, clue pulse, soft vision)
	var at_sea := bool(view_model.get("at_sea", false)) or _ship_override != null
	var current_port := String(view_model.get("current_port_id", ""))
	var has_animated_markers := not get_clues().is_empty() or has_unknown_destination()
	if at_sea or not current_port.is_empty() or has_animated_markers or _ship_vision_radius > 0.0:
		queue_redraw()


func _draw() -> void:
	_try_fit()
	if view_model.is_empty():
		_draw_empty_state()
		return
	_draw_water()
	_draw_grid()
	_draw_landmasses(false)
	# Fog sits above unexplored land (unknown coastlines stay hidden) but below
	# routes/ports: a known route between two discovered ports is knowledge, not terrain.
	_draw_fog()
	# Charted islands keep a dim silhouette above the grey fog so the landmass reads
	# as a whole instead of a coastal fringe.
	_draw_landmasses(true)
	# 随船照亮在迷雾/陆地剪影之上、航线与港口图标之下：它照亮地形，但不遮挡
	# 航线、港口与线索这些“玩家已知信息”。
	_draw_ship_vision()
	_draw_routes()
	# 线索与未知终点都在迷雾之上：它们是"玩家已经拿到的情报"，不是地形。船 icon
	# 最后画，演出的船始终压在预测线与 ? 标记之上。
	_draw_clues()
	_draw_unknown_destination()
	_draw_ports()
	_draw_ship()
	_draw_compass()
	_draw_legend()
	_draw_zoom_indicator()


func _draw_empty_state() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_WATER)
	var font := get_theme_default_font()
	draw_string(font, Vector2(size.x * 0.5 - 60, size.y * 0.5), "海图加载中...",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.6, 0.7, 0.7, 0.5))


func _draw_water() -> void:
	# Chart table: everything outside the mapped world is darker "uncharted" margin,
	# so the world rect reads as the charted area instead of ragging into open water.
	# 航行演出取景（`_presentation_mode`）下不再有图表边距：整屏先铺开阔水面，
	# 世界矩形只是已测绘的部分，屏幕边缘永远是海而不是暗色留白（验收反馈 F3）。
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_WATER if _presentation_mode else COLOR_CHART_MARGIN)
	var world_rect := Rect2(
		world_to_screen(_world_bounds.position),
		_world_bounds.size * _zoom
	)
	draw_rect(world_rect, COLOR_WATER)
	# Depth bands in world coordinates
	var cx := _world_bounds.position.x + _world_bounds.size.x * 0.3
	var cy := _world_bounds.position.y + _world_bounds.size.y * 0.4
	draw_circle(world_to_screen(Vector2(cx, cy)), _world_bounds.size.y * 0.5 * _zoom, COLOR_WATER_DEEP)
	cx = _world_bounds.position.x + _world_bounds.size.x * 0.75
	cy = _world_bounds.position.y + _world_bounds.size.y * 0.6
	draw_circle(world_to_screen(Vector2(cx, cy)), _world_bounds.size.y * 0.4 * _zoom, COLOR_WATER_SHALLOW)
	# Chart frame around the mapped world.
	draw_rect(world_rect, COLOR_CHART_FRAME, false, 1.0)


func _draw_grid() -> void:
	# World-space grid lines (every 50 units major, every 10 minor)
	var step_minor := 10.0
	var step_major := 50.0
	# Only draw if zoom is high enough
	if _zoom < 0.3:
		return
	var x_start := floorf(_world_bounds.position.x / step_minor) * step_minor
	var x_end := ceilf((_world_bounds.position.x + _world_bounds.size.x) / step_minor) * step_minor
	var y_start := floorf(_world_bounds.position.y / step_minor) * step_minor
	var y_end := ceilf((_world_bounds.position.y + _world_bounds.size.y) / step_minor) * step_minor

	var x := x_start
	while x <= x_end:
		var screen_x := world_to_screen(Vector2(x, 0)).x
		if screen_x >= 0.0 and screen_x <= size.x:
			var is_major := absf(fmod(x, step_major)) < 0.1
			draw_line(
				Vector2(screen_x, 0), Vector2(screen_x, size.y),
				COLOR_GRID_MAJOR if is_major else COLOR_GRID_MINOR, 1.0
			)
		x += step_minor

	var y := y_start
	while y <= y_end:
		var screen_y := world_to_screen(Vector2(0, y)).y
		if screen_y >= 0.0 and screen_y <= size.y:
			var is_major := absf(fmod(y, step_major)) < 0.1
			draw_line(
				Vector2(0, screen_y), Vector2(size.x, screen_y),
				COLOR_GRID_MAJOR if is_major else COLOR_GRID_MINOR, 1.0
			)
		y += step_minor


func _draw_landmasses(only_explored: bool) -> void:
	## `only_explored = false` runs before the fog and draws the unexplored land that
	## the fog then blanks out. `only_explored = true` runs after the fog and paints a
	## dim silhouette of the islands the player has charted: the design doc says an
	## explored (grey) region still shows the coastline dimly, not just a fringe.
	var landmasses: Array = view_model.get("landmasses", [])
	var fog_data: Dictionary = view_model.get("fog", {})
	for lm in landmasses:
		var polygon: Array = lm.get("polygon", [])
		if polygon.size() < 3:
			continue
		var is_explored := _is_landmass_explored(lm, fog_data)
		if is_explored != only_explored:
			continue
		var screen_points := PackedVector2Array()
		for point in polygon:
			var wx := float(point.get("x", 0.0))
			var wy := float(point.get("y", 0.0))
			screen_points.append(world_to_screen(Vector2(wx, wy)))
		if is_explored:
			draw_colored_polygon(screen_points, COLOR_LAND_SILHOUETTE)
			draw_polyline(screen_points, COLOR_LAND_SILHOUETTE_OUTLINE, 1.5, true)
			if screen_points.size() >= 2:
				draw_line(screen_points[-1], screen_points[0], COLOR_LAND_SILHOUETTE_OUTLINE, 1.5)
		else:
			# Dim the landmass under fog
			draw_colored_polygon(screen_points, COLOR_LAND_EXPLORED)
			draw_polyline(screen_points, COLOR_LAND_EXPLORED_OUTLINE, 1.5, true)
			if screen_points.size() >= 2:
				draw_line(screen_points[-1], screen_points[0], COLOR_LAND_EXPLORED_OUTLINE, 1.5)


func _is_landmass_explored(lm: Dictionary, fog_data: Dictionary) -> bool:
	## A landmass is "charted" once a meaningful share of its coastline has been
	## revealed. Sampling the centroid is wrong (the coastal band rings the island, so
	## the centre stays BLACK while the coast is mapped); requiring only one revealed
	## sample is equally wrong (sailing into one harbour would reveal a whole continent).
	const EXPLORED_COAST_RATIO := 0.25
	if fog_data.is_empty():
		return true
	var state_grid: Array = fog_data.get("state_grid", [])
	if state_grid.is_empty():
		return true
	var polygon: Array = lm.get("polygon", [])
	if polygon.size() < 3:
		return false
	var cell_size: float = fog_data.get("cell_size", 8.0)
	var grid_height: int = fog_data.get("height", 0)
	var grid_width: int = fog_data.get("width", 0)
	if cell_size <= 0.0 or grid_height <= 0 or grid_width <= 0:
		return false
	var step := maxi(1, polygon.size() / 24)
	var samples := 0
	var revealed := 0
	var index := 0
	while index < polygon.size():
		var point: Dictionary = polygon[index]
		var gx := int(float(point.get("x", 0.0)) / cell_size)
		var gy := int(float(point.get("y", 0.0)) / cell_size)
		if gx >= 0 and gx < grid_width and gy >= 0 and gy < grid_height:
			samples += 1
			var row: Array = state_grid[gy]
			if gx < row.size() and int(row[gx]) != 0:
				revealed += 1
		index += step
	if samples == 0:
		return false
	return float(revealed) / float(samples) >= EXPLORED_COAST_RATIO


## 4.3 / U5：普通航线只在选中港口时显示。选中港口 → 只画与它相邻的航线；未选中
## （或选中了线索）→ 一条普通航线都不画；演出计划航线由 `_focus_points` 单独画，
## 不经过这个过滤。该函数是纯函数，无头测试可直接断言。
static func visible_routes(routes: Array, selected_port: String) -> Array:
	var visible: Array = []
	if selected_port.is_empty():
		return visible
	for route in routes:
		if not (route is Dictionary):
			continue
		var from_id := String((route as Dictionary).get("from", ""))
		var to_id := String((route as Dictionary).get("to", ""))
		if from_id == selected_port or to_id == selected_port:
			visible.append(route)
	return visible


## 航线标注距离的绘制条件：航线有距离且缩放足够大。选中任意港口后，其相邻的所有可见
## 航线都满足（不再限于「与当前港相连」的航线）。纯函数，测试可直接断言。
static func shows_route_distance(distance: float, zoom: float) -> bool:
	return zoom > 0.4 and distance > 0.0


func _draw_routes() -> void:
	# 演出时普通航线全部让位给计划航线（`_focus_points`）；非演出时只画选中港
	# 相邻的航线（U5：未选港口时海图无线）。
	var routes: Array = [] if _presentation_mode \
		else visible_routes(view_model.get("routes", []), _selected_port)
	var current_port := String(view_model.get("current_port_id", ""))
	var font := get_theme_default_font()
	for route in routes:
		var from_id := String(route.get("from", ""))
		var to_id := String(route.get("to", ""))
		var bezier_path: Array = route.get("bezier_path", [])
		# 读数值直接取海图边的权威距离（= 该折线的折线长度 = `voyage.preview` 计费距离）。
		var distance: float = float((route as Dictionary).get("distance", 0.0))
		var explored := bool(route.get("explored", false))
		if bezier_path.size() < 2:
			continue
		# Convert path to screen coordinates
		var screen_path := PackedVector2Array()
		for point in bezier_path:
			var wx := float(point.get("x", 0.0))
			var wy := float(point.get("y", 0.0))
			screen_path.append(world_to_screen(Vector2(wx, wy)))
		var is_active := from_id == current_port or to_id == current_port
		var unlocked := bool(route.get("unlocked", true))
		var color := COLOR_ROUTE_UNKNOWN
		if not unlocked:
			# 未测绘航线：两端已发现但不是「已测绘图」，画虚线，不可出航。
			color = COLOR_ROUTE_LOCKED
		elif is_active:
			color = COLOR_ROUTE_ACTIVE
		elif explored:
			color = COLOR_ROUTE_EXPLORED
		# Draw shadow
		draw_polyline(screen_path, Color(color.r, color.g, color.b, 0.075), 7.0, true)
		# Draw route
		var line_width := 2.0 if is_active else 1.3
		if unlocked:
			draw_polyline(screen_path, color, line_width, true)
		else:
			_draw_dashed_polyline(screen_path, color, line_width)
		# Distance label at the arc-length midpoint, skipped when a port label would sit
		# on top of it (index-based midpoints pile up next to the origin port).
		# 选中任意港口后它相邻的航线都会显示距离；不再只给「与当前港相连」的航线画
		# 距离（4.3/U5 的可见性过滤已保证未选港口时一条都不画）。
		if shows_route_distance(distance, _zoom):
			var midpoint := _path_midpoint(screen_path)
			if not _near_any_port(midpoint, 46.0):
				var text := "%d 海里" % int(roundf(distance))
				var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
				var plate := Rect2(
					midpoint + Vector2(-text_width * 0.5 - 3, -7),
					Vector2(text_width + 6, 13)
				)
				draw_rect(
					plate,
					Color(0.02, 0.08, 0.09, 0.7) if is_active else Color(0.02, 0.08, 0.09, 0.45),
					true
				)
				draw_string(
					font, midpoint + Vector2(-text_width * 0.5, 3), text,
					HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9,
					Color(0.9, 0.8, 0.58, 0.8) if is_active else Color(0.72, 0.8, 0.78, 0.6)
				)
	# 航行演出（含探索）的计划航线：`sea_chart.view` 的 routes 只含"两端都已发现"的
	# 港口对，而演出走的是世界航线表（探索时终点甚至不是港口）。`_focus_points` 就是
	# 这条计划航线，必须像已发现航线一样画成金色，否则玩家只能看到一条虚线预测线。
	if _presentation_mode and _focus_points.size() >= 2:
		var focus_screen := PackedVector2Array()
		for point in _focus_points:
			focus_screen.append(world_to_screen(point))
		draw_polyline(focus_screen, Color(COLOR_ROUTE_ACTIVE.r, COLOR_ROUTE_ACTIVE.g,
			COLOR_ROUTE_ACTIVE.b, 0.10), 8.0, true)
		draw_polyline(focus_screen, COLOR_ROUTE_ACTIVE, 2.4, true)


## Dashed variant of `draw_polyline`, used for chart routes that are physically present
## but not charted yet (unlocked == false). Godot only ships `draw_dashed_line`, so walk
## the polyline segment by segment with the same dash length.
func _draw_dashed_polyline(path: PackedVector2Array, color: Color, width: float) -> void:
	for index in range(1, path.size()):
		draw_dashed_line(path[index - 1], path[index], color, width, ROUTE_LOCKED_DASH)


## Point at half the polyline's arc length.
func _path_midpoint(path: PackedVector2Array) -> Vector2:
	if path.size() < 2:
		return path[0] if path.size() == 1 else Vector2.ZERO
	var total := 0.0
	for index in range(1, path.size()):
		total += path[index - 1].distance_to(path[index])
	var target := total * 0.5
	var walked := 0.0
	for index in range(1, path.size()):
		var segment := path[index - 1].distance_to(path[index])
		if walked + segment >= target:
			return path[index - 1].lerp(path[index], (target - walked) / maxf(segment, 0.0001))
		walked += segment
	return path[path.size() - 1]


## ── Clues (exploration phase 4.1) ──

## 画所有线索：level 2 方向箭头、level 3/4 虚线圆；level 4 圆内再写 `？港口名？`。
## level 1（"确有此地"）没有可画的图形，只存在于面板列表里。
func _draw_clues() -> void:
	var clues := get_clues()
	if clues.is_empty():
		return
	var font := get_theme_default_font()
	for entry in clues:
		if not (entry is Dictionary):
			continue
		var clue: Dictionary = entry
		var geometry := clue_screen_geometry(clue)
		if geometry.is_empty():
			continue
		var selected := String(clue.get("id", "")) == _selected_clue
		var color := COLOR_CLUE_SELECTED if selected else COLOR_CLUE
		match String(geometry.get("kind", "")):
			"arrow":
				_draw_clue_arrow(geometry, color, selected)
			"circle":
				_draw_clue_circle(clue, geometry, color, selected, font)


## level 2：从参照港出发的黄铜方向箭头。箭头长度是世界单位（`CLUE_ARROW_LENGTH`），
## 缩放时跟着海图一起缩，和港口保持稳定的空间关系。
func _draw_clue_arrow(geometry: Dictionary, color: Color, selected: bool) -> void:
	var start: Vector2 = geometry["start"]
	var end: Vector2 = geometry["end"]
	var delta := end - start
	if delta.length() < 0.001:
		return
	var direction := delta.normalized()
	if selected:
		draw_line(start, end, COLOR_CLUE_GLOW, 7.0)
	draw_line(start, end, color, 2.0 if not selected else 2.6)
	# 箭头两翼：在终点处沿 ±150° 画出。
	var head := 9.0
	var left := end - direction.rotated(0.5) * head
	var right := end - direction.rotated(-0.5) * head
	draw_line(end, left, color, 2.0 if not selected else 2.6)
	draw_line(end, right, color, 2.0 if not selected else 2.6)


## level 3/4：虚线圆 + 中心 `?`（level 4 换成 `？港口名？`）。选中时画一圈黄铜光晕。
func _draw_clue_circle(
	clue: Dictionary, geometry: Dictionary, color: Color, selected: bool, font: Font
) -> void:
	var center: Vector2 = geometry["center"]
	var radius: float = geometry["radius"]
	if radius < 2.0:
		return
	if selected:
		draw_circle(center, radius, COLOR_CLUE_GLOW)
		draw_circle(center, radius * 0.55, Color(0.95, 0.83, 0.48, 0.08))
	_draw_dashed_circle(center, radius, color, 2.0 if selected else 1.5)
	var level := int(clue.get("level", 0))
	var text := "?"
	if level >= 4:
		text = _clue_name_text(String(clue.get("name_key", "")))
	if text.is_empty():
		return
	var font_size := 13
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var position := center + Vector2(-text_size.x * 0.5, font_size * 0.35)
	# 深色底板让问号/港名在亮色虚线圆里也能读清。
	draw_rect(
		Rect2(center + Vector2(-text_size.x * 0.5 - 4, -font_size * 0.7),
			Vector2(text_size.x + 8, font_size * 1.35)),
		Color(0.02, 0.08, 0.09, 0.72), true
	)
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


## `？<翻译后的港口名>？`；name_key 缺失/无法翻译时退回 `?`（不渲染原始键名）。
func _clue_name_text(name_key: String) -> String:
	if name_key.is_empty():
		return "?"
	var name := _tr(name_key)
	if name.is_empty() or name == name_key:
		return "?"
	return "？%s？" % name


## 探索演出的未知终点：从当前船位到 `?` 终点的虚线预测线，终点一个 `?` 标记。
## `top_inset` 是海图上方的固定 chrome 高度（顶栏 + 状态条）：终点被它挡住时把标记
## clamp 到可见区（虚线也画到 clamp 后的位置），保证玩家永远看得到探索目标。
func _draw_unknown_destination() -> void:
	if _unknown_destination.is_empty():
		return
	var target := Vector2(
		float(_unknown_destination.get("x", 0.0)),
		float(_unknown_destination.get("y", 0.0))
	)
	var start := _current_ship_world()
	var start_screen := world_to_screen(start)
	var target_screen := world_to_screen(target)
	var marker := clamp_marker_to_view(
		target_screen, size, float(_unknown_destination.get("top_inset", 0.0))
	)
	var color := Color(0.94, 0.82, 0.48, 0.55)
	_draw_dashed_line(start_screen, marker, color, 1.6, 9.0, 7.0)
	var pulse := 0.5 + 0.5 * sin(_time * 2.4)
	draw_circle(marker, 11.0 + pulse * 3.0, Color(0.94, 0.82, 0.48, 0.10))
	draw_arc(marker, 9.0, 0.0, TAU, 28, Color(0.94, 0.82, 0.48, 0.25 + 0.2 * pulse), 1.0)
	var font := get_theme_default_font()
	var label_key := String(_unknown_destination.get("label_key", ""))
	var label := _tr(label_key) if not label_key.is_empty() else "?"
	if label.is_empty() or label == label_key:
		label = "？"
	var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	draw_rect(
		Rect2(marker + Vector2(-label_size.x * 0.5 - 5, -11), Vector2(label_size.x + 10, 22)),
		Color(0.03, 0.09, 0.10, 0.8), true
	)
	draw_string(font, marker + Vector2(-label_size.x * 0.5, 6), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, COLOR_CLUE_SELECTED)


## 把屏幕坐标 clamp 进「海图可见区」：左右/下各留 26 px，上边界加上传入的 chrome
## 高度。纯函数，测试可以直接断言（导航页的 `?` 曾整个藏在顶栏后面）。
static func clamp_marker_to_view(
	target: Vector2, view_size: Vector2, top_inset: float
) -> Vector2:
	var margin := 26.0
	var min_y := maxf(0.0, top_inset) + margin
	var max_y := maxf(min_y, view_size.y - margin)
	var max_x := maxf(margin, view_size.x - margin)
	return Vector2(clampf(target.x, margin, max_x), clampf(target.y, min_y, max_y))


## 当前船位的世界坐标：演出 override 优先，否则用 ViewModel 的 `ship_position`。
func _current_ship_world() -> Vector2:
	if _ship_override != null:
		return _ship_override
	var ship_pos: Dictionary = view_model.get("ship_position", {})
	return Vector2(float(ship_pos.get("x", 0.0)), float(ship_pos.get("y", 0.0)))


func _draw_dashed_line(
	from: Vector2, to: Vector2, color: Color, width: float, dash: float, gap: float
) -> void:
	var total := from.distance_to(to)
	if total < 0.001:
		return
	var direction := (to - from) / total
	var walked := 0.0
	while walked < total:
		var segment_end := minf(walked + dash, total)
		draw_line(from + direction * walked, from + direction * segment_end, color, width)
		walked = segment_end + gap


func _draw_dashed_circle(center: Vector2, radius: float, color: Color, width: float) -> void:
	if radius < 1.0:
		return
	var step := TAU / float(CLUE_CIRCLE_SEGMENTS)
	var index := 0
	while index < CLUE_CIRCLE_SEGMENTS:
		var start := float(index) * step
		var end := start + step * CLUE_DASH_RATIO
		draw_arc(center, radius, start, end, 6, color, width, true)
		index += 1


## 一条线索在当前 zoom/offset 下的屏幕几何；不可画（参照港不在图上 / 等级 1）返回 `{}`。
## kind = "arrow" → `{start, end}`；kind = "circle" → `{center, radius}`。
## 4.4：货物行情线索的目标是已发现港口、没有搜索区，因此不在图上画方向箭头 / 虚线圆
## （行情在右侧面板与线索列表页展示）。
func clue_screen_geometry(clue: Dictionary) -> Dictionary:
	if String(clue.get("type", "port_location")) == "port_goods":
		return {}
	var level := int(clue.get("level", 0))
	if level >= 3:
		var circle: Variant = clue.get("circle", null)
		if not (circle is Dictionary):
			return {}
		var radius := float((circle as Dictionary).get("radius", 0.0))
		if radius <= 0.0:
			return {}
		var center_world := Vector2(
			float((circle as Dictionary).get("x", 0.0)),
			float((circle as Dictionary).get("y", 0.0))
		)
		var geometry := clue_circle_screen(center_world, radius, _zoom, _offset)
		geometry["kind"] = "circle"
		return geometry
	if level == 2:
		var reference_position: Variant = _port_world_position(
			String(clue.get("reference_port_id", ""))
		)
		if reference_position == null:
			return {}
		var start_world: Vector2 = reference_position
		var end_world := clue_arrow_endpoint(
			start_world, float(clue.get("direction_angle", 0.0)), CLUE_ARROW_LENGTH
		)
		return {
			"kind": "arrow",
			"start": world_to_screen(start_world),
			"end": world_to_screen(end_world),
		}
	return {}


## level 2 箭头起点所在的参照港世界坐标；参照港不在当前视图模型里时返回 `null`
## （线索要跳过，不能画到 (0,0)）。
func _port_world_position(port_id: String) -> Variant:
	if port_id.is_empty():
		return null
	for port_data in view_model.get("ports", []):
		if String(port_data.get("id", "")) == port_id:
			return Vector2(
				float(port_data.get("x", 0.0)),
				float(port_data.get("y", 0.0))
			)
	return null


## 点击命中纯函数：箭头按线段距离、虚线圆按圆环或圆心距离，12 px 容差。
static func clue_hit_test(screen_position: Vector2, geometry: Dictionary) -> bool:
	if geometry.is_empty():
		return false
	match String(geometry.get("kind", "")):
		"arrow":
			var start: Vector2 = geometry.get("start", Vector2.ZERO)
			var end: Vector2 = geometry.get("end", Vector2.ZERO)
			return Geometry2D.get_closest_point_to_segment(
				screen_position, start, end
			).distance_to(screen_position) <= CLUE_HIT_TOLERANCE
		"circle":
			var center: Vector2 = geometry.get("center", Vector2.ZERO)
			var radius := float(geometry.get("radius", 0.0))
			var distance := screen_position.distance_to(center)
			return distance <= CLUE_HIT_TOLERANCE \
				or absf(distance - radius) <= CLUE_HIT_TOLERANCE
		_:
			return false


## 世界坐标 + 方向（弧度）+ 世界长度 → 箭头终点。纯几何，测试可单独断言。
static func clue_arrow_endpoint(
	port_world: Vector2, angle: float, length: float
) -> Vector2:
	return port_world + Vector2(cos(angle), sin(angle)) * length


## 世界坐标的圆 → 屏幕圆心/半径。纯几何：`zoom` 与 `offset` 就是
## `world_to_screen()` 用的那两个量，测试不用渲染即可断言换算。
static func clue_circle_screen(
	center_world: Vector2, radius_world: float, zoom: float, offset: Vector2
) -> Dictionary:
	return {
		"center": center_world * zoom + offset,
		"radius": maxf(0.0, radius_world * zoom),
	}


## True when `point` is within `radius` screen pixels of any drawn port icon.
func _near_any_port(point: Vector2, radius: float) -> bool:
	for port_data in view_model.get("ports", []):
		var port_pos := world_to_screen(Vector2(
			float(port_data.get("x", 0.0)), float(port_data.get("y", 0.0))
		))
		if point.distance_to(port_pos) <= radius:
			return true
	return false


func _draw_fog() -> void:
	## The fog is baked into a small RGBA texture (one texel per fog cell) and drawn
	## with linear filtering, so cell borders interpolate instead of showing as hard
	## rectangles — the design doc requires smoothed alpha between cells, and this is
	## also a single draw call instead of one per cell.
	if _fog_texture == null:
		return
	var top_left := world_to_screen(_fog_rect_world.position)
	var bottom_right := world_to_screen(_fog_rect_world.end)
	draw_texture_rect(_fog_texture, Rect2(top_left, bottom_right - top_left), false)


## Bakes `fog.alpha_grid` / `fog.state_grid` into a texture, one texel per cell.
func _build_fog_texture(fog_data: Dictionary) -> void:
	_fog_texture = null
	_fog_rect_world = Rect2()
	var grid_w: int = int(fog_data.get("width", 0))
	var grid_h: int = int(fog_data.get("height", 0))
	var alpha_grid: Array = fog_data.get("alpha_grid", [])
	var state_grid: Array = fog_data.get("state_grid", [])
	var cell_size: float = float(fog_data.get("cell_size", 0.0))
	if grid_w <= 0 or grid_h <= 0 or cell_size <= 0.0 or alpha_grid.size() < grid_h:
		return
	var image := Image.create(grid_w, grid_h, false, Image.FORMAT_RGBA8)
	for gy in grid_h:
		var alpha_row: Array = alpha_grid[gy]
		var state_row: Array = state_grid[gy]
		for gx in grid_w:
			var alpha: float = 1.0
			if gx < alpha_row.size():
				alpha = float(alpha_row[gx])
			var cell_state: int = 0
			if gx < state_row.size():
				cell_state = int(state_row[gx])
			var color: Color
			if cell_state == 2:  # VISIBLE: no fog at all
				color = Color(0, 0, 0, 0)
			elif cell_state == 1:  # EXPLORED: dim, lets the coastline read through
				color = Color(
					COLOR_FOG_EXPLORED.r, COLOR_FOG_EXPLORED.g, COLOR_FOG_EXPLORED.b,
					clampf(alpha * 0.85, 0.0, 1.0)
				)
			else:  # BLACK: opaque unknown
				color = Color(
					COLOR_FOG_BLACK.r, COLOR_FOG_BLACK.g, COLOR_FOG_BLACK.b,
					clampf(alpha, 0.0, 1.0)
				)
			image.set_pixel(gx, gy, color)
	_fog_texture = ImageTexture.create_from_image(image)
	# FogGrid maps world (0,0) to grid (0,0); honour a shifted world origin if any.
	var origin := Vector2(_world_bounds.position.x, _world_bounds.position.y)
	_fog_rect_world = Rect2(origin, Vector2(grid_w * cell_size, grid_h * cell_size))


func _draw_ports() -> void:
	var ports: Array = view_model.get("ports", [])
	var current_port := String(view_model.get("current_port_id", ""))
	var font := get_theme_default_font()
	for port_data in ports:
		var port_id := String(port_data.get("id", ""))
		var px := float(port_data.get("x", 0.0))
		var py := float(port_data.get("y", 0.0))
		var screen_pos := world_to_screen(Vector2(px, py))
		# Skip off-screen ports
		if screen_pos.x < -30.0 or screen_pos.x > size.x + 30.0:
			continue
		if screen_pos.y < -30.0 or screen_pos.y > size.y + 30.0:
			continue
		var is_current := port_id == current_port
		var is_visited := bool(port_data.get("visited", false))
		var is_discovered := bool(port_data.get("discovered", false))
		var is_selected := port_id == _selected_port
		# Port icon radius scales with zoom
		var base_r := 10.0
		var r := clampf(base_r * sqrt(_zoom), 5.0, 18.0)
		# Current port pulse
		if is_current:
			var pulse := 2.0 + sin(_time * 2.2) * 2.0
			draw_circle(screen_pos, r + 8.0 + pulse, Color(0.94, 0.8, 0.46, 0.055))
			draw_arc(screen_pos, r + 4.0 + pulse, 0.0, TAU, 40, Color(0.94, 0.8, 0.46, 0.25), 1.0)
		# Port body
		if is_current:
			draw_circle(screen_pos, r, COLOR_PORT_CURRENT)
			draw_circle(screen_pos, r * 0.4, Color("0b1116"))
		elif is_visited:
			draw_circle(screen_pos, r, Color(0.06, 0.14, 0.16, 0.95))
			draw_circle(screen_pos, r * 0.85, COLOR_PORT_VISITED)
			draw_circle(screen_pos, r * 0.35, Color("0b1116"))
		elif is_discovered:
			draw_circle(screen_pos, r * 0.7, Color(0.08, 0.16, 0.16, 0.95))
			draw_arc(screen_pos, r * 0.7, 0.0, TAU, 24, COLOR_PORT_DISCOVERED, 1.6)
			draw_circle(screen_pos, r * 0.24, COLOR_PORT_DISCOVERED)
		else:
			draw_circle(screen_pos, r * 0.5, Color(0.1, 0.16, 0.18, 0.95))
			draw_arc(screen_pos, r * 0.5, 0.0, TAU, 20, COLOR_PORT_UNKNOWN, 1.2)
		# Selection highlight
		if is_selected:
			draw_arc(screen_pos, r + 6.0, 0.0, TAU, 40, COLOR_BRASS, 2.0)
		# Hover highlight
		if port_id == _hovered_port:
			draw_arc(screen_pos, r + 8.0, 0.0, TAU, 40, COLOR_BRASS, 2.0)
		# Departure angle tick. `departure_angle` is already in radians (atan2 output) —
		# converting it again as degrees used to aim every tick due east.
		var exit := exit_direction(port_data)
		var tick_color := Color(0.62, 0.76, 0.73, 0.45)
		if is_current:
			tick_color = Color(0.94, 0.81, 0.5, 0.8)
		draw_line(
			screen_pos + exit * (r + 2.0),
			screen_pos + exit * (r + 10.0),
			tick_color, 1.4
		)
		# Port name label (only when zoomed in enough)
		if _zoom > 0.35:
			var name_key := String(port_data.get("name_key", ""))
			var label := _tr(name_key) if name_key != "" else port_id
			var label_color := COLOR_INK
			if is_current:
				label_color = COLOR_BRASS
			elif not is_visited and not is_discovered:
				label_color = Color(0.62, 0.7, 0.7, 0.65)
			var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
			var plate := Rect2(
				screen_pos + Vector2(-text_size.x * 0.5 - 5, r + 4),
				Vector2(text_size.x + 10, 17)
			)
			draw_rect(plate, Color(0.02, 0.08, 0.09, 0.72), true)
			draw_rect(plate, Color(0.44, 0.6, 0.56, 0.18 if not is_current else 0.42), false, 1.0)
			draw_string(font, screen_pos + Vector2(-text_size.x * 0.5, r + 16),
				label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12 if not is_current else 13, label_color)
		# Hover tooltip
		if port_id == _hovered_port and _zoom <= 0.35:
			var name_key := String(port_data.get("name_key", ""))
			var label := _tr(name_key) if name_key != "" else port_id
			var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
			draw_string(font, screen_pos + Vector2(-text_size.x * 0.5, r + 14),
				label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, COLOR_BRASS)


## 随船照亮的同心软圆（4.3.3 / U4）。外圈先画、内圈后画，中心叠加出最亮的暖光，
## 边缘平滑衰减到没有；不引入 shader 或新资产。
func _draw_ship_vision() -> void:
	if _ship_vision_radius <= 0.0:
		return
	var center := world_to_screen(_current_ship_world())
	var pixel_radius := _ship_vision_radius * _zoom
	if pixel_radius < 1.0:
		return
	var rings := ship_vision_rings(_ship_vision_radius, SHIP_VISION_RINGS)
	for index in range(rings.size() - 1, -1, -1):
		var ring: Dictionary = rings[index]
		var radius_px := float(ring.get("radius", 0.0)) * _zoom
		var alpha := float(ring.get("alpha", 0.0))
		if radius_px < 0.5 or alpha <= 0.0:
			continue
		draw_circle(center, radius_px, Color(
			COLOR_SHIP_VISION.r, COLOR_SHIP_VISION.g, COLOR_SHIP_VISION.b, alpha
		))
	# 核心的一点亮：船正下方始终像被提灯照着，软圆中心不会留出一个空斑。
	draw_circle(center, maxf(2.0, pixel_radius * 0.22),
		Color(COLOR_SHIP_VISION.r, COLOR_SHIP_VISION.g, COLOR_SHIP_VISION.b,
			SHIP_VISION_CORE_ALPHA))


## 软圆的同心环（纯函数）：返回 `[{radius, alpha}, ...]`，半径从
## `radius_world / steps` 单调增长到 `radius_world`，alpha 单调衰减、最后一环为 0。
## 供 `_draw_ship_vision()` 使用，也便于无头测试不渲染就断言衰减形状。
static func ship_vision_rings(
	radius_world: float, steps: int = SHIP_VISION_RINGS
) -> Array:
	var rings: Array = []
	var radius := maxf(0.0, radius_world)
	if radius <= 0.0:
		return rings
	var count := maxi(2, steps)
	for index in count:
		var fraction := float(index + 1) / float(count)
		rings.append({
			"radius": radius * fraction,
			"alpha": SHIP_VISION_MAX_ALPHA * pow(1.0 - fraction, 1.5),
		})
	return rings


func _draw_ship() -> void:
	var at_sea := bool(view_model.get("at_sea", false)) or _ship_override != null
	if not at_sea:
		return
	var world := Vector2.ZERO
	if _ship_override != null:
		world = _ship_override
	else:
		var ship_pos: Dictionary = view_model.get("ship_position", {})
		world = Vector2(float(ship_pos.get("x", 0.0)), float(ship_pos.get("y", 0.0)))
	var screen_pos := world_to_screen(world)
	var r := clampf(8.0 * sqrt(_zoom), 6.0, 18.0)
	var heading := _ship_heading if _has_ship_heading else 0.0
	var rotation := Transform2D(heading, screen_pos)
	var pulse := 2.0 + sin(_time * 3.0) * 2.0
	# Soft pulse ring behind the hull keeps the marker visible on dark fog.
	draw_circle(screen_pos, r * 1.4 + pulse, Color(COLOR_SHIP.r, COLOR_SHIP.g, COLOR_SHIP.b, 0.09))
	# Wake: two fading streaks behind the stern, so the icon reads as "under way"
	# and the heading is obvious even when the route bends only slightly.
	var stern_local := Vector2(-r * 1.35, 0.0)
	var wake := PackedVector2Array([
		rotation * (stern_local + Vector2(-r * 0.9, -r * 0.28)),
		rotation * (stern_local + Vector2(-r * 0.25, 0.0)),
		rotation * (stern_local + Vector2(-r * 0.9, r * 0.28)),
	])
	draw_polyline(wake, Color(0.82, 0.9, 0.92, 0.32), maxf(1.0, r * 0.14), true)
	# Hull: pointed bow along the heading, rounded stern behind it.
	var hull := PackedVector2Array()
	for point in ship_icon_shape(r):
		hull.append(rotation * point)
	draw_colored_polygon(hull, COLOR_SHIP)
	draw_polyline(hull, Color(0.55, 0.42, 0.14, 0.85), 1.3, true)
	# Deckhouse + funnel/mast cues, kept abstract at chart scale.
	var house := PackedVector2Array([
		rotation * Vector2(r * 0.1, -r * 0.3),
		rotation * Vector2(r * 0.55, -r * 0.22),
		rotation * Vector2(r * 0.55, r * 0.22),
		rotation * Vector2(r * 0.1, r * 0.3),
	])
	draw_colored_polygon(house, Color(0.55, 0.4, 0.16, 0.9))
	draw_line(rotation * Vector2(-r * 0.3, 0.0), rotation * Vector2(-r * 0.3, -r * 0.95),
		Color(0.9, 0.82, 0.62, 0.8), maxf(1.0, r * 0.12), true)


## 本地坐标（+X = 船艏、原点 = 船中心）的船体轮廓。纯几何函数：`_draw_ship()`
## 按 `_ship_heading` 旋转后绘制，测试也用它验证"船头指向移动方向"。
static func ship_icon_shape(radius: float) -> PackedVector2Array:
	var r := maxf(1.0, radius)
	return PackedVector2Array([
		Vector2(r * 1.3, 0.0),
		Vector2(r * 0.45, -r * 0.58),
		Vector2(-r * 0.85, -r * 0.5),
		Vector2(-r * 1.0, 0.0),
		Vector2(-r * 0.85, r * 0.5),
		Vector2(r * 0.45, r * 0.58),
	])


func _draw_compass() -> void:
	var center := Vector2(size.x - 50.0, 50.0)
	var font := get_theme_default_font()
	draw_circle(center, 22.0, Color(0.02, 0.08, 0.09, 0.6))
	draw_arc(center, 22.0, 0.0, TAU, 48, Color(0.62, 0.72, 0.66, 0.28), 1.0)
	draw_arc(center, 15.0, 0.0, TAU, 40, Color(0.62, 0.72, 0.66, 0.16), 1.0)
	draw_line(center + Vector2(0, -18), center + Vector2(0, 18), Color(0.72, 0.64, 0.42, 0.55), 1.0)
	draw_line(center + Vector2(-18, 0), center + Vector2(18, 0), Color(0.62, 0.72, 0.66, 0.3), 1.0)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -18), center + Vector2(-3.5, -8), center + Vector2(3.5, -8),
	]), Color(0.88, 0.7, 0.4, 0.7))
	draw_string(font, center + Vector2(-4, -26), "N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9,
		Color(0.78, 0.7, 0.48, 0.8))


func _draw_legend() -> void:
	var font := get_theme_default_font()
	var entries := [
		[COLOR_PORT_CURRENT, "当前港"], [COLOR_PORT_VISITED, "已访问"],
		[COLOR_PORT_DISCOVERED, "已发现"], [COLOR_PORT_UNKNOWN, "未知"],
	]
	var x := 16.0
	var y := size.y - 14.0
	# Background plate
	draw_rect(Rect2(x - 4, y - 14, 360, 22), Color(0.02, 0.08, 0.09, 0.6), true)
	for entry in entries:
		draw_circle(Vector2(x + 3.0, y - 3.0), 3.0, entry[0])
		draw_string(font, Vector2(x + 11.0, y), String(entry[1]),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color(0.62, 0.72, 0.69, 0.7))
		x += 11.0 + font.get_string_size(String(entry[1]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9).x + 16.0


func _draw_zoom_indicator() -> void:
	var font := get_theme_default_font()
	var text := "×%.1f" % _zoom
	draw_string(font, Vector2(size.x - 90, size.y - 14), text,
		HORIZONTAL_ALIGNMENT_RIGHT, 80.0, 10, Color(0.6, 0.7, 0.7, 0.5))


# ── Input handling ──

func _gui_input(event: InputEvent) -> void:
	# Zoom with mouse wheel
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, ZOOM_STEP)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1.0 / ZOOM_STEP)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				# Check for port click first: a clue arrow may start at a harbour, and
				# clicking the harbour itself should still select the harbour.
				var port_id := _port_at(mb.position)
				if not port_id.is_empty():
					select_port(port_id)
					port_clicked.emit(port_id)
					queue_redraw()
					accept_event()
					return
				# Then clues: arrow line / dashed circle ring / circle centre.
				var clue_id := _clue_at(mb.position)
				if not clue_id.is_empty():
					select_clue(clue_id)
					clue_clicked.emit(clue_id)
					queue_redraw()
					accept_event()
					return
				# Start dragging
				_is_dragging = true
				_drag_start = mb.position
				_drag_offset_start = _offset
			else:
				_is_dragging = false
			return
	# Pan with mouse drag
	if event is InputEventMouseMotion and _is_dragging:
		var motion := event as InputEventMouseMotion
		_offset = _drag_offset_start + (motion.position - _drag_start)
		queue_redraw()
		accept_event()
		return
	# Hover detection
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var port_id := _port_at(motion.position)
		var clue_id := "" if not port_id.is_empty() else _clue_at(motion.position)
		if port_id != _hovered_port or clue_id != _hovered_clue:
			_hovered_port = port_id
			_hovered_clue = clue_id
			port_hovered.emit(port_id)
			mouse_default_cursor_shape = (
				Control.CURSOR_POINTING_HAND
				if not port_id.is_empty() or not clue_id.is_empty()
				else Control.CURSOR_ARROW
			)
			queue_redraw()
	# Keyboard: Escape to deselect, +/- to zoom
	if event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		if key.keycode == KEY_ESCAPE:
			_selected_port = ""
			_selected_clue = ""
			queue_redraw()
			accept_event()
		elif key.keycode == KEY_EQUAL or key.keycode == KEY_KP_ADD:
			_zoom_at(size * 0.5, ZOOM_STEP)
			accept_event()
		elif key.keycode == KEY_MINUS or key.keycode == KEY_KP_SUBTRACT:
			_zoom_at(size * 0.5, 1.0 / ZOOM_STEP)
			accept_event()


func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var old_zoom := _zoom
	_zoom = clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	if _zoom == old_zoom:
		return
	# Keep the point under the cursor stationary
	var ratio := _zoom / old_zoom
	_offset = screen_pos - (screen_pos - _offset) * ratio
	queue_redraw()


func _port_at(screen_pos: Vector2) -> String:
	var ports: Array = view_model.get("ports", [])
	var best := ""
	var best_distance := 20.0
	for port_data in ports:
		var port_id := String(port_data.get("id", ""))
		var px := float(port_data.get("x", 0.0))
		var py := float(port_data.get("y", 0.0))
		var pos := world_to_screen(Vector2(px, py))
		var distance := screen_pos.distance_to(pos)
		var hit_radius := clampf(12.0 * sqrt(_zoom), 8.0, 22.0)
		if distance <= hit_radius and distance <= best_distance:
			best = port_id
			best_distance = distance
	return best


## 命中的线索 id；多个线索重叠时取形状距离最近的那个。
func _clue_at(screen_pos: Vector2) -> String:
	var best := ""
	var best_distance := INF
	for entry in get_clues():
		if not (entry is Dictionary):
			continue
		var clue: Dictionary = entry
		var geometry := clue_screen_geometry(clue)
		if geometry.is_empty() or not clue_hit_test(screen_pos, geometry):
			continue
		var distance := 0.0
		if String(geometry.get("kind", "")) == "circle":
			var center: Vector2 = geometry["center"]
			var radius := float(geometry["radius"])
			distance = absf(screen_pos.distance_to(center) - radius)
		else:
			distance = Geometry2D.get_closest_point_to_segment(
				screen_pos, geometry["start"], geometry["end"]
			).distance_to(screen_pos)
		if distance < best_distance:
			best = String(clue.get("id", ""))
			best_distance = distance
	return best


func _tr(key: String) -> String:
	if key.is_empty():
		return key
	if _translate.is_valid():
		var value: Variant = _translate.call(key)
		if value is String and not (value as String).is_empty():
			return value
	# Fallback: return the key itself so a missing translate callback is visible,
	# never a silently blank label.
	return key
