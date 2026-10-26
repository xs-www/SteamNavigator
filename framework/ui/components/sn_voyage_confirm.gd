class_name SNVoyageConfirm
extends Control
## @static-doc
## 作用：海图内的出航确认弹窗（阶段 4.3.4 / U7）。以半透明遮罩 + 居中面板覆盖海图，
## 展示航线预估（距离 / 预计时间 / 煤水 / 风险 / 发现概率）、可行性 blockers、
## 锅炉策略切换与「取消 / 启航」。普通出航与「循线索出航」共用同一个弹窗。
##
## - 关键依赖：Shell 组合好的 `departure` 字典与本地化回调；本控件不查询、不发命令。
##
## ## 契约与约束
## - `bind(data, translate)` 注入数据，数据形状见 `main.gd` 的 `_chart_departure_model()`：
##   `{kind: "voyage"|"explore", target_name, current_port_name, strategy_id,
##     strategies: [{id, name}], preview: {feasible, blockers, distance,
##     duration_hours, coal_required, water_required, risk_score, risk_label,
##     discovery_chance}}`（名称/文案由 Shell 预翻译）。
## - 信号：`strategy_changed(strategy_id)`（Shell 用新策略重新查询预估并重开弹窗）、
##   `confirmed(strategy_id)`（Shell 直接执行 `voyage.start` / `explore.start`）、
##   `cancelled`（关闭弹窗）。
## - 不可行时「启航」禁用、blockers 逐条列出被翻译后的文案；面板不自行判断可行性。
## - 弹窗打开时遮罩吃掉点击（`mouse_filter = STOP`），避免误触下层海图。
## - 4.3.5 连续消耗只改页面读数与结算，不改变本弹窗的数据契约。
##
## ## 场景化结构（P0；契约见 docs/specs/UI_SCENE_MIGRATION.md）
## - `sn_voyage_confirm.tscn` 拥有静态骨架：`ConfirmShade`（全屏遮罩）/ `Center` /
##   `ConfirmPanel`（Theme 变体 `SNPanel`，最小宽度 520）/ `Body`（VBox，sep 10）/
##   `Title` / `Subtitle` / `SeparatorA` / `EstimateBox` / `StrategyRow`
##   （`StrategyLabel` + `StrategyPicker`）/ `BlockersBox` / `SeparatorB` / `Hint` /
##   `Actions`（`Spacer` + `CancelButton` + `ConfirmButton`）。
## - 脚本只负责：本地化文本、估值/阻断行填充、策略项填充、遮罩/文字颜色（`SNSkin` token）、
##   按钮禁用与信号；不再 `remove_child` 整棵重建。重复 `bind()` 只清空
##   `EstimateBox` / `BlockersBox` 这类动态容器，静态骨架复用。
## - 实例化契约：必须 `preload(".../sn_voyage_confirm.tscn").instantiate()`；
##   `SNVoyageConfirm.new()` 只有脚本、没有子树，`bind()` 会安全空返回。
## - 节点名 `ConfirmShade` / `ConfirmPanel` / `CancelButton` / `ConfirmButton` 与
##   面板最小宽 520（场景 `custom_minimum_size.x`）仍是 Shell / 测试的契约。
##
## ## 外观来源（外部贴图 + SNSkin）
## - 面板底层用 Theme 变体 `SNPanel`（黄铜钢框 + 凹槽承托），选钢而不是羊皮纸是因为
##   弹窗叠在海图上、正文含风险/阻断色；深底 + text.light/text.muted 的对比度更稳。
## - 遮罩色取 `SNSkin.color("bg.abyss")` 再降 alpha；正文/风险色全部取
##   `SNSkin.color(token)`（text.light / text.muted / brass.highlight / state.danger /
##   state.success），本文件无 `StyleBoxFlat`、无十六进制色。
## - 按钮样式由场景的 Theme 变体给出：取消 `SNGhostButton`、启航 `SNPrimaryButton`。
## @end-static-doc

signal confirmed(strategy_id: String)
signal cancelled
signal strategy_changed(strategy_id: String)

## 遮罩透明度（`SNSkin.color("bg.abyss")` 上叠加）。
const SHADE_ALPHA := 0.62

var _data: Dictionary = {}
var _tr: Callable
var _strategies: Array = []
var _shade: ColorRect = null
var _title: Label = null
var _subtitle: Label = null
var _estimate_box: VBoxContainer = null
var _strategy_row: HBoxContainer = null
var _strategy_label: Label = null
var _strategy_picker: OptionButton = null
var _blockers_box: VBoxContainer = null
var _hint: Label = null
var _cancel_button: Button = null
var _confirm_button: Button = null
var _wired := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_refs()


## 注入/更新数据并重绘。可以在 `_ready()` 之前调用：场景子树在 `instantiate()` 时
## 已经存在，`_ensure_refs()` 会在进树前解析节点。
func bind(data: Dictionary, translate: Callable) -> void:
	_data = data
	_tr = translate
	_strategies = data.get("strategies", []) if data.get("strategies", []) is Array else []
	if not _ensure_refs():
		return
	_render()


