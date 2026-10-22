extends TestCase
## @static-doc
## 作用：Phase C C2（goods + materials → `items` 2.0）的运行时合并回归：类型表 /
## Schema 版本、Core 12 条 item 定义、市场条目覆盖（含前 materials 的买/卖语义）、
## crafting_material 判定、港口 / 船厂 / 打造 ViewModel 的 category 分类字段，以及
## 货物线索只命中普通贸易货物（`good.trade`）而不是材料。
##
## - 关键依赖：`bootstrap_core()`、`ContentTypes.ITEM`、`ShipOps.item_definition` /
##   `is_crafting_material`、`MarketOps.initialize_port_market`、`PortViewQuery`、
##   `ShipyardViewQuery`、`CraftOps.material_plan`、`ClueService.goods_candidates`
##
## ## 契约与约束
## - 不引用已删除的 `ContentTypes.GOOD` / `ContentTypes.MATERIAL`；材料判定只用
##   `data.crafting_material`（旧 goods 里可打造的三条也为 true），不再有内容类型分割。
## - 市场语义保持：所有 item 都有卖入口；港口 assortments 里的可买；煤/水走补给条目。
## - UI 分类只读 `category` / `crafting_material` / `tier` 字段，不做类型分支。
## @end-static-doc

const MANIFEST_PATH := "res://content_types.json"


func _manifest_types() -> Dictionary:
	var parsed := JsonUtils.parse_file(MANIFEST_PATH)
	if not bool(parsed.get("ok", false)):
		fail("content_types.json cannot be parsed: %s" % String(parsed.get("error", "")))
		return {}
	var by_key := {}
	for entry in (parsed["value"] as Dictionary).get("types", []):
		if entry is Dictionary:
			by_key[String(entry.get("key", ""))] = entry
	return by_key


func test_items_is_the_single_active_2_0_type() -> void:
	var types := _manifest_types()
	if types.is_empty():
		return
	assert_true(types.has("items"), "items is an active content type")
	var entry: Dictionary = types["items"]
	assert_eq(String(entry.get("schema_version", "")), "2.0", "items is a Schema 2.0 type")
	assert_eq(String(entry.get("capability", "")), "content.items.v1", "items capability")
	assert_eq(String(entry.get("schema", "")), "schemas/v2/item.schema.json", "items schema path")
	for retired in ["goods", "materials"]:
		assert_false(types.has(retired), "%s legacy type is retired" % retired)
		assert_false(ContentTypes.all().has(StringName(retired)), "%s is not a runtime content type" % retired)
	assert_eq(ContentTypes.schema_version(ContentTypes.ITEM), "2.0", "runtime ITEM version")
	assert_eq(ContentTypes.singular(ContentTypes.ITEM), "item", "runtime ITEM singular")


func test_core_items_resolve_materials_by_flag() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var hub: RegistryHub = context.registries
	assert_eq(hub.get_all(ContentTypes.ITEM).size(), 12, "core ships 12 merged item definitions")
	var iron_ore := ShipOps.item_definition(hub, "core:item/iron_ore")
	assert_not_null(iron_ore, "former trade good resolves through the items registry")
	assert_true(bool(iron_ore.data.get("crafting_material", false)), "iron ore is a crafting material")
	assert_true(ShipOps.is_crafting_material(hub, "core:item/iron_ore"), "ShipOps reports iron ore as a material")
	var plate := ShipOps.item_definition(hub, "core:item/boiler_plate")
	assert_not_null(plate, "former material resolves through the items registry")
	assert_true(ShipOps.is_crafting_material(hub, "core:item/boiler_plate"), "boiler plate is a crafting material")
	assert_eq(int(plate.data.get("tier", 0)), 2, "former material keeps its tier")
	var textiles := ShipOps.item_definition(hub, "core:item/textiles")
	assert_not_null(textiles, "ordinary trade item resolves")
	assert_false(ShipOps.is_crafting_material(hub, "core:item/textiles"), "textiles are not a crafting material")
	assert_true(ShipOps.item_definition(hub, "core:item/absent") == null, "unknown items still resolve to null")


