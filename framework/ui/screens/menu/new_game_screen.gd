class_name NewGameScreen
extends VBoxContainer
## New-voyage form. It owns local form state and emits a start intent.

signal action_requested(action: StringName, params: Dictionary)

const TEXT := Color("ece1c5")
const MUTED := Color("9fafa7")
const BRASS := Color("e1c487")
var _tr: Callable
var _builds: Array = []
var _selected_build := ""
var _seed_input: LineEdit
var _description: Label


func bind(vm: Dictionary, translate: Callable) -> void:
	_tr = translate; _builds = vm.get("builds", []); _selected_build = String(vm.get("selected_build", "")); _clear()
	add_child(_heading("航程准备", _loc("ui.menu.new_game", "新航程"), "选择初始构筑与种子"))
	var intro := _panel(); var intro_box := _content(intro)
	intro_box.add_child(_label(_loc("ui.app.subtitle", ""), 15, MUTED))
	intro_box.add_child(_label("%s: %d" % [_loc("ui.label.content", "Content"), int(vm.get("content_total", 0))], 14, TEXT))
	intro_box.add_child(_label("%s: %s" % [_loc("ui.label.registry", "Registry"), "frozen" if bool(vm.get("registry_frozen", false)) else "open"], 14, TEXT))
	var mod_names := PackedStringArray(); for mod in vm.get("mods", []): mod_names.append("%s %s" % [mod.get("id", "?"), mod.get("version", "?")])
	intro_box.add_child(_label("%s: %s" % [_loc("ui.label.mods", "Mods"), ", ".join(mod_names)], 14, TEXT)); add_child(intro)

	var form := _panel(); var form_box := _content(form); form_box.add_child(_label(_loc("ui.label.build", "Starting build"), 15, BRASS))
	var option := OptionButton.new(); option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for build in _builds:
		option.add_item(_loc(String(build.get("name_key", "")), String(build.get("id", "")))); option.set_item_metadata(option.item_count - 1, String(build.get("id", "")))
		if _selected_build.is_empty() or _selected_build == String(build.get("id", "")): option.select(option.item_count - 1); _selected_build = String(build.get("id", ""))
	option.item_selected.connect(_on_build_selected.bind(option)); form_box.add_child(option)
	_description = _label("", 13, MUTED); form_box.add_child(_description); _refresh_description()
	var seed_row := HBoxContainer.new(); seed_row.add_child(_label(_loc("ui.label.seed", "Seed"), 14, TEXT))
	_seed_input = LineEdit.new(); _seed_input.placeholder_text = "random"; _seed_input.text = String(vm.get("seed_text", "")); _seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL; seed_row.add_child(_seed_input); form_box.add_child(seed_row)
	var buttons := HBoxContainer.new()
	var start := Button.new(); start.text = _loc("ui.button.new_run", "开始航行"); start.theme_type_variation = &"SNPrimaryButton"; start.size_flags_horizontal = Control.SIZE_EXPAND_FILL; start.pressed.connect(_start); buttons.add_child(start)
	var back := Button.new(); back.text = _loc("ui.menu.back", "返回主菜单"); back.theme_type_variation = &"SNGhostButton"; back.pressed.connect(func(): action_requested.emit(&"back", {})); buttons.add_child(back)
	form_box.add_child(buttons); add_child(form)
	var warnings: Array = vm.get("warnings", [])
	if not warnings.is_empty():
		var warning_panel := _panel(); var warning_box := _content(warning_panel); warning_box.add_child(_label(_loc("ui.label.warnings", "Warnings"), 15, BRASS))
		for warning in warnings.slice(0, 5): warning_box.add_child(_label("• %s" % warning.get("message", ""), 13, MUTED))
		add_child(warning_panel)


func _on_build_selected(_index: int, option: OptionButton) -> void:
	_selected_build = String(option.get_item_metadata(option.selected)); _refresh_description()
func _refresh_description() -> void:
	if _description == null: return
	_description.text = ""
	for build in _builds:
		if String(build.get("id", "")) == _selected_build: _description.text = _loc(String(build.get("description_key", "")), ""); return
func _start() -> void:
	action_requested.emit(&"start_run", {"build_id": _selected_build, "seed_text": _seed_input.text})
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
