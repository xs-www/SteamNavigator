extends SceneTree
## @static-doc
## 作用：从 `assets/ui/skin/<skin>/skin.json` 生成 `assets/ui/theme/steam_navigator_theme.tres`。Theme 里的每个可见状态都是一张外部 PNG（StyleBoxTexture 九宫格）或外部图标，因此换掉 skin 目录里的同名同尺寸贴图即可整体换肤；本脚本只在换整套皮肤/改九宫格参数时重新运行。
##
## ## 用法
## ```powershell
## godot --headless --path . --script res://tools/ui/build_ui_theme.gd -- [--skin=sn_v1] [--check]
## ```
## - 默认读取 `res://assets/ui/skin/sn_v1/skin.json`，写 `res://assets/ui/theme/steam_navigator_theme.tres`。
## - `--check`：生成到 `user://ui_theme_check/` 并与已提交 Theme 逐字节比对，不覆盖；有差异退出码 1。
##
## ## 主题映射（唯一来源，改映射必须同步改本文件与 SNSkin 文档）
## - Button：normal/hover/pressed/disabled + focus 环；Primary=selected/hover/pressed，Danger=button_danger 提亮 hover，Ghost=空底 + 半透明底纹 hover。
## - Panel：Panel/PanelContainer/SNPanel/SNElevatedPanel=panel_steel（modulate 区分层级），SNInsetPanel=panel_recess，SNGlassPanel=panel_steel α0.62，SNParchmentPanel=panel_parchment，SNBlueprintSheetPanel=panel_blueprint，SNCanvasPanel=panel_canvas，SNBlueprintPanel=既有 blueprint_panel 九宫格（56/54 边距、66/62 安全区）。
## - ProgressBar：meter_trough + meter_fill_amber/aqua/rust（低边距版本，适配 14px 高资源条）。
## - Badge：badge/badge_danger + tone 染色；Input：input_recess；ScrollBar：scrollbar_track/grabber；CheckBox：check_* 图标；Tooltip/Popup/Tab 用 steel/recess/button 纹理。
## - 颜色与字号全部来自 skin.json 的 colors/fonts（对应 UI_FOUNDATION_SPEC_V1 §6/§7），不在 Theme 里另写业务色值。
##
## ## 约束
## - `[gd_resource]` 保留既有 uid `uid://donrdopu47413`（main.tscn 按 uid 引用）；不要手改生成物。
## - StyleBox 的内容边距与 skin.json `content_margin` 一致；新增变体必须同时更新 UI_FOUNDATION_SPEC_V1 的组件清单。
## - 生成必须确定性：ext/sub 资源按固定顺序编号，输出无时间戳。
## @end-static-doc

const DEFAULT_SKIN := "sn_v1"
const SKIN_ROOT := "res://assets/ui/skin/"
const THEME_PATH := "res://assets/ui/theme/steam_navigator_theme.tres"
const CHECK_PATH := "user://ui_theme_check/steam_navigator_theme.tres"
const THEME_UID := "uid://donrdopu47413"
const BLUEPRINT_PANEL_PATH := "res://assets/ui/shipyard/blueprint_panel.png"

const FONT_SANS := "Noto Sans CJK SC, Microsoft YaHei UI, Microsoft YaHei, Source Han Sans SC, Arial"
const FONT_SERIF := "Noto Serif CJK SC, Noto Serif SC, Source Han Serif SC, SimSun, Microsoft YaHei UI"

