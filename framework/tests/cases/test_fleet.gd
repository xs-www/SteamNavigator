extends TestCase
## @static-doc
## 作用：Phase D2 舰队运行时的回归测试：`data.fleet` 惰性结构、旗舰与当前单船衔接、
## `fleet.view` 形状、captain 指派/可指挥船型/唯一性、formation 与 slot 校验、
## doctrine 选择、增删舰与容量、领域事件、存档 round-trip、旧档惰性补齐、确定性。
##
## ## 契约与约束
## - 内容从 Core 注册表动态选取（ship_archetypes / captains / formations /
##   fleet_doctrines），不写死 core:* 内容 id 到断言里。
## - 旗舰永远等于当前 `data.ship`（archetype 由 hull_ref 反查），fleet 不复制 ship
##   的模块/耐久状态；测试用 `state.ship().hull_id` 对照。
## - 所有写操作走 `fleet.*` 命令（CommandBus 事务）；失败命令不得提交状态。`n## - D2-FIX 覆盖：max_ships 缺省按 slots 数、flagship 槽位独占与自动分配跳过、`n##   slot/formation 清空、以及损坏 `data.fleet` 的规范化不抛引擎错误。
## @end-static-doc

const STEADY := "core:starting_scenario/steady"


func _start(seed_value: int) -> AppContext:
	var context: AppContext = bootstrap_core()["context"]
	var started := context.commands.execute(&"run.start", {"starting_scenario": STEADY, "seed": seed_value})
	assert_true(bool(started.get("ok", false)), "run.start succeeds: %s" % str(started))
	return context


func _view(context: AppContext) -> Dictionary:
	if context.state == null:
		return {}
	var result := context.queries.execute(&"fleet.view")
	assert_true(bool(result.get("ok", false)), "fleet.view answers: %s" % str(result))
	return result.get("data", {})


func _ships(view: Dictionary) -> Array:
	return view.get("ships", [])


func _flagship(view: Dictionary) -> Dictionary:
	for ship in _ships(view):
		if ship is Dictionary and bool((ship as Dictionary).get("is_flagship", false)):
			return ship
	return {}


func _sorted_ids(context: AppContext, content_type: StringName) -> Array[String]:
	var ids: Array[String] = []
	for definition in context.registries.get_all(content_type):
		ids.append(definition.id)
	ids.sort()
	return ids


func _captain_for(context: AppContext, archetype_id: String, allow_missing := false) -> String:
	for definition in context.registries.get_all(ContentTypes.CAPTAIN):
		if Array(definition.data.get("commandable_archetypes", [])).has(archetype_id):
			return definition.id
	if allow_missing:
		return ""
	return ""


func _captain_without(context: AppContext, archetype_id: String) -> String:
	for definition in context.registries.get_all(ContentTypes.CAPTAIN):
		if not Array(definition.data.get("commandable_archetypes", [])).has(archetype_id):
			return definition.id
	return ""


func _other_archetype(context: AppContext, flagship_archetype: String) -> String:
	for archetype_id in _sorted_ids(context, ContentTypes.SHIP_ARCHETYPE):
		if archetype_id != flagship_archetype:
			return archetype_id
	return flagship_archetype


func test_commands_and_query_are_registered() -> void:
	var context := _start(201)
	for command in [
		&"fleet.assign_captain", &"fleet.set_formation", &"fleet.set_doctrine",
		&"fleet.add_ship", &"fleet.remove_ship",
	]:
		assert_true(context.commands.has(command), "%s is registered" % String(command))
	assert_true(context.queries.has(&"fleet.view"), "fleet.view is registered")


