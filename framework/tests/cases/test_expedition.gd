extends TestCase
## @static-doc
## 作用：Phase D5 遗迹远征运行时测试：开始/进入/事件选择/撤退/完成奖励、危险结算、
## 遗物收藏、存档往返、损坏数据规范化与确定性。
##
## ## 契约与约束
## - 内容从 Core 的 ruin_archetypes / room_templates / expedition_events /
##   hazard_tables / relics 动态选取，不写死房间/遗物 id。
## - 全程用公开命令推进；事件选项按 0 处理，循环直到远征结束。
## - 完成奖励断言钱/物品/遗物至少有一项落地，且遗物进入 `data.relics`。
## @end-static-doc

const STEADY := "core:starting_scenario/steady"


func _start(seed_value: int) -> AppContext:
	var context: AppContext = bootstrap_core()["context"]
	var started := context.commands.execute(&"run.start", {"starting_scenario": STEADY, "seed": seed_value})
	assert_true(bool(started.get("ok", false)), "run.start succeeds: %s" % str(started))
	return context


func _ruin_id(context: AppContext) -> String:
	var ruins := context.registries.get_all(ContentTypes.RUIN_ARCHETYPE)
	assert_false(ruins.is_empty(), "core ships ruin archetypes")
	return ruins[0].id if not ruins.is_empty() else ""


func _view(context: AppContext) -> Dictionary:
	var result := context.queries.execute(&"expedition.view")
	assert_true(bool(result.get("ok", false)), "expedition.view answers")
	return result.get("data", {})


func _run_to_end(context: AppContext) -> Dictionary:
	for _step in 30:
		var view := _view(context)
		if not bool(view.get("active", false)):
			return view
		if String(view.get("phase", "")) == "event":
			var chosen := context.commands.execute(&"expedition.choose", {"option_index": 0})
			assert_true(bool(chosen.get("ok", false)), "choosing an event option succeeds: %s" % str(chosen))
		else:
			var entered := context.commands.execute(&"expedition.enter", {})
			assert_true(bool(entered.get("ok", false)), "entering a room succeeds: %s" % str(entered))
	return _view(context)


func test_commands_and_query_are_registered() -> void:
	var context := _start(601)
	for command in [&"expedition.start", &"expedition.enter", &"expedition.choose", &"expedition.retreat"]:
		assert_true(context.commands.has(command), "%s is registered" % String(command))
	assert_true(context.queries.has(&"expedition.view"), "expedition.view is registered")


func test_start_validates_ruin_and_is_unique() -> void:
	var context := _start(602)
	var unknown := context.commands.execute(&"expedition.start", {"ruin_id": "test:ruin_archetype/absent"})
	assert_eq(String(unknown.get("error_code", "")), "unknown_ruin", "unknown ruins are rejected")
	var started := context.commands.execute(&"expedition.start", {"ruin_id": _ruin_id(context)})
	assert_true(bool(started.get("ok", false)), "starting an expedition succeeds: %s" % str(started))
	var view := _view(context)
	assert_true(bool(view.get("active", false)), "the view reports the active expedition")
	assert_true(int(view.get("room_count", 0)) >= 2, "the expedition generates rooms")
	var again := context.commands.execute(&"expedition.start", {"ruin_id": _ruin_id(context)})
	assert_eq(String(again.get("error_code", "")), "expedition_running", "only one expedition can run")


func test_full_expedition_completes_and_grants_a_relic() -> void:
	var context := _start(603)
	assert_true(bool(context.commands.execute(&"expedition.start", {"ruin_id": _ruin_id(context)}).get("ok", false)), "start succeeds")
	var view := _run_to_end(context)
	assert_false(bool(view.get("active", true)), "the expedition finishes")
	assert_eq(String(view.get("phase", "")), "finished", "the phase is finished")
	assert_contains(view.get("log", []).map(func(entry): return String(entry.get("event", ""))), "completed",
		"the completion is logged")
	var relics: Array = view.get("relics", [])
	assert_false(relics.is_empty(), "a relic enters the permanent collection")
	assert_true(context.state.data.get("relics", []) is Array, "data.relics is persisted")


