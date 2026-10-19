class_name PortViewQuery
extends RefCounted

static func execute(_params: Dictionary, context) -> Dictionary:
	var state: GameState = context.state
	if not context.has_run():
		return Result.ok({"has_run": false})
	var hub: RegistryHub = context.registries
	var world := state.world()
	var current_port := state.current_port_id()
	var port_data := MapOps.port(world, current_port)
	var diorama_value: Variant = port_data.get("diorama", {})
	var diorama: Dictionary = diorama_value if diorama_value is Dictionary else {}
	# Older saves/world snapshots predate the stored `diorama` block; fall back to
	# the archetype definition so the stage still gets its town kit.
	if diorama.is_empty():
		var archetype := hub.get_by_id(
			ContentTypes.PORT_ARCHETYPE,
			String(port_data.get("archetype_id", ""))
		)
		if archetype != null:
			var archetype_diorama: Variant = archetype.data.get("diorama", {})
			if archetype_diorama is Dictionary:
				diorama = (archetype_diorama as Dictionary).duplicate(true)
	var ship := state.ship()
	var stats := ShipOps.stats(hub, ship)
	var voyage: Variant = state.data.get("voyage", null)

	var market_rows: Array = []
	var market := MarketOps.market_for(state, current_port)
	var hull := hub.get_by_id(ContentTypes.HULL, String(ship.get("hull_id", "")))
	var item_ids: Array = market.keys()
	item_ids.sort()
	for item_id in item_ids:
		var entry: Dictionary = market[item_id]
		if bool(entry.get("is_supply", false)):
			continue
		var definition := ShipOps.item_definition(hub, String(item_id))
		if definition == null:
			continue
		var history: Array = entry.get("price_history", [])
		var recent_prices: Array = history.slice(maxi(0, history.size() - 8), history.size())
		var trend_percent := 0.0
		if recent_prices.size() >= 2 and float(recent_prices[0]) > 0.0:
			trend_percent = (float(recent_prices[recent_prices.size() - 1]) - float(recent_prices[0])) / float(recent_prices[0])
		market_rows.append({
			"item_id": String(item_id),
			"name_key": definition.name_key,
			"unit_weight": float(definition.data.get("unit_weight", 0.0)),
			"price": int(round(float(entry.get("price", 0.0)))),
			"stock": int(entry.get("stock", 0)),
			"buyable": bool(entry.get("buyable", true)),
			"trend": _trend(entry),
			"trend_percent": trend_percent,
			"recent_prices": recent_prices,
			"cargo_amount": ShipOps.cargo_amount(ship, String(item_id), true),
			"sellable_amount": ShipOps.cargo_amount(ship, String(item_id), false),
			"cargo_avg_cost": ShipOps.cargo_average_cost(ship, String(item_id), false),
		})

	var destinations: Array = []
	for neighbor in MapOps.neighbors(world, current_port):
		var neighbor_data := MapOps.port(world, neighbor)
		var route := MapOps.route_between(world, current_port, neighbor)
		destinations.append({
			"port_id": neighbor,
			"name_key": MapOps.port_display_key(world, neighbor),
			"distance": float(route.get("distance", 0.0)),
			"base_risk": float(route.get("base_risk", 0.0)),
			"discovered": MapOps.is_discovered(state, neighbor),
			"visited": MapOps.is_visited(state, neighbor),
			"facilities_known": MapOps.facilities_known(state, hub, neighbor),
			"facilities": MapOps.visible_facilities(state, hub, neighbor),
		})
	destinations.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left["port_id"]) < String(right["port_id"])
	)

	var strategies: Array = []
	for strategy in hub.get_all(ContentTypes.STRATEGY):
		strategies.append({
			"id": strategy.id,
			"name_key": strategy.name_key,
			"description_key": strategy.description_key,
			"tags": Array(strategy.tags),
			"data": strategy.data.duplicate(true),
		})

	var contracts: Dictionary = state.contracts()
	var main_contract: Variant = contracts.get("main", null)
	var main_offer: Variant = contracts.get("main_offer", null)
	var active_count: int = Array(contracts.get("active", [])).size()
	var intel := IntelService.get_snapshot(state)
	var debt: Variant = state.player().get("debt", null)
	var victory: Variant = state.data.get("victory", null)
	return Result.ok({
		"has_run": true,
		"at_sea": voyage is Dictionary,
		"voyage": voyage.duplicate(true) if voyage is Dictionary else null,
		"current_port_id": current_port,
		"current_port": {
			"id": current_port,
			"name_key": String(port_data.get("name_key", current_port)),
			"description_key": String(port_data.get("description_key", "")),
			"source_mod": String(port_data.get("source_mod", "")),
			"archetype_id": String(port_data.get("archetype_id", "")),
			"banner_asset": String(port_data.get("banner_asset", "")),
			"facilities": Array(port_data.get("facilities", [])),
			"size": String(port_data.get("size", "medium")),
			"diorama": diorama.duplicate(true),
			"town_visuals": _resolved_town_visuals(
				context,
				String(port_data.get("source_mod", "")),
				diorama
			),
			"tags": Array(port_data.get("tags", [])),
			"visited": bool(port_data.get("visited", false)),
		},
		"time": state.now(),
		"time_label": ClockService.format_time(state.now()),
		"money": state.money(),
		"reputation": int(state.player().get("reputation", 0)),
		"debt": debt.duplicate(true) if debt is Dictionary else null,
		"market": market_rows,
		"destinations": destinations,
		"strategies": strategies,
		"ship": _ship_view(hub, state, stats, ship, hull, context),
		"contracts": {
			"main": _contract_view(hub, state, main_contract),
			"main_offer": _contract_view(hub, state, main_offer),
			"active": _contract_list(hub, state, contracts.get("active", [])),
			"offers": _contract_list(hub, state, contracts.get("offers", [])),
			"completed": Array(contracts.get("completed", [])),
			"next_main_sequence": int(contracts.get("next_main_sequence", 1)),
			"active_limit": ContractOps.active_limit(state),
			"active_count": active_count,
			"normal_holds": active_count,
			"main_chain_complete": VictoryService.main_chain_complete(hub, state),
			"main_done": _completed_main_count(hub, state),
			"main_total": ContractOps.templates_by_kind(hub, "main").size(),
		},
		"intelligence": {
			"generated_at": float(intel.get("generated_at", -1.0)),
			"generated_label": String(intel.get("generated_label", "")),
			"age_hours": IntelService.snapshot_age(state),
			"ports": intel.get("ports", []).size(),
			"npcs": intel.get("npcs", []).size(),
		},
		"notices": state.recent_notices(6),
		"unlocks": Array(state.player().get("unlocks", [])),
		"stats": state.stats().duplicate(true),
		"victory": {
			"achieved": victory is Dictionary and bool(victory.get("achieved", false)),
			"achieved_at": float(victory.get("achieved_at", 0.0)) if victory is Dictionary else 0.0,
			"conditions": VictoryService.conditions(hub, state),
		},
	})


