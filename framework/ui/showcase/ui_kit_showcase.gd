extends Control
## @static-doc
## 作用：皮肤验收展示页：在一个可滚动页面里集中展示纹理化 Theme 与 SNSkin 素材的全部可复用控件状态——按钮矩阵、面板材质、徽标、表单、资源条、进度条、九宫格拉伸对照、图标网格、parts 装饰、旗帜与 sparkline；供 1440×900 / 960×540 截图验收与视觉冒烟。
##
## - 关键依赖：`assets/ui/theme/steam_navigator_theme.tres`、`SNSkin`（运行纹理/图标/颜色 token）、
##   `sn_button/sn_panel/sn_badge/sn_section_header/sn_resource_meter/sn_sparkline` 场景，
##   新增的 `sn_icon.gd` / `sn_nav_button.gd` 只在本页用 `preload()` 引用（避免依赖全局类缓存）。
##
## ## 契约与约束
## - 不依赖 AppContext / Core 内容：可在编辑器与 headless 截图工具中独立实例化。
## - 页面结构保持 `UIKitShowcase` → `Margin/Scroll` 骨架，场景只负责骨架，全部内容由脚本构建。
## - 颜色统一 `SNSkin.color(token)`，不写十六进制；不新建 StyleBoxFlat。
## - 状态演示只用 `add_theme_stylebox_override` 静态套用 SNSkin 纹理（hover/pressed/selected/focus 不需要
##   真实鼠标），不把状态色写死在页面里。
## - 内容区按 `Margin/Scroll` 可用宽度自适应 2/3 列，960×540 下只纵向滚动、不横向溢出。
##
## ## 重点逻辑
## ### `_build_showcase()`
## - 先建全宽区段（页头、按钮矩阵、铭牌/导航、旗帜），再建自适应网格区段（面板、徽标、表单、资源条、
##   九宫格、图标、parts、sparkline）。
## ### `_apply_columns()`
## - 监听滚动容器尺寸：可用宽度 ≥ 1350 时区段网格用 3 列、否则 2 列；按钮状态行 ≥ 960 时 6 列、
##   否则 3 列（两行）。两个阈值都来自实测最小宽度，保证窄窗只纵向滚动、不横向裁切。
## @end-static-doc

const SNButtonScene := preload("res://framework/ui/components/sn_button.tscn")
const SNPanelScene := preload("res://framework/ui/components/sn_panel.tscn")
const SNBadgeScene := preload("res://framework/ui/components/sn_badge.tscn")
const SNSectionHeaderScene := preload("res://framework/ui/components/sn_section_header.tscn")
const SNResourceMeterScene := preload("res://framework/ui/components/sn_resource_meter.tscn")
const SNSparklineScene := preload("res://framework/ui/components/sn_sparkline.tscn")
## New class_name scripts are referenced only through preload() (the global class cache may lag before import).
const SNIconScript := preload("res://framework/ui/components/sn_icon.gd")
const SNNavButtonScript := preload("res://framework/ui/components/sn_nav_button.gd")

const COLUMNS_WIDE := 3
const COLUMNS_NARROW := 2
## Section grid: three columns need ~1256 px of minimum content width, so the
## threshold is measured on the scroll viewport, not on the design canvas.
const WIDE_MIN_WIDTH := 1350.0
## Button state matrix: six columns only when the row can keep full button widths.
const BUTTON_STATE_WIDE_WIDTH := 960.0
const BUTTON_STATES_WIDE := 6
const BUTTON_STATES_NARROW := 3
const SECTION_MIN_WIDTH := 300.0
const SECTION_SEPARATION := 16
const CELL_SEPARATION := 10
const ICON_SIZE := 24.0
const ICON_SECTION_SIZE := 28.0

const BUTTON_STATES: Array[String] = ["normal", "hover", "pressed", "selected", "focus", "disabled"]
## Semantic variants of SNButton plus the SNSkin.button_style() variant key.
const BUTTON_VARIANTS := [
	{"label": "主操作 · PRIMARY", "variant": 0, "key": "primary", "icon": "action_confirm", "text": "确认出航"},
	{"label": "次操作 · SECONDARY", "variant": 1, "key": "secondary", "icon": "nav_chart", "text": "查看详情"},
	{"label": "危险 · DANGER", "variant": 2, "key": "danger", "icon": "status_warning", "text": "放弃委托"},
	{"label": "幽灵 · GHOST", "variant": 3, "key": "ghost", "icon": "status_unlocked", "text": "返回港口"},
]

