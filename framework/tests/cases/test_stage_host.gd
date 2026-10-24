extends TestCase
## 2.5D 舞台基础设施契约：LocationStage / SNStageHost / ShipyardStage / PortStage。
##
## 这些测试全部是同步函数（无 await）：节点在同一个调用里加入 SceneTree，
## `_ready` 与 `add_child` 通知会同步派发，因此挂载/卸载生命周期可以在一步内
## 完整断言。每个用例自己 new 节点并在结尾 free，避免残留节点影响其他套件。
##
## 覆盖：
##   - LocationStage 默认契约（enter/bind/exit 可调用、空锚点、portal_requested）；
##   - SNStageHost 生命周期（enter→bind 顺序、portal 转发、隐藏停更、卸载、重挂载）；
##   - 场景缺失 / 根节点不是 LocationStage 时的 fallback_requested；
##   - 真实 ShipyardStage 场景可按 hull_tier 挂载船体；
##   - SNShipStage3D 适配器（SNShipView renderer 契约）；
##   - PortStage 按 facilities 装配、GLB 视觉替换与回落、size 缩放、portal 意图。

const SHIPYARD_STAGE_SCENE := "res://framework/ui/stages/shipyard_stage.tscn"
const NON_STAGE_SCENE := "res://framework/ui/components/sn_badge.tscn"
const STEAMER_MODEL := "res://assets/models/ships/SN_Paddle_Steamer.glb"
const PORT_STAGE_SCENE := "res://framework/ui/stages/port_stage.tscn"


## A LocationStage that records the host-driven lifecycle in call order.
class FakeStage extends LocationStage:
	signal exited

	var enter_payload: Dictionary = {}
	var bind_vm: Dictionary = {}
	var exit_called := false
	var calls: Array[String] = []

	func enter(payload: Dictionary = {}) -> void:
		enter_payload = payload.duplicate(true)
		calls.append("enter")

	func bind(view_model: Dictionary = {}) -> void:
		bind_vm = view_model.duplicate(true)
		calls.append("bind")

	func exit() -> void:
		exit_called = true
		calls.append("exit")
		exited.emit()


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Creates a host and parents it to the real tree, so _ready builds the
## SubViewport/World exactly like the game does.
func _new_host() -> SNStageHost:
	var host := SNStageHost.new()
	host.name = "StageHostUnderTest"
	_tree().root.add_child(host)
	return host


func _free_host(host: SNStageHost) -> void:
	if host.get_parent() != null:
		host.get_parent().remove_child(host)
	host.free()


func _new_fake(stage_id: String) -> FakeStage:
	var stage := FakeStage.new()
	stage.stage_id = stage_id
	return stage


# --- 1. LocationStage default contract ---------------------------------------


func test_location_stage_default_contract_is_callable() -> void:
	var stage := LocationStage.new()
	var portals: Array[String] = []
	stage.portal_requested.connect(func(target_id: String): portals.append(target_id))
	assert_eq(stage.stage_id, "", "a bare LocationStage has no stage id until a scene overrides it")
	stage.enter({"reason": "test"})
	stage.bind({"ship": {}})
	stage.exit()
	assert_true(stage.has_visual(), "the default stage reports a usable visual so hosts do not fall back")
	assert_empty(stage.hotspot_anchors(), "the default stage exposes no world-space hotspot anchors")
	stage.portal_requested.emit("market")
	assert_eq(portals.size(), 1, "portal_requested can be emitted by the stage")
	assert_eq(portals[0], "market", "portal_requested forwards the requested target id")
	stage.free()


# --- 2. SNStageHost mount/unmount lifecycle ----------------------------------


func test_host_mounts_stage_and_drives_enter_bind_exit_lifecycle() -> void:
	var host := _new_host()
	var mounted: Array = []
	var unmounted: Array[String] = []
	var portals: Array[String] = []
	host.stage_mounted.connect(func(stage: Node, stage_id: String): mounted.append({"stage": stage, "id": stage_id}))
	host.stage_unmounted.connect(func(stage_id: String): unmounted.append(stage_id))
	host.portal_requested.connect(func(target_id: String): portals.append(target_id))

	var fake := _new_fake("fake_stage")
	# The host frees the stage on unmount, so observe exit() through a signal
	# fired before the node is gone instead of reading the freed instance.
	var exits: Array[String] = []
	fake.exited.connect(func(): exits.append("exit"))
	assert_true(host.mount_stage(fake, {"payload_key": 7}), "mount_stage accepts a LocationStage instance")
	assert_true(host.has_stage(), "has_stage() reports the mounted stage")
	assert_eq(host.current_stage(), fake, "current_stage() returns the mounted instance")
	assert_eq(host.stage_id(), "fake_stage", "the host adopts the stage's stage_id")
	assert_eq(mounted.size(), 1, "stage_mounted is emitted once")
	assert_eq(String(mounted[0]["id"]), "fake_stage", "stage_mounted reports the stage id")
	assert_eq(fake.calls.size(), 2, "mounting runs exactly enter and bind")
	assert_eq(fake.calls[0], "enter", "enter() runs before bind()")
	assert_eq(fake.calls[1], "bind", "bind() runs after enter()")
	assert_eq(int(fake.enter_payload.get("payload_key", 0)), 7, "the mount payload reaches enter()")
	assert_true(host.stage_world() != null, "the host owns a stage World3D root")
	assert_not_null(host.stage_viewport(), "the host owns a SubViewport")

	host.bind_view_model({"ship": {"hull_tier": 2}, "marker": 9})
	assert_eq(int(fake.bind_vm.get("marker", 0)), 9, "bind_view_model forwards the latest ViewModel")
	assert_eq(int(host.view_model().get("marker", 0)), 9, "the host caches the latest ViewModel")
	assert_eq(fake.calls.size(), 3, "a later bind_view_model re-binds the stage")
	assert_eq(fake.calls[2], "bind", "the forwarded refresh is a bind() call")

	fake.portal_requested.emit("market")
	assert_eq(portals.size(), 1, "the host re-emits a stage portal request")
	assert_eq(portals[0], "market", "the requested target id survives forwarding")

	host.set_stage_visible(false)
	assert_false(host.is_stage_visible(), "is_stage_visible() follows set_stage_visible()")
	assert_eq(int(fake.process_mode), Node.PROCESS_MODE_DISABLED, "hiding the host disables stage processing")
	assert_eq(
		int(host.stage_viewport().render_target_update_mode),
		SubViewport.UPDATE_DISABLED,
		"hiding the host stops viewport rendering"
	)
	host.set_stage_visible(true)
	assert_true(host.is_stage_visible(), "the stage can be shown again")
	assert_eq(int(fake.process_mode), Node.PROCESS_MODE_INHERIT, "showing the host restores stage processing")
	assert_eq(
		int(host.stage_viewport().render_target_update_mode),
		SubViewport.UPDATE_WHEN_VISIBLE,
		"showing the host resumes viewport updates"
	)

	host.unmount_stage()
	assert_eq(exits.size(), 1, "unmount_stage() calls exit() before freeing the stage")
	assert_false(host.has_stage(), "has_stage() is false after unmount")
	assert_eq(host.stage_id(), "", "the unmounted host drops its stage id")
	assert_eq(unmounted.size(), 1, "stage_unmounted is emitted once")
	assert_eq(unmounted[0], "fake_stage", "stage_unmounted reports the removed stage id")

	# The same host can host another stage afterwards.
	var second := _new_fake("")
	second.name = "SecondFakeStage"
	assert_true(host.mount_stage(second), "the host can mount a new stage after unmounting")
	assert_true(host.has_stage(), "the replacement stage is mounted")
	assert_eq(host.stage_id(), "SecondFakeStage", "an empty stage_id falls back to the node name")
	assert_eq(second.calls.size(), 2, "the replacement stage is entered and bound")
	assert_eq(second.calls[0], "enter", "the replacement is entered first")
	assert_eq(second.calls[1], "bind", "the replacement is bound second")
	_free_host(host)


# --- 3. Fallback behaviour ---------------------------------------------------


func test_host_emits_fallback_for_missing_or_non_stage_scenes() -> void:
	var host := _new_host()
	var reasons: Array[String] = []
	host.fallback_requested.connect(func(reason: String): reasons.append(reason))

	assert_false(host.load_stage("res://does_not_exist.tscn"), "a missing stage scene reports failure")
	assert_eq(reasons.size(), 1, "a missing stage scene requests the 2D fallback")
	assert_true(
		reasons[0].begins_with("stage_scene_missing"),
		"the fallback reason names the missing scene: %s" % reasons[0]
	)
	assert_false(host.has_stage(), "a failed load mounts nothing")

	assert_false(host.load_stage(NON_STAGE_SCENE), "a scene whose root is not a LocationStage reports failure")
	assert_eq(reasons.size(), 2, "a non-stage scene also requests the 2D fallback")
	assert_true(
		reasons[1].begins_with("stage_not_location_stage"),
		"the fallback reason says the root is not a LocationStage: %s" % reasons[1]
	)
	assert_false(host.has_stage(), "a rejected scene leaves the host empty")
	_free_host(host)


# --- 4. Real shipyard stage --------------------------------------------------


func test_shipyard_stage_scene_loads_and_binds_a_hull() -> void:
	var host := _new_host()
	assert_true(host.load_stage(SHIPYARD_STAGE_SCENE), "the authored shipyard stage scene loads")
	var stage := host.current_stage()
	assert_not_null(stage, "the shipyard stage is mounted on the host")
	assert_true(stage is ShipyardStage, "the mounted node is a ShipyardStage")
	assert_eq(host.stage_id(), "shipyard", "the shipped stage scene keeps stage_id=shipyard")
	host.bind_view_model({"ship": {"hull_tier": 1}})
	var shipyard := stage as ShipyardStage
	assert_true(shipyard.has_ship(), "binding hull_tier=1 mounts a ship model in the stage")
	assert_true(
		String(shipyard.model_path()).contains("SN_Paddle_Steamer"),
		"tier 1 resolves to the paddle steamer GLB: %s" % shipyard.model_path()
	)
	assert_true(shipyard.has_visual(), "the ship stage reports a usable visual")
	_free_host(host)


