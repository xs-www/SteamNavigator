class_name VoyagePresentation
extends RefCounted
## @static-doc
## 作用：航行演出（海图系统阶段 3）的**纯状态机**：把一次已经由 `voyage.start`
## 结算的航行，在界面上依次演成「出航云层 → 海图航行（时间加速）→ 事件中断 →
## 抵达云层」。它不碰 `GameState`、不碰节点树，只输出阶段、进度和里程碑，
## 因此可以在无头测试里逐帧推进。
##
## ## 契约与约束
## - **只做表现，不改规则**：航行结果（是否抵达、事件、结算）由 `VoyageService`
##   决定；本类只决定「什么时候把哪个画面推到玩家面前」。领域数值一行不改。
## - **阶段不可跳跃**：`plan()` → `begin_departure()` → 云层盖满后自动进 `AT_SEA`
##   → 事件点/终点各自先盖云层再交界面。所有转移集中在本类，Shell 只按 `Step`
##   换页，避免演出顺序散落在 UI 里。
## - **时间加速可解释**：整段航程压缩成 `MIN_PLAYBACK_SECONDS..MAX_PLAYBACK_SECONDS`
##   的实时时长，`hours_per_second` 就是界面上要显示的倍率；游戏时间本身不加速，
##   它已经由 `voyage.start` 一次性推进。
## - **跳过不等于替玩家做决定**：`skip()` 只跳过航行过程；未处理的事件仍然会被
##   推到玩家面前（决策不能替玩家做）。
## @end-static-doc

## 演出阶段。名字与设计文档 §8.1 的状态机对应；与 3D 有关的两个额外阶段是
## `DEPARTURE_3D`（船驶离港口 + 镜头上升）与 `ARRIVAL_HARBOR`（下降入港），
## 它们存在的原因见 §8.2：镜头要在 3D 里先动起来，云层只是「盖上/掀开」的接缝。
enum Phase {
	IN_PORT,
	VOYAGE_PLANNED,
	## 3D 离港：船从泊位驶向海门，镜头升到高位（云层未盖）。
	DEPARTURE_3D,
	## 云层盖住高位镜头，盖满后切到海图。
	DEPARTURE_VEIL,
	AT_SEA,
	EVENT_APPROACH,
	EVENT_WAIT,
	EVENT_RESUME,
	## 云层盖住海图，盖满后切到目的港 3D 场景。
	ARRIVAL_APPROACH,
	## 3D 入港：镜头从高位下降回站位机位，船从海门驶入泊位（云层同时散开）。
	ARRIVAL_HARBOR,
	DONE,
}

## `tick()` 的里程碑：Shell 只在拿到这些值时才换页。
enum Step {
	NONE,
	## 3D 离港动作演完，可以开始盖云层了。
	DEPARTED,
	## 出航云层盖满、可以换成海图航行页了。
	AT_SEA_STARTED,
	## 事件云层盖满、可以把事件选项推给玩家了。
	EVENT_READY,
	## 抵达云层盖满、可以换上目的港的 3D 入港场景了。
	ARRIVAL_READY,
	## 入港动作演完、云层散尽，Shell 可以换成抵达结算页并丢弃本对象。
	DONE,
}

## 1 游戏小时压缩成多少实时秒；再被上下限夹一次。
const SECONDS_PER_GAME_HOUR := 0.35
const MIN_PLAYBACK_SECONDS := 2.0
const MAX_PLAYBACK_SECONDS := 9.0
## 云层盖满/散开各用多久（实时秒）。
const VEIL_SECONDS := 0.7
## 3D 离港 / 入港动作的时长。必须与 `PortStage.VOYAGE_BEAT_SECONDS` 一致：
## 状态机与 3D 动画在同一帧开始、同一帧结束，云层才不会在镜头还在动时就盖下。
const DEPARTURE_3D_SECONDS := 1.8
const HARBOR_SECONDS := 1.8
## 没有真实路径数据时的兜底航程时长（小时），避免演出瞬间播完。
const FALLBACK_HOURS := 8.0
## 事件默认落在航程的这个比例处（设计文档 §8.1：事件发生在途中）。
const DEFAULT_EVENT_PROGRESS := 0.5

