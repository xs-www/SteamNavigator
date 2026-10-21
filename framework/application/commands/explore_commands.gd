class_name ExploreCommands
extends RefCounted
## @static-doc
## 作用：探索系统的命令包装（`explore.start` / `explore.settle` / `explore.decide` /
## `clue.buy` / `clue.investigate` / `clue.travel`），把参数校验与领域服务的返回原样
## 交给 CommandBus 的事务/事件流程。
##
## - 关键依赖：`ExploreVoyageService`、`ClueService`、`Result`
##
## ## 契约与约束
## - 命令只在 `CommandBus` 的 GameState 克隆上执行；失败返回 `Result.fail`
##   （`code` + `ui.error.*` message_key），成功返回 `Result.ok(payload, events)`，
##   领域事件由总线发布。
## - 所有会改变状态的扣费 / 时间推进 / 发现都发生在领域服务里，这里只做缺参校验。
## - 4.4.2：`clue.travel` 只用于 `port_goods` 线索，目标港由 `ClueService.travel`
##   在领域层解析后调用 `VoyageService.start`；查询 / UI 不接触 `target_port_id`。
## @end-static-doc


static func start(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var clue_id := String(params.get("clue_id", ""))
	if clue_id.is_empty():
		return Result.fail("unknown_clue", "ui.error.unknown_clue")
	var strategy_id := String(params.get("strategy_id", ""))
	if strategy_id.is_empty():
		return Result.fail("missing_strategy", "ui.error.missing_strategy")
	return ExploreVoyageService.start(context, clue_id, strategy_id)


static func settle(_params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	return ExploreVoyageService.settle(context)


static func decide(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var choice := String(params.get("choice", ""))
	if choice.is_empty():
		return Result.fail("unknown_choice", "ui.error.unknown_option")
	return ExploreVoyageService.decide(context, choice)


static func buy(_params: Dictionary, context) -> Dictionary:
	return ClueService.buy(context)


## 4.3.2 / U2：`clue.investigate` —— 在港把一条线索推进一级（上限 4）。
## 等级推进与门禁都在 `ClueService.investigate`，命令只做缺参校验。
static func investigate(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var clue_id := String(params.get("clue_id", ""))
	if clue_id.is_empty():
		return Result.fail("unknown_clue", "ui.error.unknown_clue")
	return ClueService.investigate(context, clue_id)


## 4.4.2：`clue.travel` —— 对 `port_goods` 线索执行普通航线前往其目标港。
## 目标港由领域层解析，查询 / UI 永远不拿到 `target_port_id`；其余门禁与
## `VoyageService.start` 完全一致（在港、非探索中、预览可行）。
static func travel(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var clue_id := String(params.get("clue_id", ""))
	if clue_id.is_empty():
		return Result.fail("unknown_clue", "ui.error.unknown_clue")
	var strategy_id := String(params.get("strategy_id", ""))
	if strategy_id.is_empty():
		return Result.fail("missing_strategy", "ui.error.missing_strategy")
	return ClueService.travel(context, clue_id, strategy_id)
