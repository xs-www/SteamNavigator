class_name StoryCommands
extends RefCounted
## @static-doc
## 作用：新手剧情 / 教学系统的命令包装：`story.advance`（剧情卡继续）、
## `story.skip`（跳过整段教程）、`story.observe`（Shell 转发成功命令 / UI 事件）。
## 只做参数校验与领域服务转交，状态推进在 `StoryService` / CommandBus 事务内完成。
##
## - 关键依赖：`StoryService`、`Result`
##
## ## 契约与约束
## - 只在 `CommandBus` 的 GameState 克隆上执行；失败返回 `Result.fail`，成功返回
##   `Result.ok(payload, events)`，领域事件由总线发布。
## - `story.observe` 的参数 `{event, data}`：`event` 为 `cmd:<command>` /
##   `ui:<event>`；未知事件只是不推进，不会报错。
## @end-static-doc


static func advance(_params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	return StoryService.advance(context)


static func skip(_params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	return StoryService.skip(context)


static func observe(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var event := String(params.get("event", ""))
	if event.is_empty():
		return Result.fail("missing_event", "ui.error.missing_event")
	var data: Dictionary = {}
	if params.get("data", null) is Dictionary:
		data = (params.get("data") as Dictionary).duplicate(true)
	return StoryService.observe(context, event, data)
