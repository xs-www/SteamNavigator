extends TestCase
## @static-doc
## 作用：Phase D1-B 战斗自动结算测试。用最小合成 RegistryHub（武器 / 伤害类型 / 能力 /
## 敌人原型 / 遭遇表 / 掉落表 / hull）驱动 `CombatOps`（纯规则）、`CombatService`
## （落盘 / 战利品 / 惰性 `data.combat`）、`CombatCommands.resolve` 与
## `CombatViewQuery` / `CombatLogQuery`，并补一条真实 core 内容的分辨率冒烟。
##
## ## 契约与约束
## - **不依赖 core 内容做精确断言**：护甲 / 穿甲 / 状态 / 撤退 / 战利品数值全部用
##   `test:*` 合成定义控制；真实 core 只在 `test_core_content_resolves` 里做
##   「能加载、能结算、结果形状稳定」的冒烟（不锁具体随机结果）。
## - **确定性**：同一 state + 同一显式 seed 两次结算的 `data` 完全相等（含日志与战利品）；
##   seed 会写入 battle 记录。
## - **不把持久 id/时间写进数值断言**：battle 的 `id / at_time` 由服务写入，测试只比较
##   同 seed 下的完整结果（两次都在 game_time 0 / 首场，因此仍然可逐字段比较）。
## - **旧档**：没有 `data.combat` 的 state 上查询不创建该块、命令结算后才惰性创建。
## - **D1-FIX 诊断**：未知 weapon class 的 socket 跳过时写入 `battle.diagnostics`
##   （敌我一致，side/index/socket/socket_class/reason），未知 loot_table / loot entry
##   同样记录 reason；battle 仍可结算，内容层缺口由 CrossReferenceValidator 报 error。
## - **D1-FIX2**：显式 `weapon_loadout` 受 socket class 门禁（不匹配 `weapon_class_mismatch`
##   且不回退默认武器）；`combat.resolve` 的可选 `encounter_id` 是结算幂等键，重复调用
##   返回 `already_settled` 且不发奖/不追加/不发事件；`RngService.STREAM_NAMES` 含 combat。
## @end-static-doc

const HULL_SINGLE := "test:hull/single"
const HULL_DUAL := "test:hull/dual"
const HULL_GUNNER := "test:hull/gunner"
const HULL_TOWER := "test:hull/tower"
const WEAPON_LIGHT := "test:weapon/light_gun"
const WEAPON_PIERCER := "test:weapon/piercer"
const WEAPON_BURNER := "test:weapon/burner"
const WEAPON_PLAIN_BURNER := "test:weapon/plain_burner"
const WEAPON_MEDIUM := "test:weapon/medium_gun"
const WEAPON_CRUSHER := "test:weapon/crusher"
const WEAPON_HEAVY_BURST := "test:weapon/heavy_burst"
const ENEMY_WEAK := "test:enemy/weak"
const ENEMY_ARMORED := "test:enemy/armored"
const ENEMY_FLEEING := "test:enemy/fleeing"
const ENEMY_GUNSHIP := "test:enemy/gunship"
const ENEMY_CRUSHER := "test:enemy/crusher"
const ENEMY_TANK := "test:enemy/tank"
const ENEMY_LOOTBAG := "test:enemy/lootbag"
const ENEMY_ARMORY := "test:enemy/armory"
const ENEMY_BAD_LOOT := "test:enemy/bad_loot"
const ENCOUNTER_SCRAP := "test:encounter/scrap"
const ENCOUNTER_ARMORED := "test:encounter/armored"
const ENCOUNTER_FLEEING := "test:encounter/fleeing"
const ENCOUNTER_GUNSHIP := "test:encounter/gunship"
const ENCOUNTER_CRUSHER := "test:encounter/crusher"
const ENCOUNTER_TANK := "test:encounter/tank"
const LOOT_SCRAP := "test:loot/scrap"
const LOOT_MODULE := "test:loot/module"
const LOOT_WEAPON := "test:loot/weapon"
const PORT_ID := "port_0"
const ITEM_SCRAP := "test:item/scrap"
const MODULE_CRATE := "test:module/crate"

static var _hub_cache: RegistryHub = null


## Minimal context accepted by CombatCommands / ViewModels (no buses needed).
class FakeContext:
	extends RefCounted
	var state: GameState
	var registries: RegistryHub

	func has_run() -> bool:
		return state != null and not state.is_empty()


## ---------------------------------------------------------------------------
## Fixture
## ---------------------------------------------------------------------------

