extends TestCase
## 迭代 2 UI 外壳接线冒烟测试（反馈 2/3/4/5/6）。
##
## Instantiates the real shell scene headless and drives the same builders the
## game uses, so a query/command wiring mistake in `main.gd` fails here instead
## of only showing up when someone runs the game. Components are preloaded by
## path, so the suite does not depend on the editor's global class cache.

const MAIN_SCENE := "res://framework/ui/shell/main.tscn"
const METER_SCRIPT := preload("res://framework/ui/components/sn_resource_meter.gd")
const CARD_SCRIPT := preload("res://framework/ui/components/sn_supply_card.gd")
const INTEL_TABLE_SCRIPT := preload("res://framework/ui/components/sn_intel_table.gd")
const ITEM_TILE_SCRIPT := preload("res://framework/ui/components/sn_item_tile.gd")
const DROP_ZONE_SCRIPT := preload("res://framework/ui/components/sn_drop_zone.gd")
const CARGO_HOLD_SCRIPT := preload("res://framework/ui/components/sn_cargo_hold_panel.gd")
const CARRY_GHOST_SCENE := preload("res://framework/ui/components/sn_carry_ghost.tscn")

const MARKET_SCREEN_SCRIPT := preload("res://framework/ui/screens/port/market_screen.gd")
const CONTRACTS_SCREEN_SCRIPT := preload("res://framework/ui/screens/port/contracts_screen.gd")
const TAVERN_SCREEN_SCRIPT := preload("res://framework/ui/screens/port/tavern_screen.gd")
const OVERVIEW_SCREEN_SCRIPT := preload("res://framework/ui/screens/port/overview_screen.gd")
const SHIPYARD_SCREEN_SCRIPT := preload("res://framework/ui/screens/port/shipyard_screen.gd")
const BASE_SCREEN_SCRIPT := preload("res://framework/ui/screens/port/base_screen.gd")
const PORT_MEMORY_SCREEN_SCRIPT := preload("res://framework/ui/screens/flow/port_memory_screen.gd")
const SETTLEMENT_SCREEN_SCRIPT := preload("res://framework/ui/screens/flow/settlement_screen.gd")
const AT_SEA_SCREEN_SCRIPT := preload("res://framework/ui/screens/flow/at_sea_screen.gd")
const EVENT_SCREEN_SCRIPT := preload("res://framework/ui/screens/flow/event_screen.gd")
const SEA_CHART_SCREEN_SCRIPT := preload("res://framework/ui/screens/flow/sea_chart_screen.gd")
const VICTORY_SCREEN_SCRIPT := preload("res://framework/ui/screens/flow/victory_screen.gd")
const MAIN_MENU_SCREEN_SCRIPT := preload("res://framework/ui/screens/menu/main_menu_screen.gd")
const NEW_GAME_SCREEN_SCRIPT := preload("res://framework/ui/screens/menu/new_game_screen.gd")
const MODS_SCREEN_SCRIPT := preload("res://framework/ui/screens/menu/mods_screen.gd")
const SETTINGS_SCREEN_SCRIPT := preload("res://framework/ui/screens/menu/settings_screen.gd")
const STEADY_BUILD := "core:starting_scenario/steady"

## Notices whose rendered sentence is spelled out (per language) in
## `test_notice_log_renders_filled_localized_text`: every notice with more than
## one slot belongs here, because a swapped pair of slots still renders as a
## plausible-looking sentence in either language.
const LITERAL_EXPECTED_NOTICE_KEYS := [
	"ui.notice.craft_ordered",
	"ui.notice.craft_completed",
	"ui.notice.waited",
	"ui.notice.chart_purchased",
]


func _mount(seed_value: int) -> Dictionary:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var started := context.commands.execute(&"run.start", {
		"starting_scenario": STEADY_BUILD,
		"seed": seed_value,
	})
	assert_true(bool(started.get("ok", false)), "run.start succeeds in the shell fixture: %s" % str(started))
	var scene: PackedScene = load(MAIN_SCENE)
	assert_not_null(scene, "the playable shell scene loads")
	var shell: Control = scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(shell)
	assert_true(shell.is_inside_tree(), "the shell fixture is inside the scene tree")
	return {"context": context, "shell": shell, "tree": tree}


func _unmount(bundle: Dictionary) -> void:
	var shell: Control = bundle["shell"]
	if shell.get_parent() != null:
		shell.get_parent().remove_child(shell)
	shell.free()


func _goto(shell: Control, screen: String) -> void:
	shell._active_screen = screen
	shell._refresh()


func _label_texts(root: Node, out: Array = []) -> Array:
	for child in root.get_children():
		if child is Label:
			out.append(String((child as Label).text))
		_label_texts(child, out)
	return out


func _texture_rects(root: Node, out: Array = []) -> Array:
	for child in root.get_children():
		if child is TextureRect:
			out.append(child)
		_texture_rects(child, out)
	return out


## 2026-10-28 图标轮：导航按钮改纯图标，入口身份放在 `nav_screen` meta；旧路径仍按
## 本地化导航名 `text` 回退，测试两种形态都能定位。
func _nav_buttons(root: Node) -> Array:
	var nav := _named_node(root, "Nav")
	if nav == null:
		return []
	var buttons: Array = []
	for child in nav.get_children():
		if child is Button:
			buttons.append(child)
	return buttons


func _nav_button(root: Node, screen: String) -> Button:
	for child in _nav_buttons(root):
		if String((child as Button).get_meta("nav_screen", "")) == screen:
			return child
	var shell := root
	var wanted := String(shell.call("_tr", "ui.nav.%s" % screen, screen)) if shell.has_method("_tr") else screen
	for child in _nav_buttons(root):
		if String((child as Button).text) == wanted:
			return child
	return null


## 文字标签被图标化后，语义只存在于控件 `tooltip_text` 上；按 tooltip 找 chip。
func _nodes_with_tooltip(root: Node, tooltip: String, out: Array = []) -> Array:
	if tooltip.is_empty():
		return out
	for child in root.get_children():
		if child is Control and String((child as Control).tooltip_text) == tooltip:
			out.append(child)
		_nodes_with_tooltip(child, tooltip, out)
	return out


## Every `push_notice(key, …)` written by the game code, so a missing or
## mis-ordered localization entry fails here instead of showing a raw template to
## the player. The keys are read from the domain/application sources (test
## fixtures excluded), not from a hand-kept list.
func _pushed_notice_keys() -> Array[String]:
	var regex := RegEx.new()
	regex.compile("push_notice\\(\"([^\"]+)\"")
	var keys: Array[String] = []
	for path in _gd_files("res://framework"):
		if path.contains("/tests/"):
			continue
		var source := FileAccess.get_file_as_string(path)
		for match_result in regex.search_all(source):
			var key := match_result.get_string(1)
			if not keys.has(key):
				keys.append(key)
	keys.sort()
	return keys


func _gd_files(root: String, out: Array[String] = []) -> Array[String]:
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		var path := root.path_join(entry)
		if dir.current_is_dir():
			_gd_files(path, out)
		elif entry.ends_with(".gd"):
			out.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
	return out


