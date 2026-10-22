class_name SimulationService
extends RefCounted
## @static-doc
## 作用：最小确定性 tick / 模拟框架（Phase D0）。以 1 游戏小时为固定步长推进
## `data.sim`（`{paused, speed, tick}` 惰性状态），按 TickScheduler 的
## priority + id 顺序调用已注册系统，并为每个 tick 生成 `sim.tick` 领域事件。
##
## 关键依赖：`GameState.advance_time`、`ClockService.format_time`、`TickScheduler`
##
## ## 契约与约束
## - `ensure_state()` 惰性创建 / 修复 `data.sim`；旧档没有该块时按默认值补齐，
##   不写存档迁移、不触碰 `port.wait` / 航行时间语义（D0 不接 gameplay）。
## - 固定步长 `TICK_HOURS = 1.0`；`advance()` 先把真实小时数乘以 `speed`，再按
##   **整 tick** 推进（不足 1 小时的部分直接丢弃，不做跨调用累计）。
## - 暂停（`paused=true`）时不推进时间、不调用系统、不发事件；暂停状态下
##   `advance()` 返回 `ticks = 0`。
## - 每 tick 依次：`tick += 1` → `advance_time(TICK_HOURS)` → TickScheduler.run(...)
##   → 生成 `{type: "sim.tick", payload: {tick, game_time, step_hours}}`；命令层把
##   这些事件交给 CommandBus 发布（服务本身不发事件）。
## - `view()` 只读，不创建 / 不修改 `data.sim`；无 run 或旧档返回默认值。
## @end-static-doc

const SIM_KEY := "sim"
const TICK_HOURS := 1.0
const DEFAULT_SPEED := 1.0
const MIN_SPEED := 0.25
const MAX_SPEED := 8.0
const MAX_ADVANCE_HOURS := 720.0
const DEFAULT_STATE := {
	"paused": false,
	"speed": DEFAULT_SPEED,
	"tick": 0,
}


## Lazily creates/repairs `data.sim` and returns the live dictionary.
static func ensure_state(state: GameState) -> Dictionary:
	if state == null:
		return DEFAULT_STATE.duplicate(true)
	var current: Variant = state.data.get(SIM_KEY, null)
	if not (current is Dictionary):
		current = DEFAULT_STATE.duplicate(true)
		state.data[SIM_KEY] = current
	var sim: Dictionary = current
	for key in DEFAULT_STATE.keys():
		if not sim.has(key):
			sim[key] = DEFAULT_STATE[key]
	sim["paused"] = bool(sim.get("paused", false))
	var speed_value := float(sim.get("speed", DEFAULT_SPEED))
	if not is_finite(speed_value) or speed_value <= 0.0:
		speed_value = DEFAULT_SPEED
	sim["speed"] = clampf(speed_value, MIN_SPEED, MAX_SPEED)
	sim["tick"] = maxi(0, int(sim.get("tick", 0)))
	return sim


static func pause(state: GameState) -> Dictionary:
	var sim := ensure_state(state)
	sim["paused"] = true
	return sim


static func resume(state: GameState) -> Dictionary:
	var sim := ensure_state(state)
	sim["paused"] = false
	return sim


## Sets the speed multiplier; returns `{}` for non-finite / out-of-range values.
static func set_speed(state: GameState, speed: float) -> Dictionary:
	if not is_valid_speed(speed):
		return {}
	var sim := ensure_state(state)
	sim["speed"] = speed
	return sim


## Advances `hours` real hours at the current speed, one fixed tick at a time.
## Returns `{ticks, hours_requested, hours_advanced, paused, speed, tick,
## start_tick, end_tick, game_time, time_label, events}`.
static func advance(state: GameState, hours: float, context = null) -> Dictionary:
	var sim := ensure_state(state)
	var requested := maxf(0.0, hours)
	var start_tick := int(sim["tick"])
	var events: Array = []
	var ticks := 0
	if not bool(sim["paused"]):
		var scaled := requested * float(sim["speed"])
		ticks = int(floor(scaled + 0.0000001))
		for _index in ticks:
			sim["tick"] = int(sim["tick"]) + 1
			var tick := int(sim["tick"])
			state.advance_time(TICK_HOURS)
			TickScheduler.run(state, tick, context)
			events.append({
				"type": "sim.tick",
				"payload": {
					"tick": tick,
					"game_time": state.now(),
					"step_hours": TICK_HOURS,
				},
			})
	return {
		"ticks": ticks,
		"hours_requested": requested,
		"hours_advanced": float(ticks) * TICK_HOURS,
		"paused": bool(sim["paused"]),
		"speed": float(sim["speed"]),
		"tick": int(sim["tick"]),
		"start_tick": start_tick,
		"end_tick": int(sim["tick"]),
		"game_time": state.now(),
		"time_label": ClockService.format_time(state.now()),
		"events": events,
	}


## Read-only snapshot for `sim.view`. Never mutates the state, so old saves keep
## their missing `data.sim` block until a sim command (or explicit ensure) runs.
static func view(state: GameState) -> Dictionary:
	var sim: Dictionary = DEFAULT_STATE.duplicate(true)
	if state != null and state.data.get(SIM_KEY, null) is Dictionary:
		sim = (state.data[SIM_KEY] as Dictionary).duplicate(true)
	for key in DEFAULT_STATE.keys():
		if not sim.has(key):
			sim[key] = DEFAULT_STATE[key]
	var speed_value := float(sim.get("speed", DEFAULT_SPEED))
	if not is_finite(speed_value) or speed_value <= 0.0:
		speed_value = DEFAULT_SPEED
	speed_value = clampf(speed_value, MIN_SPEED, MAX_SPEED)
	var paused := bool(sim.get("paused", false))
	var tick := maxi(0, int(sim.get("tick", 0)))
	var game_time := 0.0
	if state != null:
		game_time = state.now()
	return {
		"paused": paused,
		"speed": speed_value,
		"tick": tick,
		"step_hours": TICK_HOURS,
		"game_time": game_time,
		"time_label": ClockService.format_time(game_time),
		"systems": TickScheduler.systems(),
	}


static func is_valid_speed(speed: float) -> bool:
	return is_finite(speed) and speed >= MIN_SPEED and speed <= MAX_SPEED


static func is_valid_advance_hours(hours: float) -> bool:
	return is_finite(hours) and hours > 0.0 and hours <= MAX_ADVANCE_HOURS
