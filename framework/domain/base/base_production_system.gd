class_name BaseProductionSystem
extends RefCounted
## @static-doc
## 作用：Phase D3 基地的确定性 tick 系统：每游戏小时支付维护费/建筑维护/工人工资，
## 推进建筑建造、升级与生产订单，完成时把产物写入基地仓储。由 `Bootstrap` 注册到
## `TickScheduler`（id `base.production`，priority 100），`sim.advance` 驱动。
##
## ## 契约与约束
## - 没有 `data.base` 或没有注册表上下文时完全 no-op；不创建 `data.base`。
## - 每 tick 先把站点维护费、建筑维护费与工资累加到 `upkeep_debt`，按整金币支付；
##   余额不足时置 `halted=true`、`unpaid_ticks += 1`，本 tick 不推进建造/升级/生产。
## - 建造/升级按 1 小时递减；生产按 `BaseOps.production_speed()` 递减（≥1 tick 的
##   离散步长），工人少于配方 `workers_required` 时订单不推进（工资照付）。
## - 产物完成时直接进入基地仓储（允许短时超过容量；`base.view` 如实报告）。
## - 系统只依赖 `state` / `context.registries`，不读时钟、不随机，保证同 tick 可复现。
## @end-static-doc

const SYSTEM_ID := "base.production"
const PRIORITY := 100


static func register() -> void:
	TickScheduler.register(SYSTEM_ID, PRIORITY, Callable(BaseProductionSystem, "tick"))


## Idempotent registration used by `base.claim` and by `sim.advance` after loading a
## save that already has a base; keeps the global scheduler free of a system that can
## never run (and keeps D0 scheduler tests unaffected).
static func ensure_registered() -> void:
	if not TickScheduler.has(SYSTEM_ID):
		register()


static func tick(state: GameState, _tick: int, context = null) -> void:
	if state == null or context == null or not BaseOps.has_base(state):
		return
	var hub: RegistryHub = context.registries
	var base := BaseOps.ensure_structure(state)
	if base.is_empty():
		return
	if not _pay_upkeep(state, hub, base):
		return
	for entry in base.get("buildings", []):
		if not (entry is Dictionary):
			continue
		var building: Dictionary = entry
		match String(building.get("status", "")):
			"building":
				_tick_construction(building)
			"upgrading":
				_tick_upgrade(hub, building)
			"ready":
				_tick_production(hub, base, building)


static func _pay_upkeep(state: GameState, hub: RegistryHub, base: Dictionary) -> bool:
	var due := BaseOps.money_due_per_tick(hub, base)
	var debt := float(base.get("upkeep_debt", 0.0)) + due
	var payable := int(floor(debt + 0.0000001))
	if payable > 0:
		if state.money() < payable:
			base["upkeep_debt"] = debt
			base["halted"] = true
			base["unpaid_ticks"] = int(base.get("unpaid_ticks", 0)) + 1
			return false
		state.add_money(-payable)
		state.record_expense(payable)
		debt -= float(payable)
	base["upkeep_debt"] = maxf(0.0, debt)
	base["halted"] = false
	return true


static func _tick_construction(entry: Dictionary) -> void:
	var remaining := maxf(0.0, float(entry.get("remaining_hours", 0.0))) - 1.0
	entry["remaining_hours"] = maxf(0.0, remaining)
	if remaining <= 0.0:
		entry["status"] = "ready"
		entry["remaining_hours"] = 0.0


static func _tick_upgrade(hub: RegistryHub, entry: Dictionary) -> void:
	var remaining := maxf(0.0, float(entry.get("remaining_hours", 0.0))) - 1.0
	entry["remaining_hours"] = maxf(0.0, remaining)
	if remaining > 0.0:
		return
	var upgrade := BaseOps.upgrade_definition(hub, String(entry.get("upgrade_ref", "")))
	if upgrade != null:
		entry["level"] = int(upgrade.data.get("to_level", int(entry.get("level", 1)) + 1))
	entry["status"] = "ready"
	entry["remaining_hours"] = 0.0
	entry["upgrade_ref"] = ""


static func _tick_production(hub: RegistryHub, base: Dictionary, entry: Dictionary) -> void:
	var order: Dictionary = entry.get("order", {})
	if order.is_empty():
		return
	var recipe := BaseOps.recipe_definition(hub, String(order.get("recipe_id", "")))
	if recipe == null:
		entry["order"] = {}
		return
	if BaseOps.assigned_worker_count(entry) < int(recipe.data.get("workers_required", 0)):
		return
	var speed := BaseOps.production_speed(hub, base, entry)
	var remaining := maxf(0.0, float(order.get("remaining_hours", 0.0))) - speed
	order["remaining_hours"] = maxf(0.0, remaining)
	entry["order"] = order
	if remaining > 0.0:
		return
	_add_outputs(hub, base, recipe)
	entry["order"] = {}


static func _add_outputs(hub: RegistryHub, base: Dictionary, recipe: ContentDefinition) -> void:
	var storage: Dictionary = base.get("storage", {})
	for stack in recipe.data.get("outputs", []):
		if not (stack is Dictionary):
			continue
		var item_id := String((stack as Dictionary).get("item", ""))
		var amount := int((stack as Dictionary).get("amount", 0))
		if amount > 0:
			storage[item_id] = int(storage.get(item_id, 0)) + amount
	base["storage"] = storage