func test_hazards_are_resolved_on_entering_rooms() -> void:
	var context := _start(604)
	var ruin := context.registries.get_by_id(ContentTypes.RUIN_ARCHETYPE, _ruin_id(context))
	var hazard_id := String(ruin.data.get("hazard_table", ""))
	var hazard := context.registries.get_by_id(ContentTypes.HAZARD_TABLE, hazard_id)
	assert_true(hazard != null, "the ruin references a hazard table")
	assert_true(bool(context.commands.execute(&"expedition.start", {"ruin_id": ruin.id}).get("ok", false)), "start succeeds")
	var money_before := context.state.money()
	var durability_before := float(context.state.ship().get("durability", 0.0))
	var entered := context.commands.execute(&"expedition.enter", {})
	assert_true(bool(entered.get("ok", false)), "entering the first room succeeds")
	var after := _view(context)
	var hazard_logs: Array = after.get("log", []).filter(func(entry): return String(entry.get("event", "")) == "hazard")
	assert_false(hazard_logs.is_empty(), "entering a room rolls the hazard table")
	assert_true(context.state.money() <= money_before and float(context.state.ship().get("durability", 0.0)) <= durability_before,
		"hazards never heal the player")


func test_retreat_ends_the_run_without_completion_reward() -> void:
	var context := _start(605)
	assert_true(bool(context.commands.execute(&"expedition.start", {"ruin_id": _ruin_id(context)}).get("ok", false)), "start succeeds")
	var relics_before := Array(context.state.data.get("relics", [])).size()
	var retreated := context.commands.execute(&"expedition.retreat", {})
	assert_true(bool(retreated.get("ok", false)), "retreat succeeds")
	var view := _view(context)
	assert_false(bool(view.get("active", true)), "the expedition is no longer active")
	assert_eq(Array(context.state.data.get("relics", [])).size(), relics_before, "retreat does not grant a relic")


func test_save_round_trip_mid_expedition() -> void:
	var context := _start(606)
	assert_true(bool(context.commands.execute(&"expedition.start", {"ruin_id": _ruin_id(context)}).get("ok", false)), "start succeeds")
	context.commands.execute(&"expedition.enter", {})
	var before := _view(context)
	assert_true(bool(context.save.save_slot("ruin_manual", context.state, context.save_meta()).get("ok", false)), "saving succeeds")
	var loaded := context.save.load_slot("ruin_manual")
	assert_true(bool(loaded.get("ok", false)), "loading succeeds")
	var loaded_context: AppContext = bootstrap_core()["context"]
	loaded_context.set_state(loaded["state"])
	var after := _view(loaded_context)
	assert_eq(String(after.get("ruin_id", "")), String(before.get("ruin_id", "")), "the ruin survives")
	assert_eq(int(after.get("room_index", -1)), int(before.get("room_index", -2)), "the room index survives")
	assert_eq(int(after.get("room_count", 0)), int(before.get("room_count", 0)), "the room sequence survives")


func test_malformed_expedition_data_is_normalized() -> void:
	var context := _start(607)
	for variant in ["broken", 42, ["no"], {"active": true, "room_index": null, "rooms": "bad", "log": "bad", "phase": "warp"}]:
		context.state.data["expedition"] = variant
		var result := context.queries.execute(&"expedition.view")
		assert_true(bool(result.get("ok", false)), "expedition.view tolerates malformed data")
		var view: Dictionary = result.get("data", {})
		assert_eq(typeof(view.get("phase", "")), TYPE_STRING, "the phase is normalized")
		assert_true(view.get("rooms", null) is Array, "rooms normalize to an array")


func test_malformed_relics_completion_is_safe() -> void:
	var context := _start(609)
	context.state.data["relics"] = "broken"
	assert_true(bool(context.commands.execute(&"expedition.start", {"ruin_id": _ruin_id(context)}).get("ok", false)), "start succeeds")
	var view := _run_to_end(context)
	assert_false(bool(view.get("active", true)), "completion succeeds with a corrupt relic list")
	assert_true(context.state.data.get("relics", null) is Array, "the relic list is repaired to an array")
	assert_false(Array(context.state.data.get("relics", [])).is_empty(), "the reward relic lands in the collection")


func test_same_seed_and_commands_are_deterministic() -> void:
	var first := _start(608)
	var second := _start(608)
	for context in [first, second]:
		context.commands.execute(&"expedition.start", {"ruin_id": _ruin_id(context)})
		context.commands.execute(&"expedition.enter", {})
		context.commands.execute(&"expedition.retreat", {})
	if first.state == null or second.state == null:
		return
	assert_eq(first.state.data.get("expedition", null), second.state.data.get("expedition", null),
		"same seed + same expedition commands reproduce the same run")
