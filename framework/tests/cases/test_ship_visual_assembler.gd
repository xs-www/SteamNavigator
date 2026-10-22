## @static-doc
## 作用：守护运行时整船装配层（`ShipVisualPlan` / `ShipVisualAssembler` / `ShipRigAssembly`）与 Core 内容契约：4 艘船的 hull/rig 计划解析、rig_kit 挂接与烘焙节点替换、武器 class 门禁、缺 socket / 缺套件 / 缺 hull 的回退，以及「同一计划重复装配得到相同节点树」的确定性。
##
## ## 契约与约束
## - 计划解析用真实 `bootstrap_core()` 的 `RegistryHub` + `AssetService`，验证 Core manifest 资源键（`model.ship.*` / `model.rig.*` / `model.weapon.*`）与 `hulls.json` 的 `data.rig_plan` 真的能驱动装配，不在测试里写死物理路径。
## - 装配在真实 SceneTree 根下的临时 holder 中进行，`global_transform` 与游戏一致；每个用例结尾释放 holder。
## - 断言 rig 替换是「全有或全无」：任一套件缺失 → `rig.mode=baked` 且原船烘焙节点仍在；全部成功 → `hide_nodes` 名单里的节点必须消失、`Rig_*` 节点数量与 socket 数一致。
## - 武器只做逐件门禁：class 匹配即挂载（净空是软判定），class 不匹配 / `Modular` kit 件 / 缺 socket 只跳过并记录，不影响 rig。
## - 确定性断言比较两次装配的 `snapshot()` 数组（路径 + 量化 1e-4 变换），以及 `report.rig.mounted` 的字符串字段。
## - 测试不写 GameState、不依赖存档；GLB 通过 `ShipVisualAssembler.instantiate_model()` 加载（与游戏同一路径）。
## @end-static-doc

extends TestCase

const SHIPYARD_STAGE_SCENE := "res://framework/ui/stages/shipyard_stage.tscn"
const PORT_STAGE_SCENE := "res://framework/ui/stages/port_stage.tscn"

const HULL_IDS := {
	"steamer": "core:hull/small_efficient",
	"schooner": "core:hull/medium_standard",
	"freighter": "core:hull/large_efficient",
	"ironclad": "core:hull/large_performance",
}

const PF_MAST_NODES := ["SN_PF_Mast_Fore", "SN_PF_Mast_Main"]
const PF_YARD_NODES := ["SN_PF_Yards"]
const SF_MAST_NODES := ["SN_SF_Mast_Fore", "SN_SF_Mast_Main"]


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _holder() -> Node3D:
	var holder := Node3D.new()
	holder.name = "AssemblerHolder"
	_tree().root.add_child(holder)
	return holder


func _release(holder: Node3D) -> void:
	if holder.get_parent() != null:
		holder.get_parent().remove_child(holder)
	holder.free()


func _plan(context: AppContext, hull_id: String, loadout: Variant = null) -> Dictionary:
	var ship := {"hull_id": hull_id}
	if loadout != null:
		ship["weapon_loadout"] = loadout
	return ShipVisualPlan.resolve(context.registries, context.assets, ship)


func _asset_path(context: AppContext, key: String) -> String:
	return ShipVisualPlan.resolve_asset(context.assets, key)


func _boot() -> AppContext:
	var boot := bootstrap_core()
	return boot["context"] as AppContext


# --- 1. Plan resolution ------------------------------------------------------


