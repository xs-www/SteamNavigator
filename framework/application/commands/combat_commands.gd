class_name CombatCommands
extends RefCounted
## @static-doc
## 作用：`combat.resolve` 命令入口（Phase D1 自动战斗）。把参数（可选
## `encounter_table_id` / `seed` / `encounter_id`）交给 `CombatService.resolve`，在
## CommandBus 事务里提交耐久、战利品与 `data.combat` 记录，并发布 `combat.resolved`
## 领域事件。
##
## ## 契约与约束
## - 参数：`encounter_table_id` 省略时用注册表里 id 最小的遭遇表（确定性默认）；
##   `seed` 省略（0）时由 run seed + 战斗序号派生，显式传入则直接决定本场结果。
## - 幂等键：`encounter_id`（兼容别名 `settlement_key`）非空时作为结算 key；同一 key
##   重复调用返回已有 battle（`data.already_settled=true`），**不发奖、不追加记录、
##   不发事件、不 autosave**。key 为空保持“每次调用都是新战斗”。
## - 失败原样返回 `CombatService` 的结构化 Result（`no_run` / `no_ship` /
##   `unknown_encounter` / `combat_resolve_failed`），命令事务不提交状态。
## - 新结算返回 `{battle, durability, loot_applied, already_settled:false}` 且
##   `autosave=true`；事件 payload 含 battle id / outcome / rounds / money。
## - 不发 `run.started` 等既有事件；本切片不接入航行风险结算，commander 可直接
##   `context.commands.execute(&"combat.resolve", {...})` 调用。
## @end-static-doc


static func resolve(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var encounter_table_id := String(params.get("encounter_table_id", ""))
	var seed_value := int(params.get("seed", 0))
	var settlement_key := String(params.get("encounter_id", params.get("settlement_key", "")))
	var resolved := CombatService.resolve(
		context.registries, context.state, encounter_table_id, seed_value, settlement_key
	)
	if not bool(resolved.get("ok", false)):
		return resolved
	var data: Dictionary = resolved.get("data", {})
	if bool(data.get("already_settled", false)):
		return Result.ok(data, [])
	var battle: Dictionary = data["battle"]
	var loot_applied: Dictionary = data.get("loot_applied", {})
	var event := {
		"type": "combat.resolved",
		"payload": {
			"battle_id": String(battle.get("id", "")),
			"encounter_table_id": String(battle.get("encounter_table_id", "")),
			"settlement_key": String(battle.get("settlement_key", "")),
			"outcome": String(battle.get("outcome", "")),
			"rounds": int(battle.get("rounds", 0)),
			"durability": float(data.get("durability", 0.0)),
			"money": int(loot_applied.get("money", 0)),
		},
	}
	var result := Result.ok(data, [event])
	result["autosave"] = true
	return result
