class_name SettingsScreen
extends VBoxContainer
## Runtime settings presentation. Persistence remains in the shell.

signal action_requested(action: StringName, params: Dictionary)

const TEXT := Color("ece1c5")
const MUTED := Color("9fafa7")
var _tr: Callable


func bind(vm: Dictionary, translate: Callable) -> void:
	_tr = translate; _clear(); add_child(_heading("偏好", _loc("ui.menu.settings_title", "设置"), "语言与自动存档"))
	var panel := _panel(); var box := _content(panel); var locale_row := HBoxContainer.new(); locale_row.add_theme_constant_override("separation", 10); locale_row.add_child(_field_label(_loc("ui.menu.language", "语言"))); locale_row.add_child(_button("中文", &"set_locale", {"locale": "zh_CN"})); locale_row.add_child(_button("English", &"set_locale", {"locale": "en"})); locale_row.add_child(_label("%s：%s" % [_loc("ui.menu.current", "当前"), "中文" if String(vm.get("locale", "zh_CN")) == "zh_CN" else "English"], 13, MUTED)); box.add_child(locale_row)
	var autosave_row := HBoxContainer.new(); autosave_row.add_theme_constant_override("separation", 10); autosave_row.add_child(_field_label(_loc("ui.menu.autosave", "自动存档"))); var enabled := bool(vm.get("autosave_enabled", true)); autosave_row.add_child(_button(_loc("ui.menu.autosave_on", "开") if enabled else _loc("ui.menu.autosave_off", "关"), &"toggle_autosave", {})); autosave_row.add_child(_label(_loc("ui.menu.autosave_note", "关闭后本次运行不再自动写入自动存档。"), 12, MUTED)); box.add_child(autosave_row); add_child(panel)
	var note := _panel(); var note_box := _content(note); note_box.add_child(_label(_loc("ui.menu.settings_note", "设置仅对本次运行生效。"), 12, MUTED)); if bool(vm.get("show_settings_path", false)): note_box.add_child(_label(_loc("ui.menu.settings_path", "保存位置：user://config/config.json（默认 config/config.json）"), 12, MUTED)); add_child(note)
	add_child(_button(_loc("ui.menu.back", "返回主菜单"), &"back", {}))


func _button(text: String, action: StringName, params: Dictionary) -> Button:
	var button := Button.new(); button.text = text; button.pressed.connect(func(): action_requested.emit(action, params)); return button
func _panel() -> PanelContainer:
	var panel := PanelContainer.new(); panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; return panel
func _content(panel: PanelContainer) -> VBoxContainer:
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 8); panel.add_child(box); return box
func _heading(eyebrow: String, title: String, detail: String) -> SNSectionHeader:
	var header := SNSectionHeader.new(); header.eyebrow = eyebrow; header.title = title; header.detail = detail; return header
func _field_label(text: String) -> Label:
	var label := _label(text, 15, TEXT); label.custom_minimum_size.x = 96; return label
func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size", size); label.add_theme_color_override("font_color", color); label.autowrap_mode = TextServer.AUTOWRAP_OFF; return label
func _loc(key: String, fallback: String) -> String:
	var text := String(_tr.call(key)) if _tr.is_valid() else fallback; return fallback if text.is_empty() or text == key else text
func _clear() -> void:
	for child in get_children(): remove_child(child); child.free()
