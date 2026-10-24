extends SceneTree
## @static-doc
## 作用：把 `docs/design/` 下的 UI 控件图集与图标图集切成运行纹理，输出到 `assets/ui/skin/<skin>/`，并写 `skin.json`（样式/九宫格/颜色 token/图标表）。这是「外部贴图驱动 UI」的唯一素材入口：页面与 Theme 只引用本脚本产出的 PNG，换同名同尺寸贴图即可整体换肤。
##
## ## 用法
## ```powershell
## godot --headless --path . --script res://tools/ui/build_ui_skin.gd -- [--skin=sn_v1] [--check]
## ```
## - 默认输出 `res://assets/ui/skin/sn_v1/`；`--skin=<id>` 选择输出目录。
## - `--check`：生成到 `user://ui_skin_check/` 并与已提交文件逐字节比对（PNG + skin.json），不覆盖仓库文件；有任何差异退出码 1。改完图集/参数后必须让 `--check` 通过。
##
## ## 输入
## - `docs/design/ui_controls_v1/sn_controls_atlas_v1.png` + `regions.json`（30 个控件区域，源图像素坐标）。
## - `docs/design/ui_icons_v1/icons/<id>.png`（30 个 256×256 透明图标；manifest.json 只用于校验 id 列表）。
## - 颜色/字号 token 内置于本脚本（与 `docs/design/UI_FOUNDATION_SPEC_V1.md` §6/§7 对应），随 skin.json 输出，供 SNSkin 与主题生成器共用。
##
## ## 输出契约
## - `nine_slice/<id>.png`：控件九宫格纹理，源区域 0.5× 缩放；`texture_margin` 为缩放后的九宫格边距，`content_margin` 是安全文字区（逻辑像素）。
## - `parts/<id>.png`：固定比例配件（复选框、滑柄、挂钩、绳环、纸夹、蜡封），不做九宫格。
## - `icons/<id>.png`：128×128 图标（已裁掉透明留白并居中，便于 24/28/32 逻辑像素显示）。
## - 派生件：`fill_rust`（危险填充）、`badge`/`badge_danger`（小铭牌）、`meter_trough`/`meter_fill_*`（仪表用低边距槽/填充）、`scrollbar_track`/`scrollbar_grabber`、`check_*`（复选框 20×20 图标）、`focus_ring`（黄铜焦点描边）。
## - `skin.json`：`id/version/scale/colors/fonts/styles/icons/parts/source`；styles 每项含 `file/texture_margin/content_margin/modulate`，是 Theme 生成器与 SNSkin 的唯一数据源。
##
## ## 约束
## - 生成必须确定性：固定排序、无时间戳、JSON `sort_keys`，同一输入重复运行逐字节一致。
## - 不要手改 `assets/ui/skin/` 下的 PNG / skin.json；改图集或本脚本后重新生成。
## - 源母版留在 `docs/design/`，运行时只用派生副本（与 blueprint_panel 的做法一致）。
## @end-static-doc

const SCALE := 0.5
const DEFAULT_SKIN := "sn_v1"
const SKIN_ROOT := "res://assets/ui/skin/"
const CONTROL_ATLAS_PATH := "res://docs/design/ui_controls_v1/sn_controls_atlas_v1.png"
const CONTROL_REGIONS_PATH := "res://docs/design/ui_controls_v1/regions.json"
const ICON_DIR := "res://docs/design/ui_icons_v1/icons/"
const ICON_MANIFEST_PATH := "res://docs/design/ui_icons_v1/manifest.json"
const CHECK_ROOT := "user://ui_skin_check/"

## 颜色 token，顺序固定（写进 skin.json 供 SNSkin.color() 使用）。
const COLORS := {
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
	"text.ink": "#2A2119",
	"paper.ink_muted": "#5C4A34",
}

const FONT_SIZES := {
	"display": 36,
	"h1": 28,
	"h2": 22,
	"key": 24,
	"body": 15,
	"label": 14,
	"detail": 12,
	"caption": 11,
}

