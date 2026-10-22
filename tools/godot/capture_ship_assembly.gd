## @static-doc
## 作用：`ShipVisualAssembler` 的实机截图工具（窗口化 1440×900）：用真实 Core 内容解析 4 艘船的视觉装配计划，在真实 `ShipyardStage` / `PortStage` 场景里逐张抓图（船厂 4 艘 + 装配近景 + 港口停泊 + 航行离港 + 航行入港），每张都自检 hull / rig / 武器装配数量后才写盘。
##
## - 关键依赖：`Bootstrap`（真实 Core 内容）、`ShipVisualPlan`（计划解析，不在工具里写死物理路径）、`ShipyardStage` / `PortStage`（游戏内真实舞台）
##
## ## 契约与约束
## - 必须窗口化运行（headless 下 viewport 纹理为空），固定 1440×900；`--resolution` 与脚本内 `window_set_size` 同时设置。
## - 船体 / 套件 / 武器路径全部由 `ShipVisualPlan.resolve()` 从 Core manifest + `hulls.json.rig_plan` 解析，截图即验证「内容驱动的装配」而不是硬编码资产。
## - 每张截图前断言：`stage.has_ship()`、rig 报告 `mode` 与 `mounted` 数量、武器 `mounted` 数量符合预期；不满足则 `[FAIL]` 且不提交半套图。
## - 截图先写 `res://tmp_*`，全部成功后才移入 `docs/design/screenshots/ship_assembly/`；任何失败退出码 1 并清理临时文件。
## - 航行演出用 `begin_departure()` / `begin_arrival()` + `advance_voyage(delta)` 手动步进到固定进度，不依赖帧率。
## @end-static-doc

extends SceneTree

const SHIPYARD_STAGE_SCENE := "res://framework/ui/stages/shipyard_stage.tscn"
const PORT_STAGE_SCENE := "res://framework/ui/stages/port_stage.tscn"
const OUT_DIR := "res://docs/design/screenshots/ship_assembly"
const WINDOW := Vector2i(1440, 900)
const SETTLE_FRAMES := 30
const SETTLE_SECONDS := 0.6
const VOYAGE_BEAT_SECONDS := 3.2
const DEPARTURE_CAPTURE_PROGRESS := 0.42
const ARRIVAL_CAPTURE_PROGRESS := 0.70
const WATCHDOG_SECONDS := 240.0
const TMP_PREFIX := "res://tmp_ship_assembly_"

const FREIGHTER_LOADOUT := [
	{"socket": "SN_Socket_Weapon_Port_1", "asset": "model.weapon.broadside"},
	{"socket": "SN_Socket_Weapon_Starboard_1", "asset": "model.weapon.broadside"},
	{"socket": "SN_Socket_Weapon_Port_2", "asset": "model.weapon.deck_gun"},
	{"socket": "SN_Socket_Weapon_Starboard_2", "asset": "model.weapon.deck_gun"},
]

## The four playable hulls, assembled from content: rig plan + a preview loadout
## (weapons have no gameplay content type yet, so the capture injects a
## deterministic preview loadout to exercise the weapon sockets).
const SHIPS := [
	{
		"key": "steamer",
		"hull_id": "core:hull/small_efficient",
		"tier": 1,
		"rig_mode": "baked",
		"rig_parts": 0,
		"weapons": 3,
		"loadout": [
			{"socket": "SN_Socket_Weapon_Port_1", "asset": "model.weapon.deck_gun"},
			{"socket": "SN_Socket_Weapon_Starboard_1", "asset": "model.weapon.deck_gun"},
			{"socket": "SN_Socket_Weapon_Stern", "asset": "model.weapon.repeater"},
		],
	},
	{
		"key": "schooner",
		"hull_id": "core:hull/medium_standard",
		"tier": 2,
		"rig_mode": "replace",
		"rig_parts": 2,
		"weapons": 3,
		"loadout": [
			{"socket": "SN_Socket_Weapon_Port_1", "asset": "model.weapon.deck_gun"},
			{"socket": "SN_Socket_Weapon_Starboard_1", "asset": "model.weapon.deck_gun"},
			{"socket": "SN_Socket_Weapon_Bow", "asset": "model.weapon.repeater"},
		],
	},
	{
		"key": "freighter",
		"hull_id": "core:hull/large_efficient",
		"tier": 3,
		"rig_mode": "replace",
		"rig_parts": 4,
		"weapons": 4,
		"loadout": FREIGHTER_LOADOUT,
	},
	{
		"key": "ironclad",
		"hull_id": "core:hull/large_performance",
		"tier": 3,
		"rig_mode": "baked",
		"rig_parts": 0,
		"weapons": 4,
		"loadout": [
			{"socket": "SN_Socket_Weapon_Port_1", "asset": "model.weapon.heavy_cannon"},
			{"socket": "SN_Socket_Weapon_Starboard_1", "asset": "model.weapon.heavy_cannon"},
			{"socket": "SN_Socket_Weapon_Port_2", "asset": "model.weapon.repeater"},
			{"socket": "SN_Socket_Weapon_Starboard_2", "asset": "model.weapon.repeater"},
		],
	},
]

