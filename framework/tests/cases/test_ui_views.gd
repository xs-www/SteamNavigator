extends TestCase


func _candidate(rows: Array, module_id: String) -> Dictionary:
	for row in rows:
		if row is Dictionary and String(row.get("module_id", "")) == module_id:
			return row
	return {}


func test_shipyard_view_reports_slots_and_blockers() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": 8181})
	var result := context.queries.execute(&"shipyard.view")
	assert_true(bool(result["ok"]), "shipyard view succeeds")
	var data: Dictionary = result["data"]
	assert_true(bool(data["has_shipyard"]), "starting hub has a shipyard")
	var candidates: Array = data["candidates"]
	assert_true(candidates.size() >= 10, "all module types are listed")
	var installed_hull := _candidate(candidates, "core:hull/small_efficient")
	assert_true(bool(installed_hull["installed"]), "current hull is marked installed")
	assert_false(bool(installed_hull["can_install"]), "installed hull cannot be installed again")
	var medium_hull := _candidate(candidates, "core:hull/medium_standard")
	assert_false(bool(medium_hull["can_install"]), "medium hull is blocked by money at start")
	assert_contains(medium_hull["blockers"], "insufficient_money", "money blocker is exposed")
	context.state.set_money(5000)
	var rich_result := context.queries.execute(&"shipyard.view")
	var rich: Dictionary = rich_result["data"]
	var affordable := _candidate(rich["candidates"], "core:hull/medium_standard")
	assert_true(bool(affordable["can_install"]), "medium hull becomes installable with enough money")


func test_intel_view_exposes_snapshot_rows() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": 8282})
	var empty := context.queries.execute(&"intel.view")
	assert_true(bool(empty["ok"]), "intel view succeeds")
	assert_false(bool(empty["data"]["has_report"]), "no report before refreshing")
	var intel_port := ""
	for port_id in context.state.world().get("ports", {}).keys():
		var port: Dictionary = context.state.world()["ports"][port_id]
		if Array(port.get("facilities", [])).has("intel"):
			intel_port = String(port_id)
			break
	assert_true(not intel_port.is_empty(), "map contains an intel port")
	context.state.world()["current_port_id"] = intel_port
	var discovered: Array = context.state.world().get("discovered_ports", [])
	if not discovered.has(intel_port):
		discovered.append(intel_port)
	context.state.world()["discovered_ports"] = discovered
	var refresh := context.commands.execute(&"intel.refresh", {})
	assert_true(bool(refresh["ok"]), "intel refresh succeeds: %s" % str(refresh))
	var report := context.queries.execute(&"intel.view")
	var data: Dictionary = report["data"]
	assert_true(bool(data["has_report"]), "report exists after refresh")
	assert_true(int(data["port_count"]) >= 1, "report contains the discovered port")
	assert_true(not String(data["generated_label"]).is_empty(), "report has a timestamp")
	assert_true(data["ports"].size() >= 1, "port rows are exposed")
