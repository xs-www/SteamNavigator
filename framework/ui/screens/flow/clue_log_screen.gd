class_name ClueLogScreen
extends VBoxContainer
## @static-doc
## 作用：线索列表页（阶段 4.4.4）。只读展示 `clue.list` 查询的输出：全部 active 线索
## （类型 / 来源 / 等级 / 剩余时效 / 分级披露内容 / 可调查状态）与折叠的过期历史；
## 点击条目回到海图并选中该线索，关闭返回海图。页面不查询后端、不执行命令。
##
## - 关键依赖：`clue.list` 查询的 ViewModel、`SNSectionHeader`、`SNSeaChartPanel.compass_key`
##   （八方位换算复用面板的纯函数）。
##
## ## 契约与约束
## - `bind(vm, translate)` 注入数据；文案全部来自本地化键，键缺失时回退中文/键名。
## - 不自行计算规则：等级文案、剩余时效、行情区间全部来自查询层裁剪后的字段；
##   任何等级都不会拿到 `target_port_id` / `credibility` / 真实 `search_zone`。
## - 整张卡片是一个按钮：`clue_selected(clue_id)` 由 Shell 转成「回海图并选中」。
## - 过期历史只读 `vm.expired`，灰显并标注 `ui.clue.expired`；不参与 active 计数。
## - 空态（active + expired 都为空）显示 `ui.clue.list.empty` 引导文案。
##
## ## 皮肤与节点约束（UI 贴图层）
## - 外观来自 `assets/ui/skin/sn_v1/` 纹理化 Theme：外层列表用 `SNPanel`，
##   active 卡片改为 `SNParchmentPanel` 承托、内部 `SNGhostButton` 只渲染文字并
##   由 Theme 表达 hover/pressed；不再手写三态 `StyleBoxFlat`。
## - 纸面正文/次要文字取 `SNSkin.color("ink.primary")` / `"paper.ink_muted"`；
##   深底标题/空态取 `text.light` / `text.muted`。
## - 节点名 `ClueCard_<id>`（Button 文本即卡片内容）、`ExpiredClue_<id>`、
##   `ClueList`、`CloseButton` 与线索列表 `520` 高滚动区不变，test_sea_chart
##   按名字与卡片文本断言。
## @end-static-doc

## 关闭列表页（Shell 回到海图）。
signal close_requested
## 选中一条线索（Shell 回海图并绑定该线索）。
signal clue_selected(clue_id: String)

var _tr: Callable = Callable()


func bind(view_model: Dictionary, translate: Callable) -> void:
	_tr = translate
	for child in get_children():
		remove_child(child)
		child.free()
	var count_text := _loc("ui.clue.list.count", "持有 %d / %d") % [
		int(view_model.get("active_count", 0)), int(view_model.get("max_active", 0)),
	]
	add_child(_heading(
		_loc("ui.clue.section_title", "线索"),
		_loc("ui.clue.list.title", "线索列表"),
		"%s · %s" % [
			count_text,
			_loc("ui.clue.list.click_hint", "点击线索回到海图"),
		]
	))
	if not bool(view_model.get("has_run", false)):
		add_child(_label(_loc("ui.sea_chart.no_data", "没有可用的世界数据。"), 14, SNSkin.color("text.muted")))
		add_child(_close_button())
		return
	var clues: Array = view_model.get("clues", [])
	var expired: Array = view_model.get("expired", [])
	if clues.is_empty() and expired.is_empty():
		add_child(_label(_loc("ui.clue.list.empty", "目前没有线索。"), 14, SNSkin.color("text.muted")))
		add_child(_close_button())
		return
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SNPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Shell 把页面挂在 PageScroll 里（内容高度按最小尺寸算），ScrollContainer 自身
	# 最小高度为 0 时整页只剩关闭按钮；给列表一个可滚动的最小高度。
	scroll.custom_minimum_size = Vector2(0, 520)
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "ClueList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for clue in clues:
		if clue is Dictionary:
			list.add_child(_clue_card(clue as Dictionary))
	if not expired.is_empty():
		var separator := HSeparator.new()
		list.add_child(separator)
		var history_header := _label(
			_loc("ui.clue.list.expired_section", "已过期"), 14, SNSkin.color("text.muted")
		)
		list.add_child(history_header)
		for clue in expired:
			if clue is Dictionary:
				list.add_child(_expired_row(clue as Dictionary))
	box.add_child(_close_button())


