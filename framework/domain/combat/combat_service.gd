class_name CombatService
extends RefCounted
## @static-doc
## 作用：Phase D1 战斗自动结算的运行时门面：解析遭遇表、调用 `CombatOps` 纯规则层，
## 把结果落到 `GameState`（结构耐久、战利品、`data.combat` 惰性战斗记录），并给命令 /
## 查询提供稳定的 view 形状。命令 `combat.resolve` 与查询 `combat.view` / `combat.log`
## 都只是本服务的薄封装。
##
## 关键依赖：`CombatOps`、`RegistryHub`、`GameState`、`ShipOps`、`WarehouseOps`、
## `StableHash`、`RngService`。
##
## ## 契约与约束
## - **确定性**：显式 `requested_seed` 直接决定本场战斗；省略时按
##   `StableHash.seed_from(run.seed, "combat", "battle:<序号>")` 派生，因此同存档 + 同
##   战斗序号的连续结算也可复现。战斗随机流固定为 `RngService` 的 `combat` 命名流。
## - **一次遭遇一次结算**：结算成功才写状态；`data.combat` 记录每场战斗的 JSON 快照
##   （含回合日志，最多 `CombatOps.MAX_LOG_ENTRIES` 条）；最多保留 `MAX_BATTLES` 场，
##   超出从最旧开始丢弃。旧档没有该块时惰性补齐，不改 `schema_version`。
## - **结算幂等（可选 settlement key）**：`resolve(..., settlement_key)` 用
##   `data.combat.settlements`（key → battle id）保证同一 key 只结算一次；重复调用返回
##   已有 battle（`data.already_settled=true`），不发奖、不追加记录、不推进序号。key 为空
##   时保持旧语义（每次调用都是新战斗）；被 `MAX_BATTLES` 淘汰的战斗会同时清理其 key。
## - **耐久语义**：战后把 `player.durability_after` 写回 `ship.durability`（0–100）；
##   击沉落到 `CombatOps.MIN_DURABILITY_AFTER_DEFEAT`，维修入口沿用现有港口维修。
## - **战利品发放**：`victory` 才发放。金钱 → `player.money` + `stats.income`；item →
##   船上货舱（`ShipOps.add_cargo`，D1 不做容量拦截；超载由现有载重/市场规则处理）；
##   module → 当前港仓库（`WarehouseOps.add_module`）；weapon 掉落由 `CombatOps` 折算成
##   残骸回收金钱，因此没有「武器背包」存档分区。
## - **错误**：`no_run` / `no_ship` / `unknown_encounter` / `combat_resolve_failed`；
##   失败不提交状态（命令事务负责）。
## - 本服务不发领域事件（命令层负责）；不接 `voyage` 风险结算（D1 只提供 commander
##   可调用入口，接入航行留给后续切片）。
## @end-static-doc

const COMBAT_KEY := "combat"
const SCHEMA_VERSION := 1
## 保留的战斗记录上限（从最旧丢弃），避免存档无界增长。
const MAX_BATTLES := 20
const DEFAULT_STATE := {
	"schema_version": SCHEMA_VERSION,
	"next_battle_id": 1,
	"battles": [],
	## settlement key → battle id, for caller-provided encounter/settlement ids.
	"settlements": {},
}


## Lazily creates / repairs `data.combat` and returns the live dictionary.
static func ensure_state(state: GameState) -> Dictionary:
	if state == null:
		return DEFAULT_STATE.duplicate(true)
	var current: Variant = state.data.get(COMBAT_KEY, null)
	if not (current is Dictionary):
		current = DEFAULT_STATE.duplicate(true)
		state.data[COMBAT_KEY] = current
	var combat: Dictionary = current
	if not (combat.get("battles", null) is Array):
		combat["battles"] = []
	if not (combat.get("settlements", null) is Dictionary):
		combat["settlements"] = {}
	combat["schema_version"] = SCHEMA_VERSION
	var next_id := int(combat.get("next_battle_id", 1))
	var battles: Array = combat["battles"]
	# Repair old/hand-written blocks: drop non-dictionary entries and make sure the
	# sequence number is ahead of every recorded battle.
	for battle in battles:
		if battle is Dictionary:
			next_id = maxi(next_id, int((battle as Dictionary).get("sequence", 0)) + 1)
	combat["next_battle_id"] = maxi(1, next_id)
	return combat