func get_strategy_id() -> String:
	if _strategy_picker != null and _strategies.size() > 0:
		var index := _strategy_picker.selected
		if index >= 0 and index < _strategies.size():
			return String((_strategies[index] as Dictionary).get("id", ""))
	return String(_data.get("strategy_id", ""))


func is_feasible() -> bool:
	var preview: Dictionary = _data.get("preview", {}) if _data.get("preview", null) is Dictionary else {}
	return bool(preview.get("feasible", true))


## 解析场景节点（幂等，返回是否成功）。返回 false 表示当前实例不是由
## `sn_voyage_confirm.tscn` 创建（例如误用 `.new()`），调用方安全跳过渲染。
func _ensure_refs() -> bool:
	if _title != null:
		return true
	_shade = get_node_or_null("ConfirmShade") as ColorRect
	_title = get_node_or_null("Center/ConfirmPanel/Body/Title") as Label
	_subtitle = get_node_or_null("Center/ConfirmPanel/Body/Subtitle") as Label
	_estimate_box = get_node_or_null("Center/ConfirmPanel/Body/EstimateBox") as VBoxContainer
	_strategy_row = get_node_or_null("Center/ConfirmPanel/Body/StrategyRow") as HBoxContainer
	_strategy_label = get_node_or_null("Center/ConfirmPanel/Body/StrategyRow/StrategyLabel") as Label
	_strategy_picker = get_node_or_null("Center/ConfirmPanel/Body/StrategyRow/StrategyPicker") as OptionButton
	_blockers_box = get_node_or_null("Center/ConfirmPanel/Body/BlockersBox") as VBoxContainer
	_hint = get_node_or_null("Center/ConfirmPanel/Body/Hint") as Label
	_cancel_button = get_node_or_null("Center/ConfirmPanel/Body/Actions/CancelButton") as Button
	_confirm_button = get_node_or_null("Center/ConfirmPanel/Body/Actions/ConfirmButton") as Button
	if _title == null or _confirm_button == null:
		return false
	_apply_static_skin()
	_wire()
	return true


## 遮罩与静态文字色：颜色 token 只从 `SNSkin` 来，场景里不复制十六进制值。
func _apply_static_skin() -> void:
	var shade_color := SNSkin.color("bg.abyss")
	shade_color.a = SHADE_ALPHA
	if _shade != null:
		_shade.color = shade_color
	if _title != null:
		_title.add_theme_color_override("font_color", SNSkin.color("brass.highlight"))
	if _subtitle != null:
		_subtitle.add_theme_color_override("font_color", SNSkin.color("text.light"))
	if _hint != null:
		_hint.add_theme_color_override("font_color", SNSkin.color("text.muted"))
	if _strategy_label != null:
		_strategy_label.add_theme_color_override("font_color", SNSkin.color("text.muted"))


## 场景节点只连一次信号；重复 `bind()` 不会重复连接。
func _wire() -> void:
	if _wired:
		return
	_wired = true
	if _cancel_button != null:
		_cancel_button.pressed.connect(func() -> void: cancelled.emit())
	if _confirm_button != null:
		_confirm_button.pressed.connect(func() -> void: confirmed.emit(get_strategy_id()))
	if _strategy_picker != null:
		_strategy_picker.item_selected.connect(_on_strategy_selected)


func _on_strategy_selected(index: int) -> void:
	if _strategy_picker == null:
		return
	var metadata: Variant = _strategy_picker.get_item_metadata(index)
	strategy_changed.emit(String(metadata) if metadata != null else "")


func _render() -> void:
	var kind := String(_data.get("kind", "voyage"))
	var title_fallback := "确认出航" if kind == "voyage" else "循线索出航"
	_title.text = _loc("ui.confirm.title.%s" % kind, title_fallback)
	var current := String(_data.get("current_port_name", ""))
	var target := String(_data.get("target_name", ""))
	var subtitle := ""
	if kind == "explore":
		subtitle = _loc("ui.confirm.clue", "线索：%s") % target
	elif not current.is_empty() and not target.is_empty():
		subtitle = _loc("ui.confirm.route", "航线：%s → %s") % [current, target]
	_subtitle.text = subtitle
	_subtitle.visible = not subtitle.is_empty()

	var preview: Dictionary = _data.get("preview", {}) if _data.get("preview", null) is Dictionary else {}
	_clear_dynamic(_estimate_box)
	_add_estimate_rows(_estimate_box, preview, kind)

	_strategy_row.visible = not _strategies.is_empty()
	_strategy_label.text = _loc("ui.confirm.strategy", "锅炉策略")
	_clear_dynamic(_blockers_box)
	if _strategy_row.visible:
		_fill_strategies()
	_add_blockers(_blockers_box, preview)

	_hint.text = _loc("ui.confirm.hint", "出航后不能更改策略；遇到事件时只能从本次抽样出的选项中选择。")
	_cancel_button.text = _loc("ui.button.cancel", "取消")
	_confirm_button.text = _loc("ui.button.start_voyage", "启航")
	_confirm_button.disabled = not bool(preview.get("feasible", true))