func _hub() -> RegistryHub:
	if _hub_cache != null:
		return _hub_cache
	var hub := RegistryHub.new()
	_define(hub, ContentTypes.ITEM, ITEM_SCRAP, {
		"unit_weight": 1.0,
		"base_price": 10,
		"base_stock": 10,
		"category": "trade",
	})
	_define(hub, ContentTypes.MODULE, MODULE_CRATE, {
		"category": "cargo",
		"weight": 1.0,
		"capacity": 5.0,
	})
	_define(hub, ContentTypes.HULL, HULL_SINGLE, {
		"max_durability": 100,
		"max_weight": 200,
		"weapon_sockets": [{"name": "S1", "socket_class": "Light", "socket_index": 0}],
	})
	_define(hub, ContentTypes.HULL, HULL_DUAL, {
		"max_durability": 100,
		"max_weight": 200,
		"weapon_sockets": [
			{"name": "S1", "socket_class": "Light", "socket_index": 0},
			{"name": "S2", "socket_class": "Medium", "socket_index": 1},
		],
	})
	_define(hub, ContentTypes.HULL, HULL_GUNNER, {
		"max_durability": 100,
		"max_weight": 200,
		"weapon_sockets": [{"name": "S1", "socket_class": "Medium", "socket_index": 0}],
	})
	# No synthetic weapon declares the Tower class: every socket below is unmounted.
	_define(hub, ContentTypes.HULL, HULL_TOWER, {
		"max_durability": 100,
		"max_weight": 200,
		"weapon_sockets": [{"name": "S1", "socket_class": "Tower", "socket_index": 0}],
	})
	_damage_type(hub, "test:damage_type/kinetic", 0.1, "none")
	_damage_type(hub, "test:damage_type/piercing", 1.0, "none")
	_damage_type(hub, "test:damage_type/fire", 0.0, "burn")
	_weapon(hub, WEAPON_LIGHT, "Light", 10.0, 1.0, 1.0, "test:damage_type/kinetic")
	_weapon(hub, WEAPON_PIERCER, "Light", 10.0, 1.0, 1.0, "test:damage_type/piercing")
	_weapon(hub, WEAPON_BURNER, "Medium", 5.0, 1.0, 1.0, "test:damage_type/fire")
	_weapon(hub, WEAPON_PLAIN_BURNER, "Medium", 5.0, 1.0, 1.0, "test:damage_type/kinetic")
	_weapon(hub, WEAPON_MEDIUM, "Medium", 100.0, 1.0, 1.0, "test:damage_type/kinetic")
	_weapon(hub, WEAPON_CRUSHER, "Side", 220.0, 10.0, 1.0, "test:damage_type/kinetic")
	_weapon(hub, WEAPON_HEAVY_BURST, "Heavy", 500.0, 1.0, 1.0, "test:damage_type/kinetic")
	_ability(hub, "test:ability/berserk", "engage", -1.0)
	_ability(hub, "test:ability/coward", "evade", 0.5)
	_enemy(hub, ENEMY_WEAK, 20.0, 0.0, "Tower", "test:ability/berserk", LOOT_SCRAP)
	_enemy(hub, ENEMY_ARMORED, 100.0, 0.5, "Tower", "test:ability/berserk", LOOT_SCRAP)
	_enemy(hub, ENEMY_FLEEING, 1000.0, 0.0, "Tower", "test:ability/coward", LOOT_SCRAP)
	_enemy(hub, ENEMY_GUNSHIP, 200.0, 0.1, "Heavy", "test:ability/berserk", LOOT_SCRAP)
	_enemy(hub, ENEMY_CRUSHER, 200.0, 0.1, "Side", "test:ability/berserk", LOOT_SCRAP)
	_enemy(hub, ENEMY_TANK, 28.0, 0.0, "Tower", "test:ability/berserk", LOOT_SCRAP)
	_enemy(hub, ENEMY_LOOTBAG, 20.0, 0.0, "Tower", "test:ability/berserk", LOOT_MODULE)
	_enemy(hub, ENEMY_ARMORY, 20.0, 0.0, "Tower", "test:ability/berserk", LOOT_WEAPON)
	_enemy(hub, ENEMY_BAD_LOOT, 20.0, 0.0, "Tower", "test:ability/berserk", "test:loot/missing")
	_encounter(hub, ENCOUNTER_SCRAP, ENEMY_WEAK)
	_encounter(hub, ENCOUNTER_ARMORED, ENEMY_ARMORED)
	_encounter(hub, ENCOUNTER_FLEEING, ENEMY_FLEEING)
	_encounter(hub, ENCOUNTER_GUNSHIP, ENEMY_GUNSHIP)
	_encounter(hub, ENCOUNTER_CRUSHER, ENEMY_CRUSHER)
	_encounter(hub, ENCOUNTER_TANK, ENEMY_TANK)
	_define(hub, ContentTypes.ENCOUNTER_TABLE, "test:encounter/wing", {
		"kind": "patrol",
		"danger": 2,
		"entries": [{"enemy_archetype": ENEMY_WEAK, "weight": 1, "count_range": [2, 2]}],
	})
	_encounter(hub, "test:encounter/module", ENEMY_LOOTBAG)
	_encounter(hub, "test:encounter/weapon", ENEMY_ARMORY)
	_encounter(hub, "test:encounter/bad_loot", ENEMY_BAD_LOOT)
	_loot(hub, LOOT_SCRAP, [10, 10], [{"kind": "item", "id": ITEM_SCRAP, "weight": 1, "amount_range": [2, 2]}])
	_loot(hub, LOOT_MODULE, [], [{"kind": "module", "id": MODULE_CRATE, "weight": 1, "amount_range": [1, 1]}])
	_loot(hub, LOOT_WEAPON, [], [{"kind": "weapon", "id": WEAPON_MEDIUM, "weight": 1, "amount_range": [1, 1]}])
	hub.freeze_all()
	_hub_cache = hub
	return hub


func _define(hub: RegistryHub, content_type: StringName, definition_id: String, data: Dictionary) -> void:
	var definition := ContentDefinition.from_raw({
		"id": definition_id,
		"name_key": "test.name",
		"enabled": true,
		"data": data,
	}, content_type, "test", "res://framework/tests/cases/test_combat.gd")
	hub.register(definition, "test")


func _damage_type(hub: RegistryHub, definition_id: String, armor_pierce: float, status: String) -> void:
	_define(hub, ContentTypes.DAMAGE_TYPE, definition_id, {
		"color": "#ffffff",
		"armor_pierce": armor_pierce,
		"status_effect": status,
	})


