class_name ContractOps
extends RefCounted
## Contract instance generation, loading and delivery settlement.

static func ensure_structure(state: GameState) -> void:
	if state.data.get("contracts", null) is Dictionary:
		var contracts: Dictionary = state.data["contracts"]
		for key in ["active", "offers", "completed", "failed", "next_main_sequence", "counter"]:
			if not contracts.has(key):
				contracts[key] = [] if key in ["active", "offers", "completed", "failed"] else (1 if key == "next_main_sequence" else 0)
		if not contracts.has("main"):
			contracts["main"] = null
		if not contracts.has("main_offer"):
			contracts["main_offer"] = null
		return
	state.data["contracts"] = {
		"main": null,
		"main_offer": null,
		"active": [],
		"offers": [],
		"completed": [],
		"failed": [],
		"next_main_sequence": 1,
		"counter": 0,
	}


static func next_serial(state: GameState) -> int:
	ensure_structure(state)
	var contracts: Dictionary = state.data["contracts"]
	contracts["counter"] = int(contracts.get("counter", 0)) + 1
	return int(contracts["counter"])


static func create_instance(hub: RegistryHub, template: ContentDefinition, origin: String, destination: String, now: float, distance: float, serial: int, rng: RandomNumberGenerator) -> Dictionary:
	var data: Dictionary = template.data
	var cargo_weight := 0.0
	var passengers := 0
	var cargo_entries: Array = []
	var player_sourced := false
	for raw_payload in data.get("payloads", []):
		if not (raw_payload is Dictionary):
			continue
		var payload: Dictionary = raw_payload
		match String(payload.get("kind", "")):
			"cargo":
				var weight_range: Array = payload.get("weight_range", [1, 1])
				var weight := _range_int(rng, weight_range)
				var item_id := String(payload.get("cargo_item_id", ""))
				var item_definition := ShipOps.item_definition(hub, item_id)
				var unit_weight := float(item_definition.data.get("unit_weight", 1.0)) if item_definition != null else 1.0
				var amount := maxi(1, int(ceil(weight / maxf(0.1, unit_weight))))
				cargo_weight += amount * unit_weight
				var entry := {"item_id": item_id, "amount": amount}
				# 4.5.2：`provider: player` = 玩家自备货物，接取时不装船、不占载重，
				# 完成时从船上扣除；`provider: fuel` = 用船上的燃料舱交付（教学首航的
				# 「运煤」），出航前由 VoyageService 校验是否备够。
				match String(payload.get("provider", "")):
					"player":
						entry["player_sourced"] = true
						player_sourced = true
					"fuel":
						entry["fuel_sourced"] = true
						player_sourced = true
					_:
						pass
				cargo_entries.append(entry)
			"passenger":
				var count_range: Array = payload.get("count_range", [1, 1])
				passengers += _range_int(rng, count_range)
	var rewards: Dictionary = data.get("rewards", {})
	var base_money := _range_int(rng, rewards.get("base_money", [0, 0]))
	var on_time_bonus := _range_int(rng, rewards.get("on_time_bonus", [0, 0]))
	var formula_id := String(data.get("deadline_formula", ""))
	var deadline_hours := FormulaRegistry.evaluate(formula_id, {
		"distance": distance,
		"cargo_weight": cargo_weight,
		"passengers": passengers,
	})
	if deadline_hours < 0.0:
		deadline_hours = 24.0
	return {
		"instance_id": "%s@%d" % [template.id, serial],
		"template_id": template.id,
		"name_key": template.name_key,
		"kind": String(data.get("kind", "normal")),
		"sequence": int(data.get("sequence", 0)),
		"origin": origin,
		"destination": destination,
		"distance": distance,
		"deadline": now + deadline_hours,
		"accepted_at": now,
		"cargo_weight": cargo_weight,
		"cargo": cargo_entries,
		"player_sourced": player_sourced,
		"passengers": passengers,
		"base_money": base_money,
		"on_time_bonus": on_time_bonus,
		"reputation": int(rewards.get("reputation", 0)),
		"unlock_ids": Array(rewards.get("unlock_ids", [])),
		"injuries": 0,
		"status": "offer",
	}


