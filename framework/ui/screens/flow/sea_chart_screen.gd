class_name SeaChartScreen
extends VBoxContainer
## @static-doc
## 作用：全屏航海图页（海图系统阶段 2 入口集成，4.3.4 / U7 重构出航流程）：
## 左侧 `SNSeaChartView` 铺满、右侧 `SNSeaChartPanel`（320 px）展示选中港口/航线/线索，
## 顶部章节标题 + 关闭按钮；出航时在页内叠加 `SNVoyageConfirm` 确认弹窗。
## 数据只来自 `sea_chart.view`（外加 Shell 组合的 `departure` 块），经
## `bind(view_model, translate)` 注入。
##
## ## 契约与约束
## - 图上点击港口：视图只改选中态，面板绑定该港与当前港之间的航线数据；
##   本页自身不查询、不执行命令。
## - 面板「启航」/「循此线索出航」统一冒泡为 `departure_requested(kind, target_id)`
##   （kind = `voyage` | `explore`），由 Shell 打开确认弹窗（预估 + 锅炉策略切换 +
##   取消 / 启航），确认后才执行 `voyage.start` / `explore.start`。出航准备页已删除。
## - `view_model["departure"]` 非空时本页把确认弹窗绘制为居中遮罩层；弹窗的三个意图
##   信号原样转发：`departure_confirmed(kind, target_id, strategy_id)` /
##   `departure_cancelled` / `departure_strategy_changed(strategy_id)`。
## - `close_requested` 交给 Shell 决定返回页；`has_run=false` 时只显示提示文案。
## - 选中当前港时面板只显示港口信息（无航线区、无启航按钮）。
## - **线索**（探索系统 4.1）：图上点击线索 → 面板切到线索区块；面板的
##   `purchase_clue_requested` / `investigate_requested` 由本页原样转发给 Shell。
##   `can_buy_clue` 来自同一个 `sea_chart.view`，本页只负责塞给面板。
## - **逐级调查**（4.3.2 / U2）：面板 `investigate_requested(clue_id)` 由本页原样
##   转发为同名信号；Shell 执行 `clue.investigate` 后刷新海图。
## - **线索列表入口**（4.4.4）：顶栏「线索列表」按钮发 `clue_list_requested` 给 Shell；
##   `view_model["preselect_clue_id"]` 非空时本页在绑定时直接选中该线索（列表页
##   「点击回海图」用，即使货物线索在海图上没有几何也能在面板里打开）。
##
## ## 皮肤与节点约束（UI 贴图层）
## - 本页只做壳层与接线：章节标题走 `SNSectionHeader`（SNTitleLabel/SNEyebrowLabel/
##   SNDetailLabel），顶栏按钮统一 `SNGhostButton`，空态提示取
##   `SNSkin.color("text.muted")`；不再保留颜色常量。
## - 海图绘制、迷雾、航线与坐标全部在 `SNSeaChartView`（不在本页写域），右侧信息
##   面板在 `SNSeaChartPanel`（ui-port 写域）；本页不改它们的绘制契约。
## - 节点名 `Header` / `ChartBody` / `ChartRow` / `ClueListButton` / `CloseButton` /
##   `VoyageConfirm` 与 `PANEL_WIDTH = 320`、全窗 `VBox` 结构不变（test_sea_chart /
##   test_ui_shell 按名字与最小宽度断言）。
## - 确认弹窗已场景化（P0，见 docs/specs/UI_SCENE_MIGRATION.md）：本页只负责
##   `sn_voyage_confirm.tscn` 的实例化、信号接线与 `bind()`，不构造弹窗内部节点。
## @end-static-doc