const PANEL_VARIANTS := [
	{"label": "基础面板 STEEL", "variant": 0, "color": "text.light", "note": "页面 / 弹窗承托"},
	{"label": "高架面板 ELEVATED", "variant": 1, "color": "text.light", "note": "浮起层级"},
	{"label": "内嵌仪表槽 INSET", "variant": 2, "color": "text.light", "note": "输入 / 资源槽"},
	{"label": "羊皮纸 PARCHMENT", "variant": 3, "color": "ink.primary", "note": "账册 / 合同 / 回执"},
	{"label": "蓝图 BLUEPRINT", "variant": 4, "color": "blueprint.line", "note": "技术信息 / 部件"},
	{"label": "画布 CANVAS", "variant": 5, "color": "ink.primary", "note": "说明 / 便笺"},
	{"label": "玻璃 GLASS", "variant": 6, "color": "text.light", "note": "3D 舞台浮层"},
]

const BADGES := [
	{"tone": 0, "text": "当前港"},
	{"tone": 1, "text": "已完成"},
	{"tone": 2, "text": "中等风险"},
	{"tone": 3, "text": "严重损坏"},
]

const HUD_ICONS := [
	"resource_coins", "resource_coal", "resource_water", "resource_durability", "resource_cargo",
]
const SHIPYARD_ICONS := [
	"shipyard_hull", "shipyard_boiler", "shipyard_cargo",
	"shipyard_navigation", "shipyard_safety", "shipyard_cabin",
]
const ACTION_STATUS_ICONS := [
	"action_add", "action_remove", "action_confirm",
	"status_warning", "status_locked", "status_unlocked",
	"status_anchor", "status_time", "status_weather",
	"status_storm", "status_reputation", "status_route",
]
const NAV_ICONS := [
	"nav_market", "nav_contracts", "nav_shipyard", "nav_resupply",
	"nav_intelligence", "nav_chart", "nav_departure",
]
const DECOR_PARTS := [
	{"id": "hook", "label": "挂钩"},
	{"id": "paper_clip", "label": "纸夹"},
	{"id": "rope_loop", "label": "绳结"},
	{"id": "slider_knob", "label": "滑阀"},
	{"id": "wax_seal", "label": "蜡封"},
	{"id": "checkbox_empty", "label": "复选空框"},
]
const FLAGS := [
	{"style": "flag_teal", "label": "市场"},
	{"style": "flag_blue", "label": "海图"},
	{"style": "flag_red", "label": "出航"},
	{"style": "flag_selected", "label": "当前页"},
]

var _sections_grid: GridContainer
var _state_grids: Array[GridContainer] = []


func _ready() -> void:
	var background := get_node_or_null("Background") as ColorRect
	if background != null:
		background.color = SNSkin.color("bg.abyss")
	_build_showcase()
	var scroll := get_node_or_null("Margin/Scroll") as ScrollContainer
	if scroll != null and not scroll.resized.is_connected(_apply_columns):
		scroll.resized.connect(_apply_columns)
	_apply_columns()


func _build_showcase() -> void:
	var scroll := get_node_or_null("Margin/Scroll") as ScrollContainer
	if scroll == null:
		return
	var root := VBoxContainer.new()
	root.name = "Content"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 20)
	scroll.add_child(root)

	root.add_child(_page_header())
	root.add_child(_button_matrix())
	root.add_child(_chrome_and_nav())
	root.add_child(_overflow_check_strip())

	_sections_grid = GridContainer.new()
	_sections_grid.name = "Sections"
	_sections_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sections_grid.add_theme_constant_override("h_separation", SECTION_SEPARATION)
	_sections_grid.add_theme_constant_override("v_separation", SECTION_SEPARATION)
	root.add_child(_sections_grid)
	for section in [
		_panel_variants(),
		_badges_and_forms(),
		_meters(),
		_nine_slice_scaling(),
		_icon_grids(),
		_parts_strip(),
		_sparklines(),
	]:
		_sections_grid.add_child(section)

	root.add_child(_flags())


func _apply_columns() -> void:
	if _sections_grid == null:
		return
	var scroll := get_node_or_null("Margin/Scroll") as ScrollContainer
	var width := scroll.size.x if scroll != null else 0.0
	var wide := width >= WIDE_MIN_WIDTH
	_sections_grid.columns = COLUMNS_WIDE if wide else COLUMNS_NARROW
	var state_columns := BUTTON_STATES_WIDE if width >= BUTTON_STATE_WIDE_WIDTH else BUTTON_STATES_NARROW
	for grid in _state_grids:
		if grid != null:
			grid.columns = state_columns