var _args: Dictionary = {}
var _skin: Dictionary = {}
var _styles: Dictionary = {}
var _colors: Dictionary = {}
var _exts: Dictionary = {}            # path -> id
var _ext_order: Array = []
var _subs: Dictionary = {}            # signature -> id
var _sub_blocks: Array = []
var _sub_index := 0
var _skin_dir := ""


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var body := arg.substr(2)
			var eq := body.find("=")
			if eq >= 0:
				_args[body.substr(0, eq)] = body.substr(eq + 1)
			else:
				_args[body] = "true"
	var skin_id := String(_args.get("skin", DEFAULT_SKIN))
	_skin_dir = SKIN_ROOT.path_join(skin_id)
	var skin := _read_json(_skin_dir.path_join("skin.json"))
	if skin.is_empty():
		printerr("cannot read %s" % _skin_dir.path_join("skin.json"))
		quit(1)
		return
	_skin = skin
	_styles = skin.get("styles", {})
	_colors = skin.get("colors", {})
	var text := _build_theme_text()
	if text.is_empty():
		quit(1)
		return
	var check := bool(_args.get("check", "false") == "true")
	if check:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CHECK_PATH.get_base_dir()))
		var err := _write_text(CHECK_PATH, text)
		if err != OK:
			printerr("cannot write check output")
			quit(1)
			return
		var current := FileAccess.get_file_as_string(THEME_PATH)
		if current == text:
			print("[build_ui_theme] check OK (%s)" % skin_id)
			_cleanup()
			quit(0)
		else:
			printerr("[build_ui_theme] theme differs from %s" % THEME_PATH)
			_printerr_first_diff(current, text)
			_cleanup()
			quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(THEME_PATH.get_base_dir()))
	var err := _write_text(THEME_PATH, text)
	if err != OK:
		printerr("cannot write %s" % THEME_PATH)
		quit(1)
		return
	print("[build_ui_theme] wrote %s" % THEME_PATH)
	quit(0)


# ---------------------------------------------------------------------------
# Theme assembly
# ---------------------------------------------------------------------------

func _build_theme_text() -> String:
	var body: Array[String] = []
	# 基础字体
	var sans := _font_block("SystemFont_body", FONT_SANS)
	var serif := _font_block("SystemFont_display", FONT_SERIF)
	# 基础控件
	_add_button_type(body, "Button", _button_set(
		"button_normal", "button_hover", "button_pressed", "button_disabled"
	))
	_add_badge_free_label(body, "Label", "text.light", false)
	_add_line_edit(body)
	_add_option_button(body)
	_add_panel_type(body, "Panel", _style("panel_steel"))
	_add_panel_type(body, "PanelContainer", _style("panel_steel"))
	_add_progress_type(body, "ProgressBar", "meter_fill_amber")
	_add_check_box(body)
	_add_scroll_types(body)
	_add_separators(body)
	_add_tooltip(body)
	_add_tabs(body)
	_add_popup(body)
	body.append("RichTextLabel/colors/default_color = %s" % _color_str("text.light"))
	body.append("RichTextLabel/colors/font_shadow_color = Color(0, 0, 0, 0.32)")
	body.append("GridContainer/constants/h_separation = 16")
	body.append("GridContainer/constants/v_separation = 16")
	body.append("HBoxContainer/constants/separation = 12")
	body.append("VBoxContainer/constants/separation = 12")
	# 语义变体：按钮
	_add_button_variation(body, "SNPrimaryButton", _button_set(
		"button_selected", "button_hover", "button_pressed", "button_disabled"
	), _colors.get("text.light"))
	_add_button_variation(body, "SNSecondaryButton", _button_set(
		"button_normal", "button_hover", "button_pressed", "button_disabled"
	), _colors.get("text.light"))
	_add_button_variation(body, "SNDangerButton", _danger_button_set(), _colors.get("text.light"))
	_add_button_variation(body, "SNGhostButton", _ghost_button_set(), _colors.get("text.light"))
	_add_button_variation(body, "SNPlateButton", _button_set(
		"badge", "button_hover", "button_pressed", "button_disabled"
	), _colors.get("text.light"))
	_add_button_variation(body, "SNCompactButton", _compact_button_set(), _colors.get("text.light"))
	# 语义变体：面板
	_add_panel_variation(body, "SNPanel", _style("panel_steel", [1, 1, 1, 0.96]))
	_add_panel_variation(body, "SNElevatedPanel", _style("panel_steel", [1.08, 1.08, 1.08, 0.98], [24, 22, 24, 22]))
	_add_panel_variation(body, "SNInsetPanel", _style("panel_recess", [1, 1, 1, 0.95]))
	_add_panel_variation(body, "SNGlassPanel", _style("panel_steel", [1, 1, 1, 0.62], [14, 12, 14, 12]))
	_add_panel_variation(body, "SNChromePanel", _style("panel_steel", [1, 1, 1, 0.84], [16, 12, 16, 12]))
	_add_panel_variation(body, "SNStatusBarPanel", _style("panel_steel", [1, 1, 1, 0.9], [14, 6, 14, 6]))
	_add_panel_variation(body, "SNParchmentPanel", _style("panel_parchment"))
	_add_panel_variation(body, "SNBlueprintSheetPanel", _style("panel_blueprint"))
	_add_panel_variation(body, "SNCanvasPanel", _style("panel_canvas"))
	_add_panel_variation(body, "SNBlueprintPanel", _blueprint_panel_style())
	# 语义变体：徽标
	_add_badge_variation(body, "SNBadge", _style("badge"), "brass.highlight")
	_add_badge_variation(body, "SNSuccessBadge", _style("badge", [0.62, 0.92, 0.7, 1.0]), "state.success")
	_add_badge_variation(body, "SNWarningBadge", _style("badge", [1.0, 0.84, 0.56, 1.0]), "state.warning")
	_add_badge_variation(body, "SNDangerBadge", _style("badge_danger", null), "state.danger")
	# 语义变体：文字
	_add_label_variation(body, "SNTitleLabel", 24, "text.light", "SystemFont_display", 0.0)
	_add_label_variation(body, "SNEyebrowLabel", 11, "brass.highlight", "", 0.12)
	_add_label_variation(body, "SNDetailLabel", 12, "text.muted", "", 0.0)
	# 语义变体：进度
	_add_progress_variation(body, "SNBrassProgressBar", "meter_fill_amber")
	_add_progress_variation(body, "SNWaterProgressBar", "meter_fill_aqua")
	_add_progress_variation(body, "SNDangerProgressBar", "meter_fill_rust")

	var lines: Array[String] = []
	var ext_count := _ext_order.size()
	var sub_count := _sub_blocks.size() + 2
	lines.append("[gd_resource type=\"Theme\" uid=\"%s\" load_steps=%d format=3]" % [THEME_UID, ext_count + sub_count + 1])
	lines.append("")
	for path in _ext_order:
		lines.append("[ext_resource type=\"Texture2D\" path=\"%s\" id=\"%s\"]" % [path, _exts[path]])
	lines.append("")
	for block in _sub_blocks:
		lines.append(block)
	lines.append(sans)
	lines.append(serif)
	lines.append("")
	lines.append("[resource]")
	lines.append("default_font = SubResource(\"SystemFont_body\")")
	lines.append("default_font_size = 14")
	for line in body:
		lines.append(line)
	lines.append("")
	return "\n".join(lines)