signal close_requested
## 打开线索列表页（4.4.4）：Shell 负责查询 `clue.list` 并挂载页面。
signal clue_list_requested
## 面板的出航入口（4.3.4 / U7）：`kind` = `voyage` | `explore` | `goods`。
signal departure_requested(kind: String, target_id: String)
## 确认弹窗「启航」：Shell 直接执行 `voyage.start` / `explore.start`。
signal departure_confirmed(kind: String, target_id: String, strategy_id: String)
## 确认弹窗「取消」：Shell 关闭弹窗（弹窗自己的取消按钮不关页面）。
signal departure_cancelled
## 确认弹窗切换锅炉策略：Shell 用新策略重新查询并重开弹窗。
signal departure_strategy_changed(strategy_id: String)
## 购买线索：Shell 接 `clue.buy`，成功后刷新海图。
signal purchase_clue_requested
## 调查线索：Shell 接 `clue.investigate`，成功后刷新海图。
signal investigate_requested(clue_id: String)

const PANEL_WIDTH := 320.0
## 新组件按路径 preload，避免依赖编辑器生成的全局 class_name 缓存（无头测试与
## 全新检出都能直接加载；不引用 `SNVoyageConfirm` 这个全局名）。
## P0 场景化后弹窗是 `sn_voyage_confirm.tscn`（静态骨架在场景里，脚本只做绑定）。
const VOYAGE_CONFIRM_SCENE := preload("res://framework/ui/components/sn_voyage_confirm.tscn")

var _tr: Callable
var _view_model: Dictionary = {}
var _departure: Dictionary = {}
var _chart: SNSeaChartView
var _panel: SNSeaChartPanel
## 无类型：确认弹窗只通过信号 / 方法动态交互，避免全局 class_name 缓存依赖。
var _confirm = null


func bind(view_model: Dictionary, translate: Callable) -> void:
	_view_model = view_model
	_tr = translate
	_departure = view_model.get("departure", {}) if view_model.get("departure", null) is Dictionary else {}
	_rebuild()


func get_chart() -> SNSeaChartView:
	return _chart


func get_panel() -> SNSeaChartPanel:
	return _panel


## 当前是否存在待确认的出航弹窗（测试与 Shell 读这个而不是猜节点）。
func is_departure_open() -> bool:
	return not _departure.is_empty()


func get_departure() -> Dictionary:
	return _departure.duplicate(true)


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_confirm = null
	add_child(_header())
	if not bool(_view_model.get("has_run", false)):
		var message := Label.new()
		message.text = _loc("ui.sea_chart.no_data", "没有可用的世界数据。")
		message.add_theme_font_size_override("font_size", 15)
		message.add_theme_color_override("font_color", SNSkin.color("text.muted"))
		add_child(message)
		return
	# 图表与确认弹窗叠在同一个 body 里：弹窗用全窗锚点覆盖图表，而不是把页面挤成
	# 三行（否则「弹窗」会变成把海图压扁的普通页面块）。
	var body := Control.new()
	body.name = "ChartBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	var row := HBoxContainer.new()
	row.name = "ChartRow"
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 12)
	body.add_child(row)
	_chart = SNSeaChartView.new()
	_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart.port_clicked.connect(_on_port_clicked)
	_chart.clue_clicked.connect(_on_clue_clicked)
	row.add_child(_chart)
	_panel = SNSeaChartPanel.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.departure_requested.connect(departure_requested.emit)
	_panel.purchase_clue_requested.connect(purchase_clue_requested.emit)
	_panel.investigate_requested.connect(investigate_requested.emit)
	var can_buy: Variant = _view_model.get("can_buy_clue", {})
	if can_buy is Dictionary:
		_panel.set_can_buy_clue(can_buy as Dictionary)
	row.add_child(_panel)
	_chart.bind(_view_model, _tr)
	# 预选港口（「规划出航」入口传入）优先；否则选当前港。
	var initial := String(_view_model.get("preselect_port_id", ""))
	if initial.is_empty():
		initial = String(_view_model.get("current_port_id", ""))
	var ports: Array = _view_model.get("ports", [])
	if initial.is_empty() and not ports.is_empty():
		initial = String((ports[0] as Dictionary).get("id", ""))
	if not initial.is_empty():
		_chart.select_port(initial)
		_bind_panel(initial)
	# 4.4.4：从线索列表回海图时预选线索（货物线索没有几何，也能在面板里打开）。
	var preselect_clue := String(_view_model.get("preselect_clue_id", ""))
	if not preselect_clue.is_empty() and not _chart.clue_by_id(preselect_clue).is_empty():
		_on_clue_clicked(preselect_clue)
	if not _departure.is_empty():
		_add_confirm_overlay(body)