func _weapon(hub: RegistryHub, definition_id: String, weapon_class: String, damage: float, cooldown: float, accuracy: float, damage_type: String) -> void:
	_define(hub, ContentTypes.WEAPON, definition_id, {
		"kind": "direct",
		"damage": damage,
		"range": 300,
		"min_range": 0,
		"cooldown": cooldown,
		"accuracy": accuracy,
		"projectile_speed": 300,
		"splash": 0,
		"arc_deg": 270,
		"salvo": 1,
		"weapon_class": weapon_class,
		"assembly_profile": "yaw_pitch",
		"tier": 1,
		"weight": 1,
		"purchase_price": 100,
		"damage_type": damage_type,
	})


func _ability(hub: RegistryHub, definition_id: String, action: String, retreat_hull: float) -> void:
	var data := {"action": action}
	if retreat_hull >= 0.0:
		data["retreat_hull"] = retreat_hull
	_define(hub, ContentTypes.COMBAT_ABILITY, definition_id, data)


func _enemy(hub: RegistryHub, definition_id: String, hull_points: float, armor: float, socket_class: String, ability: String, loot_table: String) -> void:
	_define(hub, ContentTypes.ENEMY_ARCHETYPE, definition_id, {
		"enemy_class": "Light",
		"hull_points": hull_points,
		"armor": armor,
		"max_speed": 10,
		"turn_rate_deg": 40,
		"weapon_sockets": [socket_class],
		"combat_ability": ability,
		"loot_table": loot_table,
	})


func _encounter(hub: RegistryHub, definition_id: String, enemy_id: String) -> void:
	_define(hub, ContentTypes.ENCOUNTER_TABLE, definition_id, {
		"kind": "patrol",
		"danger": 1,
		"entries": [{"enemy_archetype": enemy_id, "weight": 1, "count_range": [1, 1]}],
	})


func _loot(hub: RegistryHub, definition_id: String, money_range: Array, entries: Array) -> void:
	var data := {"entries": entries}
	if not money_range.is_empty():
		data["money_range"] = money_range
	_define(hub, ContentTypes.LOOT_TABLE, definition_id, data)


## Builds a minimal playable-shape state: one port, one ship, no combat block yet.
func _state(hub: RegistryHub, hull_id: String, loadout: Array = [], durability: float = 100.0, seed_value: int = 4242) -> GameState:
	var ship := {
		"hull_id": hull_id,
		"boiler_id": "",
		"cargo_modules": [],
		"navigation_module_id": "",
		"safety_module_id": "",
		"passenger_cabin_id": "",
		"engineer_id": "",
		"navigator_id": "",
		"durability": durability,
		"coal": 0.0,
		"water": 0.0,
		"cargo": [],
	}
	if not loadout.is_empty():
		ship["weapon_loadout"] = loadout
	var state := GameState.new()
	state.data = {
		"schema_version": GameState.SCHEMA_VERSION,
		"run": {
			"seed": seed_value,
			"game_time": 0.0,
			"started_at": "2026-10-23T00:00:00",
			"starting_build": "test:starting_scenario/standard",
			"map_profile_id": "",
		},
		"player": {"money": 100, "reputation": 0, "unlocks": [], "debt": null},
		"world": {
			"current_port_id": PORT_ID,
			"start_port_id": PORT_ID,
			"discovered_ports": [PORT_ID],
			"routes": [],
			"ports": {PORT_ID: {"id": PORT_ID, "name_key": "test.port", "archetype_id": "", "facilities": []}},
		},
		"ship": ship,
		"contracts": {},
		"market": {},
		"port_memory": {},
		"npcs": [],
		"intelligence": {},
		"notices": [],
		"stats": GameState.STATS_DEFAULTS.duplicate(true),
		"victory": null,
	}
	state.ensure_campaign()
	return state


func _context(state: GameState) -> FakeContext:
	var context := FakeContext.new()
	context.state = state
	context.registries = _hub()
	return context


func _single_gun_loadout(weapon_id: String) -> Array:
	return [{"socket": "S1", "weapon_id": weapon_id}]


## ---------------------------------------------------------------------------
## Tests
## ---------------------------------------------------------------------------

func test_resolve_victory_applies_loot_and_durability() -> void:
	var hub := _hub()
	var state := _state(hub, HULL_SINGLE, _single_gun_loadout(WEAPON_LIGHT))
	var result := CombatService.resolve(hub, state, ENCOUNTER_SCRAP, 1234)
	assert_true(bool(result.get("ok", false)), "resolve succeeds: %s" % result)
	var battle: Dictionary = result["data"]["battle"]
	assert_eq(String(battle.get("outcome", "")), "victory", "unarmed 20 HP enemy is sunk")
	assert_eq(String(battle.get("id", "")), "battle_1", "battle sequence id starts at 1")
	assert_eq(int(battle.get("seed", 0)), 1234, "explicit seed is recorded")
	assert_true((battle.get("log", []) as Array).size() > 0, "battle log is written")
	assert_eq((battle.get("enemies", []) as Array).size(), 1, "one enemy instance spawned")
	assert_true(bool((battle["enemies"][0] as Dictionary).get("sunk", false)), "enemy is marked sunk")
	var loot: Dictionary = battle["loot"]
	assert_eq(int(loot.get("money", 0)), 10, "loot money range rolled")
	assert_eq(int((result["data"]["loot_applied"] as Dictionary).get("money", 0)), 10, "money is credited")
	assert_eq(int(state.money()), 110, "player money increased by loot")
	assert_eq(int((state.data["stats"] as Dictionary).get("income", 0)), 10, "loot is recorded as income")
	var rolled_items: Array = loot.get("items", [])
	assert_eq(rolled_items.size(), 1, "scrap loot is rolled as one item stack")
	assert_eq(ShipOps.cargo_amount(state.ship(), ITEM_SCRAP), int(rolled_items[0]["amount"]), "loot item amount lands in the cargo hold")
	assert_true(int(rolled_items[0]["amount"]) >= 2, "at least one loot roll landed")
	assert_almost_eq(float(state.ship()["durability"]), 100.0, 0.001, "undamaged player keeps full durability")
	assert_true(state.data.has("combat"), "battle record block is created")
	assert_eq(CombatService.battle_records(state).size(), 1, "one battle is persisted")


