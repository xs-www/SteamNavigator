extends TestCase
## UI 皮肤基础层验收（task-6 / UI Foundation Spec V1）。
##
## 只读取交付物，不启动渲染：headless 下验证
##   - `assets/ui/skin/sn_v1/skin.json` 可解析、清单齐全；
##   - manifest 声明的每张九宫格 / 图标纹理存在、可加载、尺寸符合 0.5× 约定；
##   - theme 的 SN* variation 齐全，纹理类 stylebox 全部指向皮肤目录且边距合理；
##   - theme 引用的纹理清单与 skin.json 声明一致（换贴图一致性门禁）；
##   - 颜色 / 字号 token 覆盖 UI_FOUNDATION_SPEC_V1 §7；
##   - `SNSkin` 运行时 API 返回有效对象；
##   - `framework/ui` 业务脚本不再出现 `StyleBoxFlat.new()` 与十六进制业务色。
##
## 生成器 `--check` 不在这里直接调用外部进程；等价门禁由
## `test_theme_textures_match_the_skin_manifest` 完成：theme 里每个纹理都必须
## 能在 skin.json 的 texture 清单里找到（唯一的固定例外是随 Core 发布的
## `assets/ui/shipyard/blueprint_panel.png`，SNBlueprintPanel 专用九宫格）。

const SKIN_DIR := "res://assets/ui/skin/sn_v1/"
const SKIN_JSON := SKIN_DIR + "skin.json"
const THEME_PATH := "res://assets/ui/theme/steam_navigator_theme.tres"
const CONTROL_REGIONS_PATH := "res://docs/design/ui_controls_v1/regions.json"
const ICON_MANIFEST_PATH := "res://docs/design/ui_icons_v1/manifest.json"
const SKIN_BUILD_SCRIPT := "res://tools/ui/build_ui_skin.gd"
const SKIN_BUILD_WRAPPER := "res://tools/build_ui_skin.ps1"

## UI_FOUNDATION_SPEC_V1 §7 的 20 个颜色 token 与取值（页面不得再写业务十六进制色）。
const SPEC_COLORS := {
	"bg.abyss": "#061416",
	"steel.base": "#102B2E",
	"steel.raised": "#1A4548",
	"steel.recess": "#071D20",
	"brass.shadow": "#6D431D",
	"brass.base": "#C28A3B",
	"brass.highlight": "#EDC46D",
	"paper.base": "#D8C69E",
	"paper.highlight": "#EFE1BD",
	"ink.primary": "#2A2119",
	"blueprint.base": "#153D47",
	"blueprint.line": "#C8DED0",
	"cloth.teal": "#245B5E",
	"cloth.blue": "#285A72",
	"state.success": "#6E9C75",
	"state.warning": "#D19A42",
	"state.danger": "#A84A3E",
	"state.water": "#4CA4B8",
	"text.light": "#F0E4C8",
	"text.muted": "#A5B0A4",
}
const SPEC_FONT_TOKENS := ["display", "h1", "h2", "key", "body", "label", "detail", "caption"]
## Theme 必须提供的 SN* variation（UI Foundation Spec V1 组件契约）。
const REQUIRED_VARIATIONS := [
	"SNPrimaryButton", "SNSecondaryButton", "SNDangerButton", "SNGhostButton", "SNPlateButton",
	"SNPanel", "SNElevatedPanel", "SNInsetPanel", "SNGlassPanel", "SNParchmentPanel",
	"SNBlueprintSheetPanel", "SNCanvasPanel", "SNBlueprintPanel",
	"SNBadge", "SNSuccessBadge", "SNWarningBadge", "SNDangerBadge",
	"SNTitleLabel", "SNEyebrowLabel", "SNDetailLabel",
	"SNBrassProgressBar", "SNWaterProgressBar", "SNDangerProgressBar",
]
const PANEL_KINDS := ["steel", "recess", "parchment", "blueprint", "canvas", "glass", "frame_open"]
const BUTTON_STATES := ["normal", "hover", "pressed", "disabled", "focus"]
## 主题里唯一允许的皮肤目录外纹理：保留的 Core 船厂蓝图九宫格。
const THEME_TEXTURE_EXCEPTIONS := ["res://assets/ui/shipyard/blueprint_panel.png"]
## 换贴图一致性允许的派生主题图标：`check_checked/check_empty/check_{...}_disabled`
## 由生成器从控件图集（checkbox_empty 底 + action_confirm 勾/叉）派生，theme 直接按文件
## 引用，不进 skin.json 的 icons 业务表（业务图标保持 30 个 + 3 个别名）。
const DERIVED_THEME_ICON_PREFIXES := ["res://assets/ui/skin/sn_v1/icons/check_"]
## 业务脚本守门白名单：皮肤运行时 + 数据可视化（线稿/图表可保留绘制型 StyleBox）。
const STYLEBOX_FLAT_WHITELIST := [
	"res://framework/ui/skin/",
	"res://framework/ui/components/sn_sea_chart_view.gd",
	"res://framework/ui/components/sn_sea_chart_panel.gd",
	"res://framework/ui/components/sn_sparkline.gd",
]
const HEX_COLOR_WHITELIST := ["res://framework/ui/skin/"]


