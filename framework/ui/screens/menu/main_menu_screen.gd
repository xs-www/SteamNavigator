class_name MainMenuScreen
extends VBoxContainer
## @static-doc
## 作用：启动主菜单页面场景：展示启动状态与主入口，并把用户操作转成 Shell 意图。
##
## - 关键依赖：`app.view` 启动状态、`SNBadge`、`SNSkin`、纹理化 Theme
##
## ## 契约与约束
## - bind(vm, translate) 接收状态、本地化和 autosave_available，不访问 AppContext、
##   存档服务或场景树退出 API。
## - 开始、加载、模组、设置、诊断与退出均发出 action_requested(action, params)，
##   由 Shell 执行。
## - 加载按钮的禁用状态只由 autosave_available 决定；页面不自行探测文件。
## - 页面可重复 bind，每次清理旧节点。
##
## ## 皮肤与节点约束（UI 贴图层）
## - 主菜单入口列由 `SNCanvasPanel` 纹理承托，顶部状态行用 `SNChromePanel`；
##   分割线改用 Theme 的 `HSeparator`（主题铜色细线），不再手搓 ColorRect 色块。
## - 按钮文本与顺序不变，图标经 `Button.icon` + Button 的 `icon_max_width` 主题常量
##   （20）接外部 skin：开始→nav_departure、加载→nav_chart、模组→status_locked、
##   设置→nav_intelligence、退出→status_anchor、诊断→status_warning。
## - 文案尺寸保持：入口按钮 360×52 / 17 px、标题 68 px、副标题 16 px、列宽 470、
##   左边距 72；测试与截图依赖这些尺寸和按钮文本。
## - 颜色统一 `SNSkin.color(token)`：标题 `brass.highlight`、眉题/次要 `text.muted`、
##   正文 `text.light`；本页无内联 StyleBox。
## @end-static-doc

signal action_requested(action: StringName, params: Dictionary)

var _tr: Callable
var _update_button: Button = null
var _update_state: Dictionary = {}


func bind(vm: Dictionary, translate: Callable) -> void:
	_tr = translate
	_clear()
	var top_row := HBoxContainer.new()
	var top_spacer := Control.new(); top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(top_spacer)
	var status := SNBadge.new()
	status.text = _loc(String(vm.get("status_key", "ui.status.ok")), "")
	status.tone = int(vm.get("status_tone", SNBadge.Tone.NEUTRAL))
	top_row.add_child(status)
	var update := Button.new()
	update.name = "UpdateButton"
	update.text = _loc("ui.update.check", "检查更新")
	update.theme_type_variation = &"SNGhostButton"
	update.icon = SNSkin.icon("status_time")
	update.add_theme_constant_override("icon_max_width", 20)
	update.pressed.connect(func(): action_requested.emit(&"check_update", {}))
	top_row.add_child(update)
	_update_button = update
	var diagnostics := Button.new()
	diagnostics.text = _loc("ui.button.log", "Diagnostics")
	diagnostics.theme_type_variation = &"SNGhostButton"
	diagnostics.icon = SNSkin.icon("status_warning")
	diagnostics.add_theme_constant_override("icon_max_width", 20)
	diagnostics.pressed.connect(func(): action_requested.emit(&"diagnostics", {}))
	top_row.add_child(diagnostics)
	var top_panel := PanelContainer.new()
	top_panel.name = "MenuStatusRow"
	top_panel.theme_type_variation = &"SNChromePanel"
	top_panel.add_child(top_row)
	add_child(top_panel)

	var shell := HBoxContainer.new(); shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL; shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(shell)
	var margin := MarginContainer.new(); margin.add_theme_constant_override("margin_left", 72); shell.add_child(margin)
	var board := PanelContainer.new()
	board.name = "MenuBoard"
	board.theme_type_variation = &"SNCanvasPanel"
	board.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	margin.add_child(board)
	var column := VBoxContainer.new(); column.custom_minimum_size = Vector2(470, 0); column.alignment = BoxContainer.ALIGNMENT_CENTER; column.add_theme_constant_override("separation", 12); board.add_child(column)
	column.add_child(_label("S T E A M   N A V I G A T O R", 11, SNSkin.color("text.muted")))
	column.add_child(_label(_loc("ui.app.title", "Steam Navigator"), 68, SNSkin.color("brass.highlight")))
	column.add_child(_label(_loc("ui.menu.subtitle", ""), 16, SNSkin.color("text.light")))
	# 分割线由 Theme 提供（HSeparator → StyleBoxLine），不再手写 ColorRect 铜线。
	var rule := HSeparator.new()
	rule.custom_minimum_size = Vector2(360, 1)
	column.add_child(rule)
	var spacer := Control.new(); spacer.custom_minimum_size = Vector2(0, 14); column.add_child(spacer)
	var has_save := bool(vm.get("autosave_available", false))
	column.add_child(_menu_button(_loc("ui.menu.start", "开始游戏"), &"open", {"screen": "new_game"}, false, true, "nav_departure"))
	column.add_child(_menu_button(_loc("ui.menu.load", "加载游戏") if has_save else _loc("ui.menu.load_empty", "加载游戏（无存档）"), &"continue", {}, not has_save, false, "nav_chart"))
	column.add_child(_menu_button(_loc("ui.menu.mods", "模组"), &"open", {"screen": "mods"}, false, false, "status_locked"))
	column.add_child(_menu_button(_loc("ui.menu.settings", "设置"), &"open", {"screen": "settings"}, false, false, "nav_intelligence"))
	column.add_child(_menu_button(_loc("ui.menu.quit", "退出游戏"), &"quit", {}, false, false, "status_anchor"))
	var right_spacer := Control.new(); right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; shell.add_child(right_spacer)
	_render_update_state()