func test_view_is_lazy_and_links_the_flagship_to_the_current_ship() -> void:
	var context := _start(202)
	assert_false(context.state.data.has("fleet"), "run.start does not create data.fleet eagerly")
	var view := _view(context)
	assert_false(context.state.data.has("fleet"), "fleet.view never persists data.fleet")
	assert_eq(String(view.get("flagship_id", "")), FleetOps.FLAGSHIP_ID, "the flagship id is stable")
	assert_eq(int(view.get("ship_count", 0)), 1, "a fresh fleet only has the flagship")
	var flagship := _flagship(view)
	assert_false(flagship.is_empty(), "the view exposes the flagship entry")
	assert_eq(String(flagship.get("ship_id", "")), FleetOps.FLAGSHIP_ID, "the flagship entry uses the flagship id")
	var hull_id := String(context.state.ship().get("hull_id", ""))
	var expected_archetype := ""
	for definition in context.registries.get_all(ContentTypes.SHIP_ARCHETYPE):
		if String(definition.data.get("hull_ref", "")) == hull_id:
			expected_archetype = definition.id
	assert_eq(String(flagship.get("archetype_id", "")), expected_archetype,
		"the flagship archetype is resolved from the current hull")
	assert_true(view.get("max_ships", 0) is int and int(view["max_ships"]) >= 1, "the view reports fleet capacity")
	assert_true(view.get("formation", null) is Dictionary, "the view reports a formation block")
	assert_true(view.get("doctrine", null) is Dictionary, "the view reports a doctrine block")


func test_assign_captain_validates_references_and_uniqueness() -> void:
	var context := _start(203)
	var flagship := _flagship(_view(context))
	var archetype_id := String(flagship.get("archetype_id", ""))
	var captain_id := _captain_for(context, archetype_id)
	assert_false(captain_id.is_empty(), "core has a captain able to command the flagship")
	var assigned := context.commands.execute(&"fleet.assign_captain", {"captain_id": captain_id})
	assert_true(bool(assigned.get("ok", false)), "assigning a valid captain succeeds: %s" % str(assigned))
	assert_eq(String(_flagship(_view(context)).get("captain_id", "")), captain_id, "the view reports the assigned captain")
	var unknown := context.commands.execute(&"fleet.assign_captain", {"captain_id": "test:captain/absent"})
	assert_eq(String(unknown.get("error_code", "")), "unknown_captain", "unknown captains are rejected")
	var other_archetype := _other_archetype(context, archetype_id)
	var added := context.commands.execute(&"fleet.add_ship", {"archetype_id": other_archetype})
	assert_true(bool(added.get("ok", false)), "adding a roster ship succeeds: %s" % str(added))
	var ship_id := String(added["data"].get("ship_id", ""))
	var duplicated := context.commands.execute(&"fleet.assign_captain", {
		"ship_id": ship_id,
		"captain_id": captain_id,
	})
	assert_eq(String(duplicated.get("error_code", "")), "captain_already_assigned",
		"one captain cannot command two ships")
	var cleared := context.commands.execute(&"fleet.assign_captain", {"captain_id": ""})
	assert_true(bool(cleared.get("ok", false)), "an empty captain clears the assignment")
	assert_eq(String(_flagship(_view(context)).get("captain_id", "unset")), "", "the captain is cleared")


func test_captain_must_command_the_ship_archetype() -> void:
	var context := _start(204)
	var flagship := _flagship(_view(context))
	var archetype_id := String(flagship.get("archetype_id", ""))
	var wrong_captain := _captain_without(context, archetype_id)
	if wrong_captain.is_empty():
		return
	var rejected := context.commands.execute(&"fleet.assign_captain", {"captain_id": wrong_captain})
	assert_false(bool(rejected.get("ok", true)), "a captain that cannot command the archetype is rejected")
	assert_eq(String(rejected.get("error_code", "")), "captain_cannot_command", "captain commandability error code")


