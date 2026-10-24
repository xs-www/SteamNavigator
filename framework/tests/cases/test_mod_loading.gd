extends TestCase
## Core content load checks. C2 (items merge): the old `goods` + `materials`
## definitions now live in one active Schema 2.0 `items` registry.
##
## Item icons are guarded here as well: every `items` definition that declares
## `information.texture` must resolve to a real `Texture2D` through
## `AssetService` (imported `.ctex` or raw SVG via `ContentAssetLoader`), and the
## framework-wide `assets/ui/icons/item_fallback.svg` placeholder must load.

const ITEM_ICON_LOCAL_IDS := [
	"iron_ore",
	"brass",
	"textiles",
	"spices",
	"timber",
	"glassware",
	"contract_freight",
	"boiler_plate",
	"precision_gear",
	"sealing_compound",
]

## Scratch dir for the raw-SVG load assertion (see the icon asset test).
const RAW_ICON_COPY_DIR := "user://item_icon_raw_check"


func test_core_loads_cleanly() -> void:
	var boot := bootstrap_core()
	var report: StartupReport = boot["report"]
	assert_true(not report.has_fatal(), "core bootstrap has no fatal error: %s" % report.format_text())
	assert_eq(report.status_name(), "ok", "core-only bootstrap is OK")
	assert_true(report.registry_frozen, "registry is frozen after load")
	assert_true(report.disabled_mods.is_empty(), "no mod is disabled")
	assert_eq(report.mods.size(), 1, "one mod loaded")
	assert_eq(String(report.mods[0]["id"]), "core", "loaded mod is core")
	assert_true(report.content_total() >= 45, "core provides a substantial content set")
	assert_eq(int(report.content_counts.get("items", 0)), 12, "items merge goods and materials (incl. coal and water)")
	assert_eq(int(report.content_counts.get("hulls", 0)), 4, "hull count")
	assert_eq(int(report.content_counts.get("contracts", 0)), 9, "contract count")


func test_registry_accessible_after_freeze() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	assert_not_null(context.registries.get_by_id(ContentTypes.ITEM, "core:item/iron_ore"), "iron ore is registered")
	assert_not_null(context.registries.get_by_id(ContentTypes.HULL, "core:hull/medium_standard"), "medium hull is registered")
	assert_not_null(context.registries.get_by_id(ContentTypes.CONTRACT, "core:contract/main_05"), "finale contract is registered")
	assert_true(context.commands.has(&"run.start"), "run.start command is registered")
	assert_true(context.queries.has(&"port.view"), "port.view query is registered")
	assert_true(context.localization.has_key("item.core.iron_ore.name"), "localization loaded")
	var manifest_parsed := JsonUtils.parse_file("res://dev_mods/core/manifest.json")
	assert_true(bool(manifest_parsed.get("ok", false)), "core manifest parses")
	if bool(manifest_parsed.get("ok", false)):
		var declared_assets: Dictionary = manifest_parsed["value"].get("assets", {})
		assert_eq(
			context.assets.count(),
			declared_assets.size(),
			"every Core manifest asset is registered (image, model and shared-texture keys)"
		)
	var coal := context.registries.get_by_id(ContentTypes.ITEM, "core:item/coal")
	assert_eq(String(coal.information.get("texture", "")), "icon.coal", "Core items expose parsed texture information")
	assert_eq(coal.asset_uri("model"), "asset://core/model.good.coal", "Core items expose namespaced model URIs")
	assert_true(context.assets.has(coal.asset_uri("texture")), "Core texture URI resolves")
	assert_true(context.assets.has(coal.asset_uri("model")), "Core model URI resolves")
	var hull := context.registries.get_by_id(ContentTypes.HULL, "core:hull/large_efficient")
	assert_eq(hull.asset_uri("model"), "asset://core/model.ship.paddle_freighter", "Core hull model is parsed")
	assert_true(context.assets.has(hull.asset_uri("model")), "Core hull model URI resolves")


func test_starting_scenarios_are_runnable() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	for build in RunFactory.available_scenarios(context.registries):
		var ship := RunFactory.create_ship(context.registries, build)
		var validation := ShipOps.validate_configuration(context.registries, ship)
		assert_true(bool(validation["ok"]), "starting build %s is valid: %s" % [build.id, validation["errors"]])
		assert_true(ShipOps.max_weight(context.registries, ship) > 0.0, "starting build %s has a weight limit" % build.id)


func test_third_party_mod_uses_public_api() -> void:
	var boot := bootstrap_core({
		"scan_roots": PackedStringArray(["res://dev_mods", "res://sdk/examples"]),
	})
	var report: StartupReport = boot["report"]
	assert_true(not report.has_fatal(), "third-party load has no fatal error: %s" % report.format_text())
	assert_eq(report.status_name(), "ok", "core + example mod loads cleanly")
	assert_true(report.mods.size() >= 2, "example mod is loaded")
	var context: AppContext = boot["context"]
	var boiler := context.registries.get_by_id(ContentTypes.MODULE, "example_boilers:module/compound_efficient")
	assert_not_null(boiler, "example boiler is registered through the normal registry")
	assert_eq(context.localization.tr_key(boiler.name_key), "复合式高效锅炉", "example localization is loaded")


