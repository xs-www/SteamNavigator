class_name SNCloudVeil
extends Control
## @static-doc
## 作用：航行演出的云层转场层（阶段 3）。全屏、不吃鼠标，用程序化云团把画面从
## 3D 港口「盖住」，等界面切到海图后再「散开」；抵达时反向再用一次。
##
## ## 契约与约束
## - **只渲染，不管时序**：`cover`（0 散开 – 1 盖满）由 `VoyagePresentation`
##   逐帧算好推过来，本控件不做缓动、不发信号，因此演出顺序只有一处真源，
##   也方便无头测试直接断言 `cover`。
## - 云团位置在 `_ready` 里用固定种子一次性生成（同一次运行可复现），
##   每帧只按 `cover` 与 `drift` 重排，不重抽随机。
## - `cover <= 0` 时完全不绘制并隐藏，避免在港口页白吃一次全屏 blended 绘制。
## @end-static-doc

## 云层三档深浅：底面水汽、中层云、顶层受光云脊。
const COLOR_BASE := Color(0.55, 0.62, 0.60)
const COLOR_MID := Color(0.78, 0.82, 0.78)
const COLOR_HIGH := Color(0.94, 0.95, 0.90)
const PUFF_COUNT := 64
## 云团随「穿过」动作漂移的幅度（像素）。
const DRIFT_PIXELS := 180.0
## 云团贴图边长（一次生成、重复使用）。圆形渐变贴图让每团云的边缘是软的，
## 直接用 `draw_circle` 会得到一颗颗硬边气泡，不像云。
const PUFF_TEXTURE_SIZE := 128
const SEED := 99352845


var cover: float = 0.0:
	set(value):
		cover = clampf(value, 0.0, 1.0)
		visible = cover > 0.001
		queue_redraw()
## 0..1 的缓慢漂移相位，让盖满时云层仍在流动（由 Shell 每帧推进）。
var drift: float = 0.0

var _puffs: Array[Dictionary] = []
var _puff_texture: ImageTexture = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A bare `Control` added at runtime gets no layout from its parent, so the
	# anchors *and* offsets have to be set explicitly — otherwise the veil stays
	# 0×0 and silently draws nothing while the presentation reports "covered".
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build_puff_texture()
	_build_puffs()


## 每帧推进漂移；`speed` 为每秒相位增量。
func advance(delta: float, speed: float = 0.06) -> void:
	drift = fmod(drift + maxf(0.0, delta) * speed, 1.0)
	if cover > 0.001:
		queue_redraw()


func is_covered() -> bool:
	return cover >= 0.999


func is_clear() -> bool:
	return cover <= 0.001


## 一次性生成一张「白色 + 平滑 alpha 衰减」的圆形贴图，供所有云团复用。
func _build_puff_texture() -> void:
	var side := PUFF_TEXTURE_SIZE
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var center := Vector2(side - 1, side - 1) * 0.5
	var radius := float(side) * 0.5
	for y in side:
		for x in side:
			var dist := Vector2(x, y).distance_to(center) / radius
			var alpha := clampf(1.0 - dist, 0.0, 1.0)
			# smoothstep：中心实、边缘软，叠起来才像云而不是气泡。
			alpha = alpha * alpha * (3.0 - 2.0 * alpha)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_puff_texture = ImageTexture.create_from_image(image)


func _build_puffs() -> void:
	_puffs.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for index in PUFF_COUNT:
		# 三档深度：0 底面 / 1 中层 / 2 顶层。深度决定漂移量与颜色。
		var depth := index % 3
		_puffs.append({
			"x": rng.randf(),
			"y": rng.randf(),
			"radius": lerpf(0.10, 0.34, rng.randf()) * lerpf(1.0, 0.72, float(depth) / 2.0),
			"alpha": lerpf(0.30, 0.62, rng.randf()),
			"depth": depth,
		})


func _draw() -> void:
	if cover <= 0.001 or _puff_texture == null:
		return
	var screen := Rect2(Vector2.ZERO, size)
	# 先铺一层水汽底色，保证 cover=1 时画面不透；中间档位留一点缝，别把画面
	# 一开始就洗成纯色。
	draw_rect(screen, Color(COLOR_BASE.r, COLOR_BASE.g, COLOR_BASE.b, cover * 0.72))
	var diagonal := size.length()
	for puff in _puffs:
		var depth := int(puff["depth"])
		var radius := float(puff["radius"]) * diagonal * 0.5
		# 顶层飘得更快，制造穿云的层次感；cover 越大漂移越明显。
		var drift_px := (drift - 0.5) * DRIFT_PIXELS * (1.0 + float(depth)) * cover
		var position := Vector2(
			float(puff["x"]) * size.x,
			float(puff["y"]) * size.y + drift_px
		)
		var color: Color = [COLOR_BASE, COLOR_MID, COLOR_HIGH][depth]
		var alpha := clampf(float(puff["alpha"]) * (0.35 + 1.1 * cover), 0.0, 0.92)
		draw_texture_rect(
			_puff_texture,
			Rect2(position - Vector2(radius, radius), Vector2(radius, radius) * 2.0),
			false,
			Color(color.r, color.g, color.b, alpha)
		)
