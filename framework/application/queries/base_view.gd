class_name BaseViewQuery
extends RefCounted
## @static-doc
## 作用：`base.view` 只读查询：输出基地站点、建筑实例、仓储、工人、防御与每 tick
## 支出；未占领时只返回 `{claimed:false}`，不创建 / 不修改 `data.base`。
##
## ## 契约与约束
## - 字段稳定：`claimed / site_id / site_archetype_id / site / port_id / slot_count /
##   slots_used / buildings[] / storage / workers / defense / maintenance_per_tick /
##   upkeep_per_tick / wages_per_tick / money_due_per_tick / halted / unpaid_ticks /
##   upkeep_debt`。
## - `buildings[]`：`{instance_id, building_id, name_key, category, level, status,
##   remaining_hours, upgrade_ref, worker_slots, workers[], order, production_speed,
##   upkeep_per_tick}`。
## @end-static-doc


static func execute(_params: Dictionary, context) -> Dictionary:
	return Result.ok(BaseOps.view(context.state, context.registries))
