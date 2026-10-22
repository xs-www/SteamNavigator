extends SceneTree
## @static-doc
## 作用：航行演出（海图系统阶段 3）的**实机演示**：窗口模式下自动开一局、发出真实的
## `voyage.start`，然后让整段演出自己播完（3D 离港 → 云层 → 海图航行 → 事件/入港 →
## 抵达结算），结束后换一个种子重来，方便人工反复观察。不截图、不改存档。
##
## 用法（**必须窗口模式**，`--headless` 下什么都看不见）：
##   godot --path . --resolution 1440x900 --script res://tools/godot/preview_voyage_presentation.gd
##
## 自动跑完限定时间后退出（用于无人值守的自检）：
##   ... --script ... -- --demo-seconds=40
##
## ## 契约与约束
## - 全部走真实命令与真实 Shell：没有预录动画，也不跳过任何演出阶段。
## - 事件停在「等玩家决策」时自动选第一个方案，否则演示会卡住等点击。
## - 单轮看门狗：一轮超过 `CYCLE_TIMEOUT_SECONDS` 还没回港，打印告警并重开，避免
##   一次逻辑卡死让窗口永远停在半路。
## - 关闭窗口即结束（不写存档、不改项目设置）。
## @end-static-doc

const MAIN_SCENE := "res://framework/ui/shell/main.tscn"
const WINDOW := Vector2i(1440, 900)
const STEADY_BUILD := "core:starting_scenario/steady"
const STANDARD_STRATEGY := "core:boiler_strategy/standard"
const SETTLE_SECONDS := 0.8
const CYCLE_GAP_SECONDS := 2.2
const CYCLE_TIMEOUT_SECONDS := 45.0
const SEEDS := [4321, 12345, 6789, 2024]

var _context: AppContext
var _shell: Control
## `-- --demo-seconds=N` limits the demo to N seconds (self-check runs); 0 = run
## until the window is closed.
var _demo_seconds := 0.0
var _demo_deadline_msec := 0


func _init() -> void:
	print("[DEMO] boot")
	_run()


func _process(_delta: float) -> bool:
	# Staying explicit: a SceneTree script that never returns true from `_process`
	# would still run, but this keeps the intent visible and lets the demo exit
	# cleanly if a window is closed.
	return false


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("preview_voyage_presentation: run windowed (drop --headless) to actually see it")
		quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--demo-seconds="):
			_demo_seconds = maxf(0.0, String(argument).trim_prefix("--demo-seconds=").to_float())
	if _demo_seconds > 0.0:
		_demo_deadline_msec = Time.get_ticks_msec() + int(_demo_seconds * 1000.0)
	DisplayServer.window_set_size(WINDOW)
	DisplayServer.window_set_title("Steam Navigator · voyage presentation")
	await process_frame
	_context = _bootstrap()
	if _context == null:
		quit(1)
		return
	var scene: PackedScene = load(MAIN_SCENE)
	_shell = scene.instantiate()
	root.add_child(_shell)
	await _wait(1.2)
	print("[DEMO] shell mounted, starting the loop (close the window to stop)")

	var index := 0
	while true:
		if _demo_seconds > 0.0 and Time.get_ticks_msec() >= _demo_deadline_msec:
			print("[DEMO] demo-seconds elapsed, quitting")
			quit(0)
			return
		var seed_value := int(SEEDS[index % SEEDS.size()])
		index += 1
		await _play_cycle(seed_value)
		await _wait(CYCLE_GAP_SECONDS)


func _play_cycle(seed_value: int) -> void:
	print("[DEMO] cycle seed=%d" % seed_value)
	_context.reset_state()
	_shell._reset_voyage_presentation()
	_shell._settlement_summary = {}
	_shell._active_screen = "overview"
	var started := _context.commands.execute(&"run.start", {"starting_scenario": STEADY_BUILD, "seed": seed_value})
	if not bool(started.get("ok", false)):
		push_error("run.start failed: %s" % str(started))
		return
	_shell._refresh()
	await _wait(SETTLE_SECONDS)
	var destination := _main_destination()
	if destination.is_empty():
		push_error("no main contract destination for seed %d" % seed_value)
		return
	print("[DEMO] departure → %s" % destination)
	_shell._run_command(&"voyage.start", {"destination_id": destination, "strategy_id": STANDARD_STRATEGY})

	var last_phase := ""
	var deadline := Time.get_ticks_msec() + int(CYCLE_TIMEOUT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var phase := _phase()
		if phase != last_phase:
			last_phase = phase
			print("[DEMO] phase: %s" % ("(settled)" if phase.is_empty() else phase))
		# Auto-answer a voyage event so the demo never waits for a click.
		if phase == "event_wait":
			await _answer_event()
			continue
		if phase.is_empty() and String(_shell._active_screen) == "settlement":
			print("[DEMO] arrived · cycle done")
			return
	if last_phase != "":
		push_warning("preview_voyage_presentation: cycle timed out at phase %s" % last_phase)


func _answer_event() -> void:
	var voyage: Variant = _context.state.data.get("voyage", null)
	if not (voyage is Dictionary):
		return
	var event: Variant = (voyage as Dictionary).get("event", null)
	if not (event is Dictionary):
		return
	var option_ids: Array = (event as Dictionary).get("option_ids", [])
	if option_ids.is_empty():
		return
	await _wait(1.4)
	print("[DEMO] event decision → %s" % String(option_ids[0]))
	_shell._run_command(&"event.choose_option", {"option_id": String(option_ids[0])})


func _phase() -> String:
	if _shell._presentation == null:
		return ""
	return String(_shell._presentation.phase_name())


func _main_destination() -> String:
	var main_contract: Variant = _context.state.contracts().get("main", null)
	if main_contract is Dictionary:
		return String((main_contract as Dictionary).get("destination", ""))
	return ""


func _bootstrap() -> AppContext:
	var bootstrap := Bootstrap.new()
	bootstrap.run({
		"scan_roots": PackedStringArray(["res://dev_mods"]),
		"allow_loose": true,
		"mount_packs": false,
		"log_to_console": false,
		"autosave": false,
		"save_directory": "user://preview_saves/voyage_preview",
	})
	var context := bootstrap.context
	if context == null:
		push_error("bootstrap produced no AppContext")
		return null
	AppContext.set_active(context)
	return context


func _wait(seconds: float) -> void:
	await create_timer(maxf(0.0, seconds)).timeout