func _add_button_type(body: Array[String], type_name: String, styles: Dictionary) -> void:
	body.append("%s/colors/font_color = %s" % [type_name, _color_str("text.light")])
	body.append("%s/colors/font_disabled_color = %s" % [type_name, _color_with_alpha("text.muted", 0.65)])
	body.append("%s/colors/font_focus_color = %s" % [type_name, _color_str("text.light")])
	body.append("%s/colors/font_hover_color = %s" % [type_name, _color_str("brass.highlight")])
	body.append("%s/colors/font_pressed_color = %s" % [type_name, _color_str("brass.highlight")])
	body.append("%s/font_sizes/font_size = 14" % type_name)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		body.append("%s/styles/%s = SubResource(\"%s\")" % [type_name, state, styles[state]])


func _add_button_variation(body: Array[String], type_name: String, styles: Dictionary, font_color: Variant) -> void:
	body.append("%s/base_type = &\"Button\"" % type_name)
	if font_color != null:
		body.append("%s/colors/font_color = %s" % [type_name, _color_from(font_color)])
	body.append("%s/colors/font_hover_color = %s" % [type_name, _color_str("brass.highlight")])
	body.append("%s/colors/font_pressed_color = %s" % [type_name, _color_str("brass.highlight")])
	body.append("%s/colors/font_disabled_color = %s" % [type_name, _color_with_alpha("text.muted", 0.65)])
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		body.append("%s/styles/%s = SubResource(\"%s\")" % [type_name, state, styles[state]])


func _button_set(normal: String, hover: String, pressed: String, disabled: String) -> Dictionary:
	return {
		"normal": _style(normal),
		"hover": _style(hover),
		"pressed": _style(pressed),
		"disabled": _style(disabled),
		"focus": _focus_style(),
	}


func _danger_button_set() -> Dictionary:
	return {
		"normal": _style("button_danger"),
		"hover": _style("button_danger", [1.16, 1.08, 1.06, 1.0]),
		"pressed": _style("button_pressed"),
		"disabled": _style("button_disabled"),
		"focus": _focus_style(),
	}


