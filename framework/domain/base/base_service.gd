class_name BaseService
extends RefCounted
## @static-doc
## 作用：Phase D3 基地的领域用例：占领基地、建造/升级建筑、雇工/派工、仓储存取与
## 启动生产。所有入口返回 `Result`，由应用层命令在 CommandBus 事务内调用；状态只落在
## `data.base`，生产推进由 `BaseProductionSystem` 在 tick 中完成。
##
## 关键依赖：`RegistryHub`（base_sites / buildings / building_upgrades /
## production_recipes / worker_roles）、`BaseOps`、`WarehouseOps`、`GameState`
##
## ## 契约与约束
## - 占领：同一存档只能有一个基地；要求当前在港，扣除站点 `claim_cost_money`，授予
##   `starting_workers` / `starting_storage`，基地绑定当前港口。
## - 建造/升级：金钱直接扣；材料从基地仓储扣；建筑有建造/升级工时，tick 完成后才可用。
## - 仓储：`deposit` 从当前港口仓库转入、`withdraw` 转回，均要求人在基地港口；容量
##   按 item.unit_weight 计算，超容量返回 `base_storage_full`。
## - 雇工：扣除 `hire_cost_money` 后进入待派工池；派工要求建筑已完工、工种匹配、
##   不超过 worker_slots，并从池中转移。
## - 生产：建筑空闲、配方属于该建筑、工人/材料/金钱满足时锁存输入并生成订单；
##   tick 推进期间不再重复扣费，完成后输出进基地仓储。
## - 领域事件：`base.claimed` / `base.building_started` / `base.upgrade_started` /
##   `base.worker_hired` / `base.worker_assigned` / `base.production_started` /
##   `base.storage_changed`。
## @end-static-doc


