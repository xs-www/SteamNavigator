class_name SNCargoHoldPanel
extends PanelContainer
## @static-doc
## 作用：市场页左侧「船只背包」：顶部载重 / 货舱摘要，上半船舱货物（`SNDropZone` + 图标格子，委托货带锁定标记），下半当前港仓库材料；把图标拖拽映射成买卖 / 存取命令意图。
##
## Left-hand "ship hold" column of the direct-manipulation market page.
##
## Layout: summary (weight / cargo) on top, then two skin-backed drop zones:
## `船舱货物` (left accepts `market_item` for buy-into-cargo and `warehouse_item`
## for take-from-warehouse) and `港口仓库` (accepts `market_item` for buy-into-
## warehouse and `cargo_item` for store-into-warehouse). The panel only emits
## command intent; the Shell executes `trade.*` / `warehouse.*`.
##
## ## 外观来源（外部贴图 + SNSkin）
## - 外层用 Theme 变体 `SNPanel`；两个落点由 `SNDropZone` 提供
##   `panel_recess` / `panel_steel` 纹理高亮，本面板不手搓 StyleBox。
## - 文字颜色全部取 `SNSkin.color(token)`（text.light / text.muted /
##   brass.highlight / state.warning），图标格子里的锁定标记来自
##   `SNSkin.icon("status_locked")`，无硬编码路径与十六进制色。
## - 尺寸：固定 360 px 宽（Shell 设置），格子 2 列；面板自身不设最小高度，
##   竖直方向随内容增长、由外层 PageScroll 滚动。
##
## ## 契约与约束
## - `bind(view_model, translate)` 可重复调用：每次先清空自建子节点再重建。
## - ViewModel 字段按 `docs/design/MARKET_UI_REFACTOR.md` §3：`ship.hold` /
##   `warehouse.materials` 的 `icon` 已由 Shell 解析成 `Texture2D`。
## - 落点命令固定：market_item→cargo 区 `trade.buy{destination:"cargo"}`、
##   market_item→仓库区 `trade.buy{destination:"warehouse"}`、
##   cargo_item→仓库区 `warehouse.store_materials`、
##   warehouse_item→cargo 区 `warehouse.take_materials`。
## - 委托货（`is_contract`）格子不可拖拽、不产生命令。
## - `set_offer(offer)` / `clear_offer()` 是「拿起 / 放下」手势的入口：把市场商品
##   offer 转发给船舱 / 仓库两个 `SNDropZone`，玩家点一下落点即可放下。格子自己
##   也把 `drop_host` 指向所在 zone，保证点 zone 内的子格子同样能放下。
## @end-static-doc

signal command_requested(command: StringName, params: Dictionary)

const TILE_SCRIPT := preload("res://framework/ui/components/sn_item_tile.gd")
const ZONE_SCRIPT := preload("res://framework/ui/components/sn_drop_zone.gd")

const TILE_COLUMNS := 2
const ZONE_MIN_HEIGHT := 96.0

var _tr: Callable = Callable()
var _view_model: Dictionary = {}
var _cargo_zone: Variant = null
var _warehouse_zone: Variant = null
var _cargo_grid: GridContainer = null
var _warehouse_grid: GridContainer = null


## Rebuilds the whole backpack from the market ViewModel. Repeatable: every call
## drops the self-built children first, so the panel can re-bind on shell refresh.
func bind(view_model: Dictionary, translate: Callable) -> void:
	_tr = translate
	_view_model = view_model
	_clear()
	theme_type_variation = &"SNPanel"
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 10)
	add_child(content)
	content.add_child(_header())
	content.add_child(_summary(view_model))
	content.add_child(_build_cargo_zone(view_model))
	content.add_child(_build_warehouse_zone(view_model))


## 船舱 / 仓库两个落点（按节点名暴露给测试与后续船内交互）。
func cargo_zone() -> Control:
	return _cargo_zone as Control


func warehouse_zone() -> Control:
	return _warehouse_zone as Control


