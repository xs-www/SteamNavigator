class_name FleetService
extends RefCounted
## @static-doc
## 作用：Phase D2 舰队的领域用例：舰长指派、编队/槽位、战术选择、增删舰船。
## 所有入口返回 `Result`（`{ok,error_code,message_key,data,events}`），由应用层命令
## 在 CommandBus 事务内调用；状态只落在 `data.fleet`，不复制 `data.ship`。
##
## 关键依赖：`RegistryHub`（ship_archetypes / captains / formations /
## fleet_doctrines）、`FleetOps`、`GameState`
##
## ## 契约与约束
## - 引用校验：ship archetype / captain / formation / doctrine 必须存在；captain 的
##   `commandable_archetypes` 必须包含目标船的 archetype；formation slot 必须存在于
##   当前 formation 且互斥；doctrine 的 `formation` 引用若存在则必须可解析。
## - 旗舰：`data.fleet.flagship = "flagship"`，其 archetype 始终由 `data.ship.hull_id`
##   反查，不允许 remove；`assign_captain` 对旗舰同样校验可指挥船型。role 为
##   `flagship` 的 formation 槽位只能由旗舰使用（`flagship_slot_only`）；`add_ship`
##   自动分配槽位时跳过旗舰槽与已占槽。`ship.install_module` 换 hull 后调用
##   `reconcile_flagship_after_hull_change`，释放已无法指挥新旗舰 archetype 的舰长。
## - 容量：`FleetOps.MAX_SHIPS` 为框架上限；有 formation 时缺省按
##   `min(MAX_SHIPS, formation.slots.size())`，显式 `max_ships` 也以 MAX_SHIPS 封顶；
##   无 formation 时用 MAX_SHIPS。
## - 清空语义：`captain_id:""` / `doctrine_id:""` 清空对应选择；`slot:""` 清空单船槽位；
##   `formation_id:""` 清空整队编队并清空所有槽位。切换 formation 时还会清空 role 变成
##   `flagship` 的槽位上的非旗舰船。
## - 领域事件（由命令层发布）：`fleet.captain_assigned` / `fleet.formation_changed` /
##   `fleet.slot_assigned` / `fleet.doctrine_changed` / `fleet.ship_added` /
##   `fleet.ship_removed`。
## - 同一 captain 只能指挥一艘船；删除船会隐式释放其 captain（不复制其它状态）。
## @end-static-doc


