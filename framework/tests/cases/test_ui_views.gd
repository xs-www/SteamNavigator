extends TestCase

## Loaded by path so the component works even before the editor refreshes the
## global class cache (`class_name SNIntelTable` stays the public API).
const SNIntelTableScript := preload("res://framework/ui/components/sn_intel_table.gd")


func _candidate(rows: Array, module_id: String) -> Dictionary:
	for row in rows:
		if row is Dictionary and String(row.get("module_id", "")) == module_id:
			return row
	return {}


func test_shipyard_view_reports_slots_and_blockers() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": 8181})
	var result := context.queries.execute(&"shipyard.view")
	assert_true(bool(result["ok"]), "shipyard view succeeds")
	var data: Dictionary = result["data"]
	assert_true(bool(data["has_shipyard"]), "starting hub has a shipyard")
	var candidates: Array = data["candidates"]
	assert_true(candidates.size() >= 10, "all module types are listed")
	var installed_hull := _candidate(candidates, "core:hull/small_efficient")
	assert_true(bool(installed_hull["installed"]), "current hull is marked installed")
	assert_false(bool(installed_hull["can_install"]), "installed hull cannot be installed again")
	var medium_hull := _candidate(candidates, "core:hull/medium_standard")
	assert_false(bool(medium_hull["can_install"]), "medium hull is contract-locked at start")
	assert_contains(medium_hull["blockers"], "locked_by_contract", "contract lock blocker is exposed")
	assert_contains(medium_hull["blockers"], "insufficient_money", "money blocker is exposed")
	context.state.set_money(5000)
	var rich_result := context.queries.execute(&"shipyard.view")
	var rich: Dictionary = rich_result["data"]
	var still_locked := _candidate(rich["candidates"], "core:hull/medium_standard")
	assert_false(bool(still_locked["can_install"]), "money alone does not unlock the medium hull")
	assert_contains(still_locked["blockers"], "locked_by_contract", "contract lock survives having enough money")
	var unlocks: Array = context.state.player().get("unlocks", [])
	if not unlocks.has("core:hull/medium_standard"):
		unlocks.append("core:hull/medium_standard")
	context.state.player()["unlocks"] = unlocks
	var unlocked_result := context.queries.execute(&"shipyard.view")
	var unlocked: Dictionary = unlocked_result["data"]
	var affordable := _candidate(unlocked["candidates"], "core:hull/medium_standard")
	assert_true(bool(affordable["can_install"]), "medium hull becomes installable after the main_03 unlock")


func test_intel_view_exposes_snapshot_rows() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": 8282})
	var empty := context.queries.execute(&"intel.view")
	assert_true(bool(empty["ok"]), "intel view succeeds")
	assert_false(bool(empty["data"]["has_report"]), "no report before refreshing")
	var intel_port := ""
	for port_id in context.state.world().get("ports", {}).keys():
		var port: Dictionary = context.state.world()["ports"][port_id]
		if MapOps.has_tavern(port):
			intel_port = String(port_id)
			break
	assert_true(not intel_port.is_empty(), "map contains a tavern harbour")
	context.state.world()["current_port_id"] = intel_port
	var discovered: Array = context.state.world().get("discovered_ports", [])
	if not discovered.has(intel_port):
		discovered.append(intel_port)
	context.state.world()["discovered_ports"] = discovered
	var refresh := context.commands.execute(&"intel.refresh", {})
	assert_true(bool(refresh["ok"]), "price-intel refresh succeeds: %s" % str(refresh))
	var report := context.queries.execute(&"intel.view")
	var data: Dictionary = report["data"]
	assert_true(bool(data["has_report"]), "report exists after refresh")
	assert_true(int(data["port_count"]) >= 1, "report contains the discovered port")
	assert_true(not String(data["generated_label"]).is_empty(), "report has a timestamp")
	assert_true(data["ports"].size() >= 1, "port rows are exposed")


func _facility_port(context: AppContext, facility: String) -> String:
	for raw_port_id in context.state.world().get("ports", {}).keys():
		var port: Dictionary = context.state.world()["ports"][raw_port_id]
		if Array(port.get("facilities", [])).has(facility):
			return String(raw_port_id)
	return ""


func _column(columns: Array, port_id: String) -> Dictionary:
	for column in columns:
		if column is Dictionary and String(column.get("port_id", "")) == port_id:
			return column
	return {}