static func attach(state: GameState, hub: RegistryHub, instance: Dictionary) -> Dictionary:
	var ship := state.ship()
	var cargo_weight := 0.0
	var supplied_entries: Array = []
	for entry in instance.get("cargo", []):
		# 4.5.2：玩家自备 / 燃料舱交付的货物不在接取时装船，因此也不占接取时的
		# 载重 / 货舱校验。
		if bool(entry.get("player_sourced", false)) or bool(entry.get("fuel_sourced", false)):
			continue
		var definition := ShipOps.item_definition(hub, String(entry.get("item_id", "")))
		if definition == null:
			return Result.fail("unknown_item", "ui.error.unknown_item")
		cargo_weight += float(definition.data.get("unit_weight", 0.0)) * float(entry.get("amount", 0))
		supplied_entries.append(entry)
	var passengers := int(instance.get("passengers", 0))
	if passengers > ShipOps.passenger_capacity(hub, ship):
		return Result.fail("need_cabin", "ui.error.need_cabin", {"required": passengers})
	var added_weight := cargo_weight + float(passengers) * ShipOps.PASSENGER_WEIGHT
	if ShipOps.total_weight(hub, state) + added_weight > ShipOps.max_weight(hub, ship) + 0.0001:
		return Result.fail("weight_limit", "ui.error.weight")
	# 乘客委托（4.5.5）不带货箱，不应因为船上已有的散货 / 货舱已卸下而拒绝接客。
	if cargo_weight > 0.0 \
			and ShipOps.cargo_used(hub, ship) + cargo_weight > ShipOps.cargo_capacity(hub, ship) + 0.0001:
		return Result.fail("cargo_capacity", "ui.error.capacity")
	var instance_id := String(instance.get("instance_id", ""))
	for entry in supplied_entries:
		ShipOps.add_cargo(ship, String(entry.get("item_id", "")), int(entry.get("amount", 0)), instance_id)
	instance["status"] = "active"
	return Result.ok({
		"instance_id": instance_id,
		"cargo_weight": cargo_weight,
		"passengers": passengers,
		"player_sourced": bool(instance.get("player_sourced", false)),
	})


## 4.5.2：自备货物 / 燃料舱交付的缺口（空字典 = 已备齐）。出航前拦截 + 完成时
## 燃料舱扣减都使用同一口径。
static func missing_player_cargo(state: GameState, instance: Dictionary) -> Dictionary:
	var available: Dictionary = {}
	for stack in state.ship().get("cargo", []):
		if not (stack is Dictionary):
			continue
		var item_id := String((stack as Dictionary).get("item_id", ""))
		available[item_id] = int(available.get(item_id, 0)) + int((stack as Dictionary).get("amount", 0))
	for entry in instance.get("cargo", []):
		if not (entry is Dictionary):
			continue
		var item_id := String((entry as Dictionary).get("item_id", ""))
		var required := int((entry as Dictionary).get("amount", 0))
		if bool((entry as Dictionary).get("fuel_sourced", false)):
			var fuel := float(state.ship().get("coal", 0.0))
			if fuel < float(required):
				return {"item_id": item_id, "required": required, "available": int(floor(fuel)), "source": "fuel"}
			continue
		if not bool((entry as Dictionary).get("player_sourced", false)):
			continue
		if int(available.get(item_id, 0)) < required:
			return {
				"item_id": item_id,
				"required": required,
				"available": int(available.get(item_id, 0)),
				"source": "cargo",
			}
	return {}