func _localization_keys(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(parsed is Dictionary, "%s is a JSON object" % path)
	return parsed if parsed is Dictionary else {}


## Slot sequence of a template, in order: zh/en must agree on it, because one
## positional argument list has to satisfy both languages.
func _slots(template: String) -> String:
	var regex := RegEx.new()
	regex.compile("%[sd]")
	var found: Array[String] = []
	for match_result in regex.search_all(template):
		found.append(match_result.get_string(0))
	return "".join(found)


func _nodes_with_script(root: Node, script: Script, out: Array = []) -> Array:
	for child in root.get_children():
		if child.get_script() == script:
			out.append(child)
		_nodes_with_script(child, script, out)
	return out


func _button_by_text(root: Node, text: String) -> Button:
	for child in root.get_children():
		if child is Button and String((child as Button).text) == text:
			return child
		var found := _button_by_text(child, text)
		if found != null:
			return found
	return null


## 设置页里字段名为「允许上传数据」的横向设置行（TELEMETRY.md §2）。
func _telemetry_row(root: Node) -> HBoxContainer:
	for node in root.find_children("*", "HBoxContainer", true, false):
		if node is HBoxContainer and _label_texts(node).has("允许上传数据"):
			return node
	return null


## 递归删除测试用 `user://` 目录树。
func _remove_tree(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		return
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if dir != null:
		dir.list_dir_begin()
		var entry := dir.get_next()
		while not entry.is_empty():
			var child := path.path_join(entry)
			if dir.current_is_dir():
				_remove_tree(child)
			else:
				DirAccess.remove_absolute(child)
			entry = dir.get_next()
		dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _meter_of_supply_card(root: Node, title: String) -> Control:
	for card in _nodes_with_script(root, CARD_SCRIPT):
		if not _label_texts(card).has(title):
			continue
		var meters := _nodes_with_script(card, METER_SCRIPT)
		if not meters.is_empty():
			return meters[0]
	return null


func test_dense_screen_fields_keep_horizontal_minimum_widths() -> void:
	for screen_script in [SETTINGS_SCREEN_SCRIPT, OVERVIEW_SCREEN_SCRIPT, MARKET_SCREEN_SCRIPT, SHIPYARD_SCREEN_SCRIPT, PORT_MEMORY_SCREEN_SCRIPT]:
		var screen: Control = screen_script.new()
		var label: Label = screen._label("横向字段不可逐字换行", 13, Color.WHITE)
		assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_OFF, "%s keeps dense row labels on one line" % screen_script.resource_path)
		label.free()
		screen.free()
	var market: Control = MARKET_SCREEN_SCRIPT.new()
	var market_cell: Label = market._grid_label("商品", 12, Color.WHITE)
	assert_true(market_cell.custom_minimum_size.x >= 72.0, "market cells reserve enough width for horizontal text")
	market_cell.free()
	market.free()
	var memory: Control = PORT_MEMORY_SCREEN_SCRIPT.new()
	var memory_cell: Label = memory._grid_label("上次储备", 12, Color.WHITE, 140.0)
	assert_true(memory_cell.custom_minimum_size.x >= 140.0, "port-memory snapshot columns reserve a readable width")
	memory_cell.free()
	memory.free()
	var table: Control = INTEL_TABLE_SCRIPT.new()
	table.bind(
		[{"port_id": "port", "name_key": "港口", "discovered": true}],
		[{"item_id": "goods", "name_key": "商品", "unit_weight": 1.0, "ref_price": 10, "cells": [{"known": true, "buy_price": 9, "sell_price": 10}]}],
		"port",
		func(key: String) -> String: return key
	)
	var grid := table.get_node("Content/Grid") as GridContainer
	assert_eq(grid.size_flags_horizontal, Control.SIZE_EXPAND_FILL, "intel matrix expands across its panel")
	var goods_header := grid.get_child(0) as PanelContainer
	var port_header := grid.get_child(3) as PanelContainer
	assert_eq(goods_header.size_flags_horizontal, Control.SIZE_FILL, "intel metadata columns keep a compact fixed width")
	assert_eq(port_header.size_flags_horizontal, Control.SIZE_EXPAND_FILL, "only port columns share the remaining width")
	assert_true(port_header.custom_minimum_size.x >= 120.0, "port columns reserve a readable minimum width")
	var regular_style := goods_header.get_theme_stylebox("panel")
	assert_true(regular_style is StyleBoxTexture, "ordinary intel cells are backed by a skin StyleBoxTexture, not a hand-built StyleBoxFlat")
	if regular_style is StyleBoxTexture:
		var regular_texture := (regular_style as StyleBoxTexture).texture
		assert_not_null(regular_texture, "the intel cell stylebox carries a skin texture")
		if regular_texture != null:
			assert_contains(String(regular_texture.resource_path), "assets/ui/skin/", "ordinary intel cells use an external skin texture")
	table.free()


func test_damaged_module_is_visible_in_the_shell() -> void:
	var bundle := _mount(5110)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	var module_chip: String = context.translate("ui.label.module_status", "部件")
	var damaged_label: String = context.translate("ui.label.damaged_modules", "受损部件")
	# 2026-10-28 图标轮：HUD chip 只有图标 + 数值，字段名只挂在 tooltip 上。
	assert_true(_nodes_with_tooltip(shell._root_box, module_chip).is_empty(),
		"a healthy ship shows no module chip in the info bar")
	ShipModules.damage(context.state.ship(), "boiler", 0, 0.5)
	shell._refresh()
	var texts := _label_texts(shell._root_box)
	assert_contains(texts, "1 · 50%", "the info bar adds a module status chip once a part is damaged")
	assert_false(_nodes_with_tooltip(shell._root_box, module_chip).is_empty(),
		"the damaged module chip keeps its field name in the tooltip")
	_goto(shell, "shipyard")
	var card_texts := _label_texts(shell._root_box)
	assert_contains(card_texts, damaged_label, "the ship card lists damaged modules")
	assert_contains(card_texts, "1 · 50%", "the ship card shows the worst condition")
	_unmount(bundle)


func test_stats_bar_shows_the_current_port_and_remaining_capacity() -> void:
	var bundle := _mount(5101)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	# The main view is the bare 3D stage, so the detailed 2D panels live on the
	# 2D overview page (top chrome "2D 总览" toggle); open it before asserting.
	shell._overview_stage_mode = false
	shell._refresh()
	var view: Dictionary = context.queries.execute(&"port.view")["data"]
	var ship: Dictionary = view["ship"]
	var texts := _label_texts(shell._root_box)
	assert_eq(_nodes_with_script(shell._root_box, OVERVIEW_SCREEN_SCRIPT).size(), 1, "the shell instantiates the extracted overview screen")
	assert_true(_named_node(shell._root_box, "MapCanvas") == null,
		"4.3/U6: the overview no longer instantiates the old map canvas")
	assert_false(bool(view["at_sea"]), "the fixture starts in port")
	# Expected values are recomputed from the domain (port definition + ShipOps),
	# not from the shell helpers that produced them.
	var port_name := context.translate(String(view["current_port"]["name_key"]), "")
	assert_contains(texts, port_name, "the info bar names the current port")
	var hub: RegistryHub = context.registries
	var ship_state: Dictionary = context.state.ship()
	var free_weight := maxf(0.0, ShipOps.max_weight(hub, ship_state) - ShipOps.total_weight(hub, context.state))
	assert_almost_eq(float(ship["free_weight"]), free_weight, 0.001, "the view reports the real remaining weight")
	assert_contains(texts, "%.1f / %.1f" % [free_weight, ShipOps.max_weight(hub, ship_state)], "the info bar shows remaining weight over the weight limit")
	var free_capacity := ShipOps.free_cargo_capacity(hub, ship_state)
	assert_almost_eq(float(ship["free_cargo_capacity"]), free_capacity, 0.001, "the view reports the real remaining cargo capacity")
	assert_contains(texts, "%.1f / %.1f" % [free_capacity, ShipOps.cargo_capacity(hub, ship_state)], "the info bar shows remaining cargo capacity, not only weight")
	assert_true(free_capacity > 0.0, "an empty hold still has free capacity to report")
	# At sea the same slot has to name where the ship is heading.
	var at_sea := view.duplicate(true)
	at_sea["at_sea"] = true
	at_sea["voyage"] = {"destination": String(context.state.current_port_id())}
	var at_sea_label: String = shell._current_port_label(at_sea)
	assert_true(at_sea_label.contains("→"), "the info bar shows a destination while sailing")
	assert_true(at_sea_label.contains(port_name), "the destination is the translated port name, not a raw id")
	_goto(shell, "market")
	assert_eq(_nodes_with_script(shell._root_box, MARKET_SCREEN_SCRIPT).size(), 1, "the shell instantiates the extracted market screen")
	_goto(shell, "contracts")
	assert_eq(_nodes_with_script(shell._root_box, CONTRACTS_SCREEN_SCRIPT).size(), 1, "the shell instantiates the extracted contracts screen")
	_goto(shell, "sea_chart")
	assert_eq(_nodes_with_script(shell._root_box, SEA_CHART_SCREEN_SCRIPT).size(), 1, "the chart page is the only departure route now")
	shell._memory_port_id = String(view.get("current_port_id", ""))
	_goto(shell, "port_memory")
	assert_eq(_nodes_with_script(shell._root_box, PORT_MEMORY_SCREEN_SCRIPT).size(), 1, "the shell instantiates the extracted port-memory screen")
	shell._settlement_summary = {"destination": String(view.get("current_port_id", "")), "arrival_time": 1.0, "contracts": []}
	_goto(shell, "settlement")
	assert_eq(_nodes_with_script(shell._root_box, SETTLEMENT_SCREEN_SCRIPT).size(), 1, "the shell instantiates the extracted settlement screen")
	shell._screen_at_sea(view, {"origin": String(view.get("current_port_id", "")), "destination": String(view.get("current_port_id", "")), "arrival_time": 1.0})
	# The at-sea chart is a full-window page (phase-3 acceptance feedback F3): it is
	# mounted outside the scrolling page stack, under the top chrome.
	assert_eq(_nodes_with_script(shell._fullscreen_layer, AT_SEA_SCREEN_SCRIPT).size(), 1,
		"the shell instantiates the extracted at-sea screen in the full-window layer")
	shell._screen_event(view, {"event_id": "fixture", "name_key": "fixture", "options": []})
	assert_eq(_nodes_with_script(shell._root_box, EVENT_SCREEN_SCRIPT).size(), 1, "the shell instantiates the extracted event screen")
	shell._screen_victory({"summary": {"seed": 5101, "modules": []}})
	assert_eq(_nodes_with_script(shell._root_box, VICTORY_SCREEN_SCRIPT).size(), 1, "the shell instantiates the extracted victory screen")
	context.reset_state()
	for menu_case in [
		["main", MAIN_MENU_SCREEN_SCRIPT],
		["new_game", NEW_GAME_SCREEN_SCRIPT],
		["mods", MODS_SCREEN_SCRIPT],
		["settings", SETTINGS_SCREEN_SCRIPT],
	]:
		shell._menu_screen = menu_case[0]
		shell._refresh()
		assert_eq(_nodes_with_script(shell._root_box, menu_case[1]).size(), 1, "the shell instantiates the extracted %s menu screen" % menu_case[0])
	_unmount(bundle)


func test_victory_plan_explains_how_to_clear_the_mvp() -> void:
	var bundle := _mount(5102)
	var shell: Control = bundle["shell"]
	# The victory plan is part of the 2D overview page over the stage.
	shell._overview_stage_mode = false
	shell._refresh()
	var overview_screens := _nodes_with_script(shell._root_box, OVERVIEW_SCREEN_SCRIPT)
	assert_eq(overview_screens.size(), 1, "the victory plan is hosted by the extracted overview screen")
	var overview_screen: Control = overview_screens[0]
	var texts := _label_texts(shell._root_box)
	assert_contains(texts, shell._tr("ui.victory.plan_title", ""), "the objective panel lists the win conditions")
	assert_contains(texts, shell._tr("ui.victory.plan_locked", ""), "an unfinished build says the large hull is still out of reach")
	var contracts: Dictionary = shell._last_port_view["contracts"]
	assert_eq(int(contracts["main_total"]), 5, "the main line has five chapters")
	assert_contains(texts, shell._tr("ui.victory.plan_readiness", "") % [
		int(contracts["main_done"]),
		int(contracts["main_total"]),
	], "chapter progress is shown as numbers")
	# Finishing the main line must switch the guidance to the shipyard step.
	var main_done: Control = overview_screen._victory_plan({
		"contracts": {"main_done": 5, "main_total": 5, "main_chain_complete": true},
		"victory": {"conditions": {
			"main_complete": true, "large_hull": false, "boiler": false,
			"cargo": false, "shipyard": false, "ready": false,
		}},
	})
	assert_contains(_label_texts(main_done), shell._tr("ui.victory.plan_main_done", ""), "a finished main line points at the shipyard")
	main_done.free()
	var ready: Control = overview_screen._victory_plan({
		"contracts": {"main_done": 5, "main_total": 5, "main_chain_complete": true},
		"victory": {"conditions": {
			"main_complete": true, "large_hull": true, "boiler": true,
			"cargo": true, "shipyard": true, "ready": true,
		}},
	})
	assert_contains(_label_texts(ready), shell._tr("ui.victory.plan_ready", ""), "a satisfied build says installing a module wins")
	ready.free()
	# Requirement: the win checklist lives on the overview only; the refit page
	# now opens the 组件 categories instead of repeating the victory plan.
	_goto(shell, "shipyard")
	var shipyard_texts := _label_texts(shell._root_box)
	assert_false(shipyard_texts.has(shell._tr("ui.victory.plan_title", "")), "the shipyard page no longer repeats the win conditions")
	assert_contains(shipyard_texts, shell._tr("ui.label.components", ""), "the shipyard page shows the 组件 categories instead")
	_unmount(bundle)


func test_shipyard_order_and_port_wait_make_time_move() -> void:
	var bundle := _mount(5103)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	context.state.set_money(5000)
	_goto(shell, "shipyard")
	var shipyard_screens := _nodes_with_script(shell._root_box, SHIPYARD_SCREEN_SCRIPT)
	assert_eq(shipyard_screens.size(), 1, "the shell instantiates the extracted shipyard screen")
	var shipyard_screen: Control = shipyard_screens[0]
	var yard: Dictionary = context.queries.execute(&"shipyard.view")["data"]
	assert_true(bool(yard["has_shipyard"]), "the fixture hub has a shipyard")
	var recipe := {}
	for row in yard["craft"]:
		if row is Dictionary and bool(row.get("money_only", false)) and bool(row.get("can_craft", false)):
			recipe = row
			break
	assert_true(not recipe.is_empty(), "a money-only tier-1 recipe is craftable without materials")
	# Craft entries now live in the module type's refit category, craft tab.
	shipyard_screen.set_category(String(recipe["content_type"]))
	assert_true(bool(shipyard_screen._refit), "opening a category enters refit mode")
	shipyard_screen.set_tab("craft")
	var craft_button := _button_by_text(shell._root_box, shipyard_screen._craft_button_text(recipe))
	assert_not_null(craft_button, "the craft button states the work hours it commits to")
	var module_id := String(recipe["module_id"])
	var port_id := String(context.state.current_port_id())
	var money_before := context.state.money()
	craft_button.emit_signal("pressed")
	assert_eq(CraftOps.orders(context.state).size(), 1, "crafting queues an order instead of finishing instantly")
	assert_eq(context.state.money(), money_before - int(recipe["craft_cost"]), "the order charges its gold cost")
	assert_eq(WarehouseOps.module_qty(context.state, port_id, module_id), 0, "the ordered module is not delivered immediately")
	# The command rebuilds the page; the shell must keep refit mode + category.
	shipyard_screens = _nodes_with_script(shell._root_box, SHIPYARD_SCREEN_SCRIPT)
	assert_eq(shipyard_screens.size(), 1, "the shell rebuilds the shipyard page after the craft command")
	if shipyard_screens.size() != 1:
		_unmount(bundle)
		return
	var rebuilt: Control = shipyard_screens[0]
	assert_true(bool(rebuilt._refit), "the shell keeps refit mode after a command")
	assert_eq(String(rebuilt._category), String(recipe["content_type"]), "the shell keeps the refit category across the rebuild")
	# Port wait now lives in 杂项, together with orders and warehouse materials.
	rebuilt.set_category("misc")
	var wait_button := _button_by_text(shell._root_box, "24 h")
	assert_not_null(wait_button, "the 杂项 category offers a 24-hour port wait")
	var time_before := context.state.now()
	wait_button.emit_signal("pressed")
	assert_almost_eq(context.state.now(), time_before + 24.0, 0.001, "the wait button advances game time")
	assert_eq(CraftOps.orders(context.state).size(), 0, "the finished order leaves the queue")
	assert_eq(WarehouseOps.module_qty(context.state, port_id, module_id), 1, "the finished module lands in the ordering port warehouse")
	_unmount(bundle)


## 2026-10-28 反馈：市场只显示「本港买得到」的货；仅收购品种不再占格子，但卖出
## 不受影响（整块市场面板是落点，`trade.sell` 不依赖行情行存在）。
func test_market_hides_sell_only_goods_but_still_allows_selling() -> void:
	var bundle := _mount(5211)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	var view: Dictionary = context.queries.execute(&"port.view")["data"]
	var sell_only := {}
	for raw_row in view["market"]:
		if raw_row is Dictionary and not bool((raw_row as Dictionary).get("buyable", true)):
			sell_only = raw_row
			break
	assert_true(not sell_only.is_empty(), "the fixture market exposes a sell-only good")
	if sell_only.is_empty():
		_unmount(bundle)
		return
	var item_id := String(sell_only["item_id"])
	var item_name := context.translate(String(sell_only.get("name_key", "")), item_id)
	ShipOps.add_cargo(context.state.ship(), item_id, 2, "", 0.0)
	_goto(shell, "market")
	var grid := _named_node(shell._root_box, "MarketGrid")
	assert_not_null(grid, "the market renders its goods grid")
	if grid != null:
		assert_false(_label_texts(grid).has(item_name),
			"a sell-only good gets no market tile")
	# The sell path is the drop zone on the panel, not the removed row.
	var sell := context.commands.execute(&"trade.sell", {"item_id": item_id, "amount": 1})
	assert_true(bool(sell.get("ok", false)), "the sell-only good can still be sold: %s" % str(sell))
	_unmount(bundle)


func test_market_supply_block_paints_the_lost_capacity_band() -> void:
	var bundle := _mount(5104)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	context.state.ship()["coal"] = 0.0
	context.state.ship()["water"] = 0.0
	_goto(shell, "market")
	assert_eq(_nodes_with_script(shell._root_box, MARKET_SCREEN_SCRIPT).size(), 1, "the shell mounts the market page")
	assert_true(shell.find_child("MarketSupply", true, false) != null, "the market page hosts the supply block")
	var water_label: String = shell._tr("ui.label.water", "")
	var water_meter := _meter_of_supply_card(shell._root_box, water_label)
	assert_not_null(water_meter, "the market supply block renders a water meter")
	assert_almost_eq(float(water_meter.loss_value), 0.0, 0.001, "nothing is lost while both tanks are empty")
	var before: Dictionary = context.queries.execute(&"supply.view")["data"]["water_view"]
	var bought := context.commands.execute(&"supply.buy_coal", {"amount": 10})
	assert_true(bool(bought.get("ok", false)), "buying coal succeeds: %s" % str(bought))
	_goto(shell, "market")
	water_meter = _meter_of_supply_card(shell._root_box, water_label)
	var after: Dictionary = context.queries.execute(&"supply.view")["data"]["water_view"]
	assert_eq(int(after["cap_loss"]), 10, "loading coal takes ten units off the water ceiling")
	assert_eq(int(water_meter.loss_value), int(after["cap_loss"]), "the water meter paints the lost ceiling")
	assert_eq(int(water_meter.maximum_value), int(after["capacity"]), "the meter maximum is the reduced physical ceiling")
	assert_almost_eq(
		float(water_meter.maximum_value) + float(water_meter.loss_value),
		float(before["maximum_baseline"]),
		0.001,
		"the drawn bar spans the baseline ceiling, so the fill ratio cannot rise"
	)
	_unmount(bundle)


func test_shipyard_refit_draws_over_the_port_stage_and_chrome_names_the_port() -> void:
	var bundle := _mount(5206)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	_goto(shell, "shipyard")
	# 顶栏品牌位换成港口名：产品名不再出现在常驻 chrome 里。
	var chrome_texts := _label_texts(shell._top_chrome)
	assert_false(chrome_texts.has(shell._tr("ui.app.title", "Steam Navigator")),
		"the chrome no longer shows the product title")
	assert_false(chrome_texts.has("S T E A M   N A V I G A T O R"),
		"the chrome no longer shows the spaced brand line")
	var view: Dictionary = context.queries.execute(&"port.view")["data"]
	assert_contains(chrome_texts, context.translate(String(view["current_port"]["name_key"]), ""),
		"the port name sits where the brand used to be")
	# 正常态：面板内的 3D 船体舞台负责船体，港区舞台保持隐藏。
	var host: Variant = shell.get("_port_stage_host")
	assert_true(host == null or not bool(host.is_stage_visible()),
		"the normal shipyard page keeps the district stage hidden")
	var screens := _nodes_with_script(shell._root_box, SHIPYARD_SCREEN_SCRIPT)
	assert_eq(screens.size(), 1, "the shipyard page is mounted once")
	if screens.size() != 1:
		_unmount(bundle)
		return
	var screen: Control = screens[0]
	var refit_button: Variant = screen.get("_refit_button")
	assert_true(refit_button is Button, "the normal page offers the refit toggle")
	if not (refit_button is Button):
		_unmount(bundle)
		return
	(refit_button as Button).emit_signal("pressed")
	# 改装态：港区舞台显示并停在船厂站位（页面本身只画蓝图与操作坞）。
	host = shell.get("_port_stage_host")
	assert_not_null(host, "refit mode mounts the shared 3D port stage")
	if host != null:
		assert_true(bool(host.is_stage_visible()), "refit mode shows the 3D shipyard station")
		var stage: Node = host.current_stage()
		if stage != null and stage.has_method("current_station"):
			assert_eq(String(stage.current_station()), "shipyard", "the stage focuses the shipyard station")
	# 退出改装态：舞台再次隐藏，避免与面板内的 3D 船体重叠。
	var done_button: Variant = screen.get("_refit_button")
	assert_true(done_button is Button, "refit mode keeps a toggle to leave it")
	if done_button is Button:
		(done_button as Button).emit_signal("pressed")
	if host != null:
		assert_false(bool(host.is_stage_visible()), "leaving refit hides the district stage again")
	_unmount(bundle)


func test_tavern_screen_renders_price_intel_and_port_clues() -> void:
	var bundle := _mount(5105)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	context.commands.execute(&"intel.refresh")
	_goto(shell, "tavern")
	assert_eq(_nodes_with_script(shell._root_box, TAVERN_SCREEN_SCRIPT).size(), 1, "the shell instantiates the extracted tavern screen")
	var tables := _nodes_with_script(shell._root_box, INTEL_TABLE_SCRIPT)
	assert_eq(tables.size(), 1, "the tavern screen renders one price-intel table")
	var texts := _label_texts(tables[0])
	assert_contains(texts, shell._tr("ui.label.goods", ""), "the table has a goods column")
	assert_contains(texts, shell._tr("ui.label.unknown_port", ""), "unexplored ports keep their own masked column")
	assert_contains(texts, "？", "unknown cells are masked with ?")
	var intel: Dictionary = context.queries.execute(&"intel.view")["data"]
	assert_eq(int(intel["column_count"]), MapOps.ports(context.state.world()).size(), "every port on the chart gets a column, explored or not")
	var undiscovered := 0
	for column in intel["columns"]:
		if not bool(column["discovered"]):
			undiscovered += 1
	assert_true(undiscovered >= 1, "the chart has an unexplored port to mask")
	# 4.5.4：酒馆页同时提供港口线索入口（购买 + 列表）。
	var buy_button := _named_node(shell._root_box, "BuyClueButton") as Button
	assert_not_null(buy_button, "the tavern renders the buy-clue entry")
	var clues_before := ClueService.active(context.state).size()
	if buy_button != null:
		assert_false(buy_button.disabled, "buying a clue is available at a tavern with unknown harbours")
		buy_button.emit_signal("pressed")
	assert_eq(ClueService.active(context.state).size(), clues_before + 1,
		"pressing the tavern buy entry runs the real clue.buy command")
	_unmount(bundle)


func test_base_page_claims_and_builds_from_the_ui() -> void:
	var bundle := _mount(4242)
	var context: AppContext = bundle["context"]
	var shell: Control = bundle["shell"]
	context.state.set_money(5000)
	WarehouseOps.add_material(context.state, context.state.current_port_id(), "core:item/timber", 10)
	shell._active_screen = "base"
	shell._rebuild_ui()
	var screen: Control = shell.find_child("BaseScreen", true, false)
	assert_not_null(screen, "the base page mounts from the navigation")
	var site_name := context.translate("base_site.core.coastal_outpost.name", "")
	var claim := _button_by_text(screen, "%s（250 金）" % site_name)
	assert_not_null(claim, "the claim button lists the base site and cost: %s" % str(_label_texts(screen)))
	claim.pressed.emit()
	assert_true(context.state.data.get("base", null) is Dictionary, "the claim button runs base.claim through the shell")
	shell._rebuild_ui()
	screen = shell.find_child("BaseScreen", true, false)
	assert_not_null(screen, "the page rebuilds after claiming")
	var deposit := _button_by_text(screen, "投入 5")
	assert_not_null(deposit, "the storage deposit button is offered for port warehouse materials")
	deposit.pressed.emit()
	shell._rebuild_ui()
	screen = shell.find_child("BaseScreen", true, false)
	var building_name := context.translate("building.core.sawmill.name", "")
	var build := _button_by_text(screen, "%s（120 金）" % building_name)
	assert_not_null(build, "the build button lists the sawmill: %s" % str(_label_texts(screen)))
	build.pressed.emit()
	var view: Dictionary = context.queries.execute(&"base.view")["data"]
	assert_eq(int(view.get("slots_used", 0)), 1, "the build button starts a base building")
	_unmount(bundle)


func test_auto_trade_page_starts_a_policy_from_the_ui() -> void:
	var bundle := _mount(4243)
	var context: AppContext = bundle["context"]
	var shell: Control = bundle["shell"]
	shell._active_screen = "trade"
	shell._rebuild_ui()
	var screen: Control = shell.find_child("AutoTradeScreen", true, false)
	assert_not_null(screen, "the auto trade page mounts from the navigation")
	var policy := context.registries.get_all(ContentTypes.TRADE_POLICY)[0]
	var policy_name := context.translate(policy.name_key, policy.id)
	var start := _button_by_text(screen, policy_name)
	assert_not_null(start, "the start button lists the policy: %s" % str(_label_texts(screen)))
	start.pressed.emit()
	assert_true(context.state.data.get("trade", null) is Dictionary, "the button runs auto_trade.start")
	assert_true(bool(context.queries.execute(&"auto_trade.view")["data"].get("active", false)), "the view reports the active run")
	_unmount(bundle)


func test_ruins_page_starts_an_expedition_from_the_ui() -> void:
	var bundle := _mount(4244)
	var context: AppContext = bundle["context"]
	var shell: Control = bundle["shell"]
	shell._active_screen = "ruins"
	shell._rebuild_ui()
	var screen: Control = shell.find_child("RuinsScreen", true, false)
	assert_not_null(screen, "the ruins page mounts from the navigation")
	var ruin := context.registries.get_all(ContentTypes.RUIN_ARCHETYPE)[0]
	var ruin_name := context.translate(ruin.name_key, ruin.id)
	var start := _button_by_text(screen, ruin_name)
	assert_not_null(start, "the start button lists the ruin: %s" % str(_label_texts(screen)))
	start.pressed.emit()
	assert_true(context.state.data.get("expedition", null) is Dictionary, "the button runs expedition.start")
	assert_true(bool(context.queries.execute(&"expedition.view")["data"].get("active", false)), "the view reports the active expedition")
	_unmount(bundle)


func _log_lines(shell: Control) -> Array:
	var lines: Array = []
	for text in _label_texts(shell._root_box):
		if String(text).begins_with("· "):
			lines.append(String(text))
	return lines


## The single log line containing every `must` and none of `avoid`.
func _log_line_with(lines: Array, must: Array, avoid: Array = []) -> String:
	for line in lines:
		var text := String(line)
		var matches := true
		for needle in must:
			if not text.contains(String(needle)):
				matches = false
		for needle in avoid:
			if text.contains(String(needle)):
				matches = false
		if matches:
			return text
	return ""


func test_notice_log_renders_filled_localized_text() -> void:
	var bundle := _mount(5106)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	context.state.set_money(5000)
	_goto(shell, "shipyard")
	var yard: Dictionary = context.queries.execute(&"shipyard.view")["data"]
	var recipe := {}
	for row in yard["craft"]:
		if row is Dictionary and bool(row.get("money_only", false)) and bool(row.get("can_craft", false)):
			recipe = row
			break
	assert_true(not recipe.is_empty(), "a money-only recipe is available for the order")
	var module_id := String(recipe["module_id"])
	var module_key := String(ShipOps.find_installable(context.registries, module_id).name_key)
	var port_key := String(yard["port_name_key"])
	var cost := int(recipe["craft_cost"])
	assert_true(context.commands.execute(&"ship.craft_module", {"module_id": module_id}).get("ok", false), "the order is placed")
	context.commands.execute(&"port.wait", {"hours": 24})
	# 航线解锁（2026-10-26）：在酒馆买一张海图，让 `ui.notice.chart_purchased` 也进入
	# 航行日志（两个槽位，必须按语言逐字校验，防止 %s/%d 顺序被换）。
	var current_port := context.state.current_port_id()
	var main_contract: Variant = context.state.contracts().get("main", null)
	var main_destination := ""
	if main_contract is Dictionary:
		main_destination = String((main_contract as Dictionary).get("destination", ""))
	# 只保留主线自带的那张海图，保证还有一条未测绘航线可以买。
	var unlocked_keys: Array = WorldOps.unlocked_route_keys(context.state)
	for key in unlocked_keys.duplicate():
		var parts := String(key).split("|", false)
		if parts.size() == 2 and parts[0] != main_destination and parts[1] != main_destination:
			unlocked_keys.erase(key)
	var chart_port := ""
	for port in WorldOps.world_map(context.state).ports:
		if port.id != current_port and port.id != main_destination:
			chart_port = port.id
			break
	assert_false(chart_port.is_empty(), "a locked harbour is available for the chart purchase")
	WorldOps.discover_port_id(context.state, chart_port)
	MapOps.discover(context.state, chart_port)
	_goto(shell, "tavern")
	var buy_chart := _named_button_with_prefix(shell, "BuyChartButton_")
	assert_not_null(buy_chart, "the tavern lists the newly discovered harbour's chart")
	if buy_chart != null:
		buy_chart.emit_signal("pressed")
	var chart_port_key := MapOps.port_display_key(context.state.world(), chart_port)
	var chart_cost := ChartCommands.chart_cost(context.state, context.registries)
	# The shell takes its locale from the player's saved settings, so pin it here:
	# the expected sentences below are per language.
	context.localization.set_locale("zh_CN")
	# The sailing log is part of the 2D overview page, not the bare stage.
	shell._overview_stage_mode = false
	_goto(shell, "overview")
	var log_texts := _log_lines(shell)
	assert_true(log_texts.size() >= 3, "the sailing log lists the session notices: %s" % str(log_texts))
	_assert_notice_log(log_texts, context, port_key, module_key, cost, str(float(recipe["craft_time_hours"])), false, chart_port_key, chart_cost)
	# Same log in English. The expected sentences are spelled out per language
	# below: a template whose slots are swapped still renders, so only a literal
	# expectation catches "the English copy says it the wrong way round".
	context.localization.set_locale("en")
	_goto(shell, "overview")
	_assert_notice_log(_log_lines(shell), context, port_key, module_key, cost, str(float(recipe["craft_time_hours"])), true, chart_port_key, chart_cost)
	context.localization.set_locale("zh_CN")
	_unmount(bundle)


func _assert_notice_log(log_texts: Array, context: AppContext, port_key: String, module_key: String, cost: int, hours_text: String, english: bool, chart_port_key: String = "", chart_cost: int = 60) -> void:
	var port_name := context.translate(port_key, "")
	var module_name := context.translate(module_key, "")
	var expected_order := "· 已在 %s 下单打造 %s · 工时 %s 小时 · 花费 %d 金币。" % [port_name, module_name, hours_text, cost]
	var expected_completed := "· %s 打造完成，已存入 %s 仓库。" % [module_name, port_name]
	var expected_wait := "· 在 %s 等待了 24 小时。" % port_name
	var expected_chart := "· 已购买 %s 海图（%d 金币），航线已测绘。" % [
		context.translate(chart_port_key, ""), chart_cost,
	]
	if english:
		expected_order = "· Ordered at %s: %s · %s hours · %d gold." % [port_name, module_name, hours_text, cost]
		expected_completed = "· %s finished and was stored in the warehouse of %s." % [module_name, port_name]
		expected_wait = "· Waited at %s for 24 hours." % port_name
		expected_chart = "· Bought the %s chart (%d gold) — the route is now charted." % [
			context.translate(chart_port_key, ""), chart_cost,
		]
	for text in log_texts:
		assert_false(text.contains("%s") or text.contains("%d"), "the log line is filled in, not a raw template: %s" % text)
		assert_false(text.contains("ui.notice."), "the log line is translated, not a raw key: %s" % text)
	assert_contains(log_texts, expected_order, "the log orders the port, module, hours and gold (%s)" % ("en" if english else "zh"))
	assert_contains(log_texts, expected_completed, "the log reports the finished module before its port (%s)" % ("en" if english else "zh"))
	assert_contains(log_texts, expected_wait, "the log waits at the port for the hours (%s)" % ("en" if english else "zh"))
	assert_contains(log_texts, expected_chart, "the log reports the chart purchase with harbour and price (%s)" % ("en" if english else "zh"))
	var build_name := context.translate(String(context.registries.get_by_id(ContentTypes.STARTING_SCENARIO, STEADY_BUILD).name_key), "")
	assert_true(_log_line_with(log_texts, [build_name]) != "", "the opening notice names the chosen build: %s" % str(log_texts))


func test_every_pushed_notice_key_is_localized_in_both_languages() -> void:
	var keys := _pushed_notice_keys()
	assert_true(keys.size() >= 7, "the scan found the notice push sites: %s" % str(keys))
	var roots := ["res://framework/localization", "res://dev_mods/core/localization"]
	var locales: Array[Dictionary] = []
	for root in roots:
		var zh := _localization_keys(root.path_join("zh_CN.json"))
		var en := _localization_keys(root.path_join("en.json"))
		assert_eq(zh.size(), en.size(), "%s locales define the same number of keys" % root)
		for key in zh:
			assert_true(en.has(key), "%s: en.json defines %s too" % [root, key])
			if en.has(key):
				assert_eq(
					_slots(String(zh[key])),
					_slots(String(en[key])),
					"%s: %s uses the same slots in the same order in both languages" % [root, key]
				)
		locales.append(zh)
	for key in keys:
		var covering := 0
		for zh in locales:
			if zh.has(key):
				covering += 1
		assert_eq(covering, 1, "%s is defined by exactly one localization set" % key)
		for zh in locales:
			if zh.has(key) and _slots(String(zh[key])).length() > 2:
				assert_true(
					key in LITERAL_EXPECTED_NOTICE_KEYS,
					"%s has several slots, so test_notice_log_renders_filled_localized_text must spell out its sentence per language" % key
				)


## 主界面重构：总览页默认进入 3D 港口舞台，紧凑顶部 chrome 与两侧招牌常驻。
func test_overview_defaults_to_the_3d_port_stage_with_compact_chrome() -> void:
	var bundle := _mount(5205)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	_goto(shell, "overview")
	assert_true(bool(shell._port_stage_available()), "the port stage scene is available in this build")
	assert_true(bool(shell._overview_stage_mode), "the 3D port stage is the default overview")
	var host: SNStageHost = shell._port_stage_host
	assert_not_null(host, "the shell mounts a stage host")
	if host == null:
		_unmount(bundle)
		return
	assert_true(host.is_stage_visible() and host.visible, "the 3D stage host is visible")
	var stage := host.current_stage()
	assert_true(stage is PortStage, "the mounted stage is a PortStage")
	if not (stage is PortStage):
		_unmount(bundle)
		return
	var port_stage := stage as PortStage
	var facilities: Array = shell._last_port_view.get("current_port", {}).get("facilities", [])
	assert_eq(int(port_stage.facility_count()), facilities.size(), "every present facility is assembled in the stage")
	assert_true(bool(shell._port_stage_active()), "the shell reports the stage as active on the overview")

	# Compact chrome: one panel, every datum and button from the old three bars.
	var chrome: PanelContainer = shell._top_chrome
	assert_not_null(chrome, "the compact top chrome is mounted")
	if chrome == null:
		_unmount(bundle)
		return
	var chrome_height := chrome.get_combined_minimum_size().y
	assert_true(
		chrome_height <= 130.0,
		"the compact chrome stays under 130 px (measured %.1f)" % chrome_height
	)
	var chrome_texts := _label_texts(chrome)
	var view: Dictionary = context.queries.execute(&"port.view")["data"]
	var port_name := context.translate(String(view["current_port"]["name_key"]), "")
	var ship: Dictionary = view["ship"]
	assert_contains(chrome_texts, port_name, "the chrome names the current port")
	assert_contains(chrome_texts, str(int(view["money"])), "the chrome keeps the money chip")
	assert_contains(chrome_texts, str(int(view["reputation"])), "the chrome keeps the reputation chip")
	assert_contains(chrome_texts, "%.1f / %.1f" % [float(ship["free_weight"]), float(ship["max_weight"])], "the chrome keeps the remaining weight chip")
	assert_contains(chrome_texts, "%.1f / %.1f" % [float(ship["free_cargo_capacity"]), float(ship["cargo_capacity"])], "the chrome keeps the remaining cargo chip")
	# 2026-10-28 图标轮：chip 不再画 9 px 文字标签，字段名收敛到 chip 的 tooltip。
	for label_key in [
		"ui.label.time", "ui.label.money", "ui.label.reputation",
		"ui.label.free_weight", "ui.label.free_capacity",
		"ui.label.coal", "ui.label.water", "ui.label.durability",
	]:
		assert_false(_nodes_with_tooltip(chrome, context.translate(label_key, "")).is_empty(),
			"the chrome keeps the %s field name as a chip tooltip" % label_key)
	# 导航：图标 + 本地化页名按钮，入口身份仍走 `nav_screen` meta（未发布系统不出现）。
	for screen in ["overview", "market", "contracts", "shipyard", "tavern"]:
		var nav_entry := _nav_button(chrome, screen)
		assert_not_null(nav_entry, "the compact chrome keeps the %s navigation button" % screen)
		if nav_entry != null:
			assert_eq(String(nav_entry.text), shell._tr("ui.nav.%s" % screen, screen),
				"the %s navigation entry keeps its label" % screen)
			assert_not_null(nav_entry.icon, "the %s navigation entry keeps its icon" % screen)
	for screen in ["base", "trade", "ruins"]:
		assert_true(_nav_button(chrome, screen) == null,
			"the compact chrome hides the unpublished %s navigation entry" % screen)
	assert_true(_nav_button(chrome, "voyage") == null,
		"4.3/U7: the voyage page is gone from the navigation")
	assert_not_null(_nav_button(chrome, "sea_chart"),
		"the chart toggle stays in the navigation")
	assert_not_null(_button_by_text(chrome, shell._tr("ui.button.log", "")), "the compact chrome keeps the diagnostics button")
	assert_not_null(_button_by_text(chrome, shell._tr("ui.button.refresh", "")), "the compact chrome keeps the refresh button")

	# HUD icons come from the skin table only in the 2026-10-28 icon round (the
	# early content `icon.coal|money|water` assets were retired): every chip paints
	# a loaded skin texture and the logical-key table stays complete.
	var skin_icons: Dictionary = shell.get_script().get_script_constant_map().get("HUD_SKIN_ICONS", {})
	for logical_key in skin_icons:
		assert_not_null(SNSkin.icon(String(skin_icons[logical_key])),
			"%s maps to a real skin icon" % logical_key)
	var hud_icons := _texture_rects(chrome)
	assert_true(hud_icons.size() >= 8, "the chrome paints the HUD icons (%d texture nodes)" % hud_icons.size())
	for icon_node in hud_icons:
		assert_not_null((icon_node as TextureRect).texture, "every HUD icon node has a loaded texture")

	# Window scaling: `canvas_items + expand` maps a 960x540 window to a scaled
	# 1600x900 logical canvas, so the full-density HUD (including the capacity
	# chips asserted above) is kept instead of dropping to a compact branch. The
	# 960x540 acceptance screenshot is the evidence for that layout.

	# Edge signboards: fixed left/right columns, one per present facility plus
	# the permanent chart sign (4.3/U7: replaces the old voyage sign). Positions come from the camera projection, but
	# the controls themselves are pinned to the screen edges and drawn as themed
	# wood/iron plates (the Button component keeps text/accessibility semantics).
	host.stage_viewport().size = Vector2i(1440, 900)
	shell._layout_port_hotspots()
	var layer_width: float = shell._port_hotspot_layer.size.x
	if layer_width <= 0.0:
		layer_width = shell.get_viewport_rect().size.x
	var signs := 0
	for child in shell._port_hotspot_layer.get_children():
		if child is Button:
			signs += 1
	var expected_signs := facilities.size() + 1
	if facilities.has("supply"):
		# 4.5.3: the supply facility moved into the market page, so it gets no sign.
		expected_signs -= 1
	assert_eq(signs, expected_signs, "one edge sign per standalone facility plus the chart sign")
	for facility in ["exchange", "contracts", "tavern", "shipyard"]:
		var sign: Variant = shell._port_hotspot_layer.get_node_or_null("Hotspot_%s" % facility)
		if facilities.has(facility):
			assert_not_null(sign, "the present %s facility gets an edge sign" % facility)
			if sign is Button:
				var normalized: Vector2 = port_stage.facility_screen_anchor(String(facility))
				var button := sign as Button
				assert_true(button.has_method("configure"), "the %s sign uses the themed harbour-sign component" % facility)
				assert_eq(button.custom_minimum_size, Vector2(172.0, 42.0), "the %s sign keeps the 172x42 plate" % facility)
				if button.has_method("configure"):
					assert_eq(int(button.get("arrow_direction")), -1 if normalized.x < 0.5 else 1, "the %s sign arrow points into the scene" % facility)
				if normalized.x < 0.5:
					assert_true(button.position.x < layer_width * 0.5, "%s sign sits in the left column" % facility)
					assert_true(String(button.text).ends_with(" ▶"), "the left column points into the scene: %s" % String(button.text))
				else:
					assert_true(button.position.x > layer_width * 0.5, "%s sign sits in the right column" % facility)
					assert_true(String(button.text).begins_with("◀ "), "the right column points into the scene: %s" % String(button.text))
		else:
			assert_true(sign == null, "an absent %s facility gets no edge sign" % facility)
	var chart_sign: Variant = shell._port_hotspot_layer.get_node_or_null("Hotspot_sea_chart")
	assert_not_null(chart_sign, "the chart sign is always present at the bottom of the right column")
	if chart_sign is Button:
		assert_true(String((chart_sign as Button).text).contains(shell._tr("ui.nav.sea_chart", "")),
			"the permanent sign opens the chart, not a voyage page")
	# A resize re-lays the sign columns without losing or duplicating signs.
	host.stage_viewport().size = Vector2i(1280, 720)
	shell._on_viewport_size_changed()
	shell._layout_port_hotspots()
	var resized_signs := 0
	for child in shell._port_hotspot_layer.get_children():
		if child is Button:
			resized_signs += 1
	assert_eq(resized_signs, expected_signs, "resizing the window re-lays the edge signs")
	var exchange_sign: Variant = shell._port_hotspot_layer.get_node_or_null("Hotspot_exchange")
	if exchange_sign is Button:
		(exchange_sign as Button).emit_signal("pressed")
		assert_eq(String(shell._active_screen), "market", "clicking the exchange sign opens the market page")
	# The navigation refresh runs behind the fade tween; headless tests never
	# advance frames, so settle the transition synchronously before continuing.
	shell._transitioning = false
	shell._pending_transition = false
	shell._fade_layer.visible = false

	# Adjacent-station pages: overview / market share the same mounted district.
	# Switching pages pans the camera and sails the hull, so the stage stays
	# visible, the page becomes a dock panel and nothing is rebuilt.
	var stage_instance := host.current_stage()
	_goto(shell, "market")
	assert_eq(_nodes_with_script(shell._root_box, MARKET_SCREEN_SCRIPT).size(), 1, "the market page is mounted")
	assert_true(bool(host.visible), "the market page keeps the shared 3D district visible")
	assert_eq(host.current_stage(), stage_instance, "the market page reuses the mounted stage instance")
	assert_eq(String(shell._stage_station), "market", "the shell points the stage at the market station")
	assert_eq(String(shell._stage_framing), "panel", "the market page uses the dock-panel framing")
	assert_eq(String(port_stage.current_station()), "market", "the PortStage focuses the market station")
	var dock_row: Variant = shell._root_box.get_node_or_null("DockPanelRow")
	assert_not_null(dock_row, "the market page is laid out as a dock panel beside the stage window")
	if dock_row is HBoxContainer:
		var dock_panel := (dock_row as HBoxContainer).get_node_or_null("DockPanel") as PanelContainer
		assert_not_null(dock_panel, "the dock panel is pinned to the right of the stage window")
		if dock_panel != null:
			assert_true(
				dock_panel.custom_minimum_size.x >= 620.0,
				"the dock panel keeps the narrow content column (%.0f px)" % dock_panel.custom_minimum_size.x
			)
	assert_true(shell.find_child("PortStatusBar", true, false) == null,
		"the removed bottom status strip never mounts on any page")
	assert_true(shell._top_chrome != null and shell._top_chrome.get_combined_minimum_size().y <= 130.0, "the compact chrome is shared by every page")
	assert_not_null(_nav_button(shell._top_chrome, "market"), "the shared chrome keeps navigation on other pages")

	# Headless tests never advance frames, so step the stage clock directly: the
	# camera really pans to the market shot and the hull really sails to the berth.
	# The landmark facade (grand harbour terminal) keeps the player ship mounted —
	# it is the stage's primary subject (player feedback #5) — so the berth
	# assertion is unconditional; facade mode additionally scales the hull down
	# beside the 0.42-scaled terminal.
	var market_shot: Vector3 = port_stage.station_camera_pose("market", "panel")["position"]
	port_stage.advance_station(2.0)
	assert_almost_eq(
		port_stage.camera_position().distance_to(market_shot),
		0.0,
		0.05,
		"the camera pans to the market station of the shared district"
	)
	port_stage.advance_station(8.0)
	assert_false(port_stage.is_station_transitioning(), "the market station transition settles")
	var current_port: Dictionary = shell._last_port_view.get("current_port", {})
	assert_true(port_stage.has_ship(), "the market station keeps the player ship mounted")
	var market_berth := port_stage.station_ship_position("market").x
	assert_almost_eq(port_stage.ship_x(), market_berth, 0.3, "the hull moors at the market berth")
	var market_ship: Node3D = port_stage.get_node_or_null("Content/PlayerShip") as Node3D
	assert_not_null(market_ship, "the market station shows a Content/PlayerShip root")
	if market_ship != null:
		assert_almost_eq(
			market_ship.position.x, market_berth, 0.3, "the mounted hull sits at the market berth"
		)
		if not String(current_port.get("landmark_path", "")).is_empty():
			assert_almost_eq(
				market_ship.scale.x,
				PortStage.MINIMAL_SHIP_SCALE,
				0.001,
				"the landmark facade shows a scaled player ship"
			)

	# 4.5.3: supply lives inside the market page, not as an adjacent station page;
	# navigating to the old `supply` id is redirected to the market.
	_goto(shell, "supply")
	assert_eq(String(shell._active_screen), "market", "the legacy supply id redirects to the market")
	assert_eq(_nodes_with_script(shell._root_box, MARKET_SCREEN_SCRIPT).size(), 1, "the market page is mounted")
	assert_eq(String(shell._stage_station), "market", "the supply redirect keeps the market station")
	assert_eq(String(port_stage.current_station()), "market", "the PortStage stays on the market station")
	assert_almost_eq(port_stage.ship_x(), market_berth, 0.3, "the supply redirect keeps the hull at the market berth")

	# Pages that are not stage-backed still hide the district and show the fade.
	_goto(shell, "contracts")
	assert_false(bool(host.visible), "leaving the station pages hides the 3D stage")
	_goto(shell, "overview")
	assert_true(bool(host.visible), "returning to the overview shows the district again")
	assert_eq(String(port_stage.current_station()), "harbor", "the overview returns to the harbour station")

	# The 2D overview stays reachable as the fallback / accessibility toggle.
	_goto(shell, "overview")
	var toggle := _button_by_text(shell._top_chrome, shell._tr("ui.button.overview_2d", ""))
	assert_not_null(toggle, "the chrome offers the 2D overview toggle")
	if toggle != null:
		toggle.emit_signal("pressed")
	assert_false(bool(shell._overview_stage_mode), "the 2D overview can be selected")
	assert_false(bool(host.visible), "the 2D overview hides the stage host")
	assert_true(_named_node(shell._root_box, "MapCanvas") == null,
		"4.3/U6: the 2D overview no longer renders the old line-art chart")
	var stage_button := _button_by_text(shell._root_box, shell._tr("ui.button.port_stage", ""))
	assert_not_null(stage_button, "the 2D page offers the way back to the 3D stage")
	if stage_button != null:
		stage_button.emit_signal("pressed")
	assert_true(bool(shell._overview_stage_mode), "the 3D stage can be restored")
	_unmount(bundle)


## 用户反馈：基地 / 贸易 / 遗迹三个未开发系统不要出现在屏幕上。
## 顶部导航不生成这三个入口；遗迹属于航行探索玩法，不作为港口页入口。页面路由、
## 场景与 `ui.nav.*` 中英文案保留（`tools/ui_snapshot.gd` 仍直接路由这些页面做视觉
## 验收，未来重新发布时只从 `HIDDEN_NAV_SCREENS` 移除即可）。
func test_unpublished_systems_have_no_player_navigation_entry() -> void:
	var bundle := _mount(5309)
	var shell: Control = bundle["shell"]
	_goto(shell, "overview")
	var hidden: Array = Array(shell.get_script().get_script_constant_map().get("HIDDEN_NAV_SCREENS", []))
	assert_eq(hidden, ["base", "trade", "ruins"], "the unpublished systems live in one navigation constant")
	var screens: Array = Array(shell.get_script().get_script_constant_map().get("SCREENS", []))
	for screen in hidden:
		assert_true(screens.has(screen),
			"%s keeps its route, so the internal page stays directly routable" % screen)
	var zh: Dictionary = _localization_keys("res://framework/localization/zh_CN.json")
	var en: Dictionary = _localization_keys("res://framework/localization/en.json")
	var chrome: PanelContainer = shell._top_chrome
	assert_not_null(chrome, "the compact chrome is mounted on the overview")
	if chrome == null:
		_unmount(bundle)
		return
	var nav := _named_node(chrome, "Nav")
	assert_not_null(nav, "the chrome builds one navigation container")
	if nav == null:
		_unmount(bundle)
		return
	var nav_screens: Array[String] = []
	var nav_tooltips: Array[String] = []
	for child in nav.get_children():
		if child is Button:
			nav_screens.append(String((child as Button).get_meta("nav_screen", "")))
			nav_tooltips.append(String((child as Button).tooltip_text))
	for screen in hidden:
		var key := "ui.nav.%s" % screen
		var zh_text := String(zh.get(key, ""))
		var en_text := String(en.get(key, ""))
		assert_false(zh_text.is_empty(), "%s keeps its zh_CN label for the internal page" % key)
		assert_false(en_text.is_empty(), "%s keeps its en label for the internal page" % key)
		assert_true(zh_text != en_text, "%s is really translated in both languages" % key)
		# 2026-10-28 图标轮：导航是纯图标按钮，入口身份走 meta（不再是 text）。
		assert_false(nav_screens.has(screen), "the nav has no %s entry" % screen)
		assert_false(nav_tooltips.has(zh_text), "the nav has no %s tooltip entry in zh_CN" % screen)
		assert_false(nav_tooltips.has(en_text), "the nav has no %s tooltip entry in en either" % screen)
		# 剧情引导解析同一个导航表：隐藏入口不能被 focus 高亮成假入口。
		assert_true(shell._story_nav_button(screen) == null,
			"story focus cannot resolve the hidden %s navigation entry" % screen)
	# 舞台设施招牌是另一个玩家入口表：只允许打开已发布页面。
	var facility_screens: Dictionary = shell.get_script().get_script_constant_map().get("PORT_STAGE_FACILITY_SCREENS", {})
	for screen in hidden:
		assert_false(Array(facility_screens.values()).has(screen),
			"no port-stage facility sign opens the unpublished %s page" % screen)
	# 已发布页面照常保留图标入口（身份走 `nav_screen` meta）。
	for screen in ["overview", "market", "contracts", "shipyard", "tavern"]:
		assert_true(nav_screens.has(screen),
			"the published %s entry keeps its button" % screen)
	_unmount(bundle)


## 舞台不可用 / 加载失败时仍自动回退 2D 总览并提示，不出现空画面。
func test_overview_stage_falls_back_to_the_usable_2d_overview() -> void:
	var bundle := _mount(5208)
	var shell: Control = bundle["shell"]
	_goto(shell, "overview")
	assert_true(bool(shell._overview_stage_mode), "the fixture starts on the 3D stage")
	shell._on_port_stage_fallback("fixture")
	shell._refresh()
	assert_true(bool(shell._port_stage_load_failed), "a failed stage load is remembered for the session")
	assert_false(bool(shell._overview_stage_mode), "the fallback switches to the 2D overview")
	assert_false(bool(shell._port_stage_available()), "a failed stage is not retried")
	if shell._port_stage_host != null:
		assert_false(bool(shell._port_stage_host.visible), "the failed stage host is hidden")
	assert_true(_named_node(shell._root_box, "MapCanvas") == null,
		"4.3/U6: the fallback 2D overview has no old chart panel either")
	assert_contains(_label_texts(shell._root_box), shell._tr("ui.error.port_stage_unavailable", ""), "the fallback explains what happened")
	assert_not_null(_nav_button(shell._root_box, "market"), "navigation keeps working after the fallback")
	_unmount(bundle)


## 2026-10-28 反馈：底部状态条与顶部 chrome 完全重复，整条移除；等待 / 航行记录 /
## 详细总览仍在 2D 总览页，海图入口在顶部导航（`nav_screen = sea_chart`）。
func test_overview_has_no_duplicate_status_strip_and_2d_page_keeps_actions() -> void:
	var bundle := _mount(5206)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	_goto(shell, "overview")
	assert_true(shell.find_child("PortStatusBar", true, false) == null,
		"the duplicate bottom status strip is gone")
	# 2D 总览页（顶部「2D 总览」开关）：详细面板 / 等待 / 航行记录都在这里。
	shell._overview_stage_mode = false
	shell._refresh()
	assert_false(bool(shell._overview_stage_mode), "the 2D overview page opens")
	assert_true(_named_node(shell._root_box, "MapCanvas") == null,
		"4.3/U6: the 2D overview page no longer shows the old chart")
	var texts := _label_texts(shell._root_box)
	assert_contains(texts, context.translate("ui.victory.plan_title", ""), "the 2D page keeps the victory plan")
	assert_contains(texts, "航行记录", "the 2D page keeps the notices log")
	var time_before := context.state.now()
	var wait_button := _button_by_text(shell._root_box, "12 h")
	assert_not_null(wait_button, "the 2D quick actions keep the 12-hour wait")
	if wait_button != null:
		wait_button.emit_signal("pressed")
	assert_almost_eq(context.state.now(), time_before + 12.0, 0.001, "the 2D wait button advances game time by 12 hours")
	var chart_button := _nav_button(shell, "sea_chart") as Button
	assert_not_null(chart_button, "the chart entry lives in the top navigation now")
	if chart_button != null:
		chart_button.emit_signal("pressed")
	assert_eq(String(shell._active_screen), "sea_chart", "the nav chart button opens the chart")
	_unmount(bundle)


## Sea chart entry integration (4.3.4 / U7): `run.start` stores a coordinate-space
## twin world keyed by the played map's port ids, so the full chart page binds the
## real run. The chrome toggle and M key flip the active screen; the panel's
## departure button opens the shared confirmation dialog (boiler strategy +
## estimate + blockers), and only its confirm button fires `voyage.start`.
##
## Animated nav refreshes rebuild the page a few frames later, so content
## assertions run right after `_goto`/`_refresh()` (synchronous), and the
## button/M-key checks only assert the synchronously flipped `_active_screen`.
func test_sea_chart_entry_integration() -> void:
	var bundle := _mount(20260401)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]

	# The real run feeds the chart: the twin world generated at run.start binds
	# live data instead of the no-data hint.
	_goto(shell, "sea_chart")
	assert_false(_label_texts(shell).has(shell._tr("ui.sea_chart.no_data", "")),
		"a real run has chart data, so the no-data hint stays hidden")
	var screens := _nodes_with_script(shell._root_box, SEA_CHART_SCREEN_SCRIPT)
	assert_eq(screens.size(), 1, "the chart page mounts exactly one screen")
	var chart_screen: Control = screens[0]
	assert_true((chart_screen._view_model.get("ports", []) as Array).size() >= 1,
		"the chart screen binds the query view model with the discovered ports")

	# Discover a neighbour so the chart shows the route and the panel's depart
	# button: departure is confirmed in the chart now, not on a voyage page.
	var current_port_id := String(context.state.current_port_id())
	var port_id := String(MapOps.neighbors(context.state.world(), current_port_id)[0])
	var discovered: Array = context.state.campaign_world().get("discovered_port_ids", [])
	if not discovered.has(port_id):
		discovered.append(port_id)
	# 海图解锁是独立门禁：本用例验证「海图 → 确认弹窗 → voyage.start」的接线，
	# 先把这条航线标记为已测绘（解锁机制本身由 test_route_unlock 覆盖）。
	WorldOps.unlock_route(context.state, current_port_id, port_id)
	_goto(shell, "sea_chart")
	screens = _nodes_with_script(shell._root_box, SEA_CHART_SCREEN_SCRIPT)
	chart_screen = screens[0]
	chart_screen._on_port_clicked(port_id)
	var depart_button := _named_node(chart_screen, "DepartButton") as Button
	assert_not_null(depart_button, "the selected harbour exposes the chart depart button")
	if depart_button != null:
		depart_button.emit_signal("pressed")
	assert_true(not shell._chart_departure.is_empty(), "depart opens the confirmation dialog")
	screens = _nodes_with_script(shell._root_box, SEA_CHART_SCREEN_SCRIPT)
	assert_eq(screens.size(), 1, "the chart page is rebuilt with the dialog")
	chart_screen = screens[0]
	var confirm: Control = _named_node(chart_screen, "VoyageConfirm")
	assert_not_null(confirm, "the chart renders the shared departure confirmation")
	assert_true(chart_screen.is_departure_open(), "the screen reports the pending departure")
	var strategy_picker := _named_node(chart_screen, "StrategyPicker") as OptionButton
	assert_not_null(strategy_picker, "the dialog offers the boiler strategy switch")
	if strategy_picker != null:
		assert_eq(strategy_picker.item_count, (context.queries.execute(&"port.view")["data"].get("strategies", []) as Array).size(),
			"the strategy picker lists every content strategy")
		# Strategy changes reopen the dialog with new estimates and are remembered.
		var second_strategy := String(strategy_picker.get_item_metadata(0))
		strategy_picker.item_selected.emit(0)
		assert_eq(String(shell._selected_strategy), second_strategy,
			"switching the strategy is remembered by the shell")
		screens = _nodes_with_script(shell._root_box, SEA_CHART_SCREEN_SCRIPT)
		chart_screen = screens[0]
		assert_true(not shell._chart_departure.is_empty(), "the dialog stays open after a strategy change")
	# Cancel closes the dialog without starting a voyage.
	var cancel_button := _named_node(chart_screen, "CancelButton") as Button
	assert_not_null(cancel_button, "the dialog offers cancel")
	if cancel_button != null:
		cancel_button.emit_signal("pressed")
	assert_true(shell._chart_departure.is_empty(), "cancel closes the dialog")
	assert_true(shell._presentation == null, "cancel does not start a voyage")

	# Reopen and confirm: the shell fires the real `voyage.start`, which hands
	# over to the voyage presentation.
	screens = _nodes_with_script(shell._root_box, SEA_CHART_SCREEN_SCRIPT)
	chart_screen = screens[0]
	chart_screen._on_port_clicked(port_id)
	depart_button = _named_node(chart_screen, "DepartButton") as Button
	if depart_button != null:
		depart_button.emit_signal("pressed")
	screens = _nodes_with_script(shell._root_box, SEA_CHART_SCREEN_SCRIPT)
	chart_screen = screens[0]
	var confirm_button := _named_node(chart_screen, "ConfirmButton") as Button
	assert_not_null(confirm_button, "the dialog offers the confirm button")
	if confirm_button != null:
		confirm_button.emit_signal("pressed")
	assert_true(shell._chart_departure.is_empty(), "confirm closes the dialog")
	assert_true(shell._presentation != null, "confirm starts the voyage presentation")

	# M closes the running chart back to the opening page (the voyage itself is
	# now command-driven and unaffected by navigation).
	shell._presentation = null
	shell._reset_voyage_presentation()
	_goto(shell, "sea_chart")
	var press_m := InputEventKey.new()
	press_m.keycode = KEY_M
	press_m.pressed = true
	shell._unhandled_input(press_m)
	assert_eq(String(shell._active_screen), "overview", "M closes the chart back to the opening page")
	shell._unhandled_input(press_m)
	assert_eq(String(shell._active_screen), "sea_chart", "M opens the chart again")
	_unmount(bundle)