func _row(rows: Array, item_id: String) -> Dictionary:
	for row in rows:
		if row is Dictionary and String(row.get("item_id", "")) == item_id:
			return row
	return {}


func _cell(cells: Array, port_id: String) -> Dictionary:
	for cell in cells:
		if cell is Dictionary and String(cell.get("port_id", "")) == port_id:
			return cell
	return {}


func _label_texts(node: Node) -> Array[String]:
	var texts: Array[String] = []
	if node is Label:
		texts.append((node as Label).text)
	for child in node.get_children():
		texts.append_array(_label_texts(child))
	return texts


func _has_text_containing(texts: Array[String], needle: String) -> bool:
	for text in texts:
		if text.contains(needle):
			return true
	return false


## Moves to a tavern harbour and refreshes so the comparison matrix has a report.
## The start hub already has a tavern (4.5.4), so this also reveals one neighbour:
## the matrix needs a second discovered port to compare against.
func _refresh_intel(context: AppContext) -> String:
	var intel_port := _facility_port(context, "tavern")
	if intel_port.is_empty():
		return ""
	context.state.world()["current_port_id"] = intel_port
	var discovered: Array = context.state.world().get("discovered_ports", [])
	if not discovered.has(intel_port):
		discovered.append(intel_port)
	if discovered.size() < 2:
		for neighbour in MapOps.neighbors(context.state.world(), intel_port):
			if not discovered.has(neighbour):
				discovered.append(neighbour)
				break
	context.state.world()["discovered_ports"] = discovered
	var refresh := context.commands.execute(&"intel.refresh", {})
	assert_true(bool(refresh["ok"]), "price-intel refresh succeeds: %s" % str(refresh))
	return intel_port


