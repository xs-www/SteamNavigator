class_name ShipyardViewQuery
extends RefCounted
## Shipyard ViewModel: current modules, transit modules, port warehouse, craft
## recipes, open craft orders, wait options and every purchasable module with the
## same blocker rules as ship.install_module / ship.craft_module. New arrays are
## always present so the UI can render them even without a run or outside a shipyard.
## 4.5.5：剧情期间（`StoryService.module_filter`）购买 / 打造 / 仓库候选按 Core
## `unlocked_modules` 裁剪；当前已装模块与当前槽位仍完整输出，保证可以卸下。

const SLOT_VIEW_DEFS := [
	{"slot": "hull", "category": "hulls", "instance": "hull", "key": "hull_id"},
	{"slot": "boiler", "category": "boiler", "instance": "boiler", "key": "boiler_id"},
	{"slot": "navigation_module", "category": "utility", "instance": "navigation", "key": "navigation_module_id"},
	{"slot": "safety_module", "category": "utility", "instance": "safety", "key": "safety_module_id"},
	{"slot": "passenger_cabin", "category": "cabin", "instance": "cabin", "key": "passenger_cabin_id"},
]


static func execute(_params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.ok(_empty_view())
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var at_port := state.is_at_port()
	var port_id := state.current_port_id()
	var port_data := MapOps.port(state.world(), port_id)
	var has_shipyard := MapOps.has_facility(port_data, "shipyard")
	WarehouseOps.ensure_structure(state)
	CraftOps.ensure_orders(state)
	var ship := state.ship()
	var hull := hub.get_by_id(ContentTypes.HULL, String(ship.get("hull_id", "")))
	var stats := ShipOps.stats(hub, ship)
	var installed_ids := ShipOps.all_installed_module_ids(ship)

	var current_modules := _current_modules(hub, state, ship)
	var transit_rows := _transit_rows(hub, ship)
	var warehouse_data := _warehouse_data(hub, state, port_id, has_shipyard, at_port)
	var craft_rows := _craft_rows(hub, state, at_port, has_shipyard)
	var order_rows := _order_rows(hub, state, port_id)
	# 4.5.5：剧情进行中时船厂只露出 Core `unlocked_modules`（第三港只卖小型客舱）；
	# 已装模块 / 当前库存仍可卸下查看，其余购买 / 打造 / 仓库安装候选隐藏。
	var module_filter := StoryService.module_filter(state, hub)
	if bool(module_filter.get("active", false)):
		var allowed: Array = module_filter.get("items", [])
		warehouse_data["modules"] = _filter_module_rows(warehouse_data.get("modules", []), allowed)
		craft_rows = _filter_module_rows(craft_rows, allowed)

	var candidates: Array = []
	for module in ShipOps.installable_definitions(hub):
		if bool(module_filter.get("active", false)) \
				and not Array(module_filter.get("items", [])).has(module.id):
			continue
		var category := "hulls" if module.content_type == ContentTypes.HULL else ModuleOps.category_of(module)
		var blockers := ShipOps.install_blockers(hub, state, module.id)
		if not has_shipyard:
			blockers.push_front("no_shipyard")
		if not at_port:
			blockers.push_front("not_at_port")
		var installed := installed_ids.has(module.id)
		if installed:
			blockers.push_front("already_installed")
		candidates.append({
			"content_type": String(module.content_type),
			"category": category,
			"module_id": module.id,
			"name_key": module.name_key,
			"description_key": module.description_key,
			"price": int(round(float(module.data.get("purchase_price", 0.0)))),
			"weight": float(module.data.get("weight", 0.0)),
			"tier": int(module.data.get("tier", 1)),
			"installed": installed,
			"blockers": blockers,
			"can_install": blockers.is_empty(),
			"will_replace": _will_replace(hub, ship, module),
			"unlock_template_id": ShipOps.unlock_contract_id(hub, module.id),
			"craftable": CraftOps.craftable(hub, module.id),
			"money_only": CraftOps.money_only(hub, module.id),
			"craft_blockers": CraftOps.craft_blockers(hub, state, module.id),
			"effect": module.data.duplicate(true),
		})

	return Result.ok({
		"has_run": true,
		"at_port": at_port,
		"has_shipyard": has_shipyard,
		"port_id": port_id,
		"port_name_key": String(port_data.get("name_key", port_id)),
		"money": state.money(),
		"ship": {
			"hull_id": String(ship.get("hull_id", "")),
			"hull_tier": int(stats.get("hull_tier", 1)),
			"hull_model_key": String(hull.information.get("model", "")) if hull != null else "",
			"hull_model_path": _asset_path(context, hull.asset_uri("model")) if hull != null else "",
			"visual": ShipVisualPlan.resolve(hub, context.assets, ship),
			"boiler_id": String(ship.get("boiler_id", "")),
			"modules": current_modules,
			"transit_modules": transit_rows,
			"transit_weight": WarehouseOps.transit_module_weight(hub, ship),
			"durability": float(ship.get("durability", 0.0)),
			"max_durability": float(stats.get("max_durability", 0.0)),
			"total_weight": ShipOps.total_weight(hub, state),
			"max_weight": ShipOps.max_weight(hub, ship),
			"cargo_slots": int(hull.data.get("cargo_slots", 0)) if hull != null else 0,
			"cargo_used": ShipOps.cargo_module_ids(ship).size(),
			"cabin_slots": int(hull.data.get("cabin_slots", 0)) if hull != null else 0,
			"cabin_used": 0 if String(ship.get("passenger_cabin_id", "")).is_empty() else 1,
			"navigation_occupied": not String(ship.get("navigation_module_id", "")).is_empty(),
			"safety_occupied": not String(ship.get("safety_module_id", "")).is_empty(),
			"cargo_capacity": ShipOps.cargo_capacity(hub, ship),
			"passenger_capacity": ShipOps.passenger_capacity(hub, ship),
			"module_damage_points": ShipOps.module_damage_points(hub, ship),
			"worst_module_condition": ShipModules.worst_condition(ship),
			"damaged_modules": ShipModules.damaged_rows(ship).size(),
			"disabled_modules": _disabled_module_count(ship),
		},
		"warehouse": warehouse_data,
		"craft": craft_rows,
		"orders": order_rows,
		"wait_options": PortCommands.WAIT_OPTIONS.duplicate(),
		"candidates": candidates,
	})


## Keeps only rows whose `module_id` is in the story's unlocked-module set.
static func _filter_module_rows(rows: Array, allowed: Array) -> Array:
	var result: Array = []
	for row in rows:
		if row is Dictionary and allowed.has(String((row as Dictionary).get("module_id", ""))):
			result.append(row)
	return result


static func _empty_view() -> Dictionary:
	return {
		"has_run": false,
		"at_port": false,
		"has_shipyard": false,
		"port_id": "",
		"port_name_key": "",
		"money": 0,
		"ship": {
			"hull_id": "",
			"hull_tier": 1,
			"hull_model_key": "",
			"hull_model_path": "",
			"visual": ShipVisualPlan.empty(),
			"boiler_id": "",
			"modules": [],
			"transit_modules": [],
			"transit_weight": 0.0,
			"durability": 0.0,
			"max_durability": 0.0,
			"total_weight": 0.0,
			"max_weight": 0.0,
			"cargo_slots": 0,
			"cargo_used": 0,
			"cabin_slots": 0,
			"cabin_used": 0,
			"navigation_occupied": false,
			"safety_occupied": false,
			"cargo_capacity": 0.0,
			"passenger_capacity": 0,
			"module_damage_points": 0.0,
			"worst_module_condition": 1.0,
			"damaged_modules": 0,
			"disabled_modules": 0,
		},
		"warehouse": {"port_id": "", "modules": [], "materials": []},
		"craft": [],
		"orders": [],
		"wait_options": PortCommands.WAIT_OPTIONS.duplicate(),
		"candidates": [],
	}


static func _current_modules(hub: RegistryHub, state: GameState, ship: Dictionary) -> Array:
	var rows: Array = []
	for slot_def in SLOT_VIEW_DEFS:
		var module_id := String(ship.get(String(slot_def["key"]), ""))
		if module_id.is_empty():
			continue
		var is_hull: bool = String(slot_def["slot"]) == "hull"
		var module := hub.get_by_id(ContentTypes.HULL, module_id) if is_hull else ModuleOps.get_by_id(hub, module_id)
		var category := "hulls" if is_hull else ModuleOps.category_of(module)
		var content_type: String = "hulls" if is_hull else String(module.content_type) if module != null else ""
		var instance_slot := String(slot_def["instance"])
		var uninstall_blockers := ShipOps.uninstall_blockers(hub, state, module_id)
		var condition := ShipModules.condition(ship, instance_slot, 0) if not is_hull else 1.0
		rows.append({
			"content_type": content_type,
			"category": category,
			"slot": instance_slot,
			"slot_key": String(slot_def["slot"]),
			"index": 0,
			"module_id": module_id,
			"name_key": module.name_key if module != null else module_id,
			"description_key": module.description_key if module != null else module_id,
			"price": int(round(float(module.data.get("purchase_price", 0.0)))) if module != null else 0,
			"weight": float(module.data.get("weight", 0.0)) if module != null else 0.0,
			"tier": int(module.data.get("tier", 1)) if module != null else 1,
			"effect": module.data.duplicate(true) if module != null else {},
			"condition": condition,
			"disabled": condition <= 0.0,
			"can_uninstall": uninstall_blockers.is_empty(),
			"uninstall_blockers": uninstall_blockers,
		})
	for index in ShipOps.cargo_module_ids(ship).size():
		var cargo_id := ShipOps.cargo_module_ids(ship)[index]
		var cargo := ModuleOps.get_by_id(hub, cargo_id)
		var cargo_uninstall := ShipOps.uninstall_blockers(hub, state, cargo_id)
		var cargo_condition := ShipModules.condition(ship, "cargo", index)
		rows.append({
			"content_type": String(cargo.content_type) if cargo != null else "",
			"category": "cargo",
			"slot": "cargo",
			"slot_key": "cargo_modules",
			"index": index,
			"module_id": cargo_id,
			"name_key": cargo.name_key if cargo != null else cargo_id,
			"description_key": cargo.description_key if cargo != null else cargo_id,
			"price": int(round(float(cargo.data.get("purchase_price", 0.0)))) if cargo != null else 0,
			"weight": float(cargo.data.get("weight", 0.0)) if cargo != null else 0.0,
			"tier": int(cargo.data.get("tier", 1)) if cargo != null else 1,
			"effect": cargo.data.duplicate(true) if cargo != null else {},
			"condition": cargo_condition,
			"disabled": cargo_condition <= 0.0,
			"can_uninstall": cargo_uninstall.is_empty(),
			"uninstall_blockers": cargo_uninstall,
		})
	return rows


static func _asset_path(context, uri: String) -> String:
	if uri.is_empty() or context == null:
		return ""
	if context.assets.has(uri):
		return context.assets.resolve(uri)
	return ""


static func _disabled_module_count(ship: Dictionary) -> int:
	var count := 0
	for row in ShipModules.installed_rows(ship):
		if bool(row["disabled"]):
			count += 1
	return count


static func _category_for(definition: ContentDefinition) -> String:
	if definition == null:
		return ""
	return "hulls" if definition.content_type == ContentTypes.HULL else ModuleOps.category_of(definition)


static func _transit_rows(hub: RegistryHub, ship: Dictionary) -> Array:
	var rows: Array = []
	var transit := WarehouseOps.transit_modules(ship)
	for raw_module_id in transit.keys():
		var module_id := String(raw_module_id)
		var qty := int(transit[raw_module_id])
		if qty <= 0:
			continue
		var module := ShipOps.find_installable(hub, module_id)
		var unit_weight := float(module.data.get("weight", 0.0)) if module != null else 0.0
		rows.append({
			"module_id": module_id,
			"name_key": module.name_key if module != null else module_id,
			"qty": qty,
			"weight": unit_weight,
			"total_weight": unit_weight * float(qty),
			"content_type": String(module.content_type) if module != null else "",
			"category": _category_for(module),
		})
	return rows


static func _warehouse_data(hub: RegistryHub, state: GameState, port_id: String, has_shipyard: bool, at_port: bool) -> Dictionary:
	var warehouse := WarehouseOps.warehouse(state, port_id)
	var module_rows: Array = []
	var modules: Variant = warehouse.get("modules", null)
	if modules is Dictionary:
		for raw_module_id in modules.keys():
			var module_id := String(raw_module_id)
			var qty := int(modules[raw_module_id])
			if qty <= 0:
				continue
			var module := ShipOps.find_installable(hub, module_id)
			var blockers := ShipOps.install_blockers(hub, state, module_id, "warehouse")
			if not has_shipyard:
				blockers.push_front("no_shipyard")
			if not at_port:
				blockers.push_front("not_at_port")
			module_rows.append({
				"content_type": String(module.content_type) if module != null else "",
				"category": _category_for(module),
				"module_id": module_id,
				"name_key": module.name_key if module != null else module_id,
				"qty": qty,
				"weight": float(module.data.get("weight", 0.0)) if module != null else 0.0,
				"can_install": blockers.is_empty(),
				"blockers": blockers,
			})
	var material_rows: Array = []
	var materials: Variant = warehouse.get("materials", null)
	if materials is Dictionary:
		for raw_item_id in materials.keys():
			var item_id := String(raw_item_id)
			var amount := int(materials[raw_item_id])
			if amount <= 0:
				continue
			var item := ShipOps.item_definition(hub, item_id)
			material_rows.append({
				"item_id": item_id,
				"name_key": item.name_key if item != null else item_id,
				"amount": amount,
				"unit_weight": float(item.data.get("unit_weight", 0.0)) if item != null else 0.0,
			})
	return {
		"port_id": port_id,
		"modules": module_rows,
		"materials": material_rows,
	}


static func _craft_rows(hub: RegistryHub, state: GameState, at_port: bool, has_shipyard: bool) -> Array:
	var rows: Array = []
	for module in ShipOps.installable_definitions(hub):
		if not CraftOps.is_craftable_definition(module):
			continue
		if not CraftOps.craftable(hub, module.id):
			continue
		var blockers := CraftOps.craft_blockers(hub, state, module.id)
		if not has_shipyard:
			blockers.push_front("no_shipyard")
		if not at_port:
			blockers.push_front("not_at_port")
		var category := "hulls" if module.content_type == ContentTypes.HULL else ModuleOps.category_of(module)
		rows.append({
			"content_type": String(module.content_type),
			"category": category,
			"module_id": module.id,
			"name_key": module.name_key,
			"description_key": module.description_key,
			"tier": int(module.data.get("tier", 1)),
			"weight": float(module.data.get("weight", 0.0)),
			"craft_time_hours": CraftOps.craft_time(hub, module.id),
			"craft_cost": CraftOps.craft_cost(hub, module.id),
			"money_only": CraftOps.money_only(hub, module.id),
			"materials": CraftOps.material_plan(state, hub, state.current_port_id(), module.id),
			"unlocked": not ShipOps.locked_by_contract(hub, state, module.id),
			"can_craft": blockers.is_empty(),
			"blockers": blockers,
		})
	return rows


## Open craft orders (all ports), with a live remaining-hours countdown.
static func _order_rows(hub: RegistryHub, state: GameState, current_port_id: String) -> Array:
	var rows: Array = []
	var now := state.now()
	for order in CraftOps.orders(state):
		if not (order is Dictionary):
			continue
		var module_id := String(order.get("module_id", ""))
		var module := ShipOps.find_installable(hub, module_id)
		var port_id := String(order.get("port_id", ""))
		var ready_at := float(order.get("ready_at", 0.0))
		rows.append({
			"order_id": String(order.get("order_id", "")),
			"module_id": module_id,
			"name_key": module.name_key if module != null else module_id,
			"content_type": String(order.get("content_type", "")),
			"port_id": port_id,
			"port_name_key": MapOps.port_display_key(state.world(), port_id),
			"placed_at": float(order.get("placed_at", 0.0)),
			"ready_at": ready_at,
			"remaining_hours": maxf(0.0, ready_at - now),
			"at_current_port": port_id == current_port_id,
		})
	return rows


## Module that the purchase candidate would move into the current-port warehouse.
static func _will_replace(hub: RegistryHub, ship: Dictionary, module: ContentDefinition) -> String:
	var current_id := ""
	if module.content_type == ContentTypes.HULL:
		current_id = String(ship.get("hull_id", ""))
	elif ModuleOps.category_of(module) == "cargo":
		# Cargo candidates fill a free slot; the caller names a replace target explicitly.
		return ""
	else:
		var slot := ModuleOps.slot_for(module, ship)
		current_id = String(ship.get(ModuleOps.ship_slot_key(slot), ""))
	if current_id == module.id:
		return ""
	return current_id