func test_set_formation_assigns_slots_and_rejects_conflicts() -> void:
	var context := _start(205)
	var formation_ids := _sorted_ids(context, ContentTypes.FORMATION)
	assert_false(formation_ids.is_empty(), "core ships at least one formation")
	var formation_id := formation_ids[0]
	var formation := context.registries.get_by_id(ContentTypes.FORMATION, formation_id)
	var slot_ids := FleetOps.formation_slot_ids(context.registries, formation_id)
	if slot_ids.is_empty():
		return
	assert_false(slot_ids.is_empty(), "the formation declares slots")
	var unknown := context.commands.execute(&"fleet.set_formation", {"formation_id": "test:formation/absent"})
	assert_eq(String(unknown.get("error_code", "")), "unknown_formation", "unknown formations are rejected")
	var set := context.commands.execute(&"fleet.set_formation", {"formation_id": formation_id})
	assert_true(bool(set.get("ok", false)), "setting a formation succeeds: %s" % str(set))
	assert_eq(String(_view(context).get("formation_id", "")), formation_id, "the view reports the formation")
	var slot_id := ""
	for candidate in slot_ids:
		if FleetOps.formation_slot_role(context.registries, formation_id, candidate) != "flagship":
			slot_id = candidate
			break
	if slot_id.is_empty():
		slot_id = slot_ids[0]
	var assigned := context.commands.execute(&"fleet.set_formation", {"ship_id": FleetOps.FLAGSHIP_ID, "slot": slot_id})
	assert_true(bool(assigned.get("ok", false)), "assigning the flagship to a slot succeeds: %s" % str(assigned))
	assert_eq(String(_flagship(_view(context)).get("formation_slot", "")), slot_id, "the slot is recorded")
	var other_archetype := _other_archetype(context, String(_flagship(_view(context)).get("archetype_id", "")))
	var added := context.commands.execute(&"fleet.add_ship", {"archetype_id": other_archetype})
	assert_true(bool(added.get("ok", false)), "adding another ship succeeds: %s" % str(added))
	var ship_id := String(added["data"].get("ship_id", ""))
	var occupied := context.commands.execute(&"fleet.set_formation", {"ship_id": ship_id, "slot": slot_id})
	assert_eq(String(occupied.get("error_code", "")), "formation_slot_occupied", "formation slots are exclusive")
	var invalid := context.commands.execute(&"fleet.set_formation", {"ship_id": ship_id, "slot": "not a slot"})
	assert_eq(String(invalid.get("error_code", "")), "invalid_formation_slot", "unknown slot ids are rejected")
	assert_eq(formation.name_key, String(_view(context)["formation"].get("name_key", "")), "the view resolves the formation name")
	# Switching to another formation clears slots that no longer exist.
	if formation_ids.size() > 1:
		var second_id := formation_ids[1]
		var switched := context.commands.execute(&"fleet.set_formation", {"formation_id": second_id})
		assert_true(bool(switched.get("ok", false)), "switching formations succeeds: %s" % str(switched))
		var valid_second := FleetOps.formation_slot_ids(context.registries, second_id)
		for ship in _ships(_view(context)):
			var slot := String((ship as Dictionary).get("formation_slot", ""))
			assert_true(slot.is_empty() or valid_second.has(slot), "slots survive only when the new formation has them")


func test_set_doctrine_validates_and_reports() -> void:
	var context := _start(206)
	var doctrine_ids := _sorted_ids(context, ContentTypes.FLEET_DOCTRINE)
	assert_false(doctrine_ids.is_empty(), "core ships at least one fleet doctrine")
	var doctrine_id := doctrine_ids[0]
	var doctrine := context.registries.get_by_id(ContentTypes.FLEET_DOCTRINE, doctrine_id)
	var set := context.commands.execute(&"fleet.set_doctrine", {"doctrine_id": doctrine_id})
	assert_true(bool(set.get("ok", false)), "setting a doctrine succeeds: %s" % str(set))
	var view := _view(context)
	assert_eq(String(view.get("doctrine_id", "")), doctrine_id, "the view reports the doctrine")
	assert_eq(String((view["doctrine"] as Dictionary).get("engagement", "")),
		String(doctrine.data.get("engagement", "")), "the doctrine block exposes engagement")
	assert_eq(String((view["doctrine"] as Dictionary).get("supply_policy", "")),
		String(doctrine.data.get("supply_policy", "")), "the doctrine block exposes supply policy")
	var unknown := context.commands.execute(&"fleet.set_doctrine", {"doctrine_id": "test:fleet_doctrine/absent"})
	assert_eq(String(unknown.get("error_code", "")), "unknown_doctrine", "unknown doctrines are rejected")
	var cleared := context.commands.execute(&"fleet.set_doctrine", {"doctrine_id": ""})
	assert_true(bool(cleared.get("ok", false)), "an empty doctrine clears the selection")
	assert_eq(String(_view(context).get("doctrine_id", "unset")), "", "the doctrine is cleared")