## Arms / clears the click-to-drop offer of the 拿起手势 on both zones. The zones
## filter incompatible payloads themselves (`SNDropZone.set_offer`).
func set_offer(offer: Dictionary) -> void:
	for zone in [_cargo_zone, _warehouse_zone]:
		if zone == null or not is_instance_valid(zone):
			continue
		zone.call("set_offer", offer)


func clear_offer() -> void:
	set_offer({})


## Handles a payload dropped on the 船舱货物 zone.
func handle_cargo_drop(data: Dictionary) -> void:
	var item_id := String(data.get("item_id", ""))
	if item_id.is_empty():
		return
	var amount := maxi(1, int(data.get("amount", 1)))
	match String(data.get("kind", "")):
		"market_item":
			command_requested.emit(&"trade.buy", {
				"item_id": item_id,
				"amount": amount,
				"destination": "cargo",
			})
		"warehouse_item":
			command_requested.emit(&"warehouse.take_materials", {
				"item_id": item_id,
				"amount": amount,
			})


## Handles a payload dropped on the 港口仓库 zone.
func handle_warehouse_drop(data: Dictionary) -> void:
	var item_id := String(data.get("item_id", ""))
	if item_id.is_empty():
		return
	var amount := maxi(1, int(data.get("amount", 1)))
	match String(data.get("kind", "")):
		"market_item":
			command_requested.emit(&"trade.buy", {
				"item_id": item_id,
				"amount": amount,
				"destination": "warehouse",
			})
		"cargo_item":
			command_requested.emit(&"warehouse.store_materials", {
				"item_id": item_id,
				"amount": amount,
			})


func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.free()


