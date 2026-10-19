class_name ModsScreen
extends VBoxContainer
## Read-only loaded-mod list with navigation and rescan intents.

signal action_requested(action: StringName, params: Dictionary)

const TEXT := Color("ece1c5")
const MUTED := Color("9fafa7")
const BRASS := Color("e1c487")
var _tr: Callable


func bind(vm: Dictionary, translate: Callable) -> void:
	_tr = translate; _clear(); add_child(_heading("模组", _loc("ui.menu.mods_title", "已加载模组"), "启动时实际加载的内容包"))
	var note := _panel(); _content(note).add_child(_label(_loc("ui.menu.mods_note", "模组启用/禁用和加载顺序管理尚未实现；这里显示本次启动实际加载的模组。"), 13, MUTED)); add_child(note)
	for mod in vm.get("mods", []):
		var panel := _panel(); var box := _content(panel); var header := HBoxContainer.new(); var name := _label("%s  ·  %s" % [String(mod.get("name", mod.get("id", ""))), String(mod.get("id", ""))], 17, BRASS); name.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(name); header.add_child(_label("v%s" % String(mod.get("version", "?")), 13, MUTED)); box.add_child(header)
		var source := String(mod.get("source", "")); if not source.is_empty(): box.add_child(_label("%s：%s" % [_loc("ui.menu.source", "源"), source], 12, MUTED))
		var dependencies: Array = mod.get("dependencies", []); box.add_child(_label("%s：%s" % [_loc("ui.menu.dependencies", "依赖"), ", ".join(dependencies) if not dependencies.is_empty() else "—"], 12, MUTED)); box.add_child(_label("%s：%s" % [_loc("ui.menu.required", "必需"), _loc("ui.menu.yes", "是") if bool(mod.get("required", false)) else _loc("ui.menu.no", "否")], 12, MUTED)); add_child(panel)
	var footer := HBoxContainer.new(); footer.add_child(_button(_loc("ui.menu.back", "返回主菜单"), &"back")); footer.add_child(_button(_loc("ui.menu.rescan", "重新扫描"), &"retry")); add_child(footer)


func _button(text: String, action: StringName) -> Button:
	var button := Button.new(); button.text = text; button.pressed.connect(func(): action_requested.emit(action, {})); return button
func _panel() -> PanelContainer:
	var panel := PanelContainer.new(); panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; return panel
func _content(panel: PanelContainer) -> VBoxContainer:
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 8); panel.add_child(box); return box
func _heading(eyebrow: String, title: String, detail: String) -> SNSectionHeader:
	var header := SNSectionHeader.new(); header.eyebrow = eyebrow; header.title = title; header.detail = detail; return header
func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size", size); label.add_theme_color_override("font_color", color); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; return label
func _loc(key: String, fallback: String) -> String:
	var text := String(_tr.call(key)) if _tr.is_valid() else fallback; return fallback if text.is_empty() or text == key else text
func _clear() -> void:
	for child in get_children(): remove_child(child); child.free()
