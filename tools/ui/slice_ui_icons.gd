extends SceneTree
## @static-doc
## 作用：把 `docs/design/ui_icons_v1/sn_ui_icons_v1.png`（1536×1024 的透明 UI 图标图集）
## 按「真实像素内容」重新切片：先用全透明行/列把图集分成图标格（不用固定等宽/等高网格），
## 再逐格求 alpha 紧包围盒，把每枚图标以原像素尺寸居中放进统一的 256×256 透明画布，
## 写回 `docs/design/ui_icons_v1/icons/<id>.png`，并更新 `manifest.json` 的
## `atlas_region`（精确内容包围盒）、行带与「未映射图标」记录。
##
## ## 为什么不再用固定网格裁切
## 图集是生成式 AI 出图：行高不是整数等分（实际行带 28–219 / 235–411 / 426–620 /
## 625–795 / 810–996），第 3 行还多画了 1 枚图标（7 枚而不是 6 枚）。旧版按 256×256
## 固定方形从行偏移裁切，结果每张独立 PNG 底部都带下一行图标的顶端碎屑，第 3 行还会
## 逐格串进相邻图标。本工具只取当前图标「内容核心」的紧包围盒，不会再串行。
##
## ## 用法
## ```powershell
## godot --headless --path . --script res://tools/ui/slice_ui_icons.gd -- [--dry-run]
## ```
## - 默认写图标与 manifest；`--dry-run` 只打印检测结果，不落盘。
## - 图标顺序/命名取自 `manifest.json` 的 `assets[].id`（行优先）。每行按内容检测到的
##   列块从左到右绑定；多出来的列块（本图集第 3 行的交叉工具）不生成独立文件，但会把
##   包围盒记录到 manifest 的 `unmapped`，方便以后提升为正式图标。
##
## ## 契约
## - 每枚图标输出 256×256 RGBA 画布，内容按原像素尺寸居中（不缩放、不变形、不旋转）。
## - `manifest.json` 仍是 30 个 `assets` + 3 个 `aliases`；`atlas_region` 为 `[x, y, w, h]`。
## - 源图集保持不变；重跑同一输入逐字节一致（固定行/列顺序，无时间戳）。
## - 下游 `tools/ui/build_ui_skin.gd` 会再裁透明留白并缩放居中到 128×128 运行图标，
##   因此「原尺寸居中」不改变运行图标的尺寸基准。
## @end-static-doc

const ATLAS_PATH := "res://docs/design/ui_icons_v1/sn_ui_icons_v1.png"
const ICON_DIR := "res://docs/design/ui_icons_v1/icons/"
const MANIFEST_PATH := "res://docs/design/ui_icons_v1/manifest.json"
const COLUMNS := 6
const ROWS := 5
const CANVAS_SIZE := 256
## 用来判断「实心内容」的 alpha 阈值：过滤图集生成残留的微弱雾状 alpha。
const SOLID_CUT := 64
## 求内容包围盒的 alpha 阈值（含图标外发光/阴影的可见部分）。
const CONTENT_CUT := 24
## 包围盒外扩像素：把图标外发光与抗锯齿边一起带进独立 PNG。
const CONTENT_PAD := 6
## 最后一列没有下一列块时，向右搜索的像素上限。
const EDGE_SEARCH := 24

var _dry_run := false


func _init() -> void:
	_dry_run = "--dry-run" in OS.get_cmdline_user_args()
	quit(_run())