var phase: Phase = Phase.IN_PORT
var progress: float = 0.0
## 0 = 云层散开，1 = 云层盖满。
var veil: float = 0.0
## -1 上升穿越（离港），1 下降穿越（入港/事件）；只影响云层绘制方向。
var veil_direction: float = 1.0
var total_hours: float = 0.0
var playback_seconds: float = MIN_PLAYBACK_SECONDS
var elapsed_seconds: float = 0.0
var has_event: bool = false
var event_progress: float = DEFAULT_EVENT_PROGRESS
var event_fired: bool = false
## 海图船只图标在「刚接管画面」时的航程比例。3D 船停在 `SEA_HANDOFF` 那一刻
## 对应的海图位置就是它——默认 0，即出发港的港口图标：3D 船是从这个港口驶出去
## 的，海图上的船也必须从同一处出现，接缝才不跳。
var handoff_progress: float = 0.0
var departure_3d_seconds: float = DEPARTURE_3D_SECONDS
var harbor_seconds: float = HARBOR_SECONDS

var _beat_seconds: float = 0.0
var _veil_from: float = 0.0
var _veil_to: float = 0.0
var _veil_elapsed: float = 0.0
var _veil_seconds: float = VEIL_SECONDS


## 进入「已规划」阶段：`hours` 是 `voyage.arrival_time - departure_time`，
## `event_at` 为事件在航程中的比例（<0 表示本次航行没有事件）。
func plan(hours: float, event_at: float = -1.0) -> void:
	total_hours = maxf(0.0, hours)
	has_event = event_at >= 0.0
	event_progress = clampf(event_at, 0.05, 0.95) if has_event else -1.0
	playback_seconds = clampf(
		maxf(total_hours, 0.0) * SECONDS_PER_GAME_HOUR,
		MIN_PLAYBACK_SECONDS,
		MAX_PLAYBACK_SECONDS
	)
	progress = 0.0
	elapsed_seconds = 0.0
	event_fired = false
	_beat_seconds = 0.0
	handoff_progress = 0.0
	veil = 0.0
	_veil_from = 0.0
	_veil_to = 0.0
	_veil_elapsed = 0.0
	phase = Phase.VOYAGE_PLANNED


## 「确认出航」：先在 3D 里把船开出去、镜头升起来，再盖云层进海图。
func begin_departure() -> void:
	if phase != Phase.VOYAGE_PLANNED:
		return
	phase = Phase.DEPARTURE_3D
	veil_direction = -1.0
	_beat_seconds = 0.0
	veil = 0.0
	_veil_from = 0.0
	_veil_to = 0.0
	_veil_elapsed = 0.0


## 3D 离港动作结束（由 Shell 在拿到 `DEPARTED` 后无需再调，保留给工具/测试
## 强制推进一个 beat）。正常流程由 `tick()` 计时自动调用。
func finish_departure_beat() -> void:
	if phase != Phase.DEPARTURE_3D:
		return
	_beat_seconds = departure_3d_seconds


## 目的港的 3D 舞台没挂上（场景缺失 / 回退 2D）时用它跳过入港 beat，避免
## 演出为了一个看不见的动画空等 1.8 s。
func skip_harbor_beat() -> void:
	if phase != Phase.ARRIVAL_HARBOR:
		return
	_beat_seconds = harbor_seconds
	veil = 0.0


## 玩家处理完事件：先重新盖上云层（避免事件页被硬切回海图），盖满后回海图继续航行。
func resolve_event() -> void:
	if phase != Phase.EVENT_WAIT:
		return
	phase = Phase.EVENT_RESUME
	veil_direction = -1.0
	_start_veil(1.0)


## 事件页已经推给玩家：云层散开，让事件场景露出来（阶段仍停在 EVENT_WAIT 等选择）。
func begin_event_reveal() -> void:
	if phase != Phase.EVENT_WAIT:
		return
	_start_veil(0.0)