# ---------------------------------------------------------------------------
# Section helpers
# ---------------------------------------------------------------------------

## Shared card shell: SNPanel (steel) + SNSectionHeader + detail note.
func _section(title: String, subtitle: String, icon_id: String = "") -> Dictionary:
	var panel := SNPanelScene.instantiate() as SNPanel
	panel.variant = SNPanel.Variant.BASE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(SECTION_MIN_WIDTH, 0)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	var header := SNSectionHeaderScene.instantiate() as SNSectionHeader
	header.eyebrow = "UI KIT"
	header.title = title
	header.detail = ""
	header.icon_id = icon_id
	content.add_child(header)
	var note := _caption(subtitle)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)
	return {"panel": panel, "content": content}


func _caption(text: String) -> Label:
	var label := Label.new()
	label.name = "Caption"
	label.theme_type_variation = &"SNDetailLabel"
	label.text = text
	return label


func _page_header() -> Control:
	var header := SNSectionHeaderScene.instantiate() as SNSectionHeader
	header.name = "PageHeader"
	header.eyebrow = "STEAM NAVIGATOR · UI SKIN V1"
	header.title = "皮肤验收 · UI Kit Showcase"
	header.detail = "外部贴图驱动 · 1440 × 900 / 960 × 540"
	header.icon_id = "nav_chart"
	return header


# ---------------------------------------------------------------------------
# Buttons
# ---------------------------------------------------------------------------

## Four semantic variants x five states; hover/pressed/focus reuse the SNSkin
## styleboxes statically so the page shows every state without mouse input.
func _button_matrix() -> Control:
	var section := _section(
		"按钮状态矩阵",
		"4 个语义变体 × normal / hover / pressed / selected / focus / disabled；状态纹理来自 SNSkin，页面不写死颜色",
		"action_confirm"
	)
	var content := section["content"] as VBoxContainer
	for definition in BUTTON_VARIANTS:
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 4)
		content.add_child(block)
		var label := Label.new()
		label.theme_type_variation = &"SNEyebrowLabel"
		label.text = String(definition["label"])
		block.add_child(label)
		# Grid instead of HBox: six states collapse to three per row on narrow
		# windows so the page never overflows horizontally.
		var row := GridContainer.new()
		row.columns = BUTTON_STATES_WIDE
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("h_separation", CELL_SEPARATION)
		row.add_theme_constant_override("v_separation", 6)
		block.add_child(row)
		_state_grids.append(row)
		for state in BUTTON_STATES:
			row.add_child(_button_state_cell(definition, state))
	return section["panel"] as Control


func _button_state_cell(definition: Dictionary, state: String) -> Control:
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override("separation", 3)
	var button := SNButtonScene.instantiate() as SNButton
	button.variant = int(definition["variant"])
	button.text = String(definition["text"])
	button.icon_id = String(definition["icon"])
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if state == "focus":
		cell.add_child(_focus_demo(button, String(definition["key"])))
	elif state == "disabled":
		button.disabled = true
		button.text = "载重不足"
		cell.add_child(button)
	else:
		if state == "selected":
			# Selected plate is one shared texture; fall back to the variant's own
			# normal box if the skin is unavailable.
			var selected: StyleBox = SNSkin.style("button_selected")
			if selected == null:
				selected = SNSkin.button_style("normal", String(definition["key"]))
			if selected != null:
				button.add_theme_stylebox_override("normal", selected)
		elif state != "normal":
			var box: StyleBox = SNSkin.button_style(state, String(definition["key"]))
			if box != null:
				button.add_theme_stylebox_override("normal", box)
		cell.add_child(button)
	cell.add_child(_caption(state.capitalize()))
	return cell


## Static focus preview: the button keeps its normal texture and a sibling Control
## draws the SNSkin focus ring on top (only one control can own real keyboard focus).
func _focus_demo(button: SNButton, variant_key: String) -> Control:
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, SNButton.HEIGHT_DEFAULT)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(button)
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ring := Control.new()
	ring.name = "FocusRing"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(ring)
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var focus_box: StyleBox = SNSkin.button_style("focus", variant_key)
	if focus_box != null:
		ring.draw.connect(func() -> void:
			ring.draw_style_box(focus_box, Rect2(Vector2.ZERO, ring.size))
		)
	return stage