func test_plan_resolves_rig_plans_for_the_four_core_hulls() -> void:
	var context := _boot()
	var steamer := _plan(context, HULL_IDS["steamer"])
	assert_eq(String((steamer["hull"] as Dictionary).get("model_key", "")), "model.ship.paddle_steamer",
		"the steamer plan resolves the hull manifest key")
	assert_true(String((steamer["hull"] as Dictionary).get("model_path", "")).contains("SN_Paddle_Steamer"),
		"the steamer plan resolves a physical hull path")
	assert_eq(String((steamer["rig"] as Dictionary).get("mode", "")), "baked",
		"the steamer has no rig_plan and keeps its authored rig")

	var schooner := _plan(context, HULL_IDS["schooner"])
	var schooner_rig: Dictionary = schooner["rig"]
	assert_eq(String(schooner_rig.get("mode", "")), "replace", "the schooner declares a rig replacement plan")
	assert_eq(String(schooner_rig.get("kind", "")), "sail", "the schooner uses the sail mast kit family")
	assert_eq(schooner_rig.get("mount_kinds", []), ["mast"], "the schooner replaces masts only (1:1 fit)")
	assert_true(String(schooner_rig.get("mast_path", "")).contains("SN_Rig_Mast_Sail"),
		"the schooner mast asset key resolves to the sail mast GLB")
	assert_eq(schooner_rig.get("hide_nodes", []).size(), 2, "the schooner hides its two baked masts")

	var freighter := _plan(context, HULL_IDS["freighter"])
	var freighter_rig: Dictionary = freighter["rig"]
	assert_eq(String(freighter_rig.get("mode", "")), "replace", "the freighter declares a rig replacement plan")
	assert_eq(String(freighter_rig.get("kind", "")), "steam", "the freighter uses the steam mast kit family")
	assert_eq(freighter_rig.get("mount_kinds", []), ["mast", "yard"], "the freighter replaces masts and yards")
	assert_true(String(freighter_rig.get("mast_path", "")).contains("SN_Rig_Mast_Steam"),
		"the freighter mast asset key resolves to the steam mast GLB")
	assert_true(String(freighter_rig.get("yard_path", "")).contains("SN_Rig_Yard"),
		"the freighter yard asset key resolves to the yard GLB")

	var ironclad := _plan(context, HULL_IDS["ironclad"])
	assert_eq(String((ironclad["rig"] as Dictionary).get("mode", "")), "baked",
		"the ironclad is a single mesh and keeps its authored rig")
	assert_empty((ironclad["weapons"] as Dictionary).get("slots", []), "no loadout means no weapon slots")


func test_plan_normalises_the_weapon_loadout_and_reports_missing_assets() -> void:
	var context := _boot()
	var deck_gun := _asset_path(context, "model.weapon.deck_gun")
	assert_true(deck_gun.contains("SN_Weapon_DeckGun"), "the deck gun manifest key resolves: %s" % deck_gun)
	var bow_key := [{"socket": "SN_Socket_Weapon_Bow", "asset": "model.weapon.repeater"}]
	var from_array := _plan(context, HULL_IDS["schooner"], bow_key)
	var slots: Array = (from_array["weapons"] as Dictionary)["slots"]
	assert_eq(slots.size(), 1, "array-form loadout produces one slot")
	assert_eq(String((slots[0] as Dictionary).get("socket", "")), "SN_Socket_Weapon_Bow", "the socket name survives")
	assert_true(String((slots[0] as Dictionary).get("asset_path", "")).contains("SN_Weapon_Repeater"),
		"the weapon manifest key resolves to a physical path")

	var dict_form := _plan(context, HULL_IDS["schooner"], {"SN_Socket_Weapon_Bow": "model.weapon.repeater"})
	assert_eq(((dict_form["weapons"] as Dictionary)["slots"] as Array).size(), 1,
		"dictionary-form loadout is normalised as well")

	var broken := _plan(context, HULL_IDS["schooner"], [
		{"socket": "SN_Socket_Weapon_Bow", "asset": "model.weapon.does_not_exist"},
		{"socket": "", "asset": "model.weapon.deck_gun"},
	])
	var broken_slots: Array = (broken["weapons"] as Dictionary)["slots"]
	assert_eq(broken_slots.size(), 1, "an incomplete entry is dropped, not mounted")
	assert_eq(String((broken_slots[0] as Dictionary).get("asset_path", "")), "",
		"an unresolved asset key keeps an empty path for the assembler to report")
	var warnings: Array = broken["warnings"]
	assert_true(warnings.has("weapon_asset_missing:model.weapon.does_not_exist"),
		"the missing weapon asset is reported: %s" % str(warnings))
	assert_true(warnings.has("weapon_entry_incomplete"), "the incomplete entry is reported")


# --- 2. Assembled ships ------------------------------------------------------


