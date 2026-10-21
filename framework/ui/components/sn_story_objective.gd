class_name SNStoryObjective
extends PanelContainer
## @static-doc
## 作用：新手剧情 / 教学系统的非阻塞目标条（阶段 4.5）：顶部居中的小面板，显示
## 当前剧情目标文案与进度（`故事目标（2/4）`）。不锁输入、不遮挡操作。
##
## - 关键依赖：`story.view.objective` 的 `text_key / progress / target`、本地化回调
##
## ## 契约与约束
## - `bind(text_key, progress, target, translate)` 只显示，不推进剧情、不发信号。
## - `mouse_filter = IGNORE`：目标条不拦截点击；位置由 Shell 负责摆放。
## - 进度 `target <= 0` 时只显示目标文案。
## @end-static-doc

var _label: Label


func bind(text_key: String, progress: int, target: int, translate: Callable = Callable()) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_type_variation = &"SNPanel"
	for child in get_children():
		remove_child(child)
		child.free()
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var icon := Label.new()
	icon.text = "◈"
	icon.add_theme_font_size_override("font_size", 14)
	icon.add_theme_color_override("font_color", Color("e1c487"))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	_label = Label.new()
	_label.name = "ObjectiveLabel"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var objective := _loc(text_key, "", translate)
	if target > 1:
		var template := _loc("ui.story.objective_progress", "目标：%s（%d/%d）", translate)
		_label.text = template % [objective, clampi(progress, 0, target), target]
	else:
		var template := _loc("ui.story.objective", "目标：%s", translate)
		_label.text = template % objective
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color("ece1c5"))
	box.add_child(_label)
	custom_minimum_size = Vector2(0, 0)


func _loc(key: String, fallback: String, translate: Callable) -> String:
	if key.is_empty():
		return fallback
	var text := String(translate.call(key)) if translate.is_valid() else fallback
	if text.is_empty() or text == key:
		return fallback
	return text