## Compact plates, SNPlate tabs and the new SNNavButton (preload-only reference).
func _chrome_and_nav() -> Control:
	var section := _section(
		"铭牌 · 紧凑按钮 · 导航按钮",
		"compact 用 SNCompactButton 小铭牌（31 px）；SNPlateButton 用于二级页签；SNNavButton 演示图标 + active/primary",
		"nav_market"
	)
	var content := section["content"] as VBoxContainer
	var compact_row := HBoxContainer.new()
	compact_row.add_theme_constant_override("separation", CELL_SEPARATION)
	content.add_child(compact_row)
	for definition in [
		{"icon": "action_remove", "text": "−", "variant": 1},
		{"icon": "action_add", "text": "+", "variant": 0},
		{"icon": "action_confirm", "text": "全部", "variant": 1},
		{"icon": "", "text": "禁用的步进", "variant": 1, "disabled": true},
	]:
		var compact_button := SNButtonScene.instantiate() as SNButton
		compact_button.compact = true
		compact_button.variant = int(definition["variant"])
		compact_button.text = String(definition["text"])
		compact_button.icon_id = String(definition["icon"])
		compact_button.custom_minimum_size.x = 96
		if bool(definition.get("disabled", false)):
			compact_button.disabled = true
		compact_row.add_child(compact_button)

	var plate_row := HBoxContainer.new()
	plate_row.add_theme_constant_override("separation", CELL_SEPARATION)
	content.add_child(plate_row)
	for definition in [
		{"text": "页签 · 已选", "variation": &"SNPlateButton", "disabled": false},
		{"text": "页签 · 普通", "variation": &"SNPlateButton", "disabled": false},
		{"text": "页签 · 禁用", "variation": &"SNPlateButton", "disabled": true},
	]:
		var plate := Button.new()
		plate.theme_type_variation = definition["variation"]
		plate.text = String(definition["text"])
		plate.custom_minimum_size = Vector2(120, 32)
		plate.disabled = bool(definition["disabled"])
		plate_row.add_child(plate)

	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", CELL_SEPARATION)
	content.add_child(nav_row)
	for definition in [
		{"icon": "nav_market", "text": "市场", "active": true, "primary": false},
		{"icon": "nav_contracts", "text": "委托", "active": false, "primary": false},
		{"icon": "nav_shipyard", "text": "船厂", "active": false, "primary": false},
		{"icon": "nav_departure", "text": "出航", "active": false, "primary": true},
	]:
		var nav: Button = SNNavButtonScript.new()
		nav.icon_id = String(definition["icon"])
		nav.text = String(definition["text"])
		nav.compact = true
		nav.active = bool(definition["active"])
		nav.primary = bool(definition["primary"])
		nav.custom_minimum_size = Vector2(96, 36)
		nav_row.add_child(nav)
	return section["panel"] as Control


## Deliberately wide rows: if the viewport is too narrow these must scroll
## vertically only, never push the page past the window width.
func _overflow_check_strip() -> Control:
	var section := _section(
		"安全区 / 窄窗",
		"960 × 540 下只纵向滚动；长文案、禁用原因与数字读数都保持在九宫格安全区内",
		"status_route"
	)
	var content := section["content"] as VBoxContainer
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", CELL_SEPARATION)
	content.add_child(row)
	for text in ["短", "四字标签", "较长的禁用原因说明", "123 456"]:
		var badge := SNBadgeScene.instantiate() as SNBadge
		badge.text = text
		row.add_child(badge)
	content.add_child(_caption("「123 456」验证等宽数字与六位读数；长解释在窄窗中允许换行。"))
	return section["panel"] as Control


# ---------------------------------------------------------------------------
# Panels
# ---------------------------------------------------------------------------

func _panel_variants() -> Control:
	var section := _section("面板材质", "全部 Theme 面板变体：钢 / 高架 / 内嵌 / 羊皮纸 / 蓝图 / 画布 / 玻璃", "shipyard_hull")
	var content := section["content"] as VBoxContainer
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", CELL_SEPARATION)
	grid.add_theme_constant_override("v_separation", CELL_SEPARATION)
	content.add_child(grid)
	for definition in PANEL_VARIANTS:
		var panel := SNPanelScene.instantiate() as SNPanel
		panel.variant = int(definition["variant"])
		panel.custom_minimum_size = Vector2(150, 96)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		panel.add_child(box)
		var label := Label.new()
		label.text = String(definition["label"])
		label.add_theme_color_override("font_color", SNSkin.color(String(definition["color"])))
		label.add_theme_font_size_override("font_size", 13)
		box.add_child(label)
		var note := Label.new()
		note.text = String(definition["note"])
		note.add_theme_color_override("font_color", SNSkin.color(String(definition["color"])))
		note.add_theme_font_size_override("font_size", 11)
		box.add_child(note)
		grid.add_child(panel)
	return section["panel"] as Control