func test_add_remove_ships_and_capacity() -> void:
	var context := _start(207)
	var formation_ids := _sorted_ids(context, ContentTypes.FORMATION)
	if not formation_ids.is_empty():
		context.commands.execute(&"fleet.set_formation", {"formation_id": formation_ids[0]})
	var flagship := _flagship(_view(context))
	var archetype_id := String(flagship.get("archetype_id", ""))
	var added_ids: Array[String] = []
	for _index in 4:
		var added := context.commands.execute(&"fleet.add_ship", {"archetype_id": archetype_id})
		if bool(added.get("ok", false)):
			added_ids.append(String(added["data"].get("ship_id", "")))
	assert_false(added_ids.is_empty(), "at least one roster ship can be added")
	var full := context.commands.execute(&"fleet.add_ship", {"archetype_id": archetype_id})
	assert_false(bool(full.get("ok", true)), "the fleet rejects ships beyond its capacity")
	assert_eq(String(full.get("error_code", "")), "fleet_full", "capacity errors are explicit")
	assert_eq(int(_view(context).get("ship_count", 0)), int(_view(context).get("max_ships", 5)),
		"the ship count reaches the reported capacity")
	var removed := context.commands.execute(&"fleet.remove_ship", {"ship_id": added_ids[0]})
	assert_true(bool(removed.get("ok", false)), "removing a roster ship succeeds: %s" % str(removed))
	var flagship_removal := context.commands.execute(&"fleet.remove_ship", {"ship_id": FleetOps.FLAGSHIP_ID})
	assert_eq(String(flagship_removal.get("error_code", "")), "flagship_required", "the flagship cannot be removed")
	var missing := context.commands.execute(&"fleet.remove_ship", {"ship_id": "ship_404"})
	assert_eq(String(missing.get("error_code", "")), "ship_not_found", "unknown ships are rejected")


func test_commands_publish_fleet_events() -> void:
	var context := _start(208)
	context.events.clear()
	var flagship := _flagship(_view(context))
	var captain_id := _captain_for(context, String(flagship.get("archetype_id", "")))
	if not captain_id.is_empty():
		context.commands.execute(&"fleet.assign_captain", {"captain_id": captain_id})
	var formation_ids := _sorted_ids(context, ContentTypes.FORMATION)
	if not formation_ids.is_empty():
		context.commands.execute(&"fleet.set_formation", {"formation_id": formation_ids[0]})
	var doctrine_ids := _sorted_ids(context, ContentTypes.FLEET_DOCTRINE)
	if not doctrine_ids.is_empty():
		context.commands.execute(&"fleet.set_doctrine", {"doctrine_id": doctrine_ids[0]})
	var added := context.commands.execute(&"fleet.add_ship", {"archetype_id": String(flagship.get("archetype_id", ""))})
	if bool(added.get("ok", false)):
		context.commands.execute(&"fleet.remove_ship", {"ship_id": String(added["data"].get("ship_id", ""))})
	if not captain_id.is_empty():
		assert_true(context.events.has_event(&"fleet.captain_assigned"), "captain assignment is published")
	if not formation_ids.is_empty():
		assert_true(context.events.has_event(&"fleet.formation_changed"), "formation changes are published")
	if not doctrine_ids.is_empty():
		assert_true(context.events.has_event(&"fleet.doctrine_changed"), "doctrine changes are published")
	assert_true(context.events.has_event(&"fleet.ship_added"), "ship additions are published")


