class_name SettlementScreen
extends VBoxContainer
## @static-doc
## 作用：抵达结算页。展示委托收入 / 准时 / 延误、船况资源、交付明细与旅客受伤，
## 并在 `summary.explore` 存在时追加**探索结果**区块（探索系统 4.1）：结果
## （发现 / 失败漂流 / 掉头返航）、港口名、额外煤水与耐久损失、线索状态说明。
##
## ## 契约与约束
## - 只读 `bind(vm)` 里的 summary / ship / money；不查询后端、不发命令。
## - 探索区块只在 `summary.explore` 存在时追加，委托结算的既有布局不变。
## - 新文案走 `_loc(key, fallback)`：键先按契约编码，本地化缺失时回退中文，
##   不渲染 `ui.*` 原始键名。
## @end-static-doc

signal navigation_requested(screen_id: StringName, params: Dictionary)

const TEXT := Color("ece1c5")
const MUTED := Color("9fafa7")
const BRASS := Color("e1c487")
const RED := Color("c36b53")
const GREEN := Color("76aa8c")
## 探索结算回退文案（键由领域侧本地化提供；缺键时不能让玩家看到 `ui.explore.*`）。
const EXPLORE_RESULT_FALLBACK := {
	"discovered": "发现新港口",
	"failed": "探索失败，漂流返航",
	"turned_back": "掉头返航",
}
const EXPLORE_CLUE_STATUS_FALLBACK := {
	"discovered": "线索已解决：目标港口已标入海图。",
	"failed": "线索已作废：这次探索没能找到它的目标。",
	"turned_back": "线索保留：仍可按此线索再次出航。",
}
## 结果 → 线索状态键。发现即解决；失败即作废；返航保留原文线索。
const EXPLORE_CLUE_STATUS_KEY := {
	"discovered": "ui.explore.clue_resolved",
	"failed": "ui.explore.clue_failed",
	"turned_back": "ui.explore.clue_retained",
}
var _tr: Callable


func bind(vm: Dictionary, translate: Callable) -> void:
	_tr = translate; _clear()
	var summary: Dictionary = vm.get("summary", {}); var ship: Dictionary = vm.get("ship", {}); var contracts: Array = summary.get("contracts", [])
	add_child(_heading("航次完成", "抵达 %s" % String(vm.get("destination_name", "目的港")), ClockService.format_time(float(summary.get("arrival_time", 0.0)))))
	var panel := _panel(); panel.theme_type_variation = &"SNElevatedPanel"; var box := _content(panel); var payout := 0; var on_time := 0
	for contract in contracts:
		if contract is Dictionary:
			payout += int(contract.get("payout", 0))
			if bool(contract.get("on_time", false)):
				on_time += 1
	var stats := HBoxContainer.new(); stats.add_theme_constant_override("separation", 6); stats.add_child(_stat("委托收入", str(payout), BRASS)); stats.add_child(VSeparator.new()); stats.add_child(_stat("准时交付", "%d / %d" % [on_time, contracts.size()], GREEN)); stats.add_child(VSeparator.new()); var delayed := float(summary.get("delayed_hours", 0.0)); stats.add_child(_stat("延误", "%s h" % _fmt(delayed), RED if delayed > 0.0 else TEXT)); stats.add_child(VSeparator.new()); stats.add_child(_stat("当前金币", str(int(vm.get("money", 0))), BRASS)); box.add_child(stats)
	var resources := HBoxContainer.new(); resources.add_theme_constant_override("separation", 18); resources.add_child(_badge("煤炭 %s" % _fmt(float(ship.get("coal", 0.0))), SNBadge.Tone.WARNING)); resources.add_child(_badge("淡水 %s" % _fmt(float(ship.get("water", 0.0))), SNBadge.Tone.NEUTRAL)); resources.add_child(_badge("耐久 %s / %s" % [_fmt(float(ship.get("durability", 0.0))), _fmt(float(ship.get("max_durability", 0.0)))], SNBadge.Tone.SUCCESS if float(ship.get("durability", 0.0)) > float(ship.get("max_durability", 1.0)) * 0.5 else SNBadge.Tone.DANGER)); box.add_child(resources)
	if not contracts.is_empty(): box.add_child(_label("交付明细", 14, BRASS))
	for contract in contracts:
		if not (contract is Dictionary): continue
		var row := HBoxContainer.new(); var name := _label(String(contract.get("display_name", contract.get("template_id", ""))), 13, TEXT); name.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(name); var timely := bool(contract.get("on_time", false)); row.add_child(_badge("准时" if timely else "延误", SNBadge.Tone.SUCCESS if timely else SNBadge.Tone.DANGER)); row.add_child(_label("+%d" % int(contract.get("payout", 0)), 13, BRASS)); box.add_child(row)
	var injuries := int(summary.get("injuries", 0))
	if injuries > 0:
		box.add_child(_label("旅客受伤 %d 人" % injuries, 13, RED))
	var explore: Variant = summary.get("explore", null)
	if explore is Dictionary and not (explore as Dictionary).is_empty():
		box.add_child(_explore_block(explore as Dictionary, String(vm.get("destination_name", "目的港"))))
	var enter := Button.new(); enter.text = "进入港口"; enter.pressed.connect(func(): navigation_requested.emit(&"overview", {})); box.add_child(enter); add_child(panel)