# ---------------------------------------------------------------------------
# Badges / forms
# ---------------------------------------------------------------------------

func _badges_and_forms() -> Control:
	var section := _section("徽标与表单", "四色徽标；输入、下拉与复选由 Theme 纹理化", "status_warning")
	var content := section["content"] as VBoxContainer
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", CELL_SEPARATION)
	content.add_child(row)
	for definition in BADGES:
		var badge := SNBadgeScene.instantiate() as SNBadge
		badge.tone = int(definition["tone"])
		badge.text = String(definition["text"])
		row.add_child(badge)
	var line_edit := LineEdit.new()
	line_edit.placeholder_text = "输入航次名称"
	content.add_child(line_edit)
	var option := OptionButton.new()
	option.add_item("经济航速 · 低消耗")
	option.add_item("标准航速 · 平衡")
	option.add_item("极速航行 · 高风险")
	content.add_child(option)
	var check := CheckBox.new()
	check.text = "抵达时自动保存"
	check.button_pressed = true
	content.add_child(check)
	var disabled_check := CheckBox.new()
	disabled_check.text = "受限选项（禁用）"
	disabled_check.disabled = true
	content.add_child(disabled_check)
	return section["panel"] as Control


# ---------------------------------------------------------------------------
# Meters / progress
# ---------------------------------------------------------------------------

func _meters() -> Control:
	var section := _section("资源仪表", "三色 ProgressBar + 三段式损失带；LossBar 与 ProgressBar 使用同一套 meter 纹理", "resource_coal")
	var content := section["content"] as VBoxContainer
	for definition in [
		{"variation": &"SNBrassProgressBar", "value": 62.0, "text": "黄铜 · 煤炭装载"},
		{"variation": &"SNWaterProgressBar", "value": 48.0, "text": "水青 · 淡水液位"},
		{"variation": &"SNDangerProgressBar", "value": 24.0, "text": "锈红 · 危险耐久"},
	]:
		var label := Label.new()
		label.theme_type_variation = &"SNDetailLabel"
		label.text = String(definition["text"])
		content.add_child(label)
		var bar := ProgressBar.new()
		bar.theme_type_variation = definition["variation"]
		bar.custom_minimum_size = Vector2(0, 14)
		bar.max_value = 100.0
		bar.value = float(definition["value"])
		bar.show_percentage = false
		content.add_child(bar)
	var meter_data := [
		["煤炭", 31.0, 50.0, 0.0, "预计续航 6.2 天", 0],
		["淡水", 39.0, 50.0, 0.0, "预计续航 9.8 天", 1],
		["船体耐久", 22.0, 100.0, 0.0, "低于安全线，建议维修", 2],
		["淡水（上限损失）", 5.0, 40.0, 10.0, "另一项补给占用的载重", 1],
	]
	for item in meter_data:
		var meter := SNResourceMeterScene.instantiate() as SNResourceMeter
		meter.label_text = String(item[0])
		meter.current_value = float(item[1])
		meter.maximum_value = float(item[2])
		meter.loss_value = float(item[3])
		meter.hint = String(item[4])
		meter.tone = int(item[5])
		meter.suffix = "%" if String(item[0]).contains("耐久") else "单位"
		content.add_child(meter)
	return section["panel"] as Control


# ---------------------------------------------------------------------------
# Nine-slice stretch comparison
# ---------------------------------------------------------------------------

## Same steel panel texture at 0.75x / 1x / 1.2x of a 160x90 base: corners and
## rivets must keep their proportion while the center stretches.
func _nine_slice_scaling() -> Control:
	var section := _section("九宫格拉伸对照", "同一面板纹理 0.75× / 1× / 1.2×：角件与铆钉不随中心拉伸", "shipyard_hull")
	var content := section["content"] as VBoxContainer
	var base := Vector2(160, 90)
	for scale in [0.75, 1.0, 1.2]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", CELL_SEPARATION)
		content.add_child(row)
		var label := Label.new()
		label.theme_type_variation = &"SNEyebrowLabel"
		label.text = "%.2f×" % scale
		label.custom_minimum_size.x = 56
		row.add_child(label)
		var panel := SNPanelScene.instantiate() as SNPanel
		panel.variant = SNPanel.Variant.BASE
		panel.custom_minimum_size = Vector2(roundf(base.x * scale), roundf(base.y * scale))
		panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var text := Label.new()
		text.text = "%.0f × %.0f" % [panel.custom_minimum_size.x, panel.custom_minimum_size.y]
		panel.add_child(text)
		row.add_child(panel)
	return section["panel"] as Control