## 控件内容安全区（逻辑像素，缩放后）：texture_margin 由 regions.json 自动取 0.5×。
const CONTENT_MARGINS := {
	"button_normal": [20, 10, 20, 10],
	"button_hover": [20, 10, 20, 10],
	"button_pressed": [20, 10, 20, 10],
	"button_selected": [20, 10, 20, 10],
	"button_disabled": [20, 10, 20, 10],
	"button_danger": [20, 10, 20, 10],
	"panel_steel": [24, 20, 24, 20],
	"panel_recess": [16, 14, 16, 14],
	"panel_parchment": [28, 22, 28, 22],
	"panel_blueprint": [22, 20, 22, 20],
	"panel_canvas": [20, 18, 20, 18],
	"frame_open": [16, 12, 16, 12],
	"input_recess": [20, 10, 20, 10],
	"list_parchment": [20, 10, 20, 10],
	"progress_trough": [0, 0, 0, 0],
	"fill_amber": [0, 0, 0, 0],
	"fill_aqua": [0, 0, 0, 0],
	"fill_sage": [0, 0, 0, 0],
	"flag_teal": [16, 24, 16, 16],
	"flag_blue": [16, 24, 16, 16],
	"flag_cream": [16, 24, 16, 16],
	"flag_red": [16, 24, 16, 16],
	"flag_disabled": [16, 24, 16, 16],
	"flag_selected": [16, 24, 16, 16],
	"checkbox_empty": [0, 0, 0, 0],
	"slider_knob": [0, 0, 0, 0],
	"hook": [0, 0, 0, 0],
	"rope_loop": [0, 0, 0, 0],
	"paper_clip": [0, 0, 0, 0],
	"wax_seal": [0, 0, 0, 0],
}

## 非九宫格的固定配件：不写 texture_margin。
const FIXED_IDS := ["checkbox_empty", "slider_knob", "hook", "rope_loop", "paper_clip", "wax_seal"]

## 派生样式：file 指向派生 PNG；texture_margin/content_margin 手工给定。
const DERIVED_STYLES := {
	"fill_rust": {"file": "nine_slice/fill_rust.png", "texture_margin": [4, 4, 4, 4], "content_margin": [0, 0, 0, 0]},
	"badge": {"file": "nine_slice/badge.png", "texture_margin": [12, 10, 12, 10], "content_margin": [10, 6, 10, 6]},
	"badge_danger": {"file": "nine_slice/badge_danger.png", "texture_margin": [12, 10, 12, 10], "content_margin": [10, 6, 10, 6]},
	"meter_trough": {"file": "nine_slice/meter_trough.png", "texture_margin": [6, 5, 6, 5], "content_margin": [0, 0, 0, 0]},
	"meter_fill_amber": {"file": "nine_slice/meter_fill_amber.png", "texture_margin": [4, 4, 4, 4], "content_margin": [0, 0, 0, 0]},
	"meter_fill_aqua": {"file": "nine_slice/meter_fill_aqua.png", "texture_margin": [4, 4, 4, 4], "content_margin": [0, 0, 0, 0]},
	"meter_fill_sage": {"file": "nine_slice/meter_fill_sage.png", "texture_margin": [4, 4, 4, 4], "content_margin": [0, 0, 0, 0]},
	"meter_fill_rust": {"file": "nine_slice/meter_fill_rust.png", "texture_margin": [4, 4, 4, 4], "content_margin": [0, 0, 0, 0]},
	"scrollbar_track": {"file": "nine_slice/scrollbar_track.png", "texture_margin": [4, 4, 4, 4], "content_margin": [0, 0, 0, 0]},
	"scrollbar_grabber": {"file": "nine_slice/scrollbar_grabber.png", "texture_margin": [4, 4, 4, 4], "content_margin": [0, 0, 0, 0]},
	"cell_recess": {"file": "nine_slice/cell_recess.png", "texture_margin": [6, 5, 6, 5], "content_margin": [8, 2, 8, 2]},
	"focus_ring": {"file": "nine_slice/focus_ring.png", "texture_margin": [16, 16, 16, 16], "content_margin": [0, 0, 0, 0]},
	"plate_small": {"file": "nine_slice/badge.png", "texture_margin": [12, 10, 12, 10], "content_margin": [12, 6, 12, 6]},
}

var _args: Dictionary = {}
var _atlas: Image
var _regions: Dictionary
var _scaled: Dictionary = {}   # id -> Image (0.5x)
var _out_root: String


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var body := arg.substr(2)
			var eq := body.find("=")
			if eq >= 0:
				_args[body.substr(0, eq)] = body.substr(eq + 1)
			else:
				_args[body] = "true"
	var skin := String(_args.get("skin", DEFAULT_SKIN))
	var check := bool(_args.get("check", "false") == "true")
	_out_root = CHECK_ROOT.path_join(skin) if check else SKIN_ROOT.path_join(skin)
	if check:
		_cleanup_dir(_out_root)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_root))
	var ok := _generate()
	if not ok:
		printerr("[build_ui_skin] FAILED")
		quit(1)
		return
	if check:
		var diff := _compare_with_committed(_out_root, SKIN_ROOT.path_join(skin))
		_cleanup_dir(_out_root)
		if diff.is_empty():
			print("[build_ui_skin] check OK (%s)" % skin)
			quit(0)
		else:
			for line in diff:
				printerr(line)
			quit(1)
		return
	print("[build_ui_skin] wrote %s" % _out_root)
	quit(0)