# ---------------------------------------------------------------------------
# 数据读取辅助
# ---------------------------------------------------------------------------

func _read_json(path: String) -> Dictionary:
	assert_true(FileAccess.file_exists(path), "%s exists" % path)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(parsed is Dictionary, "%s parses as a JSON object" % path)
	return parsed if parsed is Dictionary else {}


func _manifest() -> Dictionary:
	return _read_json(SKIN_JSON)


func _styles(manifest: Dictionary) -> Dictionary:
	var styles: Variant = manifest.get("styles", {})
	return styles if styles is Dictionary else {}


func _icons(manifest: Dictionary) -> Dictionary:
	var icons: Variant = manifest.get("icons", {})
	return icons if icons is Dictionary else {}


func _skin_path(rel: String) -> String:
	if rel.begins_with("res://"):
		return rel
	return SKIN_DIR.path_join(rel)


func _load_skin_texture(rel: String) -> Texture2D:
	var path := _skin_path(rel)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _control_regions() -> Dictionary:
	var parsed := _read_json(CONTROL_REGIONS_PATH)
	var regions := {}
	for asset in parsed.get("assets", []):
		if not (asset is Dictionary):
			continue
		var region: Variant = (asset as Dictionary).get("region", [])
		if region is Array and (region as Array).size() == 4:
			regions[String((asset as Dictionary).get("id", ""))] = Vector2i(
				int(region[2]), int(region[3])
			)
	return regions


func _icon_manifest() -> Dictionary:
	return _read_json(ICON_MANIFEST_PATH)


func _declared_style_files(manifest: Dictionary) -> Dictionary:
	var files := {}
	for style_id in _styles(manifest):
		var def: Variant = _styles(manifest)[style_id]
		if def is Dictionary and (def as Dictionary).has("file"):
			files[String(style_id)] = String((def as Dictionary).get("file", ""))
	return files


func _all_declared_files(manifest: Dictionary) -> Array[String]:
	var files: Array[String] = []
	for rel in _declared_style_files(manifest).values():
		if not String(rel).is_empty() and not files.has(String(rel)):
			files.append(String(rel))
	for icon_id in _icons(manifest):
		var rel := String(_icons(manifest)[icon_id])
		if not rel.is_empty() and not files.has(rel):
			files.append(rel)
	return files


func _gd_files(root: String, out: Array[String] = []) -> Array[String]:
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		var path := root.path_join(entry)
		if dir.current_is_dir():
			_gd_files(path, out)
		elif entry.ends_with(".gd"):
			out.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
	return out


func _is_whitelisted(path: String, whitelist: Array) -> bool:
	for prefix in whitelist:
		if path.begins_with(String(prefix)):
			return true
	return false


func _color_from_hex(text: String) -> Color:
	return Color(text)


# ---------------------------------------------------------------------------
# 1. skin.json 本身
# ---------------------------------------------------------------------------

