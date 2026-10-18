@tool
class_name SNSectionHeader
extends HBoxContainer
## Reusable eyebrow + title block with an optional right-aligned detail.

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

var _eyebrow_label: Label
var _title_label: Label
var _detail_label: Label


func _ready() -> void:
	_build_once()
	_sync_text()


func _build_once() -> void:
	if get_node_or_null("Text") != null:
		_eyebrow_label = get_node("Text/Eyebrow") as Label
		_title_label = get_node("Text/Title") as Label
		_detail_label = get_node("Detail") as Label
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
	_detail_label.theme_type_variation = &"SNDetailLabel"
	add_child(_detail_label)


func _sync_text() -> void:
	if not is_inside_tree():
		return
	_build_once()
	_eyebrow_label.text = eyebrow.to_upper()
	_title_label.text = title
	_detail_label.text = detail
	_detail_label.visible = not detail.is_empty()