const SHOTS := [
	{"file": "shipyard_steamer.png", "kind": "shipyard", "ship": 0},
	{"file": "shipyard_schooner.png", "kind": "shipyard", "ship": 1},
	{"file": "shipyard_freighter.png", "kind": "shipyard", "ship": 2},
	{"file": "shipyard_ironclad.png", "kind": "shipyard", "ship": 3},
	{"file": "shipyard_schooner_hero.png", "kind": "shipyard_rig", "ship": 1},
	{"file": "port_moored.png", "kind": "port", "ship": 1},
	{"file": "voyage_departure.png", "kind": "departure", "ship": 1},
	{"file": "voyage_arrival.png", "kind": "arrival", "ship": 1},
]

var _context: AppContext
var _failures := 0
var _saved: Array[String] = []
var _pending: Array[Dictionary] = []
var _shipyard: ShipyardStage
var _port: PortStage
var _active_shot := ""


func _init() -> void:
	_watchdog()
	_run()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("must run windowed (drop --headless), otherwise the viewport texture is empty")
		_finish()
		return
	DisplayServer.window_set_size(WINDOW)
	DisplayServer.window_set_title("Steam Navigator · ship assembly")
	await process_frame
	await process_frame
	if not _bootstrap():
		_finish()
		return
	for shot in SHOTS:
		_active_shot = String(shot["file"])
		var kind := String(shot["kind"])
		match kind:
			"shipyard":
				if not await _prepare_shipyard(int(shot["ship"])):
					continue
			"shipyard_rig":
				if not await _prepare_shipyard(int(shot["ship"])):
					continue
				_frame_rig_closeup()
			"port":
				if not await _prepare_port(int(shot["ship"])):
					continue
			"departure":
				if not await _prepare_port(int(shot["ship"])):
					continue
				if not await _play_departure():
					continue
			"arrival":
				if not _port_ready():
					continue
				if not await _play_arrival():
					continue
			_:
				_fail("unknown shot kind: " + kind)
				continue
		if await _capture_to_tmp():
			_pending.append({"tmp": TMP_PREFIX + _active_shot, "file": _active_shot})
	_commit_shots()
	if _shipyard != null and is_instance_valid(_shipyard):
		_shipyard.free()
	if _port != null and is_instance_valid(_port):
		_port.free()
	await process_frame
	_finish()


func _bootstrap() -> bool:
	var bootstrap := Bootstrap.new()
	bootstrap.run({
		"scan_roots": PackedStringArray(["res://dev_mods"]),
		"allow_loose": true,
		"mount_packs": false,
		"log_to_console": false,
		"autosave": false,
		"save_directory": "user://ship_assembly_capture_saves",
	})
	_context = bootstrap.context
	if _context == null:
		_fail("bootstrap failed; cannot resolve Core content")
		return false
	var started := _context.commands.execute(&"run.start", {
		"build_id": "core:starting_build/steady",
		"seed": 20261022,
	})
	if not bool(started.get("ok", false)):
		_fail("run.start failed: %s" % str(started))
		return false
	return true


func _ship_plan(ship: Dictionary) -> Dictionary:
	var bridge := {
		"hull_id": String(ship["hull_id"]),
		"hull_tier": int(ship["tier"]),
		"weapon_loadout": ship["loadout"],
	}
	var plan := ShipVisualPlan.resolve(_context.registries, _context.assets, bridge)
	for warning in plan["warnings"]:
		print("[WARN] plan warning: %s" % String(warning))
	return plan


func _ship_view_model(ship: Dictionary) -> Dictionary:
	return {
		"hull_id": String(ship["hull_id"]),
		"hull_tier": int(ship["tier"]),
		"weapon_loadout": ship["loadout"],
		"visual": _ship_plan(ship),
	}


# --- Shipyard ---------------------------------------------------------------


func _prepare_shipyard(ship_index: int) -> bool:
	var ship: Dictionary = SHIPS[ship_index]
	print("[INFO] shipyard shot %s: %s" % [_active_shot, String(ship["key"])])
	if _shipyard == null or not is_instance_valid(_shipyard):
		var packed := load(SHIPYARD_STAGE_SCENE) as PackedScene
		if packed == null:
			_fail("shipyard stage scene load failed")
			return false
		_shipyard = packed.instantiate() as ShipyardStage
		if _shipyard == null:
			_fail("shipyard stage is not a ShipyardStage")
			return false
		root.add_child(_shipyard)
		await process_frame
	_shipyard.bind({"ship": _ship_view_model(ship)})
	await _settle()
	if not _verify_shipyard(ship):
		return false
	return true