func test_intel_view_builds_port_comparison_matrix() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": 8383})
	var intel_port := _refresh_intel(context)
	assert_true(not intel_port.is_empty(), "map contains a tavern harbour")
	var result := context.queries.execute(&"intel.view")
	assert_true(bool(result["ok"]), "intel view succeeds")
	var data: Dictionary = result["data"]
	var columns: Array = data["columns"]
	var rows: Array = data["rows"]
	assert_true(columns.size() >= 2, "matrix has the current port plus at least one more column")
	assert_eq(String(columns[0].get("port_id", "")), intel_port, "current port leads the column order")
	assert_true(bool(columns[0].get("is_current", false)), "first column is marked current")
	assert_true(bool(columns[0].get("discovered", false)), "current port is discovered")
	assert_true(rows.size() >= 8, "matrix rows cover the ordinary goods assortment")
	assert_eq(int(data["column_count"]), columns.size(), "column_count matches columns")
	assert_eq(int(data["row_count"]), rows.size(), "row_count matches rows")

	var masked_count := 0
	var masked_seen := false
	var order_ok := true
	for row in rows:
		assert_eq(Array(row.get("cells", [])).size(), columns.size(), "each row has one cell per column")
	for column in columns:
		if not bool(column.get("discovered", false)):
			masked_count += 1
			masked_seen = true
			assert_eq(String(column.get("name_key", "")), "ui.label.unknown_port", "undiscovered column uses the unknown-port key")
			assert_false(bool(column.get("in_snapshot", false)), "undiscovered port has no snapshot row")
		elif masked_seen:
			order_ok = false
	assert_true(order_ok, "discovered columns come before masked columns")
	assert_true(masked_count >= 1, "undiscovered ports keep a masked column")

	for column in columns:
		if bool(column.get("discovered", false)):
			continue
		for row in rows:
			var cell := _cell(row.get("cells", []), String(column.get("port_id", "")))
			assert_false(bool(cell.get("known", false)), "masked cell is unknown: %s" % String(row.get("item_id", "")))
			assert_eq(int(cell.get("buy_price", 0)), -1, "masked buy price is -1")
			assert_eq(int(cell.get("sell_price", 0)), -1, "masked sell price is -1")

	var other := ""
	for column in columns:
		if bool(column.get("discovered", false)) and not bool(column.get("is_current", false)):
			other = String(column.get("port_id", ""))
			break
	assert_true(not other.is_empty(), "snapshot also covers another discovered port")
	var snapshot := IntelService.get_snapshot(context.state)
	assert_true(not snapshot.is_empty(), "snapshot is stored")
	var snap_rows := {}
	for port_report in snapshot.get("ports", []):
		if String(port_report.get("port_id", "")) == other:
			for snap_row in port_report.get("market", []):
				snap_rows[String(snap_row.get("item_id", ""))] = snap_row
	assert_true(snap_rows.size() >= 8, "snapshot covers the other port market")
	var compared := 0
	for raw_item_id in snap_rows.keys():
		var snap_row: Dictionary = snap_rows[raw_item_id]
		assert_true(snap_row.has("trend_percent"), "snapshot row exposes trend_percent: %s" % raw_item_id)
		if bool(snap_row.get("is_supply", false)):
			continue
		var row := _row(rows, String(raw_item_id))
		assert_true(not row.is_empty(), "snapshot commodity is a matrix row: %s" % raw_item_id)
		var cell := _cell(row.get("cells", []), other)
		assert_true(bool(cell.get("known", false)), "snapshot cell is known: %s" % raw_item_id)
		var expected_buy := int(floor(float(snap_row.get("price", 0)) * MarketOps.DEFAULT_TRADE_MARGIN))
		var expected_sell := int(round(float(snap_row.get("price", 0)))) if bool(snap_row.get("buyable", true)) else -1
		assert_eq(int(cell.get("buy_price", 0)), expected_buy, "snapshot buy price matches MarketOps: %s" % raw_item_id)
		assert_eq(int(cell.get("sell_price", 0)), expected_sell, "snapshot sell price matches MarketOps: %s" % raw_item_id)
		compared += 1
	assert_true(compared >= 8, "ordinary snapshot commodities were compared")

	var live_market := MarketOps.market_for(context.state, intel_port)
	var live_item := ""
	for raw_item_id in live_market.keys():
		if not bool(live_market[raw_item_id].get("is_supply", false)):
			live_item = String(raw_item_id)
			break
	assert_true(not live_item.is_empty(), "current port has an ordinary good")
	var live_entry: Dictionary = live_market[live_item]
	var live_cell := _cell(_row(rows, live_item).get("cells", []), intel_port)
	var live_buy := int(floor(float(live_entry.get("price", 0)) * MarketOps.DEFAULT_TRADE_MARGIN))
	var live_sell := int(round(float(live_entry.get("price", 0)))) if bool(live_entry.get("buyable", true)) else -1
	assert_true(bool(live_cell.get("known", false)), "current column cell is known")
	assert_eq(int(live_cell.get("buy_price", 0)), live_buy, "current column uses the live market buy price")
	assert_eq(int(live_cell.get("sell_price", 0)), live_sell, "current column uses the live market sell price")

	var table = SNIntelTableScript.new()
	table.bind(columns, rows, intel_port, func(key: String) -> String: return key)
	var texts := _label_texts(table)
	assert_true(texts.size() > columns.size(), "real view model binds into the table")
	assert_contains(texts, "？", "masked columns render the unknown mark")
	table.free()


func test_intel_view_matrix_without_report() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": 8484})
	var result := context.queries.execute(&"intel.view")
	assert_true(bool(result["ok"]), "intel view succeeds without a report")
	var data: Dictionary = result["data"]
	assert_false(bool(data["has_report"]), "no report before refreshing")
	var columns: Array = data["columns"]
	var rows: Array = data["rows"]
	var current := context.state.current_port_id()
	assert_true(columns.size() >= 1, "matrix keeps the current port column without a report")
	assert_eq(String(columns[0].get("port_id", "")), current, "current port leads without a report")
	assert_true(bool(columns[0].get("is_current", false)), "current column is flagged")
	assert_true(rows.size() >= 8, "live market still provides rows without a report")
	for column in columns:
		if bool(column.get("is_current", false)):
			assert_eq(float(column.get("age_hours", -1.0)), 0.0, "live column has no snapshot age")
			continue
		assert_false(bool(column.get("in_snapshot", false)), "no snapshot column without a report")
		assert_eq(float(column.get("age_hours", 0.0)), -1.0, "snapshot age is -1 without a report")
	var first_row: Dictionary = rows[0]
	var cell := _cell(first_row.get("cells", []), current)
	assert_true(bool(cell.get("known", false)), "current column cell still reads the live market")
	assert_eq(Array(first_row.get("cells", [])).size(), columns.size(), "cells stay aligned with columns")