## 推进演出。`delta` 是实时秒。返回本次推进跨过的里程碑。
func tick(delta: float) -> Step:
	var step := maxf(0.0, delta)
	match phase:
		Phase.DEPARTURE_3D:
			# 3D 离港：船驶离 + 镜头上升。云层此时还没出现，玩家看得到船离开。
			_beat_seconds += step
			if _beat_seconds >= departure_3d_seconds:
				phase = Phase.DEPARTURE_VEIL
				veil_direction = -1.0
				_start_veil(1.0)
				return Step.DEPARTED
			return Step.NONE
		Phase.ARRIVAL_HARBOR:
			# 3D 入港：云层同时散开，镜头下降、船驶入泊位；动作与云层都完成才算结束。
			_advance_veil(step)
			_beat_seconds += step
			if _beat_seconds >= harbor_seconds and veil <= 0.0001:
				phase = Phase.DONE
				return Step.DONE
			return Step.NONE
		Phase.DEPARTURE_VEIL, Phase.EVENT_APPROACH, Phase.EVENT_RESUME, Phase.ARRIVAL_APPROACH:
			_advance_veil(step)
			# 到达目标值就结算——包括「本来就在目标值」：事件页的云层还没散开玩家
			# 就选了方案时，云层已盖满，这里必须立刻交还画面而不是再等 0.7 s。
			if not is_equal_approx(veil, _veil_to):
				return Step.NONE
			return _on_veil_settled()
		Phase.AT_SEA:
			_advance_veil(step)
			# 云层还在散开时先别让船只动，否则前 0.7 s 的航程被云挡着白跑。
			if veil > 0.0001:
				return Step.NONE
			return _advance_voyage(step)
		Phase.EVENT_WAIT:
			# 等玩家选方案，但云层仍要散开，事件页才会露出来。
			_advance_veil(step)
			return Step.NONE
		_:
			return Step.NONE


## 跳过航行过程。未处理的事件仍然会推给玩家（决策不代打）。
func skip() -> Step:
	match phase:
		Phase.AT_SEA:
			if has_event and not event_fired:
				return _reach_event()
			return _reach_arrival()
		Phase.DEPARTURE_3D:
			# 跳过 3D 离港动作：下一次 tick 立刻盖云层进海图。
			_beat_seconds = departure_3d_seconds
			return Step.NONE
		Phase.ARRIVAL_HARBOR:
			_beat_seconds = harbor_seconds
			veil = 0.0
			return Step.NONE
		Phase.DEPARTURE_VEIL, Phase.EVENT_APPROACH, Phase.EVENT_RESUME, Phase.ARRIVAL_APPROACH:
			# 云层动画中按跳过：直接把云层推到目标值，下一次 tick 结算。
			_veil_elapsed = _veil_seconds
			veil = _veil_to
			return Step.NONE
		Phase.EVENT_WAIT:
			# 等玩家选方案，不能跳过。
			return Step.NONE
		_:
			return Step.NONE


func is_active() -> bool:
	return phase != Phase.IN_PORT and phase != Phase.DONE


## 游戏内已经走过的航程小时数（界面时钟显示用）。
func elapsed_hours() -> float:
	return total_hours * progress


## 剩余小时数。
func remaining_hours() -> float:
	return maxf(0.0, total_hours - elapsed_hours())


## 界面上的时间倍率：1 实时秒 = 多少游戏小时。
func hours_per_second() -> float:
	if playback_seconds <= 0.0001:
		return 0.0
	return total_hours / playback_seconds


func is_veiled() -> bool:
	return veil >= 1.0 - 0.0001


func phase_name() -> String:
	return Phase.keys()[phase].to_lower()


## 只读快照，供 ViewModel 使用（可直接 JSON 化）。
func snapshot() -> Dictionary:
	return {
		"phase": phase_name(),
		"progress": progress,
		"veil": veil,
		"veil_direction": veil_direction,
		"total_hours": total_hours,
		"elapsed_hours": elapsed_hours(),
		"remaining_hours": remaining_hours(),
		"hours_per_second": hours_per_second(),
		"has_event": has_event,
		"event_fired": event_fired,
		"handoff_progress": handoff_progress,
	}