func _ghost_button_set() -> Dictionary:
	# content margin 全状态一致（12/4），否则 hover/focus 会改变按钮最小尺寸；
	# 这也是 test_sea_chart 的回归守卫。
	return {
		"normal": _empty_style([12, 4, 12, 4]),
		"hover": _style("button_normal", [1.0, 1.0, 1.0, 0.45], [12, 4, 12, 4]),
		"pressed": _style("button_pressed", [1.0, 1.0, 1.0, 0.7], [12, 4, 12, 4]),
		"disabled": _empty_style([12, 4, 12, 4]),
		"focus": _style("focus_ring", null, [12, 4, 12, 4]),
	}


## 紧凑按钮：小铭牌纹理（badge）+ 低内边距，给 30–36px 的导航 / 工具 / 步进按钮，
## 避免标准按钮 20/10 内容边距把固定层顶高。
func _compact_button_set() -> Dictionary:
	return {
		"normal": _style("badge", null, [12, 4, 12, 4]),
		"hover": _style("button_hover", null, [12, 4, 12, 4]),
		"pressed": _style("button_pressed", null, [12, 4, 12, 4]),
		"disabled": _style("button_disabled", null, [12, 4, 12, 4]),
		"focus": _style("focus_ring", null, [12, 4, 12, 4]),
	}


func _add_line_edit(body: Array[String]) -> void:
	body.append("LineEdit/colors/caret_color = %s" % _color_str("brass.highlight"))
	body.append("LineEdit/colors/font_color = %s" % _color_str("text.light"))
	body.append("LineEdit/colors/font_placeholder_color = %s" % _color_with_alpha("text.muted", 0.62))
	body.append("LineEdit/colors/selection_color = %s" % _color_with_alpha("brass.base", 0.35))
	body.append("LineEdit/styles/normal = SubResource(\"%s\")" % _style("input_recess"))
	body.append("LineEdit/styles/focus = SubResource(\"%s\")" % _style("input_recess", [1.22, 1.12, 0.96, 1.0]))
	body.append("LineEdit/styles/read_only = SubResource(\"%s\")" % _style("input_recess", [0.82, 0.86, 0.86, 1.0]))


func _add_option_button(body: Array[String]) -> void:
	body.append("OptionButton/colors/font_color = %s" % _color_str("text.light"))
	body.append("OptionButton/colors/font_hover_color = %s" % _color_str("brass.highlight"))
	body.append("OptionButton/font_sizes/font_size = 14")
	body.append("OptionButton/styles/normal = SubResource(\"%s\")" % _style("button_normal"))
	body.append("OptionButton/styles/hover = SubResource(\"%s\")" % _style("button_hover"))
	body.append("OptionButton/styles/pressed = SubResource(\"%s\")" % _style("button_pressed"))
	body.append("OptionButton/styles/disabled = SubResource(\"%s\")" % _style("button_disabled"))
	body.append("OptionButton/styles/focus = SubResource(\"%s\")" % _focus_style())


func _add_panel_type(body: Array[String], type_name: String, style_id: String) -> void:
	body.append("%s/styles/panel = SubResource(\"%s\")" % [type_name, style_id])


func _add_panel_variation(body: Array[String], type_name: String, style_id: String) -> void:
	body.append("%s/base_type = &\"PanelContainer\"" % type_name)
	body.append("%s/styles/panel = SubResource(\"%s\")" % [type_name, style_id])


func _add_label_free(body: Array[String], type_name: String) -> void:
	body.append("%s/colors/font_color = %s" % [type_name, _color_str("text.light")])
	body.append("%s/colors/font_shadow_color = Color(0, 0, 0, 0.32)" % type_name)
	body.append("%s/constants/shadow_offset_x = 1" % type_name)
	body.append("%s/constants/shadow_offset_y = 2" % type_name)


func _add_badge_free_label(body: Array[String], type_name: String, color_token: String, with_style: bool) -> void:
	_add_label_free(body, type_name)


func _add_label_variation(body: Array[String], type_name: String, size: int, color_token: String, font_id: String, shadow_alpha: float) -> void:
	body.append("%s/base_type = &\"Label\"" % type_name)
	body.append("%s/colors/font_color = %s" % [type_name, _color_str(color_token)])
	body.append("%s/font_sizes/font_size = %d" % [type_name, size])
	if not font_id.is_empty():
		body.append("%s/fonts/font = SubResource(\"%s\")" % [type_name, font_id])
	if shadow_alpha > 0.0:
		body.append("%s/colors/font_shadow_color = Color(0, 0, 0, %.2f)" % [type_name, shadow_alpha])
		body.append("%s/constants/shadow_offset_x = 0" % type_name)
		body.append("%s/constants/shadow_offset_y = 1" % type_name)