# --- 5. SNShipStage3D renderer adapter --------------------------------------


func test_ship_stage_3d_adapter_wraps_the_stage_host() -> void:
	var adapter := SNShipStage3D.new()
	adapter.name = "ShipStage3DUnderTest"
	_tree().root.add_child(adapter)
	assert_true(adapter.has_stage(), "the adapter mounts its shipyard stage on _ready")
	assert_eq(adapter.stage_id(), "shipyard", "the adapter reports the shipyard stage id")

	adapter.ship_view_update({"hull_model_path": STEAMER_MODEL, "hull_tier": 1})
	assert_true(adapter.has_ship(), "ship_view_update forwards the ship ViewModel to the stage")
	assert_true(
		String(adapter.model_path()).contains("SN_Paddle_Steamer"),
		"the adapter reports the bound hull model: %s" % adapter.model_path()
	)

	adapter.ship_view_set_mode(1)
	assert_false(adapter.is_stage_visible(), "CUTAWAY mode hides the 3D stage")
	adapter.ship_view_set_mode(0)
	assert_true(adapter.is_stage_visible(), "EXTERIOR mode shows the 3D stage again")

	adapter.ship_view_highlight(["boiler"])
	if adapter.get_parent() != null:
		adapter.get_parent().remove_child(adapter)
	adapter.free()


# --- 6. PortStage ------------------------------------------------------------

const PORT_FACILITIES := ["exchange", "shipyard", "tavern"]
const MARKET_STALL_MODEL := "res://assets/models/port/SN_Market_Stall.glb"
const MISSING_FACILITY_MODEL := "res://assets/models/port/SN_Not_A_Model.glb"
const VIEWPORT_SIZE := Vector2i(1440, 900)


## Mounts the authored port stage scene on a real host. The caller checks
## `"stage"` and always frees the host.
func _mount_port_stage() -> Dictionary:
	var host := _new_host()
	# Do not rely on the container layout finishing within this frame; the
	# hotspot projection reads the viewport size directly.
	host.stage_viewport().size = VIEWPORT_SIZE
	var loaded := host.load_stage(PORT_STAGE_SCENE)
	return {"host": host, "loaded": loaded, "stage": host.current_stage()}


func _port_view(size: String, facilities: Array, extra_port: Dictionary = {}) -> Dictionary:
	var port := {"id": "test_harbor", "size": size, "facilities": facilities.duplicate()}
	for key in extra_port.keys():
		port[String(key)] = extra_port[key]
	return {"port": port}


func test_port_stage_assembles_present_facilities_and_fills_empty_slots() -> void:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	assert_true(bool(bundle["loaded"]), "the authored port stage scene loads")
	var stage: Variant = bundle["stage"]
	assert_true(stage is PortStage, "the port stage scene mounts a PortStage")
	if not (stage is PortStage):
		_free_host(host)
		return
	var port := stage as PortStage
	assert_eq(host.stage_id(), "port", "the shipped port stage scene keeps stage_id=port")

	host.bind_view_model(_port_view("medium", PORT_FACILITIES))
	assert_eq(port.facility_count(), 3, "only the present facilities get anchors")
	assert_eq(port.filler_count(), 2, "the absent facilities are filled instead of anchored")
	for facility in PORT_FACILITIES:
		assert_eq(
			port.facility_visual_kind(facility),
			"billboard",
			"%s uses its procedural billboard when no GLB is supplied" % facility
		)
	assert_eq(port.facility_visual_kind("contracts"), "missing", "an absent facility reports kind missing")
	assert_eq(port.facility_visual_kind("supply"), "missing", "an absent facility never becomes a hotspot")

	var anchors := port.facility_anchors()
	assert_eq(anchors.size(), 3, "facility_anchors() exposes one anchor per present facility")
	assert_false(anchors.has("contracts"), "an absent facility is not in facility_anchors()")
	for facility in PORT_FACILITIES:
		assert_true(anchors.has(facility), "the %s anchor is exposed for 2D hotspots" % facility)
	assert_false(port.has_backdrop(), "no banner_path means no L1 backdrop")
	assert_eq(port.loaded_banner_path(), "", "nothing was loaded as a backdrop")
	assert_true(port.has_visual(), "the procedural port stage stays drawable without any content asset")

	var screen_anchor := port.facility_screen_anchor("exchange")
	assert_true(is_finite(screen_anchor.x) and is_finite(screen_anchor.y), "the projected hotspot anchor is finite")
	assert_eq(port.facility_screen_anchor("contracts"), Vector2.ZERO, "an absent facility projects to zero")
	_free_host(host)


func test_port_stage_uses_facility_visual_models_and_falls_back_on_missing_files() -> void:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	var stage: Variant = bundle["stage"]
	assert_true(bool(bundle["loaded"]) and stage is PortStage, "the port stage scene loads")
	if not (stage is PortStage):
		_free_host(host)
		return
	var port := stage as PortStage

	host.bind_view_model(_port_view("medium", ["exchange"], {"facility_visuals": {"exchange": MARKET_STALL_MODEL}}))
	assert_eq(port.facility_visual_kind("exchange"), "model", "a resolved facility GLB replaces the procedural anchor")
	assert_eq(port.facility_count(), 1, "the single requested facility is still the only anchor")
	assert_eq(port.filler_count(), 4, "the other four facility slots are filled")

	host.bind_view_model(_port_view("medium", ["exchange"], {"facility_visuals": {"exchange": MISSING_FACILITY_MODEL}}))
	assert_eq(port.facility_visual_kind("exchange"), "billboard", "an illegal facility GLB path falls back to the billboard")
	_free_host(host)


func test_port_stage_scales_facility_anchors_with_port_size() -> void:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	var stage: Variant = bundle["stage"]
	assert_true(bool(bundle["loaded"]) and stage is PortStage, "the port stage scene loads")
	if not (stage is PortStage):
		_free_host(host)
		return
	var port := stage as PortStage

	host.bind_view_model(_port_view("medium", ["exchange"]))
	var medium_anchors := port.facility_anchors()
	if not medium_anchors.has("exchange"):
		assert_true(false, "the medium port exposes the exchange anchor")
		_free_host(host)
		return
	var medium_x := float(medium_anchors["exchange"].x)
	host.bind_view_model(_port_view("small", ["exchange"]))
	var small_x := float(port.facility_anchors()["exchange"].x)
	host.bind_view_model(_port_view("large", ["exchange"]))
	var large_x := float(port.facility_anchors()["exchange"].x)

	assert_true(absf(medium_x) > 0.01, "the fixture anchor is off-centre so its x scales visibly")
	assert_almost_eq(small_x / medium_x, 0.9, 0.05, "size=small scales facility anchors by 0.9")
	assert_almost_eq(large_x / medium_x, 1.15, 0.05, "size=large scales facility anchors by 1.15")
	_free_host(host)


func test_port_stage_mounts_the_player_hull_and_requests_portals() -> void:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	var stage: Variant = bundle["stage"]
	assert_true(bool(bundle["loaded"]) and stage is PortStage, "the port stage scene loads")
	if not (stage is PortStage):
		_free_host(host)
		return
	var port := stage as PortStage
	var portals: Array[String] = []
	host.portal_requested.connect(func(target_id: String): portals.append(target_id))

	host.bind_view_model({
		"port": {"id": "test_harbor", "size": "medium", "facilities": PORT_FACILITIES},
		"ship": {"hull_model_path": STEAMER_MODEL, "hull_tier": 1},
	})
	assert_true(port.has_ship(), "a resolved hull_model_path mounts the player ship in the port")

	# The rigid steamer hull is baked into ship-local draw batches.
	var ship_stats: Dictionary = port.batch_stats()
	assert_false(bool(ship_stats["ship_fallback"]), "the rigid paddle-steamer hull batches instead of falling back")
	assert_true(int(ship_stats["ship_batches"]) > 0, "the hull produces ship-local draw batches")
	assert_true(
		int(ship_stats["ship_meshes_after"]) < int(ship_stats["ship_meshes_before"]),
		"hull batching reduces the hull draw meshes: %d -> %d" % [
			int(ship_stats["ship_meshes_before"]), int(ship_stats["ship_meshes_after"])
		]
	)

	port.request_portal("exchange")
	assert_eq(portals.size(), 1, "request_portal is re-emitted by the host")
	assert_eq(portals[0], "exchange", "the portal target is the requested facility")
	_free_host(host)


# --- 7. PortStage scene fill (L0/L1/L2/L6/L7) --------------------------------

const IRON_HARBOR_BANNER := "res://dev_mods/core/assets/ports/iron_harbor_banner.png"


func test_port_stage_scene_fill_builds_procedural_skyline_without_banner() -> void:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	var stage: Variant = bundle["stage"]
	assert_true(bool(bundle["loaded"]) and stage is PortStage, "the port stage scene loads")
	if not (stage is PortStage):
		_free_host(host)
		return
	var port := stage as PortStage

	host.bind_view_model(_port_view("medium", PORT_FACILITIES))
	assert_false(port.has_backdrop(), "the banner-less fixture uses the procedural fallback, not L1")
	assert_not_null(port.foreground_frame(), "the L6 foreground frame is always mounted")
	var particle_systems := port.atmosphere_particle_systems()
	assert_true(
		particle_systems >= 1 and particle_systems <= 3,
		"the L7 atmosphere mounts 1..3 particle systems: %d" % particle_systems
	)
	assert_true(port.atmosphere_layers() >= 1, "the L7 atmosphere mounts at least one fog layer")
	assert_eq(port.skyline_building_count(), 10, "medium ports draw 10 L2 skyline buildings")
	var cranes := port.skyline_crane_count()
	assert_true(cranes >= 2 and cranes <= 3, "the L2 skyline draws 2..3 cranes: %d" % cranes)
	_free_host(host)