func _generate() -> bool:
	var atlas_path := ProjectSettings.globalize_path(CONTROL_ATLAS_PATH)
	_atlas = Image.load_from_file(atlas_path)
	if _atlas == null or _atlas.is_empty():
		printerr("cannot load control atlas: %s" % atlas_path)
		return false
	_regions = _read_json(CONTROL_REGIONS_PATH)
	if _regions.is_empty():
		printerr("cannot read regions.json")
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_root.path_join("nine_slice")))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_root.path_join("parts")))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_root.path_join("icons")))
	var styles := {}
	for entry in Array(_regions.get("assets", [])):
		var id := String(entry.get("id", ""))
		if id.is_empty():
			continue
		var region := Rect2i(
			int(entry["region"][0]), int(entry["region"][1]),
			int(entry["region"][2]), int(entry["region"][3])
		)
		var img := _atlas.get_region(region)
		if img == null or img.is_empty():
			printerr("empty region for %s" % id)
			return false
		img = _scale_image(img, SCALE)
		_scaled[id] = img
		if id in FIXED_IDS:
			var fixed_file := "parts/%s.png" % id
			_save_png(img, fixed_file)
			styles[id] = {
				"file": fixed_file,
				"fixed": true,
				"size": [img.get_width(), img.get_height()],
			}
			continue
		var file := "nine_slice/%s.png" % id
		_save_png(img, file)
		var margins: Array = entry.get("nine_slice_margins", [])
		var scaled_margins := [0, 0, 0, 0]
		for i in range(min(4, margins.size())):
			scaled_margins[i] = int(round(float(margins[i]) * SCALE))
		styles[id] = {
			"file": file,
			"texture_margin": scaled_margins,
			"content_margin": Array(CONTENT_MARGINS.get(id, [12, 8, 12, 8])),
		}
	# 派生件
	if not _build_derived(styles):
		return false
	# 图标
	var icons := _build_icons()
	if icons.is_empty():
		printerr("no icons generated")
		return false
	var skin := {
		"id": String(_args.get("skin", DEFAULT_SKIN)),
		"version": 1,
		"scale": SCALE,
		"source": {
			"controls_atlas": CONTROL_ATLAS_PATH,
			"controls_regions": CONTROL_REGIONS_PATH,
			"icon_dir": ICON_DIR,
			"icon_manifest": ICON_MANIFEST_PATH,
		},
		"colors": COLORS,
		"fonts": FONT_SIZES,
		"styles": styles,
		"icons": icons,
	}
	_write_json(_out_root.path_join("skin.json"), skin)
	return true


