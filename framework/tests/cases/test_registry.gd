extends TestCase
## Registry unit tests. C2 (items merge): trade goods and crafting materials now
## share the single active `items` definition type.


func _make_definition(id: String, tags: Array) -> ContentDefinition:
	return ContentDefinition.from_raw({
		"id": id,
		"name_key": "test.name",
		"enabled": true,
		"tags": tags,
		"information": {"texture": "icon.test", "model": "model.test"},
		"data": {"crafting_material": false, "unit_weight": 1, "base_price": 10, "base_stock": 10, "price_elasticity": 0.1},
	}, ContentTypes.ITEM, "testmod", "content/items.json")


func test_register_and_query() -> void:
	var hub := RegistryHub.new(ContentTypes.all())
	var definition := _make_definition("testmod:item/one", ["good.trade", "good.bulk"])
	var result := hub.register(definition, "testmod")
	assert_true(bool(result["ok"]), "definition registers")
	assert_true(hub.contains(ContentTypes.ITEM, "testmod:item/one"), "registry contains id")
	assert_eq(hub.get_all(ContentTypes.ITEM).size(), 1, "registry count")
	assert_eq(hub.query(ContentTypes.ITEM, ["good.bulk"]).size(), 1, "tag query finds definition")
	assert_eq(hub.query(ContentTypes.ITEM, ["good.missing"]).size(), 0, "tag query filters")
	assert_eq(String(definition.get_information_value("texture")), "icon.test", "information is parsed")
	assert_eq(definition.asset_uri("texture"), "asset://testmod/icon.test", "bare asset keys use the definition namespace")
	assert_eq(definition.asset_uri("model"), "asset://testmod/model.test", "model keys resolve like textures")
	assert_eq(String(definition.to_raw()["information"]["texture"]), "icon.test", "information survives serialization")


func test_duplicate_id_rejected() -> void:
	var hub := RegistryHub.new(ContentTypes.all())
	var definition := _make_definition("testmod:item/one", [])
	assert_true(bool(hub.register(definition, "testmod")["ok"]), "first registration succeeds")
	var duplicate := hub.register(_make_definition("testmod:item/one", []), "testmod")
	assert_false(bool(duplicate["ok"]), "duplicate id is rejected")
	assert_eq(String(duplicate["error_code"]), "duplicate_id", "duplicate error code")


func test_freeze_blocks_mutation() -> void:
	var hub := RegistryHub.new(ContentTypes.all())
	assert_true(bool(hub.register(_make_definition("testmod:item/one", []), "testmod")["ok"]), "register before freeze")
	hub.freeze_all()
	assert_true(hub.is_frozen(), "hub reports frozen")
	var late := hub.register(_make_definition("testmod:item/two", []), "testmod")
	assert_false(bool(late["ok"]), "registration after freeze is rejected")
	assert_eq(String(late["error_code"]), "registry_frozen", "frozen error code")
