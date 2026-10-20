## @static-doc
## 作用：铁港建筑验收的 PortStage 实机截图（分辨率参数化）：加载 `port_stage_preview.tscn`，把窗口设到命令行给定尺寸后抓一张 PNG，并顺带打印内容 GLB 的材质/贴图自证行；第三个参数可切换 LOD0/LOD1 标签与 tri 期望，用于 LOD1 临时入舞台的 960×540 可读性证据。
##
## ## 契约与约束
## - 用法：`godot --path . --script res://tools/godot/capture_port_stage_res.gd -- <w> <h> [LOD0|LOD1]`；必须窗口模式（headless 下视口纹理为空）。
## - 输出 `docs/design/screenshots/iron_harbor_architecture/SN_HT_Warehouse_Long_<LABEL>_port_stage_<w>x<h>.png`；失败以非 0 退出码结束。
## - `_report_asset_materials()` 逐个 `load()` 5 个槽位 GLB（`TOWN_ASSETS`：warehouse_long / warehouse_short / harbor_office / cargo_shed / tavern，stage 采样同一路径），打印每栋 `[asset] ... surfaces/tris/uv_surfaces/textured_surfaces/materials/textures`；有面缺贴图/缺 UV、或 tri 数与期望表（LOD0 7436 / 3788 / 10336 / 3356 / 5116；LOD1 1584 / 1060 / 1896 / 776 / 1248）不符都记为失败。stage 里 static batching 会把逐对象节点合并释放，所以**不能**在场景树里找它。
## - `budget: ... tris=` 是整台 stage 的总量（含并行工作流往城镇加的道具），**不能**当单资产增量证据，单资产证据看 `[asset]` 行。
## - 与既有 `capture_port_stage.gd`（固定 1440×900、preview+sparse 两张）并行存在，不改后者行为。
## @end-static-doc

extends SceneTree
## Real-render PortStage screenshots at an explicit window resolution.
##
## Companion to `capture_port_stage.gd` (which is fixed at 1440x900 and captures
## the preview + sparse variants). This one is for R1 acceptance gates: it loads
## the same `port_stage_preview.tscn`, resizes the window to the requested size
## and saves one PNG named after that size.
##
## Usage (windowed, NOT headless):
##   godot --path . --script res://tools/godot/capture_port_stage_res.gd -- 1440 900
##   godot --path . --script res://tools/godot/capture_port_stage_res.gd -- 960 540
##
## Output:
##   docs/design/screenshots/iron_harbor_architecture/
##     SN_HT_Warehouse_Long_LOD0_port_stage_<w>x<h>.png
##
## Any failure exits with code 1.

const PREVIEW_SCENE := "res://dev_scenes/port_stage/port_stage_preview.tscn"
const OUT_DIR := "res://docs/design/screenshots/iron_harbor_architecture"
const SETTLE_FRAMES := 90
const SETTLE_SECONDS := 1.0
const RESIZE_FRAMES := 20
const WATCHDOG_SECONDS := 150.0
## The five drop-in buildings the iron-harbor town slots resolve to. The stage
## mounts them through `port.town_visuals`, so inspecting the imported scenes is
## the same geometry the fixed camera renders (the static batcher frees the
## per-object nodes later, so they cannot be found in the live scene tree).
const TOWN_ASSETS := {
	"warehouse_long": "res://dev_mods/core/assets/models/props/SN_HT_Warehouse_Long.glb",
	"warehouse_short": "res://dev_mods/core/assets/models/props/SN_HT_Warehouse_Short.glb",
	"harbor_office": "res://dev_mods/core/assets/models/props/SN_HT_Harbor_Office.glb",
	"cargo_shed": "res://dev_mods/core/assets/models/props/SN_HT_Cargo_Shed.glb",
	"tavern": "res://dev_mods/core/assets/models/props/SN_HT_Tavern.glb",
}
const EXPECTED_ASSET_TRIS := {
	"warehouse_long": 7436,
	"warehouse_short": 3788,
	"harbor_office": 10336,
	"cargo_shed": 3356,
	"tavern": 5116,
}
## Batch-A LOD1 tris, used when the third CLI arg is `LOD1` (the stage is pointed
## at the LOD1 GLBs temporarily; the screenshot is named `..._LOD1_...`).
const EXPECTED_LOD1_TRIS := {
	"warehouse_long": 1584,
	"warehouse_short": 1060,
	"harbor_office": 1896,
	"cargo_shed": 776,
	"tavern": 1248,
}
var _label := "LOD0"

var _failures := 0

func _init() -> void:
	_watchdog()
	_run()


func _watchdog() -> void:
	await process_frame
	await create_timer(WATCHDOG_SECONDS).timeout
	push_error("capture_port_stage_res: timed out")
	quit(1)


