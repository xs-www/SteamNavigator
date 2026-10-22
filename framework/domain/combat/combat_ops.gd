class_name CombatOps
extends RefCounted
## @static-doc
## 作用：Phase D1 战斗自动结算的纯规则层。把「玩家船 + encounter_table 抽出的敌舰组合 +
## 武器/伤害类型/敌人原型/能力数据」解析成一次确定性、无状态副作用的自动战斗，输出
## 回合日志、双方耐久变化、击沉 / 撤退结论与战利品 roll。
##
## 关键依赖：`RegistryHub`（weapons / damage_types / combat_abilities /
## enemy_archetypes / loot_tables）、`ShipOps.durability_max`、`RngService`。
##
## ## 契约与约束
## - **纯函数**：只读 `hub` / `ship` / 内容定义，不读写 `GameState`；状态落盘与战利品
##   发放由 `CombatService` 负责，便于单测与幂等控制。
## - **确定性**：随机只来自调用方传入的 `RandomNumberGenerator`（`RngService` 的
##   `combat` 命名流）。武器按解析顺序开火、敌舰按生成顺序行动；同 seed + 同初始
##   耐久 + 同内容 = 完全相同的结果（日志与战利品都一致）。
## - **抽象回合制**：1 回合 = 1 战斗秒；武器按 `cooldown` 就绪，双方同回合同时开火。
##   没有空间/弹道模型（D1 明确不做战术层）；`range` / `min_range` 只写入 weapon
##   row view，不参与武器选择或命中判定。
## - **伤害公式**：`effective = damage × (1 − armor × (1 − armor_pierce))`；
##   `damage_types.armor_pierce` 是唯一穿甲来源；`status_effect != none` 的命中会给
##   目标挂 3 秒持续伤害（burn 1.0 / shock 0.5 / flood 1.5 每回合，忽略护甲）。
## - **玩家战斗耐久池**：`durability × PLAYER_HIT_POINTS_PER_DURABILITY`（内容层
##   `max_durability` 是结构耐久 0–100，敌舰 `hull_points` 是战斗 HP；D1 用固定倍率
##   把两者放到同一量级）。战后的结构耐久 = `hp / PLAYER_HIT_POINTS_PER_DURABILITY`，
##   击沉时落到 1.0（救援/维修入口沿用现有维修系统）。
## - **玩家护甲**：`PLAYER_ARMOR` 常量。hull Schema 目前没有 armor 字段，等 Phase E/
##   模块 condition 派生后再内容化，注释即 TODO。
## - **内容字段消费范围（D1）**：`enemy_archetypes` 的 `hull_points / armor /
##   weapon_sockets / combat_ability / loot_table` 参与结算；`max_speed / turn_rate_deg /
##   enemy_class` 只写入 battle 视图（战术层后置）。`combat_abilities` 目前只消费
##   `retreat_hull`（撤退阈值）；`action / target_priority / preferred_range` 是给后续
##   战术 AI 的声明式参数，D1 自动结算不使用。
## - **结局**：`victory`（敌舰全灭）/ `enemy_retreated`（敌舰全部脱离）/ `retreated`
##   （玩家耐久比例 ≤ `PLAYER_RETREAT_RATIO` 主动脱离）/ `defeat`（玩家 HP ≤ 0）。
##   只有 `victory` 对**已击沉**敌舰 roll 战利品；撤退/击沉玩家不发奖励。
## - **内容缺失诊断（D1-FIX）**：未知 weapon class 的 socket 会被 skip，但同一份
##   `battle.diagnostics[]` 会记录 `{side, index?, socket, socket_class,
##   reason:"weapon_class_missing"}`；未知 loot_table / loot entry 也记录
##   `reason:"loot_table_missing"` / `"loot_entry_missing"`。敌我双方规则一致；
##   `player.view.unmounted_sockets` / `enemy.view.unmounted_sockets` 提供同源视图。
##   校验器（CrossReferenceValidator）在内容层把这些 class 缺口升级为 error。
## @end-static-doc

