class_name ClueListViewQuery
extends RefCounted
## @static-doc
## 作用：线索列表页的只读查询（`clue.list`）。返回全部 active 线索的等级裁剪视图
## （与 `sea_chart.view` 同一套 `ClueService.view_entry` 裁剪）、调查入口字段、
## 可出航标记，以及最近过期线索的折叠历史（`data.clues.expired`）。
##
## - 关键依赖：`ClueService`、`ExplorationRules`、`GameState.data.clues`、`WorldOps`
##
## ## 契约与约束
## - 只读：由 `QueryBus` 在状态克隆上执行；不清理过期线索、不写状态、不发事件。
##   「已过期但尚未被命令路径 sweep」的条目由 `ClueService.view` 过滤掉；
##   历史折叠区只读 `expired` 快照。
## - **任何类型、任何等级都不输出** `target_port_id`、`credibility`、真实
##   `search_zone` 与未披露的 `goods_snapshot` 明细；字段裁剪完全复用领域视图。
## - 调查成本 / 工时 / 成功率来自 Core `exploration` 块，列表页不自算规则。
## - `can_sail`：在港、未在探索、线索 active；货物线索的目标港不能是当前港。
##   港口位置线索允许出航（与海图面板一致，不因等级不足而禁止）。
## - 过期条目只给历史需要的字段（id / 类型 / 来源 / 等级 / 货物与港口名 / 到期时间），
##   供列表页灰显；不参与 `max_active_clues` 计数。
## @end-static-doc


static func execute(_params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.ok(_empty_result())
	var state: GameState = context.state
	var rules := ExplorationRules.read(state, context.registries)
	var at_port := state.is_at_port()
	var exploring := state.explore_voyage() is Dictionary
	var clues: Array = []
	for entry in ClueService.view(state, context):
		if not (entry is Dictionary):
			continue
		var clue_view: Dictionary = entry
		var clue := ClueService.find_clue(state, String(clue_view.get("id", "")))
		var level := int(clue_view.get("level", 1))
		clue_view["investigation_cost"] = int(rules.get("investigation_cost", 0))
		clue_view["investigation_hours"] = float(rules.get("investigation_hours", 0.0))
		clue_view["investigation_success_chance"] = clampf(
			float(rules.get("investigation_success_chance", 1.0)), 0.0, 1.0
		)
		clue_view["can_investigate"] = at_port and level < ClueService.NAME_MIN_LEVEL
		clue_view["can_sail"] = _can_sail(state, clue, at_port, exploring)
		clues.append(clue_view)
	var expired: Array = []
	for raw in Array(state.ensure_clues().get("expired", [])):
		if raw is Dictionary:
			expired.append(_expired_entry(state, raw))
	return Result.ok({
		"has_run": true,
		"now": state.now(),
		"max_active": int(rules.get("max_active_clues", 4)),
		"active_count": ClueService.active_count(state),
		"clues": clues,
		"expired": expired,
	})


static func _can_sail(
	state: GameState, clue: Dictionary, at_port: bool, exploring: bool
) -> bool:
	if not at_port or exploring or clue.is_empty():
		return false
	if String(clue.get("type", ClueService.TYPE_PORT_LOCATION)) == ClueService.TYPE_PORT_GOODS:
		return String(clue.get("target_port_id", "")) != state.current_port_id()
	return true


## History entry for a timed-out clue. The port of a goods clue is public information
## (goods clues target discovered harbours), so it may show its display name.
static func _expired_entry(state: GameState, clue: Dictionary) -> Dictionary:
	var type := String(clue.get("type", ClueService.TYPE_PORT_LOCATION))
	var entry := {
		"id": String(clue.get("id", "")),
		"type": type,
		"level": int(clue.get("level", 1)),
		"source_key": String(clue.get("source_key", "")),
		"source_display_key": String(clue.get("source_display_key", "")),
		"expires_at": float(clue.get("expires_at", 0.0)),
	}
	if type == ClueService.TYPE_PORT_GOODS:
		entry["target_goods_id"] = String(clue.get("target_goods_id", ""))
		entry["port_name_key"] = WorldOps.port_display_key(
			WorldOps.world_map(state), String(clue.get("target_port_id", ""))
		)
	return entry


static func _empty_result() -> Dictionary:
	return {
		"has_run": false,
		"now": 0.0,
		"max_active": 0,
		"active_count": 0,
		"clues": [],
		"expired": [],
	}