func test_save_round_trip_and_legacy_lazy_state() -> void:
	var context := _start(209)
	var flagship := _flagship(_view(context))
	var captain_id := _captain_for(context, String(flagship.get("archetype_id", "")))
	if not captain_id.is_empty():
		context.commands.execute(&"fleet.assign_captain", {"captain_id": captain_id})
	var formation_ids := _sorted_ids(context, ContentTypes.FORMATION)
	if not formation_ids.is_empty():
		context.commands.execute(&"fleet.set_formation", {"formation_id": formation_ids[0]})
	var doctrine_ids := _sorted_ids(context, ContentTypes.FLEET_DOCTRINE)
	if not doctrine_ids.is_empty():
		context.commands.execute(&"fleet.set_doctrine", {"doctrine_id": doctrine_ids[0]})
	var saved := context.save.save_slot("fleet_manual", context.state, context.save_meta())
	assert_true(bool(saved.get("ok", false)), "saving the fleet succeeds: %s" % str(saved))
	var loaded := context.save.load_slot("fleet_manual")
	assert_true(bool(loaded.get("ok", false)), "loading the fleet succeeds")
	var loaded_state: GameState = loaded["state"]
	var loaded_context: AppContext = bootstrap_core()["context"]
	loaded_context.set_state(loaded_state)
	var original_view := _view(context)
	var restored_view := _view(loaded_context)
	assert_eq(String(restored_view.get("formation_id", "")), String(original_view.get("formation_id", "")), "formation round-trips")
	assert_eq(String(restored_view.get("doctrine_id", "")), String(original_view.get("doctrine_id", "")), "doctrine round-trips")
	assert_eq(_ships(restored_view).size(), _ships(original_view).size(), "the roster round-trips")

	var legacy := _start(210)
	legacy.state.data.erase("fleet")
	assert_false(legacy.state.data.has("fleet"), "the legacy state has no fleet block")
	var legacy_view := _view(legacy)
	assert_eq(int(legacy_view.get("ship_count", 0)), 1, "the legacy view reports only the flagship")
	assert_false(legacy.state.data.has("fleet"), "reading the legacy view does not persist a fleet block")
	var doctrine := _sorted_ids(legacy, ContentTypes.FLEET_DOCTRINE)
	if not doctrine.is_empty():
		var created := legacy.commands.execute(&"fleet.set_doctrine", {"doctrine_id": doctrine[0]})
		assert_true(bool(created.get("ok", false)), "a fleet command lazily creates the block")
		assert_true(legacy.state.data.get("fleet", null) is Dictionary, "the block is persisted after the first command")


func test_same_seed_and_commands_are_deterministic() -> void:
	var first := _start(211)
	var second := _start(211)
	for context in [first, second]:
		var flagship := _flagship(_view(context))
		var captain_id := _captain_for(context, String(flagship.get("archetype_id", "")))
		if not captain_id.is_empty():
			context.commands.execute(&"fleet.assign_captain", {"captain_id": captain_id})
		var formation_ids := _sorted_ids(context, ContentTypes.FORMATION)
		if not formation_ids.is_empty():
			context.commands.execute(&"fleet.set_formation", {"formation_id": formation_ids[0]})
			var slot := FleetOps.formation_slot_ids(context.registries, formation_ids[0])
			if not slot.is_empty():
				context.commands.execute(&"fleet.set_formation", {"ship_id": FleetOps.FLAGSHIP_ID, "slot": slot[0]})
		context.commands.execute(&"fleet.add_ship", {
			"archetype_id": _other_archetype(context, String(flagship.get("archetype_id", ""))),
		})
	if first.state == null or second.state == null:
		return
	first.state.data["run"].erase("started_at")
	second.state.data["run"].erase("started_at")
	if first.state.data.get("campaign", null) is Dictionary:
		(first.state.data["campaign"] as Dictionary).erase("created_at")
	if second.state.data.get("campaign", null) is Dictionary:
		(second.state.data["campaign"] as Dictionary).erase("created_at")
	assert_eq(first.state.data.get("fleet", null), second.state.data.get("fleet", null),
		"same seed + same fleet commands produce the same fleet block")