## 战斗随机流名（RngService 的命名流；D1 新增，不影响其他流）。
const STREAM_COMBAT := &"combat"
## 一次自动结算的最大回合数（1 回合 = 1 战斗秒）。超过即按当前状态判终局。
const MAX_ROUNDS := 180
## 玩家结构耐久 → 战斗 HP 的倍率（见文件头「玩家战斗耐久池」）。
const PLAYER_HIT_POINTS_PER_DURABILITY := 2.5
## 玩家护甲（hull Schema 无 armor 字段前的框架常量；未来内容化）。
const PLAYER_ARMOR := 0.15
## 玩家主动脱离阈值：耐久比例低于该值即撤退（自动结算的选择策略）。
const PLAYER_RETREAT_RATIO := 0.25
## 击沉后最低保留的结构耐久（避免把存档写成 0 而无法继续游戏）。
const MIN_DURABILITY_AFTER_DEFEAT := 1.0
## 状态效果持续时间（回合）。
const STATUS_DURATION_ROUNDS := 3
## 每回合状态持续伤害（忽略护甲）。
const STATUS_DAMAGE_PER_ROUND := {
	"burn": 1.0,
	"shock": 0.5,
	"flood": 1.5,
}
## 每个战利品表的抽取次数区间。
const LOOT_ROLLS_PER_TABLE := [1, 2]
## 武器类掉落没有背包/仓库槽位，D1 折算为残骸回收金额（purchase_price × 该比例）。
const WEAPON_SALVAGE_RATIO := 0.5
## 日志最多保留的条目数（避免存档膨胀；超出后只记 truncated 标记）。
const MAX_LOG_ENTRIES := 240


## Resolves one encounter for `ship` without touching GameState.
## `encounter_table` is a `ContentDefinition` of type `encounter_tables`.
## Returns `{ok, reason, battle}`; `battle` is JSON-safe and deterministic.
static func resolve(
	hub: RegistryHub,
	ship: Dictionary,
	encounter_table: ContentDefinition,
	seed_value: int
) -> Dictionary:
	if hub == null or encounter_table == null:
		return {"ok": false, "reason": "missing_content", "battle": {}}
	var rng := RngService.new(seed_value).stream(STREAM_COMBAT, "battle")
	var player := _player_combatant(hub, ship)
	if player.is_empty():
		return {"ok": false, "reason": "invalid_player_ship", "battle": {}}
	var encounter_data: Dictionary = encounter_table.data
	var enemies := _spawn_enemies(hub, encounter_data, rng)
	if enemies.is_empty():
		return {"ok": false, "reason": "empty_encounter", "battle": {}}

	var battle := {
		"seed": seed_value,
		"encounter_table_id": encounter_table.id,
		"encounter_kind": String(encounter_data.get("kind", "")),
		"danger": float(encounter_data.get("danger", 0.0)),
		"outcome": "",
		"rounds": 0,
		"player": player["view"],
		"enemies": [],
		"log": [],
		"log_truncated": false,
		"loot": _empty_loot(),
		"diagnostics": [],
	}
	battle["player"]["weapons"] = player["weapon_rows"]
	battle["player"]["hit_points"] = player["hp"]
	battle["player"]["hit_points_after"] = player["hp"]
	battle["player"]["damage_taken"] = 0.0
	battle["player"]["retreated"] = false
	if not (player["view"]["unmounted_sockets"] as Array).is_empty():
		for missing in player["view"]["unmounted_sockets"]:
			(battle["diagnostics"] as Array).append({
				"side": "player",
				"socket": String((missing as Dictionary).get("socket", "")),
				"socket_class": String((missing as Dictionary).get("socket_class", "")),
				"reason": "weapon_class_missing",
			})
	for enemy in enemies:
		battle["enemies"].append(enemy["view"])
		if (enemy["view"]["unmounted_sockets"] as Array).is_empty():
			continue
		for missing in enemy["view"]["unmounted_sockets"]:
			(battle["diagnostics"] as Array).append({
				"side": "enemy",
				"index": int(enemy["index"]),
				"socket": "",
				"socket_class": String((missing as Dictionary).get("socket_class", "")),
				"reason": "weapon_class_missing",
			})

	_run_battle(hub, battle, player, enemies, rng)
	battle["rounds"] = int(battle["rounds"])
	battle["player"]["durability_after"] = _durability_after(
		float(battle["player"]["hit_points_after"]), float(battle["player"]["durability_before"])
	)
	if String(battle["outcome"]) == "victory":
		var loot_result := _roll_loot(hub, enemies, rng)
		battle["loot"] = loot_result["loot"]
		for diagnostic in loot_result["diagnostics"]:
			(battle["diagnostics"] as Array).append(diagnostic)
	return {"ok": true, "reason": "", "battle": battle}


## Compact, UI/test-facing view of a persisted battle record. Returns a deep
## copy so callers cannot mutate the stored log through the ViewModel.
static func battle_view(battle: Dictionary) -> Dictionary:
	return (battle as Dictionary).duplicate(true)