## 4.3.4 / U7：统一出航确认弹窗。数据（目标名、预估、策略列表）都由 Shell 预翻译，
## 本页只实例化 `sn_voyage_confirm.tscn`、接线并 `bind()`，不构造弹窗内部节点。
func _add_confirm_overlay(body: Control) -> void:
	_confirm = VOYAGE_CONFIRM_SCENE.instantiate()
	_confirm.name = "VoyageConfirm"
	var kind := String(_departure.get("kind", "voyage"))
	var target_id := String(_departure.get("target_id", ""))
	_confirm.confirmed.connect(func(strategy_id: String) -> void:
		departure_confirmed.emit(kind, target_id, strategy_id)
	)
	_confirm.cancelled.connect(func() -> void:
		departure_cancelled.emit()
	)
	_confirm.strategy_changed.connect(departure_strategy_changed.emit)
	body.add_child(_confirm)
	_confirm.bind(_departure, _tr)


func _header() -> Control:
	var header := HBoxContainer.new()
	header.name = "Header"
	var heading := SNSectionHeader.new()
	heading.eyebrow = _loc("ui.sea_chart.eyebrow", "NAUTICAL CHART")
	heading.title = _loc("ui.sea_chart.title", "航海图")
	heading.detail = _loc("ui.sea_chart.detail", "滚轮缩放 · 拖拽平移 · 点击港口查看详情")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var clue_list := Button.new()
	clue_list.name = "ClueListButton"
	clue_list.text = _loc("ui.button.clue_list", "线索列表")
	clue_list.theme_type_variation = &"SNGhostButton"
	clue_list.pressed.connect(func() -> void: clue_list_requested.emit())
	header.add_child(clue_list)
	var close := Button.new()
	close.name = "CloseButton"
	close.text = _loc("ui.sea_chart.close", "返回")
	close.theme_type_variation = &"SNGhostButton"
	close.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close)
	return header


func _on_port_clicked(port_id: String) -> void:
	if _chart == null:
		return
	# 港口选中会清掉线索选中（视图里两者互斥），面板随之回到港口信息。
	_chart.select_port(port_id)
	_bind_panel(port_id)


## 图上点中线索引 → 面板进入线索区块。视图本身已经处理了选中高亮，这里只负责
## 把线索数据喂给面板（屏幕不重算几何、不查询后端）。
func _on_clue_clicked(clue_id: String) -> void:
	if _chart == null or _panel == null:
		return
	var clue := _chart.clue_by_id(clue_id)
	if clue.is_empty():
		return
	_chart.select_clue(clue_id)
	_panel.bind_clue(clue, _tr)


## Same glue as the standalone preview: the selected port plus the route between
## it and the current harbour drive the right-hand panel.
func _bind_panel(port_id: String) -> void:
	if _panel == null:
		return
	var ports: Array = _view_model.get("ports", [])
	var current := String(_view_model.get("current_port_id", ""))
	var port_data := {}
	for entry in ports:
		if String((entry as Dictionary).get("id", "")) == port_id:
			port_data = entry
			break
	var route_data := {}
	if not port_data.is_empty() and port_id != current:
		for route in _view_model.get("routes", []):
			var from_id := String((route as Dictionary).get("from", ""))
			var to_id := String((route as Dictionary).get("to", ""))
			if (from_id == current and to_id == port_id) \
					or (from_id == port_id and to_id == current):
				route_data = route
				break
	_panel.bind(port_data, route_data, _tr)


func _loc(key: String, fallback: String) -> String:
	var text := String(_tr.call(key)) if _tr.is_valid() else fallback
	return fallback if text.is_empty() or text == key else text
