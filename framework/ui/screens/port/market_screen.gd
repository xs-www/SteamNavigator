class_name MarketScreen
extends VBoxContainer
## @static-doc
## 作用：港口市场页面（图标直接交易）：账册摘要 + 行情图标网格（左键 +1 / 右键清空 / 拖拽交易）+ 补给区块；行情格右上角显示剩余库存，整块市场面板是卖出落点，把拖入的船舱 / 仓库货物映射成 `trade.sell {source}` 命令。
##
## Direct-manipulation port market page (Bounty Train style).
##
## The icon grid replaces the old buy/sell quantity buttons: a market tile holds a
## pending amount (left click +1, right click clears) and dragging it to the left
## backpack buys into cargo / warehouse. Conversely the whole market panel is the
## sell drop target for `cargo_item` / `warehouse_item` payloads.
##
## The market tile's top-right badge shows the **remaining stock**
## (`badge_mode: "remaining"`, `max(0, stock - pending)`) instead of the selected
## amount: the selected amount is already painted on the cursor ghost
## (`SNCarryGhost`), together with the estimated cost.
##
## ## 外观来源（外部贴图 + SNSkin）
## - 「市场账册摘要」用 Theme 变体 `SNParchmentPanel`（暖纸面），纸面正文改用
##   `SNSkin.color("ink.primary")` / `paper.ink_muted`；行情格子是 `SNItemTile`
##   （`panel_recess` / `panel_steel` 皮肤纹理）；整个面板的落点用透明
##   `SNDropZone`（高亮时仍是皮肤纹理 + token 染色）。
## - 其余文字颜色取 `SNSkin.color(token)`（text.light / text.muted /
##   brass.highlight / state.water）。
## - 尺寸约束：行情网格 4 列（108 px 格子 + 8 px 间距），适配 Shell 提供的
##   640 px 右侧面板（内层 592 px）；`_grid_label` 保持 72 px 最小宽。
##
## ## 契约与约束
## - `bind(view_model, translate)` 可重复调用：每次先清空自建子节点再重建。
## - ViewModel 字段按 `docs/design/MARKET_UI_REFACTOR.md` §3；行情行 `icon` 已由
##   Shell 解析成 `Texture2D`，本页不解析资产路径。
## - 行情格角标是 `remaining` 语义（始终可见，纯数字 = `stock - pending`）；meta
##   只显示单价 + 趋势，玩家已选数量只在光标幽灵上显示，两处不重复。
## - 图标行 `stock<=0` 或 `buyable=false` 时不可拖拽（仍显示，标注「仅收购」）。
## - 待交易上限只按 `stock` 设置，不预扣金币与剩余载重：数量可以点到库存上限，
##   金币 / 载重不足由 `trade.buy` 失败并在状态栏报错（页面刷新后归零）。
## - 拖入市场面板的载荷 kind 只认 `cargo_item` / `warehouse_item`，命令固定为
##   `trade.sell {item_id, amount, source}`。
## - `_grid_label` / `_label` / `_loc` 是测试与旧调用方依赖的 helper，保留签名。
##
## ## 拿起 / 放下（feedback #1）
## - `signal carry_changed(offer)`：市场商品格子 `pending_changed` 的聚合结果。offer
##   是 `{kind:"market_item", item_id, name, icon, amount, unit_price}`，空字典表示
##   放下 / 取消。Shell 用它驱动光标幽灵（SNCarryGhost，显示 `×amount` 与
##   `unit_price × amount` 的预计消费）并把 offer 转发给船舱 / 仓库落点
##   （`SNCargoHoldPanel.set_offer`），玩家点落点即执行 `trade.buy`。
## - 同时只有一个格子被「拿起」：切换携带时先 `clear_pending()` 旧格子（避免重入：
##   先清 `_carry_tile` 再清旧格子，旧格子的 0 事件不会再发 carry_changed）。
## - 右键取消走 `_input`（格子 / 落点是 `MOUSE_FILTER_STOP`，普通 `_gui_input`
##   收不到别处的右键）：清 pending 并发 `carry_changed({})`。
## - 市场格子仍是原生拖拽来源，拖拽与拿起可共存；`_clear()` 会丢弃携带引用，
##   页面重建（命令成功）后 pending 与幽灵一起归零。
## @end-static-doc

