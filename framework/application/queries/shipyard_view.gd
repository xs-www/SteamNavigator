class_name ShipyardViewQuery
extends RefCounted
## @static-doc
## 作用：船厂只读 ViewModel；统一投影模块改装/打造/仓库、舰载武器 socket、购买/装配/库存、船体每视图蓝图线稿的已解析路径，以及槽位圆点用的蓝图锚点（`ship.slot_anchors`）。
##
## Shipyard ViewModel: current modules, transit modules, port warehouse, craft
## recipes, open craft orders, wait options and every purchasable module with the
## same blocker rules as ship.install_module / ship.craft_module. New arrays are
## always present so the UI can render them even without a run or outside a shipyard.
## `ship.blueprint_views.{side,top}` is resolved from hull `data.blueprint_views`
## through AssetService into `{image_key, path, width, height, space}`; the 2D stage
## draws them in the refit view and falls back to the generic section when absent.
## 4.5.5：剧情期间（`StoryService.module_filter`）购买 / 打造 / 仓库候选按 Core
## `unlocked_modules` 裁剪；当前已装模块与当前槽位仍完整输出，保证可以卸下。
##
## ## `ship.slot_anchors`（P2b 契约，2026-10-28）
## 把内容 `hull.data.module_slots[]` / `hull.data.compartments[]` 的
## `blueprint_position.side`（左上原点 0..1，相对 `space:"trimmed"` 侧视线稿）投影成
## UI 槽位键，供 `SNShipView` 在船体上画圆点 + 折线：
## ```
## {
##   "hull": [x, y], "boiler": [x, y], "navigation_module": [x, y],
##   "safety_module": [x, y], "passenger_cabin": [x, y],
##   "cargo_modules": [[x, y], ...]   # 按 x 从左到右，序号对应 UI 货舱槽
## }
## ```
## - `module_slots` 按 `allowed_categories` 映射（boiler/cabin/cargo），`navigation` /
##   `safety` 同属 utility，用 id 关键字区分；不依赖 id 的其它键留空。
## - `compartments` 按 `allowed_types` 映射：cabin→客舱，其余→货舱（`cargo_N` 顺序）。
## - schema 的 `module_slots.allowed_categories` 没有 `hull`，因此 `hull` 锚点默认用所有
##   已解析锚点的质心兜底（内容显式给 `id:"hull"` 的 module_slot 时优先采用）。
## - 内容没有锚点时返回**空字典**：UI 回退到面板内通用锚点，旧内容 / SDK 模板不崩。
## @end-static-doc

const WeaponOps := preload("res://framework/domain/ship/weapon_ops.gd")

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
	var weapon_sockets := _weapon_socket_rows(hub, state)
	var weapon_candidates := _weapon_candidate_rows(hub, state, at_port, has_shipyard)
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
			"blueprint_views": _blueprint_views(context, hull),
			"slot_anchors": _slot_anchors(hull),
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
			"weapon_sockets": weapon_sockets,
			"weapon_weight": WeaponOps.total_weight(hub, ship),
		},
		"warehouse": warehouse_data,
		"craft": craft_rows,
		"orders": order_rows,
		"wait_options": PortCommands.WAIT_OPTIONS.duplicate(),
		"candidates": candidates,
		"weapon_candidates": weapon_candidates,
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
			"blueprint_views": {},
			"slot_anchors": {},
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
			"weapon_sockets": [],
			"weapon_weight": 0.0,
		},
		"warehouse": {"port_id": "", "modules": [], "materials": [], "weapons": []},
		"craft": [],
		"orders": [],
		"wait_options": PortCommands.WAIT_OPTIONS.duplicate(),
		"candidates": [],
		"weapon_candidates": [],
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


## Resolves the hull's authored blueprint line-art bindings into plain paths
## that the 2D stage can load without knowing about mods or asset keys.
static func _blueprint_views(context, hull: ContentDefinition) -> Dictionary:
	var result: Dictionary = {}
	if hull == null:
		return result
	var raw: Variant = hull.data.get("blueprint_views", null)
	if not (raw is Dictionary):
		return result
	for view in ["side", "top"]:
		var entry: Variant = (raw as Dictionary).get(view, null)
		if not (entry is Dictionary):
			continue
		var key := String((entry as Dictionary).get("image", "")).strip_edges()
		if key.is_empty():
			continue
		var uri := key if key.begins_with("asset://") else "asset://%s/%s" % [hull.source_mod, key]
		var asset_path := _asset_path(context, uri)
		if asset_path.is_empty():
			continue
		result[view] = {
			"image_key": key,
			"path": asset_path,
			"width": int((entry as Dictionary).get("width", 0)),
			"height": int((entry as Dictionary).get("height", 0)),
			"space": String((entry as Dictionary).get("space", "trimmed")),
		}
	return result


