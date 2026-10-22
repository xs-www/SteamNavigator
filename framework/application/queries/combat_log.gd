class_name CombatLogQuery
extends RefCounted
## @static-doc
## 作用：`combat.log` 只读查询：按时间顺序输出持久化的战斗摘要（最新在最后），供
## 调试 / 后续航海日志页复用。
##
## ## 契约与约束
## - 参数 `limit`（默认 20，clamp 到 1..`CombatService.MAX_BATTLES`）。
## - 返回 `{battles: [{id, sequence, at_time, port_id, encounter_table_id, outcome,
##   rounds, durability_before, durability_after, money, item_count, enemies}], total}`；
##   不含逐回合日志（完整日志由 `combat.view.last_battle` 提供）。
## - 只读：旧档无 `data.combat` 时返回 `{battles:[], total:0}`，不创建状态块。
## @end-static-doc


static func execute(params: Dictionary, context) -> Dictionary:
	var limit := int(params.get("limit", 20))
	return Result.ok({
		"battles": CombatService.log_rows(context.state, limit),
		"total": CombatService.battle_records(context.state).size(),
	})