func test_skin_manifest_exists_and_is_complete() -> void:
	assert_true(FileAccess.file_exists(SKIN_JSON), "skin manifest exists: %s" % SKIN_JSON)
	var manifest := _manifest()
	if manifest.is_empty():
		return
	assert_eq(String(manifest.get("id", "")), "sn_v1", "manifest declares the skin id")
	assert_eq(int(manifest.get("version", 0)), 1, "manifest declares version 1")
	assert_almost_eq(float(manifest.get("scale", 0.0)), 0.5, 0.0001, "manifest declares the 0.5x texture scale")
	for key in ["source", "colors", "fonts", "styles", "icons"]:
		assert_true(manifest.get(key) is Dictionary, "manifest has a %s dictionary" % key)
	# 每张纹理的声明都带完整字段：file，且非固定件带 texture_margin / content_margin。
	var invalid: Array[String] = []
	for style_id in _styles(manifest):
		var def: Variant = _styles(manifest)[style_id]
		if not (def is Dictionary):
			invalid.append(String(style_id))
			continue
		var entry: Dictionary = def
		if not entry.has("file"):
			invalid.append("%s: missing file" % style_id)
		elif bool(entry.get("fixed", false)):
			if not (entry.get("size", []) is Array) or (entry.get("size", []) as Array).size() != 2:
				invalid.append("%s: fixed part without size" % style_id)
		else:
			for margin_key in ["texture_margin", "content_margin"]:
				if not _is_margin(entry.get(margin_key, null)):
					invalid.append("%s: bad %s" % [style_id, margin_key])
	assert_empty(invalid, "every style declaration is complete: %s" % str(invalid))
	var source := manifest.get("source", {}) as Dictionary
	for key in ["controls_atlas", "controls_regions", "icon_manifest"]:
		var path := String(source.get(key, ""))
		assert_true(path.begins_with("res://"), "source.%s is a res:// path" % key)
		assert_true(FileAccess.file_exists(path), "source.%s exists on disk" % key)
	assert_true(FileAccess.file_exists(SKIN_BUILD_SCRIPT), "skin generator exists: %s" % SKIN_BUILD_SCRIPT)
	assert_true(FileAccess.file_exists(SKIN_BUILD_WRAPPER), "skin generator wrapper exists: %s" % SKIN_BUILD_WRAPPER)


func _is_margin(value: Variant) -> bool:
	if not (value is Array):
		return false
	var entries: Array = value
	if entries.size() != 4:
		return false
	for entry in entries:
		if not (entry is int or entry is float):
			return false
	return true


# ---------------------------------------------------------------------------
# 2. 九宫格 / 图标纹理：存在、可加载、0.5× 与边距约定
# ---------------------------------------------------------------------------

func test_declared_skin_textures_exist_and_match_half_scale() -> void:
	var manifest := _manifest()
	var regions := _control_regions()
	assert_true(regions.size() >= 25, "control regions manifest lists the source atlas regions (%d)" % regions.size())
	var missing: Array[String] = []
	var unloadable: Array[String] = []
	var wrong_scale: Array[String] = []
	var bad_margins: Array[String] = []
	var derived: Array[String] = []
	for style_id in _declared_style_files(manifest):
		var def: Dictionary = _styles(manifest)[style_id]
		var rel := String(def.get("file", ""))
		var tex := _load_skin_texture(rel)
		if not ResourceLoader.exists(_skin_path(rel)):
			missing.append("%s (%s)" % [style_id, rel])
			continue
		if tex == null:
			unloadable.append("%s (%s)" % [style_id, rel])
			continue
		var size := tex.get_size()
		if bool(def.get("fixed", false)):
			var declared: Array = def.get("size", [])
			if size != Vector2(float(declared[0]), float(declared[1])):
				wrong_scale.append("%s: fixed part is %s, declared %s" % [style_id, str(size), str(declared)])
			continue
		var region: Variant = regions.get(style_id, null)
		if region is Vector2i:
			var source: Vector2i = region
			var expected := Vector2(source.x * 0.5, source.y * 0.5)
			# 0.5× 输出会做整数取整：允许 ±1 px。
			if absf(size.x - expected.x) > 1.0 or absf(size.y - expected.y) > 1.0:
				wrong_scale.append("%s: %s, expected 0.5x of %s ≈ %s" % [style_id, str(size), str(source), str(expected)])
		else:
			derived.append(style_id)
			if size.x <= 0.0 or size.y <= 0.0:
				unloadable.append("%s: empty size" % style_id)
		var margins: Array = def.get("texture_margin", [])
		if _is_margin(margins) and (
			float(margins[0]) * 2.0 > size.x or float(margins[2]) * 2.0 > size.x or
			float(margins[1]) * 2.0 > size.y or float(margins[3]) * 2.0 > size.y
		):
			bad_margins.append("%s: margins %s vs texture %s" % [style_id, str(margins), str(size)])
	assert_empty(missing, "every declared nine-slice/part texture exists: %s" % str(missing))
	assert_empty(unloadable, "every declared texture loads as Texture2D: %s" % str(unloadable))
	assert_empty(wrong_scale, "nine-slice textures follow the 0.5x source convention: %s" % str(wrong_scale))
	assert_empty(bad_margins, "texture margins leave a non-negative stretch area: %s" % str(bad_margins))
	assert_true(not derived.is_empty(), "derived parts (badge/fill/scrollbar/focus ring) are declared too (%d)" % derived.size())
	assert_true(_declared_style_files(manifest).size() >= 40,
		"manifest declares the full control set (%d styles)" % _declared_style_files(manifest).size())


