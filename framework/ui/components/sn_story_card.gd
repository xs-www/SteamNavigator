class_name SNStoryCard
extends Control
## @static-doc
## 作用：新手剧情 / 教学系统的全屏剧情卡（阶段 4.5）。深色遮罩 + 居中剧情面板：
## 标题、多段正文、右侧「继续」与「跳过教程」；点「跳过教程」先切到确认页，
## 确认后才发 `skip_requested`。纯表现组件，不查询后端、不改状态。
##
## - 关键依赖：`story.view` 的 `card` 字典、本地化回调
##
## ## 契约与约束
## - `bind(card, translate)` 注入已裁剪的 card 数据（`title_key` / `body_keys` /
##   `advance_label_key` / `skip_label_key`）；文案键由调用方 / 本地化服务翻译。
## - 信号：`advance_requested`（继续）、`skip_requested`（确认跳过）。确认页的
##   「取消」只回到剧情正文，不发信号。
## - 遮罩 `mouse_filter = STOP`：卡片打开期间拦截页面点击；尺寸变化由布局自适应。
## - 测试通过节点名访问按钮：`ContinueButton` / `SkipButton` / `SkipConfirmButton` /
##   `SkipCancelButton`。
##
## ## 皮肤与节点约束（UI 贴图层）
## - 剧情卡是航海日志纸面：面板用 `SNParchmentPanel`（`StoryPanel` 节点名不变），
##   遮罩色取 `SNSkin.color("bg.abyss")` + 0.72 alpha；标题/眉题沿用
##   `SNTitleLabel` / `SNEyebrowLabel`，在纸面上把文字色覆盖为
##   `ink.primary` / `brass.shadow`。按钮统一 Theme 变体（继续 `SNPrimaryButton`、
##   跳过/取消 `SNGhostButton`），Ghost 在纸面用深墨色字体覆盖以保证对比度。
## - 卡片宽度 `CARD_WIDTH = 720`、按钮节点名与信号（`advance_requested` /
##   `skip_requested`）不变，test_story_ui 按名字查找。
## @end-static-doc

signal advance_requested
signal skip_requested

const CARD_WIDTH := 720.0

var _card: Dictionary = {}
var _tr: Callable = Callable()
var _skip_confirm := false
var _panel: PanelContainer


func bind(card: Dictionary, translate: Callable = Callable()) -> void:
	_card = card.duplicate(true)
	_tr = translate
	_skip_confirm = false
	_rebuild()


func is_skip_confirm() -> bool:
	return _skip_confirm


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.name = "StoryDim"
	var dim_color := SNSkin.color("bg.abyss")
	dim_color.a = 0.72
	dim.color = dim_color
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "StoryPanel"
	_panel.theme_type_variation = &"SNParchmentPanel"
	_panel.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.name = "StoryBox"
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)
	if _skip_confirm:
		_build_confirm(box)
	else:
		_build_card(box)


func _build_card(box: VBoxContainer) -> void:
	var eyebrow := Label.new()
	eyebrow.text = _loc("ui.story.eyebrow", "航路局 · 新手教程")
	eyebrow.theme_type_variation = &"SNEyebrowLabel"
	eyebrow.add_theme_color_override("font_color", SNSkin.color("brass.shadow"))
	box.add_child(eyebrow)
	var title := Label.new()
	title.name = "StoryTitle"
	title.text = _loc(String(_card.get("title_key", "")), "")
	title.theme_type_variation = &"SNTitleLabel"
	title.add_theme_color_override("font_color", SNSkin.color("ink.primary"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	for key in Array(_card.get("body_keys", [])):
		var body := Label.new()
		body.text = _loc(String(key), "")
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_font_size_override("font_size", 15)
		body.add_theme_color_override("font_color", SNSkin.color("ink.primary"))
		box.add_child(body)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	var skip := Button.new()
	skip.name = "SkipButton"
	skip.text = _loc(String(_card.get("skip_label_key", "")), _loc("ui.story.skip", "跳过教程"))
	skip.theme_type_variation = &"SNGhostButton"
	_ink_ghost(skip)
	skip.pressed.connect(func() -> void:
		_skip_confirm = true
		_rebuild()
	)
	buttons.add_child(skip)
	var advance := Button.new()
	advance.name = "ContinueButton"
	advance.text = _loc(String(_card.get("advance_label_key", "")), _loc("ui.story.continue", "继续"))
	advance.theme_type_variation = &"SNPrimaryButton"
	advance.pressed.connect(func() -> void: advance_requested.emit())
	buttons.add_child(advance)


func _build_confirm(box: VBoxContainer) -> void:
	var eyebrow := Label.new()
	eyebrow.text = _loc("ui.story.eyebrow", "航路局 · 新手教程")
	eyebrow.theme_type_variation = &"SNEyebrowLabel"
	eyebrow.add_theme_color_override("font_color", SNSkin.color("brass.shadow"))
	box.add_child(eyebrow)
	var title := Label.new()
	title.name = "StoryTitle"
	title.text = _loc("ui.story.skip_confirm_title", "跳过新手教程？")
	title.theme_type_variation = &"SNTitleLabel"
	title.add_theme_color_override("font_color", SNSkin.color("ink.primary"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var body := Label.new()
	body.text = _loc("ui.story.skip_confirm_body", "")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", SNSkin.color("ink.primary"))
	box.add_child(body)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	var cancel := Button.new()
	cancel.name = "SkipCancelButton"
	cancel.text = _loc("ui.story.skip_confirm_no", "取消")
	cancel.theme_type_variation = &"SNGhostButton"
	_ink_ghost(cancel)
	cancel.pressed.connect(func() -> void:
		_skip_confirm = false
		_rebuild()
	)
	buttons.add_child(cancel)
	var confirm := Button.new()
	confirm.name = "SkipConfirmButton"
	confirm.text = _loc("ui.story.skip_confirm_yes", "确定跳过")
	confirm.theme_type_variation = &"SNPrimaryButton"
	confirm.pressed.connect(func() -> void: skip_requested.emit())
	buttons.add_child(confirm)


## Ghost 变体在纸面上默认用深底浅色文字；这里把文字统一压成深墨，保证可读。
func _ink_ghost(button: Button) -> void:
	var ink := SNSkin.color("ink.primary")
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)
	button.add_theme_color_override("font_focus_color", ink)


func _loc(key: String, fallback: String) -> String:
	if key.is_empty():
		return fallback
	var text := String(_tr.call(key)) if _tr.is_valid() else fallback
	if text.is_empty() or text == key:
		return fallback
	return text