## Resolves one encounter and applies its consequences to `state`.
## Returns the same `{ok, error_code, message_key, data, events}` envelope shape as
## other domain entry points; `data.battle` is the persisted battle view.
##
## `settlement_key` is optional caller-provided idempotency key (the command exposes
## it as `encounter_id`): when a battle with the same key was already persisted this
## call returns that existing record with `data.already_settled = true`, applies no
## loot, appends no record and does not advance `next_battle_id`. An empty key keeps
## the previous "every call is a new battle" behaviour.
static func resolve(
	hub: RegistryHub,
	state: GameState,
	encounter_table_id: String = "",
	requested_seed: int = 0,
	settlement_key: String = ""
) -> Dictionary:
	if state == null or state.is_empty():
		return Result.fail("no_run", "ui.error.no_run")
	if hub == null:
		return Result.fail("no_registries", "ui.error.start_failed")
	var ship := state.ship()
	if ship.is_empty():
		return Result.fail("no_ship", "ui.error.no_ship")
	# Replay path is read-only: it must not create/repair `data.combat`, so a
	# failed command keeps the state untouched.
	if not settlement_key.is_empty():
		var settled := _settled_battle_from_state(state, settlement_key)
		if not settled.is_empty():
			return Result.ok({
				"battle": CombatOps.battle_view(settled),
				"durability": float(ship.get("durability", 0.0)),
				"loot_applied": (settled.get("loot_applied", {}) as Dictionary).duplicate(true),
				"already_settled": true,
			})
	var encounter := _resolve_encounter(hub, encounter_table_id)
	if encounter == null:
		return Result.fail("unknown_encounter", "ui.error.combat_unknown_encounter", {
			"encounter_table_id": encounter_table_id,
		})
	var combat := ensure_state(state)
	var battle_number := int(combat.get("next_battle_id", 1))
	var seed_value := requested_seed
	if seed_value == 0:
		seed_value = StableHash.seed_from(state.seed(), CombatOps.STREAM_COMBAT, "battle:%d" % battle_number)
	var resolved := CombatOps.resolve(hub, ship, encounter, seed_value)
	if not bool(resolved.get("ok", false)):
		return Result.fail("combat_resolve_failed", "ui.error.combat_resolve_failed", {
			"reason": String(resolved.get("reason", "")),
			"encounter_table_id": encounter.id,
		})
	var battle: Dictionary = resolved["battle"]
	battle["id"] = "battle_%d" % battle_number
	battle["sequence"] = battle_number
	battle["at_time"] = state.now()
	battle["port_id"] = state.current_port_id()
	if not settlement_key.is_empty():
		battle["settlement_key"] = settlement_key

	var player_view: Dictionary = battle["player"]
	ship["durability"] = clampf(
		float(player_view.get("durability_after", ship.get("durability", 1.0))),
		CombatOps.MIN_DURABILITY_AFTER_DEFEAT,
		ShipOps.durability_max(hub, ship)
	)
	var applied := _apply_loot(hub, state, battle.get("loot", {}))
	battle["loot_applied"] = applied

	var battles: Array = combat["battles"]
	battles.append(battle)
	while battles.size() > MAX_BATTLES:
		var dropped: Variant = battles.pop_front()
		_drop_settlement(combat, dropped)
	combat["next_battle_id"] = battle_number + 1
	if not settlement_key.is_empty():
		(combat["settlements"] as Dictionary)[settlement_key] = String(battle["id"])
	return Result.ok({
		"battle": CombatOps.battle_view(battle),
		"durability": float(ship["durability"]),
		"loot_applied": applied,
		"already_settled": false,
	})


## Returns the persisted battle for a settlement key, or `{}` when the key is new
## (or its battle record has been trimmed out of the log). `prune_missing=false` is
## used by the read-only replay path so a failed/replayed command never mutates state.
static func _settled_battle(combat: Dictionary, settlement_key: String, prune_missing: bool = true) -> Dictionary:
	var settlements: Variant = combat.get("settlements", null)
	if not (settlements is Dictionary):
		return {}
	var battle_id := String((settlements as Dictionary).get(settlement_key, ""))
	if battle_id.is_empty():
		return {}
	for battle in combat.get("battles", []):
		if battle is Dictionary and String((battle as Dictionary).get("id", "")) == battle_id:
			return battle
	if prune_missing:
		(settlements as Dictionary).erase(settlement_key)
	return {}


## Read-only variant used by the replay path: never creates or repairs the block.
static func _settled_battle_from_state(state: GameState, settlement_key: String) -> Dictionary:
	var current: Variant = state.data.get(COMBAT_KEY, null)
	if not (current is Dictionary):
		return {}
	return _settled_battle(current, settlement_key, false)


## Removes settlement keys that pointed at a battle record dropped from the log.
static func _drop_settlement(combat: Dictionary, dropped_battle: Variant) -> void:
	if not (dropped_battle is Dictionary):
		return
	var settlements: Variant = combat.get("settlements", null)
	if not (settlements is Dictionary):
		return
	var dropped_id := String((dropped_battle as Dictionary).get("id", ""))
	if dropped_id.is_empty():
		return
	var keys: Array = (settlements as Dictionary).keys()
	for key in keys:
		if String((settlements as Dictionary)[key]) == dropped_id:
			(settlements as Dictionary).erase(key)