## 探索系统 4.1 · 购买线索入口：海图面板在 `can_buy_clue.available` 时显示购买按钮，
## 点击后由 Shell 执行真实的 `clue.buy`，成功后海图刷新出新线索（active 列表 +1）。
func test_sea_chart_buys_an_intel_clue_from_the_panel() -> void:
	var bundle := _mount(20260402)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	context.state.set_money(5000)
	# 买线索需要情报站：把当前港设到地图上任意一个有 intel 设施的港口（真实对局里
	# 玩家就是先把船开到这里再进海图页买）。
	var intel_port := ""
	for port in MapOps.ports(context.state.world()).values():
		if port is Dictionary and MapOps.has_tavern(port as Dictionary):
			intel_port = String((port as Dictionary).get("id", ""))
			break
	assert_true(not intel_port.is_empty(), "the fixture map has a harbour with a tavern")
	if intel_port.is_empty():
		_unmount(bundle)
		return
	# `GameState.current_port_id()` 读玩法世界字典的 current_port_id；`WorldOps` 的
	# data 路径是给旧代码 / 演出用的镜像，两处都写才能让查询与面板看到新港口。
	context.state.world()["current_port_id"] = intel_port
	WorldOps.set_current_port(context.state, intel_port)
	_goto(shell, "sea_chart")
	var screens := _nodes_with_script(shell._root_box, SEA_CHART_SCREEN_SCRIPT)
	assert_eq(screens.size(), 1, "the chart page mounts")
	if screens.is_empty():
		_unmount(bundle)
		return
	var chart_screen: Control = screens[0]
	var view_model: Dictionary = chart_screen._view_model
	assert_true(bool((view_model.get("can_buy_clue", {}) as Dictionary).get("available", false)),
		"the chart offers the buy entry at a harbour with a tavern: %s" % str(view_model.get("can_buy_clue", {})))
	var purchase := _named_node(chart_screen, "PurchaseClueButton") as Button
	assert_not_null(purchase, "the panel renders the purchase entry")
	if purchase == null:
		_unmount(bundle)
		return
	var clues_before: int = ClueService.active(context.state).size()
	purchase.emit_signal("pressed")
	assert_eq(ClueService.active(context.state).size(), clues_before + 1,
		"pressing the buy entry runs the real clue.buy command")
	var expected_notice: String = context.translate("ui.notice.clue_acquired") \
		% context.translate("ui.clue.source.intel")
	assert_true(String(shell._status_message).contains(expected_notice),
		"the status bar reports the acquired clue, got: %s" % shell._status_message)
	assert_true(context.state.money() < 5000, "the clue costs gold")
	# `_run_command` rebuilds the chart page, so the new clue is in the fresh view model.
	screens = _nodes_with_script(shell._root_box, SEA_CHART_SCREEN_SCRIPT)
	assert_eq(screens.size(), 1, "the chart page is rebuilt after the purchase")
	if not screens.is_empty():
		var rebuilt: Control = screens[0]
		assert_eq((rebuilt._view_model.get("clues", []) as Array).size(), clues_before + 1,
			"the refreshed chart view model carries the new clue")
	_unmount(bundle)