## Sorted encounter-table summaries for `combat.view` (deterministic order by id).
static func encounter_summaries(hub: RegistryHub) -> Array:
	var summaries: Array = []
	var definitions := hub.get_all(ContentTypes.ENCOUNTER_TABLE)
	definitions.sort_custom(func(left: ContentDefinition, right: ContentDefinition) -> bool:
		return left.id < right.id
	)
	for definition in definitions:
		var data: Dictionary = definition.data
		var entries: Array = Array(data.get("entries", []))
		summaries.append({
			"id": definition.id,
			"name_key": definition.name_key,
			"description_key": definition.description_key,
			"kind": String(data.get("kind", "")),
			"danger": float(data.get("danger", 0.0)),
			"entry_count": entries.size(),
		})
	return summaries


## Resolves the player's armament: an explicit `ship.weapon_loadout` /
## `ship.weapons` list wins when it contains resolvable weapon ids; otherwise every
## hull socket class maps to the alphabetically-first weapon definition that fits
## the socket class. Returns rows `{socket, weapon_id, weapon_class, damage}`.
## `range` is reported for UI only and never selects or gates a shot.
static func player_weapon_rows(hub: RegistryHub, ship: Dictionary) -> Array:
	var hull := hub.get_by_id(ContentTypes.HULL, String(ship.get("hull_id", "")))
	if hull == null:
		return []
	var sockets: Array = Array((hull.data as Dictionary).get("weapon_sockets", []))
	var explicit := _explicit_loadout(hub, ship)
	var rows: Array = []
	for socket in sockets:
		var socket_entry: Dictionary = socket
		var socket_name := String(socket_entry.get("name", ""))
		var socket_class := String(socket_entry.get("socket_class", ""))
		var weapon: ContentDefinition = null
		if not explicit.is_empty():
			weapon = explicit.get(socket_name, null)
		if weapon == null:
			weapon = _default_weapon_for_socket(hub, socket_class)
		if weapon == null:
			continue
		rows.append(_weapon_row(socket_name, weapon))
	return rows


## Hull sockets skipped because no weapon definition fits their class. Reported in
## the battle record (`player.view.unmounted_sockets`) and via the view query, so a
## content gap is visible instead of silently removing armament; the same shape is
## used for enemy sockets. D1: unknown socket class (no weapon with matching
## `weapon_class` / `mount_class`) is skipped at runtime and recorded here.
static func unmounted_sockets(hub: RegistryHub, ship: Dictionary) -> Array:
	var hull := hub.get_by_id(ContentTypes.HULL, String(ship.get("hull_id", "")))
	if hull == null:
		return []
	var explicit := _explicit_loadout(hub, ship)
	var missing: Array = []
	for socket in hull.data.get("weapon_sockets", []):
		var socket_entry: Dictionary = socket
		var socket_name := String(socket_entry.get("name", ""))
		var socket_class := String(socket_entry.get("socket_class", ""))
		if explicit.has(socket_name):
			continue
		if _default_weapon_for_socket(hub, socket_class) == null:
			missing.append({
				"socket": socket_name,
				"socket_class": socket_class,
				"reason": "weapon_class_missing",
			})
	return missing


## True when the damage type's status effect should be applied by hits.
static func status_of(hub: RegistryHub, weapon: ContentDefinition) -> String:
	var damage_type_id := String((weapon.data as Dictionary).get("damage_type", ""))
	if damage_type_id.is_empty():
		return "none"
	var damage_type := hub.get_by_id(ContentTypes.DAMAGE_TYPE, damage_type_id)
	if damage_type == null:
		return "none"
	return String((damage_type.data as Dictionary).get("status_effect", "none"))


## 0–1 share of damage that ignores armor, from `damage_types.armor_pierce`.
static func armor_pierce_of(hub: RegistryHub, weapon: ContentDefinition) -> float:
	var damage_type_id := String((weapon.data as Dictionary).get("damage_type", ""))
	if damage_type_id.is_empty():
		return 0.0
	var damage_type := hub.get_by_id(ContentTypes.DAMAGE_TYPE, damage_type_id)
	if damage_type == null:
		return 0.0
	return clampf(float((damage_type.data as Dictionary).get("armor_pierce", 0.0)), 0.0, 1.0)


## ---------------------------------------------------------------------------
## Internal resolution
## ---------------------------------------------------------------------------