func test_port_stage_skyline_counts_scale_with_port_size() -> void:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	var stage: Variant = bundle["stage"]
	assert_true(bool(bundle["loaded"]) and stage is PortStage, "the port stage scene loads")
	if not (stage is PortStage):
		_free_host(host)
		return
	var port := stage as PortStage

	host.bind_view_model(_port_view("small", PORT_FACILITIES))
	var small_buildings := port.skyline_building_count()
	var small_cranes := port.skyline_crane_count()
	host.bind_view_model(_port_view("medium", PORT_FACILITIES))
	var medium_buildings := port.skyline_building_count()
	var medium_cranes := port.skyline_crane_count()
	host.bind_view_model(_port_view("large", PORT_FACILITIES))
	var large_buildings := port.skyline_building_count()
	var large_cranes := port.skyline_crane_count()

	assert_eq(small_buildings, 7, "small ports draw 7 L2 skyline buildings")
	assert_eq(medium_buildings, 10, "medium ports draw 10 L2 skyline buildings")
	assert_eq(large_buildings, 13, "large ports draw 13 L2 skyline buildings")
	assert_true(
		small_buildings < medium_buildings and medium_buildings < large_buildings,
		"the L2 building budget grows with port size: %d/%d/%d" % [small_buildings, medium_buildings, large_buildings]
	)
	assert_true(
		small_cranes <= medium_cranes and medium_cranes <= large_cranes,
		"the L2 crane budget never shrinks with port size: %d/%d/%d" % [small_cranes, medium_cranes, large_cranes]
	)
	assert_true(large_cranes <= 3, "the crane count stays within the L2 budget: %d" % large_cranes)
	_free_host(host)


func test_port_stage_banner_replaces_skyline_but_keeps_frame_and_atmosphere() -> void:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	var stage: Variant = bundle["stage"]
	assert_true(bool(bundle["loaded"]) and stage is PortStage, "the port stage scene loads")
	if not (stage is PortStage):
		_free_host(host)
		return
	var port := stage as PortStage

	host.bind_view_model(_port_view("medium", PORT_FACILITIES, {"banner_path": IRON_HARBOR_BANNER}))
	assert_true(port.has_backdrop(), "the authored harbour banner loads as the L1 backdrop")
	assert_eq(port.loaded_banner_path(), IRON_HARBOR_BANNER, "the loaded backdrop path is reported")
	assert_eq(port.skyline_building_count(), 0, "a painted L1 banner replaces the L2 skyline")
	assert_eq(port.skyline_crane_count(), 0, "no L2 cranes are drawn over a painted banner")
	assert_not_null(port.foreground_frame(), "the L6 frame stays in front of the painted backdrop")
	var particle_systems := port.atmosphere_particle_systems()
	assert_true(particle_systems >= 1, "the L7 atmosphere stays active over a banner: %d" % particle_systems)
	assert_true(port.atmosphere_layers() >= 1, "at least one L7 fog layer stays over a banner")

	host.bind_view_model(_port_view("medium", PORT_FACILITIES))
	assert_false(port.has_backdrop(), "binding without a banner drops the L1 backdrop")
	assert_eq(port.skyline_building_count(), 10, "the L2 skyline returns when the banner is gone")
	_free_host(host)


func test_port_stage_scene_fill_accessors_survive_visibility_toggle() -> void:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	var stage: Variant = bundle["stage"]
	assert_true(bool(bundle["loaded"]) and stage is PortStage, "the port stage scene loads")
	if not (stage is PortStage):
		_free_host(host)
		return
	var port := stage as PortStage

	host.bind_view_model(_port_view("medium", PORT_FACILITIES))
	var frame := port.foreground_frame()
	var particle_systems := port.atmosphere_particle_systems()
	var fog_layers := port.atmosphere_layers()
	var buildings := port.skyline_building_count()
	var cranes := port.skyline_crane_count()

	host.set_stage_visible(false)
	assert_false(host.is_stage_visible(), "the host is hidden")
	assert_true(is_instance_valid(frame), "the L6 frame node stays valid while the stage is hidden")
	assert_eq(port.foreground_frame(), frame, "the L6 accessor still returns the frame while hidden")
	assert_eq(port.atmosphere_particle_systems(), particle_systems, "the L7 particle count is stable while hidden")
	assert_eq(port.atmosphere_layers(), fog_layers, "the L7 fog layer count is stable while hidden")
	assert_eq(port.skyline_building_count(), buildings, "the L2 building count is stable while hidden")
	assert_eq(port.skyline_crane_count(), cranes, "the L2 crane count is stable while hidden")

	host.set_stage_visible(true)
	assert_true(host.is_stage_visible(), "the host is shown again")
	assert_eq(port.foreground_frame(), frame, "the L6 frame survives the visibility round-trip")
	assert_eq(port.atmosphere_particle_systems(), particle_systems, "the L7 particle count survives the visibility round-trip")
	assert_eq(port.atmosphere_layers(), fog_layers, "the L7 fog layer count survives the visibility round-trip")
	assert_eq(port.skyline_building_count(), buildings, "the L2 building count survives the visibility round-trip")
	_free_host(host)


# --- 8. PortStage harbour-town street kit (L2b) ------------------------------

## The official town kit as the query resolves it for a dev/loose `core` mod.
## Five buildings + nine repeated fence modules + nine workers + ten plaza props
## + five boats + ten dock-side industry props are the maximum (busy tier);
## a tier mounts a prefix of each group.
const TOWN_VISUALS := {
	"warehouse_long": "res://dev_mods/core/assets/models/props/SN_HT_Warehouse_Long.glb",
	"warehouse_short": "res://dev_mods/core/assets/models/props/SN_HT_Warehouse_Short.glb",
	"harbor_office": "res://dev_mods/core/assets/models/props/SN_HT_Harbor_Office.glb",
	"cargo_shed": "res://dev_mods/core/assets/models/props/SN_HT_Cargo_Shed.glb",
	"tavern": "res://dev_mods/core/assets/models/props/SN_HT_Tavern.glb",
	"fence_row": "res://dev_mods/core/assets/models/props/SN_HT_Fence_Row.glb",
	"dock_worker_a": "res://dev_mods/core/assets/models/props/SN_HT_Dock_Worker_A.glb",
	"dock_worker_b": "res://dev_mods/core/assets/models/props/SN_HT_Dock_Worker_B.glb",
	"rowboat": "res://dev_mods/core/assets/models/props/SN_HT_Rowboat.glb",
	"cargo_lighter": "res://dev_mods/core/assets/models/props/SN_HT_Cargo_Lighter.glb",
	"crate": "res://dev_mods/core/assets/models/props/SN_Crate.glb",
	"barrel": "res://dev_mods/core/assets/models/props/SN_Barrel.glb",
	"coal_pile": "res://dev_mods/core/assets/models/props/SN_Coal_Pile.glb",
	"timber_stack": "res://dev_mods/core/assets/models/props/SN_Timber_Stack.glb",
	"handcart": "res://dev_mods/core/assets/models/props/SN_Handcart.glb",
	"gas_lamp": "res://dev_mods/core/assets/models/props/SN_Gas_Lamp.glb",
	"market_stall": "res://assets/models/port/SN_Market_Stall.glb",
	"harbor_crane": "res://dev_mods/core/assets/models/props/SN_Harbor_Crane.glb",
	"sack_pile": "res://dev_mods/core/assets/models/props/SN_Sack_Pile.glb",
	"plate_stack": "res://dev_mods/core/assets/models/props/SN_Plate_Stack.glb",
	"ore_pile": "res://dev_mods/core/assets/models/props/SN_Ore_Pile.glb",
	"pallet": "res://dev_mods/core/assets/models/props/SN_Pallet.glb",
	"gangway": "res://dev_mods/core/assets/models/props/SN_Gangway.glb",
	"mooring_bollard": "res://dev_mods/core/assets/models/props/SN_Mooring_Bollard.glb",
	"capstan": "res://dev_mods/core/assets/models/props/SN_Capstan.glb",
	"buoy": "res://dev_mods/core/assets/models/props/SN_Buoy.glb",
}
## town_prop_count per density tier (buildings are always mounted).
const TOWN_DENSITY_COUNTS := {"sparse": 28, "normal": 47, "busy": 63}
## Station-dressing props per density tier (3 adjacent stations x prefix size).
const STATION_DENSITY_COUNTS := {"sparse": 15, "normal": 24, "busy": 33}
const TOWN_MISSING_MODEL := "res://dev_mods/core/assets/models/props/SN_Does_Not_Exist.glb"
const STEADY_BUILD := "core:starting_scenario/steady"


func test_port_stage_town_kit_mounts_full_streetscape() -> void:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	var stage: Variant = bundle["stage"]
	assert_true(bool(bundle["loaded"]) and stage is PortStage, "the port stage scene loads")
	if not (stage is PortStage):
		_free_host(host)
		return
	var port := stage as PortStage

	host.bind_view_model(_port_view("medium", PORT_FACILITIES, {"town_visuals": TOWN_VISUALS}))
	assert_eq(port.town_density(), "normal", "medium ports default to the normal street density")
	assert_eq(
		port.town_prop_count(),
		int(TOWN_DENSITY_COUNTS["normal"]),
		"5 buildings + 7 fences + 7 workers + 8 plaza props + 3 boats + 17 quay props mount"
	)
	assert_eq(port.town_blockout_count(), 0, "every resolved town slot loads its GLB instead of a blockout")
	assert_eq(port.skyline_building_count(), 0, "a mounted town kit replaces the L2 skyline")
	assert_eq(port.skyline_crane_count(), 0, "a mounted town kit replaces the L2 cranes")

	# The painted L1 banner and the town kit are independent layers.
	host.bind_view_model(_port_view("medium", PORT_FACILITIES, {
		"town_visuals": TOWN_VISUALS,
		"banner_path": IRON_HARBOR_BANNER,
	}))
	assert_true(port.has_backdrop(), "the authored banner still loads with a town kit bound")
	assert_eq(
		port.town_prop_count(),
		int(TOWN_DENSITY_COUNTS["normal"]),
		"the town kit stays mounted under a painted banner"
	)
	assert_eq(port.town_blockout_count(), 0, "the banner does not disturb the town kit")
	_free_host(host)