## 市场页重构（图标直接交易）：三栏布局、图标格子、船舱 / 仓库落点、待交易数量。
func test_market_page_three_column_icon_trading() -> void:
	var bundle := _mount(5301)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	context.state.set_money(5000)
	var market_query := context.queries.execute(&"market.view")
	var rows: Array = []
	if bool(market_query.get("ok", false)):
		rows = Array((market_query["data"] as Dictionary).get("market", []))
	else:
		rows = Array(context.queries.execute(&"port.view")["data"].get("market", []))
	var trade_row := {}
	for row in rows:
		if row is Dictionary and bool(row.get("buyable", true)) and int(row.get("stock", 0)) >= 2:
			trade_row = row
			break
	assert_true(not trade_row.is_empty(), "the fixture market has a buyable good")
	if trade_row.is_empty():
		_unmount(bundle)
		return
	var bought := context.commands.execute(&"trade.buy", {
		"item_id": String(trade_row.get("item_id", "")),
		"amount": 2,
	})
	assert_true(bool(bought.get("ok", false)), "loading the hold succeeds: %s" % str(bought))
	ShipOps.add_cargo(context.state.ship(), "core:item/contract_freight", 1, "fixture_contract")
	WarehouseOps.add_material(context.state, context.state.current_port_id(), "core:item/timber", 3)
	_goto(shell, "market")

	assert_eq(_nodes_with_script(shell._root_box, MARKET_SCREEN_SCRIPT).size(), 1, "the market page mounts exactly one MarketScreen")
	var dock_row := _named_node(shell._root_box, "DockPanelRow") as HBoxContainer
	assert_not_null(dock_row, "the market page keeps the three-column dock row")
	var stage_window := _named_node(shell._root_box, "StageWindow") as Control
	assert_not_null(stage_window, "the middle stage window stays in the row")
	if stage_window != null:
		assert_eq(stage_window.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the stage window never eats mouse input")
	var dock_panel := _named_node(shell._root_box, "DockPanel") as PanelContainer
	assert_not_null(dock_panel, "the market dock panel is pinned to the right")
	if dock_panel != null:
		assert_true(dock_panel.custom_minimum_size.x >= 620.0, "the dock panel keeps the narrow content column")
	var cargo_panel := _named_node(shell._root_box, "CargoHoldPanel") as Control
	assert_not_null(cargo_panel, "the page adds the left ship-hold backpack")
	if cargo_panel != null:
		assert_true(cargo_panel.custom_minimum_size.x >= 360.0, "the backpack column keeps its 360 px minimum")
	var cargo_zone := _named_node(shell._root_box, "CargoDropZone")
	var warehouse_zone := _named_node(shell._root_box, "WarehouseDropZone")
	var sell_zone := _named_node(shell._root_box, "MarketDropZone")
	assert_not_null(cargo_zone, "the backpack exposes the 船舱货物 drop zone")
	assert_not_null(warehouse_zone, "the backpack exposes the 港口仓库 drop zone")
	assert_not_null(sell_zone, "the whole market panel is the sell drop zone")
	if cargo_zone == null or warehouse_zone == null or sell_zone == null:
		_unmount(bundle)
		return
	assert_contains(Array(cargo_zone.get("accept_kinds")), "market_item", "buying into cargo accepts market icons")
	assert_contains(Array(cargo_zone.get("accept_kinds")), "warehouse_item", "taking from the warehouse accepts warehouse icons")
	assert_contains(Array(warehouse_zone.get("accept_kinds")), "cargo_item", "storing accepts hold icons")
	assert_contains(Array(warehouse_zone.get("accept_kinds")), "market_item", "buying into the warehouse accepts market icons")
	assert_contains(Array(sell_zone.get("accept_kinds")), "cargo_item", "the market sells hold icons")
	assert_contains(Array(sell_zone.get("accept_kinds")), "warehouse_item", "the market sells warehouse icons")

	var market_tiles: Array = []
	for node in _nodes_with_script(shell._root_box, ITEM_TILE_SCRIPT):
		var tile_item: Dictionary = node.get("item")
		if String(tile_item.get("kind", "")) == "market_item":
			market_tiles.append(node)

	# Icon grid: every buyable market row renders one tile; sell-only rows are hidden
	# (2026-10-28 feedback) but stay sellable through the panel drop zone.
	var buyable_rows := 0
	for row in rows:
		if bool((row as Dictionary).get("buyable", true)):
			buyable_rows += 1
	assert_eq(market_tiles.size(), buyable_rows, "every buyable market row gets exactly one icon tile")
	for node in market_tiles:
		assert_not_null(node.call("icon_texture"), "market tiles paint a resolved icon texture (content icon or fallback)")

	# Left click +1 (capped), right click clears.
	var trade_tile: Variant = null
	for node in market_tiles:
		if bool(node.get("draggable")) and int(node.get("max_pending")) >= 3:
			trade_tile = node
			break
	assert_not_null(trade_tile, "at least one market tile is draggable with stock available")
	if trade_tile == null:
		_unmount(bundle)
		return
	var tile: Control = trade_tile
	tile.call("increment_pending")
	assert_eq(int(tile.get("pending")), 1, "increment_pending bumps the pending amount by one")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	tile.call("_on_gui_input", press)
	assert_eq(int(tile.get("pending")), 1, "the press that starts a drag does not add a unit")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	tile.call("_on_gui_input", release)
	assert_eq(int(tile.get("pending")), 2, "a plain left click adds one unit on release")
	for index in range(12):
		tile.call("increment_pending")
	assert_eq(int(tile.get("pending")), mini(14, int(tile.get("max_pending"))),
		"the pending amount never exceeds the available stock")
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	tile.call("_on_gui_input", right_click)
	assert_eq(int(tile.get("pending")), 0, "right click clears the pending amount")
	var zero_payload: Dictionary = tile.call("drag_payload")
	assert_eq(int(zero_payload.get("amount", 0)), 1, "a pure drag (pending 0) carries exactly one unit")
	for index in range(3):
		tile.call("increment_pending")
	var drag_payload: Dictionary = tile.call("drag_payload")
	assert_eq(String(drag_payload.get("kind", "")), "market_item", "market tiles carry the market_item drag kind")
	assert_eq(int(drag_payload.get("amount", 0)), 3, "clicking three times then dragging carries exactly three units")
	# A drag ends with a release: that release must not add a fourth unit.
	tile.set("_dragging", true)
	var drag_release := InputEventMouseButton.new()
	drag_release.button_index = MOUSE_BUTTON_LEFT
	drag_release.pressed = false
	tile.call("_on_gui_input", drag_release)
	assert_eq(int(tile.get("pending")), 3, "the release that ends a drag adds no extra unit")
	assert_false(bool(tile.get("_dragging")), "the drag flag resets after the release")

	# Contract cargo stays locked: no drag, explicit lock marker / label.
	var contract_tiles: Array = []
	var hold_tiles: Array = []
	for node in _nodes_with_script(shell._root_box, ITEM_TILE_SCRIPT):
		var tile_item: Dictionary = node.get("item")
		if String(tile_item.get("kind", "")) != "cargo_item":
			continue
		hold_tiles.append(node)
		if bool(node.get("locked")):
			contract_tiles.append(node)
	assert_true(hold_tiles.size() >= 2, "the hold renders the bought cargo and the contract cargo")
	assert_eq(contract_tiles.size(), 1, "the contract cargo stack gets its own locked tile")
	if contract_tiles.size() == 1:
		var contract_tile: Control = contract_tiles[0]
		assert_false(bool(contract_tile.get("draggable")), "contract cargo cannot be dragged")
		assert_true(contract_tile.call("_get_drag_data", Vector2.ZERO) == null, "contract cargo returns no drag payload")
		var contract_lock: String = shell._tr("ui.market.contract_locked", "")
		var explained := false
		for text in _label_texts(contract_tile):
			if not contract_lock.is_empty() and String(text).contains(contract_lock):
				explained = true
		assert_true(explained, "the contract tile explains why it cannot be traded: %s" % str(_label_texts(contract_tile)))
	var warehouse_tiles: Array = []
	for node in _nodes_with_script(shell._root_box, ITEM_TILE_SCRIPT):
		var tile_item: Dictionary = node.get("item")
		if String(tile_item.get("kind", "")) == "warehouse_item":
			warehouse_tiles.append(node)
	if bool(market_query.get("ok", false)):
		assert_eq(warehouse_tiles.size(), 1, "the port warehouse material renders one tile")
	else:
		assert_eq(warehouse_tiles.size(), 0, "without market.view the port.view fallback has no warehouse rows")
	# Missing content icons must degrade to the framework item fallback, not crash.
	assert_true(ResourceLoader.exists("res://assets/ui/icons/item_fallback.svg")
			or FileAccess.file_exists("res://assets/ui/icons/item_fallback.svg"),
		"the framework item fallback icon ships with the UI")
	var fallback_texture: Texture2D = shell._fallback_item_icon()
	assert_not_null(fallback_texture, "the framework item fallback icon loads")
	var unknown_texture: Texture2D = shell._resolve_item_icon("icon.item.no_such_item", fallback_texture)
	assert_eq(unknown_texture, fallback_texture, "unknown content icon keys fall back to the item placeholder")
	_unmount(bundle)


## 拖拽载荷 → 固定命令契约：船舱 / 仓库落点与整块市场面板的 fallback 行为。
func test_market_drag_drops_emit_the_contract_commands() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"starting_scenario": STEADY_BUILD, "seed": 5302})
	var view_model := {
		"current_port": {"id": "fixture", "name_key": "fixture"},
		"money": 100,
		"ship": {
			"total_weight": 1.0, "max_weight": 10.0, "cargo_used": 1.0, "cargo_capacity": 10.0,
			"hold": [
				{
					"item_id": "core:item/brass", "name_key": "item.core.brass.name",
					"category": "metal", "crafting_material": true, "unit_weight": 2.0,
					"amount": 3, "sellable_amount": 3, "is_contract": false,
					"contract_id": "", "avg_cost": 10.0, "icon_key": "",
				},
				{
					"item_id": "core:item/contract_freight", "name_key": "item.core.contract_freight.name",
					"category": "contract", "crafting_material": false, "unit_weight": 1.0,
					"amount": 1, "sellable_amount": 0, "is_contract": true,
					"contract_id": "fixture_contract", "avg_cost": 0.0, "icon_key": "",
				},
			],
		},
		"warehouse": {
			"port_id": "fixture",
			"materials": [{
				"item_id": "core:item/timber", "name_key": "item.core.timber.name",
				"category": "wood", "crafting_material": true, "unit_weight": 2.5,
				"amount": 4, "icon_key": "",
			}],
		},
		"market": [{
			"item_id": "core:item/brass", "name_key": "item.core.brass.name",
			"category": "metal", "crafting_material": true, "unit_weight": 2.0,
			"price": 88, "stock": 10, "buyable": true, "icon_key": "",
		}],
		"trends": {},
	}
	var tree := Engine.get_main_loop() as SceneTree
	var translate := Callable(context, "translate")

	var hold: Control = CARGO_HOLD_SCRIPT.new()
	var emitted: Array = []
	hold.command_requested.connect(func(command: StringName, params: Dictionary) -> void:
		emitted.append({"command": String(command), "params": params.duplicate(true)})
	)
	hold.bind(view_model, translate)
	tree.root.add_child(hold)
	var cargo_zone := _named_node(hold, "CargoDropZone")
	var warehouse_zone := _named_node(hold, "WarehouseDropZone")
	assert_not_null(cargo_zone, "standalone backpack exposes the cargo zone")
	assert_not_null(warehouse_zone, "standalone backpack exposes the warehouse zone")
	if cargo_zone == null or warehouse_zone == null:
		hold.get_parent().remove_child(hold)
		hold.free()
		return
	# Highlight only while a compatible payload hovers; incompatible kinds are rejected.
	assert_true(bool(cargo_zone.call("_can_drop_data", Vector2.ZERO, {"kind": "market_item"})),
		"the cargo zone accepts a market icon")
	assert_true(bool(cargo_zone.call("is_highlighted")), "accepted payloads light the drop zone")
	assert_false(bool(cargo_zone.call("_can_drop_data", Vector2.ZERO, {"kind": "cargo_item"})),
		"the cargo zone rejects its own cargo kind")
	assert_false(bool(cargo_zone.call("is_highlighted")), "a rejected payload clears the highlight again")

	cargo_zone.call("_drop_data", Vector2.ZERO, {"kind": "market_item", "item_id": "core:item/brass", "amount": 2})
	assert_eq(emitted.size(), 1, "a market icon dropped on 船舱货物 emits one command")
	if emitted.size() == 1:
		assert_eq(emitted[0]["command"], "trade.buy", "buying into cargo runs trade.buy")
		assert_eq(String(emitted[0]["params"].get("destination", "")), "cargo", "the buy names the cargo destination")
		assert_eq(int(emitted[0]["params"].get("amount", 0)), 2, "the buy carries the dragged amount")

	warehouse_zone.call("_drop_data", Vector2.ZERO, {"kind": "market_item", "item_id": "core:item/brass", "amount": 1})
	assert_eq(emitted.size(), 2, "a market icon dropped on 港口仓库 emits one command")
	if emitted.size() == 2:
		assert_eq(emitted[1]["command"], "trade.buy", "buying into the warehouse runs trade.buy")
		assert_eq(String(emitted[1]["params"].get("destination", "")), "warehouse", "the buy names the warehouse destination")

	warehouse_zone.call("_drop_data", Vector2.ZERO, {"kind": "cargo_item", "item_id": "core:item/brass", "amount": 3})
	assert_eq(emitted.size(), 3, "hold cargo dropped on the warehouse emits one command")
	if emitted.size() == 3:
		assert_eq(emitted[2]["command"], "warehouse.store_materials", "storing hold cargo runs warehouse.store_materials")
		assert_eq(int(emitted[2]["params"].get("amount", 0)), 3, "storing keeps the dragged amount")

	cargo_zone.call("_drop_data", Vector2.ZERO, {"kind": "warehouse_item", "item_id": "core:item/timber", "amount": 1})
	assert_eq(emitted.size(), 4, "warehouse material dropped on 船舱货物 emits one command")
	if emitted.size() == 4:
		assert_eq(emitted[3]["command"], "warehouse.take_materials", "taking warehouse material runs warehouse.take_materials")

	# Contract cargo tile: pure render, no drag payload.
	var contract_tile: Variant = null
	for node in _nodes_with_script(hold, ITEM_TILE_SCRIPT):
		if bool(node.get("locked")):
			contract_tile = node
			break
	assert_not_null(contract_tile, "the standalone backpack renders the locked contract cargo")
	if contract_tile != null:
		assert_true(contract_tile.call("_get_drag_data", Vector2.ZERO) == null, "contract cargo never produces a drag payload")

	# Sell side: the whole market panel maps cargo / warehouse payloads to trade.sell.
	var market: Control = MARKET_SCREEN_SCRIPT.new()
	var sells: Array = []
	market.command_requested.connect(func(command: StringName, params: Dictionary) -> void:
		sells.append({"command": String(command), "params": params.duplicate(true)})
	)
	market.bind(view_model, translate)
	tree.root.add_child(market)
	var sell_zone := _named_node(market, "MarketDropZone")
	assert_not_null(sell_zone, "the market panel exposes the sell drop zone")
	if sell_zone != null:
		assert_false(bool(sell_zone.call("_can_drop_data", Vector2.ZERO, {"kind": "market_item"})),
			"the sell zone rejects market icons")
		sell_zone.call("_drop_data", Vector2.ZERO, {"kind": "cargo_item", "item_id": "core:item/brass", "amount": 2})
		sell_zone.call("_drop_data", Vector2.ZERO, {"kind": "warehouse_item", "item_id": "core:item/timber", "amount": 1})
	assert_eq(sells.size(), 2, "both hold and warehouse payloads sell from the market panel")
	if sells.size() == 2:
		assert_eq(sells[0]["command"], "trade.sell", "hold cargo dropped on the market runs trade.sell")
		assert_eq(String(sells[0]["params"].get("source", "")), "cargo", "hold cargo sells from the cargo hold")
		assert_eq(sells[1]["command"], "trade.sell", "warehouse material dropped on the market runs trade.sell")
		assert_eq(String(sells[1]["params"].get("source", "")), "warehouse", "warehouse material sells from the warehouse")

	hold.get_parent().remove_child(hold)
	hold.free()
	market.get_parent().remove_child(market)
	market.free()


