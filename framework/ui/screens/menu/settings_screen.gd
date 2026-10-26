class_name SettingsScreen
extends VBoxContainer
## @static-doc
## 作用：设置页面场景：展示语言、自动存档与「允许上传数据」三项设置，并发出设置修改意图。
##
## - 关键依赖：`settings` / Shell 组合的视图模型、`SNSectionHeader`、`SNSkin`、纹理化 Theme
##
## ## 契约与约束
## - bind(vm, translate) 接收 locale、autosave_enabled、telemetry_enabled 与 show_settings_path，
##   不直接读写 SettingsService。
## - 语言 / 自动存档 / 游玩数据上传分别只发出 set_locale / toggle_autosave / toggle_telemetry；
##   Shell 更新运行时上下文并持久化（telemetry 契约见 docs/design/TELEMETRY.md §2）。
## - 设置项标签保留固定字段宽度（96 px），横向选项和状态文案禁止智能折成逐字竖排
##   （`_label` 关闭自动换行，test_ui_shell 直接调用 `_label` 断言这一点）。
## - 游玩数据上传的说明文案用 `ui.menu.telemetry_note`，默认关（vm 的 telemetry_enabled）。
## - 返回主菜单只发出 back 意图；配置保存结果由 Shell 状态条反馈。
##
## ## 皮肤与节点约束（UI 贴图层）
## - 表单用 `SNParchmentPanel` 纸面承托，说明条用 `SNPanel` 钢框；字段名
##   `ink.primary`、当前值/说明 `paper.ink_muted`，按钮统一 Theme 变体
##   （语言切换 `SNSecondaryButton`、自动存档/上传开关 `SNPlateButton`、返回 `SNGhostButton`）。
## - 颜色只取 `SNSkin.color(token)`；`_label(text, size, color)` 签名与 96 px 字段宽、
##   三行设置结构（语言 / 自动存档 / 允许上传数据）、按钮文本均不变。
## @end-static-doc

signal action_requested(action: StringName, params: Dictionary)

var _tr: Callable


func bind(vm: Dictionary, translate: Callable) -> void:
	_tr = translate; _clear(); add_child(_heading("偏好", _loc("ui.menu.settings_title", "设置"), "语言、自动存档与游玩数据"))
	var panel := _panel(&"SNParchmentPanel"); var box := _content(panel); var locale_row := HBoxContainer.new(); locale_row.add_theme_constant_override("separation", 10); locale_row.add_child(_field_label(_loc("ui.menu.language", "语言"))); locale_row.add_child(_button("中文", &"set_locale", {"locale": "zh_CN"}, &"SNSecondaryButton")); locale_row.add_child(_button("English", &"set_locale", {"locale": "en"}, &"SNSecondaryButton")); locale_row.add_child(_label("%s：%s" % [_loc("ui.menu.current", "当前"), "中文" if String(vm.get("locale", "zh_CN")) == "zh_CN" else "English"], 13, SNSkin.color("paper.ink_muted"))); box.add_child(locale_row)
	var autosave_row := HBoxContainer.new(); autosave_row.add_theme_constant_override("separation", 10); autosave_row.add_child(_field_label(_loc("ui.menu.autosave", "自动存档"))); var enabled := bool(vm.get("autosave_enabled", true)); autosave_row.add_child(_button(_loc("ui.menu.autosave_on", "开") if enabled else _loc("ui.menu.autosave_off", "关"), &"toggle_autosave", {}, &"SNPlateButton")); autosave_row.add_child(_label(_loc("ui.menu.autosave_note", "关闭后本次运行不再自动写入自动存档。"), 12, SNSkin.color("paper.ink_muted"))); box.add_child(autosave_row)
	# 游玩数据上传（TELEMETRY.md §2）：默认关，切换即时写回配置；说明文案在右侧。
	var telemetry_row := HBoxContainer.new(); telemetry_row.add_theme_constant_override("separation", 10); telemetry_row.add_child(_field_label(_loc("ui.menu.telemetry", "允许上传数据"))); var telemetry_enabled := bool(vm.get("telemetry_enabled", false)); telemetry_row.add_child(_button(_loc("ui.menu.telemetry_on", "开") if telemetry_enabled else _loc("ui.menu.telemetry_off", "关"), &"toggle_telemetry", {}, &"SNPlateButton")); telemetry_row.add_child(_label(_loc("ui.menu.telemetry_note", "勾选后，每次结束游玩时会把本局游戏日志上传到官网，用于改进游戏；仅含游玩数据，不含个人信息。"), 12, SNSkin.color("paper.ink_muted"))); box.add_child(telemetry_row); add_child(panel)
	var note := _panel(&"SNPanel"); var note_box := _content(note); note_box.add_child(_label(_loc("ui.menu.settings_note", "设置仅对本次运行生效。"), 12, SNSkin.color("text.muted"))); if bool(vm.get("show_settings_path", false)): note_box.add_child(_label(_loc("ui.menu.settings_path", "保存位置：user://config/config.json（默认 config/config.json）"), 12, SNSkin.color("text.muted"))); add_child(note)
	add_child(_button(_loc("ui.menu.back", "返回主菜单"), &"back", {}, &"SNGhostButton"))


func _button(text: String, action: StringName, params: Dictionary, variation: StringName = &"SNSecondaryButton") -> Button:
	var button := Button.new(); button.text = text; button.theme_type_variation = variation; button.pressed.connect(func(): action_requested.emit(action, params)); return button
func _panel(variation: StringName) -> PanelContainer:
	var panel := PanelContainer.new(); panel.theme_type_variation = variation; panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; return panel
func _content(panel: PanelContainer) -> VBoxContainer:
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 8); panel.add_child(box); return box
func _heading(eyebrow: String, title: String, detail: String) -> SNSectionHeader:
	var header := SNSectionHeader.new(); header.eyebrow = eyebrow; header.title = title; header.detail = detail; return header
func _field_label(text: String) -> Label:
	var label := _label(text, 15, SNSkin.color("ink.primary")); label.custom_minimum_size.x = 96; return label
func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size", size); label.add_theme_color_override("font_color", color); label.autowrap_mode = TextServer.AUTOWRAP_OFF; return label
func _loc(key: String, fallback: String) -> String:
	var text := String(_tr.call(key)) if _tr.is_valid() else fallback; return fallback if text.is_empty() or text == key else text
func _clear() -> void:
	for child in get_children(): remove_child(child); child.free()
