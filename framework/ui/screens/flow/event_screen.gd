class_name EventScreen
extends VBoxContainer
## Voyage-event choice presentation.
##
## 普通航行事件与 4.2 资源告急页共用这一版式。选项按钮只发 `command_requested`，
## 由 Shell 决定把它接到 `event.choose_option` 还是资源告急决策；提示行默认是
## 「选择后会立即结算」，事件 VM 可以用 `hint_text`（已本地化）或 `hint_key`
## （交给翻译回调）覆盖它——资源告急的 `continue` 不会立刻结算，需要换文案。

signal command_requested(command: StringName, params: Dictionary)

const TEXT := Color("ece1c5")
const MUTED := Color("9fafa7")
const RED := Color("c36b53")
## 没有 hint 覆盖时保持原有文案（普通事件的外观/语义一行不改）。
const DEFAULT_HINT := "从以下方案中选择一个，选择后会立即结算。"
var _tr: Callable


func bind(vm: Dictionary, translate: Callable) -> void:
	_tr = translate; _clear(); var event: Dictionary = vm.get("event", {}); var ship: Dictionary = vm.get("ship", {}); var panel := PanelContainer.new(); var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 8); panel.add_child(box)
	box.add_child(_label(_loc(String(event.get("name_key", "")), String(event.get("event_id", ""))), 22, RED))
	var description_key := String(event.get("description_key", ""))
	if not description_key.is_empty():
		box.add_child(_label(_loc(description_key, ""), 14, TEXT))
	box.add_child(_label("耐久 %s / %s · 淡水 %s · 煤炭 %s · 金币 %d" % [_fmt(float(ship.get("durability", 0.0))), _fmt(float(ship.get("max_durability", 0.0))), _fmt(float(ship.get("water", 0.0))), _fmt(float(ship.get("coal", 0.0))), int(vm.get("money", 0))], 13, MUTED)); box.add_child(_label(_hint_text(event), 12, MUTED))
	for option in event.get("options", []):
		var option_id := String(option.get("id", "")); var button := Button.new(); button.text = _loc(String(option.get("name_key", "")), option_id); button.pressed.connect(_choose_option.bind(option_id)); box.add_child(button)
	add_child(panel)


## 提示行：`hint_text`（Shell 已经拼好的本地化文本）优先，其次 `hint_key`，
## 都没有时保留普通事件的原文案。
func _hint_text(event: Dictionary) -> String:
	var text := String(event.get("hint_text", ""))
	if not text.is_empty():
		return text
	var hint_key := String(event.get("hint_key", ""))
	if not hint_key.is_empty():
		text = _loc(hint_key, "")
		if not text.is_empty():
			return text
	return DEFAULT_HINT


func _choose_option(option_id: String) -> void:
	command_requested.emit(&"event.choose_option", {"option_id": option_id})
func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size", size); label.add_theme_color_override("font_color", color); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; return label
func _loc(key: String, fallback: String) -> String:
	var text := String(_tr.call(key)) if _tr.is_valid() else fallback; return fallback if text.is_empty() or text == key else text
func _fmt(value: float) -> String: return "%.1f" % value
func _clear() -> void:
	for child in get_children(): remove_child(child); child.free()