func _named_node(root: Node, node_name: String) -> Node:
	if String(root.name) == node_name:
		return root
	for child in root.get_children():
		var found := _named_node(child, node_name)
		if found != null:
			return found
	return null


## First Button whose node name starts with `prefix` (e.g. `BuyChartButton_`).
func _named_button_with_prefix(root: Node, prefix: String) -> Button:
	if root is Button and String(root.name).begins_with(prefix):
		return root as Button
	for child in root.get_children():
		var found := _named_button_with_prefix(child, prefix)
		if found != null:
			return found
	return null


## 性能回归守门（P0）：整页重建在一个读作用域里只克隆一次 GameState。
## 用「往快照写标记、下一个查询能否读到」来证明共享，避免实例 id 被复用造成误判。
func test_query_read_scope_shares_one_snapshot_and_command_invalidates_it() -> void:
	var bundle := _mount(5201)
	var context: AppContext = bundle["context"]
	context.queries.register(&"test.snapshot_write", func(_params: Dictionary, ctx) -> Dictionary:
		ctx.state.data["__read_scope_probe"] = true
		return {"ok": true, "data": {}})
	context.queries.register(&"test.snapshot_read", func(_params: Dictionary, ctx) -> Dictionary:
		return {"ok": true, "data": {"seen": ctx.state.data.has("__read_scope_probe")}})

	context.queries.begin_read_scope()
	context.queries.execute(&"test.snapshot_write")
	var shared: Dictionary = context.queries.execute(&"test.snapshot_read")
	context.queries.end_read_scope()
	assert_true(bool(shared["data"].get("seen", false)),
		"queries inside one read scope share the same state snapshot")
	assert_eq(context.queries.read_scope_depth(), 0, "the read scope is closed again")
	assert_false(context.state.data.has("__read_scope_probe"),
		"the shared snapshot never touches live state")

	context.queries.execute(&"test.snapshot_write")
	var fresh: Dictionary = context.queries.execute(&"test.snapshot_read")
	assert_false(bool(fresh["data"].get("seen", false)),
		"outside a read scope each query still gets a fresh clone")

	context.queries.begin_read_scope()
	context.queries.execute(&"test.snapshot_write")
	var waited := context.commands.execute(&"port.wait", {"hours": 1})
	assert_true(bool(waited.get("ok", false)), "port.wait commits inside the read scope: %s" % str(waited))
	var after_commit: Dictionary = context.queries.execute(&"test.snapshot_read")
	context.queries.end_read_scope()
	assert_false(bool(after_commit["data"].get("seen", false)),
		"a committed command invalidates the shared snapshot")
	_unmount(bundle)