func test_same_seed_is_deterministic() -> void:
	var hub := _hub()
	var first_state := _state(hub, HULL_SINGLE, _single_gun_loadout(WEAPON_LIGHT))
	var second_state := _state(hub, HULL_SINGLE, _single_gun_loadout(WEAPON_LIGHT))
	var first := CombatService.resolve(hub, first_state, ENCOUNTER_SCRAP, 999)
	var second := CombatService.resolve(hub, second_state, ENCOUNTER_SCRAP, 999)
	assert_true(bool(first.get("ok", false)) and bool(second.get("ok", false)), "both resolutions succeed")
	assert_eq(first["data"], second["data"], "same state + seed + content = identical battle data")
	# Different seeds still produce a valid, seeded result (content here is fully
	# deterministic per hit, so only the recorded seed is guaranteed to differ).
	var other := CombatService.resolve(hub, _state(hub, HULL_SINGLE, _single_gun_loadout(WEAPON_LIGHT)), ENCOUNTER_SCRAP, 1000)
	assert_eq(int((other["data"]["battle"] as Dictionary).get("seed", 0)), 1000, "different seed is recorded")


func test_armor_and_damage_type_pierce() -> void:
	var hub := _hub()
	assert_almost_eq(CombatOps.armor_pierce_of(hub, hub.get_by_id(ContentTypes.WEAPON, WEAPON_LIGHT)), 0.1, 0.0001, "kinetic pierces 10%")
	assert_almost_eq(CombatOps.armor_pierce_of(hub, hub.get_by_id(ContentTypes.WEAPON, WEAPON_PIERCER)), 1.0, 0.0001, "piercing ignores armor")
	var kinetic := CombatService.resolve(hub, _state(hub, HULL_SINGLE, _single_gun_loadout(WEAPON_LIGHT)), ENCOUNTER_ARMORED, 77)
	var piercing := CombatService.resolve(hub, _state(hub, HULL_SINGLE, _single_gun_loadout(WEAPON_PIERCER)), ENCOUNTER_ARMORED, 77)
	assert_true(bool(kinetic.get("ok", false)) and bool(piercing.get("ok", false)), "both armored battles resolve")
	var kinetic_battle: Dictionary = kinetic["data"]["battle"]
	var piercing_battle: Dictionary = piercing["data"]["battle"]
	assert_eq(String(kinetic_battle["outcome"]), "victory", "armored enemy still sinks")
	var kinetic_rounds := int(kinetic_battle["rounds"])
	var piercing_rounds := int(piercing_battle["rounds"])
	assert_true(piercing_rounds < kinetic_rounds, "piercing kills faster (%d < %d)" % [piercing_rounds, kinetic_rounds])
	var first_kinetic_damage := _first_fire_damage(kinetic_battle)
	var first_piercing_damage := _first_fire_damage(piercing_battle)
	assert_almost_eq(first_kinetic_damage, 5.5, 0.001, "0.5 armor with 10% pierce leaves 5.5 of 10")
	assert_almost_eq(first_piercing_damage, 10.0, 0.001, "full pierce ignores armor")


func test_status_effect_adds_damage_over_time() -> void:
	var hub := _hub()
	var status := CombatService.resolve(hub, _state(hub, HULL_GUNNER, _single_gun_loadout(WEAPON_BURNER)), ENCOUNTER_TANK, 5)
	var plain := CombatService.resolve(hub, _state(hub, HULL_GUNNER, _single_gun_loadout(WEAPON_PLAIN_BURNER)), ENCOUNTER_TANK, 5)
	assert_true(bool(status.get("ok", false)) and bool(plain.get("ok", false)), "both burn variants resolve")
	var status_battle: Dictionary = status["data"]["battle"]
	var plain_battle: Dictionary = plain["data"]["battle"]
	assert_eq(String(status_battle["outcome"]), "victory", "28 HP tank is sunk")
	var status_entries := 0
	for entry in status_battle["log"]:
		if String((entry as Dictionary).get("source", "")) == "status" and String(entry.get("status", "")) == "burn":
			status_entries += 1
	assert_true(status_entries > 0, "burn damage-over-time is logged")
	assert_true(int(status_battle["rounds"]) < int(plain_battle["rounds"]),
		"burn kills faster than the identical plain weapon (%d < %d)" % [status_battle["rounds"], plain_battle["rounds"]])
	for entry in plain_battle["log"]:
		assert_ne(String((entry as Dictionary).get("source", "")), "status", "plain kinetic weapon applies no status")


func test_player_retreats_below_threshold() -> void:
	var hub := _hub()
	var state := _state(hub, HULL_SINGLE, _single_gun_loadout(WEAPON_LIGHT))
	var result := CombatService.resolve(hub, state, ENCOUNTER_CRUSHER, 21)
	assert_true(bool(result.get("ok", false)), "crusher battle resolves")
	var battle: Dictionary = result["data"]["battle"]
	assert_eq(String(battle["outcome"]), "retreated", "player disengages at the retreat threshold")
	assert_true(bool((battle["player"] as Dictionary).get("retreated", false)), "player retreat flag is set")
	var durability := float(state.ship()["durability"])
	assert_true(durability > 1.0 and durability < 100.0, "retreat keeps a damaged but positive durability")
	assert_eq(int((result["data"]["loot_applied"] as Dictionary).get("money", 0)), 0, "retreat grants no loot")
	assert_eq(int(state.money()), 100, "retreat does not change money")