## Blueprint slot anchors for the refit stage, keyed like the UI slot descriptors.
## Content driven (`hull.data.module_slots` / `compartments`); `{}` when the hull
## declares none, so `SNShipView` falls back to its generic panel anchors.
static func _slot_anchors(hull: ContentDefinition) -> Dictionary:
	if hull == null:
		return {}
	return _slot_anchors_from_data(hull.data)


## Pure data projection, split out so tests and future editors can run it on raw
## hull JSON without a ContentDefinition / registry. See the header for the shape.
static func _slot_anchors_from_data(data: Dictionary) -> Dictionary:
	var anchors: Dictionary = {}
	var cargo_points: Array = []
	var module_slots: Variant = data.get("module_slots", null)
	if module_slots is Array:
		for raw_entry in module_slots:
			if not (raw_entry is Dictionary):
				continue
			var entry: Dictionary = raw_entry
			var key := _module_slot_anchor_key(entry)
			var point := _blueprint_side_point(entry.get("blueprint_position", null))
			if key.is_empty() or point == Vector2(-1.0, -1.0):
				continue
			if key == "cargo_modules":
				cargo_points.append(point)
			elif not anchors.has(key):
				anchors[key] = [point.x, point.y]
	var compartments: Variant = data.get("compartments", null)
	if compartments is Array:
		for raw_entry in compartments:
			if not (raw_entry is Dictionary):
				continue
			var entry: Dictionary = raw_entry
			var key := _compartment_anchor_key(entry)
			var point := _blueprint_side_point(entry.get("blueprint_position", null))
			if key.is_empty() or point == Vector2(-1.0, -1.0):
				continue
			if key == "cargo_modules":
				cargo_points.append(point)
			elif not anchors.has(key):
				anchors[key] = [point.x, point.y]
	if not cargo_points.is_empty():
		cargo_points.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var rows: Array = []
		for point in cargo_points:
			rows.append([point.x, point.y])
		anchors["cargo_modules"] = rows
	if anchors.is_empty():
		return {}
	# schema has no `hull` module slot: the hull chip anchors on the centroid of
	# every other anchor (a point on the hull body) unless content declares one.
	if not anchors.has("hull"):
		var sum := Vector2.ZERO
		var count := 0
		for key in anchors.keys():
			if String(key) == "cargo_modules":
				for row in anchors[key]:
					sum += Vector2(float(row[0]), float(row[1]))
					count += 1
				continue
			var row: Array = anchors[key]
			sum += Vector2(float(row[0]), float(row[1]))
			count += 1
		if count > 0:
			anchors["hull"] = [sum.x / float(count), sum.y / float(count)]
	return anchors


## `module_slots[]` → UI slot key. Categories win; `navigation` / `safety` are both
## `utility` and are told apart by their readable id (`navigation` / `safety`).
static func _module_slot_anchor_key(entry: Dictionary) -> String:
	var slot_id := String(entry.get("id", "")).to_lower()
	var categories: Variant = entry.get("allowed_categories", [])
	var has_category := func(category: String) -> bool:
		return categories is Array and (categories as Array).has(category)
	if slot_id.contains("navigation"):
		return "navigation_module"
	if slot_id.contains("safety") or slot_id.contains("life"):
		return "safety_module"
	if slot_id.contains("hull"):
		return "hull"
	if has_category.call("boiler") or slot_id.contains("boiler"):
		return "boiler"
	if has_category.call("cabin") or slot_id.contains("cabin"):
		return "passenger_cabin"
	if has_category.call("cargo") or slot_id.contains("cargo"):
		return "cargo_modules"
	return ""


## `compartments[]` → UI slot key: cabin compartments are passenger cabins, every
## other compartment is a cargo bay (matching `cargo_slots` / `cabin_slots`).
static func _compartment_anchor_key(entry: Dictionary) -> String:
	var compartment_id := String(entry.get("id", "")).to_lower()
	var types: Variant = entry.get("allowed_types", [])
	var allows_cargo := types is Array and (types as Array).has("cargo")
	var allows_cabin := types is Array and (types as Array).has("cabin")
	if compartment_id.contains("cabin") or (allows_cabin and not allows_cargo):
		return "passenger_cabin"
	if compartment_id.contains("cargo") or allows_cargo:
		return "cargo_modules"
	if allows_cabin:
		return "passenger_cabin"
	return ""