func _header() -> Control:
	var row := HBoxContainer.new()
	row.name = "Header"
	row.add_theme_constant_override("separation", 8)
	var title := _label(_loc("ui.market.backpack", "船只背包"), 22, SNSkin.color("text.light"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(_label(_loc("ui.hint.market_drag", "点击拿起 · 点落点放下 · 右键取消 · 可拖拽"), 11, SNSkin.color("text.muted")))
	return row


func _summary(view_model: Dictionary) -> Control:
	var ship: Dictionary = view_model.get("ship", {})
	var box := VBoxContainer.new()
	box.name = "Summary"
	box.add_theme_constant_override("separation", 2)
	var weight := _label(_loc("ui.market.weight_summary", "载重 %s / %s") % [
		_fmt(float(ship.get("total_weight", 0.0))),
		_fmt(float(ship.get("max_weight", 0.0))),
	], 12, SNSkin.color("text.light"))
	weight.name = "WeightSummary"
	box.add_child(weight)
	var cargo := _label(_loc("ui.market.hold_summary", "货舱 %s / %s") % [
		_fmt(float(ship.get("cargo_used", 0.0))),
		_fmt(float(ship.get("cargo_capacity", 0.0))),
	], 12, SNSkin.color("text.light"))
	cargo.name = "HoldSummary"
	box.add_child(cargo)
	return box


func _build_cargo_zone(view_model: Dictionary) -> Control:
	var ship: Dictionary = view_model.get("ship", {})
	var hold: Array = ship.get("hold", [])
	_cargo_zone = _zone("CargoDropZone", ["market_item", "warehouse_item"])
	_cargo_zone.dropped.connect(handle_cargo_drop)
	var content: VBoxContainer = _cargo_zone.content_root()
	content.add_child(_zone_heading("ui.market.cargo_section", "船舱货物", hold.size()))
	if hold.is_empty():
		content.add_child(_hint(_loc("ui.hint.cargo_zone_empty", "点击市场商品拿起，再点这里买入；也可拖拽。"), 12))
	else:
		_cargo_grid = _grid("CargoGrid")
		for row in hold:
			if row is Dictionary:
				_cargo_grid.add_child(_tile(row as Dictionary, "cargo_item", _cargo_zone))
		content.add_child(_cargo_grid)
		content.add_child(_hint(_loc("ui.hint.cargo_zone", "把货物拖到右侧市场卖出，或拖到下方仓库。"), 11))
	return _cargo_zone as Control


func _build_warehouse_zone(view_model: Dictionary) -> Control:
	var warehouse: Dictionary = view_model.get("warehouse", {})
	var materials: Array = warehouse.get("materials", [])
	_warehouse_zone = _zone("WarehouseDropZone", ["market_item", "cargo_item"])
	_warehouse_zone.dropped.connect(handle_warehouse_drop)
	var content: VBoxContainer = _warehouse_zone.content_root()
	content.add_child(_zone_heading("ui.market.warehouse_section", "港口仓库", materials.size()))
	if materials.is_empty():
		content.add_child(_hint(_loc("ui.hint.warehouse_zone_empty", "点击市场商品拿起，再点这里入库；也可拖拽。"), 12))
	else:
		_warehouse_grid = _grid("WarehouseGrid")
		for row in materials:
			if row is Dictionary:
				_warehouse_grid.add_child(_tile(row as Dictionary, "warehouse_item", _warehouse_zone))
		content.add_child(_warehouse_grid)
		content.add_child(_hint(_loc("ui.hint.warehouse_zone", "把船舱货物拖到这里存仓；拖到市场直接卖出。"), 11))
	return _warehouse_zone as Control


func _zone(node_name: String, accepted_kinds: Array) -> Control:
	var zone = ZONE_SCRIPT.new()
	zone.name = node_name
	zone.custom_minimum_size = Vector2(0.0, ZONE_MIN_HEIGHT)
	zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zone.configure(accepted_kinds, "panel_recess")
	return zone as Control


func _zone_heading(title_key: String, fallback: String, count: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	# PASS so a click on the heading still reaches the zone's click-to-drop handler.
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var title := _label(_loc(title_key, fallback), 15, SNSkin.color("brass.highlight"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(_label(_loc("ui.market.species_count", "%d 种") % count, 12, SNSkin.color("text.muted")))
	return row


func _grid(node_name: String) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = node_name
	grid.columns = TILE_COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# PASS: clicks on the grid gaps (between tiles) must bubble up to the zone.
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	return grid


func _tile(row: Dictionary, kind: String, drop_host: Control) -> Control:
	var item_id := String(row.get("item_id", ""))
	var is_contract := bool(row.get("is_contract", false))
	var amount := int(row.get("amount", 0))
	var sellable := int(row.get("sellable_amount", amount))
	var title := _loc(String(row.get("name_key", "")), item_id)
	var subtitle_parts: Array[String] = []
	var category := String(row.get("category", ""))
	if not category.is_empty():
		subtitle_parts.append(_loc("ui.item.category." + category, category))
	if bool(row.get("crafting_material", false)):
		subtitle_parts.append(_loc("ui.label.crafting_material", "材料"))
	if is_contract:
		subtitle_parts.append(_loc("ui.market.contract_locked", "委托货物不可交易"))
	var max_pending := sellable if kind == "cargo_item" else amount
	if is_contract:
		max_pending = 0
	var meta := ""
	if kind == "cargo_item":
		meta = _loc("ui.market.hold_tile_meta", "×%d · 均本 %s") % [
			amount,
			_fmt(float(row.get("avg_cost", 0.0))),
		]
	else:
		meta = _loc("ui.market.warehouse_tile_meta", "×%d · 单重 %s") % [
			amount,
			_fmt(float(row.get("unit_weight", 0.0))),
		]
	var tile = TILE_SCRIPT.new()
	tile.configure({
		"title": title,
		"subtitle": " · ".join(subtitle_parts),
		"meta": meta,
		"icon": row.get("icon", null),
		"max_pending": max_pending,
		"draggable": max_pending > 0,
		"locked": is_contract,
		"payload": {
			"kind": kind,
			"item_id": item_id,
			"amount": max_pending,
			"name": title,
		},
		"item": {
			"kind": kind,
			"item_id": item_id,
			"is_contract": is_contract,
			"amount": amount,
			"sellable_amount": sellable,
		},
	})
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.drop_host = drop_host
	return tile as Control


func _hint(text: String, font_size: int) -> Label:
	var label := _label(text, font_size, SNSkin.color("text.muted"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 0
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _loc(key: String, fallback: String) -> String:
	if not _tr.is_valid():
		return fallback
	var text := String(_tr.call(key))
	return fallback if text.is_empty() or text == key else text


func _fmt(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