signal command_requested(command: StringName, params: Dictionary)
## Aggregated 拿起 state: non-empty offer = carried stack, `{}` = nothing carried.
signal carry_changed(offer: Dictionary)

const SUPPLY_CARD_SCENE := preload("res://framework/ui/components/sn_supply_card.tscn")
const TILE_SCRIPT := preload("res://framework/ui/components/sn_item_tile.gd")
const ZONE_SCRIPT := preload("res://framework/ui/components/sn_drop_zone.gd")

## Market grid: four expanding tiles per row (min 108 px + 8 px gaps) fit the
## 592 px dock panel while leaving room for the single-line price / trend meta.
const MARKET_GRID_COLUMNS := 4
const GRID_SEPARATION := 8

var _tr: Callable = Callable()
var _sell_zone: Variant = null
## The market tile currently carried by the 拿起手势 (null = nothing carried).
var _carry_tile: Variant = null


func bind(view_model: Dictionary, translate: Callable) -> void:
	_tr = translate
	_clear()
	# The whole market panel is the sell drop target: cargo / warehouse payloads
	# dragged from the left backpack land here. Idle = transparent panel.
	_sell_zone = ZONE_SCRIPT.new()
	_sell_zone.name = "MarketDropZone"
	_sell_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sell_zone.content_padding = Vector2.ZERO
	_sell_zone.configure(["cargo_item", "warehouse_item"], "")
	_sell_zone.dropped.connect(handle_sell_drop)
	add_child(_sell_zone)
	var content: VBoxContainer = _sell_zone.content_root()
	content.add_theme_constant_override("separation", 12)
	var port: Dictionary = view_model.get("current_port", {})
	content.add_child(_heading(
		_loc("ui.nav.market", "Market"),
		_loc(String(port.get("name_key", "")), String(port.get("id", ""))),
		_loc("ui.market.grid_section", "市场行情")
	))
	content.add_child(_summary_panel(view_model))
	content.add_child(_market_section(view_model))
	content.add_child(_supply_block(view_model))


## Maps a payload dropped on the market panel to the sell command contract.
func handle_sell_drop(data: Dictionary) -> void:
	var item_id := String(data.get("item_id", ""))
	if item_id.is_empty():
		return
	var source := ""
	match String(data.get("kind", "")):
		"cargo_item":
			source = "cargo"
		"warehouse_item":
			source = "warehouse"
		_:
			return
	command_requested.emit(&"trade.sell", {
		"item_id": item_id,
		"amount": maxi(1, int(data.get("amount", 1))),
		"source": source,
	})


## Click-to-carry state of the market grid: the tile whose pending amount is being
## carried, or null. Exposed for the Shell wiring / tests.
func carrying_tile() -> Control:
	if _carry_tile == null or not is_instance_valid(_carry_tile):
		return null
	return _carry_tile as Control


## Right click anywhere on the page cancels the carry (the tiles and drop zones
## are `MOUSE_FILTER_STOP`, so a page-level `_input` is the only place that sees a
## right click outside the carried tile itself).
func _input(event: InputEvent) -> void:
	if _carry_tile == null:
		return
	if not (event is InputEventMouseButton):
		return
	var button := event as InputEventMouseButton
	if button.button_index != MOUSE_BUTTON_RIGHT or not button.pressed:
		return
	cancel_carry()
	if is_inside_tree():
		get_viewport().set_input_as_handled()


## Drops the carried stack without trading (right click / page teardown).
func cancel_carry() -> void:
	if _carry_tile == null:
		return
	var tile: Variant = _carry_tile
	_carry_tile = null
	if is_instance_valid(tile):
		tile.call("clear_pending")
	carry_changed.emit({})


## One market tile changed its pending amount: adopt it as the carried stack, or
## clear the carry when it dropped to zero. Switching tiles clears the old one
## first (with `_carry_tile` already nulled, so its zero event is a no-op).
func _on_tile_pending_changed(tile: Control, pending: int) -> void:
	if pending > 0:
		if _carry_tile != null and _carry_tile != tile:
			var previous: Variant = _carry_tile
			_carry_tile = null
			if is_instance_valid(previous):
				previous.call("clear_pending")
		_carry_tile = tile
		carry_changed.emit(_offer_for(tile))
		return
	if _carry_tile == tile:
		_carry_tile = null
		carry_changed.emit({})