static func complete(state: GameState, hub: RegistryHub, instance: Dictionary, arrival_time: float) -> Dictionary:
	var on_time := arrival_time <= float(instance.get("deadline", 0.0))
	var compensation := int(instance.get("injuries", 0)) * 50
	var base_money := int(instance.get("base_money", 0))
	var bonus := int(instance.get("on_time_bonus", 0)) if on_time else 0
	var payout := maxi(0, base_money + bonus - compensation)
	var debt_result := DebtService.receive_income(state, payout)
	var player := state.player()
	if on_time:
		player["reputation"] = int(player.get("reputation", 0)) + int(instance.get("reputation", 0))
	player["reputation"] = maxi(0, int(player.get("reputation", 0)) - int(instance.get("injuries", 0)))
	var unlocks: Array = player.get("unlocks", [])
	for unlock_id in instance.get("unlock_ids", []):
		if not unlocks.has(unlock_id):
			unlocks.append(String(unlock_id))
	player["unlocks"] = unlocks
	var ship := state.ship()
	for entry in instance.get("cargo", []):
		if bool((entry as Dictionary).get("fuel_sourced", false)):
			# 4.5.2：燃料舱交付 —— 直接从船上的煤舱扣除（教学首航的运煤委托）。
			ship["coal"] = maxf(0.0, float(ship.get("coal", 0.0)) - float((entry as Dictionary).get("amount", 0)))
			continue
		ShipOps.remove_cargo(
			ship,
			String(entry.get("item_id", "")),
			int(entry.get("amount", 0)),
			true
		)
	instance["status"] = "completed"
	instance["completed_at"] = arrival_time
	state.record_income(payout)
	var template_id := String(instance.get("template_id", ""))
	var completed: Array = state.contracts().get("completed", [])
	if not completed.has(template_id):
		completed.append(template_id)
	return {
		"instance_id": String(instance.get("instance_id", "")),
		"template_id": template_id,
		"on_time": on_time,
		"late": not on_time,
		"base_money": base_money,
		"on_time_bonus": bonus,
		"compensation": compensation,
		"payout": payout,
		"debt": debt_result,
		"reputation": int(player.get("reputation", 0)),
		"unlocks": Array(instance.get("unlock_ids", [])),
		"deadline": float(instance.get("deadline", 0.0)),
		"arrival_time": arrival_time,
	}


static func find_template_by_sequence(hub: RegistryHub, sequence: int) -> ContentDefinition:
	for template in hub.get_all(ContentTypes.CONTRACT):
		if String(template.data.get("kind", "")) == "main" and int(template.data.get("sequence", 0)) == sequence:
			return template
	return null


static func templates_by_kind(hub: RegistryHub, kind: String) -> Array[ContentDefinition]:
	var result: Array[ContentDefinition] = []
	for template in hub.get_all(ContentTypes.CONTRACT):
		if String(template.data.get("kind", "")) == kind:
			result.append(template)
	return result


## Normal (non-main) contracts the player may hold at once: `maxi(1, 1 + reputation / 2)`.
## The main-chain slot is tracked separately and never counts toward this limit.
static func active_limit(state: GameState) -> int:
	return maxi(1, 1 + int(state.player().get("reputation", 0)) / 2)


## Replaces the whole normal-offer pool with up to three fresh instances.
## Main-chain state (`main`, `main_offer`, `next_main_sequence`) is never touched.
## The weighted template pick uses the named contract-generation stream so the
## same seed + key always produces the same pool.
static func generate_normal_offers(state: GameState, hub: RegistryHub, rng_service: RngService, key: String) -> Array:
	ensure_structure(state)
	var templates := templates_by_kind(hub, "normal")
	var offers: Array = []
	if templates.is_empty():
		state.data["contracts"]["offers"] = offers
		return offers
	var candidates: Array = []
	for template in templates:
		candidates.append({"template": template, "weight": 1.0})
	var offer_rng := rng_service.stream(RngService.STREAM_CONTRACT_GENERATION, "normal_offers::%s" % key)
	var wanted := mini(3, templates.size())
	for _index in wanted:
		if candidates.is_empty():
			break
		var picked: Variant = RngService.choose_weighted(offer_rng, candidates)
		if not (picked is Dictionary):
			break
		var template: ContentDefinition = picked["template"]
		candidates.erase(picked)
		var offer := generate_offer(state, hub, template, rng_service, state.current_port_id())
		if not offer.is_empty():
			offers.append(offer)
	state.data["contracts"]["offers"] = offers
	return offers