func test_assembler_builds_all_four_hulls_with_stable_rig_nodes() -> void:
	var context := _boot()
	var holder := _holder()
	var expected_mounts := {"steamer": 0, "schooner": 2, "freighter": 4, "ironclad": 0}
	for key in HULL_IDS.keys():
		var plan := _plan(context, String(HULL_IDS[key]))
		var result := ShipVisualAssembler.assemble(plan, holder)
		var visual_value: Variant = result.get("visual", null)
		assert_true(visual_value is Node3D, "%s assembles a visible hull" % key)
		if not (visual_value is Node3D):
			continue
		var visual: Node3D = visual_value
		var report: Dictionary = result["report"]
		var rig: Dictionary = report["rig"]
		assert_eq((rig["mounted"] as Array).size(), int(expected_mounts[key]),
			"%s mounts the planned number of rig parts" % key)
		assert_true(int(report["triangles"]) > 0, "%s reports a non-zero triangle count" % key)
		var rig_nodes := _nodes_named(visual, "Rig_")
		assert_eq(rig_nodes.size(), int(expected_mounts[key]),
			"%s rig nodes use the stable Rig_ prefix" % key)
		if key == "freighter":
			for hide_name in PF_MAST_NODES + PF_YARD_NODES:
				assert_true(ShipRigAssembly.find_named(visual, hide_name) == null,
					"freighter baked node %s was replaced (hidden)" % hide_name)
			assert_not_null(ShipRigAssembly.find_named(visual, "Rig_mast_SN_Socket_Mast_Fore"),
				"freighter mounts a steam mast on SN_Socket_Mast_Fore")
			assert_not_null(ShipRigAssembly.find_named(visual, "Rig_yard_SN_Socket_Yard_Fore"),
				"freighter mounts a yard on SN_Socket_Yard_Fore")
			assert_eq(int((rig["hidden"] as Array).size()), 3, "freighter hides exactly the declared nodes")
		elif key == "schooner":
			for hide_name in SF_MAST_NODES:
				assert_true(ShipRigAssembly.find_named(visual, hide_name) == null,
					"schooner baked node %s was replaced (hidden)" % hide_name)
			assert_not_null(ShipRigAssembly.find_named(visual, "Rig_mast_SN_Socket_Mast_Main"),
				"schooner mounts the sail mast on SN_Socket_Mast_Main")
			assert_not_null(ShipRigAssembly.find_named(visual, "SN_SF_Sails_Main"),
				"schooner keeps its baked sails (only the masts are replaced)")
		holder.remove_child(visual)
		visual.free()
	_release(holder)


func test_assembler_is_deterministic_for_the_same_plan() -> void:
	var context := _boot()
	var plan := _plan(context, HULL_IDS["freighter"])
	var first_holder := _holder()
	var first := ShipVisualAssembler.assemble(plan, first_holder)
	var second_holder := _holder()
	var second := ShipVisualAssembler.assemble(plan, second_holder)
	var first_snapshot: Array = first["snapshot"]
	var second_snapshot: Array = second["snapshot"]
	assert_eq(first_snapshot.size(), second_snapshot.size(), "two assemblies produce the same node count")
	assert_eq(first_snapshot, second_snapshot, "two assemblies produce the same node paths and transforms")
	assert_eq((first["report"]["rig"] as Dictionary)["mounted"], (second["report"]["rig"] as Dictionary)["mounted"],
		"the rig report is reproducible")
	_release(first_holder)
	_release(second_holder)