func test_player_defeat_sets_minimum_durability() -> void:
	var hub := _hub()
	var state := _state(hub, HULL_SINGLE, _single_gun_loadout(WEAPON_LIGHT))
	var result := CombatService.resolve(hub, state, ENCOUNTER_GUNSHIP, 31)
	assert_true(bool(result.get("ok", false)), "defeat battle resolves")
	var battle: Dictionary = result["data"]["battle"]
	assert_eq(String(battle["outcome"]), "defeat", "an overwhelming first salvo sinks the player")
	assert_almost_eq(float(state.ship()["durability"]), CombatOps.MIN_DURABILITY_AFTER_DEFEAT, 0.001,
		"defeat floors durability at the rescue minimum")
	assert_eq((battle["loot"] as Dictionary).get("money", 0), 0, "defeat rolls no loot")


func test_enemy_retreat_gives_no_loot() -> void:
	var hub := _hub()
	var state := _state(hub, HULL_SINGLE, _single_gun_loadout(WEAPON_LIGHT))
	var result := CombatService.resolve(hub, state, ENCOUNTER_FLEEING, 41)
	assert_true(bool(result.get("ok", false)), "fleeing encounter resolves")
	var battle: Dictionary = result["data"]["battle"]
	assert_eq(String(battle["outcome"]), "enemy_retreated", "retreat_hull ability makes the enemy disengage")
	var enemy: Dictionary = battle["enemies"][0]
	assert_true(bool(enemy.get("retreated", false)) and not bool(enemy.get("sunk", true)), "enemy is retreated, not sunk")
	assert_eq((battle["loot"] as Dictionary).get("money", 0), 0, "no loot when nothing is sunk")


func test_loot_modules_and_weapon_salvage_apply() -> void:
	var hub := _hub()
	var module_state := _state(hub, HULL_SINGLE, _single_gun_loadout(WEAPON_LIGHT))
	var module_result := CombatService.resolve(hub, module_state, "test:encounter/module", 51)
	assert_true(bool(module_result.get("ok", false)), "module loot encounter resolves")
	var module_battle: Dictionary = module_result["data"]["battle"]
	var rolled_modules: Array = (module_battle["loot"] as Dictionary).get("modules", [])
	assert_true(rolled_modules.size() >= 1, "module loot is rolled")
	assert_eq(String(rolled_modules[0]["module_id"]), MODULE_CRATE, "module id comes from the loot table")
	assert_eq(WarehouseOps.module_qty(module_state, PORT_ID, MODULE_CRATE), int(rolled_modules[0]["amount"]),
		"module loot lands in the current-port warehouse")
	var weapon_state := _state(hub, HULL_SINGLE, _single_gun_loadout(WEAPON_LIGHT))
	var weapon_result := CombatService.resolve(hub, weapon_state, "test:encounter/weapon", 52)
	assert_true(bool(weapon_result.get("ok", false)), "weapon loot encounter resolves")
	var weapon_battle: Dictionary = weapon_result["data"]["battle"]
	var salvage: Array = (weapon_battle["loot"] as Dictionary).get("salvage", [])
	assert_true(salvage.size() >= 1, "weapon drop is recorded as salvage")
	assert_eq(String(salvage[0]["weapon_id"]), WEAPON_MEDIUM, "salvage references the dropped weapon")
	var expected_salvage := 0
	for row in salvage:
		expected_salvage += int(row["money"])
	assert_eq(int(weapon_battle["loot"]["money"]), expected_salvage, "salvage money is 50% of the dropped weapon price")
	assert_eq(int(weapon_state.money()), 100 + expected_salvage, "salvage money is credited")


func test_old_state_queries_are_read_only_and_command_creates_block() -> void:
	var hub := _hub()
	var state := _state(hub, HULL_SINGLE, _single_gun_loadout(WEAPON_LIGHT))
	var context := _context(state)
	assert_false(state.data.has("combat"), "fresh state has no combat block")
	var view: Dictionary = CombatViewQuery.execute({}, context)
	assert_true(bool(view.get("ok", false)), "combat.view works on an old save")
	assert_false(state.data.has("combat"), "combat.view does not create the combat block")
	var empty_log: Dictionary = CombatLogQuery.execute({}, context)
	assert_eq((empty_log["data"]["battles"] as Array).size(), 0, "old save has an empty battle log")
	assert_eq(int(empty_log["data"]["total"]), 0, "old save battle total is zero")
	var resolved: Dictionary = CombatCommands.resolve({"encounter_table_id": ENCOUNTER_SCRAP, "seed": 61}, context)
	assert_true(bool(resolved.get("ok", false)), "combat.resolve succeeds through the command")
	assert_true(bool(resolved.get("autosave", false)), "combat.resolve requests an autosave")
	assert_true(state.data.has("combat"), "the command creates the combat block")
	var log: Dictionary = CombatLogQuery.execute({"limit": 1}, context)
	assert_eq((log["data"]["battles"] as Array).size(), 1, "command result appears in combat.log")
	assert_eq(int(log["data"]["total"]), 1, "battle total counts the resolved encounter")


