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
const MAP_CANVAS_SCRIPT := preload("res://framework/ui/components/map_canvas.gd")
const MARKET_SCREEN_SCRIPT := preload("res://framework/ui/screens/port/market_screen.gd")
const CONTRACTS_SCREEN_SCRIPT := preload("res://framework/ui/screens/port/contracts_screen.gd")
const SUPPLY_SCREEN_SCRIPT := preload("res://framework/ui/screens/port/supply_screen.gd")
const INTEL_SCREEN_SCRIPT := preload("res://framework/ui/screens/port/intel_screen.gd")
const VOYAGE_SCREEN_SCRIPT := preload("res://framework/ui/screens/port/voyage_screen.gd")
const OVERVIEW_SCREEN_SCRIPT := preload("res://framework/ui/screens/port/overview_screen.gd")
const SHIPYARD_SCREEN_SCRIPT := preload("res://framework/ui/screens/port/shipyard_screen.gd")
const PORT_MEMORY_SCREEN_SCRIPT := preload("res://framework/ui/screens/flow/port_memory_screen.gd")
const SETTLEMENT_SCREEN_SCRIPT := preload("res://framework/ui/screens/flow/settlement_screen.gd")
const AT_SEA_SCREEN_SCRIPT := preload("res://framework/ui/screens/flow/at_sea_screen.gd")
const EVENT_SCREEN_SCRIPT := preload("res://framework/ui/screens/flow/event_screen.gd")
const VICTORY_SCREEN_SCRIPT := preload("res://framework/ui/screens/flow/victory_screen.gd")
const MAIN_MENU_SCREEN_SCRIPT := preload("res://framework/ui/screens/menu/main_menu_screen.gd")
const NEW_GAME_SCREEN_SCRIPT := preload("res://framework/ui/screens/menu/new_game_screen.gd")
const MODS_SCREEN_SCRIPT := preload("res://framework/ui/screens/menu/mods_screen.gd")
const SETTINGS_SCREEN_SCRIPT := preload("res://framework/ui/screens/menu/settings_screen.gd")
const STEADY_BUILD := "core:starting_build/steady"

## Notices whose rendered sentence is spelled out (per language) in
## `test_notice_log_renders_filled_localized_text`: every notice with more than
## one slot belongs here, because a swapped pair of slots still renders as a
## plausible-looking sentence in either language.
const LITERAL_EXPECTED_NOTICE_KEYS := [
	"ui.notice.craft_ordered",
	"ui.notice.craft_completed",
	"ui.notice.waited",
]


