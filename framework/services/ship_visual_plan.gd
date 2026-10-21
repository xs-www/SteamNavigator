## @static-doc
## 作用：把「当前船体 + Core 内容」解析成舞台可直接执行的视觉装配计划（hull GLB 物理路径、rig_kit 替换计划、武器 loadout 路径），让表现层只消费路径、不读注册表，也不写死任何 core 内容 ID 或资产键。
##
## - 关键依赖：`RegistryHub`（hull 定义）、`AssetService`（`find_key` / `resolve`）、Core `manifest.json` 的 `model.ship.*` / `model.rig.*` / `model.weapon.*` 键与 `hulls.json` 的 `data.rig_plan`
##
## ## 契约与约束
## - 只读：不写 GameState、不注册命令/查询；缺 hull / 缺 rig_plan / 缺资源键都返回可执行的最小计划 + `warnings`，不抛错。
## - `rig.mode` 只有 `replace`（内容声明了 `data.rig_plan`）与 `baked`（保留 GLB 内焊死帆索）两种。`replace` 计划里**任一必需套件解析不到**都会整体降级为 `baked`，避免「隐藏了烘焙桅却没装上套件」的空船。
## - 资源键一律走 `AssetService.find_key()`（裸键 → 第一个声明该键的已挂载模组）再 `resolve()`；也接受 `res://` / `user://` 直接路径。`asset://` 前缀视为调用方已完成 find_key。
## - 武器 loadout 是表现数据：`ship.weapon_loadout`（Array[Dictionary] 或 socket→asset 字典）优先，其次 `ship.weapons`；这里只解析 socket 名与路径，class 门禁在装配层（`ShipWeaponAssembly`）。
## - 本类是纯数据；节点装配在 `framework/ui/stages/ship_visual_assembler.gd`。
## @end-static-doc

class_name ShipVisualPlan
extends RefCounted

const RIG_KINDS := ["mast", "yard", "sail"]


## 没有可用 run / 没有 hull 时返回的空计划：所有键都在，调用方无需判空。
static func empty() -> Dictionary:
	return {
		"hull": {"id": "", "model_key": "", "model_path": "", "tier": 1},
		"rig": empty_rig(),
		"weapons": {"slots": []},
		"warnings": [],
	}


## `rig.mode == "baked"` 的计划骨架（不替换烘焙帆索）。
static func empty_rig() -> Dictionary:
	return {
		"mode": "baked",
		"kind": "",
		"mount_kinds": [],
		"hide_nodes": [],
		"mast_path": "",
		"yard_path": "",
		"sail_path": "",
		"per_mast_paths": [],
		"yaw_deg": 0.0,
	}


## Resolves the hull model, the optional rig replacement plan and the weapon
## loadout into physical paths. Never mutates state; missing content degrades to
## an empty/baked plan plus human-readable `warnings`.
static func resolve(hub: RegistryHub, assets: AssetService, ship: Dictionary) -> Dictionary:
	var warnings: Array[String] = []
	var hull_id := String(ship.get("hull_id", ""))
	var hull: ContentDefinition = null
	if hub != null and not hull_id.is_empty():
		hull = hub.get_by_id(ContentTypes.HULL, hull_id)
	var model_key := ""
	if hull != null:
		model_key = String(hull.information.get("model", ""))
	var model_path := String(ship.get("hull_model_path", ""))
	if model_path.is_empty() and not model_key.is_empty():
		model_path = resolve_asset(assets, model_key)
		if model_path.is_empty():
			warnings.append("hull_model_missing:%s" % model_key)
	if hull == null:
		warnings.append("hull_definition_missing:%s" % hull_id)
	return {
		"hull": {
			"id": hull_id,
			"model_key": model_key,
			"model_path": model_path,
			"tier": int(ship.get("hull_tier", 1)),
		},
		"rig": resolve_rig(hull, assets, warnings),
		"weapons": resolve_weapons(assets, ship, warnings),
		"warnings": warnings,
	}


