class_name SNSkin
extends RefCounted
## @static-doc
## 作用：UI 皮肤运行时访问层。所有「外部贴图控件」的纹理、九宫格 StyleBox、图标、颜色 token 都从 `assets/ui/skin/<skin>/skin.json` 解析，页面与控件只通过本类取素材，不在代码里写贴图路径或业务色值。
##
## ## 目录契约
## - 默认皮肤：`res://assets/ui/skin/sn_v1/`；可用 ProjectSettings `ui/skin_dir` 指向另一套 skin 目录（文件级换肤）。
## - `skin.json` 由 `tools/build_ui_skin.ps1` 生成：`styles`（file/texture_margin/content_margin）、`icons`、`colors`、`fonts`。
## - 换肤方式：替换 skin 目录内同名同尺寸 PNG（`nine_slice/*`、`icons/*`、`parts/*`）即整体换肤；换九宫格参数或整套新皮肤时重跑生成器并重新导入。
##
## ## 核心 API
## - `skin_dir()` / `manifest()`：当前皮肤目录与解析后的 manifest（空字典表示皮肤缺失，调用方应回退到无纹理样式）。
## - `texture(id)` / `icon(id)` / `decor(id)`：取 Texture2D（带缓存，缺失返回 null）。
## - `style(id)`：按 manifest 构造 StyleBoxTexture；固定配件与未知 id 返回 null。
## - `panel(kind)`：语义面板 steel / recess / parchment / blueprint / canvas / glass / frame_open。
## - `button_style(state, variant)`：state = normal/hover/pressed/disabled/focus，variant = primary/secondary/danger/ghost；Ghost normal 返回 StyleBoxEmpty。
## - `color(token)` / `font_size(token)`：颜色与字号 token；缺失时 push_warning 并回退白色/14。
## - `icon_rect(id, logical_size)`：直接生成 24px 级图标的 TextureRect，供程序化 UI 使用。
##
## ## 约束
## - 不在本类之外硬编码 `res://assets/ui/skin/...` 路径；不在业务脚本写十六进制颜色。
## - StyleBox 是运行时克隆，调用方可安全修改单个实例；缓存以 id 为键，改皮肤后调用 `clear_cache()`。
## - 本类不依赖场景树与渲染，可在 headless 测试中直接使用。
## @end-static-doc

const DEFAULT_SKIN_DIR := "res://assets/ui/skin/sn_v1/"
const MANIFEST_NAME := "skin.json"
const SETTING_SKIN_DIR := "ui/skin_dir"

const PANEL_ALIASES := {
	"steel": "panel_steel",
	"recess": "panel_recess",
	"parchment": "panel_parchment",
	"blueprint": "panel_blueprint",
	"canvas": "panel_canvas",
	"frame_open": "frame_open",
}

static var _manifest: Dictionary = {}
static var _manifest_loaded := false
static var _texture_cache: Dictionary = {}
static var _style_cache: Dictionary = {}
static var _resolved_dir := ""


## 当前皮肤目录（带尾斜杠）。`ui/skin_dir` 可覆盖默认值。
static func skin_dir() -> String:
	if not _resolved_dir.is_empty():
		return _resolved_dir
	var configured := String(ProjectSettings.get_setting(SETTING_SKIN_DIR, DEFAULT_SKIN_DIR))
	if configured.is_empty():
		configured = DEFAULT_SKIN_DIR
	if not configured.ends_with("/"):
		configured += "/"
	_resolved_dir = configured
	return _resolved_dir


## 解析 skin.json；缺失时返回空字典并警告一次。
static func manifest() -> Dictionary:
	if _manifest_loaded:
		return _manifest
	_manifest_loaded = true
	var path := skin_dir().path_join(MANIFEST_NAME)
	if not FileAccess.file_exists(path):
		push_warning("SNSkin: missing manifest %s (UI falls back to texture-less styles)" % path)
		_manifest = {}
		return _manifest
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_manifest = parsed as Dictionary
	else:
		push_warning("SNSkin: invalid manifest %s" % path)
		_manifest = {}
	return _manifest


static func is_available() -> bool:
	return not manifest().is_empty()


static func style_ids() -> Array:
	return manifest().get("styles", {}).keys()