## Read-only view for `combat.view`: current ship armament, available encounter
## tables and the last persisted battle. No run / old save returns stable defaults.
static func view(state: GameState, hub: RegistryHub) -> Dictionary:
	if state == null or state.is_empty():
		return {"has_run": false, "player": null, "encounters": [], "last_battle": null}
	var ship := state.ship()
	var hull_id := String(ship.get("hull_id", ""))
	var weapons: Array = []
	var missing: Array = []
	var max_durability := 0.0
	if hub != null and not ship.is_empty():
		weapons = CombatOps.player_weapon_rows(hub, ship)
		missing = CombatOps.unmounted_sockets(hub, ship)
		max_durability = ShipOps.durability_max(hub, ship)
	return {
		"has_run": true,
		"player": {
			"hull_id": hull_id,
			"durability": float(ship.get("durability", 0.0)),
			"max_durability": max_durability,
			"weapons": weapons,
			"unmounted_sockets": missing,
			"armor": CombatOps.PLAYER_ARMOR,
		},
		"encounters": CombatOps.encounter_summaries(hub) if hub != null else [],
		"last_battle": last_battle(state),
	}


## Last persisted battle (deep copy) or `{}` when the run has none.
static func last_battle(state: GameState) -> Dictionary:
	var battles := battle_records(state)
	if battles.is_empty():
		return {}
	return CombatOps.battle_view(battles[battles.size() - 1])


## Returns persisted battle records (live array reference; empty for old saves).
static func battle_records(state: GameState) -> Array:
	if state == null:
		return []
	var current: Variant = state.data.get(COMBAT_KEY, null)
	if not (current is Dictionary):
		return []
	var battles: Variant = (current as Dictionary).get("battles", null)
	return battles if battles is Array else []


## Compact log rows for `combat.log`: newest last, `limit` clamps to [1, MAX_BATTLES].
static func log_rows(state: GameState, limit: int = 20) -> Array:
	var battles := battle_records(state)
	var wanted := clampi(limit, 1, MAX_BATTLES)
	var start := maxi(0, battles.size() - wanted)
	var rows: Array = []
	for index in range(start, battles.size()):
		var battle: Variant = battles[index]
		if not (battle is Dictionary):
			continue
		rows.append(_battle_summary(battle))
	return rows


static func _battle_summary(battle: Dictionary) -> Dictionary:
	var player: Dictionary = battle.get("player", {})
	var loot: Dictionary = battle.get("loot", {})
	var items: Array = Array(loot.get("items", []))
	return {
		"id": String(battle.get("id", "")),
		"sequence": int(battle.get("sequence", 0)),
		"settlement_key": String(battle.get("settlement_key", "")),
		"at_time": float(battle.get("at_time", 0.0)),
		"port_id": String(battle.get("port_id", "")),
		"encounter_table_id": String(battle.get("encounter_table_id", "")),
		"outcome": String(battle.get("outcome", "")),
		"rounds": int(battle.get("rounds", 0)),
		"durability_before": float(player.get("durability_before", 0.0)),
		"durability_after": float(player.get("durability_after", 0.0)),
		"money": int(loot.get("money", 0)),
		"item_count": items.size(),
		"enemies": (battle.get("enemies", []) as Array).size(),
	}


static func _resolve_encounter(hub: RegistryHub, encounter_table_id: String) -> ContentDefinition:
	if not encounter_table_id.is_empty():
		return hub.get_by_id(ContentTypes.ENCOUNTER_TABLE, encounter_table_id)
	var definitions := hub.get_all(ContentTypes.ENCOUNTER_TABLE)
	if definitions.is_empty():
		return null
	definitions.sort_custom(func(left: ContentDefinition, right: ContentDefinition) -> bool:
		return left.id < right.id
	)
	return definitions[0]


## Credits loot through the existing persistence paths and reports what actually
## landed. Unknown ids are skipped (content validation should have caught them).
static func _apply_loot(hub: RegistryHub, state: GameState, loot: Dictionary) -> Dictionary:
	var applied := {"money": 0, "items": [], "modules": [], "salvage": Array(loot.get("salvage", []))}
	var money := int(loot.get("money", 0))
	if money > 0:
		state.add_money(money)
		state.record_income(money)
		applied["money"] = money
	var ship := state.ship()
	for raw_item in Array(loot.get("items", [])):
		if not (raw_item is Dictionary):
			continue
		var entry: Dictionary = raw_item
		var item_id := String(entry.get("item_id", ""))
		var amount := int(entry.get("amount", 0))
		if amount <= 0 or hub.get_by_id(ContentTypes.ITEM, item_id) == null:
			continue
		ShipOps.add_cargo(ship, item_id, amount)
		(applied["items"] as Array).append({"item_id": item_id, "amount": amount})
	for raw_module in Array(loot.get("modules", [])):
		if not (raw_module is Dictionary):
			continue
		var entry: Dictionary = raw_module
		var module_id := String(entry.get("module_id", ""))
		var amount := int(entry.get("amount", 0))
		if amount <= 0 or hub.get_by_id(ContentTypes.MODULE, module_id) == null:
			continue
		WarehouseOps.add_module(state, state.current_port_id(), module_id, amount)
		(applied["modules"] as Array).append({"module_id": module_id, "amount": amount})
	return applied
