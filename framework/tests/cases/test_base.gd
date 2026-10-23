extends TestCase
## @static-doc
## 作用：Phase D3 基地运行时的回归测试：`data.base` 惰性结构、占领/建造/升级、
## 仓储存取与容量、雇工/派工与工资、生产链（tick 产物进仓储）、维护费不足停机、
## 损坏数据规范化、存档 round-trip 与确定性。
##
## ## 契约与约束
## - 内容从 Core 注册表动态选取（base_sites / buildings / production_recipes /
##   worker_roles），不写死数值到断言里；测试通过公开命令驱动。
## - 生产由 `BaseProductionSystem` 在 `sim.advance` 的 tick 中推进；测试用
##   `sim.advance` 让时间流动，而不是直接改 `remaining_hours`。
## - 仓储输入通过 `base.deposit` 从当前港仓库转入；材料由测试预先写入港口仓库。
## - 所有写操作走 `base.*` 命令（CommandBus 事务）；失败命令不得提交状态。
## @end-static-doc

const STEADY := "core:starting_scenario/steady"
const COASTAL := "core:base_site/coastal_outpost"
const INDUSTRIAL := "core:base_site/industrial_yard"


func _start(seed_value: int, money: int = 20000) -> AppContext:
	var context: AppContext = bootstrap_core()["context"]
	var started := context.commands.execute(&"run.start", {"starting_scenario": STEADY, "seed": seed_value})
	assert_true(bool(started.get("ok", false)), "run.start succeeds: %s" % str(started))
	context.state.set_money(money)
	var port_id := context.state.current_port_id()
	WarehouseOps.add_material(context.state, port_id, "core:item/timber", 60)
	WarehouseOps.add_material(context.state, port_id, "core:item/coal", 40)
	WarehouseOps.add_material(context.state, port_id, "core:item/iron_ore", 30)
	WarehouseOps.add_material(context.state, port_id, "core:item/brass", 30)
	WarehouseOps.add_material(context.state, port_id, "core:item/boiler_plate", 20)
	WarehouseOps.add_material(context.state, port_id, "core:item/precision_gear", 5)
	return context


func _view(context: AppContext) -> Dictionary:
	var result := context.queries.execute(&"base.view")
	assert_true(bool(result.get("ok", false)), "base.view answers: %s" % str(result))
	return result.get("data", {})


func _claim(context: AppContext, site_id: String = COASTAL) -> Dictionary:
	return context.commands.execute(&"base.claim", {"base_site_id": site_id})


func _deposit(context: AppContext, item_id: String, amount: int) -> Dictionary:
	return context.commands.execute(&"base.deposit", {"item_id": item_id, "amount": amount})


func _build(context: AppContext, building_id: String) -> String:
	var result := context.commands.execute(&"base.build", {"building_id": building_id})
	assert_true(bool(result.get("ok", false)), "building %s starts: %s" % [building_id, str(result)])
	return String(result.get("data", {}).get("instance_id", ""))


func _advance(context: AppContext, hours: float) -> Dictionary:
	var result := context.commands.execute(&"sim.advance", {"hours": hours})
	assert_true(bool(result.get("ok", false)), "sim.advance succeeds: %s" % str(result))
	return result


func _building(view: Dictionary, instance_id: String) -> Dictionary:
	for entry in view.get("buildings", []):
		if entry is Dictionary and String((entry as Dictionary).get("instance_id", "")) == instance_id:
			return entry
	return {}


func _storage_amount(view: Dictionary, item_id: String) -> int:
	var storage: Dictionary = view.get("storage", {})
	for entry in storage.get("items", []):
		if entry is Dictionary and String((entry as Dictionary).get("item_id", "")) == item_id:
			return int((entry as Dictionary).get("amount", 0))
	return 0


func test_commands_and_query_are_registered() -> void:
	var context := _start(301)
	for command in [
		&"base.claim", &"base.build", &"base.upgrade", &"base.deposit", &"base.withdraw",
		&"base.hire_worker", &"base.assign_worker", &"base.start_production",
	]:
		assert_true(context.commands.has(command), "%s is registered" % String(command))
	assert_true(context.queries.has(&"base.view"), "base.view is registered")
	_claim(context)
	assert_true(TickScheduler.has(BaseProductionSystem.SYSTEM_ID),
		"claiming a base registers the production tick system")


