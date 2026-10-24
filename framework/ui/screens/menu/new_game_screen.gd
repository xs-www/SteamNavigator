class_name NewGameScreen
extends VBoxContainer
## @static-doc
## 作用：新航程配置页面场景：选择初始构筑和随机种子，展示启动内容摘要与警告。
## New-voyage form. It owns local form state and emits a start intent.
## C4: the picker lists `starting_scenarios` (retired `starting_builds`).
##
## - 关键依赖：`app.view` 启动内容摘要、`SNSectionHeader`、`SNSkin`、纹理化 Theme
##
## ## 契约与约束
## - bind(vm, translate) 接收 builds、selected_scenario、seed_text、mods、内容计数和
##   warnings，不访问注册表或命令总线。
## - 构筑与种子是页面局部表单状态；只有点击开始时才通过 start_run 意图一并交给 Shell。
## - 构筑选择变化只更新本页描述，不触发整页重建。
## - 返回只发出 back 意图；run.start 的参数解析与执行仍由 Shell 负责。
## - 新手剧情模式（tutorial_mode）不渲染 OptionButton，test_story_ui 断言行数。
##
## ## 皮肤与节点约束（UI 贴图层）
## - 启动摘要用 `SNPanel`（钢框），表单与警告用 `SNParchmentPanel` 纸面承托；
##   LineEdit / OptionButton 的凹槽、聚焦框与按钮四态由 Theme 纹理表达。
## - 纸面文字取 `ink.primary` / `paper.ink_muted`、强调 `brass.shadow`；钢框文字取
##   `text.light` / `text.muted`；不再写颜色常量。
## - 尺寸结构不变：表单纵向堆叠、开始按钮 Primary、返回 Ghost、种子行横向、
##   `_label(..., autowrap_word_smart)` 签名被 test_story_ui 间接依赖。
## @end-static-doc

signal action_requested(action: StringName, params: Dictionary)

var _tr: Callable
var _scenarios: Array = []
var _selected_scenario := ""
var _seed_input: LineEdit
var _description: Label