static func _player_combatant(hub: RegistryHub, ship: Dictionary) -> Dictionary:
	var hull_id := String(ship.get("hull_id", ""))
	var hull := hub.get_by_id(ContentTypes.HULL, hull_id)
	if hull == null or ship.is_empty():
		return {}
	var max_durability := ShipOps.durability_max(hub, ship)
	if max_durability <= 0.0:
		return {}
	var durability := clampf(float(ship.get("durability", max_durability)), MIN_DURABILITY_AFTER_DEFEAT, max_durability)
	var hp := durability * PLAYER_HIT_POINTS_PER_DURABILITY
	var weapon_rows := player_weapon_rows(hub, ship)
	var weapons: Array = []
	for row in weapon_rows:
		var definition := hub.get_by_id(ContentTypes.WEAPON, String(row.get("weapon_id", "")))
		if definition == null:
			continue
		weapons.append(_weapon_state(definition))
	return {
		"is_player": true,
		"hp": hp,
		"max_hp": max_durability * PLAYER_HIT_POINTS_PER_DURABILITY,
		"armor": PLAYER_ARMOR,
		"weapons": weapons,
		"statuses": {},
		"damage_taken": 0.0,
		"view": {
			"hull_id": hull_id,
			"durability_before": durability,
			"durability_after": durability,
			"hit_points": hp,
			"hit_points_after": hp,
			"armor": PLAYER_ARMOR,
			"unmounted_sockets": unmounted_sockets(hub, ship),
		},
		"weapon_rows": weapon_rows,
	}


static func _spawn_enemies(hub: RegistryHub, encounter_data: Dictionary, rng: RandomNumberGenerator) -> Array:
	var entries: Array = Array(encounter_data.get("entries", []))
	if entries.is_empty():
		return []
	var picked: Variant = RngService.choose_weighted(rng, entries, "weight")
	if not (picked is Dictionary):
		return []
	var entry: Dictionary = picked
	var archetype := hub.get_by_id(ContentTypes.ENEMY_ARCHETYPE, String(entry.get("enemy_archetype", "")))
	if archetype == null:
		return []
	var count_range: Array = Array(entry.get("count_range", [1, 1]))
	if count_range.is_empty():
		count_range = [1, 1]
	var count := rng.randi_range(
		int(count_range[0]),
		int(count_range[mini(1, count_range.size() - 1)])
	)
	count = clampi(count, 1, 8)
	var ability := hub.get_by_id(ContentTypes.COMBAT_ABILITY, String((archetype.data as Dictionary).get("combat_ability", "")))
	var enemies: Array = []
	for index in count:
		var enemy := _enemy_combatant(hub, archetype, ability, index)
		if not enemy.is_empty():
			enemies.append(enemy)
	return enemies


static func _enemy_combatant(hub: RegistryHub, archetype: ContentDefinition, ability: ContentDefinition, index: int) -> Dictionary:
	var data: Dictionary = archetype.data
	var hull_points := maxf(1.0, float(data.get("hull_points", 1.0)))
	var weapons: Array = []
	var unmounted: Array = []
	var sockets: Array = Array(data.get("weapon_sockets", []))
	for socket_index in sockets.size():
		var socket_class := String(sockets[socket_index])
		var definition := _default_weapon_for_socket(hub, socket_class)
		if definition == null:
			unmounted.append({
				"socket": "socket_%d" % socket_index,
				"socket_class": socket_class,
				"reason": "weapon_class_missing",
			})
			continue
		weapons.append(_weapon_state(definition))
	var ability_id := ability.id if ability != null else ""
	var retreat_hull := -1.0
	if ability != null:
		retreat_hull = float((ability.data as Dictionary).get("retreat_hull", -1.0))
	return {
		"is_player": false,
		"index": index,
		"archetype": archetype,
		"hp": hull_points,
		"max_hp": hull_points,
		"armor": clampf(float(data.get("armor", 0.0)), 0.0, 0.8),
		"weapons": weapons,
		"statuses": {},
		"damage_taken": 0.0,
		"ability_id": ability_id,
		"retreat_hull": retreat_hull,
		"sunk": false,
		"retreated": false,
		"view": {
			"index": index,
			"archetype_id": archetype.id,
			"enemy_class": String(data.get("enemy_class", "")),
			"max_speed": float(data.get("max_speed", 0.0)),
			"ability_id": ability_id,
			"hull_points": hull_points,
			"hull_points_after": hull_points,
			"armor": clampf(float(data.get("armor", 0.0)), 0.0, 0.8),
			"weapon_ids": _weapon_ids(weapons),
			"unmounted_sockets": unmounted,
			"sunk": false,
			"retreated": false,
			"damage_taken": 0.0,
		},
	}