static func icon_ids() -> Array:
	return manifest().get("icons", {}).keys()


## 纹理：先按 style id 找 nine_slice/parts，再按 icon id 找 icons。
static func texture(id: String) -> Texture2D:
	if _texture_cache.has(id):
		return _texture_cache[id] as Texture2D
	var rel := _file_for(id)
	if rel.is_empty():
		_texture_cache[id] = null
		return null
	var tex := _load_texture(rel)
	_texture_cache[id] = tex
	return tex


static func icon(id: String) -> Texture2D:
	var icons: Dictionary = manifest().get("icons", {})
	if not icons.has(id):
		return null
	var cache_key := "icon:" + id
	if _texture_cache.has(cache_key):
		return _texture_cache[cache_key] as Texture2D
	var tex := _load_texture(String(icons[id]))
	_texture_cache[cache_key] = tex
	return tex


static func decor(id: String) -> Texture2D:
	var cache_key := "decor:" + id
	if _texture_cache.has(cache_key):
		return _texture_cache[cache_key] as Texture2D
	var styles: Dictionary = manifest().get("styles", {})
	if not styles.has(id):
		return null
	var tex := _load_texture(String(styles[id].get("file", "")))
	_texture_cache[cache_key] = tex
	return tex


## 按 manifest 构造 StyleBoxTexture；固定配件 / 未知 id 返回 null。
static func style(id: String) -> StyleBoxTexture:
	if _style_cache.has(id):
		var cached: Variant = _style_cache[id]
		return cached as StyleBoxTexture if cached != null else null
	var styles: Dictionary = manifest().get("styles", {})
	if not styles.has(id):
		_style_cache[id] = null
		return null
	var def: Dictionary = styles[id]
	if bool(def.get("fixed", false)):
		_style_cache[id] = null
		return null
	var tex := texture(id)
	if tex == null:
		_style_cache[id] = null
		return null
	var box := StyleBoxTexture.new()
	box.texture = tex
	var margins: Array = def.get("texture_margin", [0, 0, 0, 0])
	box.texture_margin_left = float(margins[0])
	box.texture_margin_top = float(margins[1])
	box.texture_margin_right = float(margins[2])
	box.texture_margin_bottom = float(margins[3])
	var content: Array = def.get("content_margin", [0, 0, 0, 0])
	box.content_margin_left = float(content[0])
	box.content_margin_top = float(content[1])
	box.content_margin_right = float(content[2])
	box.content_margin_bottom = float(content[3])
	var modulate: Array = def.get("modulate", [1, 1, 1, 1])
	box.modulate_color = Color(float(modulate[0]), float(modulate[1]), float(modulate[2]), float(modulate[3]))
	_style_cache[id] = box
	return box


## 语义面板：返回独立克隆，调用方可继续调整。
static func panel(kind: String) -> StyleBoxTexture:
	if kind == "glass":
		var glass := style("panel_steel")
		if glass == null:
			return null
		var clone := glass.duplicate() as StyleBoxTexture
		clone.modulate_color.a = 0.62
		clone.content_margin_left = 14.0
		clone.content_margin_top = 12.0
		clone.content_margin_right = 14.0
		clone.content_margin_bottom = 12.0
		return clone
	if kind == "chrome" or kind == "status_bar":
		# HUD 固定层：半透明钢框 + 低内边距，满足 TopChrome ≤130 / 状态条 60 的预算。
		var hud := style("panel_steel")
		if hud == null:
			return null
		var hud_clone := hud.duplicate() as StyleBoxTexture
		hud_clone.modulate_color.a = 0.84 if kind == "chrome" else 0.9
		var margins := [16.0, 12.0, 16.0, 12.0] if kind == "chrome" else [14.0, 6.0, 14.0, 6.0]
		hud_clone.content_margin_left = margins[0]
		hud_clone.content_margin_top = margins[1]
		hud_clone.content_margin_right = margins[2]
		hud_clone.content_margin_bottom = margins[3]
		return hud_clone
	var style_id := String(PANEL_ALIASES.get(kind, kind))
	var box := style(style_id)
	return box.duplicate() as StyleBoxTexture if box != null else null