func test_port_stage_town_density_scales_with_size_and_override() -> void:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	var stage: Variant = bundle["stage"]
	assert_true(bool(bundle["loaded"]) and stage is PortStage, "the port stage scene loads")
	if not (stage is PortStage):
		_free_host(host)
		return
	var port := stage as PortStage

	# size derives the density tier when no explicit density is bound.
	host.bind_view_model(_port_view("small", PORT_FACILITIES, {"town_visuals": TOWN_VISUALS}))
	assert_eq(port.town_density(), "sparse", "small ports default to the sparse street density")
	assert_eq(port.town_prop_count(), int(TOWN_DENSITY_COUNTS["sparse"]), "sparse mounts 28 street props")
	host.bind_view_model(_port_view("medium", PORT_FACILITIES, {"town_visuals": TOWN_VISUALS}))
	assert_eq(port.town_density(), "normal", "medium ports default to normal density")
	assert_eq(port.town_prop_count(), int(TOWN_DENSITY_COUNTS["normal"]), "normal mounts 47 street props")
	host.bind_view_model(_port_view("large", PORT_FACILITIES, {"town_visuals": TOWN_VISUALS}))
	assert_eq(port.town_density(), "busy", "large ports default to the busy street density")
	assert_eq(port.town_prop_count(), int(TOWN_DENSITY_COUNTS["busy"]), "busy mounts 63 street props")

	# An explicit density wins over the size default.
	host.bind_view_model(_port_view("small", PORT_FACILITIES, {
		"town_visuals": TOWN_VISUALS,
		"density": "busy",
	}))
	assert_eq(port.town_density(), "busy", "an explicit density beats the size default")
	assert_eq(port.town_prop_count(), int(TOWN_DENSITY_COUNTS["busy"]), "the explicit busy density mounts 63 props")

	# The shell also forwards the same value inside port.diorama.
	host.bind_view_model(_port_view("medium", PORT_FACILITIES, {
		"town_visuals": TOWN_VISUALS,
		"diorama": {"density": "sparse"},
	}))
	assert_eq(port.town_density(), "sparse", "port.diorama.density is honoured")
	assert_eq(port.town_prop_count(), int(TOWN_DENSITY_COUNTS["sparse"]), "the diorama sparse density mounts 28 props")

	# Unknown density never breaks the stage: fall back to the size default.
	host.bind_view_model(_port_view("medium", PORT_FACILITIES, {
		"town_visuals": TOWN_VISUALS,
		"density": "ultra",
	}))
	assert_eq(port.town_density(), "normal", "an unknown density falls back to the size default")
	assert_eq(port.town_prop_count(), int(TOWN_DENSITY_COUNTS["normal"]), "the fallback density mounts the normal street")

	# Deterministic layout: binding the same ViewModel twice mounts the same set.
	host.bind_view_model(_port_view("medium", PORT_FACILITIES, {"town_visuals": TOWN_VISUALS}))
	assert_eq(port.town_prop_count(), int(TOWN_DENSITY_COUNTS["normal"]), "re-binding the same port keeps the same street layout")
	_free_host(host)


func test_port_stage_town_kit_does_not_require_every_optional_slot() -> void:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	var stage: Variant = bundle["stage"]
	assert_true(bool(bundle["loaded"]) and stage is PortStage, "the port stage scene loads")
	if not (stage is PortStage):
		_free_host(host)
		return
	var port := stage as PortStage

	# Old saves resolve the original ten slots only: new slots are simply absent
	# (fewer props), never an error or an empty anchor.
	var legacy := TOWN_VISUALS.duplicate(true)
	for slot in ["market_stall", "harbor_crane", "sack_pile", "plate_stack", "ore_pile",
			"pallet", "gangway", "mooring_bollard", "capstan", "buoy"]:
		legacy.erase(String(slot))
	host.bind_view_model(_port_view("medium", PORT_FACILITIES, {"town_visuals": legacy}))
	assert_eq(port.town_density(), "normal", "the density tier still resolves without the new slots")
	assert_eq(port.town_prop_count(), 30, "only the authored 30 street props mount when the new slots are absent")
	assert_eq(port.town_blockout_count(), 0, "missing optional slots are skipped, not blockout-filled")
	assert_eq(port.skyline_building_count(), 0, "the mounted town kit still suppresses the L2 skyline")
	_free_host(host)


func test_port_stage_without_town_kit_uses_blockouts_and_keeps_skyline() -> void:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	var stage: Variant = bundle["stage"]
	assert_true(bool(bundle["loaded"]) and stage is PortStage, "the port stage scene loads")
	if not (stage is PortStage):
		_free_host(host)
		return
	var port := stage as PortStage

	host.bind_view_model(_port_view("medium", PORT_FACILITIES))
	assert_eq(port.town_prop_count(), 5, "the five town buildings fall back to blockouts")
	assert_eq(port.town_blockout_count(), 5, "every missing building visual is a blockout")
	assert_eq(port.skyline_building_count(), 10, "without a town kit the L2 skyline is still built")
	assert_true(port.skyline_crane_count() >= 2, "without a town kit the L2 cranes are still built")
	assert_false(port.has_backdrop(), "the banner-less fixture also has no town kit")
	_free_host(host)


func test_port_stage_falls_back_to_blockouts_for_missing_town_models() -> void:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	var stage: Variant = bundle["stage"]
	assert_true(bool(bundle["loaded"]) and stage is PortStage, "the port stage scene loads")
	if not (stage is PortStage):
		_free_host(host)
		return
	var port := stage as PortStage

	# One broken building visual: only that slot degenerates to a blockout.
	var partial := TOWN_VISUALS.duplicate(true)
	partial["warehouse_long"] = TOWN_MISSING_MODEL
	host.bind_view_model(_port_view("medium", PORT_FACILITIES, {"town_visuals": partial}))
	assert_eq(port.town_blockout_count(), 1, "only the broken building falls back to a blockout")
	assert_eq(
		port.town_prop_count(),
		int(TOWN_DENSITY_COUNTS["normal"]),
		"the other town props still mount"
	)
	assert_eq(port.skyline_building_count(), 0, "a mounted town kit still suppresses the L2 skyline")

	# Every path broken: the five buildings stay as blockouts, the optional
	# fence/worker/prop/boat slots disappear instead of becoming empty anchors.
	var broken := TOWN_VISUALS.duplicate(true)
	for slot in broken.keys():
		broken[String(slot)] = TOWN_MISSING_MODEL
	host.bind_view_model(_port_view("medium", PORT_FACILITIES, {"town_visuals": broken}))
	assert_eq(port.town_blockout_count(), 5, "every missing building falls back to its blockout")
	assert_eq(port.town_prop_count(), 5, "only the five building blockouts remain")
	_free_host(host)


func test_port_view_resolves_town_visuals_for_the_port_stage() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var started := context.commands.execute(&"run.start", {"starting_scenario": STEADY_BUILD, "seed": 13013})
	assert_true(bool(started.get("ok", false)), "run.start succeeds in the port-view fixture: %s" % str(started))
	var result := context.queries.execute(&"port.view")
	assert_true(bool(result.get("ok", false)), "port.view answers after run.start: %s" % str(result))
	var data: Dictionary = result.get("data", {})
	var current_port: Dictionary = data.get("current_port", {})
	assert_false(current_port.is_empty(), "port.view reports the current port")

	var town: Dictionary = current_port.get("town_visuals", {})
	assert_true(town.size() >= 26, "port.view resolves the extended town kit slots: %d" % town.size())
	for slot in ["warehouse_long", "rowboat", "crate", "gas_lamp",
			"market_stall", "harbor_crane", "sack_pile", "plate_stack", "ore_pile",
			"pallet", "gangway", "mooring_bollard", "capstan", "buoy"]:
		assert_true(town.has(String(slot)), "the resolved town kit exposes the %s slot" % slot)
	for slot in town.keys():
		var path := String(town[slot])
		assert_true(path.begins_with("res://"), "town slot %s resolves to a res:// path: %s" % [slot, path])
		assert_true(FileAccess.file_exists(path), "town slot %s resolves to an existing file: %s" % [slot, path])
	var diorama: Dictionary = current_port.get("diorama", {})
	assert_false(
		String(diorama.get("kit", "")).is_empty(),
		"port.view keeps the diorama kit id: %s" % String(diorama.get("kit", ""))
	)
	var landmark_path := String(current_port.get("landmark_path", ""))
	assert_true(
		landmark_path.begins_with("res://"),
		"port.view resolves the iron-harbor landmark GLB: %s" % landmark_path
	)
	assert_true(
		FileAccess.file_exists(landmark_path),
		"the resolved landmark GLB exists: %s" % landmark_path
	)
	assert_true(
		landmark_path.ends_with("SN_Grand_Harbour_Terminal.glb"),
		"the resolved landmark is the grand harbour terminal: %s" % landmark_path
	)
	var size := String(current_port.get("size", ""))
	assert_true(["small", "medium", "large"].has(size), "the current port reports a known size: %s" % size)

	# End to end: the ViewModel the page would bind mounts the terminal facade
	# (minimal stage mode) plus a small curated set of dock decorations.
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	var stage: Variant = bundle["stage"]
	assert_true(bool(bundle["loaded"]) and stage is PortStage, "the port stage scene loads")
	if stage is PortStage:
		host.bind_view_model({"port": current_port})
		var port := stage as PortStage
		var minimal := not landmark_path.is_empty()
		var expected_street := int(TOWN_DENSITY_COUNTS.get(port.town_density(), -1))
		assert_true(expected_street > 0, "the resolved port reports a known density tier: %s" % port.town_density())
		if minimal:
			assert_true(
				port.town_prop_count() > 0 and port.town_prop_count() <= 16,
				"the terminal facade keeps only a small decoration set: %d" % port.town_prop_count()
			)
		else:
			assert_eq(
				port.town_prop_count(),
				expected_street,
				"the resolved query ViewModel mounts the full %s streetscape" % port.town_density()
			)
		assert_eq(port.town_blockout_count(), 0, "every resolved town visual replaces its blockout")
		var landmark := port.find_child("Landmark", true, false)
		assert_true(landmark is Node3D, "the resolved landmark mounts as a Node3D")
		if landmark is Node3D:
			assert_eq(
				(landmark as Node3D).scale,
				Vector3.ONE * PortStage.LANDMARK_SCALE,
				"the landmark uses the stage's background scale"
			)
			assert_eq(
				(landmark as Node3D).rotation_degrees.y,
				PortStage.LANDMARK_YAW,
				"the landmark faces the fixed camera"
			)
			assert_eq(
				(landmark as Node3D).position,
				PortStage.LANDMARK_POS,
				"the landmark sits on the harbour centre line"
			)
	_free_host(host)


