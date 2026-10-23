class_name WeaponOps
extends RefCounted
## @static-doc
## 作用：玩家旗舰的舰载武器所有权与装配纯规则；校验 hull socket、weapon class、来源、价格和重量，并维护 `ship.weapon_loadout`。
##
## - loadout 是 `{socket, weapon_id}` 数组；每个 socket 至多一件武器，数组按 hull socket 顺序输出。
## - 武器是独立 `weapons` 内容，不进入 module_instances；港口仓库武器由 WarehouseOps 管理。
## - 更换 hull 时 `reconcile_for_hull()` 保留同名且 class 兼容的装配，并返回应回仓的武器 id。
## @end-static-doc

const VALID_SOURCES := ["purchase", "warehouse"]


static func all(hub: RegistryHub) -> Array[ContentDefinition]:
	return hub.get_all(ContentTypes.WEAPON)


static func get_by_id(hub: RegistryHub, weapon_id: String) -> ContentDefinition:
	return hub.get_by_id(ContentTypes.WEAPON, weapon_id)


static func sockets(hub: RegistryHub, ship: Dictionary) -> Array:
	var hull := hub.get_by_id(ContentTypes.HULL, String(ship.get("hull_id", "")))
	if hull == null:
		return []
	var value: Variant = hull.data.get("weapon_sockets", null)
	return Array(value).duplicate(true) if value is Array else []


static func socket_by_name(hub: RegistryHub, ship: Dictionary, socket_name: String) -> Dictionary:
	for raw_socket in sockets(hub, ship):
		if raw_socket is Dictionary and String(raw_socket.get("name", "")) == socket_name:
			return raw_socket
	return {}


static func loadout(ship: Dictionary) -> Array:
	var value: Variant = ship.get("weapon_loadout", null)
	return value if value is Array else []


static func weapon_id_at(ship: Dictionary, socket_name: String) -> String:
	for raw_row in loadout(ship):
		if raw_row is Dictionary and String(raw_row.get("socket", "")) == socket_name:
			return String(raw_row.get("weapon_id", ""))
	return ""


static func weapon_class(definition: ContentDefinition) -> String:
	if definition == null:
		return ""
	var direct := String(definition.data.get("weapon_class", ""))
	return direct if not direct.is_empty() else String(definition.data.get("mount_class", ""))


static func accepts(socket: Dictionary, weapon: ContentDefinition) -> bool:
	return not socket.is_empty() and weapon != null \
		and String(socket.get("socket_class", "")) == weapon_class(weapon)


static func total_weight(hub: RegistryHub, ship: Dictionary) -> float:
	var total := 0.0
	var seen := {}
	for raw_row in loadout(ship):
		if not (raw_row is Dictionary):
			continue
		var socket_name := String(raw_row.get("socket", ""))
		if socket_name.is_empty() or seen.has(socket_name):
			continue
		seen[socket_name] = true
		var weapon := get_by_id(hub, String(raw_row.get("weapon_id", "")))
		if weapon != null:
			total += float(weapon.data.get("weight", 0.0))
	return total


static func install_blockers(hub: RegistryHub, state: GameState, weapon_id: String, socket_name: String, source: String = "purchase") -> Array[String]:
	var blockers: Array[String] = []
	if socket_name.is_empty():
		blockers.append("missing_socket")
		return blockers
	var socket := socket_by_name(hub, state.ship(), socket_name)
	if socket.is_empty():
		blockers.append("unknown_socket")
	var weapon := get_by_id(hub, weapon_id)
	if weapon == null:
		blockers.append("unknown_weapon")
	if not VALID_SOURCES.has(source):
		blockers.append("invalid_source")
	if not socket.is_empty() and weapon != null and not accepts(socket, weapon):
		blockers.append("weapon_class_mismatch")
	if weapon == null:
		return blockers
	if weapon_id_at(state.ship(), socket_name) == weapon_id:
		blockers.append("already_installed")
	if source == "purchase" and state.money() < int(round(float(weapon.data.get("purchase_price", 0.0)))):
		blockers.append("insufficient_money")
	if source == "warehouse" and WarehouseOps.weapon_qty(state, state.current_port_id(), weapon_id) <= 0:
		blockers.append("warehouse_empty")
	var current_id := weapon_id_at(state.ship(), socket_name)
	var current := get_by_id(hub, current_id)
	var current_weight := float(current.data.get("weight", 0.0)) if current != null else 0.0
	var next_weight := ShipOps.total_weight(hub, state) - current_weight + float(weapon.data.get("weight", 0.0))
	if next_weight > ShipOps.max_weight(hub, state.ship()) + 0.0001:
		blockers.append("weight_limit")
	return blockers


## Installs/replaces one weapon after blockers have passed. Returns the replaced id.
static func install(ship: Dictionary, socket_name: String, weapon_id: String) -> String:
	var replaced := weapon_id_at(ship, socket_name)
	var next: Array = []
	for raw_row in loadout(ship):
		if raw_row is Dictionary and String(raw_row.get("socket", "")) != socket_name:
			next.append((raw_row as Dictionary).duplicate(true))
	next.append({"socket": socket_name, "weapon_id": weapon_id})
	ship["weapon_loadout"] = next
	return replaced


static func uninstall(ship: Dictionary, socket_name: String) -> String:
	var removed := weapon_id_at(ship, socket_name)
	if removed.is_empty():
		return ""
	var next: Array = []
	for raw_row in loadout(ship):
		if raw_row is Dictionary and String(raw_row.get("socket", "")) != socket_name:
			next.append((raw_row as Dictionary).duplicate(true))
	ship["weapon_loadout"] = next
	return removed


## Rebuilds loadout in the new hull's socket order and returns weapons that no
## longer fit. The caller decides which warehouse receives those items.
static func reconcile_for_hull(hub: RegistryHub, ship: Dictionary) -> Array[String]:
	var previous := loadout(ship).duplicate(true)
	var kept: Array = []
	var removed: Array[String] = []
	var consumed := {}
	for raw_socket in sockets(hub, ship):
		if not (raw_socket is Dictionary):
			continue
		var socket_name := String(raw_socket.get("name", ""))
		for index in previous.size():
			if consumed.has(index) or not (previous[index] is Dictionary):
				continue
			var row: Dictionary = previous[index]
			if String(row.get("socket", "")) != socket_name:
				continue
			var weapon := get_by_id(hub, String(row.get("weapon_id", "")))
			if accepts(raw_socket, weapon):
				kept.append({"socket": socket_name, "weapon_id": String(row.get("weapon_id", ""))})
				consumed[index] = true
			break
	for index in previous.size():
		if consumed.has(index) or not (previous[index] is Dictionary):
			continue
		var weapon_id := String((previous[index] as Dictionary).get("weapon_id", ""))
		if not weapon_id.is_empty():
			removed.append(weapon_id)
	ship["weapon_loadout"] = kept
	return removed
