class_name ExpeditionViewQuery
extends RefCounted
## @static-doc
## 作用：`expedition.view` 只读查询：输出遗迹、房间序列、当前房间/事件选项、奖励日志
## 与永久遗物列表；无远征时 `active:false`，不创建 `data.expedition`。
##
## ## 契约与约束
## - 字段稳定：`active / ruin_id / ruin / phase / room_index / room_count / rooms[] /
##   current_room / event_id / event / event_options[] / loot_money / loot_items[] /
##   log[] / relics[]`。
## @end-static-doc


static func execute(_params: Dictionary, context) -> Dictionary:
	return Result.ok(RuinOps.view(context.state, context.registries))