## Payload for the cursor ghost + the drop zones. `amount` is the tile's pending
## amount, so the number on the ghost follows every +1 click; `unit_price` lets the
## Shell show the estimated cost (`unit_price × amount`) next to the carried stack.
func _offer_for(tile: Control) -> Dictionary:
	var payload: Dictionary = tile.get("payload")
	var item: Dictionary = tile.get("item")
	return {
		"kind": String(payload.get("kind", "")),
		"item_id": String(payload.get("item_id", "")),
		"name": String(payload.get("name", "")),
		"icon": tile.call("icon_texture"),
		"amount": int(tile.get("pending")),
		"unit_price": int(item.get("price", 0)),
	}



## 4.5.3：补给并市 —— 市场页上方的煤 / 水区块，复用 `supply.buy_*` 命令。
func _supply_block(view_model: Dictionary) -> Control:
	var supply: Dictionary = view_model.get("supply", {})
	var block := VBoxContainer.new()
	block.name = "MarketSupply"
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 7)
	if supply.is_empty():
		return block
	var title := _label(_loc("ui.market.supply_section", "补给（煤 / 水）"), 15, SNSkin.color("brass.highlight"))
	block.add_child(title)
	for kind in ["coal", "water"]:
		var data: Dictionary = supply.get("%s_view" % kind, {})
		if data.is_empty():
			continue
		var card: Variant = SUPPLY_CARD_SCENE.instantiate()
		card.custom_minimum_size = Vector2(0, 0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.bind(
			data,
			_loc("ui.label.%s" % kind, kind),
			_supply_blocker_labels(data.get("blockers", [])),
			_tr
		)
		card.command_requested.connect(func(command: StringName, params: Dictionary) -> void:
			command_requested.emit(command, params)
		)
		block.add_child(card)
	return block


func _supply_blocker_labels(blockers: Array) -> Array:
	var labels: Array = []
	for blocker in blockers:
		match String(blocker):
			"story_locked":
				labels.append(_loc("ui.story.supply_locked", ""))
			"no_supply":
				labels.append(_loc("ui.error.no_supply", ""))
			"no_stock":
				labels.append(_loc("ui.error.insufficient_stock", ""))
			"weight_limit":
				labels.append(_loc("ui.error.weight", ""))
			"insufficient_money":
				labels.append(_loc("ui.error.money", ""))
			_:
				labels.append(String(blocker))
	return labels


## 「账册摘要」是一张羊皮纸：纸面正文只用 ink token，避免浅色字落在暖纸上。
func _summary_panel(view_model: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SNParchmentPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)
	var ship: Dictionary = view_model.get("ship", {})
	content.add_child(_label(_loc("ui.market.summary", "金币 %d · 重量 %s / %s") % [
		int(view_model.get("money", 0)),
		_fmt(float(ship.get("total_weight", 0.0))),
		_fmt(float(ship.get("max_weight", 0.0))),
	], 13, SNSkin.color("ink.primary")))
	content.add_child(_label(_loc("ui.market.cargo_summary", "货舱 %s / %s · 库存成本 %s") % [
		_fmt(float(ship.get("cargo_used", 0.0))),
		_fmt(float(ship.get("cargo_capacity", 0.0))),
		_fmt(float(ship.get("cargo_cost_basis", 0.0))),
	], 13, SNSkin.color("ink.primary")))
	var hint := _paragraph(_loc("ui.hint.market", ""), 12, SNSkin.color("paper.ink_muted"))
	if not hint.text.is_empty():
		content.add_child(hint)
	return panel


func _market_section(view_model: Dictionary) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.name = "MarketList"
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 7)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var title := _label(_loc("ui.market.grid_section", "市场行情"), 15, SNSkin.color("brass.highlight"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_label(_loc("ui.hint.market_drag", "点击拿起 · 点落点放下 · 右键取消 · 可拖拽"), 11, SNSkin.color("text.muted")))
	section.add_child(header)
	var rows: Array = view_model.get("market", [])
	if rows.is_empty():
		section.add_child(_paragraph(_loc("ui.market.no_goods", "本港今日没有可交易的商品。"), 12, SNSkin.color("text.muted")))
		return section
	var trends: Dictionary = view_model.get("trends", {})
	var grid := GridContainer.new()
	grid.name = "MarketGrid"
	grid.columns = MARKET_GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", GRID_SEPARATION)
	grid.add_theme_constant_override("v_separation", GRID_SEPARATION)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for row in rows:
		if not (row is Dictionary):
			continue
		var item_id := String((row as Dictionary).get("item_id", ""))
		grid.add_child(_market_tile(row as Dictionary, String(trends.get(item_id, ""))))
	section.add_child(grid)
	section.add_child(_paragraph(_loc("ui.hint.market_sell", "把船只背包里的货物拖到这里卖出。"), 11, SNSkin.color("text.muted")))
	return section


func _market_tile(row: Dictionary, trend: String) -> Control:
	var item_id := String(row.get("item_id", ""))
	var buyable := bool(row.get("buyable", true))
	var stock := int(row.get("stock", 0))
	var price := int(row.get("price", 0))
	var title := _loc(String(row.get("name_key", "")), item_id)
	var subtitle := _item_subtitle(row, buyable)
	# 角标显示「还剩多少个」（remaining 模式），所以 meta 只保留单价 + 趋势，
	# 避免和角标重复；玩家已选数量显示在光标幽灵上。
	var meta := _loc("ui.market.tile_meta", "%d 金") % price
	meta += " " + _trend_arrow(trend)
	var tile: Variant = TILE_SCRIPT.new()
	tile.configure({
		"title": title,
		"subtitle": subtitle,
		"meta": meta,
		"icon": row.get("icon", null),
		"max_pending": stock if buyable else 0,
		"draggable": buyable and stock > 0,
		"locked": false,
		"badge_mode": "remaining",
		"stock": stock,
		"payload": {
			"kind": "market_item",
			"item_id": item_id,
			"amount": 1,
			"name": title,
		},
		"item": {
			"kind": "market_item",
			"item_id": item_id,
			"buyable": buyable,
			"stock": stock,
			"price": price,
		},
	})
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.pending_changed.connect(func(pending: int) -> void:
		_on_tile_pending_changed(tile, pending)
	)
	return tile as Control


func _item_subtitle(row: Dictionary, buyable: bool) -> String:
	var parts: Array[String] = []
	var category := String(row.get("category", ""))
	if not category.is_empty():
		parts.append(_loc("ui.item.category." + category, category))
	if bool(row.get("crafting_material", false)):
		parts.append(_loc("ui.label.crafting_material", "材料"))
	if not buyable:
		parts.append(_loc("ui.label.sell_only", "仅收购"))
	return " · ".join(parts)


func _trend_arrow(trend: String) -> String:
	match trend:
		"up":
			return "↑"
		"down":
			return "↓"
		_:
			return "→"


func _clear() -> void:
	# The page is being rebuilt (navigation / committed command): the carried tile
	# belongs to the old tree, so the Shell also hides its cursor ghost.
	_carry_tile = null
	_sell_zone = null
	for child in get_children():
		remove_child(child)
		child.free()


func _heading(eyebrow: String, title: String, detail: String) -> SNSectionHeader:
	var header := SNSectionHeader.new()
	header.eyebrow = eyebrow
	header.title = title
	header.detail = detail
	return header


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


## Long descriptive copy wraps inside the dock panel instead of forcing a
## horizontal minimum width; dense field labels stay single-line.
func _paragraph(text: String, font_size: int, color: Color) -> Label:
	var label := _label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 0
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _grid_label(text: String, font_size: int, color: Color) -> Label:
	var label := _label(text, font_size, color)
	label.custom_minimum_size.x = 72
	return label


func _loc(key: String, fallback: String) -> String:
	if not _tr.is_valid():
		return fallback
	var text := String(_tr.call(key))
	return fallback if text.is_empty() or text == key else text


func _fmt(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