## 更新状态由 Shell 的 UpdateService 推送；只改状态行按钮，不重建入口按钮列。
func set_update_state(state: Dictionary) -> void:
	_update_state = state.duplicate(true)
	_render_update_state()


func _render_update_state() -> void:
	if _update_button == null or not is_instance_valid(_update_button):
		return
	var phase := String(_update_state.get("phase", "idle"))
	var tag := String(_update_state.get("tag", ""))
	var progress := int(round(float(_update_state.get("progress", 0.0)) * 100.0))
	var text := _loc("ui.update.check", "检查更新")
	var disabled := false
	match phase:
		"checking":
			text = _loc("ui.update.checking", "检查更新中……")
			disabled = true
		"downloading":
			text = _loc("ui.update.downloading", "更新下载中 %d%%") % progress
			disabled = true
		"available":
			text = _loc("ui.update.available", "发现新版本 %s") % tag
		"staged":
			text = _loc("ui.update.staged", "重启以完成更新")
		"up_to_date":
			text = _loc("ui.update.up_to_date_short", "已是最新版本")
		"error":
			text = _loc("ui.update.failed_short", "更新失败，点击重试")
	_update_button.text = text
	_update_button.disabled = disabled
	_update_button.tooltip_text = String(_update_state.get("error", ""))


func _menu_button(text: String, action: StringName, params: Dictionary, disabled: bool = false, primary: bool = false, icon_id: String = "") -> Button:
	var button := Button.new(); button.text = text; button.disabled = disabled
	button.custom_minimum_size = Vector2(360, 52); button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.theme_type_variation = &"SNPrimaryButton" if primary else &"SNSecondaryButton"; button.add_theme_font_size_override("font_size", 17)
	button.icon = SNSkin.icon(icon_id)
	button.add_theme_constant_override("icon_max_width", 20)
	button.pressed.connect(func(): action_requested.emit(action, params))
	return button


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size", size); label.add_theme_color_override("font_color", color); return label
func _loc(key: String, fallback: String) -> String:
	var text := String(_tr.call(key)) if _tr.is_valid() else fallback; return fallback if text.is_empty() or text == key else text
func _clear() -> void:
	_update_button = null
	for child in get_children(): remove_child(child); child.free()