## 从图集切片派生仪表/铭牌/滚动条/复选框等图集未单独提供的状态。
func _build_derived(styles: Dictionary) -> bool:
	# 危险填充：琥珀填充去饱和后染成锈红，保留原 Alpha。
	var amber: Image = _scaled.get("fill_amber")
	if amber == null:
		printerr("missing fill_amber")
		return false
	_save_png(_tint_fill(amber, Color("a84a3e")), "nine_slice/fill_rust.png")
	# 小铭牌：按钮底纹缩小，供 Badge / 侧牌使用。
	var normal: Image = _scaled.get("button_normal")
	var danger: Image = _scaled.get("button_danger")
	if normal == null or danger == null:
		printerr("missing button textures")
		return false
	_save_png(_scale_image(normal, 1.0, 72, 36), "nine_slice/badge.png")
	_save_png(_scale_image(danger, 1.0, 72, 36), "nine_slice/badge_danger.png")
	# 仪表槽/填充：用低边距小尺寸版本，避免 14px 高的资源条被九宫格边距压扁。
	var trough: Image = _scaled.get("progress_trough")
	if trough == null:
		printerr("missing progress_trough")
		return false
	_save_png(_scale_image(_center_crop(trough, 0.6, 0.6), 1.0, 48, 20), "nine_slice/meter_trough.png")
	var fill_ids := {
		"meter_fill_amber": "fill_amber",
		"meter_fill_aqua": "fill_aqua",
		"meter_fill_sage": "fill_sage",
	}
	for out_id in fill_ids:
		var src: Image = _scaled.get(String(fill_ids[out_id]))
		if src == null:
			printerr("missing %s" % fill_ids[out_id])
			return false
		_save_png(_scale_image(_center_crop(src, 0.5, 0.5), 1.0, 24, 12), "nine_slice/%s.png" % out_id)
	_save_png(
		_scale_image(_center_crop(_tint_fill(amber, Color("a84a3e")), 0.5, 0.5), 1.0, 24, 12),
		"nine_slice/meter_fill_rust.png"
	)
	# 滚动条：深槽 + 黄铜滑块。
	var recess: Image = _scaled.get("panel_recess")
	if recess == null:
		printerr("missing panel_recess")
		return false
	_save_png(_scale_image(_center_crop(recess, 0.4, 0.4), 1.0, 16, 16), "nine_slice/scrollbar_track.png")
	_save_png(_scale_image(_center_crop(amber, 0.4, 0.4), 1.0, 16, 16), "nine_slice/scrollbar_grabber.png")
	# 表格单元格：低边距深色凹槽（避免 18–22px 高的格子里出现整块九宫格角件），供
	# 情报/行情等密集表格使用；当前港高亮由调用方 modulate 即可。
	_save_png(_scale_image(_center_crop(recess, 0.35, 0.35), 1.0, 32, 24), "nine_slice/cell_recess.png")
	# 复选框：20×20 图标；选中态在空框上叠确认勾。
	var checkbox: Image = _scaled.get("checkbox_empty")
	var confirm_icon := _load_icon_trimmed("action_confirm")
	if checkbox == null or confirm_icon == null:
		printerr("missing checkbox_empty or action_confirm icon")
		return false
	var empty_20 := _scale_image(checkbox, 1.0, 20, 20)
	_save_png(empty_20, "icons/check_empty.png")
	var checked := empty_20.duplicate() as Image
	var check := _center_on_canvas(_fit_image(confirm_icon, 13), 20, 20)
	checked.blend_rect(check, Rect2i(Vector2i.ZERO, check.get_size()), Vector2i.ZERO)
	_save_png(checked, "icons/check_checked.png")
	_save_png(_desaturate(empty_20), "icons/check_empty_disabled.png")
	_save_png(_desaturate(checked), "icons/check_checked_disabled.png")
	# 焦点描边：64×64 透明中心 + 2px 黄铜圆角边框。
	_save_png(_build_focus_ring(), "nine_slice/focus_ring.png")
	for id in DERIVED_STYLES:
		styles[id] = DERIVED_STYLES[id].duplicate(true)
	return true


## 图标：读独立 PNG，裁掉透明留白后统一放到 128×128 画布中央。
func _build_icons() -> Dictionary:
	var manifest := _read_json(ICON_MANIFEST_PATH)
	var ids: Array = []
	for entry in Array(manifest.get("assets", [])):
		ids.append(String(entry.get("id", "")))
	ids.sort()
	var icons := {}
	for id in ids:
		var trimmed := _load_icon_trimmed(id)
		if trimmed == null:
			printerr("missing icon: %s" % id)
			continue
		var fitted := _fit_image(trimmed, 112)
		var canvas := _center_on_canvas(fitted, 128, 128)
		_save_png(canvas, "icons/%s.png" % id)
		icons[id] = "icons/%s.png" % id
	return icons


func _load_icon_trimmed(id: String) -> Image:
	var path := ProjectSettings.globalize_path(ICON_DIR.path_join("%s.png" % id))
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	return _trim_alpha(img)


# ---------------------------------------------------------------------------
# Image helpers
# ---------------------------------------------------------------------------

func _scale_image(img: Image, factor: float, force_w: int = -1, force_h: int = -1) -> Image:
	var out := img.duplicate() as Image
	var w := force_w if force_w > 0 else maxi(1, int(round(img.get_width() * factor)))
	var h := force_h if force_h > 0 else maxi(1, int(round(img.get_height() * factor)))
	out.resize(w, h, Image.INTERPOLATE_LANCZOS)
	return out


func _center_crop(img: Image, fx: float, fy: float) -> Image:
	var w := maxi(1, int(round(img.get_width() * fx)))
	var h := maxi(1, int(round(img.get_height() * fy)))
	var x := (img.get_width() - w) / 2
	var y := (img.get_height() - h) / 2
	return img.get_region(Rect2i(x, y, w, h))