func _add_badge_variation(body: Array[String], type_name: String, style_id: String, color_token: String) -> void:
	body.append("%s/base_type = &\"Label\"" % type_name)
	body.append("%s/colors/font_color = %s" % [type_name, _color_str(color_token)])
	body.append("%s/font_sizes/font_size = 11" % type_name)
	body.append("%s/styles/normal = SubResource(\"%s\")" % [type_name, style_id])


func _add_progress_type(body: Array[String], type_name: String, fill_style: String) -> void:
	body.append("%s/styles/background = SubResource(\"%s\")" % [type_name, _style("meter_trough")])
	body.append("%s/styles/fill = SubResource(\"%s\")" % [type_name, _style(fill_style)])
	body.append("%s/colors/font_color = %s" % [type_name, _color_str("text.light")])


func _add_progress_variation(body: Array[String], type_name: String, fill_style: String) -> void:
	body.append("%s/base_type = &\"ProgressBar\"" % type_name)
	body.append("%s/styles/background = SubResource(\"%s\")" % [type_name, _style("meter_trough")])
	body.append("%s/styles/fill = SubResource(\"%s\")" % [type_name, _style(fill_style)])


func _add_check_box(body: Array[String]) -> void:
	body.append("CheckBox/colors/font_color = %s" % _color_str("text.light"))
	body.append("CheckBox/colors/font_hover_color = %s" % _color_str("brass.highlight"))
	body.append("CheckBox/colors/font_disabled_color = %s" % _color_with_alpha("text.muted", 0.65))
	body.append("CheckBox/constants/h_separation = 8")
	body.append("CheckBox/icons/checked = ExtResource(\"%s\")" % _icon_ext("check_checked"))
	body.append("CheckBox/icons/unchecked = ExtResource(\"%s\")" % _icon_ext("check_empty"))
	body.append("CheckBox/icons/checked_disabled = ExtResource(\"%s\")" % _icon_ext("check_checked_disabled"))
	body.append("CheckBox/icons/unchecked_disabled = ExtResource(\"%s\")" % _icon_ext("check_empty_disabled"))
	body.append("CheckBox/styles/normal = SubResource(\"%s\")" % _empty_style([0, 0, 0, 0]))


func _add_scroll_types(body: Array[String]) -> void:
	for type_name in ["VScrollBar", "HScrollBar"]:
		body.append("%s/styles/scroll = SubResource(\"%s\")" % [type_name, _style("scrollbar_track")])
		body.append("%s/styles/grabber = SubResource(\"%s\")" % [type_name, _style("scrollbar_grabber")])
		body.append("%s/styles/grabber_highlight = SubResource(\"%s\")" % [type_name, _style("scrollbar_grabber", [1.25, 1.2, 1.1, 1.0])])
		body.append("%s/styles/grabber_pressed = SubResource(\"%s\")" % [type_name, _style("scrollbar_grabber", [0.82, 0.8, 0.78, 1.0])])
	body.append("ScrollContainer/styles/panel = SubResource(\"%s\")" % _empty_style([0, 0, 0, 0]))


func _add_separators(body: Array[String]) -> void:
	var sep := Color(String(_colors.get("brass.base", "#C28A3B")))
	sep.a = 0.25
	var line := _line_style(sep, 1)
	body.append("HSeparator/styles/separator = SubResource(\"%s\")" % line)
	body.append("VSeparator/styles/separator = SubResource(\"%s\")" % line)


func _add_tooltip(body: Array[String]) -> void:
	body.append("TooltipPanel/styles/panel = SubResource(\"%s\")" % _style("panel_steel", [1, 1, 1, 0.97], [12, 8, 12, 8]))
	body.append("TooltipLabel/colors/font_color = %s" % _color_str("text.light"))
	body.append("TooltipLabel/font_sizes/font_size = 13")