func test_command_errors_are_structured() -> void:
	var hub := _hub()
	var state := _state(hub, HULL_SINGLE, _single_gun_loadout(WEAPON_LIGHT))
	var context := _context(state)
	var unknown := CombatCommands.resolve({"encounter_table_id": "test:encounter/missing"}, context)
	assert_false(bool(unknown.get("ok", true)), "unknown encounter fails")
	assert_eq(String(unknown.get("error_code", "")), "unknown_encounter", "error code is unknown_encounter")
	assert_false(String(unknown.get("message_key", "")).is_empty(), "failure carries a message key")
	assert_false(state.data.has("combat"), "failed command leaves state untouched")
	var empty_context := _context(GameState.new())
	var no_run := CombatCommands.resolve({}, empty_context)
	assert_eq(String(no_run.get("error_code", "")), "no_run", "missing run reports no_run")


func test_player_weapon_rows_from_hull_sockets() -> void:
	var hub := _hub()
	var dual_ship := {"hull_id": HULL_DUAL}
	var rows := CombatOps.player_weapon_rows(hub, dual_ship)
	assert_eq(rows.size(), 2, "every hull socket maps to a weapon")
	assert_eq(String(rows[0]["socket"]), "S1", "weapon rows keep socket order")
	assert_eq(String(rows[0]["weapon_id"]), WEAPON_LIGHT, "Light socket picks the alphabetically first Light weapon")
	assert_eq(String(rows[1]["weapon_id"]), WEAPON_BURNER, "Medium socket picks the alphabetically first Medium weapon")
	assert_empty(CombatOps.unmounted_sockets(hub, dual_ship), "no unmounted sockets for the dual hull")
	var explicit := {"hull_id": HULL_DUAL, "weapon_loadout": [{"socket": "S2", "weapon_id": WEAPON_MEDIUM}]}
	var explicit_rows := CombatOps.player_weapon_rows(hub, explicit)
	assert_eq(String(explicit_rows[1]["weapon_id"]), WEAPON_MEDIUM, "explicit loadout overrides the default weapon")
	var view: Dictionary = CombatViewQuery.execute({}, _context(_state(hub, HULL_DUAL))).get("data", {})
	assert_eq((view["player"]["weapons"] as Array).size(), 2, "combat.view exposes the player armament")
	assert_eq((view["encounters"] as Array).size(), 10, "combat.view lists every encounter table")


func test_multi_enemy_encounter_targets_sequentially() -> void:
	var hub := _hub()
	var state := _state(hub, HULL_SINGLE, _single_gun_loadout(WEAPON_LIGHT))
	var result := CombatService.resolve(hub, state, "test:encounter/wing", 71)
	assert_true(bool(result.get("ok", false)), "two-enemy encounter resolves")
	var battle: Dictionary = result["data"]["battle"]
	var enemies: Array = battle["enemies"]
	assert_eq(enemies.size(), 2, "count_range [2,2] spawns two enemies")
	assert_eq(String(battle["outcome"]), "victory", "both light enemies are sunk")
	assert_true(bool((enemies[0] as Dictionary).get("sunk", false)), "first enemy is sunk")
	assert_true(bool((enemies[1] as Dictionary).get("sunk", false)), "second enemy is sunk")
	assert_true(int((enemies[1] as Dictionary).get("damage_taken", 0.0)) > 0.0, "fire switched to the second target")
	var first_targets := {}
	var second_targets := {}
	for entry in battle["log"]:
		var row: Dictionary = entry
		if String(row.get("source", "")) != "player" or String(row.get("action", "")) != "fire":
			continue
		first_targets[String(row.get("target", ""))] = true
	assert_contains(first_targets.keys(), "enemy_0", "player fired at the first enemy")
	assert_contains(first_targets.keys(), "enemy_1", "player fired at the second enemy after the first sank")


func test_battle_record_is_save_safe() -> void:
	var hub := _hub()
	var state := _state(hub, HULL_SINGLE, _single_gun_loadout(WEAPON_LIGHT))
	var result := CombatService.resolve(hub, state, ENCOUNTER_SCRAP, 81)
	assert_true(bool(result.get("ok", false)), "battle resolves")
	var serialized := JsonUtils.canonical_stringify(state.data)
	assert_false(serialized.is_empty(), "state with a combat record stringifies")
	var parsed_result := JsonUtils.parse(serialized)
	assert_true(bool(parsed_result.get("ok", false)), "serialized state parses back: %s" % parsed_result.get("error", ""))
	var parsed: Dictionary = parsed_result.get("value", {})
	var combat: Dictionary = parsed.get("combat", {})
	assert_eq((combat.get("battles", []) as Array).size(), 1, "combat record survives a JSON round-trip")
	var battle: Dictionary = (combat["battles"] as Array)[0]
	assert_eq(String(battle.get("outcome", "")), "victory", "outcome survives the round-trip")
	assert_eq(String(battle.get("id", "")), "battle_1", "battle id survives the round-trip")
	assert_false((battle.get("log", []) as Array).is_empty(), "battle log survives the round-trip")
	var clone := state.clone()
	assert_eq(clone.hash(), state.hash(), "cloning a state with a combat record is hash-stable")


func test_core_content_resolves() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var hub := context.registries
	for content_type in [
		ContentTypes.WEAPON, ContentTypes.DAMAGE_TYPE, ContentTypes.COMBAT_ABILITY,
		ContentTypes.ENEMY_ARCHETYPE, ContentTypes.ENCOUNTER_TABLE, ContentTypes.LOOT_TABLE,
	]:
		assert_true(hub.get_all(content_type).size() > 0, "core registers combat content: %s" % content_type)
	var state := _state(hub, "core:hull/small_efficient")
	var result := CombatService.resolve(hub, state, "core:encounter_table/coastal_patrol", 2026)
	assert_true(bool(result.get("ok", false)), "real core encounter resolves: %s" % result)
	var battle: Dictionary = result["data"]["battle"]
	assert_contains(["victory", "defeat", "retreated", "enemy_retreated"], battle.get("outcome"), "outcome is a known terminal state")
	assert_true((battle.get("log", []) as Array).size() > 0, "core battle writes a log")
	assert_true((battle.get("enemies", []) as Array).size() >= 1, "core encounter spawns at least one enemy")
	assert_true(float(state.ship()["durability"]) >= CombatOps.MIN_DURABILITY_AFTER_DEFEAT, "durability stays playable")