func test_claim_is_unique_and_requires_a_port() -> void:
	var context := _start(302)
	var view := _view(context)
	assert_false(bool(view.get("claimed", true)), "a fresh run has no base")
	var unknown := _claim(context, "test:base_site/absent")
	assert_eq(String(unknown.get("error_code", "")), "unknown_base_site", "unknown base sites are rejected")
	assert_eq(context.state.data.get("base", null), null, "a failed claim does not create data.base")
	var claimed := _claim(context)
	assert_true(bool(claimed.get("ok", false)), "claiming the starting base succeeds: %s" % str(claimed))
	view = _view(context)
	assert_true(bool(view.get("claimed", false)), "the view reports the claimed base")
	assert_eq(String(view.get("site_archetype_id", "")), COASTAL, "the site archetype is recorded")
	assert_eq(String(view.get("port_id", "")), context.state.current_port_id(), "the base binds the current port")
	assert_eq(int(view.get("slot_count", 0)), 3, "the coastal outpost has three slots")
	var again := _claim(context)
	assert_eq(String(again.get("error_code", "")), "base_exists", "only one base can be claimed")


func test_build_consumes_materials_and_finishes_with_ticks() -> void:
	var context := _start(303)
	_claim(context)
	assert_true(bool(_deposit(context, "core:item/timber", 6).get("ok", false)), "timber is deposited")
	var before := _view(context)
	assert_eq(_storage_amount(before, "core:item/timber"), 6, "deposit moves warehouse items into base storage")
	var instance_id := _build(context, "core:building/sawmill")
	var view := _view(context)
	var building := _building(view, instance_id)
	assert_eq(String(building.get("status", "")), "building", "a building starts under construction")
	assert_eq(_storage_amount(view, "core:item/timber"), 4, "the build cost is taken from base storage")
	_advance(context, 1)
	assert_eq(String(_building(_view(context), instance_id).get("status", "")), "building", "construction is not instant")
	_advance(context, 1)
	view = _view(context)
	assert_eq(String(_building(view, instance_id).get("status", "")), "ready", "construction completes after its hours")
	assert_eq(int(view.get("slots_used", 0)), 1, "the used slot count is reported")


func test_storage_withdraw_and_capacity() -> void:
	var context := _start(304)
	_claim(context)
	assert_true(bool(_deposit(context, "core:item/timber", 10).get("ok", false)), "timber is deposited")
	var withdrawn := context.commands.execute(&"base.withdraw", {"item_id": "core:item/timber", "amount": 4})
	assert_true(bool(withdrawn.get("ok", false)), "withdrawing to the port warehouse succeeds: %s" % str(withdrawn))
	assert_eq(WarehouseOps.material_amount(context.state, context.state.current_port_id(), "core:item/timber"), 54,
		"withdrawn items return to the port warehouse")
	WarehouseOps.add_material(context.state, context.state.current_port_id(), "core:item/timber", 300)
	var full := _deposit(context, "core:item/timber", 300)
	assert_eq(String(full.get("error_code", "")), "base_storage_full", "capacity is enforced with item unit weight")
	assert_eq(String(context.commands.execute(&"base.withdraw", {"item_id": "core:item/timber", "amount": 999}).get("error_code", "")),
		"base_storage_empty", "withdrawing more than stored is rejected")


func test_hire_assign_and_wages() -> void:
	var context := _start(305)
	_claim(context)
	assert_true(bool(_deposit(context, "core:item/timber", 6).get("ok", false)), "timber is deposited")
	var inst := _build(context, "core:building/sawmill")
	_advance(context, 2)
	var view := _view(context)
	var workers: Dictionary = view.get("workers", {})
	assert_eq(int(workers.get("pool_total", 0)), 2, "the coastal outpost starts with two laborers")
	var hired := context.commands.execute(&"base.hire_worker", {"role_id": "core:worker_role/laborer", "amount": 1})
	assert_true(bool(hired.get("ok", false)), "hiring a worker succeeds: %s" % str(hired))
	var assigned := context.commands.execute(&"base.assign_worker", {"instance_id": inst, "amount": 2})
	assert_true(bool(assigned.get("ok", false)), "assigning workers succeeds: %s" % str(assigned))
	view = _view(context)
	var building := _building(view, inst)
	assert_eq(Array(building.get("workers", [])).size(), 1, "assigned workers are reported")
	var money_before := context.state.money()
	_advance(context, 1)
	assert_true(context.state.money() < money_before, "wages and upkeep are paid each tick")
	var over := context.commands.execute(&"base.assign_worker", {"instance_id": inst, "amount": 99})
	assert_eq(String(over.get("error_code", "")), "insufficient_workers", "the idle worker pool is enforced")


func test_upgrade_raises_level_and_production_speed() -> void:
	var context := _start(306)
	_claim(context)
	assert_true(bool(_deposit(context, "core:item/timber", 12).get("ok", false)), "timber is deposited")
	var inst := _build(context, "core:building/sawmill")
	_advance(context, 2)
	var before := _building(_view(context), inst)
	var upgraded := context.commands.execute(&"base.upgrade", {
		"instance_id": inst, "upgrade_id": "core:building_upgrade/sawmill_2",
	})
	assert_true(bool(upgraded.get("ok", false)), "starting the upgrade succeeds: %s" % str(upgraded))
	assert_eq(String(_building(_view(context), inst).get("status", "")), "upgrading", "the upgrade is in progress")
	_advance(context, 3)
	var after := _building(_view(context), inst)
	assert_eq(int(after.get("level", 0)), 2, "the building reaches level two")
	assert_true(float(after.get("production_speed", 1.0)) > float(before.get("production_speed", 1.0)),
		"the upgrade raises production speed")