func _add_tabs(body: Array[String]) -> void:
	body.append("TabBar/constants/h_separation = 2")
	body.append("TabBar/styles/tab_selected = SubResource(\"%s\")" % _style("button_selected", null, [14, 8, 14, 8]))
	body.append("TabBar/styles/tab_unselected = SubResource(\"%s\")" % _style("button_normal", null, [14, 8, 14, 8]))
	body.append("TabBar/styles/tab_hovered = SubResource(\"%s\")" % _style("button_hover", null, [14, 8, 14, 8]))
	body.append("TabBar/styles/tab_disabled = SubResource(\"%s\")" % _style("button_disabled", null, [14, 8, 14, 8]))
	body.append("TabBar/styles/tab_focus = SubResource(\"%s\")" % _focus_style())
	body.append("TabContainer/styles/panel = SubResource(\"%s\")" % _empty_style([0, 0, 0, 0]))


func _add_popup(body: Array[String]) -> void:
	body.append("PopupPanel/styles/panel = SubResource(\"%s\")" % _style("panel_recess", null, [8, 6, 8, 6]))
	body.append("PopupMenu/styles/panel = SubResource(\"%s\")" % _style("panel_recess", null, [6, 6, 6, 6]))
	body.append("PopupMenu/styles/hover = SubResource(\"%s\")" % _style("button_hover", null, [6, 3, 6, 3]))
	body.append("PopupMenu/colors/font_color = %s" % _color_str("text.light"))
	body.append("PopupMenu/colors/font_hover_color = %s" % _color_str("brass.highlight"))
	body.append("PopupMenu/font_sizes/font_size = 14")


# ---------------------------------------------------------------------------
# StyleBox builders
# ---------------------------------------------------------------------------

func _style(style_id: String, modulate: Variant = null, content_override: Variant = null) -> String:
	var signature := "%s|%s|%s" % [style_id, str(modulate), str(content_override)]
	if _subs.has(signature):
		return String(_subs[signature])
	var def: Dictionary = _styles.get(style_id, {})
	if def.is_empty():
		printerr("unknown style id: %s" % style_id)
		return _empty_style([0, 0, 0, 0])
	if bool(def.get("fixed", false)):
		printerr("style id is a fixed part, not a stylebox: %s" % style_id)
		return _empty_style([0, 0, 0, 0])
	var path: String = _skin_dir.path_join(String(def.get("file", "")))
	var ext := _ext(path)
	var t_margin: Array = def.get("texture_margin", [12, 8, 12, 8])
	var c_margin: Array = content_override if content_override != null else def.get("content_margin", [12, 8, 12, 8])
	var mod: Array = modulate if modulate != null else def.get("modulate", [1, 1, 1, 1])
	_sub_index += 1
	var sub_id := "StyleBox_%d" % _sub_index
	var lines: Array[String] = []
	lines.append("[sub_resource type=\"StyleBoxTexture\" id=\"%s\"]" % sub_id)
	lines.append("texture = ExtResource(\"%s\")" % ext)
	lines.append("texture_margin_left = %.1f" % float(t_margin[0]))
	lines.append("texture_margin_top = %.1f" % float(t_margin[1]))
	lines.append("texture_margin_right = %.1f" % float(t_margin[2]))
	lines.append("texture_margin_bottom = %.1f" % float(t_margin[3]))
	lines.append("modulate_color = Color(%s, %s, %s, %s)" % [
		_num(mod[0]), _num(mod[1]), _num(mod[2]), _num(mod[3])
	])
	lines.append("content_margin_left = %.1f" % float(c_margin[0]))
	lines.append("content_margin_top = %.1f" % float(c_margin[1]))
	lines.append("content_margin_right = %.1f" % float(c_margin[2]))
	lines.append("content_margin_bottom = %.1f" % float(c_margin[3]))
	_sub_blocks.append("\n".join(lines))
	_subs[signature] = sub_id
	return sub_id


func _empty_style(content: Array) -> String:
	var signature := "empty|%s" % str(content)
	if _subs.has(signature):
		return String(_subs[signature])
	_sub_index += 1
	var sub_id := "StyleBoxEmpty_%d" % _sub_index
	var lines: Array[String] = []
	lines.append("[sub_resource type=\"StyleBoxEmpty\" id=\"%s\"]" % sub_id)
	lines.append("content_margin_left = %.1f" % float(content[0]))
	lines.append("content_margin_top = %.1f" % float(content[1]))
	lines.append("content_margin_right = %.1f" % float(content[2]))
	lines.append("content_margin_bottom = %.1f" % float(content[3]))
	_sub_blocks.append("\n".join(lines))
	_subs[signature] = sub_id
	return sub_id


