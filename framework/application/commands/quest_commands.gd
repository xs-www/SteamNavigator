class_name QuestCommands
extends RefCounted
## @static-doc
## 作用：抽象任务（Quest）的命令包装（C3）：`quest.start`（接取内容任务）、
## `quest.complete`（手动完成）、`quest.observe`（Shell 把成功命令 / UI 事件转成
## `cmd:*` / `ui:*` 交给 QuestService 推进目标）。只做参数校验与领域服务转交，
## 状态推进在 `CommandBus` 的 GameState 克隆事务内完成。
##
## - 关键依赖：`QuestService`、`Result`
##
## ## 契约与约束
## - 成功返回 `Result.ok(payload, events)`；领域事件（`quest.started` /
##   `quest.updated` / `quest.completed`）由总线发布。
## - `quest.start` 参数 `{quest_id}`；`quest.complete` 参数 `{instance_id}`；
##   `quest.observe` 参数 `{event, data}`，未知事件不推进也不报错。
## - 委托接取 / 完成由 `ContractOps` 直接调 `QuestService`，不经过本命令层。
## @end-static-doc


static func start(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var quest_id := String(params.get("quest_id", ""))
	if quest_id.is_empty():
		return Result.fail("missing_quest_id", "ui.error.missing_quest_id")
	return QuestService.start(context, quest_id)


static func complete(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var instance_id := String(params.get("instance_id", ""))
	if instance_id.is_empty():
		return Result.fail("missing_instance_id", "ui.error.missing_instance_id")
	return QuestService.complete(context, instance_id)


static func observe(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var event := String(params.get("event", ""))
	if event.is_empty():
		return Result.fail("missing_event", "ui.error.missing_event")
	var data: Dictionary = {}
	if params.get("data", null) is Dictionary:
		data = (params.get("data") as Dictionary).duplicate(true)
	return QuestService.observe(context, event, data)
