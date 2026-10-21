## @static-doc
## 作用：`ShipVisualAssembler` —— 运行时把一条船拼成可见的整船：实例化船体 GLB，按船体 Root `SN_Socket_Mast/Yard/Sail_*` 挂 rig_kit 套件（并隐藏被替换的烘焙节点），再按 `SN_Socket_Weapon_*` 挂武器；返回装配根、可读报告与确定性快照，供船厂 / 港口 / 航行演出共用。
##
## - 关键依赖：`framework/services/content_asset_loader.gd`（原始 GLB 加载）、`framework/services/ship_visual_plan.gd`（输入计划）、`framework/ui/stages/ship_rig_assembly.gd`（rig 规则）、`framework/ui/stages/ship_weapon_assembly.gd`（武器规则）
##
## ## 契约与约束
## - 输入是**已解析路径**的计划（`ShipVisualPlan.resolve()` 的结果），本类不读注册表、不写 GameState；装配结果是纯表现节点。
## - 回退优先级：hull 路径加载失败 → 计划里的 fallback 路径 / `SN_Ship_Prototype` → 返回 `visual=null`（舞台保留自己的 2D 占位），任何一步都不抛错。
## - rig 是**全有或全无**：计划声明的挂件只要有一件缺 socket / 缺 GLB / 加载失败，就整体放弃 rig 替换、保留原船（`rig.mode=baked`、`fallback=rig_mount_failed`），绝不出现「烘焙桅被隐藏但套件没装上」的空船。全成功后按 `hide_nodes` 移除烘焙件。
## - 武器是**逐件尽力**：单个 socket 缺模型 / class 不匹配 / 缺 `SN_Mount` 只跳过该件并记录原因，不影响 rig 与其它武器（class 门禁见 `WEAPON_SOCKET_CONTRACT` §5）。
## - 节点命名稳定可断言：`Rig_<kind>_<socket>`、`Rig_<kind>_<socket>_<asset>`、`Weapon_<socket>`；同一计划重复装配得到相同 `snapshot()`（量化 1e-4）。
## - 顺序确定：socket 按 `ShipRigAssembly.find_sockets()` / `ShipWeaponAssembly.find_sockets()` 的 `socket_index → name` 排序，loadout 按计划数组顺序。
## @end-static-doc

class_name ShipVisualAssembler
extends RefCounted

const FALLBACK_HULL_PATH := "res://assets/models/ships/SN_Ship_Prototype.glb"


## Builds the assembled ship under `parent`. The returned `visual` node is the
## hull root (rig parts and weapons are its descendants); `null` when even the
## fallback hull cannot be instantiated.
static func assemble(plan: Dictionary, parent: Node3D, options: Dictionary = {}) -> Dictionary:
	var report := empty_report()
	if parent == null:
		report["fallback"] = "no_parent"
		return {"visual": null, "report": report, "snapshot": []}
	var hull_plan: Variant = plan.get("hull", {})
	var hull: Dictionary = hull_plan if hull_plan is Dictionary else {}
	var wanted_path := String(hull.get("model_path", ""))
	var visual := instantiate_model(wanted_path, options)
	var used_path := wanted_path
	if visual == null:
		var fallback_path := String(plan.get("fallback_model_path", FALLBACK_HULL_PATH))
		visual = instantiate_model(fallback_path, options)
		used_path = fallback_path
		if visual != null:
			report["fallback"] = "hull_fallback_model"
	if visual == null:
		report["fallback"] = "no_hull"
		report["hull_path"] = wanted_path
		return {"visual": null, "report": report, "snapshot": []}
	visual.name = String(options.get("hull_node_name", "Hull"))
	parent.add_child(visual)
	report["hull_path"] = used_path
	report["hull_asset"] = hull_asset_of(visual)
	var rig_plan: Variant = plan.get("rig", {})
	report["rig"] = _apply_rig(rig_plan if rig_plan is Dictionary else {}, visual)
	var weapon_plan: Variant = plan.get("weapons", {})
	report["weapons"] = _apply_weapons(weapon_plan if weapon_plan is Dictionary else {}, visual, options)
	report["snapshot"] = ShipRigAssembly.snapshot(visual)
	report["triangles"] = ShipRigAssembly.triangle_count(visual)
	return {"visual": visual, "report": report, "snapshot": report["snapshot"]}