## Reads `hull.data.rig_plan` into a mount plan. Missing assets downgrade the
## whole plan to `baked` so the hull keeps its authored rig instead of losing it.
static func resolve_rig(hull: ContentDefinition, assets: AssetService, warnings: Array[String]) -> Dictionary:
	var plan := empty_rig()
	if hull == null:
		return plan
	var raw: Variant = hull.data.get("rig_plan", null)
	if not (raw is Dictionary):
		return plan
	var data: Dictionary = raw
	var kind := String(data.get("kind", ""))
	if kind.is_empty():
		warnings.append("rig_plan_kind_missing")
		return plan
	var kinds: Array[String] = []
	var raw_kinds: Variant = data.get("mount_kinds", ["mast"])
	if raw_kinds is Array:
		for item in raw_kinds:
			var text := String(item)
			if RIG_KINDS.has(text) and not kinds.has(text):
				kinds.append(text)
	if kinds.is_empty():
		kinds.append("mast")
	var hide_nodes: Array[String] = []
	var raw_hide: Variant = data.get("hide_nodes", [])
	if raw_hide is Array:
		for item in raw_hide:
			hide_nodes.append(String(item))
	var per_mast: Array[String] = []
	var raw_per_mast: Variant = data.get("per_mast_assets", [])
	if raw_per_mast is Array:
		for item in raw_per_mast:
			var key := String(item)
			var path := resolve_asset(assets, key)
			if path.is_empty():
				warnings.append("rig_asset_missing:%s" % key)
			else:
				per_mast.append(path)
	plan["kind"] = kind
	plan["mount_kinds"] = kinds
	plan["hide_nodes"] = hide_nodes
	plan["mast_path"] = resolve_asset(assets, String(data.get("mast_asset", "")))
	plan["yard_path"] = resolve_asset(assets, String(data.get("yard_asset", "")))
	plan["sail_path"] = resolve_asset(assets, String(data.get("sail_asset", "")))
	plan["per_mast_paths"] = per_mast
	plan["yaw_deg"] = float(data.get("yaw_deg", 0.0))
	if kinds.has("mast") and String(plan["mast_path"]).is_empty():
		warnings.append("rig_mast_asset_missing")
		return plan
	if kinds.has("yard") and String(plan["yard_path"]).is_empty():
		warnings.append("rig_yard_asset_missing")
		return plan
	if kinds.has("sail") and String(plan["sail_path"]).is_empty():
		warnings.append("rig_sail_asset_missing")
		return plan
	plan["mode"] = "replace"
	return plan


## Normalises `ship.weapon_loadout` / `ship.weapons` into ordered slot rows with
## resolved paths. Missing assets stay in the plan with an empty path so the
## assembler can report exactly why a socket stayed empty.
static func resolve_weapons(assets: AssetService, ship: Dictionary, warnings: Array[String]) -> Dictionary:
	var entries: Array = []
	var raw: Variant = ship.get("weapon_loadout", null)
	if raw == null:
		raw = ship.get("weapons", null)
	if raw is Array:
		for item in raw:
			if item is Dictionary:
				entries.append(item)
	elif raw is Dictionary:
		var by_socket: Dictionary = raw
		for socket in by_socket.keys():
			entries.append({"socket": String(socket), "asset": String(by_socket[socket])})
	var slots: Array[Dictionary] = []
	for item in entries:
		var entry: Dictionary = item
		var socket_name := String(entry.get("socket", ""))
		var asset_key := String(entry.get("asset", entry.get("asset_key", "")))
		if socket_name.is_empty() or asset_key.is_empty():
			warnings.append("weapon_entry_incomplete")
			continue
		var asset_path := resolve_asset(assets, asset_key)
		if asset_path.is_empty():
			warnings.append("weapon_asset_missing:%s" % asset_key)
		slots.append({
			"socket": socket_name,
			"asset_key": asset_key,
			"asset_path": asset_path,
			"class": String(entry.get("class", "")),
		})
	return {"slots": slots}


## Resolves one manifest asset key (`model.rig.mast_sail`) or a direct
## `res://` path to a mounted physical path. "" means "not resolvable".
static func resolve_asset(assets: AssetService, key: String) -> String:
	if key.is_empty():
		return ""
	if key.begins_with("res://") or key.begins_with("user://"):
		return key if FileAccess.file_exists(key) else ""
	if assets == null:
		return ""
	var logical := key
	if not key.begins_with("asset://"):
		logical = assets.find_key(key)
	if logical.is_empty():
		return ""
	var path := assets.resolve(logical)
	if path.is_empty() or path == assets.fallback_path():
		return ""
	return path