func _stat(name: String, value: String, color: Color) -> Control:
	var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; var key := _label(name, 11, MUTED); key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(key); var val := _label(value, 16, color); val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(val); return box


## 探索结果区块：结果 + 港口 + 额外损耗 + 线索状态。只在 `summary.explore` 存在时
## 追加，委托结算的既有行不受影响。
func _explore_block(explore: Dictionary, destination_name: String) -> Control:
	var section := VBoxContainer.new()
	section.name = "ExploreBlock"
	section.add_theme_constant_override("separation", 4)
	var result := String(explore.get("result", ""))
	var tone := GREEN
	if result == "failed":
		tone = RED
	elif result == "turned_back":
		tone = BRASS
	section.add_child(_label(_loc("ui.explore.section_title", "探索结果"), 14, BRASS))
	section.add_child(_label(
		_loc("ui.explore.result." + result, String(EXPLORE_RESULT_FALLBACK.get(result, result))),
		15, tone
	))
	var port_name := destination_name
	var port_key := String(explore.get("port_name_key", ""))
	if not port_key.is_empty():
		port_name = _loc(port_key, destination_name)
	if not port_name.is_empty():
		section.add_child(_label(
			"%s: %s" % [_loc("ui.explore.destination", "抵达港口"), port_name], 13, TEXT
		))
	var losses: Array[String] = []
	var extra_coal := float(explore.get("extra_coal", 0.0))
	var extra_water := float(explore.get("extra_water", 0.0))
	var durability_loss := float(explore.get("durability_loss", 0.0))
	if extra_coal > 0.0001:
		losses.append("%s +%s" % [_loc("ui.label.coal", "煤炭"), _fmt(extra_coal)])
	if extra_water > 0.0001:
		losses.append("%s +%s" % [_loc("ui.label.water", "淡水"), _fmt(extra_water)])
	if durability_loss > 0.0001:
		losses.append("%s -%s" % [_loc("ui.label.durability", "耐久"), _fmt(durability_loss)])
	if not losses.is_empty():
		section.add_child(_label(
			"%s: %s" % [_loc("ui.explore.extra_losses", "额外损耗"), " · ".join(losses)], 12, RED
		))
	var clue_status := String(EXPLORE_CLUE_STATUS_FALLBACK.get(result, ""))
	if not clue_status.is_empty():
		var status_key := String(EXPLORE_CLUE_STATUS_KEY.get(result, ""))
		clue_status = _loc(status_key, clue_status)
		section.add_child(_label(clue_status, 12, MUTED))
	return section


## 本地化优先、缺键回退中文（结算页的旧文案是历史硬编码，新文案统一走这里）。
func _loc(key: String, fallback: String) -> String:
	if _tr.is_valid() and not key.is_empty():
		var text := String(_tr.call(key))
		if not text.is_empty() and text != key:
			return text
	return fallback


func _badge(text: String, tone: SNBadge.Tone) -> SNBadge:
	var badge := SNBadge.new(); badge.text = text; badge.tone = tone; return badge
func _panel() -> PanelContainer:
	var panel := PanelContainer.new(); panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; return panel
func _content(panel: PanelContainer) -> VBoxContainer:
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 8); panel.add_child(box); return box
func _heading(eyebrow: String, title: String, detail: String) -> SNSectionHeader:
	var header := SNSectionHeader.new(); header.eyebrow = eyebrow; header.title = title; header.detail = detail; return header
func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size", size); label.add_theme_color_override("font_color", color); return label
func _fmt(value: float) -> String: return "%.1f" % value
func _clear() -> void:
	for child in get_children(): remove_child(child); child.free()