func _run() -> int:
	var image := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
	if image == null or image.is_empty():
		printerr("cannot load atlas: %s" % ATLAS_PATH)
		return 1
	image.convert(Image.FORMAT_RGBA8)
	var manifest := _read_json(MANIFEST_PATH)
	var assets: Array = manifest.get("assets", [])
	if assets.size() != COLUMNS * ROWS:
		printerr("manifest lists %d assets, expected %d" % [assets.size(), COLUMNS * ROWS])
		return 1
	var bands := _row_bands(image)
	if bands.size() != ROWS:
		printerr("detected %d icon rows, expected %d (atlas %dx%d changed?)" % [
			bands.size(), ROWS, image.get_width(), image.get_height(),
		])
		return 1
	var row_bounds := _row_bounds(bands, image.get_height())
	var row_columns: Array = []
	var unmapped: Array = []
	for row in ROWS:
		var columns := _column_bands(image, bands[row])
		row_columns.append(columns.size())
		if columns.size() < COLUMNS:
			printerr("row %d detected %d icon columns, expected at least %d" % [
				row, columns.size(), COLUMNS,
			])
			return 1
		for extra in range(COLUMNS, columns.size()):
			unmapped.append({
				"row": row,
				"column": extra,
				"atlas_region": _rect_to_array(_content_bbox(image, _column_cell(row_bounds[row], columns, extra))),
			})
	if _dry_run:
		return _print_dry_run(image, bands, row_columns, unmapped)
	return _write_icons(image, manifest, assets, bands, row_bounds, row_columns, unmapped)


func _print_dry_run(image: Image, bands: Array, row_columns: Array, unmapped: Array) -> int:
	for row in ROWS:
		var band: Rect2i = bands[row]
		var columns := _column_bands(image, band)
		print("row %d y=%d..%d columns=%d" % [row, band.position.y, band.end.y - 1, int(row_columns[row])])
		for column in COLUMNS:
			var bbox := _content_bbox(image, _column_cell(_row_bounds(bands, image.get_height())[row], columns, column))
			print("  c%d bbox=%s (%dx%d)" % [column, str(bbox), bbox.size.x, bbox.size.y])
	if not unmapped.is_empty():
		print("unmapped icon cells: %s" % str(unmapped))
	return 0


func _write_icons(image: Image, manifest: Dictionary, assets: Array, bands: Array, row_bounds: Array, row_columns: Array, unmapped: Array) -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ICON_DIR))
	for row in ROWS:
		var columns := _column_bands(image, bands[row])
		for column in COLUMNS:
			var index := row * COLUMNS + column
			var entry: Dictionary = assets[index]
			var icon_id := String(entry.get("id", ""))
			var bbox := _content_bbox(image, _column_cell(row_bounds[row], columns, column))
			if bbox.size.x <= 0 or bbox.size.y <= 0:
				printerr("empty icon cell: %s (row %d column %d)" % [icon_id, row, column])
				return 1
			var region := image.get_region(bbox)
			var canvas := Image.create(CANVAS_SIZE, CANVAS_SIZE, false, Image.FORMAT_RGBA8)
			canvas.fill(Color(0.0, 0.0, 0.0, 0.0))
			canvas.blit_rect(region, Rect2i(Vector2i.ZERO, region.get_size()), Vector2i(
				(CANVAS_SIZE - region.get_width()) / 2,
				(CANVAS_SIZE - region.get_height()) / 2
			))
			var error := canvas.save_png(ProjectSettings.globalize_path(ICON_DIR.path_join("%s.png" % icon_id)))
			if error != OK:
				printerr("cannot save icon %s (error=%d)" % [icon_id, error])
				return 1
			entry["atlas_region"] = _rect_to_array(bbox)
			print("[%02d] %-22s bbox=%s (%dx%d)" % [index, icon_id, str(bbox), bbox.size.x, bbox.size.y])
	manifest["atlas_size_px"] = [image.get_width(), image.get_height()]
	manifest["grid"] = {
		"columns": COLUMNS,
		"rows": ROWS,
		"row_bands": _bands_as_arrays(bands),
		"detected_columns_per_row": row_columns,
		"note": "Columns are detected from content, not an equal grid; the extra row-3 icon is recorded under unmapped.",
	}
	manifest["individual_canvas_px"] = [CANVAS_SIZE, CANVAS_SIZE]
	manifest["slicer"] = "tools/ui/slice_ui_icons.gd"
	manifest["unmapped"] = unmapped
	var write_error := _write_json(MANIFEST_PATH, manifest)
	if write_error != OK:
		printerr("cannot write manifest (error=%d)" % write_error)
		return 1
	print("sliced %d icons into %s (canvas %dx%d, unmapped %d)" % [
		assets.size(), ICON_DIR, CANVAS_SIZE, CANVAS_SIZE, unmapped.size(),
	])
	return 0