func test_icon_manifest_has_thirty_icons_and_aliases_resolve() -> void:
	var manifest := _manifest()
	var icons := _icons(manifest)
	var icon_manifest := _icon_manifest()
	var assets: Array = icon_manifest.get("assets", [])
	assert_eq(assets.size(), 30, "the icon source manifest lists 30 icons")
	var missing: Array[String] = []
	var bad_size: Array[String] = []
	var bad_path: Array[String] = []
	for asset in assets:
		if not (asset is Dictionary):
			continue
		var icon_id := String((asset as Dictionary).get("id", ""))
		assert_true(icons.has(icon_id), "skin manifest maps icon %s" % icon_id)
		if not icons.has(icon_id):
			continue
		var rel := String(icons[icon_id])
		if not rel.begins_with("icons/"):
			bad_path.append("%s -> %s" % [icon_id, rel])
		var tex := _load_skin_texture(rel)
		if tex == null:
			missing.append(icon_id)
			continue
		# 源图标为统一 256x256 独立画布，0.5× 后必须是 128x128。
		if tex.get_size() != Vector2(128.0, 128.0):
			bad_size.append("%s: %s" % [icon_id, str(tex.get_size())])
	assert_empty(missing, "every manifest icon texture loads: %s" % str(missing))
	assert_empty(bad_size, "every manifest icon is 128x128 (0.5x of the 256 canvas): %s" % str(bad_size))
	assert_empty(bad_path, "icon entries live under icons/: %s" % str(bad_path))
	var aliases: Dictionary = icon_manifest.get("aliases", {})
	assert_eq(aliases.size(), 3, "the icon source manifest declares 3 reuse aliases")
	for alias_id in aliases:
		var target := String(aliases[alias_id])
		assert_true(icons.has(target), "alias %s resolves to a declared icon (%s)" % [alias_id, target])
		assert_true(icons.has(String(alias_id)) == false or String(alias_id) == target,
			"alias %s is a pure alias, not a duplicate entry" % alias_id)
		var alias_texture := _load_skin_texture(String(icons.get(target, "")))
		assert_not_null(alias_texture, "alias %s resolves to a loadable texture" % alias_id)


# ---------------------------------------------------------------------------
# 3. Theme：variation 齐全 + 纹理 stylebox 指向皮肤
# ---------------------------------------------------------------------------

func test_theme_exposes_all_sn_variations() -> void:
	var theme := load(THEME_PATH) as Theme
	assert_not_null(theme, "the shared theme loads: %s" % THEME_PATH)
	if theme == null:
		return
	var types: Array[String] = []
	for type_name in theme.get_type_list():
		types.append(String(type_name))
	var missing: Array[String] = []
	for variation in REQUIRED_VARIATIONS:
		if not types.has(variation):
			missing.append(variation)
			continue
		var base := String(theme.get_variation_base(variation))
		assert_false(base.is_empty(), "%s is a type variation, not a base type" % variation)
	assert_empty(missing, "the theme defines every required SN* variation: %s" % str(missing))
	assert_true(types.size() >= REQUIRED_VARIATIONS.size(),
		"the theme keeps its variation count (%d types)" % types.size())