static func claim(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary:
	if not state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port")
	if BaseOps.has_base(state):
		return Result.fail("base_exists", "ui.error.base_exists")
	var site_id := String(params.get("base_site_id", ""))
	var site := BaseOps.site_definition(hub, site_id)
	if site == null:
		return Result.fail("unknown_base_site", "ui.error.unknown_base_site", {"base_site_id": site_id})
	var cost := int(round(float(site.data.get("claim_cost_money", 0.0))))
	if state.money() < cost:
		return Result.fail("insufficient_money", "ui.error.insufficient_money", {
			"cost": cost,
			"money": state.money(),
		})
	var base: Dictionary = BaseOps.DEFAULT_BASE.duplicate(true)
	base["site_archetype_id"] = site.id
	base["port_id"] = state.current_port_id()
	for worker_seed in site.data.get("starting_workers", []):
		if worker_seed is Dictionary:
			var role_id := String((worker_seed as Dictionary).get("role", ""))
			var amount := int((worker_seed as Dictionary).get("amount", 0))
			if amount > 0:
				(base["workers"] as Dictionary)[role_id] = int((base["workers"] as Dictionary).get(role_id, 0)) + amount
	for stack in site.data.get("starting_storage", []):
		if stack is Dictionary:
			var item_id := String((stack as Dictionary).get("item", ""))
			var amount := int((stack as Dictionary).get("amount", 0))
			if amount > 0:
				(base["storage"] as Dictionary)[item_id] = int((base["storage"] as Dictionary).get(item_id, 0)) + amount
	if cost > 0:
		state.add_money(-cost)
		state.record_expense(cost)
	state.data[BaseOps.BASE_KEY] = base
	BaseProductionSystem.ensure_registered()
	return Result.ok({
		"base": BaseOps.view(state, hub),
	}, [{
		"type": "base.claimed",
		"payload": {"site_archetype_id": site.id, "port_id": String(base["port_id"]), "cost": cost},
	}])


static func build(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary:
	var base := BaseOps.ensure_structure(state)
	if base.is_empty():
		return Result.fail("no_base", "ui.error.no_base")
	var building_id := String(params.get("building_id", ""))
	var definition := BaseOps.building_definition(hub, building_id)
	if definition == null:
		return Result.fail("unknown_building", "ui.error.unknown_building", {"building_id": building_id})
	if (base.get("buildings", []) as Array).size() >= BaseOps.slot_count(hub, base):
		return Result.fail("base_slots_full", "ui.error.base_slots_full", {
			"slot_count": BaseOps.slot_count(hub, base),
		})
	var cost := int(round(float(definition.data.get("build_cost_money", 0.0))))
	if state.money() < cost:
		return Result.fail("insufficient_money", "ui.error.insufficient_money", {
			"cost": cost,
			"money": state.money(),
		})
	var missing := _missing_items(hub, base, definition.data.get("build_cost_items", []))
	if not missing.is_empty():
		return Result.fail("missing_materials", "ui.error.missing_materials", {"missing": missing})
	_consume_items(hub, base, definition.data.get("build_cost_items", []))
	if cost > 0:
		state.add_money(-cost)
		state.record_expense(cost)
	var instance_id := BaseOps.next_instance_id(base)
	var build_time := maxf(0.0, float(definition.data.get("build_time_hours", 0.0)))
	var entry: Dictionary = BaseOps.DEFAULT_BUILDING.duplicate(true)
	entry["instance_id"] = instance_id
	entry["building_ref"] = definition.id
	entry["status"] = "ready" if build_time <= 0.0 else "building"
	entry["remaining_hours"] = build_time
	(base["buildings"] as Array).append(entry)
	return Result.ok({
		"instance_id": instance_id,
		"building_id": definition.id,
		"base": BaseOps.view(state, hub),
	}, [{
		"type": "base.building_started",
		"payload": {"instance_id": instance_id, "building_id": definition.id, "build_time_hours": build_time},
	}])


static func upgrade(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary:
	var base := BaseOps.ensure_structure(state)
	if base.is_empty():
		return Result.fail("no_base", "ui.error.no_base")
	var instance_id := String(params.get("instance_id", ""))
	var entry := BaseOps.building_entry(base, instance_id)
	if entry.is_empty():
		return Result.fail("unknown_building_instance", "ui.error.unknown_building_instance", {"instance_id": instance_id})
	if String(entry.get("status", "")) != "ready":
		return Result.fail("building_busy", "ui.error.building_busy", {"instance_id": instance_id})
	if not (entry.get("order", {}) as Dictionary).is_empty():
		return Result.fail("building_busy", "ui.error.building_busy", {"instance_id": instance_id})
	var upgrade_id := String(params.get("upgrade_id", ""))
	var upgrade := BaseOps.upgrade_definition(hub, upgrade_id)
	if upgrade == null:
		return Result.fail("unknown_upgrade", "ui.error.unknown_upgrade", {"upgrade_id": upgrade_id})
	if String(upgrade.data.get("building_ref", "")) != String(entry.get("building_ref", "")):
		return Result.fail("upgrade_not_available", "ui.error.upgrade_not_available", {"upgrade_id": upgrade_id})
	if int(upgrade.data.get("from_level", 0)) != int(entry.get("level", 1)):
		return Result.fail("upgrade_not_available", "ui.error.upgrade_not_available", {
			"upgrade_id": upgrade_id,
			"level": int(entry.get("level", 1)),
		})
	var cost := int(round(float(upgrade.data.get("cost_money", 0.0))))
	if state.money() < cost:
		return Result.fail("insufficient_money", "ui.error.insufficient_money", {
			"cost": cost,
			"money": state.money(),
		})
	var missing := _missing_items(hub, base, upgrade.data.get("cost_items", []))
	if not missing.is_empty():
		return Result.fail("missing_materials", "ui.error.missing_materials", {"missing": missing})
	_consume_items(hub, base, upgrade.data.get("cost_items", []))
	if cost > 0:
		state.add_money(-cost)
		state.record_expense(cost)
	var time_hours := maxf(0.0, float(upgrade.data.get("time_hours", 0.0)))
	entry["status"] = "ready" if time_hours <= 0.0 else "upgrading"
	entry["remaining_hours"] = time_hours
	entry["upgrade_ref"] = upgrade.id
	if time_hours <= 0.0:
		entry["level"] = int(upgrade.data.get("to_level", int(entry.get("level", 1)) + 1))
		entry["upgrade_ref"] = ""
	return Result.ok({
		"instance_id": instance_id,
		"upgrade_id": upgrade.id,
		"base": BaseOps.view(state, hub),
	}, [{
		"type": "base.upgrade_started",
		"payload": {"instance_id": instance_id, "upgrade_id": upgrade.id, "time_hours": time_hours},
	}])


static func deposit(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary:
	var base := BaseOps.ensure_structure(state)
	if base.is_empty():
		return Result.fail("no_base", "ui.error.no_base")
	if not state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port")
	if String(state.current_port_id()) != String(base.get("port_id", "")):
		return Result.fail("not_at_base_port", "ui.error.not_at_base_port", {
			"base_port_id": String(base.get("port_id", "")),
		})
	var item_id := String(params.get("item_id", ""))
	var amount := int(params.get("amount", 0))
	if amount <= 0:
		return Result.fail("invalid_amount", "ui.error.invalid_amount", {"amount": amount})
	if hub.get_by_id(ContentTypes.ITEM, item_id) == null:
		return Result.fail("unknown_item", "ui.error.unknown_item", {"item_id": item_id})
	var available := WarehouseOps.material_amount(state, String(base.get("port_id", "")), item_id)
	if available < amount:
		return Result.fail("warehouse_empty", "ui.error.warehouse_empty", {
			"item_id": item_id,
			"available": available,
			"amount": amount,
		})
	var added_weight := BaseOps.item_unit_weight(hub, item_id) * float(amount)
	if BaseOps.storage_used(hub, base.get("storage", {})) + added_weight > BaseOps.storage_capacity(hub, base) + 0.0001:
		return Result.fail("base_storage_full", "ui.error.base_storage_full", {
			"capacity": BaseOps.storage_capacity(hub, base),
			"used": BaseOps.storage_used(hub, base.get("storage", {})),
			"added_weight": added_weight,
		})
	WarehouseOps.remove_material(state, String(base.get("port_id", "")), item_id, amount)
	var storage: Dictionary = base.get("storage", {})
	storage[item_id] = int(storage.get(item_id, 0)) + amount
	base["storage"] = storage
	return Result.ok({
		"item_id": item_id,
		"amount": amount,
		"base": BaseOps.view(state, hub),
	}, [{
		"type": "base.storage_changed",
		"payload": {"direction": "deposit", "item_id": item_id, "amount": amount},
	}])


static func withdraw(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary:
	var base := BaseOps.ensure_structure(state)
	if base.is_empty():
		return Result.fail("no_base", "ui.error.no_base")
	if not state.is_at_port():
		return Result.fail("not_at_port", "ui.error.not_at_port")
	if String(state.current_port_id()) != String(base.get("port_id", "")):
		return Result.fail("not_at_base_port", "ui.error.not_at_base_port", {
			"base_port_id": String(base.get("port_id", "")),
		})
	var item_id := String(params.get("item_id", ""))
	var amount := int(params.get("amount", 0))
	if amount <= 0:
		return Result.fail("invalid_amount", "ui.error.invalid_amount", {"amount": amount})
	var storage: Dictionary = base.get("storage", {})
	var available := int(storage.get(item_id, 0))
	if available < amount:
		return Result.fail("base_storage_empty", "ui.error.base_storage_empty", {
			"item_id": item_id,
			"available": available,
			"amount": amount,
		})
	storage[item_id] = available - amount
	if int(storage[item_id]) <= 0:
		storage.erase(item_id)
	base["storage"] = storage
	WarehouseOps.add_material(state, String(base.get("port_id", "")), item_id, amount)
	return Result.ok({
		"item_id": item_id,
		"amount": amount,
		"base": BaseOps.view(state, hub),
	}, [{
		"type": "base.storage_changed",
		"payload": {"direction": "withdraw", "item_id": item_id, "amount": amount},
	}])


static func hire_worker(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary:
	var base := BaseOps.ensure_structure(state)
	if base.is_empty():
		return Result.fail("no_base", "ui.error.no_base")
	var role_id := String(params.get("role_id", ""))
	var role := BaseOps.worker_role_definition(hub, role_id)
	if role == null:
		return Result.fail("unknown_worker_role", "ui.error.unknown_worker_role", {"role_id": role_id})
	var amount := int(params.get("amount", 1))
	if amount <= 0:
		return Result.fail("invalid_amount", "ui.error.invalid_amount", {"amount": amount})
	var cost := int(round(float(role.data.get("hire_cost_money", 0.0)))) * amount
	if state.money() < cost:
		return Result.fail("insufficient_money", "ui.error.insufficient_money", {
			"cost": cost,
			"money": state.money(),
		})
	if cost > 0:
		state.add_money(-cost)
		state.record_expense(cost)
	var workers: Dictionary = base.get("workers", {})
	workers[role_id] = int(workers.get(role_id, 0)) + amount
	base["workers"] = workers
	return Result.ok({
		"role_id": role_id,
		"amount": amount,
		"cost": cost,
		"base": BaseOps.view(state, hub),
	}, [{
		"type": "base.worker_hired",
		"payload": {"role_id": role_id, "amount": amount, "cost": cost},
	}])


static func assign_worker(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary:
	var base := BaseOps.ensure_structure(state)
	if base.is_empty():
		return Result.fail("no_base", "ui.error.no_base")
	var instance_id := String(params.get("instance_id", ""))
	var entry := BaseOps.building_entry(base, instance_id)
	if entry.is_empty():
		return Result.fail("unknown_building_instance", "ui.error.unknown_building_instance", {"instance_id": instance_id})
	if String(entry.get("status", "")) != "ready":
		return Result.fail("building_busy", "ui.error.building_busy", {"instance_id": instance_id})
	var definition := BaseOps.building_definition(hub, String(entry.get("building_ref", "")))
	if definition == null:
		return Result.fail("unknown_building", "ui.error.unknown_building")
	var role_id := String(definition.data.get("worker_role", ""))
	if role_id.is_empty():
		return Result.fail("no_worker_slot", "ui.error.no_worker_slot", {"instance_id": instance_id})
	var amount := int(params.get("amount", 1))
	if amount <= 0:
		return Result.fail("invalid_amount", "ui.error.invalid_amount", {"amount": amount})
	var pool: Dictionary = base.get("workers", {})
	if int(pool.get(role_id, 0)) < amount:
		return Result.fail("insufficient_workers", "ui.error.insufficient_workers", {
			"role_id": role_id,
			"available": int(pool.get(role_id, 0)),
			"amount": amount,
		})
	var assigned: Dictionary = entry.get("workers", {})
	if BaseOps.assigned_worker_count(entry) + amount > int(definition.data.get("worker_slots", 0)):
		return Result.fail("worker_slots_full", "ui.error.worker_slots_full", {
			"instance_id": instance_id,
			"worker_slots": int(definition.data.get("worker_slots", 0)),
		})
	pool[role_id] = int(pool.get(role_id, 0)) - amount
	if int(pool[role_id]) <= 0:
		pool.erase(role_id)
	assigned[role_id] = int(assigned.get(role_id, 0)) + amount
	base["workers"] = pool
	entry["workers"] = assigned
	return Result.ok({
		"instance_id": instance_id,
		"role_id": role_id,
		"amount": amount,
		"base": BaseOps.view(state, hub),
	}, [{
		"type": "base.worker_assigned",
		"payload": {"instance_id": instance_id, "role_id": role_id, "amount": amount},
	}])


static func start_production(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary:
	var base := BaseOps.ensure_structure(state)
	if base.is_empty():
		return Result.fail("no_base", "ui.error.no_base")
	var instance_id := String(params.get("instance_id", ""))
	var entry := BaseOps.building_entry(base, instance_id)
	if entry.is_empty():
		return Result.fail("unknown_building_instance", "ui.error.unknown_building_instance", {"instance_id": instance_id})
	if String(entry.get("status", "")) != "ready":
		return Result.fail("building_busy", "ui.error.building_busy", {"instance_id": instance_id})
	if not (entry.get("order", {}) as Dictionary).is_empty():
		return Result.fail("building_busy", "ui.error.building_busy", {"instance_id": instance_id})
	var recipe_id := String(params.get("recipe_id", ""))
	var recipe := BaseOps.recipe_definition(hub, recipe_id)
	if recipe == null:
		return Result.fail("unknown_recipe", "ui.error.unknown_recipe", {"recipe_id": recipe_id})
	if String(recipe.data.get("building_ref", "")) != String(entry.get("building_ref", "")):
		return Result.fail("recipe_not_available", "ui.error.recipe_not_available", {"recipe_id": recipe_id})
	var required_workers := int(recipe.data.get("workers_required", 0))
	if BaseOps.assigned_worker_count(entry) < required_workers:
		return Result.fail("workers_required", "ui.error.workers_required", {
			"required": required_workers,
			"assigned": BaseOps.assigned_worker_count(entry),
		})
	var missing := _missing_items(hub, base, recipe.data.get("inputs", []))
	if not missing.is_empty():
		return Result.fail("missing_materials", "ui.error.missing_materials", {"missing": missing})
	var money_cost := int(round(float(recipe.data.get("money_cost", 0.0))))
	if state.money() < money_cost:
		return Result.fail("insufficient_money", "ui.error.insufficient_money", {
			"cost": money_cost,
			"money": state.money(),
		})
	_consume_items(hub, base, recipe.data.get("inputs", []))
	if money_cost > 0:
		state.add_money(-money_cost)
		state.record_expense(money_cost)
	var duration := maxf(0.5, float(recipe.data.get("duration_hours", 1.0)))
	entry["order"] = {
		"recipe_id": recipe.id,
		"remaining_hours": duration,
		"total_hours": duration,
	}
	return Result.ok({
		"instance_id": instance_id,
		"recipe_id": recipe.id,
		"duration_hours": duration,
		"base": BaseOps.view(state, hub),
	}, [{
		"type": "base.production_started",
		"payload": {"instance_id": instance_id, "recipe_id": recipe.id, "duration_hours": duration},
	}])


static func _missing_items(hub: RegistryHub, base: Dictionary, stacks: Array) -> Array:
	var missing: Array = []
	var storage: Dictionary = base.get("storage", {})
	for stack in stacks:
		if not (stack is Dictionary):
			continue
		var item_id := String((stack as Dictionary).get("item", ""))
		var amount := int((stack as Dictionary).get("amount", 0))
		var available := int(storage.get(item_id, 0))
		if available < amount:
			missing.append({"item_id": item_id, "required": amount, "available": available})
	return missing


static func _consume_items(hub: RegistryHub, base: Dictionary, stacks: Array) -> void:
	var storage: Dictionary = base.get("storage", {})
	for stack in stacks:
		if not (stack is Dictionary):
			continue
		var item_id := String((stack as Dictionary).get("item", ""))
		var amount := int((stack as Dictionary).get("amount", 0))
		var remaining := int(storage.get(item_id, 0)) - amount
		if remaining <= 0:
			storage.erase(item_id)
		else:
			storage[item_id] = remaining
	base["storage"] = storage
