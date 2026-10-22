extends TestCase


func test_many_seeds_meet_map_constraints() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var failures: Array[String] = []
	for seed_value in range(1, 31):
		var generated := CampaignFactory.create_default_campaign(context, "core:starting_scenario/steady", seed_value)
		if not bool(generated["ok"]):
			failures.append("seed %d: run generation failed (%s)" % [seed_value, generated.get("error_code", "")])
			continue
		var state: GameState = generated["data"]["state"]
		var world := state.world()
		var port_count := MapOps.ports(world).size()
		if port_count < 4 or port_count > 5:
			failures.append("seed %d: port count %d" % [seed_value, port_count])
		if MapOps.routes(world).size() < port_count:
			failures.append("seed %d: no branch cycle" % seed_value)
		if not MapOps.reachable(world, "port_0"):
			failures.append("seed %d: ports unreachable" % seed_value)
		var distances := MapOps.bfs_distances(world, "port_0")
		var has_shipyard := false
		var has_intel := false
		for port_id in distances.keys():
			if int(distances[port_id]) > 2:
				continue
			var port_tags: Array = MapOps.port(world, String(port_id)).get("tags", [])
			if port_tags.has("port.shipyard"):
				has_shipyard = true
			if port_tags.has("port.intel"):
				has_intel = true
		if not has_shipyard:
			failures.append("seed %d: shipyard not within 2 edges" % seed_value)
		if not has_intel:
			failures.append("seed %d: intel station not within 2 edges" % seed_value)
		var main_contract: Variant = state.contracts().get("main", null)
		if not (main_contract is Dictionary):
			failures.append("seed %d: no main contract" % seed_value)
			continue
		var destination := String(main_contract.get("destination", ""))
		if MapOps.distance_between(world, "port_0", destination) <= 0.0:
			failures.append("seed %d: main destination is not adjacent" % seed_value)
		var saved := context.state
		context.state = state
		var preview := VoyageCalculator.preview(context, destination, "core:strategy/economic")
		context.state = saved
		if not bool(preview["ok"]) or not bool(preview["data"].get("feasible", false)):
			failures.append("seed %d: first voyage infeasible" % seed_value)
	assert_true(failures.is_empty(), "map constraints: %s" % "; ".join(failures))