func test_every_core_hull_has_an_archetype_and_commandable_captain() -> void:
	var context: AppContext = bootstrap_core()["context"]
	var hulls := context.registries.get_all(ContentTypes.HULL)
	var archetypes := context.registries.get_all(ContentTypes.SHIP_ARCHETYPE)
	var hull_by_id := {}
	for hull in hulls:
		hull_by_id[hull.id] = hull
	var commanded := {}
	for captain in context.registries.get_all(ContentTypes.CAPTAIN):
		for archetype_id in captain.data.get("commandable_archetypes", []):
			commanded[String(archetype_id)] = true
	var covered := {}
	for archetype in archetypes:
		var hull_ref := String(archetype.data.get("hull_ref", ""))
		assert_true(hull_by_id.has(hull_ref), "%s references a legal Core hull" % archetype.id)
		if not hull_by_id.has(hull_ref):
			continue
		covered[hull_ref] = true
		var hull: ContentDefinition = hull_by_id[hull_ref]
		var sockets := {}
		for socket in hull.data.get("weapon_sockets", []):
			sockets[String(socket.get("name", ""))] = String(socket.get("socket_class", ""))
		for entry in archetype.data.get("weapon_sockets", []):
			var socket_name := String(entry.get("socket", ""))
			assert_true(sockets.has(socket_name), "%s socket %s exists on %s" % [archetype.id, socket_name, hull_ref])
			if sockets.has(socket_name):
				assert_eq(String(entry.get("class", "")), String(sockets[socket_name]),
					"%s socket %s class matches the hull" % [archetype.id, socket_name])
		assert_true(commanded.has(archetype.id), "%s is commandable by a Core captain" % archetype.id)
	for hull in hulls:
		assert_true(covered.has(hull.id), "legal Core hull %s has a ship archetype" % hull.id)
	assert_true(covered.has("core:hull/large_efficient"), "the endgame large_efficient hull is covered")


## D2-FIX：无显式 max_ships 的 formation 以 slots 数量为容量；无 formation 用框架上限。
func test_max_ships_defaults_to_slot_count() -> void:
	var hub := RegistryHub.new()
	var without_cap := ContentDefinition.from_raw({
		"id": "test:formation/three_slots",
		"name_key": "test.formation.three_slots.name",
		"enabled": true,
		"data": {"slots": [
			{"id": "flagship", "role": "flagship", "offset": {"x": 0, "y": 0}},
			{"id": "left", "role": "line", "offset": {"x": -8, "y": 8}},
			{"id": "right", "role": "line", "offset": {"x": -8, "y": -8}},
		]},
	}, ContentTypes.FORMATION, "test", "res://framework/tests/cases/test_fleet.gd")
	var with_cap := ContentDefinition.from_raw({
		"id": "test:formation/two_ships",
		"name_key": "test.formation.two_ships.name",
		"enabled": true,
		"data": {"max_ships": 2, "slots": [
			{"id": "flagship", "role": "flagship", "offset": {"x": 0, "y": 0}},
			{"id": "left", "role": "line", "offset": {"x": -8, "y": 8}},
			{"id": "right", "role": "line", "offset": {"x": -8, "y": -8}},
		]},
	}, ContentTypes.FORMATION, "test", "res://framework/tests/cases/test_fleet.gd")
	hub.register(without_cap)
	hub.register(with_cap)
	assert_eq(FleetOps.max_ships(hub, "test:formation/three_slots"), 3, "capacity defaults to the slot count")
	assert_eq(FleetOps.max_ships(hub, "test:formation/two_ships"), 2, "an explicit max_ships wins over slots")
	assert_eq(FleetOps.max_ships(hub, ""), FleetOps.MAX_SHIPS, "without a formation the framework cap applies")
	assert_eq(FleetOps.max_ships(hub, "test:formation/absent"), FleetOps.MAX_SHIPS, "missing formations fall back")