func test_rig_mount_aligns_sn_mount_with_the_socket_frame() -> void:
	var context := _boot()
	var hull_scene := ShipVisualAssembler.instantiate_model(
		String(((_plan(context, HULL_IDS["schooner"])["hull"]) as Dictionary)["model_path"]))
	assert_not_null(hull_scene, "the schooner hull loads for the alignment fixture")
	if hull_scene == null:
		return
	var holder := _holder()
	holder.add_child(hull_scene)
	var sockets := ShipRigAssembly.find_sockets(hull_scene)
	assert_eq(sockets.size(), 7, "the schooner exposes 7 rig sockets")
	var socket: Node3D = null
	for candidate in sockets:
		if String(candidate.name) == "SN_Socket_Mast_Fore":
			socket = candidate
	assert_not_null(socket, "SN_Socket_Mast_Fore is discovered")
	if socket != null:
		var kit_path := _asset_path(context, "model.rig.mast_sail")
		var kit := ShipVisualAssembler.instantiate_model(kit_path)
		assert_not_null(kit, "the sail mast kit loads")
		if kit != null:
			var mounted := ShipRigAssembly.mount(socket, kit)
			assert_not_null(mounted, "the mast kit mounts on the mast socket")
			if mounted != null:
				var mount_node := ShipRigAssembly.find_mount(mounted)
				assert_not_null(mount_node, "the installed kit still exposes SN_Mount")
				if mount_node != null:
					var offset := mount_node.global_transform.origin - socket.global_transform.origin
					assert_true(offset.length() < 0.001,
						"SN_Mount sits exactly on the socket origin: %s" % str(offset))
					var dot := mount_node.global_transform.basis.x.dot(socket.global_transform.basis.x)
					assert_almost_eq(dot, 1.0, 0.001, "the kit keeps the socket forward axis")
	holder.remove_child(hull_scene)
	hull_scene.free()
	_release(holder)


# --- 3. Weapons --------------------------------------------------------------


func test_weapon_loadout_enforces_the_socket_class_gate() -> void:
	var context := _boot()
	var plan := _plan(context, HULL_IDS["schooner"])
	plan["weapons"] = {"slots": [
		{"socket": "SN_Socket_Weapon_Port_1", "asset_key": "model.weapon.deck_gun",
			"asset_path": _asset_path(context, "model.weapon.deck_gun")},
		{"socket": "SN_Socket_Weapon_Bow", "asset_key": "model.weapon.deck_gun",
			"asset_path": _asset_path(context, "model.weapon.deck_gun")},
		{"socket": "SN_Socket_Weapon_Bow", "asset_key": "model.weapon.repeater",
			"asset_path": _asset_path(context, "model.weapon.repeater")},
		{"socket": "SN_Socket_Weapon_Missing", "asset_key": "model.weapon.deck_gun",
			"asset_path": _asset_path(context, "model.weapon.deck_gun")},
		{"socket": "SN_Socket_Weapon_Port_1", "asset_key": "model.weapon.turret",
			"asset_path": _asset_path(context, "model.weapon.turret")},
	]}
	var holder := _holder()
	var result := ShipVisualAssembler.assemble(plan, holder)
	var visual: Node3D = result["visual"]
	assert_not_null(visual, "the schooner assembles with a weapon loadout")
	if visual != null:
		var weapons: Dictionary = result["report"]["weapons"]
		var mounted: Array = weapons["mounted"]
		assert_eq(mounted.size(), 2, "only class-compatible weapons mount")
		assert_eq(String((mounted[0] as Dictionary).get("socket", "")), "SN_Socket_Weapon_Port_1",
			"the Light socket takes the Light deck gun in plan order")
		assert_eq(String((mounted[1] as Dictionary).get("socket", "")), "SN_Socket_Weapon_Bow",
			"the Medium bow socket takes the Medium repeater")
		assert_true((mounted[1] as Dictionary).has("fits"),
			"clearance is a soft verdict recorded on the mount (true or false both mount)")
		assert_not_null(ShipRigAssembly.find_named(visual, "Weapon_SN_Socket_Weapon_Port_1"),
			"mounted weapons use the stable Weapon_ node name")
		var skipped: Array = weapons["skipped"]
		var reasons := PackedStringArray()
		for entry in skipped:
			reasons.append("%s:%s" % [String((entry as Dictionary).get("socket", "")), String((entry as Dictionary).get("reason", ""))])
		assert_true(reasons.size() == 3, "three slots are skipped: %s" % str(reasons))
		var mismatch := false
		var missing_socket := false
		var modular := false
		for entry in skipped:
			var row: Dictionary = entry
			var reason := String(row.get("reason", ""))
			if reason.begins_with("class mismatch"):
				mismatch = true
			elif reason == "socket_missing":
				missing_socket = true
			elif reason.begins_with("modular"):
				modular = true
		assert_true(mismatch, "a Light weapon on the Medium bow socket is rejected by class")
		assert_true(missing_socket, "an unknown weapon socket is reported, not crashed")
		assert_true(modular, "Modular kit parts are rejected as incomplete weapons")
		holder.remove_child(visual)
		visual.free()
	_release(holder)