## Assigns (or clears, with an empty captain_id) the captain of one ship.
static func assign_captain(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary:
	var fleet := FleetOps.ensure_structure(state, hub)
	var ship_id := String(params.get("ship_id", FleetOps.FLAGSHIP_ID))
	var ship := FleetOps.ship_entry(fleet, ship_id)
	if ship.is_empty():
		return Result.fail("ship_not_found", "ui.error.ship_not_found", {"ship_id": ship_id})
	var captain_id := String(params.get("captain_id", ""))
	if captain_id.is_empty():
		var previous := String(ship.get("captain_id", ""))
		ship["captain_id"] = ""
		return Result.ok({
			"ship_id": ship_id,
			"captain_id": "",
			"previous_captain_id": previous,
		}, [_captain_event(ship_id, "")])
	var captain := hub.get_by_id(ContentTypes.CAPTAIN, captain_id)
	if captain == null:
		return Result.fail("unknown_captain", "ui.error.unknown_captain", {"captain_id": captain_id})
	var already := _captain_ship(fleet, captain_id)
	if not already.is_empty() and already != ship_id:
		return Result.fail("captain_already_assigned", "ui.error.captain_already_assigned", {
			"captain_id": captain_id,
			"ship_id": already,
		})
	var archetype_id := _ship_archetype_id(state, hub, ship)
	if archetype_id.is_empty():
		return Result.fail("unknown_archetype", "ui.error.unknown_ship_archetype", {"ship_id": ship_id})
	if not _captain_can_command(captain, archetype_id):
		return Result.fail("captain_cannot_command", "ui.error.captain_cannot_command", {
			"captain_id": captain_id,
			"archetype_id": archetype_id,
		})
	ship["captain_id"] = captain_id
	return Result.ok({
		"ship_id": ship_id,
		"captain_id": captain_id,
		"wage_per_voyage": float(captain.data.get("wage_per_voyage", 0.0)),
	}, [_captain_event(ship_id, captain_id)])


## Sets the fleet formation (`formation_id`) and/or assigns a ship to a formation slot.
##
## Accepted params:
## - `formation_id`: switch (or clear, with `""`) the whole fleet's formation; ships
##   whose slots no longer exist are unassigned. Clearing also clears every slot.
## - `ship_id` + `slot`: assign one ship to a formation slot; `slot: ""` clears that
##   ship's slot. Requires a current formation and enforces slot uniqueness.
## Supplying both applies the formation first, then the slot.
static func set_formation(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary:
	var fleet := FleetOps.ensure_structure(state, hub)
	var has_formation := params.has("formation_id")
	var has_slot := params.has("ship_id") or params.has("slot")
	if not has_formation and not has_slot:
		return Result.fail("missing_formation", "ui.error.missing_formation")
	var events: Array = []
	if has_formation:
		var formation_id := String(params.get("formation_id", ""))
		if formation_id.is_empty():
			fleet["formation_id"] = ""
			for entry in fleet.get("ships", []):
				if entry is Dictionary:
					(entry as Dictionary)["formation_slot"] = ""
			events.append({
				"type": "fleet.formation_changed",
				"payload": {"formation_id": ""},
			})
		else:
			var formation := hub.get_by_id(ContentTypes.FORMATION, formation_id)
			if formation == null:
				return Result.fail("unknown_formation", "ui.error.unknown_formation", {"formation_id": formation_id})
			fleet["formation_id"] = formation_id
			var valid_slots := FleetOps.formation_slot_ids(hub, formation_id)
			var flagship_slots := FleetOps.flagship_slot_ids(hub, formation_id)
			for entry in fleet.get("ships", []):
				if entry is Dictionary:
					var ship_entry: Dictionary = entry
					var slot_id := String(ship_entry.get("formation_slot", ""))
					if slot_id.is_empty():
						continue
					var ship_id := String(ship_entry.get("ship_id", ""))
					var slot_missing := not valid_slots.has(slot_id)
					var roster_in_flagship_slot := flagship_slots.has(slot_id) and ship_id != FleetOps.FLAGSHIP_ID
					if slot_missing or roster_in_flagship_slot:
						ship_entry["formation_slot"] = ""
			var cap := FleetOps.max_ships(hub, formation_id)
			if int((fleet.get("ships", []) as Array).size()) > cap:
				return Result.fail("fleet_full", "ui.error.fleet_full", {
					"ship_count": int((fleet.get("ships", []) as Array).size()),
					"max_ships": cap,
				})
			events.append({
				"type": "fleet.formation_changed",
				"payload": {"formation_id": formation_id},
			})
	if has_slot:
		var ship_id := String(params.get("ship_id", FleetOps.FLAGSHIP_ID))
		var slot_id := String(params.get("slot", ""))
		var ship := FleetOps.ship_entry(fleet, ship_id)
		if ship.is_empty():
			return Result.fail("ship_not_found", "ui.error.ship_not_found", {"ship_id": ship_id})
		var formation_id := String(fleet.get("formation_id", ""))
		if slot_id.is_empty():
			ship["formation_slot"] = ""
			events.append({
				"type": "fleet.slot_assigned",
				"payload": {"ship_id": ship_id, "slot": "", "formation_id": formation_id},
			})
		else:
			if formation_id.is_empty():
				return Result.fail("no_formation", "ui.error.no_formation")
			if not FleetOps.is_valid_slot_id(slot_id):
				return Result.fail("invalid_formation_slot", "ui.error.invalid_formation_slot", {"slot": slot_id})
			var slot := FleetOps.formation_slot(hub, formation_id, slot_id)
			if slot.is_empty():
				return Result.fail("invalid_formation_slot", "ui.error.invalid_formation_slot", {
					"slot": slot_id,
					"formation_id": formation_id,
				})
			if String(slot.get("role", "")) == "flagship" and ship_id != FleetOps.FLAGSHIP_ID:
				return Result.fail("flagship_slot_only", "ui.error.flagship_slot_only", {
					"slot": slot_id,
					"ship_id": ship_id,
				})
			var occupied := _slot_ship(fleet, slot_id)
			if not occupied.is_empty() and occupied != ship_id:
				return Result.fail("formation_slot_occupied", "ui.error.formation_slot_occupied", {
					"slot": slot_id,
					"ship_id": occupied,
				})
			ship["formation_slot"] = slot_id
			events.append({
				"type": "fleet.slot_assigned",
				"payload": {"ship_id": ship_id, "slot": slot_id, "formation_id": formation_id},
			})
	return Result.ok({
		"formation_id": String(fleet.get("formation_id", "")),
		"ship_id": String(params.get("ship_id", "")) if has_slot else "",
		"slot": String(params.get("slot", "")) if has_slot else "",
	}, events)


## Selects the fleet doctrine. An empty `doctrine_id` clears it.
static func set_doctrine(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary:
	var fleet := FleetOps.ensure_structure(state, hub)
	var doctrine_id := String(params.get("doctrine_id", ""))
	if not doctrine_id.is_empty():
		var doctrine := hub.get_by_id(ContentTypes.FLEET_DOCTRINE, doctrine_id)
		if doctrine == null:
			return Result.fail("unknown_doctrine", "ui.error.unknown_fleet_doctrine", {"doctrine_id": doctrine_id})
		var formation_ref := String(doctrine.data.get("formation", ""))
		if not formation_ref.is_empty() and hub.get_by_id(ContentTypes.FORMATION, formation_ref) == null:
			return Result.fail("unknown_formation", "ui.error.unknown_formation", {"formation_id": formation_ref})
	fleet["doctrine_id"] = doctrine_id
	return Result.ok({
		"doctrine_id": doctrine_id,
	}, [{"type": "fleet.doctrine_changed", "payload": {"doctrine_id": doctrine_id}}])


## Adds a roster ship. `archetype_id` is required; optional `captain_id` and
## `formation_slot` are validated like their dedicated commands.
static func add_ship(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary:
	var fleet := FleetOps.ensure_structure(state, hub)
	var archetype_id := String(params.get("archetype_id", ""))
	if archetype_id.is_empty():
		return Result.fail("missing_archetype", "ui.error.missing_archetype")
	var archetype := hub.get_by_id(ContentTypes.SHIP_ARCHETYPE, archetype_id)
	if archetype == null:
		return Result.fail("unknown_archetype", "ui.error.unknown_ship_archetype", {"archetype_id": archetype_id})
	var formation_id := String(fleet.get("formation_id", ""))
	var cap := FleetOps.max_ships(hub, formation_id)
	if int((fleet.get("ships", []) as Array).size()) >= cap:
		return Result.fail("fleet_full", "ui.error.fleet_full", {
			"ship_count": int((fleet.get("ships", []) as Array).size()),
			"max_ships": cap,
		})
	var captain_id := String(params.get("captain_id", ""))
	if not captain_id.is_empty():
		if hub.get_by_id(ContentTypes.CAPTAIN, captain_id) == null:
			return Result.fail("unknown_captain", "ui.error.unknown_captain", {"captain_id": captain_id})
		if not _captain_ship(fleet, captain_id).is_empty():
			return Result.fail("captain_already_assigned", "ui.error.captain_already_assigned", {
				"captain_id": captain_id,
				"ship_id": _captain_ship(fleet, captain_id),
			})
		if not _captain_can_command(hub.get_by_id(ContentTypes.CAPTAIN, captain_id), archetype_id):
			return Result.fail("captain_cannot_command", "ui.error.captain_cannot_command", {
				"captain_id": captain_id,
				"archetype_id": archetype_id,
			})
	var slot_id := String(params.get("formation_slot", ""))
	if not slot_id.is_empty():
		if formation_id.is_empty():
			return Result.fail("no_formation", "ui.error.no_formation")
		var slot := FleetOps.formation_slot(hub, formation_id, slot_id)
		if slot.is_empty():
			return Result.fail("invalid_formation_slot", "ui.error.invalid_formation_slot", {"slot": slot_id})
		if String(slot.get("role", "")) == "flagship":
			return Result.fail("flagship_slot_only", "ui.error.flagship_slot_only", {
				"slot": slot_id,
				"ship_id": "roster",
			})
		if not _slot_ship(fleet, slot_id).is_empty():
			return Result.fail("formation_slot_occupied", "ui.error.formation_slot_occupied", {
				"slot": slot_id,
				"ship_id": _slot_ship(fleet, slot_id),
			})
	elif not formation_id.is_empty():
		slot_id = _first_free_slot(hub, fleet, formation_id)
	var entry := FleetOps.DEFAULT_SHIP.duplicate(true)
	entry["ship_id"] = FleetOps.next_ship_id(fleet)
	entry["archetype_id"] = archetype_id
	entry["captain_id"] = captain_id
	entry["formation_slot"] = slot_id
	entry["condition"] = 1.0
	(fleet["ships"] as Array).append(entry)
	return Result.ok(entry.duplicate(true), [{
		"type": "fleet.ship_added",
		"payload": {"ship_id": String(entry["ship_id"]), "archetype_id": archetype_id},
	}])


## Removes a roster ship; the flagship cannot be removed.
static func remove_ship(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary:
	var fleet := FleetOps.ensure_structure(state, hub)
	var ship_id := String(params.get("ship_id", ""))
	if ship_id == FleetOps.FLAGSHIP_ID:
		return Result.fail("flagship_required", "ui.error.flagship_required", {"ship_id": ship_id})
	var entry := FleetOps.ship_entry(fleet, ship_id)
	if entry.is_empty():
		return Result.fail("ship_not_found", "ui.error.ship_not_found", {"ship_id": ship_id})
	var ships: Array = fleet.get("ships", [])
	ships.erase(entry)
	fleet["ships"] = ships
	return Result.ok({"ship_id": ship_id}, [{
		"type": "fleet.ship_removed",
		"payload": {"ship_id": ship_id},
	}])


## Reconciles the flagship after `data.ship.hull_id` changed. The flagship archetype
## is derived from the hull, so a captain that could command the old archetype may be
## unable to command the new one. Such a captain is released (an empty
## `fleet.captain_assigned` event is returned); the command layer publishes it.
## Does nothing when no fleet block exists, which keeps `data.fleet` lazy.
static func reconcile_flagship_after_hull_change(state: GameState, hub: RegistryHub) -> Array:
	if state == null or hub == null or not state.data.has(FleetOps.FLEET_KEY):
		return []
	var fleet := FleetOps.ensure_structure(state, hub)
	var flagship := FleetOps.ship_entry(fleet, FleetOps.FLAGSHIP_ID)
	if flagship.is_empty():
		return []
	var captain_id := String(flagship.get("captain_id", ""))
	if captain_id.is_empty():
		return []
	var archetype_id := FleetOps.flagship_archetype_id(state, hub)
	var captain := hub.get_by_id(ContentTypes.CAPTAIN, captain_id)
	if captain != null and _captain_can_command(captain, archetype_id):
		return []
	flagship["captain_id"] = ""
	return [_captain_event(FleetOps.FLAGSHIP_ID, "")]


static func _ship_archetype_id(state: GameState, hub: RegistryHub, ship: Dictionary) -> String:
	if String(ship.get("ship_id", "")) == FleetOps.FLAGSHIP_ID:
		return FleetOps.flagship_archetype_id(state, hub)
	return String(ship.get("archetype_id", ""))


static func _captain_can_command(captain: ContentDefinition, archetype_id: String) -> bool:
	if captain == null or archetype_id.is_empty():
		return false
	var commandable: Array = captain.data.get("commandable_archetypes", [])
	return commandable.has(archetype_id)


static func _captain_ship(fleet: Dictionary, captain_id: String) -> String:
	for entry in fleet.get("ships", []):
		if entry is Dictionary and String((entry as Dictionary).get("captain_id", "")) == captain_id:
			return String((entry as Dictionary).get("ship_id", ""))
	return ""


static func _slot_ship(fleet: Dictionary, slot_id: String) -> String:
	for entry in fleet.get("ships", []):
		if entry is Dictionary and String((entry as Dictionary).get("formation_slot", "")) == slot_id:
			return String((entry as Dictionary).get("ship_id", ""))
	return ""


static func _first_free_slot(hub: RegistryHub, fleet: Dictionary, formation_id: String) -> String:
	var flagship_slots := FleetOps.flagship_slot_ids(hub, formation_id)
	for slot_id in FleetOps.formation_slot_ids(hub, formation_id):
		if flagship_slots.has(slot_id):
			continue
		if _slot_ship(fleet, slot_id).is_empty():
			return slot_id
	return ""


static func _captain_event(ship_id: String, captain_id: String) -> Dictionary:
	return {
		"type": "fleet.captain_assigned",
		"payload": {"ship_id": ship_id, "captain_id": captain_id},
	}