func test_theme_texture_styleboxes_use_the_skin_textures() -> void:
	var theme := load(THEME_PATH) as Theme
	assert_not_null(theme, "the shared theme loads")
	if theme == null:
		return
	var total := 0
	var outside: Array[String] = []
	var null_texture: Array[String] = []
	var bad_margins: Array[String] = []
	for type_name in theme.get_type_list():
		for style_name in theme.get_stylebox_list(type_name):
			var box: Variant = theme.get_stylebox(style_name, type_name)
			if not (box is StyleBoxTexture):
				continue
			total += 1
			var texture_box := box as StyleBoxTexture
			var texture := texture_box.texture
			if texture == null:
				null_texture.append("%s/%s" % [type_name, style_name])
				continue
			var path := String(texture.resource_path)
			if path.is_empty():
				path = String(texture.get_path())
			var allowed := path.begins_with(SKIN_DIR) or THEME_TEXTURE_EXCEPTIONS.has(path)
			if not allowed:
				outside.append("%s/%s -> %s" % [type_name, style_name, path])
			var size := texture.get_size()
			var left := texture_box.texture_margin_left
			var right := texture_box.texture_margin_right
			var top := texture_box.texture_margin_top
			var bottom := texture_box.texture_margin_bottom
			if left + right > size.x or top + bottom > size.y or left < 0.0 or top < 0.0:
				bad_margins.append("%s/%s: margins %.0f/%.0f/%.0f/%.0f vs %s" % [
					type_name, style_name, left, top, right, bottom, str(size)
				])
	assert_true(total >= 20, "the theme builds its styleboxes from textures (%d StyleBoxTexture entries)" % total)
	assert_empty(null_texture, "every texture stylebox has a texture: %s" % str(null_texture))
	assert_empty(outside, "texture styleboxes point at res://assets/ui/skin/ (blueprint panel excepted): %s" % str(outside))
	assert_empty(bad_margins, "texture margins fit inside the texture: %s" % str(bad_margins))


## 换贴图一致性门禁：theme 引用的每个纹理都存在，且九宫格文件都在 skin.json 里声明过。
## 换同名同尺寸贴图不需要改 theme；新贴图必须先进生成器 + skin.json，不能手改 theme。
func test_theme_textures_match_the_skin_manifest() -> void:
	var theme := load(THEME_PATH) as Theme
	assert_not_null(theme, "the shared theme loads")
	if theme == null:
		return
	var manifest := _manifest()
	var declared_style_files := _declared_style_files(manifest)
	var declared_icons := _icons(manifest)
	var seen: Array[String] = []
	var missing: Array[String] = []
	var undeclared: Array[String] = []
	for type_name in theme.get_type_list():
		for style_name in theme.get_stylebox_list(type_name):
			var box: Variant = theme.get_stylebox(style_name, type_name)
			if not (box is StyleBoxTexture):
				continue
			var texture := (box as StyleBoxTexture).texture
			if texture != null:
				_collect_theme_texture(texture, declared_style_files, declared_icons, seen, missing, undeclared)
		for icon_name in theme.get_icon_list(type_name):
			var icon := theme.get_icon(icon_name, type_name)
			if icon != null:
				_collect_theme_texture(icon, declared_style_files, declared_icons, seen, missing, undeclared)
	assert_true(seen.size() >= 20, "the theme references the full texture set (%d textures)" % seen.size())
	assert_empty(missing, "every theme texture file exists: %s" % str(missing))
	assert_empty(undeclared, "every theme nine-slice texture is declared in skin.json: %s" % str(undeclared))
	# 反方向：theme 用到的皮肤纹理必须来自当前 skin 目录（换肤 = 换目录/换同名文件）。
	var local := 0
	for path in seen:
		if path.begins_with(SKIN_DIR):
			local += 1
	assert_true(local >= seen.size() - THEME_TEXTURE_EXCEPTIONS.size(),
		"the theme is driven by the skin directory (%d/%d textures)" % [local, seen.size()])