static func _weapon_state(definition: ContentDefinition) -> Dictionary:
	return {
		"definition": definition,
		"cooldown": maxf(0.25, float((definition.data as Dictionary).get("cooldown", 1.0))),
		"remaining": 0.0,
	}


static func _run_battle(hub: RegistryHub, battle: Dictionary, player: Dictionary, enemies: Array, rng: RandomNumberGenerator) -> void:
	var rounds := 0
	var outcome := ""
	while rounds < MAX_ROUNDS:
		rounds += 1
		battle["rounds"] = rounds
		_tick_statuses(battle, player, enemies)
		_tick_enemy_retreats(battle, enemies)
		if _all_enemies_out(enemies):
			outcome = "victory" if _sunk_count(enemies) > 0 else "enemy_retreated"
			break
		var player_actions := _collect_fire_actions(hub, battle, player, enemies, true, rng)
		var enemy_actions := _collect_fire_actions(hub, battle, player, enemies, false, rng)
		_apply_actions(battle, player, enemies, player_actions, enemy_actions)
		if float(player["hp"]) <= 0.0:
			player["hp"] = 0.0
			outcome = "defeat"
			break
		if _all_enemies_out(enemies):
			outcome = "victory" if _sunk_count(enemies) > 0 else "enemy_retreated"
			break
		if float(player["hp"]) / maxf(1.0, float(player["max_hp"])) <= PLAYER_RETREAT_RATIO:
			outcome = "retreated"
			player["view"]["retreated"] = true
			break
	if outcome.is_empty():
		# Round cap reached: treat as an inconclusive disengagement (no loot).
		outcome = "retreated"
		player["view"]["retreated"] = true
	battle["outcome"] = outcome
	_sync_views(battle, player, enemies)


## Applies per-round damage-over-time from active damage-type statuses. Status
## damage ignores armor (documented simplification; no DOT matrix yet).
static func _tick_statuses(battle: Dictionary, player: Dictionary, enemies: Array) -> void:
	for target in [player] + enemies:
		var statuses: Dictionary = target["statuses"]
		if statuses.is_empty():
			continue
		for kind in statuses.keys():
			var remaining := int(statuses[kind])
			if remaining <= 0:
				statuses.erase(kind)
				continue
			var damage := float(STATUS_DAMAGE_PER_ROUND.get(String(kind), 0.0))
			if damage <= 0.0:
				statuses.erase(kind)
				continue
			_damage_combatant(target, damage)
			_log(battle, {
				"round": int(battle["rounds"]),
				"source": "status",
				"status": String(kind),
				"target": "player" if bool(target["is_player"]) else "enemy_%d" % int(target["index"]),
				"damage": damage,
			})
			statuses[kind] = remaining - 1


static func _tick_enemy_retreats(battle: Dictionary, enemies: Array) -> bool:
	var retreated_any := false
	for enemy in enemies:
		if bool(enemy["sunk"]) or bool(enemy["retreated"]):
			continue
		var threshold := float(enemy["retreat_hull"])
		if threshold <= 0.0:
			continue
		if float(enemy["hp"]) / maxf(1.0, float(enemy["max_hp"])) >= threshold:
			continue
		enemy["retreated"] = true
		enemy["view"]["retreated"] = true
		retreated_any = true
		_log(battle, {
			"round": int(battle["rounds"]),
			"source": "enemy",
			"action": "retreat",
			"target": "enemy_%d" % int(enemy["index"]),
			"ability_id": String(enemy["ability_id"]),
		})
	return retreated_any


## Collects fire events for one side. Player targets the first non-sunk enemy;
## enemies all target the player. Returns rolls already resolved (hit or miss),
## so both sides' damage is applied simultaneously.
static func _collect_fire_actions(
	hub: RegistryHub,
	battle: Dictionary,
	player: Dictionary,
	enemies: Array,
	player_side: bool,
	rng: RandomNumberGenerator
) -> Array:
	var actions: Array = []
	var target: Variant = null
	if player_side:
		for enemy in enemies:
			if not bool(enemy["sunk"]) and not bool(enemy["retreated"]):
				target = enemy
				break
		if target == null:
			return actions
	else:
		target = player
	var shooters: Array = [player] if player_side else enemies
	for shooter in shooters:
		if not player_side and (bool(shooter["sunk"]) or bool(shooter["retreated"])):
			continue
		var weapons: Array = shooter["weapons"]
		for weapon_state in weapons:
			var remaining := float(weapon_state["remaining"]) - 1.0
			if remaining > 0.0:
				weapon_state["remaining"] = remaining
				continue
			weapon_state["remaining"] = float(weapon_state["cooldown"])
			actions.append(_fire_weapon(hub, battle, shooter, weapon_state, target, rng))
	return actions