func _mount(seed_value: int) -> Dictionary:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var started := context.commands.execute(&"run.start", {
		"build_id": STEADY_BUILD,
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


func _meter_of_supply_card(root: Node, title: String) -> Control:
	for card in _nodes_with_script(root, CARD_SCRIPT):
		if not _label_texts(card).has(title):
			continue
		var meters := _nodes_with_script(card, METER_SCRIPT)
		if not meters.is_empty():
			return meters[0]
	return null


func test_dense_screen_fields_keep_horizontal_minimum_widths() -> void:
	for screen_script in [SETTINGS_SCREEN_SCRIPT, OVERVIEW_SCREEN_SCRIPT, MARKET_SCREEN_SCRIPT, SHIPYARD_SCREEN_SCRIPT]:
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
	var regular_style := goods_header.get_theme_stylebox("panel") as StyleBoxFlat
	assert_true(regular_style.bg_color.r < 0.2 and regular_style.bg_color.g < 0.2, "ordinary intel cells use the dark interface palette instead of StyleBoxFlat default gray")
	table.free()


func test_stats_bar_shows_the_current_port_and_remaining_capacity() -> void:
	var bundle := _mount(5101)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	var view: Dictionary = context.queries.execute(&"port.view")["data"]
	var ship: Dictionary = view["ship"]
	var texts := _label_texts(shell._root_box)
	assert_eq(_nodes_with_script(shell._root_box, OVERVIEW_SCREEN_SCRIPT).size(), 1, "the shell instantiates the extracted overview screen")
	assert_eq(_nodes_with_script(shell._root_box, MAP_CANVAS_SCRIPT).size(), 1, "overview instantiates the extracted map scene")
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
	_goto(shell, "voyage")
	assert_eq(_nodes_with_script(shell._root_box, VOYAGE_SCREEN_SCRIPT).size(), 1, "the shell instantiates the extracted voyage screen")
	shell._memory_port_id = String(view.get("current_port_id", ""))
	_goto(shell, "port_memory")
	assert_eq(_nodes_with_script(shell._root_box, PORT_MEMORY_SCREEN_SCRIPT).size(), 1, "the shell instantiates the extracted port-memory screen")
	shell._settlement_summary = {"destination": String(view.get("current_port_id", "")), "arrival_time": 1.0, "contracts": []}
	_goto(shell, "settlement")
	assert_eq(_nodes_with_script(shell._root_box, SETTLEMENT_SCREEN_SCRIPT).size(), 1, "the shell instantiates the extracted settlement screen")
	shell._screen_at_sea(view, {"origin": String(view.get("current_port_id", "")), "destination": String(view.get("current_port_id", "")), "arrival_time": 1.0})
	assert_eq(_nodes_with_script(shell._root_box, AT_SEA_SCREEN_SCRIPT).size(), 1, "the shell instantiates the extracted at-sea screen")
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
	_goto(shell, "shipyard")
	assert_contains(_label_texts(shell._root_box), shell._tr("ui.victory.plan_title", ""), "the shipyard repeats the win conditions")
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
	var craft_button := _button_by_text(shell._root_box, shipyard_screen._craft_button_text(recipe))
	assert_not_null(craft_button, "the craft button states the work hours it commits to")
	var module_id := String(recipe["module_id"])
	var port_id := String(context.state.current_port_id())
	var money_before := context.state.money()
	craft_button.emit_signal("pressed")
	assert_eq(CraftOps.orders(context.state).size(), 1, "crafting queues an order instead of finishing instantly")
	assert_eq(context.state.money(), money_before - int(recipe["craft_cost"]), "the order charges its gold cost")
	assert_eq(WarehouseOps.module_qty(context.state, port_id, module_id), 0, "the ordered module is not delivered immediately")
	var wait_button := _button_by_text(shell._root_box, "24 h")
	assert_not_null(wait_button, "the shipyard offers a 24-hour port wait")
	var time_before := context.state.now()
	wait_button.emit_signal("pressed")
	assert_almost_eq(context.state.now(), time_before + 24.0, 0.001, "the wait button advances game time")
	assert_eq(CraftOps.orders(context.state).size(), 0, "the finished order leaves the queue")
	assert_eq(WarehouseOps.module_qty(context.state, port_id, module_id), 1, "the finished module lands in the ordering port warehouse")
	_unmount(bundle)


func test_supply_screen_paints_the_lost_capacity_band() -> void:
	var bundle := _mount(5104)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	context.state.ship()["coal"] = 0.0
	context.state.ship()["water"] = 0.0
	_goto(shell, "supply")
	assert_eq(_nodes_with_script(shell._root_box, SUPPLY_SCREEN_SCRIPT).size(), 1, "the shell instantiates the extracted supply screen")
	var water_label: String = shell._tr("ui.label.water", "")
	var water_meter := _meter_of_supply_card(shell._root_box, water_label)
	assert_not_null(water_meter, "the supply screen renders a water meter")
	assert_almost_eq(float(water_meter.loss_value), 0.0, 0.001, "nothing is lost while both tanks are empty")
	var before: Dictionary = context.queries.execute(&"supply.view")["data"]["water_view"]
	var bought := context.commands.execute(&"supply.buy_coal", {"amount": 10})
	assert_true(bool(bought.get("ok", false)), "buying coal succeeds: %s" % str(bought))
	_goto(shell, "supply")
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


func test_intel_screen_renders_the_port_comparison_table() -> void:
	var bundle := _mount(5105)
	var shell: Control = bundle["shell"]
	var context: AppContext = bundle["context"]
	context.commands.execute(&"intel.refresh")
	_goto(shell, "intel")
	assert_eq(_nodes_with_script(shell._root_box, INTEL_SCREEN_SCRIPT).size(), 1, "the shell instantiates the extracted intel screen")
	var tables := _nodes_with_script(shell._root_box, INTEL_TABLE_SCRIPT)
	assert_eq(tables.size(), 1, "the intel screen renders one goods-by-port table")
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
	var module_key := String(ShipOps.find_module(context.registries, module_id).name_key)
	var port_key := String(yard["port_name_key"])
	var cost := int(recipe["craft_cost"])
	assert_true(context.commands.execute(&"ship.craft_module", {"module_id": module_id}).get("ok", false), "the order is placed")
	context.commands.execute(&"port.wait", {"hours": 24})
	# The shell takes its locale from the player's saved settings, so pin it here:
	# the expected sentences below are per language.
	context.localization.set_locale("zh_CN")
	_goto(shell, "overview")
	var log_texts := _log_lines(shell)
	assert_true(log_texts.size() >= 3, "the sailing log lists the session notices: %s" % str(log_texts))
	_assert_notice_log(log_texts, context, port_key, module_key, cost, str(float(recipe["craft_time_hours"])), false)
	# Same log in English. The expected sentences are spelled out per language
	# below: a template whose slots are swapped still renders, so only a literal
	# expectation catches "the English copy says it the wrong way round".
	context.localization.set_locale("en")
	_goto(shell, "overview")
	_assert_notice_log(_log_lines(shell), context, port_key, module_key, cost, str(float(recipe["craft_time_hours"])), true)
	context.localization.set_locale("zh_CN")
	_unmount(bundle)


func _assert_notice_log(log_texts: Array, context: AppContext, port_key: String, module_key: String, cost: int, hours_text: String, english: bool) -> void:
	var port_name := context.translate(port_key, "")
	var module_name := context.translate(module_key, "")
	var expected_order := "· 已在 %s 下单打造 %s · 工时 %s 小时 · 花费 %d 金币。" % [port_name, module_name, hours_text, cost]
	var expected_completed := "· %s 打造完成，已存入 %s 仓库。" % [module_name, port_name]
	var expected_wait := "· 在 %s 等待了 24 小时。" % port_name
	if english:
		expected_order = "· Ordered at %s: %s · %s hours · %d gold." % [port_name, module_name, hours_text, cost]
		expected_completed = "· %s finished and was stored in the warehouse of %s." % [module_name, port_name]
		expected_wait = "· Waited at %s for 24 hours." % port_name
	for text in log_texts:
		assert_false(text.contains("%s") or text.contains("%d"), "the log line is filled in, not a raw template: %s" % text)
		assert_false(text.contains("ui.notice."), "the log line is translated, not a raw key: %s" % text)
	assert_contains(log_texts, expected_order, "the log orders the port, module, hours and gold (%s)" % ("en" if english else "zh"))
	assert_contains(log_texts, expected_completed, "the log reports the finished module before its port (%s)" % ("en" if english else "zh"))
	assert_contains(log_texts, expected_wait, "the log waits at the port for the hours (%s)" % ("en" if english else "zh"))
	var build_name := context.translate(String(context.registries.get_by_id(ContentTypes.STARTING_BUILD, STEADY_BUILD).name_key), "")
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