# --- 4. Fallbacks ------------------------------------------------------------


func test_assembler_falls_back_to_the_prototype_when_the_hull_is_missing() -> void:
	var holder := _holder()
	var broken := {
		"hull": {"model_path": "res://assets/models/ships/SN_Does_Not_Exist.glb"},
		"rig": ShipVisualPlan.empty_rig(),
		"weapons": {"slots": []},
	}
	var result := ShipVisualAssembler.assemble(broken, holder)
	var visual_value: Variant = result.get("visual", null)
	assert_true(visual_value is Node3D, "a missing hull falls back to a visible model")
	if visual_value is Node3D:
		assert_eq(String(result["report"]["fallback"]), "hull_fallback_model",
			"the report says the fallback hull was used")
		holder.remove_child(visual_value as Node3D)
		(visual_value as Node3D).free()
	var hopeless := {
		"hull": {"model_path": "res://missing.glb"},
		"fallback_model_path": "res://missing_fallback.glb",
		"rig": ShipVisualPlan.empty_rig(),
		"weapons": {"slots": []},
	}
	var empty_result := ShipVisualAssembler.assemble(hopeless, holder)
	assert_eq(empty_result["visual"], null, "with no loadable hull the assembler returns null (stage keeps 2D placeholder)")
	assert_eq(String(empty_result["report"]["fallback"]), "no_hull", "the failure is reported, not raised")
	_release(holder)


func test_assembler_keeps_the_baked_rig_when_a_kit_asset_is_missing() -> void:
	var context := _boot()
	var plan := _plan(context, HULL_IDS["freighter"])
	var rig: Dictionary = plan["rig"]
	rig["mast_path"] = ""
	plan["rig"] = rig
	var holder := _holder()
	var result := ShipVisualAssembler.assemble(plan, holder)
	var visual: Node3D = result["visual"]
	assert_not_null(visual, "the hull still assembles when the kit asset is missing")
	if visual != null:
		var report_rig: Dictionary = result["report"]["rig"]
		assert_eq(String(report_rig.get("mode", "")), "baked", "the plan degrades to the baked rig")
		assert_eq(String(report_rig.get("fallback", "")), "rig_mount_failed",
			"the rig fallback reason is reported")
		assert_true((report_rig["mounted"] as Array).is_empty(), "no half-assembled kit survives")
		assert_not_null(ShipRigAssembly.find_named(visual, "SN_PF_Mast_Fore"),
			"the authored mast is still there instead of an empty ship")
		holder.remove_child(visual)
		visual.free()
	_release(holder)


func test_assembler_reports_missing_rig_sockets_without_crashing() -> void:
	var context := _boot()
	var plan := _plan(context, HULL_IDS["steamer"])
	plan["rig"] = ShipVisualPlan.empty_rig()
	var rig: Dictionary = plan["rig"]
	rig["mode"] = "replace"
	rig["kind"] = "sail"
	rig["mount_kinds"] = ["mast"]
	rig["mast_path"] = _asset_path(context, "model.rig.mast_sail")
	plan["rig"] = rig
	var holder := _holder()
	var result := ShipVisualAssembler.assemble(plan, holder)
	var visual: Node3D = result["visual"]
	assert_not_null(visual, "a hull without rig sockets still shows its hull")
	if visual != null:
		var report_rig: Dictionary = result["report"]["rig"]
		assert_eq(String(report_rig.get("mode", "")), "baked", "no socket means no rig replacement")
		var skipped: Array = report_rig["skipped"]
		assert_eq(skipped.size(), 1, "the missing socket kind is reported once")
		assert_eq(String((skipped[0] as Dictionary).get("reason", "")), "socket_missing",
			"the skip reason is socket_missing")
		holder.remove_child(visual)
		visual.free()
	_release(holder)


# --- 5. Stage integration ----------------------------------------------------