## How many main-chapter templates the run has already delivered.
static func _completed_main_count(hub: RegistryHub, state: GameState) -> int:
	var completed: Array = state.contracts().get("completed", [])
	var count := 0
	for template in ContractOps.templates_by_kind(hub, "main"):
		if completed.has(template.id):
			count += 1
	return count


static func _ship_view(hub: RegistryHub, state: GameState, stats: Dictionary, ship: Dictionary, hull, context) -> Dictionary:
	var modules: Array = []
	var slots := {
		"hull": "hull_id",
		"boiler": "boiler_id",
		"navigation": "navigation_module_id",
		"safety": "safety_module_id",
		"cabin": "passenger_cabin_id",
	}
	for slot in slots.keys():
		var module_id := String(ship.get(slots[slot], ""))
		if module_id.is_empty():
			continue
		var definition := ShipOps.find_module(hub, module_id)
		modules.append({
			"slot": slot,
			"module_id": module_id,
			"name_key": definition.name_key if definition != null else module_id,
			"tier": int(definition.data.get("tier", 0)) if definition != null else 0,
		})
	for module_id in ShipOps.cargo_module_ids(ship):
		var definition := hub.get_by_id(ContentTypes.CARGO_MODULE, module_id)
		modules.append({
			"slot": "cargo",
			"module_id": module_id,
			"name_key": definition.name_key if definition != null else module_id,
			"tier": int(definition.data.get("tier", 0)) if definition != null else 0,
		})
	var cargo: Array = []
	for stack in ship.get("cargo", []):
		var definition := ShipOps.item_definition(hub, String(stack.get("item_id", "")))
		var amount := int(stack.get("amount", 0))
		var stack_cost := float(stack.get("total_cost", 0.0))
		var contract_id := String(stack.get("contract_id", ""))
		cargo.append({
			"item_id": String(stack.get("item_id", "")),
			"name_key": definition.name_key if definition != null else String(stack.get("item_id", "")),
			"amount": amount,
			"contract_id": contract_id,
			"is_contract": not contract_id.is_empty(),
			"total_cost": stack_cost,
			"average_cost": stack_cost / float(amount) if amount > 0 and contract_id.is_empty() else 0.0,
		})
	var transit_entries: Array = []
	var transit_map: Dictionary = WarehouseOps.transit_modules(ship)
	var transit_ids: Array = transit_map.keys()
	transit_ids.sort()
	for raw_module_id in transit_ids:
		var module_id := String(raw_module_id)
		var qty := int(transit_map[raw_module_id])
		if qty <= 0:
			continue
		var transit_definition := ShipOps.find_module(hub, module_id)
		transit_entries.append({
			"module_id": module_id,
			"name_key": transit_definition.name_key if transit_definition != null else module_id,
			"qty": qty,
			"weight": float(transit_definition.data.get("weight", 0.0)) if transit_definition != null else 0.0,
		})
	return {
		"hull_id": String(ship.get("hull_id", "")),
		"boiler_id": String(ship.get("boiler_id", "")),
		"modules": modules,
		"hull_model_key": String(hull.information.get("model", "")) if hull != null else "",
		"hull_model_path": _asset_path(context, hull.asset_uri("model")) if hull != null else "",
		"transit_modules": transit_entries,
		"transit_weight": WarehouseOps.transit_module_weight(hub, ship),
		"cargo": cargo,
		"cargo_cost_basis": ShipOps.cargo_total_cost(ship),
		"durability": float(ship.get("durability", 0.0)),
		"max_durability": float(stats.get("max_durability", 0.0)),
		"coal": float(ship.get("coal", 0.0)),
		"water": float(ship.get("water", 0.0)),
		"total_weight": ShipOps.total_weight(hub, state),
		"max_weight": ShipOps.max_weight(hub, ship),
		"free_weight": maxf(0.0, ShipOps.max_weight(hub, ship) - ShipOps.total_weight(hub, state)),
		"cargo_capacity": ShipOps.cargo_capacity(hub, ship),
		"cargo_used": ShipOps.cargo_used(hub, ship),
		"free_cargo_capacity": ShipOps.free_cargo_capacity(hub, ship),
		"passengers": ShipOps.passenger_count(state),
		"passenger_capacity": ShipOps.passenger_capacity(hub, ship),
		"speed": float(stats.get("speed", 0.0)),
		"coal_rate": float(stats.get("coal_rate", 0.0)),
		"water_rate": float(stats.get("water_rate", 0.0)),
		"hull_tier": int(stats.get("hull_tier", 1)),
		"engineer_id": String(ship.get("engineer_id", "")),
		"navigator_id": String(ship.get("navigator_id", "")),
		"worst_module_condition": ShipModules.worst_condition(ship),
		"damaged_modules": ShipModules.damaged_rows(ship).size(),
		"disabled_modules": _disabled_module_count(ship),
		"module_damage_points": ShipOps.module_damage_points(hub, ship),
	}