func _collect_theme_texture(
	texture: Texture2D,
	declared_style_files: Dictionary,
	declared_icons: Dictionary,
	seen: Array,
	missing: Array,
	undeclared: Array
) -> void:
	var path := String(texture.resource_path)
	if path.is_empty():
		path = String(texture.get_path())
	if path.is_empty() or seen.has(path):
		return
	seen.append(path)
	if THEME_TEXTURE_EXCEPTIONS.has(path):
		return
	if not FileAccess.file_exists(path):
		missing.append(path)
		return
	var rel := path.trim_prefix(SKIN_DIR)
	var declared_files: Array = declared_style_files.values()
	var declared_icon_paths: Array = declared_icons.values()
	if declared_files.has(rel) or declared_icon_paths.has(rel):
		return
	for prefix in DERIVED_THEME_ICON_PREFIXES:
		if path.begins_with(String(prefix)):
			return
	undeclared.append("%s (not declared in skin.json)" % rel)


# ---------------------------------------------------------------------------
# 4. 颜色 / 字号 token
# ---------------------------------------------------------------------------

func test_color_tokens_cover_the_foundation_spec() -> void:
	var manifest := _manifest()
	var colors: Variant = manifest.get("colors", {})
	assert_true(colors is Dictionary, "manifest has a colors dictionary")
	if not (colors is Dictionary):
		return
	var actual: Dictionary = colors
	for token in SPEC_COLORS:
		if not actual.has(token):
			fail("color token %s is missing from skin.json" % token)
			continue
		var text := String(actual[token])
		var regex := RegEx.create_from_string("^#[0-9A-Fa-f]{6}$")
		assert_not_null(regex.search(text), "%s is a #RRGGBB value (%s)" % [token, text])
		assert_eq(_color_from_hex(text), _color_from_hex(String(SPEC_COLORS[token])),
			"%s matches UI_FOUNDATION_SPEC_V1 §7 (%s)" % [token, text])
	var fonts: Variant = manifest.get("fonts", {})
	assert_true(fonts is Dictionary, "manifest has a fonts dictionary")
	if fonts is Dictionary:
		var font_tokens: Dictionary = fonts
		for token in SPEC_FONT_TOKENS:
			if not font_tokens.has(token):
				fail("font token %s is missing from skin.json" % token)
				continue
			assert_true(int(font_tokens[token]) > 0, "font token %s has a positive size" % token)


# ---------------------------------------------------------------------------
# 5. SNSkin 运行时 API
# ---------------------------------------------------------------------------

