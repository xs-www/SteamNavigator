class_name MainMenuScreen
extends VBoxContainer
## Main-menu presentation. All application actions are delegated to the shell.

signal action_requested(action: StringName, params: Dictionary)

const BRASS := Color("e1c487")
const TEXT := Color("ece1c5")
const MUTED := Color("9fafa7")
var _tr: Callable


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
	var diagnostics := Button.new(); diagnostics.text = _loc("ui.button.log", "Diagnostics"); diagnostics.theme_type_variation = &"SNGhostButton"
	diagnostics.pressed.connect(func(): action_requested.emit(&"diagnostics", {}))
	top_row.add_child(diagnostics); add_child(top_row)

	var shell := HBoxContainer.new(); shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL; shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(shell)
	var margin := MarginContainer.new(); margin.add_theme_constant_override("margin_left", 72); shell.add_child(margin)
	var column := VBoxContainer.new(); column.custom_minimum_size = Vector2(470, 0); column.alignment = BoxContainer.ALIGNMENT_CENTER; column.add_theme_constant_override("separation", 12); margin.add_child(column)
	column.add_child(_label("S T E A M   N A V I G A T O R", 11, MUTED))
	column.add_child(_label(_loc("ui.app.title", "Steam Navigator"), 68, BRASS))
	column.add_child(_label(_loc("ui.menu.subtitle", ""), 16, TEXT))
	var rule := ColorRect.new(); rule.color = Color(BRASS, 0.45); rule.custom_minimum_size = Vector2(360, 1); column.add_child(rule)
	var spacer := Control.new(); spacer.custom_minimum_size = Vector2(0, 14); column.add_child(spacer)
	var has_save := bool(vm.get("autosave_available", false))
	column.add_child(_menu_button(_loc("ui.menu.start", "开始游戏"), &"open", {"screen": "new_game"}, false, true))
	column.add_child(_menu_button(_loc("ui.menu.load", "加载游戏") if has_save else _loc("ui.menu.load_empty", "加载游戏（无存档）"), &"continue", {}, not has_save))
	column.add_child(_menu_button(_loc("ui.menu.mods", "模组"), &"open", {"screen": "mods"}))
	column.add_child(_menu_button(_loc("ui.menu.settings", "设置"), &"open", {"screen": "settings"}))
	column.add_child(_menu_button(_loc("ui.menu.quit", "退出游戏"), &"quit", {}))
	var right_spacer := Control.new(); right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; shell.add_child(right_spacer)


func _menu_button(text: String, action: StringName, params: Dictionary, disabled: bool = false, primary: bool = false) -> Button:
	var button := Button.new(); button.text = text; button.disabled = disabled
	button.custom_minimum_size = Vector2(360, 52); button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.theme_type_variation = &"SNPrimaryButton" if primary else &"SNSecondaryButton"; button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(func(): action_requested.emit(action, params))
	return button


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size", size); label.add_theme_color_override("font_color", color); return label
func _loc(key: String, fallback: String) -> String:
	var text := String(_tr.call(key)) if _tr.is_valid() else fallback; return fallback if text.is_empty() or text == key else text
func _clear() -> void:
	for child in get_children(): remove_child(child); child.free()