static func _disabled_module_count(ship: Dictionary) -> int:
	var count := 0
	for row in ShipModules.installed_rows(ship):
		if bool(row["disabled"]):
			count += 1
	return count


## Resolves a content asset uri (`asset://<mod>/<key>`) to the mounted physical
## path for the presentation layer. Empty when the asset is missing.
static func _asset_path(context, uri: String) -> String:
	if uri.is_empty() or context == null:
		return ""
	if context.assets.has(uri):
		return context.assets.resolve(uri)
	return ""


## Resolves the `diorama.town` slot -> asset-key map to slot -> physical path so
## the presentation layer (PortStage) only consumes ready paths. Missing keys are
## omitted; the stage then keeps its procedural blockout for that slot.
static func _resolved_town_visuals(context, source_mod: String, diorama: Dictionary) -> Dictionary:
	var result := {}
	var town_value: Variant = diorama.get("town", {})
	if not (town_value is Dictionary) or source_mod.is_empty() or context == null:
		return result
	for raw_slot in (town_value as Dictionary).keys():
		var key := String((town_value as Dictionary)[raw_slot])
		if key.is_empty():
			continue
		var logical_key := "asset://%s/%s" % [source_mod, key]
		if context.assets.has(logical_key):
			result[String(raw_slot)] = context.assets.resolve(logical_key)
	return result