# --- 9. PortStage static batching + painted backdrop depth -------------------


func test_port_stage_batches_static_layers_into_few_draws() -> void:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	var stage: Variant = bundle["stage"]
	assert_true(bool(bundle["loaded"]) and stage is PortStage, "the port stage scene loads")
	if not (stage is PortStage):
		_free_host(host)
		return
	var port := stage as PortStage

	host.bind_view_model(_port_view("medium", PORT_FACILITIES, {"town_visuals": TOWN_VISUALS}))
	var stats: Dictionary = port.batch_stats()
	assert_true(int(stats["batches"]) > 0, "the static town/facility layers produce draw batches")
	assert_eq(
		int(stats["batches"]),
		int(stats["multimesh_batches"]) + int(stats["material_batches"]),
		"the batch count is the sum of MultiMesh and material-merge batches"
	)
	assert_true(int(stats["multimesh_batches"]) > 0, "procedural boxes batch through MultiMesh")
	assert_true(int(stats["material_batches"]) > 0, "content-kit GLB surfaces merge by material")
	assert_true(
		int(stats["meshes_before"]) > int(stats["meshes_after"]),
		"batching reduces the draw-mesh count: %d -> %d" % [int(stats["meshes_before"]), int(stats["meshes_after"])]
	)
	assert_true(
		int(stats["surfaces_before"]) > int(stats["surfaces_after"]),
		"batching reduces the surface/draw-call estimate: %d -> %d" % [int(stats["surfaces_before"]), int(stats["surfaces_after"])]
	)

	# Batching must not disturb the 2D hotspot contract.
	var anchors := port.facility_anchors()
	assert_eq(anchors.size(), PORT_FACILITIES.size(), "every present facility still exposes an anchor after batching")
	for facility in PORT_FACILITIES:
		assert_true(anchors.has(facility), "the %s anchor survives batching" % facility)
		var screen_anchor := port.facility_screen_anchor(facility)
		assert_true(
			is_finite(screen_anchor.x) and is_finite(screen_anchor.y),
			"the %s projected anchor stays finite after batching" % facility
		)

	# Batch stats are per-bind, not cumulative.
	var normal_meshes := int(stats["meshes_before"])
	host.bind_view_model(_port_view("medium", PORT_FACILITIES, {
		"town_visuals": TOWN_VISUALS,
		"density": "busy",
	}))
	var busy: Dictionary = port.batch_stats()
	assert_true(
		int(busy["meshes_before"]) > normal_meshes,
		"a denser bind mounts more street nodes before batching: %d -> %d" % [normal_meshes, int(busy["meshes_before"])]
	)
	assert_true(
		int(busy["meshes_after"]) < int(busy["meshes_before"]),
		"the busy street is batched as well: %d -> %d" % [int(busy["meshes_before"]), int(busy["meshes_after"])]
	)
	assert_true(int(busy["batches"]) > 0, "the busy street still batches")
	_free_host(host)


func test_port_stage_without_town_still_batches_facilities() -> void:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	var stage: Variant = bundle["stage"]
	assert_true(bool(bundle["loaded"]) and stage is PortStage, "the port stage scene loads")
	if not (stage is PortStage):
		_free_host(host)
		return
	var port := stage as PortStage

	host.bind_view_model(_port_view("medium", PORT_FACILITIES))
	var stats: Dictionary = port.batch_stats()
	assert_true(int(stats["batches"]) > 0, "the procedural facility billboards still batch without a town kit")
	assert_true(
		int(stats["meshes_after"]) < int(stats["meshes_before"]),
		"the facility-only stage still drops draw meshes: %d -> %d" % [int(stats["meshes_before"]), int(stats["meshes_after"])]
	)
	assert_eq(port.town_prop_count(), 5, "the five town blockouts stay mounted")
	_free_host(host)


func test_port_stage_painted_backdrop_has_depth_layers_without_banner() -> void:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	var stage: Variant = bundle["stage"]
	assert_true(bool(bundle["loaded"]) and stage is PortStage, "the port stage scene loads")
	if not (stage is PortStage):
		_free_host(host)
		return
	var port := stage as PortStage

	# No banner + town: the town kit replaces the L2 row, but the painted far
	# backdrop still supplies mountain/city/roofline depth behind it.
	host.bind_view_model(_port_view("medium", PORT_FACILITIES, {"town_visuals": TOWN_VISUALS}))
	assert_false(port.has_backdrop(), "the painted-backdrop fixture has no banner")
	var town_layers := port.painted_backdrop_layer_count()
	assert_eq(town_layers, 3, "the no-banner town stage paints exactly 3 far backdrop layers")
	assert_eq(port.skyline_building_count(), 0, "the mounted town kit still suppresses the L2 row")

	# No banner + no town: the L2 silhouette row returns and the painted layers
	# stay mounted (both read as distance behind the empty plaza).
	host.bind_view_model(_port_view("medium", PORT_FACILITIES))
	assert_false(port.has_backdrop(), "still no banner")
	assert_eq(port.painted_backdrop_layer_count(), town_layers, "the painted far layers survive a town-less bind")
	assert_eq(port.skyline_building_count(), 10, "the procedural L2 skyline returns without a town kit")

	# A painted L1 banner replaces the whole fallback backdrop: the painted
	# depth layers and the L2 row must both disappear.
	host.bind_view_model(_port_view("medium", PORT_FACILITIES, {"banner_path": IRON_HARBOR_BANNER}))
	assert_true(port.has_backdrop(), "the authored banner loads")
	assert_eq(port.painted_backdrop_layer_count(), 0, "a painted banner hides the painted depth layers")
	assert_eq(port.skyline_building_count(), 0, "a painted banner still hides the L2 skyline")
	var fallback := port.get_node_or_null("FallbackBackdrop")
	assert_not_null(fallback, "the fallback backdrop group stays mounted for banner-less ports")
	if fallback != null:
		assert_false((fallback as Node3D).visible, "the fallback backdrop group is hidden under a banner")

	# Dropping the banner brings the painted depth back.
	host.bind_view_model(_port_view("medium", PORT_FACILITIES))
	assert_eq(port.painted_backdrop_layer_count(), town_layers, "the painted depth layers return when the banner is dropped")
	if fallback != null:
		assert_true((fallback as Node3D).visible, "the fallback backdrop group is visible again")
	_free_host(host)


# --- 10. PortStage rigid player-hull batching -------------------------------


func test_port_stage_batches_player_hull_rigidly_and_keeps_foam_bounds() -> void:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	var stage: Variant = bundle["stage"]
	assert_true(bool(bundle["loaded"]) and stage is PortStage, "the port stage scene loads")
	if not (stage is PortStage):
		_free_host(host)
		return
	var port := stage as PortStage
	host.bind_view_model({
		"port": {"id": "test_harbor", "size": "medium", "facilities": PORT_FACILITIES},
		"ship": {"hull_model_path": STEAMER_MODEL, "hull_tier": 1},
	})
	assert_true(port.has_ship(), "the player hull stays mounted after rigid batching")
	var stats: Dictionary = port.batch_stats()
	assert_false(bool(stats["ship_fallback"]), "the rigid paddle-steamer hull batches instead of falling back")
	assert_eq(
		int(stats["ship_batches"]),
		int(stats["ship_multimesh_batches"]) + int(stats["ship_material_batches"]),
		"the ship batch count is the sum of its MultiMesh and material batches"
	)
	assert_true(
		int(stats["ship_surfaces_before"]) >= 40,
		"the fixture hull really is multi-surface: %d" % int(stats["ship_surfaces_before"])
	)
	assert_true(
		int(stats["ship_surfaces_after"]) * 3 <= int(stats["ship_surfaces_before"]),
		"hull batching drops surfaces by at least 3x: %d -> %d" % [
			int(stats["ship_surfaces_before"]), int(stats["ship_surfaces_after"])
		]
	)
	assert_true(
		int(stats["ship_meshes_after"]) < int(stats["ship_meshes_before"]),
		"hull batching drops draw meshes: %d -> %d" % [
			int(stats["ship_meshes_before"]), int(stats["ship_meshes_after"])
		]
	)

	# The batches stay under the animated ship root, so the bob/turn keeps
	# moving the whole ship.
	var ship_node := port.get_node_or_null("Content/PlayerShip")
	assert_not_null(ship_node, "the PlayerShip root stays in Content")
	if ship_node != null:
		assert_not_null(ship_node.get_node_or_null("ShipBatches"), "the hull batches live under the animated ship root")

	# The foam ring was configured from the un-batched hull; it must still match
	# a freshly instantiated copy of the authored hull positioned like the ship.
	var foam := port.ship_foam_bounds()
	assert_true(
		foam.size.x > 1.0 and foam.size.y > 1.0 and foam.size.z > 1.0,
		"the foam bounds capture the authored hull size: %s" % str(foam.size)
	)
	var packed := load(STEAMER_MODEL) as PackedScene
	assert_not_null(packed, "the authored steamer hull loads as a PackedScene")
	if packed != null:
		var fresh := packed.instantiate()
		var holder := Node3D.new()
		holder.name = "HullReference"
		holder.position = PortStage.SHIP_SPAWN
		holder.rotation = Vector3(0.0, deg_to_rad(PortStage.SHIP_YAW_DEG), 0.0)
		holder.scale = Vector3.ONE * PortStage.SHIP_SCALE
		holder.add_child(fresh)
		var expected := StageKit.visual_aabb(holder)
		holder.free()
		assert_true(expected.size.length() > 1.0, "the authored hull has a non-degenerate size")
		assert_almost_eq(foam.size.x, expected.size.x, 0.01, "foam bounds keep the authored hull width")
		assert_almost_eq(foam.size.y, expected.size.y, 0.01, "foam bounds keep the authored hull height")
		assert_almost_eq(foam.size.z, expected.size.z, 0.01, "foam bounds keep the authored hull length")
		assert_true(
			foam.position.distance_to(expected.position) < 0.01,
			"foam bounds keep the authored hull AABB position: %s vs %s" % [str(foam.position), str(expected.position)]
		)
	_free_host(host)


