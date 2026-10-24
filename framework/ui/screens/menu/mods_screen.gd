class_name ModsScreen
extends VBoxContainer
## @static-doc
## 作用：已加载模组列表页面场景：只读展示本次启动实际载入的模组及依赖。
##
## - 关键依赖：`app.view` 的 mods 摘要、`SNSectionHeader`、`SNSkin`、纹理化 Theme
##
## ## 契约与约束
## - bind(vm, translate) 只消费 app.view 的 mods 摘要，不扫描文件系统、不改变加载顺序。
## - 返回与重新扫描分别发出 back/retry 意图，Bootstrap 重试由 Shell 执行。
## - 每个模组显示名称、ID、版本、来源、依赖与 required 标记。
##
## ## 皮肤与节点约束（UI 贴图层）
## - 说明条用 `SNParchmentPanel` 纸签，模组条目用 `SNPanel` 钢制铭牌承托；
##   模组名 `brass.highlight`、版本/来源/依赖等次要行 `text.muted`。
## - 底部返回用 `SNGhostButton`、重新扫描用 `SNSecondaryButton`；按钮文本与顺序不变。
## - 颜色统一 `SNSkin.color(token)`，不再保留颜色常量或内联样式；
##   条目密度（13/17 px、8 px 分隔）与列表顺序不变。
## @end-static-doc

signal action_requested(action: StringName, params: Dictionary)

var _tr: Callable


func bind(vm: Dictionary, translate: Callable) -> void:
	_tr = translate; _clear(); add_child(_heading("模组", _loc("ui.menu.mods_title", "已加载模组"), "启动时实际加载的内容包"))
	var note := _panel(&"SNParchmentPanel"); _content(note).add_child(_label(_loc("ui.menu.mods_note", "模组启用/禁用和加载顺序管理尚未实现；这里显示本次启动实际加载的模组。"), 13, SNSkin.color("ink.primary"))); add_child(note)
	for mod in vm.get("mods", []):
		var panel := _panel(&"SNPanel"); var box := _content(panel); var header := HBoxContainer.new(); var name := _label("%s  ·  %s" % [String(mod.get("name", mod.get("id", ""))), String(mod.get("id", ""))], 17, SNSkin.color("brass.highlight")); name.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(name); header.add_child(_label("v%s" % String(mod.get("version", "?")), 13, SNSkin.color("text.muted"))); box.add_child(header)
		var source := String(mod.get("source", "")); if not source.is_empty(): box.add_child(_label("%s：%s" % [_loc("ui.menu.source", "源"), source], 12, SNSkin.color("text.muted")))
		var dependencies: Array = mod.get("dependencies", []); box.add_child(_label("%s：%s" % [_loc("ui.menu.dependencies", "依赖"), ", ".join(dependencies) if not dependencies.is_empty() else "—"], 12, SNSkin.color("text.muted"))); box.add_child(_label("%s：%s" % [_loc("ui.menu.required", "必需"), _loc("ui.menu.yes", "是") if bool(mod.get("required", false)) else _loc("ui.menu.no", "否")], 12, SNSkin.color("text.muted"))); add_child(panel)
	var footer := HBoxContainer.new(); footer.add_child(_button(_loc("ui.menu.back", "返回主菜单"), &"back", &"SNGhostButton")); footer.add_child(_button(_loc("ui.menu.rescan", "重新扫描"), &"retry", &"SNSecondaryButton")); add_child(footer)


func _button(text: String, action: StringName, variation: StringName) -> Button:
	var button := Button.new(); button.text = text; button.theme_type_variation = variation; button.pressed.connect(func(): action_requested.emit(action, {})); return button
func _panel(variation: StringName) -> PanelContainer:
	var panel := PanelContainer.new(); panel.theme_type_variation = variation; panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; return panel
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
