class_name IntelViewQuery
extends RefCounted
## Full intelligence ViewModel: snapshot age, a commodity x port comparison
## matrix and NPC prediction ranges.
##
## The matrix keeps one column per port. The current port is always the first
## column and reads the live market; every other discovered port reads the
## frozen intelligence snapshot. Undiscovered ports stay as masked columns
## ("ui.label.unknown_port" + "?") so the player can still see that unexplored
## ports exist.

const UNKNOWN_PORT_KEY := "ui.label.unknown_port"


static func execute(_params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.ok({
			"has_run": false,
			"has_report": false,
			"columns": [],
			"rows": [],
		})
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var world := state.world()
	var current_port := state.current_port_id()
	var snapshot := IntelService.get_snapshot(state)
	var port_data := MapOps.port(world, current_port)
	var has_tavern_facility := MapOps.has_tavern(port_data)
	var profile := _profile(context)
	var cost := int(profile.get("intel_cost", 25))
	var has_report := not snapshot.is_empty()
	var age_hours := IntelService.snapshot_age(state)
	var snapshot_ports := _snapshot_index(snapshot)
	var columns := _columns(state, world, current_port, snapshot_ports, age_hours)
	var rows := _rows(state, hub, current_port, columns, snapshot_ports)
	var ports: Array = []
	if has_report:
		for port_report in snapshot.get("ports", []):
			if not (port_report is Dictionary):
				continue
			var copy: Dictionary = port_report.duplicate(true)
			for row in copy.get("market", []):
				if row is Dictionary:
					var definition := ShipOps.item_definition(hub, String(row.get("item_id", "")))
					row["item_name_key"] = definition.name_key if definition != null else String(row.get("item_id", ""))
			ports.append(copy)
	var npcs: Array = []
	if has_report:
		for npc_report in snapshot.get("npcs", []):
			if not (npc_report is Dictionary):
				continue
			var copy: Dictionary = npc_report.duplicate(true)
			var definition := ShipOps.item_definition(hub, String(copy.get("item_id", "")))
			copy["item_name_key"] = definition.name_key if definition != null else String(copy.get("item_id", ""))
			copy["action_label_key"] = "intel.action.%s" % String(copy.get("action", "deliver"))
			npcs.append(copy)
	return Result.ok({
		"has_run": true,
		"has_report": has_report,
		"generated_at": float(snapshot.get("generated_at", -1.0)),
		"generated_label": String(snapshot.get("generated_label", "")),
		"age_hours": age_hours,
		"current_port_id": current_port,
		"current_port_name_key": MapOps.port_display_key(world, current_port),
		"columns": columns,
		"rows": rows,
		"column_count": columns.size(),
		"row_count": rows.size(),
		"ports": ports,
		"npcs": npcs,
		"port_count": ports.size(),
		"npc_count": npcs.size(),
		"discovered_port_count": Array(world.get("discovered_ports", [])).size(),
		"has_tavern_facility": has_tavern_facility,
		# 4.5.4：旧字段名保留给旧调用方 / 存档 UI 测试，语义同 `has_tavern_facility`。
		"has_intel_facility": has_tavern_facility,
		"can_refresh": has_tavern_facility and state.is_at_port() and state.money() >= cost,
		"cost": cost,
		"money": state.money(),
	})


## port_id -> {item_id: snapshot market row}, supply commodities excluded.
static func _snapshot_index(snapshot: Dictionary) -> Dictionary:
	var index := {}
	if not snapshot.has("ports"):
		return index
	for port_report in snapshot.get("ports", []):
		if not (port_report is Dictionary):
			continue
		var port_id := String(port_report.get("port_id", ""))
		if port_id.is_empty():
			continue
		var rows := {}
		for row in port_report.get("market", []):
			if not (row is Dictionary) or bool(row.get("is_supply", false)):
				continue
			rows[String(row.get("item_id", ""))] = row
		index[port_id] = rows
	return index


## Current port first, then discovered ports sorted by port_id, then masked
## undiscovered ports sorted by port_id.
static func _columns(state: GameState, world: Dictionary, current_port: String, snapshot_ports: Dictionary, age_hours: float) -> Array:
	var discovered: Array[String] = []
	var unknown_ports: Array[String] = []
	for raw_port_id in MapOps.ports(world).keys():
		var port_id := String(raw_port_id)
		if port_id == current_port:
			continue
		if MapOps.is_discovered(state, port_id):
			discovered.append(port_id)
		else:
			unknown_ports.append(port_id)
	discovered.sort()
	unknown_ports.sort()
	var ordered: Array[String] = []
	if not current_port.is_empty():
		ordered.append(current_port)
	for port_id in discovered:
		ordered.append(port_id)
	for port_id in unknown_ports:
		ordered.append(port_id)
	var columns: Array = []
	for port_id in ordered:
		columns.append(_column(state, world, port_id, current_port, snapshot_ports, age_hours))
	return columns


static func _column(state: GameState, world: Dictionary, port_id: String, current_port: String, snapshot_ports: Dictionary, age_hours: float) -> Dictionary:
	var is_current := port_id == current_port
	# The player is physically in the current port, so its name is never masked.
	var discovered := is_current or MapOps.is_discovered(state, port_id)
	var in_snapshot := snapshot_ports.has(port_id)
	return {
		"port_id": port_id,
		"name_key": MapOps.port_display_key(world, port_id) if discovered else UNKNOWN_PORT_KEY,
		"discovered": discovered,
		"masked": not discovered,
		"is_current": is_current,
		"visited": MapOps.is_visited(state, port_id),
		"in_snapshot": in_snapshot,
		"age_hours": 0.0 if is_current else (age_hours if in_snapshot else -1.0),
	}


## Row universe = live ordinary goods at the current port U ordinary goods that
## appear in the snapshot, sorted by item_id. Supply commodities are excluded:
## they have their own page and are not part of the trade comparison.
static func _rows(state: GameState, hub: RegistryHub, current_port: String, columns: Array, snapshot_ports: Dictionary) -> Array:
	var live_market: Dictionary = MarketOps.market_for(state, current_port) if not current_port.is_empty() else {}
	var item_ids := {}
	for raw_item_id in live_market.keys():
		var entry: Variant = live_market[raw_item_id]
		if entry is Dictionary and not bool(entry.get("is_supply", false)):
			item_ids[String(raw_item_id)] = true
	for raw_port_id in snapshot_ports.keys():
		for raw_item_id in snapshot_ports[raw_port_id].keys():
			item_ids[String(raw_item_id)] = true
	var ordered: Array = item_ids.keys()
	ordered.sort()
	var rows: Array = []
	for raw_item_id in ordered:
		var item_id := String(raw_item_id)
		var definition := ShipOps.item_definition(hub, item_id)
		var cells: Array = []
		for column in columns:
			if column is Dictionary:
				cells.append(_cell(state, column, snapshot_ports, item_id))
		rows.append({
			"item_id": item_id,
			"name_key": definition.name_key if definition != null else item_id,
			"unit_weight": float(definition.data.get("unit_weight", 0.0)) if definition != null else 0.0,
			"ref_price": _ref_price(definition, live_market, item_id),
			"cells": cells,
		})
	return rows


## One port x commodity cell. `buy_price` is what the port pays the player
## (MarketOps.sell: floor(price * DEFAULT_TRADE_MARGIN)); `sell_price` is what
## the player pays the port (MarketOps.buy: round(price), only when the port
## actually lists the good). -1 means "not available here".
static func _cell(state: GameState, column: Dictionary, snapshot_ports: Dictionary, item_id: String) -> Dictionary:
	var port_id := String(column.get("port_id", ""))
	var known := false
	var buy_price := -1
	var sell_price := -1
	var trend := ""
	var trend_percent := 0.0
	if bool(column.get("is_current", false)):
		var entry: Dictionary = MarketOps.entry_for(state, port_id, item_id)
		if not entry.is_empty():
			known = true
			var price := float(entry.get("price", 0.0))
			buy_price = int(floor(price * MarketOps.DEFAULT_TRADE_MARGIN)) if price > 0.0 else -1
			sell_price = int(round(price)) if price > 0.0 and bool(entry.get("buyable", true)) else -1
			trend = _trend(entry)
			trend_percent = _trend_percent(entry)
	elif bool(column.get("in_snapshot", false)):
		var port_rows: Dictionary = snapshot_ports.get(port_id, {})
		var row: Variant = port_rows.get(item_id, {})
		if row is Dictionary and not row.is_empty():
			known = true
			var price := float(row.get("price", 0.0))
			buy_price = int(floor(price * MarketOps.DEFAULT_TRADE_MARGIN)) if price > 0.0 else -1
			sell_price = int(round(price)) if price > 0.0 and bool(row.get("buyable", true)) else -1
			trend = String(row.get("trend", ""))
			trend_percent = float(row.get("trend_percent", 0.0))
	return {
		"port_id": port_id,
		"known": known,
		"buy_price": buy_price,
		"sell_price": sell_price,
		"trend": trend,
		"trend_percent": trend_percent,
	}


static func _ref_price(definition: ContentDefinition, live_market: Dictionary, item_id: String) -> float:
	if definition != null and definition.data.has("base_price"):
		return float(definition.data.get("base_price", 0.0))
	var entry: Variant = live_market.get(item_id, {})
	if entry is Dictionary and entry.has("base_price"):
		return float(entry.get("base_price", 0.0))
	return 0.0


static func _profile(context) -> Dictionary:
	var state: GameState = context.state
	var profile_id := String(state.world().get("map_profile_id", ""))
	var profile: ContentDefinition = context.registries.get_by_id(ContentTypes.MAP_PROFILE, profile_id)
	return profile.data if profile != null else {}


static func _trend(entry: Dictionary) -> String:
	var stock := float(entry.get("stock", 0.0))
	var base_stock := maxf(1.0, float(entry.get("base_stock", 1.0)))
	if stock < base_stock * 0.85:
		return "up"
	if stock > base_stock * 1.15:
		return "down"
	return "stable"


static func _trend_percent(entry: Dictionary) -> float:
	var history: Array = entry.get("price_history", [])
	var recent: Array = history.slice(maxi(0, history.size() - 8), history.size())
	if recent.size() >= 2 and float(recent[0]) > 0.0:
		return (float(recent[recent.size() - 1]) - float(recent[0])) / float(recent[0])
	return 0.0