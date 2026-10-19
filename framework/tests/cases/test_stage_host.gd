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

const PORT_FACILITIES := ["exchange", "shipyard", "intel"]
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
## Five buildings + seven repeated fence modules + six workers + eight reused
## props + three boats = 29 mounted props when every slot resolves.
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
}
const TOWN_MISSING_MODEL := "res://dev_mods/core/assets/models/props/SN_Does_Not_Exist.glb"
const STEADY_BUILD := "core:starting_build/steady"


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
	assert_eq(port.town_prop_count(), 29, "5 buildings + 7 fence modules + 6 workers + 8 props + 3 boats mount")
	assert_eq(port.town_blockout_count(), 0, "every resolved town slot loads its GLB instead of a blockout")
	assert_eq(port.skyline_building_count(), 0, "a mounted town kit replaces the L2 skyline")
	assert_eq(port.skyline_crane_count(), 0, "a mounted town kit replaces the L2 cranes")

	# The painted L1 banner and the town kit are independent layers.
	host.bind_view_model(_port_view("medium", PORT_FACILITIES, {
		"town_visuals": TOWN_VISUALS,
		"banner_path": IRON_HARBOR_BANNER,
	}))
	assert_true(port.has_backdrop(), "the authored banner still loads with a town kit bound")
	assert_eq(port.town_prop_count(), 29, "the town kit stays mounted under a painted banner")
	assert_eq(port.town_blockout_count(), 0, "the banner does not disturb the town kit")
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
	assert_eq(port.town_prop_count(), 29, "the other town props still mount")
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
	var started := context.commands.execute(&"run.start", {"build_id": STEADY_BUILD, "seed": 13013})
	assert_true(bool(started.get("ok", false)), "run.start succeeds in the port-view fixture: %s" % str(started))
	var result := context.queries.execute(&"port.view")
	assert_true(bool(result.get("ok", false)), "port.view answers after run.start: %s" % str(result))
	var data: Dictionary = result.get("data", {})
	var current_port: Dictionary = data.get("current_port", {})
	assert_false(current_port.is_empty(), "port.view reports the current port")

	var town: Dictionary = current_port.get("town_visuals", {})
	assert_true(town.size() >= 10, "port.view resolves at least the 10 town-kit slots: %d" % town.size())
	for slot in ["warehouse_long", "rowboat", "crate", "gas_lamp"]:
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
	var size := String(current_port.get("size", ""))
	assert_true(["small", "medium", "large"].has(size), "the current port reports a known size: %s" % size)

	# End to end: the ViewModel the page would bind mounts the full streetscape.
	var bundle := _mount_port_stage()
	var host: SNStageHost = bundle["host"]
	var stage: Variant = bundle["stage"]
	assert_true(bool(bundle["loaded"]) and stage is PortStage, "the port stage scene loads")
	if stage is PortStage:
		host.bind_view_model({"port": current_port})
		var port := stage as PortStage
		assert_eq(port.town_prop_count(), 29, "the resolved query ViewModel mounts the full streetscape")
		assert_eq(port.town_blockout_count(), 0, "every resolved town visual replaces its blockout")
	_free_host(host)
