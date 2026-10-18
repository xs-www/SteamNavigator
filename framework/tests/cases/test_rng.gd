extends TestCase


func _draw(seed_value: int, stream_name: StringName, context_key: String, count: int) -> Array:
	var service := RngService.new(seed_value)
	var generator := service.stream(stream_name, context_key)
	var values: Array = []
	for _index in count:
		values.append(generator.randi())
	return values


func test_same_seed_same_stream() -> void:
	assert_eq(_draw(1234, &"market", "port_0", 8), _draw(1234, &"market", "port_0", 8), "same seed reproduces the stream")


func test_streams_are_isolated() -> void:
	var a := _draw(1234, &"market", "", 8)
	var b := _draw(1234, &"voyage_risk", "", 8)
	assert_ne(a, b, "different stream names produce different sequences")
	var service_a := RngService.new(99)
	var a_values: Array = []
	var generator_a := service_a.stream(&"market", "p0")
	for _index in 6:
		a_values.append(generator_a.randi())
	var service_b := RngService.new(99)
	service_b.stream(&"voyage_risk", "p0").randi()
	var generator_b := service_b.stream(&"market", "p0")
	var b_values: Array = []
	for _index in 6:
		b_values.append(generator_b.randi())
	assert_eq(a_values, b_values, "consuming another stream does not perturb this stream")


func test_context_key_changes_stream() -> void:
	assert_ne(_draw(5, &"npc_trade", "npc_1", 4), _draw(5, &"npc_trade", "npc_2", 4), "context key changes the stream")


func test_stable_hash() -> void:
	assert_eq(StableHash.fnv1a_32("steam"), StableHash.fnv1a_32("steam"), "hash is deterministic")
	assert_ne(StableHash.fnv1a_32("steam"), StableHash.fnv1a_32("navigator"), "hash distinguishes text")
	assert_eq(
		StableHash.seed_from(42, &"market", "p0"),
		StableHash.seed_from(42, &"market", "p0"),
		"seed derivation is deterministic"
	)
	assert_ne(
		StableHash.seed_from(42, &"market", "p0"),
		StableHash.seed_from(43, &"market", "p0"),
		"base seed changes derived seed"
	)