## 一条 active 线索卡片：类型 · 来源 / 等级 / 分级披露内容 / 剩余时效。
## 卡片表面是 `SNParchmentPanel` 纸面，`ClueCard_<id>` 按钮本身用 Ghost 变体只
## 渲染文字（normal 为透明），hover / pressed 的视觉由 Theme 表达；点击仍由这个
## Button 的 `pressed` 发出，测试按按钮名与 `text` 断言。
func _clue_card(clue: Dictionary) -> Control:
	var type := String(clue.get("type", "port_location"))
	var level := int(clue.get("level", 1))
	var source_key := String(clue.get("source_key", ""))
	var source := _loc(String(clue.get("source_display_key", "")), "")
	if source.is_empty():
		source = _loc("ui.clue.source." + source_key, source_key)
	var lines: Array[String] = [
		"%s · %s" % [_loc("ui.clue.type." + type, type), source],
		_loc(_level_key(type, level), str(level)),
	]
	if type == "port_goods":
		_append_goods_lines(lines, clue, level)
	else:
		_append_port_lines(lines, clue, level)
	var card := PanelContainer.new()
	card.name = "ClueCardPanel_%s" % String(clue.get("id", "")).replace(":", "_")
	card.theme_type_variation = &"SNParchmentPanel"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var button := Button.new()
	button.name = "ClueCard_%s" % String(clue.get("id", "")).replace(":", "_")
	button.text = "\n".join(PackedStringArray(lines))
	button.theme_type_variation = &"SNGhostButton"
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(0, 88)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 纸面是浅底：正文与 hover / pressed 都保持深墨色，避免变体默认的浅色文字。
	var ink := SNSkin.color("ink.primary")
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)
	button.add_theme_color_override("font_focus_color", ink)
	var clue_id := String(clue.get("id", ""))
	button.set_meta("clue_id", clue_id)
	button.pressed.connect(func() -> void: clue_selected.emit(clue_id))
	card.add_child(button)
	return card


func _append_port_lines(lines: Array[String], clue: Dictionary, level: int) -> void:
	if level >= 2:
		var angle := float(clue.get("direction_angle", 0.0))
		var compass := SNSeaChartPanel.compass_key(angle)
		lines.append("%s: %s" % [
			_loc("ui.label.direction", "方向"),
			_loc("ui.clue.direction." + compass, compass),
		])
	var distance_max := float(clue.get("distance_max_hours", 0.0))
	if distance_max > 0.0:
		lines.append(_loc("ui.clue.distance_range", "约 %d–%d 小时航程") % [
			int(roundf(float(clue.get("distance_min_hours", 0.0)))),
			int(roundf(distance_max)),
		])
	if level >= 4:
		var name_key := String(clue.get("name_key", ""))
		if not name_key.is_empty():
			lines.append(_loc(name_key, name_key))
	else:
		lines.append(_loc("ui.label.unknown_destination", "？"))


func _append_goods_lines(lines: Array[String], clue: Dictionary, level: int) -> void:
	var goods: Variant = clue.get("goods", null)
	if not (goods is Dictionary):
		return
	var data: Dictionary = goods
	var port_key := String(data.get("port_name_key", ""))
	if not port_key.is_empty():
		lines.append(_loc("ui.clue.goods.port", "港口：%s") % _loc(port_key, port_key))
	if level >= 2:
		lines.append(_loc("ui.clue.goods.price_range", "参考价：买入 %d–%d / 卖出 %d–%d") % [
			int(data.get("buy_price_min", 0)), int(data.get("buy_price_max", 0)),
			int(data.get("sell_price_min", 0)), int(data.get("sell_price_max", 0)),
		])
	if level >= 3:
		var demand := String(data.get("demand", "normal"))
		lines.append(_loc("ui.clue.goods.supply", "库存 %d · 需求%s") % [
			int(data.get("stock", 0)),
			_loc("ui.clue.goods.demand." + demand, demand),
		])
	if level >= 4:
		lines.append(_loc("ui.clue.goods.price_exact", "行情：买入 %d / 卖出 %d") % [
			int(data.get("buy_price", 0)), int(data.get("sell_price", 0)),
		])
	var remaining := float(clue.get("remaining_hours", -1.0))
	if remaining >= 0.0:
		lines.append(_loc("ui.clue.expiry", "剩 %d 小时") % int(ceilf(remaining)))


## 过期历史的一行（灰显，只读）：类型 · 来源 · 等级 · 港口名 · 已过期。
func _expired_row(clue: Dictionary) -> Label:
	var type := String(clue.get("type", "port_location"))
	var source_key := String(clue.get("source_key", ""))
	var source := _loc(String(clue.get("source_display_key", "")), "")
	if source.is_empty():
		source = _loc("ui.clue.source." + source_key, source_key)
	var parts: Array[String] = [
		_loc("ui.clue.type." + type, type),
		source,
		_loc(_level_key(type, int(clue.get("level", 1))), str(int(clue.get("level", 1)))),
	]
	var port_key := String(clue.get("port_name_key", ""))
	if not port_key.is_empty():
		parts.append(_loc(port_key, port_key))
	parts.append(_loc("ui.clue.expired", "已过期"))
	var row := _label(" · ".join(PackedStringArray(parts)), 12, SNSkin.color("text.muted"))
	row.name = "ExpiredClue_%s" % String(clue.get("id", "")).replace(":", "_")
	return row


static func _level_key(type: String, level: int) -> String:
	if type == "port_goods":
		return "ui.clue.goods.level.%d" % level
	return "ui.clue.level.%d" % level


func _heading(eyebrow: String, title: String, detail: String) -> SNSectionHeader:
	var header := SNSectionHeader.new()
	header.eyebrow = eyebrow
	header.title = title
	header.detail = detail
	return header


func _close_button() -> Button:
	var button := Button.new()
	button.name = "CloseButton"
	button.text = _loc("ui.clue.list.back", "返回海图")
	button.theme_type_variation = &"SNGhostButton"
	button.pressed.connect(func() -> void: close_requested.emit())
	return button


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _loc(key: String, fallback: String) -> String:
	if key.is_empty():
		return fallback
	var text := String(_tr.call(key)) if _tr.is_valid() else fallback
	if text.is_empty() or text == key:
		return fallback
	return text
