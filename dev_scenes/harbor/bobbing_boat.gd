extends Node3D
## 港口浮船：让停泊的船跟随与 harbor_water.gdshader 同源的波浪起伏。
##
## 水面着色器在 vertex() 里用 `swell()` 位移水面；这里用同一套公式采样船只所在
## 位置的波高与坡度，驱动升沉（heave）、纵摇（pitch）与横摇（roll），避免船和
## 水各动各的。改波浪参数时同步修改 assets/shaders/water/harbor_water.gdshader。

## 与着色器 `swell_height` 保持一致（米）。
const SWELL_HEIGHT := 0.14
## 与着色器 `wave_speed` 保持一致（TIME 倍率）。
const WAVE_SPEED := 0.65

@export var heave_gain := 1.0
@export var pitch_gain := 0.75
@export var roll_gain := 0.75
## 系泊余量：极缓慢的横向漂移，让画面不死板（米）。
@export var mooring_drift := 0.08

var _base_position := Vector3.ZERO
var _base_rotation := Vector3.ZERO
var _time := 0.0


func _ready() -> void:
	_base_position = position
	_base_rotation = rotation


func _process(delta: float) -> void:
	_time += delta
	var t := _time * WAVE_SPEED
	var p := Vector2(_base_position.x, _base_position.z)

	# 波高与坡度（world XZ）。
	var height := _swell(p, t) * SWELL_HEIGHT
	var e := 0.8
	var slope_x := (_swell(p + Vector2(e, 0.0), t) - _swell(p - Vector2(e, 0.0), t)) / (2.0 * e) * SWELL_HEIGHT
	var slope_z := (_swell(p + Vector2(0.0, e), t) - _swell(p - Vector2(0.0, e), t)) / (2.0 * e) * SWELL_HEIGHT

	# 船体局部前向（模型 +X）与右舷方向（模型 +Z），只取水平分量。
	var yaw := _base_rotation.y
	var forward := Vector3(cos(yaw), 0.0, -sin(yaw))
	var beam := Vector3(sin(yaw), 0.0, cos(yaw))
	var slope_forward := slope_x * forward.x + slope_z * forward.z
	var slope_beam := slope_x * beam.x + slope_z * beam.z

	var heave := height * heave_gain
	var pitch := atan(slope_forward) * pitch_gain
	var roll := -atan(slope_beam) * roll_gain
	var drift := sin(_time * 0.35) * mooring_drift

	position = _base_position + Vector3(forward.x * drift, heave, forward.z * drift)
	rotation = Vector3(roll, yaw, pitch)


# 与着色器 swell() 相同的三条正弦波叠加，返回约 [-1, 1]。
func _swell(p: Vector2, t: float) -> float:
	var h := sin((p.x * 0.85 + p.y * 0.53) * 0.42 + t * 0.85) * 0.55
	h += sin((p.x * -0.42 + p.y * 0.91) * 0.85 + t * 1.25) * 0.30
	h += sin((p.x * 0.62 + p.y * -0.78) * 1.75 - t * 1.90) * 0.15
	return h