## 按钮状态样式；Ghost 的 normal/disabled 返回无底纹的 StyleBoxEmpty，但保留与 hover
## 相同的内容边距（否则 hover 会改变按钮尺寸）。compact 使用小铭牌纹理，适配 30–36px
## 高的导航 / 工具按钮。
static func button_style(state: String, variant: String = "secondary") -> StyleBox:
	var ghost := variant == "ghost"
	var compact := variant == "compact"
	if ghost and (state == "normal" or state == "disabled"):
		return _empty_box(12.0, 4.0)
	if ghost and state == "focus":
		var ghost_focus := style("focus_ring")
		if ghost_focus == null:
			return null
		var ghost_focus_clone := ghost_focus.duplicate() as StyleBoxTexture
		_set_content_margins(ghost_focus_clone, 12.0, 4.0)
		return ghost_focus_clone
	var style_id := ""
	match variant:
		"primary":
			style_id = {"normal": "button_selected", "hover": "button_hover", "pressed": "button_pressed", "disabled": "button_disabled", "focus": "focus_ring"}.get(state, "")
		"danger":
			style_id = {"normal": "button_danger", "hover": "button_danger", "pressed": "button_pressed", "disabled": "button_disabled", "focus": "focus_ring"}.get(state, "")
		"compact":
			style_id = {"normal": "badge", "hover": "button_hover", "pressed": "button_pressed", "disabled": "button_disabled", "focus": "focus_ring"}.get(state, "")
		"ghost":
			style_id = {"hover": "button_normal", "pressed": "button_pressed"}.get(state, "")
		_:
			style_id = {"normal": "button_normal", "hover": "button_hover", "pressed": "button_pressed", "disabled": "button_disabled", "focus": "focus_ring"}.get(state, "")
	if style_id.is_empty():
		return null
	var box := style(style_id)
	if box == null:
		return null
	var clone := box.duplicate() as StyleBoxTexture
	if compact:
		_set_content_margins(clone, 12.0, 4.0)
	if ghost:
		clone.modulate_color.a = 0.45 if state == "hover" else 0.7
		_set_content_margins(clone, 12.0, 4.0)
	if variant == "danger" and state == "hover":
		clone.modulate_color = Color(1.16, 1.08, 1.06, 1.0)
	return clone


static func _empty_box(horizontal: float, vertical: float) -> StyleBoxEmpty:
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = horizontal
	empty.content_margin_top = vertical
	empty.content_margin_right = horizontal
	empty.content_margin_bottom = vertical
	return empty


static func _set_content_margins(box: StyleBox, horizontal: float, vertical: float) -> void:
	box.content_margin_left = horizontal
	box.content_margin_top = vertical
	box.content_margin_right = horizontal
	box.content_margin_bottom = vertical


static func color(token: String) -> Color:
	var colors: Dictionary = manifest().get("colors", {})
	if not colors.has(token):
		push_warning("SNSkin: unknown color token '%s'" % token)
		return Color.WHITE
	return Color(String(colors[token]))


static func font_size(token: String) -> int:
	var fonts: Dictionary = manifest().get("fonts", {})
	if not fonts.has(token):
		push_warning("SNSkin: unknown font token '%s'" % token)
		return 14
	return int(fonts[token])


## 便捷构造：24px 级图标 TextureRect（KEEP_ASPECT_CENTERED，不吃鼠标）。
static func icon_rect(id: String, logical_size: float = 24.0) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = icon(id)
	rect.custom_minimum_size = Vector2(logical_size, logical_size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect


static func clear_cache() -> void:
	_manifest = {}
	_manifest_loaded = false
	_texture_cache.clear()
	_style_cache.clear()
	_resolved_dir = ""


static func _file_for(id: String) -> String:
	var styles: Dictionary = manifest().get("styles", {})
	if styles.has(id):
		return String(styles[id].get("file", ""))
	var icons: Dictionary = manifest().get("icons", {})
	if icons.has(id):
		return String(icons[id])
	return ""


static func _load_texture(rel: String) -> Texture2D:
	if rel.is_empty():
		return null
	var path := skin_dir().path_join(rel)
	if not ResourceLoader.exists(path):
		push_warning("SNSkin: missing texture %s" % path)
		return null
	return load(path) as Texture2D
