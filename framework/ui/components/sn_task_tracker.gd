class_name SNTaskTracker
extends PanelContainer
## @static-doc
## 作用：HUD 任务追踪条（阶段 4.6 Phase A）——显示 `task.view.active_task` 的类别、
## 标题与当前步骤（进度 / 目的地 / 还差多少），并提示还有几个其它任务。非阻塞、
## 不拦截点击，位置由 Shell 摆放。
##
## - 关键依赖：`task.view` 的 Task / Step 字段、本地化回调
##
## ## 契约与约束
## - 纯展示：不查状态、不发信号；只按 step.kind 选择文案模板。
## - 名称字段（货物 / 港口）先用 `_tr` 翻译内容 key，再填进框架模板。
## - 只显示当前任务；完整列表在委托页 / 后续任务页。
##
## ## 皮肤与节点约束（UI 贴图层）
## - 面板用 `SNPanel` 钢框纹理；类别/其它任务数取 `text.muted`、标题与步骤取
##   `text.light`、前导记号取 `brass.highlight`，统一 `SNSkin.color(token)`，
##   不再保留颜色常量。
## - `TaskTrackerBox` / `TaskIcon` / `TaskCategory` / `TaskTitle` / `TaskStep` /
##   `TaskMore` 节点名、字号（11/12/13/14）与步骤文案模板不变
##   （test_story_ui 按 `TaskStep` 名字读文本）。
## @end-static-doc


func bind(task: Dictionary, total_tasks: int, translate: Callable = Callable()) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_type_variation = &"SNPanel"
	for child in get_children():
		remove_child(child)
		child.free()
	var box := HBoxContainer.new()
	box.name = "TaskTrackerBox"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var icon := _label("◇", 14, SNSkin.color("brass.highlight"))
	icon.name = "TaskIcon"
	box.add_child(icon)
	var category := _label(_loc(String(task.get("category_key", "")), translate), 11, SNSkin.color("text.muted"))
	category.name = "TaskCategory"
	box.add_child(category)
	var title := _label(
		_loc(String(task.get("title_key", "")), translate),
		13,
		SNSkin.color("text.light")
	)
	title.name = "TaskTitle"
	box.add_child(title)
	var step: Variant = task.get("current_step", null)
	if step is Dictionary:
		box.add_child(_label("·", 13, SNSkin.color("text.muted")))
		var step_label := _label(_step_text(step as Dictionary, translate), 13, SNSkin.color("text.light"))
		step_label.name = "TaskStep"
		box.add_child(step_label)
	if total_tasks > 1:
		var more := _label(_loc("ui.task.more", translate) % (total_tasks - 1), 12, SNSkin.color("text.muted"))
		more.name = "TaskMore"
		box.add_child(more)
	custom_minimum_size = Vector2(0, 0)


func _step_text(step: Dictionary, translate: Callable) -> String:
	var kind := String(step.get("kind", ""))
	var progress := int(step.get("progress", 0))
	var target := int(step.get("target", 0))
	var done := bool(step.get("done", false))
	match kind:
		"objective":
			return _progress_text(
				_loc(String(step.get("text_key", "")), translate), progress, target, translate
			)
		"accept":
			return _loc("ui.task.step.accept", translate)
		"load":
			var item := _loc(String(step.get("item_name_key", "")), translate)
			var template := _loc(
				"ui.task.step.load_fuel" if bool(step.get("fuel_sourced", false)) else "ui.task.step.load",
				translate
			)
			return (("✓ " if done else "") + template) % [item, progress, target]
		"passenger":
			return (("✓ " if done else "") + _loc("ui.task.step.passenger", translate)) % [progress, target]
		"sail":
			var destination := _loc(String(step.get("destination_name_key", "")), translate)
			return (("✓ " if done else "") + _loc("ui.task.step.sail", translate)) % destination
		"deliver":
			var port := _loc(String(step.get("destination_name_key", "")), translate)
			return (("✓ " if done else "") + _loc("ui.task.step.deliver", translate)) % port
		_:
			return ""


func _progress_text(objective: String, progress: int, target: int, translate: Callable) -> String:
	if target > 1:
		var remaining := maxi(0, target - progress)
		var template := (
			_loc("ui.task.step_progress_remaining", translate) if remaining > 0
			else _loc("ui.task.step_progress", translate)
		)
		var args: Array = [objective, progress, target]
		if remaining > 0:
			args.append(remaining)
		return template % args
	return _loc("ui.story.objective", translate) % objective


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _loc(key: String, translate: Callable) -> String:
	if key.is_empty() or not translate.is_valid():
		return key
	var text := String(translate.call(key))
	return key if text.is_empty() else text