func test_intel_table_binds_headless() -> void:
	var columns: Array = [
		{"port_id": "p_current", "name_key": "port.key.current", "discovered": true, "masked": false, "is_current": true, "visited": true, "in_snapshot": true, "age_hours": 0.0},
		{"port_id": "p_known", "name_key": "port.key.known", "discovered": true, "masked": false, "is_current": false, "visited": false, "in_snapshot": true, "age_hours": 5.5},
		{"port_id": "p_unknown", "name_key": "ui.label.unknown_port", "discovered": false, "masked": true, "is_current": false, "visited": false, "in_snapshot": false, "age_hours": -1.0},
	]
	var rows: Array = [{
		"item_id": "item_a",
		"name_key": "good.key.a",
		"unit_weight": 2.0,
		"ref_price": 100,
		"cells": [
			{"port_id": "p_current", "known": true, "buy_price": 95, "sell_price": 104, "trend": "up", "trend_percent": 0.125},
			{"port_id": "p_known", "known": true, "buy_price": 88, "sell_price": -1, "trend": "down", "trend_percent": -0.05},
			{"port_id": "p_unknown", "known": false, "buy_price": -1, "sell_price": -1, "trend": "", "trend_percent": 0.0},
		],
	}]
	var table = SNIntelTableScript.new()
	table.bind(columns, rows, "p_current", func(key: String) -> String: return "T:%s" % key)
	var texts := _label_texts(table)
	assert_true(texts.size() > 0, "table renders labels headlessly")
	assert_contains(texts, "T:ui.label.goods", "header uses the tr callable")
	assert_contains(texts, "T:ui.label.ref_price", "reference price header is localized")
	assert_contains(texts, "T:ui.label.unknown_port", "masked column shows the unknown-port label")
	assert_contains(texts, "95/104", "cell shows port buy/sell prices")
	assert_contains(texts, "88/-", "unavailable sell side renders a gap")
	assert_contains(texts, "？", "unknown cell renders the unknown mark")
	assert_true(_has_text_containing(texts, "+12.5%"), "rising trend renders a positive percentage")
	assert_true(_has_text_containing(texts, "-5.0%"), "falling trend renders a negative percentage")
	assert_true(_has_text_containing(texts, "T:ui.intel.legend_cell"), "legend cell key uses tr")
	assert_true(_has_text_containing(texts, "T:ui.intel.legend_gap"), "legend gap key uses tr")
	assert_true(_has_text_containing(texts, "T:ui.intel.legend_trend"), "legend trend key uses tr")
	table.bind([], [], "", Callable())
	assert_true(table.get_child_count() >= 1, "rebinding empty data keeps the container")
	table.free()


## The localization value for ui.intel.col_age is a format string, not a prefix.
func test_intel_table_formats_snapshot_age_with_tr_template() -> void:
	var columns: Array = [
		{"port_id": "p_current", "name_key": "port.key.current", "discovered": true, "masked": false, "is_current": true, "visited": true, "in_snapshot": true, "age_hours": 0.0},
		{"port_id": "p_known", "name_key": "port.key.known", "discovered": true, "masked": false, "is_current": false, "visited": false, "in_snapshot": true, "age_hours": 5.5},
	]
	var rows: Array = [{
		"item_id": "item_a",
		"name_key": "good.key.a",
		"unit_weight": 2.0,
		"ref_price": 100,
		"cells": [
			{"port_id": "p_current", "known": true, "buy_price": 95, "sell_price": 104, "trend": "stable", "trend_percent": 0.0},
			{"port_id": "p_known", "known": true, "buy_price": 88, "sell_price": 92, "trend": "up", "trend_percent": 0.01},
		],
	}]
	var table = SNIntelTableScript.new()
	var tr_stub := func(key: String) -> String:
		if key == "ui.intel.col_age":
			return "Snapshot %s h old"
		return key
	table.bind(columns, rows, "p_current", tr_stub)
	var texts := _label_texts(table)
	assert_true(_has_text_containing(texts, "Snapshot 5.5 h old"), "age uses the tr format string")
	assert_false(_has_text_containing(texts, "Snapshot %s"), "format placeholder is substituted")
	assert_false(_has_text_containing(texts, "ui.intel.col_age"), "age key is not shown raw")
	table.free()