## 清空动态行容器（估值 / 阻断），静态骨架不重建。
func _clear_dynamic(container: VBoxContainer) -> void:
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.free()


## 策略项每次渲染重建（策略列表来自查询层），信号连接在 `_wire()` 里只做一次。
func _fill_strategies() -> void:
	if _strategy_picker == null:
		return
	_strategy_picker.clear()
	var selected := String(_data.get("strategy_id", ""))
	for index in _strategies.size():
		var entry: Dictionary = _strategies[index] if _strategies[index] is Dictionary else {}
		_strategy_picker.add_item(String(entry.get("name", entry.get("id", ""))))
		_strategy_picker.set_item_metadata(index, String(entry.get("id", "")))
		if String(entry.get("id", "")) == selected:
			_strategy_picker.select(index)


func _add_estimate_rows(container: VBoxContainer, preview: Dictionary, kind: String) -> void:
	var distance := float(preview.get("distance", 0.0))
	if distance > 0.0:
		container.add_child(_kv(_loc("ui.label.distance", "距离"), "%d %s" % [
			int(roundf(distance)), _loc("unit.nautical_miles", "海里"),
		]))
	var duration := float(preview.get("duration_hours", 0.0))
	if duration > 0.0:
		container.add_child(_kv(_loc("ui.label.estimated_time", "预计时间"), _format_duration(duration)))
	var coal := float(preview.get("coal_required", 0.0))
	var water := float(preview.get("water_required", 0.0))
	if coal > 0.0 or water > 0.0:
		container.add_child(_kv("%s / %s" % [_loc("ui.label.coal", "煤炭"), _loc("ui.label.water", "淡水")],
			"%s / %s" % [_format_amount(coal), _format_amount(water)]))
	var risk_level := float(preview.get("risk_score", 0.0))
	var risk_band := String(preview.get("risk_label", ""))
	if kind == "explore" and preview.has("discovery_chance"):
		container.add_child(_kv(_loc("ui.confirm.discovery_chance", "发现概率"), "%d%%" % int(roundf(
			clampf(float(preview.get("discovery_chance", 0.0)), 0.0, 1.0) * 100.0
		))))
	if risk_band == "unknown" or risk_level < 0.0:
		container.add_child(_kv(_loc("ui.label.risk", "风险"), _loc("ui.label.risk_unknown", "无法评估")))
	else:
		var band_text := _loc("risk." + risk_band, risk_band) if not risk_band.is_empty() \
			else _loc("risk." + VoyageCalculator.risk_label(risk_level), "")
		container.add_child(_kv(_loc("ui.label.risk", "风险"), band_text, _risk_color(risk_band, risk_level)))
	if preview.get("on_time", true) == false:
		container.add_child(_label(_loc("ui.confirm.on_time", "按本航程预计会迟到。"), 12, SNSkin.color("state.danger")))


func _add_blockers(container: VBoxContainer, preview: Dictionary) -> void:
	var blockers: Array = preview.get("blockers", [])
	if blockers.is_empty():
		return
	container.add_child(_label(_loc("ui.confirm.blockers", "无法出航："), 12, SNSkin.color("state.danger")))
	for blocker in blockers:
		if not (blocker is Dictionary):
			continue
		var message_key := String((blocker as Dictionary).get("message_key", ""))
		if message_key.is_empty():
			continue
		container.add_child(_label("· " + _loc(message_key, String((blocker as Dictionary).get("code", ""))), 11, SNSkin.color("state.danger")))


func _kv(name: String, value: String, color: Variant = null) -> Control:
	var value_color: Color = SNSkin.color("text.light") if color == null else color
	var row := HBoxContainer.new()
	var key := _label(name, 13, SNSkin.color("text.muted"))
	key.custom_minimum_size = Vector2(130, 0)
	row.add_child(key)
	row.add_child(_label(value, 13, value_color))
	return row


func _loc(key: String, fallback: String) -> String:
	if key.is_empty():
		return fallback
	if _tr.is_valid():
		var text := String(_tr.call(key))
		if not text.is_empty() and text != key:
			return text
	return fallback


func _risk_color(band: String, score: float) -> Color:
	match band:
		"low": return SNSkin.color("state.success")
		"medium": return SNSkin.color("brass.highlight")
		"high": return SNSkin.color("state.danger")
		_: return SNSkin.color("text.muted") if score < 0.0 else SNSkin.color("text.light")


## `36` / `36.5` — one decimal only when it adds information.
func _format_amount(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.1f" % value


func _format_duration(hours: float) -> String:
	var total := maxi(0, int(roundf(hours)))
	var days := total / 24
	var remainder := total % 24
	if days > 0 and remainder > 0:
		return "%d %s %d %s" % [days, _loc("unit.days", "天"), remainder, _loc("unit.hours", "小时")]
	if days > 0:
		return "%d %s" % [days, _loc("unit.days", "天")]
	return "%d %s" % [remainder, _loc("unit.hours", "小时")]


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