func test_port_stage_ship_batching_falls_back_for_non_rigid_hulls() -> void:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	var stage: Variant = bundle["stage"]
	assert_true(bool(bundle["loaded"]) and stage is PortStage, "the port stage scene loads")
	if not (stage is PortStage):
		_free_host(host)
		return
	var port := stage as PortStage
	host.bind_view_model({
		"port": {"id": "test_harbor", "size": "medium", "facilities": PORT_FACILITIES},
		"ship": {"hull_model_path": STEAMER_MODEL, "hull_tier": 1},
	})
	assert_false(bool(port.batch_stats()["ship_fallback"]), "the fallback flag defaults to false for the rigid steamer")
	var ship_node := port.get_node_or_null("Content/PlayerShip")
	assert_not_null(ship_node, "the player ship root is mounted")
	if ship_node != null:
		assert_true(port.ship_visual_is_rigid(ship_node), "the batched steamer hull is recognised as rigid")

	# Animation -> whole-hull fallback.
	var animated := Node3D.new()
	animated.add_child(AnimationPlayer.new())
	assert_false(port.ship_visual_is_rigid(animated), "an animated hull is rejected (safe fallback)")
	animated.free()

	# Skeleton/bones -> whole-hull fallback.
	var skinned := Node3D.new()
	skinned.add_child(Skeleton3D.new())
	assert_false(port.ship_visual_is_rigid(skinned), "a skeleton hull is rejected (safe fallback)")
	skinned.free()

	# Particles -> whole-hull fallback.
	var particle_visual := Node3D.new()
	particle_visual.add_child(GPUParticles3D.new())
	assert_false(port.ship_visual_is_rigid(particle_visual), "a particle hull is rejected (safe fallback)")
	particle_visual.free()

	# Transparent material -> whole-hull fallback (sorting must stay correct).
	var transparent_visual := Node3D.new()
	var transparent_instance := MeshInstance3D.new()
	transparent_instance.mesh = BoxMesh.new()
	var alpha_material := StandardMaterial3D.new()
	alpha_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	transparent_instance.material_override = alpha_material
	transparent_visual.add_child(transparent_instance)
	assert_false(port.ship_visual_is_rigid(transparent_visual), "a transparent hull material is rejected (safe fallback)")
	transparent_visual.free()

	# Sanity: the predicate is not always false — a plain opaque rigid hull works.
	var rigid_visual := Node3D.new()
	var box_instance := MeshInstance3D.new()
	box_instance.mesh = BoxMesh.new()
	rigid_visual.add_child(box_instance)
	assert_true(port.ship_visual_is_rigid(rigid_visual), "a plain rigid hull is accepted")
	rigid_visual.free()
	_free_host(host)

# --- 11. Adjacent stations (continuous harbour district) ---------------------


## The three stations are adjacent on one quay: ordered in world X, tens of
## metres apart, sharing one lens, and the panel framing is the same shot shifted
## a few metres (not a different camera setup).
func test_port_stage_stations_are_adjacent_along_one_quay() -> void:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	var stage: Variant = bundle["stage"]
	assert_true(bool(bundle["loaded"]) and stage is PortStage, "the port stage scene loads")
	if not (stage is PortStage):
		_free_host(host)
		return
	var port := stage as PortStage

	var ids := port.station_ids()
	assert_eq(ids.size(), 4, "the district exposes four adjacent stations")
	if ids.size() == 4:
		assert_eq(String(ids[0]), "market", "the market is the west station")
		assert_eq(String(ids[1]), "harbor", "the harbour authority is the centre station")
		assert_eq(String(ids[2]), "shipyard", "the shipyard dry dock sits east of the harbour")
		assert_eq(String(ids[3]), "supply", "the supply yard is the east station")
	assert_eq(port.current_station(), "harbor", "the stage starts on the harbour reference shot")

	var market_x := port.station_ship_position("market").x
	var harbor_x := port.station_ship_position("harbor").x
	var supply_x := port.station_ship_position("supply").x
	assert_true(market_x < harbor_x and harbor_x < supply_x, "the berths are ordered west -> east")
	assert_true(
		supply_x - market_x >= 50.0,
		"adjacent stations are far enough apart to read as a pan: %.1f m" % (supply_x - market_x)
	)

	# Same lens for every station, only the position/target move along the quay.
	var market_pose := port.station_camera_pose("market")
	var harbor_pose := port.station_camera_pose("harbor")
	assert_almost_eq(float(market_pose["fov"]), float(harbor_pose["fov"]), 0.001, "stations share one lens")
	var market_camera: Vector3 = market_pose["position"]
	var harbor_camera: Vector3 = harbor_pose["position"]
	assert_true(market_camera.x < harbor_camera.x, "the market shot stands west of the harbour shot")

	# The panel framing keeps the same shot and only shifts it so the landmark
	# stays clear of the 620 px dock panel on the market / supply pages.
	var panel_pose := port.station_camera_pose("market", "panel")
	var panel_camera: Vector3 = panel_pose["position"]
	assert_almost_eq(
		panel_camera.x - market_camera.x,
		PortStage.PANEL_FRAMING_SHIFT_X,
		0.001,
		"panel framing shifts the station shot by the documented offset"
	)
	assert_true(
		not port.focus_station("nowhere"),
		"an unknown station id is rejected instead of moving the camera"
	)
	assert_eq(port.current_station(), "harbor", "a rejected station keeps the current shot")
	_free_host(host)


## Focus a station: the camera pans and the hull sails to that berth, while the
## district nodes (town, facilities, hull root) are reused, never rebuilt.
func test_port_stage_focus_station_pans_camera_and_sails_the_hull() -> void:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	var stage: Variant = bundle["stage"]
	assert_true(bool(bundle["loaded"]) and stage is PortStage, "the port stage scene loads")
	if not (stage is PortStage):
		_free_host(host)
		return
	var port := stage as PortStage
	host.bind_view_model(_port_view("medium", PORT_FACILITIES, {"town_visuals": TOWN_VISUALS}))
	var ship_root := port.get_node_or_null("Content/PlayerShip")
	var town_props := port.town_prop_count()
	var station_props := port.station_prop_count()
	assert_eq(port.current_station(), "harbor", "the fixture starts at the harbour station")
	assert_almost_eq(port.ship_x(), port.station_ship_position("harbor").x, 0.05, "the hull moors at the harbour berth")

	assert_true(port.focus_station("market"), "focus_station accepts the market station")
	assert_eq(port.current_station(), "market", "the stage reports the market shot")
	assert_true(port.is_station_transitioning(), "a station switch starts a visible transition")
	port.advance_station(0.3)
	assert_true(port.is_station_transitioning(), "the camera is still panning after 0.3 s")
	port.advance_station(10.0)
	assert_false(port.is_station_transitioning(), "the pan and the sail settle")
	var market_camera: Vector3 = port.station_camera_pose("market")["position"]
	assert_almost_eq(
		port.camera_position().distance_to(market_camera),
		0.0,
		0.05,
		"the camera lands on the market shot"
	)
	var market_berth := port.station_ship_position("market").x
	assert_almost_eq(
		port.ship_x(),
		market_berth,
		0.3,
		"the hull sails to the market berth (%.1f -> %.1f)" % [
			port.station_ship_position("harbor").x, market_berth
		]
	)

	# The district was not rebuilt: same hull root, same prop counts, same
	# facility assembly. Only the shot and the hull moved.
	assert_eq(port.get_node_or_null("Content/PlayerShip"), ship_root, "the hull root is reused across stations")
	assert_eq(port.town_prop_count(), town_props, "the town kit is not rebuilt")
	assert_eq(port.station_prop_count(), station_props, "the station dressing is not rebuilt")
	assert_eq(port.facility_count(), PORT_FACILITIES.size(), "the facilities stay assembled")

	# The next adjacent station pans the other way and sails the hull back.
	assert_true(port.focus_station("supply"), "focus_station accepts the supply station")
	port.advance_station(0.3)
	assert_true(
		port.ship_x() > market_berth,
		"the hull is already sailing east towards the supply yard"
	)
	port.advance_station(10.0)
	assert_false(port.is_station_transitioning(), "the second transition settles")
	var supply_camera: Vector3 = port.station_camera_pose("supply")["position"]
	assert_almost_eq(port.camera_position().distance_to(supply_camera), 0.0, 0.05, "the camera lands on the supply shot")
	assert_almost_eq(
		port.ship_x(),
		port.station_ship_position("supply").x,
		0.3,
		"the hull moors at the supply berth"
	)
	_free_host(host)


## Immediate focus (used when the stage mounts straight onto a page) snaps both
## the shot and the berth, and re-focusing the same station is a no-op.
func test_port_stage_focus_station_immediate_and_idempotent() -> void:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	var stage: Variant = bundle["stage"]
	assert_true(bool(bundle["loaded"]) and stage is PortStage, "the port stage scene loads")
	if not (stage is PortStage):
		_free_host(host)
		return
	var port := stage as PortStage
	host.bind_view_model(_port_view("medium", PORT_FACILITIES))

	assert_true(port.focus_station("market", "panel", true), "an immediate focus is accepted")
	assert_eq(port.current_station_framing(), "panel", "the panel framing is remembered")
	assert_false(port.is_station_transitioning(), "an immediate focus snaps instead of animating")
	var panel_camera: Vector3 = port.station_camera_pose("market", "panel")["position"]
	assert_almost_eq(port.camera_position().distance_to(panel_camera), 0.0, 0.01, "the camera snaps to the panel shot")
	assert_almost_eq(
		port.ship_x(),
		port.station_ship_position("market").x,
		0.01,
		"the hull snaps to the market berth"
	)
	var pose_before := port.camera_position()
	assert_true(port.focus_station("market", "panel"), "re-focusing the current station succeeds")
	assert_false(port.is_station_transitioning(), "re-focusing does not restart the transition")
	assert_true(pose_before.is_equal_approx(port.camera_position()), "re-focusing keeps the settled shot")
	_free_host(host)