## 性能回归守门（P0）：港口名按 run seed 缓存，一次 map.view 填满整张表。
func test_port_name_lookup_fills_a_per_run_cache() -> void:
	var bundle := _mount(5201)
	var context: AppContext = bundle["context"]
	var shell: Control = bundle["shell"]
	var ports: Array = context.queries.execute(&"map.view")["data"].get("ports", [])
	assert_true(ports.size() > 0, "the fixture run has ports")
	if ports.is_empty():
		_unmount(bundle)
		return
	var port_id := String((ports[0] as Dictionary).get("id", ""))
	var first: String = String(shell._port_name(port_id))
	assert_true(not first.is_empty(), "the port resolves to a display name")
	assert_eq(shell._port_name_cache.size(), ports.size(), "one map.view warms the whole table")
	var cached_snapshot: Dictionary = shell._port_name_cache.duplicate()
	assert_eq(shell._port_name(port_id), first, "a cached lookup returns the same name")
	assert_eq(shell._port_name_cache, cached_snapshot, "cached lookups do not re-query the map")
	_unmount(bundle)


## 退出崩溃守门（P0）：窗口关闭前先把舞台卸掉并清空页面树，让 GL 资源在
## renderer 还活着的时候释放；重复调用必须幂等。
func test_prepare_quit_unmounts_the_stage_and_clears_pages() -> void:
	var bundle := _mount(5201)
	var shell: Control = bundle["shell"]
	shell._active_screen = "overview"
	shell._refresh()
	var host: SNStageHost = shell._port_stage_host
	assert_true(host != null and host.has_stage(), "the overview mounts the 3D port stage")
	shell._prepare_quit()
	assert_false(host.has_stage(), "prepare_quit unmounts the 3D stage")
	assert_eq(shell._root_box.get_child_count(), 0, "prepare_quit clears the page tree")
	assert_eq(shell._fullscreen_layer.get_child_count(), 0, "prepare_quit clears the full-screen layer")
	shell._prepare_quit()
	assert_false(host.has_stage(), "prepare_quit is idempotent")
	_unmount(bundle)