# ---------------------------------------------------------------------------
# Icon grids
# ---------------------------------------------------------------------------

func _icon_grids() -> Control:
	var section := _section("图标网格", "6 个船厂图标 + HUD 资源图标 + 行动 / 状态图标 + 7 个导航图标（SNSkin 外部贴图）", "nav_intelligence")
	var content := section["content"] as VBoxContainer
	content.add_child(_icon_group("船厂分类", SHIPYARD_ICONS, ICON_SECTION_SIZE))
	content.add_child(_icon_group("HUD 资源", HUD_ICONS, ICON_SECTION_SIZE))
	content.add_child(_icon_group("行动 / 状态", ACTION_STATUS_ICONS, ICON_SIZE))
	content.add_child(_icon_group("主导航", NAV_ICONS, ICON_SIZE))
	return section["panel"] as Control


func _icon_group(title: String, ids: Array, size: float) -> Control:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.theme_type_variation = &"SNEyebrowLabel"
	label.text = title
	group.add_child(label)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	group.add_child(grid)
	for icon_id in ids:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		grid.add_child(cell)
		var icon: TextureRect = SNIconScript.new()
		icon.icon_id = String(icon_id)
		icon.logical_size = size
		cell.add_child(icon)
		var caption := Label.new()
		caption.theme_type_variation = &"SNDetailLabel"
		caption.text = String(icon_id).replace("_", " ")
		caption.clip_text = true
		caption.custom_minimum_size.x = 76
		cell.add_child(caption)
	return group


# ---------------------------------------------------------------------------
# Fixed parts / decor
# ---------------------------------------------------------------------------

func _parts_strip() -> Control:
	var section := _section("固定配件", "parts 装饰件按原始尺寸显示：挂钩、纸夹、绳结、滑阀、蜡封、复选空框", "shipyard_safety")
	var content := section["content"] as VBoxContainer
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	for definition in DECOR_PARTS:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		grid.add_child(cell)
		var texture := SNSkin.decor(String(definition["id"]))
		var part := TextureRect.new()
		part.texture = texture
		part.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		part.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		part.custom_minimum_size = texture.get_size() if texture != null else Vector2(48, 48)
		part.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(part)
		var caption := _caption(String(definition["label"]))
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(caption)
	return section["panel"] as Control


# ---------------------------------------------------------------------------
# Sparkline / flags
# ---------------------------------------------------------------------------

func _sparklines() -> Control:
	var section := _section("价格趋势", "真实样本不足时显示样本不足；有样本后按 token 色绘制折线", "nav_market")
	var content := section["content"] as VBoxContainer
	for prices in [[72, 75, 73, 79, 78, 84], [84, 82, 80, 77, 74, 71], [63]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", CELL_SEPARATION)
		content.add_child(row)
		var spark := SNSparklineScene.instantiate() as SNSparkline
		var rising: bool = prices.size() > 1 and float(prices[prices.size() - 1]) >= float(prices[0])
		spark.set_values(prices, SNSkin.color("brass.highlight") if rising else SNSkin.color("state.danger"))
		row.add_child(spark)
		var note := _caption("样本不足" if prices.size() < 2 else "%d 个样本" % prices.size())
		row.add_child(note)
	return section["panel"] as Control


func _flags() -> Control:
	var section := _section("旗帜与当前页", "布旗材质只用于主导航 / 强语义入口：青、蓝、红、选中四态", "nav_departure")
	var content := section["content"] as VBoxContainer
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", CELL_SEPARATION)
	content.add_child(row)
	for definition in FLAGS:
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(120, 84)
		var box := SNSkin.style(String(definition["style"]))
		if box != null:
			panel.add_theme_stylebox_override("panel", box)
		var label := Label.new()
		label.text = String(definition["label"])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", SNSkin.color("text.light"))
		panel.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.add_child(panel)
	return section["panel"] as Control
