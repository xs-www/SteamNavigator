@tool
class_name SNSectionHeader
extends HBoxContainer
## @static-doc
## 作用：章节标题组合控件：眉题、标题、可选右侧说明，并可挂一枚 16–18 px 的皮肤图标；文字颜色与字号由 Theme 的 SNEyebrowLabel/SNTitleLabel/SNDetailLabel 变体决定。
##
## - 关键依赖：`assets/ui/theme/steam_navigator_theme.tres`（三个 Label 变体）；`SNSkin.icon(id)` / `SNSkin.icon_rect(id, size)`。
##
## ## 契约与约束
## - 内部子节点只创建一次，运行时与 `@tool` 编辑器预览共享同一同步路径。
## - `detail` 为空时隐藏右侧标签，标题区自动占满剩余宽度；`detail` 可省略号截断，不能把同行按钮挤出可视区。
## - `icon_id` 可选：为空时**不创建**图标节点，节点结构、行为与历史版本完全一致；图标缺失（皮肤未就绪）时隐藏图标而不是报错。
## - 图标固定 17 px，位于眉题/标题左侧，不参与文字排版安全区计算。
##
## ## 用法
## ```gdscript
## var header := SNSectionHeader.new()
## header.eyebrow = "UI KIT"
## header.title = "皮肤验收"
## header.icon_id = "nav_chart"
## ```
## @end-static-doc

const ICON_SIZE := 17.0

@export var eyebrow: String = "航路局":
	set(value):
		eyebrow = value
		_sync_text()

@export var title: String = "章节标题":
	set(value):
		title = value
		_sync_text()

@export var detail: String = "":
	set(value):
		detail = value
		_sync_text()

## Optional skin icon id shown before the eyebrow text; empty keeps the legacy header.
@export var icon_id: String = "":
	set(value):
		icon_id = value
		_sync_icon()

var _eyebrow_label: Label
var _title_label: Label
var _detail_label: Label
var _icon: TextureRect


func _ready() -> void:
	_build_once()
	_sync_text()
	_sync_icon()


func _build_once() -> void:
	if get_node_or_null("Text") != null:
		_eyebrow_label = get_node("Text/Eyebrow") as Label
		_title_label = get_node("Text/Title") as Label
		_detail_label = get_node("Detail") as Label
		_icon = get_node_or_null("Icon") as TextureRect
		return
	var text_box := VBoxContainer.new()
	text_box.name = "Text"
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	add_child(text_box)
	_eyebrow_label = Label.new()
	_eyebrow_label.name = "Eyebrow"
	_eyebrow_label.theme_type_variation = &"SNEyebrowLabel"
	text_box.add_child(_eyebrow_label)
	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.theme_type_variation = &"SNTitleLabel"
	text_box.add_child(_title_label)
	_detail_label = Label.new()
	_detail_label.name = "Detail"
	_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# 右侧说明是次要信息：允许在窄宽度下收缩并用省略号截断，避免它把同一行的
	# 按钮挤出可视区（4.4.4 海图顶栏「线索列表 / 返回」的回归）。
	_detail_label.clip_text = true
	_detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_label.theme_type_variation = &"SNDetailLabel"
	add_child(_detail_label)


func _sync_text() -> void:
	_build_once()
	if not is_inside_tree():
		return
	_eyebrow_label.text = eyebrow.to_upper()
	_title_label.text = title
	_detail_label.text = detail
	_detail_label.visible = not detail.is_empty()


func _sync_icon() -> void:
	_build_once()
	if icon_id.is_empty():
		if _icon != null:
			remove_child(_icon)
			_icon.free()
			_icon = null
		return
	if _icon == null:
		_icon = SNSkin.icon_rect(icon_id, ICON_SIZE)
		_icon.name = "Icon"
		add_child(_icon)
		move_child(_icon, 0)
	else:
		_icon.texture = SNSkin.icon(icon_id)
		_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon.visible = _icon.texture != null