## 反馈 #1（拿起 / 放下）：点市场图标后光标幽灵带着图标与数量跟随鼠标，船舱 / 仓库
## 落点被 arm，右键取消；切到另一个图标时旧格子归零。
func test_market_pickup_ghost_and_offer_targets() -> void:
	var bundle := _mount(5301)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	context.state.set_money(5000)
	_goto(shell, "market")
	var screens := _nodes_with_script(shell._root_box, MARKET_SCREEN_SCRIPT)
	assert_eq(screens.size(), 1, "the market page mounts one MarketScreen")
	if screens.is_empty():
		_unmount(bundle)
		return
	var screen: Control = screens[0]
	var market_tiles: Array = []
	for node in _nodes_with_script(shell._root_box, ITEM_TILE_SCRIPT):
		if String((node.get("item") as Dictionary).get("kind", "")) == "market_item":
			market_tiles.append(node)
	var tile: Variant = null
	var other_tile: Variant = null
	for node in market_tiles:
		if not bool(node.get("draggable")):
			continue
		if tile == null and int(node.get("max_pending")) >= 2:
			tile = node
		elif other_tile == null and node != tile:
			other_tile = node
	assert_not_null(tile, "at least one market tile can be picked up")
	if tile == null:
		_unmount(bundle)
		return
	# 角标语义（用户反馈）：市场格右上角显示「剩余库存」，不是已选购买数量。
	# 已选数量（×N）与预计消费都画在跟随鼠标的幽灵上。
	var stock := int(tile.get("max_pending"))
	var unit_price := int((tile.get("item") as Dictionary).get("price", 0))
	assert_true(unit_price > 0, "the fixture market row carries its unit price")
	var badge: SNBadge = tile.call("pending_badge")
	assert_not_null(badge, "the market tile exposes its corner badge")
	if badge != null:
		assert_true(badge.visible, "the remaining-stock badge is visible even before a click")
		assert_eq(String(badge.text), str(stock), "the badge starts at the full stock")
	var meta_label := tile.find_child("Meta", true, false) as Label
	assert_not_null(meta_label, "the market tile keeps its meta line")
	if meta_label != null:
		assert_true(String(meta_label.text).begins_with(shell._tr("ui.market.tile_meta", "") % unit_price),
			"the meta line only carries the unit price: %s" % String(meta_label.text))
	var offers: Array = []
	screen.carry_changed.connect(func(offer: Dictionary) -> void:
		offers.append(offer.duplicate(true))
	)
	tile.call("increment_pending")
	assert_eq(offers.size(), 1, "the first +1 publishes one carry offer")
	if offers.size() == 1:
		assert_eq(int(offers[0].get("unit_price", -1)), unit_price,
			"the carry offer carries the unit price for the estimated cost")
		assert_eq(int(offers[0].get("amount", 0)), 1, "the carry offer reports the selected amount")
	var ghost: Control = shell._carry_ghost
	assert_not_null(ghost, "picking up a market icon creates the cursor ghost")
	if ghost == null:
		_unmount(bundle)
		return
	assert_true(bool(ghost.call("is_carrying")), "the ghost reports the carried stack")
	assert_eq(int(ghost.call("amount")), 1, "the ghost shows the pending amount")
	assert_eq(String(ghost.call("cost_text")),
		String(shell._tr("ui.market.estimated_cost", "")) % (unit_price * 1),
		"the ghost shows unit_price x amount as the estimated cost")
	if badge != null:
		assert_eq(String(badge.text), str(stock - 1),
			"the corner badge shows the remaining stock after one click, not the selected amount")
		assert_false(String(badge.text).begins_with("×"), "the remaining-stock badge is a plain number")
	assert_true(ghost.visible, "the ghost is visible while carrying")
	# Headless mouse is (0,0): the pure placement helper asserts the +18/+12 offset.
	assert_eq(ghost.call("place_at", Vector2.ZERO), Vector2(18.0, 12.0),
		"the ghost floats at the pointer with the documented offset")
	assert_not_null(ghost.call("carried_icon"), "the carried icon travels with the ghost")
	tile.call("increment_pending")
	assert_eq(int(ghost.call("amount")), 2, "the number on the ghost follows every +1")
	assert_eq(String(ghost.call("cost_text")),
		String(shell._tr("ui.market.estimated_cost", "")) % (unit_price * 2),
		"the estimated cost follows every +1")
	if badge != null:
		assert_eq(String(badge.text), str(stock - 2),
			"the corner badge keeps counting down the remaining stock")

	var cargo_zone := _named_node(shell._root_box, "CargoDropZone")
	var warehouse_zone := _named_node(shell._root_box, "WarehouseDropZone")
	assert_not_null(cargo_zone, "the hold exposes the cargo drop target")
	assert_not_null(warehouse_zone, "the hold exposes the warehouse drop target")
	if cargo_zone != null and warehouse_zone != null:
		assert_true(bool(cargo_zone.call("offer_active")), "carrying arms the cargo target")
		assert_true(bool(warehouse_zone.call("offer_active")), "carrying arms the warehouse target")

	# Switching to another market tile clears the previous pending amount.
	if other_tile != null:
		other_tile.call("increment_pending")
		assert_eq(int(tile.get("pending")), 0, "switching the carried tile clears the old pending")
		assert_eq(int(ghost.call("amount")), 1, "the ghost shows the new stack size")
		var other_price := int((other_tile.get("item") as Dictionary).get("price", 0))
		assert_eq(String(ghost.call("cost_text")),
			String(shell._tr("ui.market.estimated_cost", "")) % (other_price * 1),
			"the estimated cost follows the newly carried item's price")
		var carried = screen.call("carrying_tile")
		assert_eq(carried, other_tile, "the page tracks exactly one carried tile")
		tile = other_tile

	# Right click cancels: pending, ghost and both drop targets reset.
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	screen.call("_input", right_click)
	assert_eq(int(tile.get("pending")), 0, "right click clears the carried pending amount")
	assert_false(bool(ghost.call("is_carrying")), "right click ends the carry")
	assert_false(ghost.visible, "right click hides the cursor ghost")
	if cargo_zone != null:
		assert_false(bool(cargo_zone.call("offer_active")), "right click disarms the cargo target")
	_unmount(bundle)


## 反馈 #1：拿到手上的货物点落点 / 点落点里的格子都能放下，且只发一条
## `trade.buy {amount = pending, destination}`；右键取消不发命令。
func test_market_pickup_click_places_the_carried_amount() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"starting_scenario": STEADY_BUILD, "seed": 5303})
	var view_model := {
		"current_port": {"id": "fixture", "name_key": "fixture"},
		"money": 100,
		"ship": {
			"total_weight": 1.0, "max_weight": 10.0, "cargo_used": 1.0, "cargo_capacity": 10.0,
			"hold": [{
				"item_id": "core:item/brass", "name_key": "item.core.brass.name",
				"category": "metal", "crafting_material": true, "unit_weight": 2.0,
				"amount": 3, "sellable_amount": 3, "is_contract": false,
				"contract_id": "", "avg_cost": 10.0, "icon_key": "",
			}],
		},
		"warehouse": {"port_id": "fixture", "materials": []},
		"market": [{
			"item_id": "core:item/brass", "name_key": "item.core.brass.name",
			"category": "metal", "crafting_material": true, "unit_weight": 2.0,
			"price": 88, "stock": 10, "buyable": true, "icon_key": "",
		}],
		"trends": {},
	}
	var tree := Engine.get_main_loop() as SceneTree
	var translate := Callable(context, "translate")
	var emitted: Array = []
	var hold: Control = CARGO_HOLD_SCRIPT.new()
	hold.command_requested.connect(func(command: StringName, params: Dictionary) -> void:
		emitted.append({"command": String(command), "params": params.duplicate(true)})
	)
	hold.bind(view_model, translate)
	tree.root.add_child(hold)
	var market: Control = MARKET_SCREEN_SCRIPT.new()
	market.command_requested.connect(func(_command: StringName, _params: Dictionary) -> void:
		emitted.append({"command": "sell_should_not_run"})
	)
	market.carry_changed.connect(func(offer: Dictionary) -> void:
		hold.set_offer(offer)
	)
	market.bind(view_model, translate)
	tree.root.add_child(market)

	var cargo_zone := _named_node(hold, "CargoDropZone")
	var tile: Variant = null
	for node in _nodes_with_script(market, ITEM_TILE_SCRIPT):
		if String((node.get("item") as Dictionary).get("kind", "")) == "market_item":
			tile = node
			break
	assert_not_null(tile, "the fixture market renders one draggable tile")
	if tile == null or cargo_zone == null:
		hold.get_parent().remove_child(hold)
		hold.free()
		market.get_parent().remove_child(market)
		market.free()
		return
	# 角标 / 单价契约（用户反馈）：fixture 行情行 price=88 / stock=10，角标显示剩余
	# 库存（10 → 9 → 8，纯数字），meta 只显示单价 + 趋势，carry offer 携带 unit_price。
	var offers: Array = []
	market.carry_changed.connect(func(offer: Dictionary) -> void:
		offers.append(offer.duplicate(true))
	)
	var expected_price := 88
	var expected_stock := 10
	assert_eq(int((tile.get("item") as Dictionary).get("price", 0)), expected_price,
		"the market tile item carries its unit price")
	assert_eq(int(tile.get("max_pending")), expected_stock, "the fixture tile starts from the full stock")
	var badge: SNBadge = tile.call("pending_badge")
	assert_not_null(badge, "the market tile exposes its corner badge")
	if badge != null:
		assert_true(badge.visible, "the remaining-stock badge is visible before any click")
		assert_eq(String(badge.text), str(expected_stock), "the badge starts at the full stock")
	var meta_label := tile.find_child("Meta", true, false) as Label
	assert_not_null(meta_label, "the market tile keeps its meta line")
	if meta_label != null:
		assert_true(String(meta_label.text).begins_with(context.translate("ui.market.tile_meta") % expected_price),
			"the meta line only carries the unit price, not the stock: %s" % String(meta_label.text))
	tile.call("increment_pending")
	assert_eq(offers.size(), 1, "the first +1 publishes one carry offer")
	if offers.size() == 1:
		assert_eq(int(offers[0].get("unit_price", -1)), expected_price,
			"the carry offer carries the unit price for the estimated cost")
		assert_eq(int(offers[0].get("amount", 0)), 1, "the carry offer reports the selected amount")
	if badge != null:
		assert_eq(String(badge.text), str(expected_stock - 1),
			"the corner badge shows the remaining stock after one click")
		assert_false(String(badge.text).begins_with("×"), "the remaining-stock badge is a plain number")
	tile.call("increment_pending")
	assert_eq(int(tile.get("pending")), 2, "two clicks carry two units")
	if offers.size() == 2:
		assert_eq(int(offers[1].get("unit_price", -1)), expected_price,
			"every carry offer keeps the unit price")
		assert_eq(int(offers[1].get("amount", 0)), 2, "the second offer reports both selected units")
	if badge != null:
		assert_eq(String(badge.text), str(expected_stock - 2),
			"the corner badge keeps counting down the remaining stock (not ×N)")
	assert_true(bool(cargo_zone.call("offer_active")), "the cargo target is armed while carrying")

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	cargo_zone.call("_gui_input", release)
	assert_eq(emitted.size(), 1, "clicking the armed cargo target emits exactly one command")
	if emitted.size() == 1:
		assert_eq(emitted[0]["command"], "trade.buy", "clicking the hold buys")
		assert_eq(String(emitted[0]["params"].get("destination", "")), "cargo", "the click names the cargo destination")
		assert_eq(int(emitted[0]["params"].get("amount", 0)), 2, "the click carries the pending amount")
		assert_false(bool(cargo_zone.call("offer_active")), "the target disarms after the drop")

	# A click on a cargo tile *inside* the zone must place the stack too (the tile is
	# MOUSE_FILTER_STOP, so it has to forward the click through `drop_host`).
	tile.call("increment_pending")
	assert_true(bool(cargo_zone.call("offer_active")), "the target re-arms on the next +1")
	var cargo_tile: Variant = null
	for node in _nodes_with_script(hold, ITEM_TILE_SCRIPT):
		if String((node.get("item") as Dictionary).get("kind", "")) == "cargo_item":
			cargo_tile = node
			break
	assert_not_null(cargo_tile, "the fixture hold renders a cargo tile")
	if cargo_tile != null:
		cargo_tile.call("_on_gui_input", release)
		assert_eq(emitted.size(), 2, "clicking a cargo tile inside the armed zone also places")
		if emitted.size() == 2:
			assert_eq(emitted[1]["command"], "trade.buy", "the inner tile click buys")
			assert_eq(int(emitted[1]["params"].get("amount", 0)), 3, "the inner tile click carries the pending amount")
		assert_eq(int(cargo_tile.get("pending")), 0, "placing the stack never bumps the zone tile's own pending")

	# Right click cancels without running a command.
	tile.call("increment_pending")
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	market.call("_input", right_click)
	assert_eq(int(tile.get("pending")), 0, "right click clears the pending carry")
	assert_false(bool(cargo_zone.call("offer_active")), "right click disarms the cargo target")
	assert_eq(emitted.size(), 2, "right click cancels the carry without a command")

	hold.get_parent().remove_child(hold)
	hold.free()
	market.get_parent().remove_child(market)
	market.free()