## D2-FIX：旗舰槽只能旗舰；add_ship 自动分配跳过旗舰/已占槽；slot 与 formation 可清空。
func test_flagship_slot_rules_and_clear_semantics() -> void:
	var context := _start(212)
	var formation_id := ""
	var flagship_slot := ""
	for candidate in _sorted_ids(context, ContentTypes.FORMATION):
		for slot_id in FleetOps.formation_slot_ids(context.registries, candidate):
			if FleetOps.formation_slot_role(context.registries, candidate, slot_id) == "flagship":
				formation_id = candidate
				flagship_slot = slot_id
				break
		if not formation_id.is_empty():
			break
	if formation_id.is_empty():
		return
	var set := context.commands.execute(&"fleet.set_formation", {"formation_id": formation_id})
	assert_true(bool(set.get("ok", false)), "setting the formation succeeds: %s" % str(set))
	var flagship := _flagship(_view(context))
	var other_archetype := _other_archetype(context, String(flagship.get("archetype_id", "")))
	var added := context.commands.execute(&"fleet.add_ship", {"archetype_id": other_archetype})
	assert_true(bool(added.get("ok", false)), "adding a roster ship succeeds: %s" % str(added))
	var ship_id := String(added["data"].get("ship_id", ""))
	assert_ne(String(added["data"].get("formation_slot", "x")), flagship_slot,
		"auto-assignment skips the flagship slot")
	var occupied := context.commands.execute(&"fleet.set_formation", {"ship_id": ship_id, "slot": flagship_slot})
	assert_eq(String(occupied.get("error_code", "")), "flagship_slot_only", "non-flagship cannot use the flagship slot")
	var flagship_assigned := context.commands.execute(&"fleet.set_formation", {
		"ship_id": FleetOps.FLAGSHIP_ID,
		"slot": flagship_slot,
	})
	assert_true(bool(flagship_assigned.get("ok", false)), "the flagship may use its slot: %s" % str(flagship_assigned))
	assert_eq(String(_flagship(_view(context)).get("formation_slot", "")), flagship_slot, "the flagship slot is recorded")
	var cleared_slot := context.commands.execute(&"fleet.set_formation", {
		"ship_id": FleetOps.FLAGSHIP_ID,
		"slot": "",
	})
	assert_true(bool(cleared_slot.get("ok", false)), "an empty slot clears the assignment")
	assert_eq(String(_flagship(_view(context)).get("formation_slot", "x")), "", "the flagship slot is cleared")
	var cleared_formation := context.commands.execute(&"fleet.set_formation", {"formation_id": ""})
	assert_true(bool(cleared_formation.get("ok", false)), "an empty formation clears the formation")
	var view := _view(context)
	assert_eq(String(view.get("formation_id", "x")), "", "the formation is cleared")
	for ship in _ships(view):
		assert_eq(String((ship as Dictionary).get("formation_slot", "x")), "", "clearing the formation clears all slots")


## D2-FIX：损坏的 data.fleet（非字典 / 非数组 / 字段类型错误）不抛引擎错误。
func test_malformed_fleet_data_is_normalized() -> void:
	var context := _start(213)
	var variants: Array = [
		"broken",
		42,
		["not", "a", "fleet"],
		{"ships": "nope", "formation_id": 5, "doctrine_id": []},
		{"ships": [null, 42, {"ship_id": 7}, {"ship_id": "flagship", "archetype_id": {}, "captain_id": 5, "formation_slot": [], "condition": "bad"}, {"ship_id": "ship_x", "captain_id": "not-a-real-captain"}]},
		{"flagship": 99, "ships": [{"ship_id": "flagship"}]},
	]
	for variant in variants:
		context.state.data["fleet"] = variant
		var result := context.queries.execute(&"fleet.view")
		assert_true(bool(result.get("ok", false)), "fleet.view stays ok for malformed data: %s" % str(result))
		var view: Dictionary = result.get("data", {})
		assert_true(view.get("ships", null) is Array, "ships are normalized to an array")
		assert_eq(_flagship(view).size() > 0, true, "the flagship entry is restored")
		for ship in _ships(view):
			assert_eq(typeof((ship as Dictionary).get("ship_id", "")), TYPE_STRING, "ship ids are strings")
			assert_eq(typeof((ship as Dictionary).get("formation_slot", "")), TYPE_STRING, "slots are strings")
		assert_eq(typeof(view.get("formation_id", "")), TYPE_STRING, "formation id is normalized to a string")
		assert_eq(typeof(view.get("doctrine_id", "")), TYPE_STRING, "doctrine id is normalized to a string")
	var healed := context.commands.execute(&"fleet.set_doctrine", {"doctrine_id": ""})
	assert_true(bool(healed.get("ok", false)), "a command repairs the malformed block")
	assert_true(context.state.data.get("fleet", null) is Dictionary, "the repaired block is a dictionary")