func test_combat_commands_and_queries_are_registered() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	assert_true(context.commands.has(&"combat.resolve"), "combat.resolve is registered on the command bus")
	assert_true(context.queries.has(&"combat.view"), "combat.view is registered on the query bus")
	assert_true(context.queries.has(&"combat.log"), "combat.log is registered on the query bus")
	var started := context.commands.execute(&"run.start", {"seed": 4321})
	assert_true(bool(started.get("ok", false)), "a real run starts for the combat end-to-end check: %s" % started)
	var view := context.queries.execute(&"combat.view", {})
	assert_true(bool(view.get("ok", false)), "combat.view works on a real run")
	assert_false((view["data"]["encounters"] as Array).is_empty(), "real run exposes encounter tables")
	assert_false(((view["data"]["player"] as Dictionary)["weapons"] as Array).is_empty(), "real run resolves hull weapons")
	var resolved := context.commands.execute(&"combat.resolve", {
		"encounter_table_id": "core:encounter_table/coastal_patrol",
		"seed": 99,
	})
	assert_true(bool(resolved.get("ok", false)), "combat.resolve runs through the command bus: %s" % resolved)
	assert_contains(["victory", "defeat", "retreated", "enemy_retreated"],
		(resolved["data"]["battle"] as Dictionary).get("outcome"), "command result carries a terminal outcome")
	var log := context.queries.execute(&"combat.log", {"limit": 5})
	assert_eq(int(log["data"]["total"]), 1, "the resolved encounter is in the persisted log")
	assert_eq((log["data"]["battles"] as Array).size(), 1, "combat.log returns the battle summary")


func test_missing_weapon_class_is_reported_for_both_sides() -> void:
	var hub := _hub()
	# Player hull has a Tower socket; enemy weak also has a Tower socket. Neither side
	# has a Tower weapon, so both skips must be visible in the battle record.
	var state := _state(hub, HULL_TOWER)
	var result := CombatService.resolve(hub, state, ENCOUNTER_SCRAP, 101)
	assert_true(bool(result.get("ok", false)), "battle still resolves with unmounted sockets")
	var battle: Dictionary = result["data"]["battle"]
	var diagnostics: Array = battle.get("diagnostics", [])
	assert_eq(diagnostics.size(), 2, "one player skip + one enemy skip are reported")
	var player_diag: Dictionary = {}
	var enemy_diag: Dictionary = {}
	for entry in diagnostics:
		var row: Dictionary = entry
		if String(row.get("side", "")) == "player":
			player_diag = row
		elif String(row.get("side", "")) == "enemy":
			enemy_diag = row
	assert_eq(String(player_diag.get("socket_class", "")), "Tower", "player skip names the socket class")
	assert_eq(String(player_diag.get("socket", "")), "S1", "player skip names the socket")
	assert_eq(String(player_diag.get("reason", "")), "weapon_class_missing", "player skip carries a reason")
	assert_eq(String(enemy_diag.get("socket_class", "")), "Tower", "enemy skip names the socket class")
	assert_eq(String(enemy_diag.get("reason", "")), "weapon_class_missing", "enemy skip carries the same reason")
	assert_eq((battle["player"]["unmounted_sockets"] as Array).size(), 1, "player view lists the unmounted socket")
	assert_eq((battle["enemies"][0]["unmounted_sockets"] as Array).size(), 1, "enemy view lists the unmounted socket")
	var view: Dictionary = CombatViewQuery.execute({}, _context(state)).get("data", {})
	assert_eq((view["player"]["unmounted_sockets"] as Array).size(), 1, "combat.view exposes unmounted player sockets")
	assert_eq(String(view["player"]["unmounted_sockets"][0]["reason"]), "weapon_class_missing", "view carries the reason")


func test_missing_loot_table_is_reported_in_battle_diagnostics() -> void:
	var hub := _hub()
	var state := _state(hub, HULL_SINGLE, _single_gun_loadout(WEAPON_LIGHT))
	var result := CombatService.resolve(hub, state, "test:encounter/bad_loot", 111)
	assert_true(bool(result.get("ok", false)), "battle resolves even when the loot table is missing")
	var battle: Dictionary = result["data"]["battle"]
	assert_eq(String(battle["outcome"]), "victory", "unarmed enemy is sunk")
	var loot_diag := {}
	for entry in battle.get("diagnostics", []):
		var row: Dictionary = entry
		if String(row.get("side", "")) == "loot":
			loot_diag = row
	assert_false(loot_diag.is_empty(), "missing loot table produces a diagnostic")
	assert_eq(String(loot_diag.get("reason", "")), "loot_table_missing", "diagnostic reason is loot_table_missing")
	assert_eq(String(loot_diag.get("loot_table", "")), "test:loot/missing", "diagnostic names the missing table")
	assert_eq(int((battle["loot"] as Dictionary).get("money", -1)), 0, "no loot is fabricated")