## Icons are content data, not framework UI: every item that exposes
## `information.texture` must resolve through `AssetService` (asset:// URI ->
## imported resource or raw mod file). Coal / water keep their existing PNGs.
func test_item_texture_icons_load() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var items := context.registries.get_all(ContentTypes.ITEM)
	assert_eq(items.size(), 12, "core registers 12 items")
	var textured := 0
	var item_icon_keys := {}
	for definition in items:
		var texture_key := String(definition.information.get("texture", "")).strip_edges()
		if texture_key.is_empty():
			continue
		textured += 1
		if texture_key.begins_with("icon.item."):
			item_icon_keys[texture_key] = true
		var logical_key := definition.asset_uri("texture")
		assert_true(context.assets.has(logical_key), "item %s texture asset is mounted (%s)" % [definition.id, logical_key])
		var texture: Texture2D = context.assets.load_texture(logical_key)
		assert_not_null(texture, "item %s texture loads as Texture2D" % definition.id)
		_assert_icon_texture(texture, "item %s texture" % definition.id)
		var model_key := String(definition.information.get("model", "")).strip_edges()
		if not model_key.is_empty():
			assert_true(context.assets.has(definition.asset_uri("model")), "item %s keeps its model asset" % definition.id)
	assert_eq(textured, 12, "every core item declares information.texture")
	assert_eq(item_icon_keys.size(), ITEM_ICON_LOCAL_IDS.size(), "ten items use an icon.item.* placeholder")
	for local_id in ITEM_ICON_LOCAL_IDS:
		assert_true(item_icon_keys.has("icon.item.%s" % local_id), "icon.item.%s is used by an item definition" % local_id)


## Manifest keys, loose Core files and the real load chain for the 10 SVG icons.
## `AssetService.load_texture()` covers whichever branch the environment provides
## (imported `.ctex` or raw mod file); `.snavmod` packs ship the SVGs raw, so the
## `ContentAssetLoader` rasterization path is asserted separately.
func test_item_icon_assets_are_declared_and_loadable() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	DirAccess.make_dir_recursive_absolute(RAW_ICON_COPY_DIR)
	var manifest_parsed := JsonUtils.parse_file("res://dev_mods/core/manifest.json")
	assert_true(bool(manifest_parsed.get("ok", false)), "core manifest parses")
	var declared_assets: Dictionary = {}
	if bool(manifest_parsed.get("ok", false)):
		declared_assets = manifest_parsed["value"].get("assets", {})
	for local_id in ITEM_ICON_LOCAL_IDS:
		var asset_key := "icon.item.%s" % local_id
		var relative_path := "assets/icons/items/%s.svg" % local_id
		assert_eq(String(declared_assets.get(asset_key, "")), relative_path, "%s is declared in manifest.assets" % asset_key)
		var source_path := "res://dev_mods/core/%s" % relative_path
		assert_true(FileAccess.file_exists(source_path), "%s source file exists" % source_path)
		assert_eq(
			context.assets.find_key(asset_key),
			"asset://core/%s" % asset_key,
			"find_key resolves the bare key %s" % asset_key
		)
		var texture: Texture2D = context.assets.load_texture("asset://core/%s" % asset_key)
		assert_not_null(texture, "%s loads through AssetService" % asset_key)
		_assert_icon_texture(texture, asset_key)
		# Reading an imported res:// image through `Image.load_from_file()` is the
		# tools-only path Godot warns about, and it is not how mounted mod packs are
		# read, so rasterize a user:// copy of the same bytes instead.
		var raw_copy_path := "%s/%s.svg" % [RAW_ICON_COPY_DIR, local_id]
		var copy_written := _write_bytes(raw_copy_path, FileAccess.get_file_as_bytes(source_path))
		assert_true(copy_written, "raw svg copy for %s is writable" % asset_key)
		if copy_written:
			ContentAssetLoader.clear_cache()
			var raw_texture := ContentAssetLoader.load_texture(raw_copy_path)
			assert_not_null(raw_texture, "%s loads as a raw SVG through ContentAssetLoader" % asset_key)
			_assert_icon_texture(raw_texture, "%s raw SVG" % asset_key)


## Contents without `information.texture` fall back to this framework placeholder.
func test_framework_item_fallback_icon_loads() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var fallback_path := "res://assets/ui/icons/item_fallback.svg"
	assert_true(FileAccess.file_exists(fallback_path), "framework item fallback svg exists")
	assert_eq(context.assets.resolve(fallback_path), fallback_path, "item fallback resolves instead of the missing placeholder")
	var texture: Texture2D = context.assets.load_texture(fallback_path)
	assert_not_null(texture, "framework item fallback loads as Texture2D")
	_assert_icon_texture(texture, "framework item fallback")


## Icons render on 128x128 canvases; anything smaller would be illegible in the
## 24-48px market slots the UI uses.
func _assert_icon_texture(texture: Texture2D, label: String) -> void:
	if texture == null:
		return
	assert_true(texture.get_width() >= 64 and texture.get_height() >= 64, "%s renders at least 64px wide" % label)
	assert_eq(texture.get_width(), texture.get_height(), "%s uses a square canvas" % label)


func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.close()
	return true