static func _contract_view(hub: RegistryHub, state: GameState, contract: Variant) -> Variant:
	if not (contract is Dictionary):
		return null
	var world := state.world()
	var copy: Dictionary = contract.duplicate(true)
	var origin := String(contract.get("origin", ""))
	var destination := String(contract.get("destination", ""))
	copy["destination_name_key"] = MapOps.port_display_key(world, destination)
	copy["origin_name_key"] = MapOps.port_display_key(world, origin)
	copy["deadline_label"] = ClockService.format_time(float(contract.get("deadline", 0.0)))
	var remaining_hours := maxf(0.0, float(contract.get("deadline", 0.0)) - state.now())
	copy["remaining_hours"] = remaining_hours
	copy["remaining_label"] = _format_remaining(remaining_hours)
	var template_id := String(contract.get("template_id", ""))
	var template := hub.get_by_id(ContentTypes.CONTRACT, template_id)
	if template != null:
		copy["description_key"] = template.description_key
	var route := MapOps.route_between(world, origin, destination)
	var distance := float(route.get("distance", 0.0))
	var ship_stats := ShipOps.stats(hub, state.ship())
	var speed := maxf(1.0, float(ship_stats.get("speed", 12.0)))
	copy["estimated_hours"] = distance / speed
	copy["estimated_label"] = _format_remaining(distance / speed)
	var risk := float(route.get("base_risk", 0.0))
	copy["risk"] = "high" if risk >= 0.09 else ("medium" if risk >= 0.05 else "low")
	return copy


static func _format_remaining(hours: float) -> String:
	if hours <= 0.0:
		return "已到期"
	var days := int(hours / 24.0)
	var remainder := int(hours) % 24
	if days > 0:
		return "%d天%d时" % [days, remainder]
	return "%d时" % remainder


static func _contract_list(hub: RegistryHub, state: GameState, contracts: Variant) -> Array:
	var result: Array = []
	if not (contracts is Array):
		return result
	for contract in contracts:
		if contract is Dictionary:
			result.append(_contract_view(hub, state, contract))
	return result


static func _trend(entry: Dictionary) -> String:
	var stock := float(entry.get("stock", 0.0))
	var base_stock := maxf(1.0, float(entry.get("base_stock", 1.0)))
	if stock < base_stock * 0.85:
		return "up"
	if stock > base_stock * 1.15:
		return "down"
	return "stable"