func _tint_fill(img: Image, tint: Color) -> Image:
	var out := img.duplicate() as Image
	for y in range(out.get_height()):
		for x in range(out.get_width()):
			var c := out.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var luma := c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
			var factor := 0.38 + luma * 0.95
			out.set_pixel(x, y, Color(
				minf(1.0, tint.r * factor),
				minf(1.0, tint.g * factor),
				minf(1.0, tint.b * factor),
				c.a
			))
	return out


func _desaturate(img: Image) -> Image:
	var out := img.duplicate() as Image
	for y in range(out.get_height()):
		for x in range(out.get_width()):
			var c := out.get_pixel(x, y)
			var luma := c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
			var gray := 0.45 + luma * 0.5
			out.set_pixel(x, y, Color(gray * 0.85, gray * 0.88, gray * 0.86, c.a * 0.75))
	return out


func _trim_alpha(img: Image) -> Image:
	var min_x := img.get_width()
	var min_y := img.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.04:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return img
	var pad := 2
	var x0 := maxi(0, min_x - pad)
	var y0 := maxi(0, min_y - pad)
	var x1 := mini(img.get_width() - 1, max_x + pad)
	var y1 := mini(img.get_height() - 1, max_y + pad)
	return img.get_region(Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1))


func _fit_image(img: Image, box: int) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var factor := float(box) / float(maxi(w, h))
	var out := img.duplicate() as Image
	out.resize(maxi(1, int(round(w * factor))), maxi(1, int(round(h * factor))), Image.INTERPOLATE_LANCZOS)
	return out


func _center_on_canvas(img: Image, canvas_w: int, canvas_h: int) -> Image:
	var canvas := Image.create(canvas_w, canvas_h, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var x := (canvas_w - img.get_width()) / 2
	var y := (canvas_h - img.get_height()) / 2
	canvas.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(x, y))
	return canvas


func _build_focus_ring() -> Image:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var half := 28.0
	var radius := 12.0
	var color := Color("edc46d")
	color.a = 0.92
	for y in range(size):
		for x in range(size):
			var px := float(x) + 0.5 - float(size) * 0.5
			var py := float(y) + 0.5 - float(size) * 0.5
			var qx := absf(px) - (half - radius)
			var qy := absf(py) - (half - radius)
			var outside := Vector2(maxf(qx, 0.0), maxf(qy, 0.0)).length()
			var inside_mix := minf(maxf(qx, qy), 0.0)
			var dist := outside + inside_mix - radius
			if absf(dist) <= 1.2:
				img.set_pixel(x, y, color)
	return img


# ---------------------------------------------------------------------------
# IO helpers
# ---------------------------------------------------------------------------

func _save_png(img: Image, rel: String) -> void:
	var path := ProjectSettings.globalize_path(_out_root.path_join(rel))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	if err != OK:
		printerr("save_png failed: %s" % path)


func _read_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed as Dictionary if parsed is Dictionary else {}


func _write_json(path: String, data: Dictionary) -> void:
	var text := JSON.stringify(data, "  ", true)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("cannot write %s" % path)
		return
	file.store_string(text + "\n")
	file.close()


func _cleanup_dir(path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(abs_path):
		return
	var dir := DirAccess.open(abs_path)
	if dir == null:
		return
	for name in dir.get_files():
		dir.remove(name)
	for sub in dir.get_directories():
		_cleanup_dir(path.path_join(sub))


func _compare_with_committed(generated_root: String, committed_root: String) -> Array:
	var diffs: Array = []
	var generated := _collect_files(generated_root)
	var committed := _collect_files(committed_root)
	for rel in committed:
		if not generated.has(rel):
			diffs.append("extra committed file: %s" % rel)
	for rel in generated:
		if not committed.has(rel):
			diffs.append("missing committed file: %s" % rel)
			continue
		var a := FileAccess.get_file_as_bytes(ProjectSettings.globalize_path(generated_root.path_join(rel)))
		var b := FileAccess.get_file_as_bytes(ProjectSettings.globalize_path(committed_root.path_join(rel)))
		if a != b:
			diffs.append("content differs: %s" % rel)
	diffs.sort()
	return diffs


func _collect_files(root: String) -> Array:
	var out: Array = []
	var abs_root := ProjectSettings.globalize_path(root)
	if not DirAccess.dir_exists_absolute(abs_root):
		return out
	var dir := DirAccess.open(abs_root)
	if dir == null:
		return out
	for name in dir.get_files():
		# Godot 导入产出的 sidecar 不参与素材一致性比较。
		if name.ends_with(".import") or name.ends_with(".uid"):
			continue
		out.append(name)
	for sub in dir.get_directories():
		for rel in _collect_files(root.path_join(sub)):
			out.append(sub.path_join(rel))
	return out