func bind(vm: Dictionary, translate: Callable) -> void:
	_tr = translate; _scenarios = vm.get("scenarios", []); _selected_scenario = String(vm.get("selected_scenario", "")); _clear()
	var tutorial_mode := bool(vm.get("tutorial_mode", false))
	add_child(_heading("航程准备", _loc("ui.menu.new_game", "新航程"), "选择起始场景与种子"))
	var intro := _panel(&"SNPanel"); var intro_box := _content(intro)
	intro_box.add_child(_label(_loc("ui.app.subtitle", ""), 15, SNSkin.color("text.muted")))
	intro_box.add_child(_label("%s: %d" % [_loc("ui.label.content", "Content"), int(vm.get("content_total", 0))], 14, SNSkin.color("text.light")))
	intro_box.add_child(_label("%s: %s" % [_loc("ui.label.registry", "Registry"), "frozen" if bool(vm.get("registry_frozen", false)) else "open"], 14, SNSkin.color("text.light")))
	var mod_names := PackedStringArray(); for mod in vm.get("mods", []): mod_names.append("%s %s" % [mod.get("id", "?"), mod.get("version", "?")])
	intro_box.add_child(_label("%s: %s" % [_loc("ui.label.mods", "Mods"), ", ".join(mod_names)], 14, SNSkin.color("text.light"))); add_child(intro)

	var form := _panel(&"SNParchmentPanel"); var form_box := _content(form)
	if tutorial_mode:
		# 4.5.2 新手剧情：固定教学场景，隐藏场景选择。
		form_box.add_child(_label(_loc("ui.new_game.tutorial_note", "新手剧情：本局使用默认教学船"), 14, SNSkin.color("brass.shadow")))
	else:
		form_box.add_child(_label(_loc("ui.label.starting_scenario", "起始场景"), 15, SNSkin.color("brass.shadow")))
		var option := OptionButton.new(); option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for scenario in _scenarios:
			option.add_item(_loc(String(scenario.get("name_key", "")), String(scenario.get("id", "")))); option.set_item_metadata(option.item_count - 1, String(scenario.get("id", "")))
			if _selected_scenario.is_empty() or _selected_scenario == String(scenario.get("id", "")): option.select(option.item_count - 1); _selected_scenario = String(scenario.get("id", ""))
		option.item_selected.connect(_on_scenario_selected.bind(option)); form_box.add_child(option)
		_description = _label("", 13, SNSkin.color("paper.ink_muted")); form_box.add_child(_description); _refresh_description()
	var seed_row := HBoxContainer.new(); var seed_label := _label(_loc("ui.label.seed", "Seed"), 14, SNSkin.color("ink.primary")); seed_label.autowrap_mode = TextServer.AUTOWRAP_OFF; seed_label.custom_minimum_size.x = 56.0; seed_row.add_child(seed_label)
	_seed_input = LineEdit.new(); _seed_input.placeholder_text = "random"; _seed_input.text = String(vm.get("seed_text", "")); _seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL; seed_row.add_child(_seed_input); form_box.add_child(seed_row)
	var buttons := HBoxContainer.new()
	var start := Button.new(); start.text = _loc("ui.button.new_run", "开始航行"); start.theme_type_variation = &"SNPrimaryButton"; start.size_flags_horizontal = Control.SIZE_EXPAND_FILL; start.pressed.connect(_start); buttons.add_child(start)
	var back := Button.new(); back.text = _loc("ui.menu.back", "返回主菜单"); back.theme_type_variation = &"SNGhostButton"; back.pressed.connect(func(): action_requested.emit(&"back", {})); _ink_text(back); buttons.add_child(back)
	form_box.add_child(buttons); add_child(form)
	var warnings: Array = vm.get("warnings", [])
	if not warnings.is_empty():
		var warning_panel := _panel(&"SNParchmentPanel"); var warning_box := _content(warning_panel); warning_box.add_child(_label(_loc("ui.label.warnings", "Warnings"), 15, SNSkin.color("brass.shadow")))
		for warning in warnings.slice(0, 5): warning_box.add_child(_label("• %s" % warning.get("message", ""), 13, SNSkin.color("ink.primary")))
		add_child(warning_panel)


func _on_scenario_selected(_index: int, option: OptionButton) -> void:
	_selected_scenario = String(option.get_item_metadata(option.selected)); _refresh_description()
func _refresh_description() -> void:
	if _description == null: return
	_description.text = ""
	for scenario in _scenarios:
		if String(scenario.get("id", "")) == _selected_scenario: _description.text = _loc(String(scenario.get("description_key", "")), ""); return
func _start() -> void:
	action_requested.emit(&"start_run", {"starting_scenario": _selected_scenario, "seed_text": _seed_input.text})
func _panel(variation: StringName = &"SNPanel") -> PanelContainer:
	var panel := PanelContainer.new(); panel.theme_type_variation = variation; panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; return panel
func _content(panel: PanelContainer) -> VBoxContainer:
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 8); panel.add_child(box); return box
func _heading(eyebrow: String, title: String, detail: String) -> SNSectionHeader:
	var header := SNSectionHeader.new(); header.eyebrow = eyebrow; header.title = title; header.detail = detail; return header
func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size", size); label.add_theme_color_override("font_color", color); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; return label


## Ghost buttons on the parchment form need ink text; the default light Ghost
## label disappears on paper and would also break when a skin swaps the sheet.
func _ink_text(button: Button) -> void:
	button.add_theme_color_override("font_color", SNSkin.color("ink.primary"))
	button.add_theme_color_override("font_hover_color", SNSkin.color("brass.shadow"))
	button.add_theme_color_override("font_pressed_color", SNSkin.color("brass.shadow"))
	button.add_theme_color_override("font_focus_color", SNSkin.color("ink.primary"))
	button.add_theme_color_override("font_disabled_color", SNSkin.color("paper.ink_muted"))
func _loc(key: String, fallback: String) -> String:
	var text := String(_tr.call(key)) if _tr.is_valid() else fallback; return fallback if text.is_empty() or text == key else text
func _clear() -> void:
	for child in get_children(): remove_child(child); child.free()
