class_name CombatCommands
extends RefCounted
## @static-doc
## 作用：`combat.resolve` 命令入口（Phase D1 自动战斗）。把参数（可选
## `encounter_table_id` / `seed`）交给 `CombatService.resolve`，在 CommandBus 事务里
## 提交耐久、战利品与 `data.combat` 记录，并发布 `combat.resolved` 领域事件。
##
## ## 契约与约束
## - 参数：`encounter_table_id` 省略时用注册表里 id 最小的遭遇表（确定性默认）；
##   `seed` 省略（0）时由 run seed + 战斗序号派生，显式传入则直接决定本场结果。
## - 失败原样返回 `CombatService` 的结构化 Result（`no_run` / `no_ship` /
##   `unknown_encounter` / `combat_resolve_failed`），命令事务不提交状态。
## - 成功返回 `{battle, durability, loot_applied}`；`autosave=true`（战斗会改持久状态）。
## - 不发 `run.started` 等既有事件；本切片不接入航行风险结算，commander 可直接
##   `context.commands.execute(&"combat.resolve", {...})` 调用。
## @end-static-doc


static func resolve(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var encounter_table_id := String(params.get("encounter_table_id", ""))
	var seed_value := int(params.get("seed", 0))
	var resolved := CombatService.resolve(
		context.registries, context.state, encounter_table_id, seed_value
	)
	if not bool(resolved.get("ok", false)):
		return resolved
	var battle: Dictionary = resolved["data"]["battle"]
	var loot_applied: Dictionary = resolved["data"].get("loot_applied", {})
	var event := {
		"type": "combat.resolved",
		"payload": {
			"battle_id": String(battle.get("id", "")),
			"encounter_table_id": String(battle.get("encounter_table_id", "")),
			"outcome": String(battle.get("outcome", "")),
			"rounds": int(battle.get("rounds", 0)),
			"durability": float(resolved["data"].get("durability", 0.0)),
			"money": int(loot_applied.get("money", 0)),
		},
	}
	var result := Result.ok(resolved["data"], [event])
	result["autosave"] = true
	return result
