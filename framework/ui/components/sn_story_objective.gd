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
##
## ## 皮肤与节点约束（UI 贴图层）
## - 面板用 `SNPanel` 钢框纹理；前导符号改为 skin 图标 `status_route`（16 px，
##   `SNSkin.icon_rect`，缺失贴图时回退文字符号「◈」），文字色取
##   `SNSkin.color("text.light")`，不再写颜色常量。
## - `ObjectiveLabel` 节点名、13 px 字号、进度模板与 target<=0 的文案分支不变
##   （test_story_ui 按名字读文本并断言「8/10」「还差 2」）。
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
	# 前导徽记来自皮肤图标；贴图缺失（极简 checkout / 另一套 skin 未带该图标）时
	# 回退到原文字符号，保证目标条仍可读且不改变布局高度。
	var icon := SNSkin.icon_rect("status_route", 16.0)
	if icon.texture != null:
		icon.name = "ObjectiveIcon"
		box.add_child(icon)
	else:
		icon.free()
		var fallback := Label.new()
		fallback.text = "◈"
		fallback.add_theme_font_size_override("font_size", 14)
		fallback.add_theme_color_override("font_color", SNSkin.color("brass.highlight"))
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(fallback)
	_label = Label.new()
	_label.name = "ObjectiveLabel"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var objective := _loc(text_key, "", translate)
	if target > 1:
		var remaining := maxi(0, target - clampi(progress, 0, target))
		var template := (
			_loc("ui.story.objective_progress_remaining", "目标：%s（%d/%d，还差 %d）", translate)
			if remaining > 0
			else _loc("ui.story.objective_progress", "目标：%s（%d/%d）", translate)
		)
		var args: Array = [objective, clampi(progress, 0, target), target]
		if remaining > 0:
			args.append(remaining)
		_label.text = template % args
	else:
		var template := _loc("ui.story.objective", "目标：%s", translate)
		_label.text = template % objective
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", SNSkin.color("text.light"))
	box.add_child(_label)
	custom_minimum_size = Vector2(0, 0)


func _loc(key: String, fallback: String, translate: Callable) -> String:
	if key.is_empty():
		return fallback
	var text := String(translate.call(key)) if translate.is_valid() else fallback
	if text.is_empty() or text == key:
		return fallback
	return text