func _line_style(color: Color, thickness: int) -> String:
	var signature := "line|%s|%d" % [_color_from(color), thickness]
	if _subs.has(signature):
		return String(_subs[signature])
	_sub_index += 1
	var sub_id := "StyleBoxLine_%d" % _sub_index
	var lines: Array[String] = []
	lines.append("[sub_resource type=\"StyleBoxLine\" id=\"%s\"]" % sub_id)
	lines.append("color = %s" % _color_from(color))
	lines.append("thickness = %d" % thickness)
	_sub_blocks.append("\n".join(lines))
	_subs[signature] = sub_id
	return sub_id


func _focus_style() -> String:
	return _style("focus_ring")


func _blueprint_panel_style() -> String:
	var signature := "blueprint_panel"
	if _subs.has(signature):
		return String(_subs[signature])
	var ext := _ext(BLUEPRINT_PANEL_PATH)
	_sub_index += 1
	var sub_id := "StyleBoxTexture_%d" % _sub_index
	var lines: Array[String] = []
	lines.append("[sub_resource type=\"StyleBoxTexture\" id=\"%s\"]" % sub_id)
	lines.append("texture = ExtResource(\"%s\")" % ext)
	lines.append("texture_margin_left = 56.0")
	lines.append("texture_margin_top = 54.0")
	lines.append("texture_margin_right = 56.0")
	lines.append("texture_margin_bottom = 54.0")
	lines.append("content_margin_left = 66.0")
	lines.append("content_margin_top = 62.0")
	lines.append("content_margin_right = 66.0")
	lines.append("content_margin_bottom = 62.0")
	_sub_blocks.append("\n".join(lines))
	_subs[signature] = sub_id
	return sub_id


func _font_block(sub_id: String, names_csv: String) -> String:
	var names: Array[String] = []
	for part in names_csv.split(","):
		names.append("\"%s\"" % part.strip_edges())
	var lines: Array[String] = []
	lines.append("[sub_resource type=\"SystemFont\" id=\"%s\"]" % sub_id)
	lines.append("font_names = PackedStringArray(%s)" % ", ".join(names))
	return "\n".join(lines)


# ---------------------------------------------------------------------------
# Tokens / IO
# ---------------------------------------------------------------------------

func _ext(path: String) -> String:
	if _exts.has(path):
		return String(_exts[path])
	var id := "tex_%d" % (_ext_order.size() + 1)
	_exts[path] = id
	_ext_order.append(path)
	return id


func _icon_ext(icon_id: String) -> String:
	return _ext(_skin_dir.path_join("icons/%s.png" % icon_id))


func _color_str(token: String) -> String:
	var value: Variant = _colors.get(token, "#ffffff")
	return _color_from(Color(String(value)))


func _color_with_alpha(token: String, alpha: float) -> String:
	var c := Color(String(_colors.get(token, "#ffffff")))
	c.a = alpha
	return _color_from(c)


func _color_from(c: Color) -> String:
	return "Color(%s, %s, %s, %s)" % [_num(c.r), _num(c.g), _num(c.b), _num(c.a)]


func _num(value: Variant) -> String:
	var f := float(value)
	if is_equal_approx(f, roundf(f)):
		return "%d" % int(roundf(f))
	return ("%.6f" % f).rstrip("0").rstrip(".")


func _read_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed as Dictionary if parsed is Dictionary else {}


func _write_text(path: String, text: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ERR_CANT_OPEN
	file.store_string(text)
	file.close()
	return OK


func _cleanup() -> void:
	var abs_path := ProjectSettings.globalize_path(CHECK_PATH)
	if FileAccess.file_exists(abs_path):
		DirAccess.remove_absolute(abs_path)


func _printerr_first_diff(current: String, generated: String) -> void:
	var cur_lines := current.split("\n")
	var gen_lines := generated.split("\n")
	var limit := mini(cur_lines.size(), gen_lines.size())
	for i in range(limit):
		if cur_lines[i] != gen_lines[i]:
			printerr("first diff at line %d:\n  committed: %s\n  generated: %s" % [i + 1, cur_lines[i], gen_lines[i]])
			return
	if cur_lines.size() != gen_lines.size():
		printerr("line count differs: committed=%d generated=%d" % [cur_lines.size(), gen_lines.size()])