func _verify_shipyard(ship: Dictionary) -> bool:
	if not _shipyard.has_ship():
		_fail("shipyard stage did not mount the assembled ship")
		return false
	var report := _shipyard.assembly_report()
	if report.is_empty():
		_fail("shipyard stage has no assembler report")
		return false
	var rig: Dictionary = report.get("rig", {})
	var weapons: Dictionary = report.get("weapons", {})
	var mounted_rig := (rig.get("mounted", []) as Array).size()
	var mounted_weapons := (weapons.get("mounted", []) as Array).size()
	if String(rig.get("mode", "")) != String(ship["rig_mode"]):
		_fail("shipyard rig mode %s != expected %s" % [String(rig.get("mode", "")), String(ship["rig_mode"])])
		return false
	if mounted_rig != int(ship["rig_parts"]):
		_fail("shipyard rig parts %d != expected %d" % [mounted_rig, int(ship["rig_parts"])])
		return false
	if mounted_weapons != int(ship["weapons"]):
		_fail("shipyard weapons %d != expected %d" % [mounted_weapons, int(ship["weapons"])])
		return false
	if String(report.get("hull_asset", "")).is_empty():
		_fail("assembler did not report the hull asset")
		return false
	print("[INFO]   rig=%s parts=%d weapons=%d hidden=%s tri=%d" % [
		String(rig.get("mode", "")), mounted_rig, mounted_weapons,
		str(rig.get("hidden", [])), int(report.get("triangles", 0)),
	])
	return true


## Close-up of the rig replacement: moves the fixed stage camera to a
## three-quarter shot of the fore mast / sails and leaves the ship intact.
func _frame_rig_closeup() -> void:
	var camera := _shipyard.get_node_or_null("StageCamera") as Camera3D
	if camera == null:
		_fail("shipyard stage has no StageCamera for the rig close-up")
		return
	camera.position = Vector3(27.0, 20.0, 35.0)
	camera.look_at(Vector3(4.6, 12.0, 0.0), Vector3.UP)
	camera.fov = 42.0


# --- Port / voyage ----------------------------------------------------------


func _prepare_port(ship_index: int) -> bool:
	var ship: Dictionary = SHIPS[ship_index]
	print("[INFO] port shot %s: player ship %s" % [_active_shot, String(ship["key"])])
	# The shipyard stage shares the root 3D world; free it before the port stage
	# renders, otherwise its hull shows up as a second ship in the same frame.
	if _shipyard != null and is_instance_valid(_shipyard):
		root.remove_child(_shipyard)
		_shipyard.free()
		_shipyard = null
		await process_frame
	if _port == null or not is_instance_valid(_port):
		var packed := load(PORT_STAGE_SCENE) as PackedScene
		if packed == null:
			_fail("port stage scene load failed")
			return false
		_port = packed.instantiate() as PortStage
		if _port == null:
			_fail("port stage is not a PortStage")
			return false
		root.add_child(_port)
		await process_frame
	_port.bind(_port_payload(ship))
	await _settle()
	return _port_ready()


func _port_ready() -> bool:
	if _port == null or not is_instance_valid(_port) or not _port.has_ship():
		_fail("port stage did not mount the assembled player ship")
		return false
	var report := _port.ship_assembly_report()
	if report.is_empty():
		_fail("port stage has no assembler report")
		return false
	var rig: Dictionary = report.get("rig", {})
	var weapons: Dictionary = report.get("weapons", {})
	print("[INFO]   port rig=%s parts=%d weapons=%d fallback=%s" % [
		String(rig.get("mode", "")),
		(rig.get("mounted", []) as Array).size(),
		(weapons.get("mounted", []) as Array).size(),
		String(report.get("fallback", "")),
	])
	if String(rig.get("mode", "")) != "replace":
		_fail("port player ship did not get the rig replacement")
		return false
	return true


## Real port ViewModel (current port facilities / town visuals) with the chosen
## assembled ship — the stage renders exactly what the overview page binds.
func _port_payload(ship: Dictionary) -> Dictionary:
	var view := _context.queries.execute(&"port.view")
	var data: Dictionary = view["data"]
	var port: Dictionary = data.get("current_port", {})
	var port_payload := {
		"id": String(port.get("id", "")),
		"size": String(port.get("size", "medium")),
		"facilities": Array(port.get("facilities", [])).duplicate(),
	}
	if port.get("town_visuals", null) is Dictionary:
		port_payload["town_visuals"] = (port["town_visuals"] as Dictionary).duplicate(true)
	if port.get("diorama", null) is Dictionary:
		port_payload["diorama"] = (port["diorama"] as Dictionary).duplicate(true)
	if port.get("palette", null) is Dictionary:
		port_payload["palette"] = (port["palette"] as Dictionary).duplicate(true)
	var banner_key := String(port.get("banner_asset", ""))
	var source_mod := String(port.get("source_mod", ""))
	if not banner_key.is_empty() and not source_mod.is_empty():
		var logical := "asset://%s/%s" % [source_mod, banner_key]
		if _context.assets.has(logical):
			port_payload["banner_path"] = _context.assets.resolve(logical)
	return {
		"port": port_payload,
		"ship": _ship_view_model(ship),
	}