func test_production_chain_reaches_shipbuilding_material() -> void:
	var context := _start(307)
	_claim(context, INDUSTRIAL)
	for item_id in ["core:item/timber", "core:item/coal", "core:item/iron_ore", "core:item/brass", "core:item/boiler_plate"]:
		assert_true(bool(_deposit(context, item_id, 20).get("ok", false)), "%s is deposited" % item_id)
	var smelter := _build(context, "core:building/smelter")
	var foundry := _build(context, "core:building/foundry")
	_advance(context, 5)
	assert_eq(String(_building(_view(context), smelter).get("status", "")), "ready", "the smelter is ready")
	assert_eq(String(_building(_view(context), foundry).get("status", "")), "ready", "the foundry is ready")
	context.commands.execute(&"base.hire_worker", {"role_id": "core:worker_role/smelter", "amount": 2})
	context.commands.execute(&"base.hire_worker", {"role_id": "core:worker_role/engineer", "amount": 2})
	var assigned_smelter := context.commands.execute(&"base.assign_worker", {"instance_id": smelter, "amount": 2})
	assert_true(bool(assigned_smelter.get("ok", false)), "smelter workers are assigned: %s" % str(assigned_smelter))
	var assigned_foundry := context.commands.execute(&"base.assign_worker", {"instance_id": foundry, "amount": 2})
	assert_true(bool(assigned_foundry.get("ok", false)), "foundry workers are assigned: %s" % str(assigned_foundry))
	var plate := context.commands.execute(&"base.start_production", {
		"instance_id": smelter, "recipe_id": "core:production_recipe/boiler_plate",
	})
	assert_true(bool(plate.get("ok", false)), "boiler plate production starts: %s" % str(plate))
	_advance(context, 3)
	assert_eq(_storage_amount(_view(context), "core:item/boiler_plate"), 20,
		"the smelter adds boiler plate after the foundry build consumed one")
	var gear := context.commands.execute(&"base.start_production", {
		"instance_id": foundry, "recipe_id": "core:production_recipe/precision_gear",
	})
	assert_true(bool(gear.get("ok", false)), "precision gear production starts: %s" % str(gear))
	_advance(context, 3)
	var view := _view(context)
	assert_eq(_storage_amount(view, "core:item/precision_gear"), 1, "the foundry adds precision gear")
	var item := context.registries.get_by_id(ContentTypes.ITEM, "core:item/precision_gear")
	assert_true(item != null and item.tags.has("material.shipbuilding"),
		"the produced item is a shipbuilding material used by fleet hulls")


func test_unpaid_upkeep_halts_production() -> void:
	var context := _start(308, 250)
	var claimed := _claim(context)
	assert_true(bool(claimed.get("ok", false)), "claiming with exactly the claim cost succeeds: %s" % str(claimed))
	assert_eq(context.state.money(), 0, "the claim spends all available money")
	_advance(context, 1)
	var view := _view(context)
	assert_true(bool(view.get("halted", false)), "missing upkeep halts the base")
	assert_true(int(view.get("unpaid_ticks", 0)) >= 1, "the unpaid tick is recorded")


## D3-FIX2：numeric fields 被写成 null/数组/字典时不能抛引擎错误，更不能在下一次 tick
## 把整个 base 规范化成空块（旧行为会静默丢基地）。
func test_malformed_numeric_fields_do_not_destroy_the_base() -> void:
	var context := _start(312)
	_claim(context)
	context.state.data["base"]["next_building"] = null
	context.state.data["base"]["unpaid_ticks"] = []
	context.state.data["base"]["upkeep_debt"] = {}
	context.state.data["base"]["storage"] = {"core:item/timber": null}
	context.state.data["base"]["workers"] = {"core:worker_role/laborer": []}
	context.state.data["base"]["buildings"] = [{
		"instance_id": "bld_1",
		"building_ref": "core:building/sawmill",
		"level": null,
		"status": "ready",
		"remaining_hours": {},
		"workers": {},
		"order": {"recipe_id": "core:production_recipe/timber", "remaining_hours": null, "total_hours": []},
	}]
	var view := _view(context)
	assert_true(bool(view.get("claimed", false)), "base.view normalizes numeric garbage without losing the base")
	assert_eq(String(view.get("site_archetype_id", "")), COASTAL, "the site survives normalization")
	_advance(context, 1)
	var after: Variant = context.state.data.get("base", null)
	assert_true(after is Dictionary and not (after as Dictionary).is_empty(), "a tick does not replace the base with an empty block")
	assert_eq(String((after as Dictionary).get("site_archetype_id", "")), COASTAL, "the base is still the same site")