func test_explicit_loadout_enforces_socket_class() -> void:
	var hub := _hub()
	# Light socket + Medium weapon in the explicit loadout: the class gate must skip it
	# (no silent fallback to the default Light weapon) and record a mismatch diagnostic.
	var state := _state(hub, HULL_SINGLE, _single_gun_loadout(WEAPON_BURNER))
	var result := CombatService.resolve(hub, state, ENCOUNTER_SCRAP, 121)
	assert_true(bool(result.get("ok", false)), "battle still resolves with a mismatched loadout")
	var battle: Dictionary = result["data"]["battle"]
	assert_true((battle["player"]["weapons"] as Array).is_empty(), "mismatched explicit weapon is not mounted")
	var mismatch := {}
	for entry in battle.get("diagnostics", []):
		var row: Dictionary = entry
		if String(row.get("side", "")) == "player" and String(row.get("reason", "")) == "weapon_class_mismatch":
			mismatch = row
	assert_false(mismatch.is_empty(), "explicit class mismatch is recorded")
	assert_eq(String(mismatch.get("socket", "")), "S1", "mismatch names the socket")
	assert_eq(String(mismatch.get("socket_class", "")), "Light", "mismatch names the socket class")
	assert_eq(String(mismatch.get("weapon_id", "")), WEAPON_BURNER, "mismatch names the rejected weapon")
	var view: Dictionary = CombatViewQuery.execute({}, _context(state)).get("data", {})
	assert_eq(String(view["player"]["unmounted_sockets"][0]["reason"]), "weapon_class_mismatch",
		"combat.view exposes the mismatch reason")


func test_settlement_key_makes_resolve_idempotent() -> void:
	var hub := _hub()
	var state := _state(hub, HULL_SINGLE, _single_gun_loadout(WEAPON_LIGHT))
	var context := _context(state)
	var first := CombatCommands.resolve({
		"encounter_table_id": ENCOUNTER_SCRAP,
		"seed": 131,
		"encounter_id": "encounter_alpha",
	}, context)
	assert_true(bool(first.get("ok", false)), "first settlement succeeds: %s" % first)
	assert_false(bool(first["data"].get("already_settled", true)), "first settlement is not a replay")
	assert_true(bool(first.get("autosave", false)), "first settlement requests an autosave")
	assert_eq((first.get("events", []) as Array).size(), 1, "first settlement publishes combat.resolved")
	var battle_id := String(first["data"]["battle"].get("id", ""))
	assert_eq(String(first["data"]["battle"].get("settlement_key", "")), "encounter_alpha", "key is persisted on the battle")
	var money_after_first := int(state.money())
	var second := CombatCommands.resolve({
		"encounter_table_id": ENCOUNTER_SCRAP,
		"seed": 131,
		"encounter_id": "encounter_alpha",
	}, context)
	assert_true(bool(second.get("ok", false)), "replayed settlement succeeds")
	assert_true(bool(second["data"].get("already_settled", false)), "same key replays the settled battle")
	assert_eq(String(second["data"]["battle"].get("id", "")), battle_id, "replay returns the existing battle id")
	assert_eq(int(state.money()), money_after_first, "replay does not pay loot twice")
	assert_eq(CombatService.battle_records(state).size(), 1, "replay does not append a battle record")
	assert_eq((second.get("events", []) as Array).size(), 0, "replay publishes no event")
	assert_false(bool(second.get("autosave", false)), "replay does not request an autosave")
	assert_eq(int((second["data"]["loot_applied"] as Dictionary).get("money", 0)),
		int((first["data"]["loot_applied"] as Dictionary).get("money", 0)), "replay reports the original payout")
	# Empty key keeps the "every call is a new battle" semantics.
	var fresh := CombatService.resolve(hub, state, ENCOUNTER_SCRAP, 131, "")
	assert_eq(String(fresh["data"]["battle"].get("id", "")), "battle_2", "no key starts a new battle")
	assert_eq(CombatService.battle_records(state).size(), 2, "unkeyed battles are all appended")


func test_settlement_keys_are_pruned_with_the_battle_log() -> void:
	var hub := _hub()
	var state := _state(hub, HULL_SINGLE, _single_gun_loadout(WEAPON_LIGHT))
	for index in CombatService.MAX_BATTLES + 1:
		var resolved := CombatService.resolve(hub, state, ENCOUNTER_SCRAP, 141, "enc_%d" % index)
		assert_true(bool(resolved.get("ok", false)), "keyed battle %d resolves" % index)
	var combat: Dictionary = CombatService.ensure_state(state)
	assert_eq((combat["battles"] as Array).size(), CombatService.MAX_BATTLES, "battle log stays capped")
	assert_eq((combat["settlements"] as Dictionary).size(), CombatService.MAX_BATTLES, "dropped battles release their keys")
	var replayed := CombatService.resolve(hub, state, ENCOUNTER_SCRAP, 141, "enc_0")
	assert_false(bool(replayed["data"].get("already_settled", true)),
		"a key whose battle was trimmed is settled fresh instead of replaying")


func test_combat_stream_is_registered() -> void:
	assert_contains(RngService.STREAM_NAMES, RngService.STREAM_COMBAT, "combat stream is registered")
	assert_eq(CombatOps.STREAM_COMBAT, RngService.STREAM_COMBAT, "CombatOps uses the registered stream name")
	var names := {}
	for name in RngService.STREAM_NAMES:
		names[String(name)] = true
	assert_eq(names.size(), RngService.STREAM_NAMES.size(), "stream names stay unique")


## ---------------------------------------------------------------------------
## Assertion helpers
## ---------------------------------------------------------------------------

func _first_fire_damage(battle: Dictionary) -> float:
	for entry in battle.get("log", []):
		var row: Dictionary = entry
		if String(row.get("source", "")) == "player" and String(row.get("action", "")) == "fire":
			return float(row.get("damage", 0.0))
	return -1.0