## 按**弧长**在折线上取点：`t=0` 是起点、`t=1` 是终点。行进的船只 icon 用它，
## 这样曲线密集段不会走得比稀疏段慢（按下标插值就会）。
static func sample_polyline(points: PackedVector2Array, t: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	if points.size() == 1:
		return points[0]
	var target := clampf(t, 0.0, 1.0) * polyline_length(points)
	var walked := 0.0
	for index in range(1, points.size()):
		var segment := points[index - 1].distance_to(points[index])
		if walked + segment >= target:
			if segment <= 0.0001:
				return points[index]
			var local := (target - walked) / segment
			return points[index - 1].lerp(points[index], local)
		walked += segment
	return points[points.size() - 1]


static func polyline_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for index in range(1, points.size()):
		total += points[index - 1].distance_to(points[index])
	return total


## 把海图查询里 `bezier_path` 的扁平数组（`[x0,y0,x1,y1,…]`）还原成点列。
static func unpack_path(flat: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	var index := 0
	while index + 1 < flat.size():
		points.append(Vector2(float(flat[index]), float(flat[index + 1])))
		index += 2
	return points


func _start_veil(target: float) -> void:
	_veil_from = veil
	_veil_to = target
	_veil_elapsed = 0.0
	_veil_seconds = VEIL_SECONDS


## 把云层朝目标值推进；是否到达由 `tick()` 用 `is_equal_approx(veil, _veil_to)` 判断。
func _advance_veil(delta: float) -> void:
	if is_equal_approx(veil, _veil_to):
		return
	_veil_elapsed += maxf(0.0, delta)
	var ratio := clampf(_veil_elapsed / maxf(0.0001, _veil_seconds), 0.0, 1.0)
	veil = lerpf(_veil_from, _veil_to, ratio)
	if ratio >= 1.0:
		veil = _veil_to


func _on_veil_settled() -> Step:
	match phase:
		Phase.DEPARTURE_VEIL:
			if is_veiled():
				# 高位离港镜头已被云层盖满：切成海图，云层同时开始散开。
				phase = Phase.AT_SEA
				_start_veil(0.0)
				return Step.AT_SEA_STARTED
		Phase.EVENT_APPROACH:
			if is_veiled():
				phase = Phase.EVENT_WAIT
				return Step.EVENT_READY
		Phase.EVENT_RESUME:
			if is_veiled():
				# 事件处理完、云层重新盖满：可以换回海图页继续航行了。
				phase = Phase.AT_SEA
				_start_veil(0.0)
				return Step.AT_SEA_STARTED
		Phase.ARRIVAL_APPROACH:
			if is_veiled():
				# 海图已被云层盖满：换成目的港的 3D 入港场景（镜头在高位），
				# 云层同时开始散开，露出「从海上进港」的画面。
				phase = Phase.ARRIVAL_HARBOR
				_beat_seconds = 0.0
				_start_veil(0.0)
				return Step.ARRIVAL_READY
		_:
			pass
	return Step.NONE


func _advance_voyage(delta: float) -> Step:
	elapsed_seconds += maxf(0.0, delta)
	progress = clampf(elapsed_seconds / maxf(0.0001, playback_seconds), 0.0, 1.0)
	if has_event and not event_fired and progress >= event_progress:
		return _reach_event()
	if progress >= 1.0:
		return _reach_arrival()
	return Step.NONE


func _reach_event() -> Step:
	event_fired = true
	progress = event_progress
	phase = Phase.EVENT_APPROACH
	veil_direction = 1.0
	_start_veil(1.0)
	return Step.NONE


func _reach_arrival() -> Step:
	progress = 1.0
	phase = Phase.ARRIVAL_APPROACH
	veil_direction = 1.0
	_start_veil(1.0)
	return Step.NONE