func test_shipyard_stage_assembles_the_planned_ship_and_keeps_the_legacy_path() -> void:
	var context := _boot()
	var stage := _mount_shipyard()
	if stage == null:
		return
	stage.bind({"ship": {"hull_model_path": "res://assets/models/ships/SN_Paddle_Steamer.glb", "hull_tier": 1}})
	assert_true(stage.has_ship(), "a legacy ViewModel still mounts the single-hull model")
	assert_true(stage.model_path().contains("SN_Paddle_Steamer"), "the legacy path is unchanged")
	assert_empty(stage.rig_report(), "the legacy path has no assembler report")

	var plan := _plan(context, HULL_IDS["freighter"])
	stage.bind({"ship": {"hull_id": HULL_IDS["freighter"], "hull_tier": 3, "visual": plan}})
	assert_true(stage.has_ship(), "the shipyard stage mounts the assembled ship")
	assert_true(stage.model_path().contains("SN_Paddle_Freighter"), "the plan hull path is reported")
	var rig := stage.rig_report()
	assert_eq(String(rig.get("mode", "")), "replace", "the stage reports the rig replacement")
	assert_eq((rig["mounted"] as Array).size(), 4, "the stage keeps every rig mount")
	var report := stage.assembly_report()
	assert_eq(String(report.get("hull_asset", "")), "SN_Paddle_Freighter", "the hull asset is reported")
	_unmount(stage)


func test_port_stage_assembles_and_batches_the_planned_player_ship() -> void:
	var context := _boot()
	var stage := _mount_port()
	if stage == null:
		return
	var plan := _plan(context, HULL_IDS["freighter"])
	stage.bind({
		"port": {"id": "test_assembled", "size": "medium", "facilities": []},
		"ship": {"hull_id": HULL_IDS["freighter"], "hull_tier": 3, "visual": plan},
	})
	assert_true(stage.has_ship(), "the port stage mounts the assembled player ship")
	var report := stage.ship_assembly_report()
	assert_eq(String((report["rig"] as Dictionary).get("mode", "")), "replace",
		"the port stage reports the rig replacement")
	var stats: Dictionary = stage.batch_stats()
	assert_false(bool(stats["ship_fallback"]), "the assembled ship still batches as a rigid hull")
	assert_true(int(stats["ship_meshes_after"]) < int(stats["ship_meshes_before"]),
		"assembled rig parts are baked into the ship batches: %d -> %d" % [
			int(stats["ship_meshes_before"]), int(stats["ship_meshes_after"])])
	assert_not_null(stage.get_node_or_null("Content/PlayerShip/ShipBatches"),
		"the batches stay under the animated player ship root")
	_unmount_port(stage)


# --- Helpers -----------------------------------------------------------------


func _nodes_named(root: Node, prefix: String) -> Array[Node]:
	var output: Array[Node] = []
	if String(root.name).begins_with(prefix):
		output.append(root)
	for child in root.get_children():
		output.append_array(_nodes_named(child, prefix))
	return output


func _mount_shipyard() -> ShipyardStage:
	var packed := load(SHIPYARD_STAGE_SCENE) as PackedScene
	assert_not_null(packed, "the shipyard stage scene loads")
	if packed == null:
		return null
	var stage := packed.instantiate() as ShipyardStage
	assert_not_null(stage, "the shipyard stage instantiates as ShipyardStage")
	if stage == null:
		return null
	_tree().root.add_child(stage)
	return stage


func _mount_port() -> PortStage:
	var packed := load(PORT_STAGE_SCENE) as PackedScene
	assert_not_null(packed, "the port stage scene loads")
	if packed == null:
		return null
	var stage := packed.instantiate() as PortStage
	assert_not_null(stage, "the port stage instantiates as PortStage")
	if stage == null:
		return null
	_tree().root.add_child(stage)
	return stage


func _unmount(stage: ShipyardStage) -> void:
	if stage.get_parent() != null:
		stage.get_parent().remove_child(stage)
	stage.free()


func _unmount_port(stage: PortStage) -> void:
	if stage.get_parent() != null:
		stage.get_parent().remove_child(stage)
	stage.free()