## A bind rebuild (cargo/ship change) must keep the current station: the new hull
## is mounted at that berth and the camera stays where the player left it.
func test_port_stage_bind_keeps_the_current_station_and_berth() -> void:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	var stage: Variant = bundle["stage"]
	assert_true(bool(bundle["loaded"]) and stage is PortStage, "the port stage scene loads")
	if not (stage is PortStage):
		_free_host(host)
		return
	var port := stage as PortStage
	host.bind_view_model({
		"port": {"id": "test_harbor", "size": "medium", "facilities": PORT_FACILITIES},
		"ship": {"hull_model_path": STEAMER_MODEL, "hull_tier": 1},
	})
	port.focus_station("supply", "panel", true)
	var supply_x := port.station_ship_position("supply").x
	var supply_camera: Vector3 = port.station_camera_pose("supply", "panel")["position"]

	# Different ship -> new bind signature -> a real rebuild.
	host.bind_view_model({
		"port": {"id": "test_harbor", "size": "medium", "facilities": PORT_FACILITIES},
		"ship": {"hull_model_path": "", "hull_tier": 2},
	})
	assert_eq(port.current_station(), "supply", "the rebuild keeps the supply station")
	assert_eq(port.current_station_framing(), "panel", "the rebuild keeps the framing")
	assert_almost_eq(
		port.camera_position().distance_to(supply_camera),
		0.0,
		0.05,
		"the rebuild keeps the camera on the current station shot"
	)
	var ship := port.get_node_or_null("Content/PlayerShip")
	assert_not_null(ship, "the rebuilt hull is mounted")
	if ship != null:
		assert_almost_eq(
			(ship as Node3D).position.x,
			supply_x,
			0.3,
			"the rebuilt hull is mounted at the supply berth, not the reference spawn"
		)
	_free_host(host)


## Each station gets its own dressing props, scaled by the street density tier.
func test_port_stage_station_dressing_scales_with_density() -> void:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	var stage: Variant = bundle["stage"]
	assert_true(bool(bundle["loaded"]) and stage is PortStage, "the port stage scene loads")
	if not (stage is PortStage):
		_free_host(host)
		return
	var port := stage as PortStage

	for size in ["small", "medium", "large"]:
		host.bind_view_model(_port_view(size, PORT_FACILITIES, {"town_visuals": TOWN_VISUALS}))
		var expected := int(STATION_DENSITY_COUNTS[PortStage.DENSITY_BY_SIZE[size]])
		assert_eq(
			port.station_prop_count(),
			expected,
			"size=%s mounts %d station dressing props" % [size, expected]
		)
	host.bind_view_model(_port_view("medium", PORT_FACILITIES, {"town_visuals": TOWN_VISUALS, "density": "busy"}))
	assert_eq(port.station_prop_count(), int(STATION_DENSITY_COUNTS["busy"]), "diorama.density=busy mounts the busy station dressing")

	# Without the town kit the station dressing has no visuals to mount; the
	# stage still keeps its blockout town and never invents placeholder props.
	host.bind_view_model(_port_view("medium", PORT_FACILITIES))
	assert_eq(port.station_prop_count(), 0, "a content-less stage mounts no station dressing")
	assert_true(port.town_prop_count() >= 5, "the blockout town still carries the silhouette")
	_free_host(host)

func test_port_stage_redirect_mid_transition_continues_from_current_pose() -> void:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	var stage: Variant = bundle["stage"]
	assert_true(bool(bundle["loaded"]) and stage is PortStage, "the port stage scene loads")
	if not (stage is PortStage):
		_free_host(host)
		return
	var port := stage as PortStage
	host.bind_view_model(_port_view("medium", PORT_FACILITIES))

	# Start a pan to the market, then redirect to the supply before it settles.
	assert_true(port.focus_station("market"), "the first station switch starts")
	port.advance_station(0.2)
	var mid_position := port.camera_position()
	var mid_shot: Vector3 = port.station_camera_pose("market")["position"]
	assert_true(
		mid_position.distance_to(mid_shot) > 1.0,
		"the camera really is mid-pan (%.1f m from the market shot)" % mid_position.distance_to(mid_shot)
	)
	assert_true(port.focus_station("supply"), "a redirect during the pan is accepted")
	assert_true(
		port.camera_position().distance_to(mid_position) < 0.01,
		"redirecting leaves the camera where it is (no snap)"
	)
	port.advance_station(0.05)
	var step := port.camera_position().distance_to(mid_position)
	assert_true(
		step < 3.0,
		"the redirect continues from the current pose instead of jumping to the old target (%.2f m in 0.05 s)" % step
	)
	port.advance_station(10.0)
	assert_false(port.is_station_transitioning(), "the redirected transition still settles")
	var supply_shot: Vector3 = port.station_camera_pose("supply")["position"]
	assert_almost_eq(
		port.camera_position().distance_to(supply_shot),
		0.0,
		0.05,
		"the redirected transition lands on the supply shot"
	)
	_free_host(host)

# --- 10. Voyage departure / arrival beat (nautical chart phase 3) -------------


## Mounts + binds the authored port stage for the voyage-beat cases. The caller
## frees `host`; an empty dictionary means the scene did not mount a PortStage
## (the assertion was already recorded, the test just bails out).
func _bound_port_stage() -> Dictionary:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	var stage: Variant = bundle["stage"]
	if not (bool(bundle["loaded"]) and stage is PortStage):
		assert_true(false, "the port stage scene mounts a PortStage")
		_free_host(host)
		return {}
	var port := stage as PortStage
	host.bind_view_model(_port_view("medium", PORT_FACILITIES))
	host.set_stage_visible(true)
	return {"host": host, "stage": port}


## Heading the departure cut must end on: berth -> SEA_HANDOFF in XZ. The model's
## bow points at +X at yaw 0 and Godot's positive Y rotation takes +X toward -Z,
## so a direction (dx, dz) is yaw = atan2(-dz, dx) — the same convention the
## station transit uses.
func _outbound_yaw_for(port: PortStage) -> float:
	var berth := port.station_ship_position(port.current_station())
	var delta := PortStage.SEA_HANDOFF - Vector3(berth.x, 0.0, berth.z)
	return atan2(-delta.z, delta.x)


## The departure cut is a real 3D move: the hull sails from its berth toward the
## harbour mouth while the camera climbs to the high, wide shot. The hull must be
## exactly on `SEA_HANDOFF` when the beat ends — that is the point the chart's
## ship marker takes over from.
func test_port_stage_departure_beat_sails_to_the_sea_handoff() -> void:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	assert_true(bool(bundle["loaded"]), "the port stage scene loads")
	var stage: Variant = bundle["stage"]
	if not (stage is PortStage):
		assert_true(false, "the port stage scene mounts a PortStage")
		_free_host(host)
		return
	var port := stage as PortStage
	host.bind_view_model(_port_view("medium", PORT_FACILITIES))
	host.set_stage_visible(true)
	var berth := port.station_ship_position(port.current_station())
	var camera_before := port.camera_position()

	port.begin_departure(PortStage.VOYAGE_BEAT_SECONDS)
	assert_eq(String(port.voyage_mode()), "depart", "the stage reports the departure beat")
	assert_true(port.is_voyage_transitioning(), "the beat is running")
	# Mid-beat the hull is between the berth and the harbour mouth, and the camera
	# has already climbed: this is what the player actually sees before the clouds.
	port.advance_voyage(PortStage.VOYAGE_BEAT_SECONDS * 0.5)
	var mid := port.ship_position()
	assert_true(mid.z > berth.z, "the hull sails out to sea")
	assert_true(mid.z < PortStage.SEA_HANDOFF.z, "the hull is still short of the handoff mid-beat")
	assert_true(port.camera_position().y > camera_before.y + 1.0, "the camera climbs during the beat")

	port.advance_voyage(PortStage.VOYAGE_BEAT_SECONDS)
	assert_false(port.is_voyage_transitioning(), "the beat finishes")
	assert_eq(String(port.voyage_mode()), "", "the stage is back to idle")
	assert_true(
		port.ship_position().is_equal_approx(PortStage.SEA_HANDOFF),
		"the hull ends exactly on the sea handoff: %s" % str(port.ship_position())
	)
	assert_true(
		port.camera_position().distance_to(PortStage.DEPART_CAMERA) < 0.5,
		"the beat ends on the high departure shot"
	)
	_free_host(host)


## 离港 beat 结束后云层还没盖满：船必须停在 SEA_HANDOFF 等入港，而不是被站位
## 平移逻辑拉回泊位——否则「船消失在哪儿、海图就从哪儿出现」的接缝在 3D 侧就破了。
func test_departure_hold_keeps_the_hull_on_the_sea_handoff_until_the_cut() -> void:
	var mounted := _bound_port_stage()
	if mounted.is_empty():
		return
	var host: SNStageHost = mounted["host"]
	var port: PortStage = mounted["stage"]
	port.begin_departure(PortStage.VOYAGE_BEAT_SECONDS)
	port.advance_voyage(PortStage.VOYAGE_BEAT_SECONDS)
	assert_true(port.ship_position().is_equal_approx(PortStage.SEA_HANDOFF),
		"the hull vanished exactly on the sea handoff")
	assert_true(port.is_voyage_holding_handoff(), "a finished departure holds the handoff")

	# The stage's own frame loop must not sail the hull back to the berth while the
	# cloud veil closes over that shot.
	port._process(0.5)
	assert_true(port.ship_position().is_equal_approx(PortStage.SEA_HANDOFF),
		"the station wheel does not drag the hull back under the veil: %s" % str(port.ship_position()))
	assert_eq(String(port.voyage_mode()), "", "holding is not a beat; the shell is not stepping one")

	# The arrival beat takes over from the same point and releases the hold.
	port.begin_arrival(PortStage.VOYAGE_BEAT_SECONDS)
	assert_false(port.is_voyage_holding_handoff(), "the arrival beat releases the hold")
	port.advance_voyage(PortStage.VOYAGE_BEAT_SECONDS * 0.5)
	assert_true(port.ship_position().z < PortStage.SEA_HANDOFF.z, "the hull starts sailing in")
	_free_host(host)