static func _fire_weapon(
	hub: RegistryHub,
	battle: Dictionary,
	shooter: Dictionary,
	weapon_state: Dictionary,
	target: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var weapon: ContentDefinition = weapon_state["definition"]
	var data: Dictionary = weapon.data
	var side := "player" if bool(shooter["is_player"]) else "enemy_%d" % int(shooter["index"])
	var target_name := "player" if bool(target["is_player"]) else "enemy_%d" % int(target["index"])
	var accuracy := clampf(float(data.get("accuracy", 0.5)), 0.0, 1.0)
	var salvo := maxi(1, int(data.get("salvo", 1)))
	var pierce := armor_pierce_of(hub, weapon)
	var status := status_of(hub, weapon)
	var rolls: Array = []
	var damage_total := 0.0
	for _shot in salvo:
		var hit := rng.randf() < accuracy
		var damage := 0.0
		if hit:
			damage = float(data.get("damage", 0.0))
			damage_total += damage
		rolls.append({"hit": hit, "damage": damage})
	return {
		"side": side,
		"shooter": shooter,
		"target": target,
		"target_name": target_name,
		"weapon_id": weapon.id,
		"weapon_kind": String(data.get("kind", "direct")),
		"pierce": pierce,
		"status": status,
		"rolls": rolls,
		"damage_total": damage_total,
	}


## Applies both sides' simultaneous fire. Damage is computed off pre-round HP so
## a mutual kill is possible; the caller resolves both-zero as a player defeat.
static func _apply_actions(
	battle: Dictionary,
	player: Dictionary,
	enemies: Array,
	player_actions: Array,
	enemy_actions: Array
) -> void:
	var enemy_damage := {}
	var player_damage := 0.0
	for action in player_actions:
		var target: Dictionary = action["target"]
		var effective := _effective_damage(float(action["damage_total"]), float(target["armor"]), float(action["pierce"]))
		enemy_damage[int(target["index"])] = float(enemy_damage.get(int(target["index"]), 0.0)) + effective
		_log_fire(battle, action, effective, int(target["index"]), float(target["hp"]))
	for action in enemy_actions:
		var effective := _effective_damage(float(action["damage_total"]), float(player["armor"]), float(action["pierce"]))
		player_damage += effective
		_log_fire(battle, action, effective, -1, float(player["hp"]))
	for enemy in enemies:
		var damage := float(enemy_damage.get(int(enemy["index"]), 0.0))
		if damage > 0.0:
			_damage_combatant(enemy, damage)
	if player_damage > 0.0:
		_damage_combatant(player, player_damage)
	for action in player_actions:
		if float(action["damage_total"]) > 0.0 and String(action["status"]) != "none":
			_apply_status(action["target"], String(action["status"]))
	for action in enemy_actions:
		if float(action["damage_total"]) > 0.0 and String(action["status"]) != "none":
			_apply_status(player, String(action["status"]))


static func _apply_status(target: Dictionary, status: String) -> void:
	if status.is_empty() or status == "none":
		return
	var statuses: Dictionary = target["statuses"]
	statuses[status] = STATUS_DURATION_ROUNDS


static func _effective_damage(raw: float, armor: float, pierce: float) -> float:
	if raw <= 0.0:
		return 0.0
	var effective_armor := clampf(armor, 0.0, 1.0) * (1.0 - clampf(pierce, 0.0, 1.0))
	return raw * (1.0 - effective_armor)


static func _damage_combatant(target: Dictionary, damage: float) -> void:
	target["hp"] = maxf(0.0, float(target["hp"]) - damage)
	target["damage_taken"] = float(target["damage_taken"]) + damage
	if not bool(target["is_player"]) and float(target["hp"]) <= 0.0:
		target["sunk"] = true
		target["view"]["sunk"] = true


static func _sync_views(battle: Dictionary, player: Dictionary, enemies: Array) -> void:
	var player_view: Dictionary = battle["player"]
	player_view["hit_points"] = float(player["hp"])
	player_view["hit_points_after"] = float(player["hp"])
	player_view["damage_taken"] = float(player["damage_taken"])
	player_view["durability_after"] = _durability_after(float(player["hp"]), float(player_view["durability_before"]))
	player_view["retreated"] = bool(player["view"]["retreated"])
	for enemy in enemies:
		var view: Dictionary = enemy["view"]
		view["hull_points_after"] = float(enemy["hp"])
		view["sunk"] = bool(enemy["sunk"])
		view["retreated"] = bool(enemy["retreated"])
		view["damage_taken"] = float(enemy["damage_taken"])


static func _durability_after(hit_points: float, durability_before: float) -> float:
	if hit_points <= 0.0:
		return MIN_DURABILITY_AFTER_DEFEAT
	return clampf(hit_points / PLAYER_HIT_POINTS_PER_DURABILITY, MIN_DURABILITY_AFTER_DEFEAT, maxf(MIN_DURABILITY_AFTER_DEFEAT, durability_before))


static func _log(battle: Dictionary, entry: Dictionary) -> void:
	var log: Array = battle["log"]
	if log.size() >= MAX_LOG_ENTRIES:
		battle["log_truncated"] = true
		return
	log.append(entry)


static func _log_fire(battle: Dictionary, action: Dictionary, effective: float, target_index: int, target_hp_before: float) -> void:
	var rolls: Array = action["rolls"]
	var hits := 0
	for roll in rolls:
		if bool(roll["hit"]):
			hits += 1
	_log(battle, {
		"round": int(battle["rounds"]),
		"source": String(action["side"]),
		"action": "fire",
		"weapon_id": String(action["weapon_id"]),
		"weapon_kind": String(action["weapon_kind"]),
		"target": String(action["target_name"]),
		"shots": rolls.size(),
		"hits": hits,
		"damage": effective,
		"target_hp_before": target_hp_before,
		"status": String(action["status"]),
	})


static func _all_enemies_out(enemies: Array) -> bool:
	for enemy in enemies:
		if not bool(enemy["sunk"]) and not bool(enemy["retreated"]):
			return false
	return not enemies.is_empty()


static func _sunk_count(enemies: Array) -> int:
	var count := 0
	for enemy in enemies:
		if bool(enemy["sunk"]):
			count += 1
	return count


static func _weapon_ids(weapons: Array) -> Array:
	var ids: Array = []
	for weapon_state in weapons:
		ids.append(((weapon_state["definition"]) as ContentDefinition).id)
	return ids


static func _empty_loot() -> Dictionary:
	return {"money": 0, "items": [], "modules": [], "salvage": []}


## Rolls loot for every sunk enemy in spawn order. Each enemy's archetype
## `loot_table` yields an optional money range plus `LOOT_ROLLS_PER_TABLE` weighted
## entry picks. Weapon drops become salvage money (no weapon inventory slot yet).
## Returns `{loot, diagnostics}`: unknown tables / entries are skipped but recorded
## (`loot_table_missing` / `loot_entry_missing`) instead of disappearing silently.
static func _roll_loot(hub: RegistryHub, enemies: Array, rng: RandomNumberGenerator) -> Dictionary:
	var loot := _empty_loot()
	var diagnostics: Array = []
	var item_totals := {}
	var module_totals := {}
	for enemy in enemies:
		if not bool(enemy["sunk"]):
			continue
		var archetype: ContentDefinition = enemy["archetype"]
		var table_id := String((archetype.data as Dictionary).get("loot_table", ""))
		if table_id.is_empty():
			continue
		var table := hub.get_by_id(ContentTypes.LOOT_TABLE, table_id)
		if table == null:
			diagnostics.append({
				"side": "loot",
				"enemy_index": int(enemy["index"]),
				"reason": "loot_table_missing",
				"loot_table": table_id,
			})
			continue
		var data: Dictionary = table.data
		var money_range: Array = Array(data.get("money_range", []))
		if money_range.size() >= 2:
			loot["money"] = int(loot["money"]) + rng.randi_range(
				mini(int(money_range[0]), int(money_range[1])),
				maxi(int(money_range[0]), int(money_range[1]))
			)
		var entries: Array = Array(data.get("entries", []))
		if entries.is_empty():
			continue
		var rolls := rng.randi_range(int(LOOT_ROLLS_PER_TABLE[0]), int(LOOT_ROLLS_PER_TABLE[1]))
		for _roll in rolls:
			var picked: Variant = RngService.choose_weighted(rng, entries, "weight")
			if not (picked is Dictionary):
				continue
			var entry: Dictionary = picked
			var amount := 1
			var amount_range: Array = Array(entry.get("amount_range", [1, 1]))
			if amount_range.size() >= 2:
				amount = rng.randi_range(
					mini(int(amount_range[0]), int(amount_range[1])),
					maxi(int(amount_range[0]), int(amount_range[1]))
				)
			var kind := String(entry.get("kind", ""))
			var id := String(entry.get("id", ""))
			match kind:
				"item":
					if hub.get_by_id(ContentTypes.ITEM, id) != null:
						item_totals[id] = int(item_totals.get(id, 0)) + amount
					else:
						diagnostics.append(_loot_entry_diagnostic(enemy, kind, id))
				"module":
					if hub.get_by_id(ContentTypes.MODULE, id) != null:
						module_totals[id] = int(module_totals.get(id, 0)) + amount
					else:
						diagnostics.append(_loot_entry_diagnostic(enemy, kind, id))
				"weapon":
					var weapon := hub.get_by_id(ContentTypes.WEAPON, id)
					if weapon != null:
						var price := float((weapon.data as Dictionary).get("purchase_price", 0.0))
						var salvage_money := int(round(price * WEAPON_SALVAGE_RATIO * float(amount)))
						loot["money"] = int(loot["money"]) + salvage_money
						(loot["salvage"] as Array).append({"weapon_id": id, "amount": amount, "money": salvage_money})
					else:
						diagnostics.append(_loot_entry_diagnostic(enemy, kind, id))
				_:
					diagnostics.append(_loot_entry_diagnostic(enemy, kind, id))
	for item_id in item_totals.keys():
		(loot["items"] as Array).append({"item_id": String(item_id), "amount": int(item_totals[item_id])})
	for module_id in module_totals.keys():
		(loot["modules"] as Array).append({"module_id": String(module_id), "amount": int(module_totals[module_id])})
	return {"loot": loot, "diagnostics": diagnostics}


static func _loot_entry_diagnostic(enemy: Dictionary, kind: String, id: String) -> Dictionary:
	return {
		"side": "loot",
		"enemy_index": int(enemy["index"]),
		"reason": "loot_entry_missing",
		"kind": kind,
		"id": id,
	}


## ---------------------------------------------------------------------------
## Weapon resolution
## ---------------------------------------------------------------------------

static func _explicit_loadout(hub: RegistryHub, ship: Dictionary) -> Dictionary:
	var result := {}
	var raw: Variant = ship.get("weapon_loadout", null)
	if raw == null:
		raw = ship.get("weapons", null)
	if raw is Array:
		for item in raw:
			if not (item is Dictionary):
				continue
			var entry: Dictionary = item
			var socket := String(entry.get("socket", ""))
			var weapon_id := String(entry.get("weapon_id", entry.get("weapon", entry.get("id", ""))))
			if socket.is_empty() or weapon_id.is_empty():
				continue
			var definition := hub.get_by_id(ContentTypes.WEAPON, weapon_id)
			if definition != null:
				result[socket] = definition
	elif raw is Dictionary:
		var by_socket: Dictionary = raw
		for socket in by_socket.keys():
			var definition := hub.get_by_id(ContentTypes.WEAPON, String(by_socket[socket]))
			if definition != null:
				result[String(socket)] = definition
	return result


static func _default_weapon_for_socket(hub: RegistryHub, socket_class: String) -> ContentDefinition:
	if socket_class.is_empty():
		return null
	var candidates: Array = []
	for definition in hub.get_all(ContentTypes.WEAPON):
		var data: Dictionary = definition.data
		var weapon_class := String(data.get("weapon_class", ""))
		var mount_class := String(data.get("mount_class", weapon_class))
		if weapon_class == socket_class or mount_class == socket_class:
			candidates.append(definition)
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(left: ContentDefinition, right: ContentDefinition) -> bool:
		return left.id < right.id
	)
	return candidates[0]


static func _weapon_row(socket_name: String, definition: ContentDefinition) -> Dictionary:
	var data: Dictionary = definition.data
	return {
		"socket": socket_name,
		"weapon_id": definition.id,
		"weapon_class": String(data.get("weapon_class", "")),
		"damage": float(data.get("damage", 0.0)),
		"range": float(data.get("range", 0.0)),
		"cooldown": float(data.get("cooldown", 1.0)),
		"accuracy": float(data.get("accuracy", 0.0)),
	}