## Empty report skeleton (callers can render it before/without assembly).
static func empty_report() -> Dictionary:
	return {
		"hull_path": "",
		"hull_asset": "",
		"fallback": "",
		"rig": {
			"mode": "baked",
			"kind": "",
			"mounted": [],
			"skipped": [],
			"hidden": [],
			"missing_hide": [],
			"fallback": "",
		},
		"weapons": {"mounted": [], "skipped": [], "mounts": []},
		"snapshot": [],
		"triangles": 0,
	}


## Instances a raw content GLB (mounted mod or loose dev tree). Imported scenes
## are preferred for `res://` paths (they carry the project's import settings);
## the raw `ContentAssetLoader` path is the fallback for zipped mods and can be
## forced with `options.prefer_imported = false` (tests).
static func instantiate_model(path: String, options: Dictionary = {}) -> Node3D:
	if path.is_empty():
		return null
	var prefer_imported := bool(options.get("prefer_imported", true))
	if prefer_imported and ResourceLoader.exists(path):
		var imported := _instantiate_imported(path)
		if imported != null:
			return imported
	if FileAccess.file_exists(path):
		return ContentAssetLoader.instantiate_model(path)
	return _instantiate_imported(path)


static func _instantiate_imported(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var node := packed.instantiate()
	if node is Node3D:
		return node as Node3D
	if node != null:
		node.free()
	return null


## Name of the hull asset declared by the GLB Root extras ("" when absent).
static func hull_asset_of(visual: Node) -> String:
	var extras := ShipRigAssembly.extras_of(visual)
	if extras.has("asset"):
		return String(extras["asset"])
	var stack: Array[Node] = [visual]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var node_extras := ShipRigAssembly.extras_of(node)
		if node_extras.has("asset"):
			return String(node_extras["asset"])
		for child in node.get_children():
			stack.append(child)
	return ""


static func _apply_rig(rig_plan: Dictionary, visual: Node3D) -> Dictionary:
	var report := {
		"mode": "baked",
		"kind": String(rig_plan.get("kind", "")),
		"mounted": [],
		"skipped": [],
		"hidden": [],
		"missing_hide": [],
		"fallback": "",
	}
	if String(rig_plan.get("mode", "baked")) != "replace":
		return report
	var raw_kinds: Variant = rig_plan.get("mount_kinds", ["mast"])
	var kinds: Array = raw_kinds if raw_kinds is Array else ["mast"]
	if kinds.is_empty():
		kinds = ["mast"]
	var asset_by_kind := {
		"mast": String(rig_plan.get("mast_path", "")),
		"yard": String(rig_plan.get("yard_path", "")),
		"sail": String(rig_plan.get("sail_path", "")),
	}
	var per_mast: Array = []
	var raw_per_mast: Variant = rig_plan.get("per_mast_paths", [])
	if raw_per_mast is Array:
		per_mast = raw_per_mast
	var yaw_deg := float(rig_plan.get("yaw_deg", 0.0))
	var sockets := ShipRigAssembly.find_sockets(visual)
	var mounted: Array[Dictionary] = []
	var skipped: Array[Dictionary] = []
	for raw_kind in kinds:
		var kind := String(raw_kind)
		var asset_path := String(asset_by_kind.get(kind, ""))
		var kind_sockets: Array[Node3D] = []
		for socket in sockets:
			if String(ShipRigAssembly.socket_info(socket).get("kind", "")) == kind:
				kind_sockets.append(socket)
		if kind_sockets.is_empty():
			skipped.append({"kind": kind, "socket": "", "reason": "socket_missing"})
			continue
		for socket in kind_sockets:
			if asset_path.is_empty():
				skipped.append({"kind": kind, "socket": String(socket.name), "reason": "asset_missing"})
				continue
			var kit := instantiate_model(asset_path)
			if kit == null:
				skipped.append({"kind": kind, "socket": String(socket.name), "reason": "asset_load_failed"})
				continue
			kit.name = "Rig_%s_%s" % [kind, String(socket.name)]
			var mounted_kit := ShipRigAssembly.mount(socket, kit, yaw_deg)
			if mounted_kit == null:
				skipped.append({"kind": kind, "socket": String(socket.name), "reason": "mount_failed"})
				continue
			mounted.append({
				"kind": kind,
				"socket": String(socket.name),
				"asset_path": asset_path,
				"node_name": String(mounted_kit.name),
			})
			if kind == "mast":
				if not _mount_aux_parts(socket, per_mast, yaw_deg, mounted, skipped):
					continue
	report["mounted"] = mounted
	report["skipped"] = skipped
	if not skipped.is_empty() or mounted.is_empty():
		# All-or-nothing: drop the kits so the hull keeps its authored rig.
		_free_mounted_rig(visual)
		report["mounted"] = []
		report["fallback"] = "rig_mount_failed"
		return report
	var hide_names: Array = []
	var raw_hide: Variant = rig_plan.get("hide_nodes", [])
	if raw_hide is Array:
		hide_names = raw_hide
	var missing_hide: Array[String] = []
	for item in hide_names:
		if ShipRigAssembly.find_named(visual, String(item)) == null:
			missing_hide.append(String(item))
	report["hidden"] = ShipRigAssembly.hide_nodes(visual, hide_names)
	report["missing_hide"] = missing_hide
	report["mode"] = "replace"
	return report


static func _mount_aux_parts(
	socket: Node3D,
	per_mast: Array,
	yaw_deg: float,
	mounted: Array[Dictionary],
	skipped: Array[Dictionary]
) -> bool:
	for index in per_mast.size():
		var asset_path := String(per_mast[index])
		var kit := instantiate_model(asset_path)
		if kit == null:
			skipped.append({
				"kind": "aux",
				"socket": String(socket.name),
				"reason": "asset_load_failed",
			})
			return false
		var asset_name := asset_path.get_file().get_basename()
		kit.name = "Rig_aux_%s_%s" % [String(socket.name), asset_name]
		var mounted_kit := ShipRigAssembly.mount(socket, kit, yaw_deg)
		if mounted_kit == null:
			skipped.append({
				"kind": "aux",
				"socket": String(socket.name),
				"reason": "mount_failed",
			})
			return false
		mounted.append({
			"kind": "aux",
			"socket": String(socket.name),
			"asset_path": asset_path,
			"node_name": String(mounted_kit.name),
		})
	return true


static func _free_mounted_rig(visual: Node3D) -> void:
	var doomed: Array[Node] = []
	for socket in ShipRigAssembly.find_sockets(visual):
		for child in socket.get_children():
			if String(child.name).begins_with("Rig_"):
				doomed.append(child)
	for node in doomed:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()


static func _apply_weapons(weapon_plan: Dictionary, visual: Node3D, options: Dictionary) -> Dictionary:
	var report := {"mounted": [], "skipped": [], "mounts": []}
	var raw_slots: Variant = weapon_plan.get("slots", [])
	if not (raw_slots is Array):
		return report
	var slots: Array = raw_slots
	var by_name := {}
	for socket in ShipWeaponAssembly.find_sockets(visual):
		by_name[String(socket.name)] = socket
	var mounted: Array[Dictionary] = []
	var skipped: Array[Dictionary] = []
	var mounts: Array[ShipWeaponMount] = []
	for item in slots:
		if not (item is Dictionary):
			continue
		var slot: Dictionary = item
		var socket_name := String(slot.get("socket", ""))
		var asset_path := String(slot.get("asset_path", ""))
		if not by_name.has(socket_name):
			skipped.append({"socket": socket_name, "reason": "socket_missing"})
			continue
		if asset_path.is_empty():
			skipped.append({"socket": socket_name, "reason": "asset_missing"})
			continue
		var socket: Node3D = by_name[socket_name]
		var weapon := instantiate_model(asset_path, options)
		if weapon == null:
			skipped.append({"socket": socket_name, "reason": "asset_load_failed"})
			continue
		var info := ShipWeaponAssembly.weapon_info(weapon)
		var socket_value := ShipWeaponAssembly.socket_info(socket)
		var reason := ShipWeaponAssembly.rejection_reason(info, socket_value)
		if not reason.is_empty():
			weapon.free()
			skipped.append({"socket": socket_name, "reason": reason})
			continue
		var mount := ShipWeaponAssembly.mount(socket, weapon)
		if mount == null:
			skipped.append({"socket": socket_name, "reason": "mount_failed"})
			continue
		weapon.name = "Weapon_%s" % socket_name
		mounts.append(mount)
		mounted.append({
			"socket": socket_name,
			"asset_path": asset_path,
			"asset": mount.weapon_asset(),
			"class": mount.weapon_class(),
			"profile": mount.profile(),
			"fits": bool(mount.clearance_report().get("fits", false)),
		})
	report["mounted"] = mounted
	report["skipped"] = skipped
	report["mounts"] = mounts
	return report