## 行带：所有像素 alpha 均低于 SOLID_CUT 的「全透明行」就是行间空隙；由此把图集切成 5 行。
func _row_bands(image: Image) -> Array:
	var data := image.get_data()
	var width := image.get_width()
	var height := image.get_height()
	var counts := PackedInt32Array()
	counts.resize(height)
	for y in height:
		var base := y * width * 4
		var count := 0
		for x in width:
			if data[base + x * 4 + 3] > SOLID_CUT:
				count += 1
		counts[y] = count
	var bands: Array = []
	var start := -1
	for y in height:
		if counts[y] > 0:
			if start < 0:
				start = y
		elif start >= 0:
			bands.append(Rect2i(0, start, width, y - start))
			start = -1
	if start >= 0:
		bands.append(Rect2i(0, start, width, height - start))
	return bands


## 行带内的列块：行带内该列所有像素 alpha 都低于 SOLID_CUT 就是列间空隙。
func _column_bands(image: Image, band: Rect2i) -> Array:
	var data := image.get_data()
	var width := image.get_width()
	var counts := PackedInt32Array()
	counts.resize(width)
	for x in width:
		var count := 0
		for y in range(band.position.y, band.end.y):
			if data[(y * width + x) * 4 + 3] > SOLID_CUT:
				count += 1
		counts[x] = count
	var bands: Array = []
	var start := -1
	for x in width:
		if counts[x] > 0:
			if start < 0:
				start = x
		elif start >= 0:
			bands.append(Vector2i(start, x - 1))
			start = -1
	if start >= 0:
		bands.append(Vector2i(start, width - 1))
	return bands


## 每行的搜索上下界：取相邻行带之间空隙的中点，避免把上一行/下一行的残留像素带进来。
func _row_bounds(bands: Array, height: int) -> Array:
	var bounds: Array = []
	for row in bands.size():
		var band: Rect2i = bands[row]
		var top: int = 0 if row == 0 else int((bands[row - 1].end.y - 1 + band.position.y) / 2)
		var bottom: int = height - 1 if row == bands.size() - 1 else int((band.end.y - 1 + bands[row + 1].position.y) / 2)
		bounds.append(Vector2i(top, bottom))
	return bounds


## 第 column 列图标的搜索格：左右边界取相邻列块之间空隙的中点，避免串到相邻图标。
func _column_cell(row_bound: Vector2i, columns: Array, column: int) -> Rect2i:
	var current: Vector2i = columns[column]
	var left: int = 0 if column == 0 else int((columns[column - 1].y + current.x) / 2)
	var right: int = int((current.y + columns[column + 1].x) / 2) \
		if column + 1 < columns.size() else current.y + EDGE_SEARCH
	var rect := Rect2i(
		left, row_bound.x,
		maxi(1, right - left + 1), maxi(1, row_bound.y - row_bound.x + 1)
	)
	return rect


## 搜索格内 alpha > CONTENT_CUT 的紧包围盒，再外扩 CONTENT_PAD（图标外发光/抗锯齿）。
func _content_bbox(image: Image, rect: Rect2i) -> Rect2i:
	var data := image.get_data()
	var width := image.get_width()
	var height := image.get_height()
	var min_x := 1 << 30
	var min_y := 1 << 30
	var max_x := -1
	var max_y := -1
	for y in range(maxi(0, rect.position.y), mini(height, rect.end.y)):
		var base := y * width * 4
		for x in range(maxi(0, rect.position.x), mini(width, rect.end.x)):
			if data[base + x * 4 + 3] > CONTENT_CUT:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	var padded := Rect2i(
		maxi(0, min_x - CONTENT_PAD),
		maxi(0, min_y - CONTENT_PAD),
		mini(width - 1, max_x + CONTENT_PAD) - maxi(0, min_x - CONTENT_PAD) + 1,
		mini(height - 1, max_y + CONTENT_PAD) - maxi(0, min_y - CONTENT_PAD) + 1
	)
	return padded


func _rect_to_array(rect: Rect2i) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _bands_as_arrays(bands: Array) -> Array:
	var result: Array = []
	for band in bands:
		var rect: Rect2i = band
		result.append([rect.position.y, rect.end.y - 1])
	return result


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _write_json(path: String, data: Dictionary) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "  ", false) + "\n")
	file.close()
	return OK