func test_sn_skin_runtime_accessors_return_live_objects() -> void:
	SNSkin.clear_cache()
	assert_true(SNSkin.skin_dir().begins_with("res://assets/ui/skin/"), "SNSkin resolves the skin directory: %s" % SNSkin.skin_dir())
	assert_true(SNSkin.skin_dir().ends_with("/"), "SNSkin skin_dir has a trailing slash for path_join")
	var manifest := SNSkin.manifest()
	assert_false(manifest.is_empty(), "SNSkin.manifest() parses skin.json")
	assert_eq(String(manifest.get("id", "")), "sn_v1", "SNSkin.manifest() exposes the skin id")
	assert_true(SNSkin.is_available(), "SNSkin reports the skin as available")
	assert_true(SNSkin.texture("button_normal") is Texture2D, "SNSkin.texture() resolves a style texture")
	assert_true(SNSkin.texture("nav_market") is Texture2D, "SNSkin.texture() falls back to the icon table")
	assert_true(SNSkin.texture("no_such_texture") == null, "SNSkin.texture() returns null for unknown ids")
	for icon_id in _icons(_manifest()):
		assert_true(SNSkin.icon(String(icon_id)) is Texture2D, "SNSkin.icon(%s) loads" % icon_id)
	assert_true(SNSkin.icon("no_such_icon") == null, "SNSkin.icon() returns null for unknown ids")
	var style := SNSkin.style("button_normal")
	assert_true(style is StyleBoxTexture, "SNSkin.style() builds a StyleBoxTexture")
	if style is StyleBoxTexture:
		assert_not_null((style as StyleBoxTexture).texture, "SNSkin stylebox carries a texture")
		assert_almost_eq((style as StyleBoxTexture).texture_margin_left, 20.0, 0.001, "SNSkin stylebox keeps the manifest texture margin")
	assert_true(SNSkin.style("checkbox_empty") == null, "SNSkin.style() returns null for fixed parts")
	assert_true(SNSkin.style("no_such_style") == null, "SNSkin.style() returns null for unknown ids")
	for kind in PANEL_KINDS:
		var panel := SNSkin.panel(String(kind))
		assert_true(panel is StyleBoxTexture, "SNSkin.panel(%s) returns a textured panel" % kind)
		if kind == "glass" and panel is StyleBoxTexture:
			assert_true((panel as StyleBoxTexture).modulate_color.a < 1.0,
				"glass panel lets the 3D stage show through")
	for state in BUTTON_STATES:
		for variant in ["primary", "secondary", "danger", "ghost"]:
			var box := SNSkin.button_style(String(state), String(variant))
			assert_not_null(box, "SNSkin.button_style(%s, %s) returns a StyleBox" % [state, variant])
	assert_true(SNSkin.button_style("normal", "ghost") is StyleBoxEmpty,
		"the ghost button keeps an empty normal state")
	assert_eq(SNSkin.color("brass.base"), _color_from_hex("#C28A3B"), "SNSkin.color() reads the brass token")
	assert_eq(SNSkin.color("text.light"), _color_from_hex("#F0E4C8"), "SNSkin.color() reads the text token")
	assert_eq(SNSkin.font_size("body"), 15, "SNSkin.font_size() reads the body size")
	assert_eq(SNSkin.font_size("no_such_token"), 14, "SNSkin.font_size() falls back to 14")
	var rect := SNSkin.icon_rect("nav_market", 24.0)
	assert_not_null(rect, "SNSkin.icon_rect() builds a TextureRect")
	if rect != null:
		assert_not_null(rect.texture, "the icon rect carries the icon texture")
		assert_eq(rect.custom_minimum_size, Vector2(24.0, 24.0), "the icon rect keeps the requested logical size")
		assert_eq(rect.mouse_filter, Control.MOUSE_FILTER_IGNORE, "icons never eat clicks")
		rect.free()
	SNSkin.clear_cache()
	assert_true(SNSkin.manifest().is_empty() == false, "SNSkin reloads the manifest after clear_cache()")


# ---------------------------------------------------------------------------
# 6. 业务代码守门：不得再手写 StyleBoxFlat / 十六进制业务色
# ---------------------------------------------------------------------------

func test_business_ui_scripts_avoid_flat_styleboxes_and_raw_hex_colors() -> void:
	var flat_offenders: Array[String] = []
	var hex_offenders: Array[String] = []
	var hex_regex := RegEx.create_from_string("#[0-9A-Fa-f]{6}")
	for path in _gd_files("res://framework/ui"):
		var normalized := String(path)
		var source := FileAccess.get_file_as_string(normalized)
		if source.is_empty():
			continue
		if not _is_whitelisted(normalized, STYLEBOX_FLAT_WHITELIST) and source.contains("StyleBoxFlat.new()"):
			var line := _line_of(source, "StyleBoxFlat.new()")
			flat_offenders.append("%s:%d" % [normalized, line])
		if not _is_whitelisted(normalized, HEX_COLOR_WHITELIST):
			var match_result := hex_regex.search(source)
			if match_result != null:
				hex_offenders.append("%s:%d (%s)" % [
					normalized,
					source.substr(0, match_result.get_start()).count("\n") + 1,
					match_result.get_string(0),
				])
	assert_empty(flat_offenders,
		"framework/ui business scripts build no StyleBoxFlat (use Theme/SNSkin textures): %s" % str(flat_offenders))
	assert_empty(hex_offenders,
		"framework/ui business scripts hardcode no hex colours (tokens live in skin.json): %s" % str(hex_offenders))


func _line_of(source: String, needle: String) -> int:
	var index := source.find(needle)
	if index < 0:
		return 0
	return source.substr(0, index).count("\n") + 1