func _target_size() -> Vector2i:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2:
		return Vector2i(int(args[0]), int(args[1]))
	return Vector2i(1440, 900)


## Optional third CLI arg: screenshot/expectation label (`LOD0` default, `LOD1`).
func _resolve_label() -> String:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 3:
		return String(args[2]).to_upper()
	return "LOD0"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("must run windowed (drop --headless)")
		_finish()
		return
	var target := _target_size()
	_label = _resolve_label()
	DisplayServer.window_set_size(target)
	for i in RESIZE_FRAMES:
		await process_frame
	DisplayServer.window_set_title("Steam Navigator · port stage R1 %dx%d" % [target.x, target.y])

	var packed := load(PREVIEW_SCENE) as PackedScene
	if packed == null:
		_fail("scene load failed: " + PREVIEW_SCENE)
		_finish()
		return
	_report_asset_materials()
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await _settle()
	await _capture("SN_HT_Warehouse_Long_%s_port_stage_%dx%d.png" % [_label, target.x, target.y])
	scene.queue_free()
	await process_frame
	_finish()


func _settle() -> void:
	for i in SETTLE_FRAMES:
		await process_frame
	await create_timer(SETTLE_SECONDS).timeout
	for i in 3:
		await process_frame


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("empty viewport texture: " + file_name)
		return
	var absolute := ProjectSettings.globalize_path(OUT_DIR.path_join(file_name))
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if dir_error != OK and not DirAccess.dir_exists_absolute(absolute.get_base_dir()):
		_fail("cannot create %s (error=%d)" % [absolute.get_base_dir(), dir_error])
		return
	var save_error := image.save_png(absolute)
	if save_error != OK:
		_fail("cannot save PNG %s (error=%d)" % [absolute, save_error])
		return
	print("[PASS] saved %s (%dx%d)" % [absolute, image.get_width(), image.get_height()])


func _fail(message: String) -> void:
	_failures += 1
	print("[FAIL] " + message)


## Material gate evidence: the imported drop-in that the town slot mounts must
## carry the shared trim-sheet textures and UVs on every surface. Prints one
## summary line; a missing texture or UV set counts as a capture failure.
func _report_asset_materials() -> void:
	for slot in TOWN_ASSETS.keys():
		_report_one_asset(String(slot), String(TOWN_ASSETS[slot]))


func _report_one_asset(slot: String, path: String) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		_fail("asset load failed (%s): %s" % [slot, path])
		return
	var node: Node = packed.instantiate()
	var stack: Array[Node] = [node]
	var surfaces := 0
	var tris := 0
	var uv_surfaces := 0
	var textured := 0
	var textures := {}
	var materials: Array[String] = []
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		for child in current.get_children():
			stack.append(child)
		if not (current is MeshInstance3D):
			continue
		var mesh: MeshInstance3D = current
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			surfaces += 1
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var uvs: Variant = arrays[Mesh.ARRAY_TEX_UV]
			if uvs is PackedVector2Array and (uvs as PackedVector2Array).size() > 0:
				uv_surfaces += 1
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			if indices is PackedInt32Array:
				tris += (indices as PackedInt32Array).size() / 3
			var material: Material = mesh.mesh.surface_get_material(surface)
			if not (material is StandardMaterial3D):
				continue
			var standard: StandardMaterial3D = material
			if not materials.has(standard.resource_name):
				materials.append(standard.resource_name)
			if standard.albedo_texture != null:
				textured += 1
				var size := standard.albedo_texture.get_size()
				textures[standard.resource_name] = "%dx%d" % [size.x, size.y]
	print("[asset] %s slot=%s surfaces=%d tris=%d uv_surfaces=%d textured_surfaces=%d materials=%s textures=%s" % [
		path.get_file(), slot, surfaces, tris, uv_surfaces, textured,
		str(materials), str(textures)])
	if textured < surfaces:
		_fail("asset surfaces without albedo texture (%s): %d/%d" % [slot, surfaces - textured, surfaces])
	if uv_surfaces < surfaces:
		_fail("asset surfaces without UVs (%s): %d/%d" % [slot, surfaces - uv_surfaces, surfaces])
	var expected_tris := EXPECTED_LOD1_TRIS if _label == "LOD1" else EXPECTED_ASSET_TRIS
	var expected := int(expected_tris.get(slot, 0))
	if expected > 0 and tris != expected:
		_fail("asset tri count changed (%s): %d != %d" % [slot, tris, expected])
	node.free()


func _finish() -> void:
	print("=== port stage R1 capture: %d failure(s) ===" % _failures)
	quit(0 if _failures == 0 else 1)