## Arrival plays it backwards: the destination harbour is already on screen from
## the high shot, the camera comes down and the hull sails into its berth.
func test_port_stage_arrival_beat_moors_the_hull_back_at_its_berth() -> void:
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	assert_true(bool(bundle["loaded"]), "the port stage scene loads")
	var stage: Variant = bundle["stage"]
	if not (stage is PortStage):
		assert_true(false, "the port stage scene mounts a PortStage")
		_free_host(host)
		return
	var port := stage as PortStage
	host.bind_view_model(_port_view("medium", PORT_FACILITIES))
	host.set_stage_visible(true)
	var berth := port.station_ship_position(port.current_station())

	port.begin_arrival(PortStage.VOYAGE_BEAT_SECONDS)
	assert_eq(String(port.voyage_mode()), "arrive", "the stage reports the arrival beat")
	assert_true(
		port.ship_position().is_equal_approx(PortStage.SEA_HANDOFF),
		"arrival starts from the same handoff point the departure vanished at"
	)
	assert_true(
		port.camera_position().distance_to(PortStage.DEPART_CAMERA) < 0.5,
		"arrival opens on the high 'from the sea' shot"
	)

	var mid_camera := port.camera_position()
	port.advance_voyage(PortStage.VOYAGE_BEAT_SECONDS * 0.5)
	assert_true(port.camera_position().y < mid_camera.y, "the camera comes down into the harbour")
	assert_true(port.ship_position().z < PortStage.SEA_HANDOFF.z, "the hull sails in")

	port.advance_voyage(PortStage.VOYAGE_BEAT_SECONDS)
	assert_false(port.is_voyage_transitioning(), "the beat finishes")
	assert_true(
		port.ship_position().is_equal_approx(Vector3(berth.x, 0.0, berth.z)),
		"the hull ends on its berth: %s" % str(port.ship_position())
	)
	var station_shot: Vector3 = port.station_camera_pose(port.current_station())["position"]
	assert_true(
		port.camera_position().distance_to(station_shot) < 0.5,
		"the beat ends on the station framing"
	)
	_free_host(host)


## F1: the departure cut is a real cast-off, not a sideways slide. The hull first
## swings its bow to the outbound heading (berth -> SEA_HANDOFF) while still on
## its berth, and only then makes way. The beat ends pointing out to sea.
func test_port_stage_departure_turns_the_bow_out_to_sea_before_making_way() -> void:
	var mounted := _bound_port_stage()
	if mounted.is_empty():
		return
	var host: SNStageHost = mounted["host"]
	var port: PortStage = mounted["stage"]
	var berth := port.station_ship_position(port.current_station())
	var moor_yaw := port.station_ship_yaw(port.current_station())
	var outbound_yaw := _outbound_yaw_for(port)
	var moor_gap := absf(angle_difference(moor_yaw, outbound_yaw))
	assert_almost_eq(port.ship_yaw(), moor_yaw, 0.001, "the hull starts on its mooring yaw")

	port.begin_departure(PortStage.VOYAGE_BEAT_SECONDS)
	assert_eq(String(port.voyage_mode()), "depart", "the stage reports the departure beat")
	# 0.3 s into the 1.8 s beat: the turn is well underway but the hull still sits
	# on its berth — a sideways slide would already have moved it.
	port.advance_voyage(PortStage.VOYAGE_BEAT_SECONDS * 0.17)
	var turned := absf(angle_difference(port.ship_yaw(), outbound_yaw))
	assert_true(
		turned < moor_gap * 0.75,
		"the bow has swung toward the open sea (%.0f deg left of a %.0f deg turn)"
			% [rad_to_deg(turned), rad_to_deg(moor_gap)]
	)
	var shifted := port.ship_position().distance_to(berth)
	assert_true(
		shifted < 0.05,
		"the opening turn makes no way: hull only %.3f m from its berth" % shifted
	)

	port.advance_voyage(PortStage.VOYAGE_BEAT_SECONDS)
	assert_almost_eq(
		port.ship_yaw(), outbound_yaw, 0.001, "the beat ends pointing straight out to sea"
	)
	_free_host(host)


## F1 seam: the heading of the departure cut's last frame is the exact heading of
## the arrival cut's first frame; the arrival then swings the bow into the
## harbour and ends back on the mooring yaw.
func test_port_stage_voyage_handoff_heading_is_seamless() -> void:
	var mounted := _bound_port_stage()
	if mounted.is_empty():
		return
	var host: SNStageHost = mounted["host"]
	var port: PortStage = mounted["stage"]
	var berth := port.station_ship_position(port.current_station())
	var outbound_yaw := _outbound_yaw_for(port)

	port.begin_departure(PortStage.VOYAGE_BEAT_SECONDS)
	port.advance_voyage(PortStage.VOYAGE_BEAT_SECONDS)
	var departed_yaw := port.ship_yaw()
	assert_true(
		port.ship_position().is_equal_approx(PortStage.SEA_HANDOFF),
		"departure ends on the sea handoff: %s" % str(port.ship_position())
	)
	assert_almost_eq(departed_yaw, outbound_yaw, 0.001, "departure ends on the outbound heading")

	port.begin_arrival(PortStage.VOYAGE_BEAT_SECONDS)
	assert_almost_eq(
		port.ship_yaw(),
		departed_yaw,
		0.001,
		"arrival opens on exactly the heading the departure vanished with"
	)
	assert_true(
		port.ship_position().is_equal_approx(PortStage.SEA_HANDOFF),
		"arrival opens on the sea handoff the departure vanished at"
	)
	port.advance_voyage(PortStage.VOYAGE_BEAT_SECONDS)
	assert_almost_eq(
		port.ship_yaw(),
		port.station_ship_yaw(port.current_station()),
		0.001,
		"arrival ends back on the mooring yaw"
	)
	assert_true(
		port.ship_position().distance_to(berth) < 0.01,
		"arrival ends exactly on its berth: %s" % str(port.ship_position())
	)
	_free_host(host)


## F2-3D: the departure camera climbs to an almost vertical, high wide shot
## instead of trucking sideways. Height and pitch must be monotonic across the
## whole beat and the beat must land on the authored `DEPART_CAMERA`.
func test_port_stage_departure_camera_climbs_to_a_near_vertical_high_shot() -> void:
	var mounted := _bound_port_stage()
	if mounted.is_empty():
		return
	var host: SNStageHost = mounted["host"]
	var port: PortStage = mounted["stage"]
	var station_height := port.camera_position().y
	var station_pitch := port.camera_pitch_deg()
	assert_true(
		station_pitch < 45.0,
		"the station shot is a shallow harbour angle (%.1f deg)" % station_pitch
	)

	port.begin_departure(PortStage.VOYAGE_BEAT_SECONDS)
	var last_pitch := port.camera_pitch_deg()
	var last_height := port.camera_position().y
	var steps := 8
	for index in steps:
		port.advance_voyage(PortStage.VOYAGE_BEAT_SECONDS / float(steps))
		var pitch := port.camera_pitch_deg()
		var height := port.camera_position().y
		assert_true(
			pitch >= last_pitch - 0.001,
			"pitch never dips while climbing (step %d: %.2f -> %.2f deg)"
				% [index, last_pitch, pitch]
		)
		assert_true(
			height >= last_height - 0.001,
			"height never dips while climbing (step %d: %.2f -> %.2f m)"
				% [index, last_height, height]
		)
		last_pitch = pitch
		last_height = height
	port.advance_voyage(PortStage.VOYAGE_BEAT_SECONDS)
	assert_true(
		port.camera_pitch_deg() >= 80.0,
		"the high departure shot is almost vertical (%.1f deg)" % port.camera_pitch_deg()
	)
	assert_almost_eq(
		port.camera_position().y,
		PortStage.DEPART_CAMERA.y,
		0.01,
		"the climb ends at the authored high camera height"
	)
	assert_true(
		port.camera_position().y > station_height + 100.0,
		"the departure shot really is pulled up above the station shot"
	)
	assert_true(
		port.camera_position().distance_to(PortStage.DEPART_CAMERA) < 0.01,
		"the beat ends on the authored high shot"
	)
	_free_host(host)


## F2-3D inverse: arrival opens on the near-vertical high shot and falls back
## monotonically onto the station framing (height and pitch never rise).
func test_port_stage_arrival_camera_falls_back_to_the_station_shot() -> void:
	var mounted := _bound_port_stage()
	if mounted.is_empty():
		return
	var host: SNStageHost = mounted["host"]
	var port: PortStage = mounted["stage"]
	var station_pose := port.station_camera_pose(
		port.current_station(), port.current_station_framing()
	)
	var station_height := port.camera_position().y
	var station_pitch := port.camera_pitch_deg()

	port.begin_arrival(PortStage.VOYAGE_BEAT_SECONDS)
	assert_true(
		port.camera_pitch_deg() >= 80.0,
		"arrival opens near vertical (%.1f deg)" % port.camera_pitch_deg()
	)
	assert_almost_eq(
		port.camera_position().y,
		PortStage.DEPART_CAMERA.y,
		0.01,
		"arrival opens at the authored high camera height"
	)
	var last_pitch := port.camera_pitch_deg()
	var last_height := port.camera_position().y
	var steps := 8
	for index in steps:
		port.advance_voyage(PortStage.VOYAGE_BEAT_SECONDS / float(steps))
		var pitch := port.camera_pitch_deg()
		var height := port.camera_position().y
		assert_true(
			pitch <= last_pitch + 0.001,
			"pitch never rises while descending (step %d: %.2f -> %.2f deg)"
				% [index, last_pitch, pitch]
		)
		assert_true(
			height <= last_height + 0.001,
			"height never rises while descending (step %d: %.2f -> %.2f m)"
				% [index, last_height, height]
		)
		last_pitch = pitch
		last_height = height
	port.advance_voyage(PortStage.VOYAGE_BEAT_SECONDS)
	assert_true(
		port.camera_position().distance_to(station_pose["position"]) < 0.01,
		"arrival hands the harbour back with the station shot"
	)
	assert_almost_eq(
		port.camera_position().y, station_height, 0.01, "camera height returns to the station height"
	)
	assert_almost_eq(
		port.camera_pitch_deg(), station_pitch, 0.01, "camera pitch returns to the station pitch"
	)
	_free_host(host)