func _play_departure() -> bool:
	if _port.voyage_mode() != "":
		_port.reset_voyage()
	_port.begin_departure(VOYAGE_BEAT_SECONDS)
	return await _advance_voyage_to(DEPARTURE_CAPTURE_PROGRESS, "departure")


func _play_arrival() -> bool:
	_port.reset_voyage()
	_port.begin_arrival(VOYAGE_BEAT_SECONDS)
	return await _advance_voyage_to(ARRIVAL_CAPTURE_PROGRESS, "arrival")


## Steps the voyage beat deterministically (fixed 1/60 s ticks) until the
## requested 0..1 progress is reached, then lets a few real frames render.
func _advance_voyage_to(progress: float, label: String) -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while _port.voyage_progress() < progress:
		if Time.get_ticks_msec() > deadline:
			_fail("%s beat did not reach progress %.2f" % [label, progress])
			return false
		_port.advance_voyage(1.0 / 60.0)
		await process_frame
	print("[INFO] %s progress=%.3f mode=%s" % [label, _port.voyage_progress(), _port.voyage_mode()])
	for i in 6:
		await process_frame
	return true


# --- Capture plumbing -------------------------------------------------------


func _settle() -> void:
	for i in SETTLE_FRAMES:
		await process_frame
	await create_timer(SETTLE_SECONDS).timeout
	for i in 3:
		await process_frame


func _capture_to_tmp() -> bool:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("empty viewport texture: " + _active_shot)
		return false
	if image.get_width() != WINDOW.x or image.get_height() != WINDOW.y:
		_fail("capture size %dx%d does not match %dx%d (%s)" % [
			image.get_width(), image.get_height(), WINDOW.x, WINDOW.y, _active_shot,
		])
		return false
	var absolute := ProjectSettings.globalize_path(TMP_PREFIX + _active_shot)
	var save_error := image.save_png(absolute)
	if save_error != OK:
		_fail("cannot save temp PNG %s (error=%d)" % [absolute, save_error])
		return false
	print("[PASS] captured %s %dx%d" % [_active_shot, image.get_width(), image.get_height()])
	return true


func _commit_shots() -> void:
	if _pending.size() != SHOTS.size():
		print("[INFO] not committing: %d/%d shot(s) captured" % [_pending.size(), SHOTS.size()])
		_cleanup_tmp()
		return
	var absolute_dir := ProjectSettings.globalize_path(OUT_DIR)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_error != OK and not DirAccess.dir_exists_absolute(absolute_dir):
		_fail("cannot create output directory %s (error=%d)" % [absolute_dir, dir_error])
		_cleanup_tmp()
		return
	for entry in _pending:
		var tmp_abs := ProjectSettings.globalize_path(String(entry["tmp"]))
		var final_abs := absolute_dir.path_join(String(entry["file"]))
		if not FileAccess.file_exists(tmp_abs):
			_fail("temp capture missing: " + tmp_abs)
			continue
		var move_error := DirAccess.rename_absolute(tmp_abs, final_abs)
		if move_error != OK:
			_fail("cannot move %s -> %s (error=%d)" % [tmp_abs, final_abs, move_error])
			continue
		_saved.append(final_abs)
		print("[PASS] saved %s" % final_abs)
	_cleanup_tmp()


func _cleanup_tmp() -> void:
	for shot in SHOTS:
		var tmp_abs := ProjectSettings.globalize_path(TMP_PREFIX + String(shot["file"]))
		if FileAccess.file_exists(tmp_abs):
			DirAccess.remove_absolute(tmp_abs)


func _fail(message: String) -> void:
	_failures += 1
	print("[FAIL] %s: %s" % [_active_shot, message])


func _finish() -> void:
	_cleanup_tmp()
	print("=== ship assembly capture: %d failures, %d/%d image(s) ===" % [
		_failures, _saved.size(), SHOTS.size(),
	])
	quit(0 if _failures == 0 else 1)


func _watchdog() -> void:
	await process_frame
	await create_timer(WATCHDOG_SECONDS).timeout
	push_error("capture_ship_assembly: screenshot flow timed out (%d s)" % int(WATCHDOG_SECONDS))
	_cleanup_tmp()
	quit(1)