## Reads `blueprint_position.side` as a validated 0..1 Vector2; (-1,-1) = missing.
static func _blueprint_side_point(raw_position: Variant) -> Vector2:
	if not (raw_position is Dictionary):
		return Vector2(-1.0, -1.0)
	var side: Variant = (raw_position as Dictionary).get("side", null)
	if not (side is Array) or (side as Array).size() != 2:
		return Vector2(-1.0, -1.0)
	var point: Array = side
	if not (point[0] is float or point[0] is int) or not (point[1] is float or point[1] is int):
		return Vector2(-1.0, -1.0)
	var x := float(point[0])
	var y := float(point[1])
	if not is_finite(x) or not is_finite(y):
		return Vector2(-1.0, -1.0)
	if x < 0.0 or x > 1.0 or y < 0.0 or y > 1.0:
		return Vector2(-1.0, -1.0)
	return Vector2(x, y)


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
				# C2: warehouse contents are plain items now; expose the content
				# category/flag so the 杂项 panel can label them consistently.
				"category": String(item.data.get("category", "")) if item != null else "",
				"crafting_material": bool(item.data.get("crafting_material", false)) if item != null else false,
				"tier": int(item.data.get("tier", 0)) if item != null else 0,
				"unit_weight": float(item.data.get("unit_weight", 0.0)) if item != null else 0.0,
			})
	var weapon_rows: Array = []
	var weapons: Variant = warehouse.get("weapons", null)
	if weapons is Dictionary:
		for raw_weapon_id in weapons.keys():
			var weapon_id := String(raw_weapon_id)
			var qty := int(weapons[raw_weapon_id])
			if qty <= 0:
				continue
			var weapon := WeaponOps.get_by_id(hub, weapon_id)
			var install_options: Array = []
			for raw_socket in WeaponOps.sockets(hub, state.ship()):
				if not (raw_socket is Dictionary) or not WeaponOps.accepts(raw_socket, weapon):
					continue
				var socket_name := String(raw_socket.get("name", ""))
				var blockers := WeaponOps.install_blockers(hub, state, weapon_id, socket_name, "warehouse")
				if not has_shipyard:
					blockers.push_front("no_shipyard")
				if not at_port:
					blockers.push_front("not_at_port")
				install_options.append({"socket": socket_name, "can_install": blockers.is_empty(), "blockers": blockers})
			weapon_rows.append({
				"weapon_id": weapon_id,
				"name_key": weapon.name_key if weapon != null else weapon_id,
				"qty": qty,
				"weapon_class": WeaponOps.weapon_class(weapon),
				"weight": float(weapon.data.get("weight", 0.0)) if weapon != null else 0.0,
				"install_options": install_options,
			})
	return {
		"port_id": port_id,
		"modules": module_rows,
		"materials": material_rows,
		"weapons": weapon_rows,
	}


static func _weapon_socket_rows(hub: RegistryHub, state: GameState) -> Array:
	var rows: Array = []
	var ship := state.ship()
	for raw_socket in WeaponOps.sockets(hub, ship):
		if not (raw_socket is Dictionary):
			continue
		var socket: Dictionary = raw_socket
		var socket_name := String(socket.get("name", ""))
		var weapon_id := WeaponOps.weapon_id_at(ship, socket_name)
		var weapon := WeaponOps.get_by_id(hub, weapon_id)
		rows.append({
			"socket": socket_name,
			"socket_class": String(socket.get("socket_class", "")),
			"socket_index": int(socket.get("socket_index", rows.size())),
			"blueprint": (socket.get("blueprint", {}) as Dictionary).duplicate(true),
			"weapon_id": weapon_id,
			"name_key": weapon.name_key if weapon != null else "",
			"weight": float(weapon.data.get("weight", 0.0)) if weapon != null else 0.0,
			"damage": float(weapon.data.get("damage", 0.0)) if weapon != null else 0.0,
			"can_uninstall": not weapon_id.is_empty(),
		})
	return rows


static func _weapon_candidate_rows(hub: RegistryHub, state: GameState, at_port: bool, has_shipyard: bool) -> Array:
	var rows: Array = []
	for raw_socket in WeaponOps.sockets(hub, state.ship()):
		if not (raw_socket is Dictionary):
			continue
		var socket: Dictionary = raw_socket
		var socket_name := String(socket.get("name", ""))
		for weapon in WeaponOps.all(hub):
			if not WeaponOps.accepts(socket, weapon):
				continue
			var blockers := WeaponOps.install_blockers(hub, state, weapon.id, socket_name, "purchase")
			if not has_shipyard:
				blockers.push_front("no_shipyard")
			if not at_port:
				blockers.push_front("not_at_port")
			rows.append({
				"socket": socket_name,
				"socket_class": String(socket.get("socket_class", "")),
				"weapon_id": weapon.id,
				"name_key": weapon.name_key,
				"description_key": weapon.description_key,
				"weapon_class": WeaponOps.weapon_class(weapon),
				"price": int(round(float(weapon.data.get("purchase_price", 0.0)))),
				"weight": float(weapon.data.get("weight", 0.0)),
				"damage": float(weapon.data.get("damage", 0.0)),
				"range": float(weapon.data.get("range", 0.0)),
				"cooldown": float(weapon.data.get("cooldown", 0.0)),
				"can_install": blockers.is_empty(),
				"blockers": blockers,
				"installed": WeaponOps.weapon_id_at(state.ship(), socket_name) == weapon.id,
			})
	return rows


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