## Refreshes the normal-offer pool on arrival. The key includes the port, the
## arrival time and the voyage count so every arrival gets its own deterministic
## pool, while repeating the same seed + command sequence reproduces it exactly.
static func refresh_normal_offers(state: GameState, hub: RegistryHub, rng_service: RngService, port_id: String, arrival_time: float) -> Array:
	var voyages := int(state.stats().get("voyages", 0))
	var key := "%s:%.3f:%d" % [port_id, arrival_time, voyages]
	return generate_normal_offers(state, hub, rng_service, key)


static func generate_offer(state: GameState, hub: RegistryHub, template: ContentDefinition, rng_service: RngService, origin: String) -> Dictionary:
	var constraints: Dictionary = template.data.get("constraints", {})
	var minimum_edges := int(constraints.get("min_route_edges", 1))
	var maximum_edges := int(constraints.get("max_route_edges", 1))
	var required_tags: Array = constraints.get("required_port_tags", [])
	var distances := MapOps.bfs_distances(state.world(), origin)
	var candidates: Array[String] = []
	for raw_port_id in distances.keys():
		var port_id := String(raw_port_id)
		if port_id == origin:
			continue
		var edges := int(distances[port_id])
		if edges < minimum_edges or edges > maximum_edges:
			continue
		if not _port_matches_tags(state.world(), port_id, required_tags):
			continue
		candidates.append(port_id)
	candidates.sort()
	if candidates.is_empty():
		return {}
	var rng := rng_service.stream(RngService.STREAM_CONTRACT_GENERATION, "%s::%s" % [template.id, origin])
	var destination: String = candidates[rng.randi_range(0, candidates.size() - 1)]
	var distance := MapOps.distance_between(state.world(), origin, destination)
	if distance <= 0.0:
		distance = float(MapOps.bfs_distances(state.world(), origin).get(destination, 1)) * 100.0
	var serial := next_serial(state)
	return create_instance(hub, template, origin, destination, state.now(), distance, serial, rng)


static func accept_offer(state: GameState, hub: RegistryHub, instance_id: String) -> Dictionary:
	ensure_structure(state)
	var contracts: Dictionary = state.data["contracts"]
	var main_offer: Variant = contracts.get("main_offer", null)
	if main_offer is Dictionary and String(main_offer.get("instance_id", "")) == instance_id:
		var attach_result := attach(state, hub, main_offer)
		if not bool(attach_result["ok"]):
			return attach_result
		contracts["main"] = main_offer
		contracts["main_offer"] = null
		return Result.ok({"contract": main_offer, "slot": "main"})
	for index in range(contracts.get("offers", []).size()):
		var offer: Dictionary = contracts["offers"][index]
		if String(offer.get("instance_id", "")) != instance_id:
			continue
		var limit := active_limit(state)
		if contracts.get("active", []).size() >= limit:
			return Result.fail("too_many_contracts", "ui.error.too_many_contracts", {"limit": limit})
		var attach_result := attach(state, hub, offer)
		if not bool(attach_result["ok"]):
			return attach_result
		contracts["offers"].remove_at(index)
		contracts["active"].append(offer)
		return Result.ok({"contract": offer, "slot": "active"})
	return Result.fail("contract_not_found", "ui.error.contract_not_found", {"instance_id": instance_id})


static func accepts_passengers(template: ContentDefinition) -> bool:
	for payload in template.data.get("payloads", []):
		if payload is Dictionary and String(payload.get("kind", "")) == "passenger":
			return true
	return false


static func _range_int(rng: RandomNumberGenerator, range_value: Variant) -> int:
	if not (range_value is Array) or range_value.is_empty():
		return 0
	var values: Array = range_value
	var minimum := int(values[0])
	var maximum := int(values[1]) if values.size() > 1 else minimum
	return rng.randi_range(mini(minimum, maximum), maxi(minimum, maximum))


static func _port_matches_tags(world: Dictionary, port_id: String, required_tags: Array) -> bool:
	if required_tags.is_empty():
		return true
	var port_data := MapOps.port(world, port_id)
	var port_tags: Array = port_data.get("tags", [])
	for tag in required_tags:
		if not port_tags.has(String(tag)):
			return false
	return true