## D3-FIX2：存取必须人在基地港口；在航（voyage 非空）时即使 current_port_id 仍是母港也要拒绝。
func test_transfer_requires_being_at_port() -> void:
	var context := _start(313)
	_claim(context)
	assert_true(bool(_deposit(context, "core:item/timber", 5).get("ok", false)), "a dock deposit succeeds")
	context.state.data["voyage"] = {"origin_port_id": context.state.current_port_id()}
	assert_false(context.state.is_at_port(), "the fixture is at sea")
	var deposit := context.commands.execute(&"base.deposit", {"item_id": "core:item/timber", "amount": 1})
	assert_eq(String(deposit.get("error_code", "")), "not_at_port", "deposit is rejected at sea")
	var withdraw := context.commands.execute(&"base.withdraw", {"item_id": "core:item/timber", "amount": 1})
	assert_eq(String(withdraw.get("error_code", "")), "not_at_port", "withdraw is rejected at sea")
	assert_eq(_storage_amount(_view(context), "core:item/timber"), 5, "rejected transfers leave storage unchanged")


## D3-FIX3：site_archetype_id 被写成非字符串时不能抛引擎错误；base.view 返回未占领，
## 但原始块不能被 tick 清空。
func test_malformed_site_id_is_tolerated() -> void:
	var context := _start(314)
	_claim(context)
	for variant in [null, [], {}]:
		context.state.data["base"]["site_archetype_id"] = variant
		var view := _view(context)
		assert_false(bool(view.get("claimed", true)), "a non-string site id reads as unclaimed")
		_advance(context, 1)
		assert_true(context.state.data.get("base", null) is Dictionary, "the base block is not destroyed")
		assert_false((context.state.data.get("base", {}) as Dictionary).is_empty(), "the base block keeps its fields")


func test_malformed_base_data_is_normalized() -> void:
	var context := _start(309)
	_claim(context)
	var variants: Array = [
		"broken",
		42,
		["not", "a", "base"],
		{"site_archetype_id": COASTAL, "buildings": "nope", "storage": "bad", "workers": []},
		{"site_archetype_id": COASTAL, "buildings": [null, 42, {"instance_id": 7}, {"instance_id": "bld_1", "building_ref": "core:building/sawmill", "level": "x", "status": "nonsense", "workers": "bad", "order": "bad"}]},
	]
	for variant in variants:
		context.state.data["base"] = variant
		var result := context.queries.execute(&"base.view")
		assert_true(bool(result.get("ok", false)), "base.view stays ok for malformed data: %s" % str(result))
		var view: Dictionary = result.get("data", {})
		if bool(view.get("claimed", false)):
			assert_true(view.get("buildings", null) is Array, "buildings normalize to an array")
			assert_true(view.get("storage", null) is Dictionary, "storage normalizes to a dictionary")
			for entry in view.get("buildings", []):
				assert_true(entry is Dictionary, "building entries normalize to dictionaries")


func test_save_round_trip() -> void:
	var context := _start(310)
	_claim(context)
	assert_true(bool(_deposit(context, "core:item/timber", 8).get("ok", false)), "timber is deposited")
	var inst := _build(context, "core:building/sawmill")
	_advance(context, 2)
	var saved := context.save.save_slot("base_manual", context.state, context.save_meta())
	assert_true(bool(saved.get("ok", false)), "saving the base succeeds: %s" % str(saved))
	var loaded := context.save.load_slot("base_manual")
	assert_true(bool(loaded.get("ok", false)), "loading the base succeeds")
	var loaded_context: AppContext = bootstrap_core()["context"]
	loaded_context.set_state(loaded["state"])
	var view := _view(loaded_context)
	assert_true(bool(view.get("claimed", false)), "the base survives a save round-trip")
	assert_eq(int(view.get("slots_used", 0)), 1, "the built structure survives")
	assert_eq(_storage_amount(view, "core:item/timber"), 6, "base storage survives")
	assert_eq(String(_building(view, inst).get("status", "")), "ready", "the building status survives")


func test_same_seed_and_commands_are_deterministic() -> void:
	var first := _start(311)
	var second := _start(311)
	for context in [first, second]:
		_claim(context)
		_deposit(context, "core:item/timber", 8)
		_build(context, "core:building/sawmill")
		_advance(context, 4)
	if first.state == null or second.state == null:
		return
	assert_eq(first.state.data.get("base", null), second.state.data.get("base", null),
		"same seed + same base commands produce the same base block")