## 用户反馈（市场购买）：角标显示剩余数量、幽灵显示已选数量 + 预计消费。
## 聚焦 fixture（price=88 / stock=10）断言：角标 10 → 9 → 8 纯数字；幽灵 cost 文本
## = 单价 × 数量；market 行 meta 只有单价；中英文案都只插值价格 / 金额。
func test_market_tile_remaining_badge_and_estimated_cost_ghost() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"starting_scenario": STEADY_BUILD, "seed": 5304})
	var view_model := {
		"current_port": {"id": "fixture", "name_key": "fixture"},
		"money": 500,
		"ship": {"total_weight": 0.0, "max_weight": 10.0, "cargo_used": 0.0, "cargo_capacity": 10.0, "hold": []},
		"warehouse": {"port_id": "fixture", "materials": []},
		"market": [{
			"item_id": "core:item/brass", "name_key": "item.core.brass.name",
			"category": "metal", "crafting_material": true, "unit_weight": 2.0,
			"price": 88, "stock": 10, "buyable": true, "icon_key": "",
		}],
		"trends": {},
	}
	var tree := Engine.get_main_loop() as SceneTree
	var market: Control = MARKET_SCREEN_SCRIPT.new()
	market.bind(view_model, Callable(context, "translate"))
	tree.root.add_child(market)
	var ghost: Control = CARRY_GHOST_SCENE.instantiate() as Control
	tree.root.add_child(ghost)
	# 场景化（P0）：静态骨架来自 .tscn，节点名 / 尺寸 / 初始隐藏是契约（R2）。
	assert_not_null(ghost.find_child("GhostPanel", true, false), "the ghost scene keeps its GhostPanel")
	assert_not_null(ghost.find_child("GhostRow", true, false), "the ghost scene keeps its GhostRow")
	var ghost_icon: TextureRect = ghost.find_child("Icon", true, false) as TextureRect
	assert_not_null(ghost_icon, "the ghost scene keeps its 40 px Icon slot")
	if ghost_icon != null:
		assert_eq(ghost_icon.custom_minimum_size, Vector2(40.0, 40.0),
			"the ghost icon size is a scene design constant")
	var ghost_cost: Label = ghost.find_child("Cost", true, false) as Label
	assert_not_null(ghost_cost, "the ghost scene keeps its estimated-cost line")
	if ghost_cost != null:
		assert_false(ghost_cost.visible, "the estimated-cost line starts hidden until a cost is passed")
	var tile: Variant = null
	for node in _nodes_with_script(market, ITEM_TILE_SCRIPT):
		if String((node.get("item") as Dictionary).get("kind", "")) == "market_item":
			tile = node
			break
	assert_not_null(tile, "the fixture market renders one market tile")
	if tile == null:
		market.get_parent().remove_child(market)
		market.free()
		ghost.get_parent().remove_child(ghost)
		ghost.free()
		return
	var badge: SNBadge = tile.call("pending_badge")
	assert_not_null(badge, "the market tile exposes its corner badge")
	if badge != null:
		assert_true(badge.visible, "the remaining-stock badge is always visible on market tiles")
		assert_eq(String(badge.text), "10", "the badge starts at the full stock with plain digits")
	var meta_label := tile.find_child("Meta", true, false) as Label
	assert_not_null(meta_label, "the market tile keeps its meta line")
	if meta_label != null:
		assert_eq(String(meta_label.text),
			String(context.translate("ui.market.tile_meta")) % 88 + " →",
			"the meta line only carries the unit price plus the trend arrow")

	var offers: Array = []
	market.carry_changed.connect(func(offer: Dictionary) -> void:
		offers.append(offer.duplicate(true))
	)
	tile.call("increment_pending")
	assert_eq(int(tile.get("pending")), 1, "one click selects one unit")
	assert_eq(offers.size(), 1, "the click publishes the carry offer")
	if offers.size() == 1:
		assert_eq(int(offers[0].get("unit_price", -1)), 88, "the offer carries the unit price")
	var cost_template := String(context.translate("ui.market.estimated_cost"))
	ghost.call("begin", tile.call("icon_texture"), "黄铜", int(offers[0].get("amount", 0)), "", cost_template % 88)
	assert_eq(ghost.call("cost_text"), cost_template % 88,
		"the ghost paints the estimated cost for one unit")
	assert_eq(int(ghost.call("amount")), 1, "the ghost paints the selected amount")
	if badge != null:
		assert_eq(String(badge.text), "9", "after one click the badge shows the remaining stock")

	tile.call("increment_pending")
	assert_eq(offers.size(), 2, "the second click publishes an updated offer")
	ghost.call("begin", tile.call("icon_texture"), "黄铜", int(offers[1].get("amount", 0)), "", cost_template % (88 * 2))
	assert_eq(ghost.call("cost_text"), cost_template % 176,
		"the estimated cost follows the selected amount (unit price x 2)")
	if badge != null:
		assert_eq(String(badge.text), "8", "two clicks leave 8 in stock")

	# 空 cost_text 时隐藏预计消费行（非市场 / 没有单价时）。
	ghost.call("begin", tile.call("icon_texture"), "黄铜", 1, "", "")
	assert_eq(ghost.call("cost_text"), "", "an empty cost hides the estimated-cost line")

	# 两套语言都只插值价格 / 金额，模板不再带库存槽位。
	for path in ["res://framework/localization/zh_CN.json", "res://framework/localization/en.json"]:
		var locale: Dictionary = _localization_keys(path)
		assert_eq(_slots(String(locale.get("ui.market.tile_meta", ""))), "%d",
			"ui.market.tile_meta interpolates only the unit price (%s)" % path)
		assert_eq(_slots(String(locale.get("ui.market.estimated_cost", ""))), "%d",
			"ui.market.estimated_cost interpolates only the total cost (%s)" % path)

	market.get_parent().remove_child(market)
	market.free()
	ghost.get_parent().remove_child(ghost)
	ghost.free()


## dev.3 反馈 #4：命令成功 / 失败的瞬时反馈要在鼠标交互处浮出，而不是只写顶部
## banner；提示是框架级浮层（页面滚动区之外、不吃鼠标、两种分辨率都不越界），
## 菜单 / 演出期间不弹。
func test_interaction_hint_pops_at_the_cursor_for_command_feedback() -> void:
	var bundle := _mount(5301)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	_goto(shell, "market")
	# Mid-tutorial fixtures may keep the story card open; the floating hint is a port
	# page interaction, so pin the card closed for this wiring test.
	shell._story_card_open = false
	# A failed command: hint must show the localized error at the cursor.
	shell._run_command(&"trade.buy", {"item_id": "core:item/no_such_item", "amount": 1})
	var hint: Control = shell._interaction_hint
	assert_not_null(hint, "a command on a port page creates the floating hint")
	if hint == null:
		_unmount(bundle)
		return
	# 场景化（P0）：浮层骨架来自 sn_interaction_hint.tscn（R2 节点名契约）。
	for node_name in ["HintPanel", "HintRow", "Icon", "Message"]:
		assert_not_null(hint.find_child(node_name, true, false),
			"the hint scene keeps its %s node" % node_name)
	assert_true(bool(hint.call("is_showing")), "the failed command pops the hint")
	assert_true(hint.visible, "the hint is painted")
	assert_true(bool(hint.call("current_error")), "failures use the error tone")
	assert_true(not String(hint.call("current_message")).is_empty(), "the hint carries the status text")
	var failed_message := String(hint.call("current_message"))
	# The top banner is still filled (persistent status stays the contract).
	assert_eq(String(shell._status_message), failed_message, "the banner keeps the same status message")
	assert_true(bool(shell._status_is_error), "the banner keeps the error flag")
	# 宽度回归（窗口实拍发现）：OVERRUN_TRIM_ELLIPSIS 让 Label 的最小宽度只剩 1 px，
	# 旧实现的面板会塌缩成图标宽（约 45 px）且文字只剩省略号；show_at 必须按文本测宽。
	var measured_hint_width: float = hint.get_combined_minimum_size().x
	assert_true(measured_hint_width > 80.0,
		"the hint measures its message instead of collapsing onto the icon (%s px)" % measured_hint_width)

	# The hint lives on the shell overlay, outside the PageScroll.
	var layer := hint.get_parent()
	assert_not_null(layer, "the hint has a parent layer")
	if layer != null:
		assert_eq(String(layer.name), "HintLayer", "the hint sits on the shell hint layer")
		assert_true(layer.get_parent() == shell, "the hint layer is a direct shell child")
	var scroll := shell.get_node_or_null("PageMargin/PageScroll")
	assert_true(scroll is ScrollContainer, "the page scroll container exists")
	if scroll is ScrollContainer:
		assert_false((scroll as ScrollContainer).is_ancestor_of(hint),
			"the hint is outside the page scroll so it cannot be clipped")
	for node in [hint, hint.get_child(0) if hint.get_child_count() > 0 else null]:
		if node is Control:
			assert_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE,
				"the hint never swallows the click that places the carried stack")
	var viewport_size := shell.get_viewport_rect().size
	var hint_bounds: Vector2 = hint.get_combined_minimum_size()
	# Pure placement: above the pointer, clamped inside the viewport at the edge.
	var bottom_right: Vector2 = hint.call("place_at", viewport_size - Vector2(4.0, 4.0))
	assert_true(bottom_right.x >= 0.0 and bottom_right.x + hint_bounds.x <= viewport_size.x + 0.5,
		"the hint stays inside the viewport horizontally")
	assert_true(bottom_right.y >= 0.0 and bottom_right.y + hint_bounds.y <= viewport_size.y + 0.5,
		"the hint stays inside the viewport vertically")
	var middle: Vector2 = hint.call("place_at", Vector2(400.0, 300.0))
	assert_true(middle.y < 300.0, "the hint floats above the interaction point")

	# A successful command updates the hint to the success tone / text.
	shell._story_card_open = false
	shell._run_command(&"port.wait", {"hours": 1})
	assert_true(bool(hint.call("is_showing")), "the successful command keeps the hint visible")
	assert_false(bool(hint.call("current_error")), "success uses the success tone")
	assert_true(String(hint.call("current_message")).length() > 0, "success also reports the status text")

	# Menu pages /演出 do not pop the hint.
	var previous_screen := String(shell._active_screen)
	shell._active_screen = "settings"
	shell._interactive_command = true
	shell._set_status("MENU_ONLY_STATUS", false)
	assert_true(String(hint.call("current_message")) != "MENU_ONLY_STATUS",
		"menu status messages do not pop the floating hint")
	shell._interactive_command = false
	shell._active_screen = previous_screen
	# 上限：超长消息最多撑到 MAX_TEXT_WIDTH(520) + 图标 18 + separation 6 + 内容边距 20，
	# 不再无限变宽；截断仍由场景里的 text_overrun_behavior = 3 完成。
	hint.call("show_at", Vector2(240.0, 240.0), "交互提示宽度上限回归".repeat(8), false)
	var capped_width: float = hint.get_combined_minimum_size().x
	assert_true(capped_width <= 570.0,
		"an overlong hint message is capped at 520 px of text (%s px)" % capped_width)
	assert_true(capped_width > 80.0,
		"the capped hint still measures its text instead of collapsing (%s px)" % capped_width)
	_unmount(bundle)


## 设置页「允许上传数据」行（docs/design/TELEMETRY.md §2）：96 px 字段名、不自动换行、
## 开/关值按钮发出 toggle_telemetry，右侧说明使用契约文案。
func test_settings_screen_offers_the_telemetry_row() -> void:
	var translate := func(key: String) -> String: return key
	var screen: Control = SETTINGS_SCREEN_SCRIPT.new()
	var actions: Array = []
	screen.action_requested.connect(func(action: StringName, params: Dictionary) -> void:
		actions.append([String(action), params])
	)
	screen.bind({
		"locale": "zh_CN",
		"autosave_enabled": true,
		"telemetry_enabled": false,
		"show_settings_path": false,
	}, translate)
	var row := _telemetry_row(screen)
	assert_not_null(row, "the settings page renders the telemetry row")
	if row != null:
		assert_true(row.get_child_count() >= 3, "the telemetry row has label + value button + note")
		var field := row.get_child(0) as Label
		assert_not_null(field, "the telemetry row starts with its field label")
		if field != null:
			assert_eq(field.custom_minimum_size.x, 96.0, "the telemetry field keeps the 96 px label width")
			assert_eq(field.autowrap_mode, TextServer.AUTOWRAP_OFF, "the telemetry field never wraps")
		for label in row.find_children("*", "Label", true, false):
			assert_eq((label as Label).autowrap_mode, TextServer.AUTOWRAP_OFF,
				"telemetry row labels stay on one horizontal line")
		var toggle := row.get_child(1) as Button
		assert_not_null(toggle, "the telemetry row has an on/off button")
		if toggle != null:
			assert_eq(toggle.text, "关", "telemetry defaults to off in the settings row")
			toggle.emit_signal("pressed")
	assert_eq(actions.size(), 1, "pressing the telemetry value emits exactly one intent")
	if actions.size() == 1:
		assert_eq(String(actions[0][0]), "toggle_telemetry", "the value button requests toggle_telemetry")
	assert_contains(_label_texts(screen), "勾选后，每次结束游玩时会把本局游戏日志上传到官网，用于改进游戏；仅含游玩数据，不含个人信息。",
		"the row explains what is uploaded")
	screen.free()
	var enabled_screen: Control = SETTINGS_SCREEN_SCRIPT.new()
	enabled_screen.bind({
		"locale": "zh_CN",
		"autosave_enabled": true,
		"telemetry_enabled": true,
		"show_settings_path": false,
	}, translate)
	var enabled_row := _telemetry_row(enabled_screen)
	assert_not_null(enabled_row, "the enabled settings page keeps the telemetry row")
	if enabled_row != null:
		var enabled_toggle := enabled_row.get_child(1) as Button
		assert_not_null(enabled_toggle, "the enabled row still has its value button")
		if enabled_toggle != null:
			assert_eq(enabled_toggle.text, "开", "the row shows 开 when telemetry is enabled")
	enabled_screen.free()


## Shell 接线：设置页 VM 来自 SettingsService，toggle 即时切换记录器并写回配置；
## 白名单领域事件与命令记录进本局日志（TELEMETRY.md §3、§6.1/§6.2）。
func test_shell_telemetry_toggle_updates_service_and_settings() -> void:
	var bundle := _mount(5211)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	var root := "user://test_ui_telemetry"
	_remove_tree(root)
	shell._settings = SettingsService.load_settings(root.path_join("config/config.json"), "res://config/config.json")
	shell._settings.set_locale("zh_CN")
	context.localization.set_locale("zh_CN")
	assert_not_null(context.telemetry, "the shell binds a telemetry service to the context")
	if context.telemetry == null:
		_unmount(bundle)
		return
	# 测试用临时队列目录，绝不写真实 user://telemetry/。
	context.telemetry.pending_dir = root.path_join("pending")
	assert_false(shell._settings.telemetry(), "telemetry defaults to off")
	shell._on_menu_action(&"toggle_telemetry", {})
	assert_true(shell._settings.telemetry(), "enabling telemetry writes the setting")
	assert_true(context.telemetry.is_enabled(), "enabling telemetry turns the live service on")
	assert_true(context.telemetry.is_recording(), "enabling telemetry starts a session")
	var reloaded := SettingsService.load_settings(root.path_join("config/config.json"), "res://config/config.json")
	assert_true(reloaded.telemetry(), "the toggle persists to config/config.json")
	# §3.3：白名单领域事件进 events，UI 事件被忽略；CommandBus 记录命令。
	context.events.publish(&"voyage.completed", {"destination": "core:port_template/iron_harbor"}, 5.0)
	context.events.publish(&"ui.chart_opened", {}, 6.0)
	shell._run_command(&"port.wait", {"hours": 1})
	var payload := context.telemetry.build_payload(shell._telemetry_summary())
	var events: Array = payload.get("events", [])
	var event_types: Array = []
	for entry in events:
		event_types.append(String(entry.get("event_type", "")))
	assert_true(event_types.has("voyage.completed"), "the whitelisted voyage event is recorded")
	assert_false(event_types.has("ui.chart_opened"), "UI events are not recorded (contract whitelist)")
	for event_type in event_types:
		assert_false(String(event_type).begins_with("ui."), "only domain events reach the telemetry buffer")
	var recorded := false
	for entry in Array(payload.get("commands", [])):
		if String(entry.get("command", "")) == "port.wait":
			recorded = true
			assert_eq(int((entry.get("params", {}) as Dictionary).get("hours", 0)), 1,
				"the shell command forwards its whitelisted param to the telemetry payload")
	assert_true(recorded, "commands executed through the shell are recorded by CommandBus")
	# 关闭：停止记录、删除待上传队列（§2）。先回到主菜单设置页以便点按钮。
	context.reset_state()
	shell._transitioning = false
	shell._pending_transition = false
	shell._menu_screen = "settings"
	shell._refresh()
	var row := _telemetry_row(shell._root_box)
	assert_not_null(row, "the settings menu renders the telemetry row")
	if row != null:
		var toggle := row.get_child(1) as Button
		assert_not_null(toggle, "the settings menu has the telemetry toggle")
		if toggle != null:
			assert_eq(toggle.text, "开", "the row shows 开 after enabling")
			toggle.emit_signal("pressed")
	assert_false(shell._settings.telemetry(), "pressing the row toggles telemetry off")
	assert_false(context.telemetry.is_enabled(), "disabling telemetry turns the service off")
	assert_false(context.telemetry.is_recording(), "disabling telemetry stops recording")
	assert_eq(context.telemetry.pending_count(), 0, "disabling telemetry deletes the pending queue")
	shell._transitioning = false
	shell._pending_transition = false
	_remove_tree(root)
	_unmount(bundle)