func test_market_covers_every_item_kind() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var hub: RegistryHub = context.registries
	var archetype := hub.get_by_id(ContentTypes.PORT_ARCHETYPE, "core:port_archetype/iron_harbor")
	assert_not_null(archetype, "core port archetype resolves")
	var rng := RngService.new(7).make_stream(RngService.STREAM_GOODS_GENERATION, "port_0")
	var market := MarketOps.initialize_port_market(hub, archetype, rng)
	for definition in hub.get_all(ContentTypes.ITEM):
		if definition.has_tag("good.contract"):
			assert_false(market.has(definition.id), "contract cargo stays out of the market: %s" % definition.id)
			continue
		assert_true(market.has(definition.id), "market creates an entry for every item: %s" % definition.id)
	# Former materials appear in the port assortment now (C2): they are buyable like goods.
	assert_true(bool((market["core:item/sealing_compound"] as Dictionary).get("buyable", false)),
		"listed former material is buyable")
	assert_true(int((market["core:item/sealing_compound"] as Dictionary).get("stock", 0)) > 0,
		"listed former material has stock")
	# Supply items keep the dedicated supply entry instead of a trade row.
	var coal: Dictionary = market["core:item/coal"]
	assert_true(bool(coal.get("is_supply", false)), "coal is a supply entry")
	assert_eq(String(coal.get("supply_kind", "")), "coal", "coal keeps its supply kind")
	# Contract freight is never a trade entry.
	assert_false(market.has("core:item/contract_freight"), "contract freight has no market entry")


func test_item_views_expose_category_fields() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var started := context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": 6161})
	assert_true(bool(started.get("ok", false)), "run starts: %s" % str(started))
	var port := context.queries.execute(&"port.view")
	assert_true(bool(port.get("ok", false)), "port.view answers: %s" % str(port))
	var iron_row := {}
	for row in (port["data"] as Dictionary).get("market", []):
		if row is Dictionary and String(row.get("item_id", "")) == "core:item/iron_ore":
			iron_row = row
			break
	assert_false(iron_row.is_empty(), "the market lists iron ore")
	assert_eq(String(iron_row.get("category", "")), "ore", "market rows expose the content category")
	assert_true(bool(iron_row.get("crafting_material", false)), "market rows expose the crafting-material flag")
	var textile_row := {}
	for row in (port["data"] as Dictionary).get("market", []):
		if row is Dictionary and String(row.get("item_id", "")) == "core:item/textiles":
			textile_row = row
			break
	assert_false(textile_row.is_empty(), "the market lists textiles")
	assert_false(bool(textile_row.get("crafting_material", true)), "pure trade items are not marked as materials")
	# Warehouse contents reuse the same fields in the shipyard ViewModel.
	var port_id := context.state.current_port_id()
	WarehouseOps.add_material(context.state, port_id, "core:item/brass", 2)
	var yard := context.queries.execute(&"shipyard.view")
	assert_true(bool(yard.get("ok", false)), "shipyard.view answers: %s" % str(yard))
	var warehouse: Dictionary = (yard["data"] as Dictionary).get("warehouse", {})
	var brass_row := {}
	for row in warehouse.get("materials", []):
		if row is Dictionary and String(row.get("item_id", "")) == "core:item/brass":
			brass_row = row
			break
	assert_false(brass_row.is_empty(), "the shipyard lists warehouse items")
	assert_eq(String(brass_row.get("category", "")), "metal", "warehouse rows expose the category")
	assert_true(bool(brass_row.get("crafting_material", false)), "warehouse rows expose the crafting-material flag")
	# Craft recipes resolve their inputs as items and expose the material tier.
	var plan := CraftOps.material_plan(context.state, context.registries, port_id, "core:module/performance")
	assert_false(plan.is_empty(), "the standard boiler recipe consumes items")
	if not plan.is_empty():
		var first: Dictionary = plan[0]
		assert_true(String(first.get("item_id", "")).begins_with("core:item/"), "recipe inputs are item ids")
		assert_false(String(first.get("category", "")).is_empty(), "recipe rows expose the item category")
		assert_true(first.has("tier"), "recipe rows expose the item tier")


func test_goods_clues_skip_crafting_only_materials() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var started := context.commands.execute(&"run.start", {"build_id": "core:starting_build/steady", "seed": 7171})
	assert_true(bool(started.get("ok", false)), "run starts: %s" % str(started))
	var world := WorldOps.world_map(context.state)
	var current := context.state.current_port_id()
	for port in world.ports:
		if port.id == current:
			continue
		WorldOps.discover_port_id(context.state, port.id)
		MapOps.discover(context.state, port.id)
		break
	var candidates := ClueService.goods_candidates(context)
	assert_false(candidates.is_empty(), "a second discovered harbour yields goods-clue candidates")
	for candidate in candidates:
		var item_id := String((candidate as Dictionary).get("good_id", ""))
		var definition := ShipOps.item_definition(context.registries, item_id)
		assert_not_null(definition, "goods clue candidate is a registered item: %s" % item_id)
		if definition != null:
			assert_true(definition.has_tag("good.trade"), "goods clue candidate is ordinary trade: %s" % item_id)
			assert_ne(item_id, "core:item/boiler_plate", "crafting-only materials never become goods clues")
			assert_ne(item_id, "core:item/precision_gear", "crafting-only materials never become goods clues")
			assert_ne(item_id, "core:item/sealing_compound", "crafting-only materials never become goods clues")
