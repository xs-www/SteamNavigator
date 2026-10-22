extends TestCase
## @static-doc
## 作用：Content Schema 2.0 运行时武器类型（`weapons`，D1 起 active）与船体安装点镜像
## （hull_data 的 `weapon_sockets` / `rig_sockets`）测试：SchemaValidator 合法 / 非法
## 文件、运行时类型登记（content_types.json / ContentTypes）与 Core 船体镜像回归。
##
## ## 契约与约束
## - `schemas/v2/weapon.schema.json`：战斗字段对齐 SNBattleSim（direct / artillery /
##   broadside），装配字段对齐 WEAPON_SOCKET_CONTRACT；合法 direct 与
##   broadside + yaw_pitch_multi 定义零错误，缺必填 / 越界 / 非法枚举 / 非法颜色 /
##   非法材料 ID 必须报错。
## - `weapons` 自 Phase D1 起是 active 2.0 运行时类型：在 `content_types.json.types`、
##   `ContentTypes.all() / registry_types()` 中，`ContentTypes.schema_path()` 指向 v2
##   weapon schema；不再登记 `draft_schemas` / `draft_types` / `planned`。
## - `schemas/v2/hull.schema.json`（hulls 2.0）的 socket 镜像字段非法（class / kind /
##   缺失 name / 越界 clearance / position 长度错误）必须被拒；不含 socket 字段的 hull
##   内容保持合法；Core 已回填的 14 个 weapon socket + 22 个 rig socket 必须通过校验。
## @end-static-doc

const WEAPON_SCHEMA := "res://schemas/v2/weapon.schema.json"
const HULL_SCHEMA := "res://schemas/v2/hull.schema.json"
const CONTENT_TYPES := "res://content_types.json"
const CORE_HULLS := "res://dev_mods/core/content/hulls.json"


func _direct_weapon_data() -> Dictionary:
	## SNBattleSim `deck_gun`（甲板速射炮）映射到内容 2.0 字段后的默认定义。
	return {
		"kind": "direct",
		"damage": 12.0,
		"range": 245.0,
		"min_range": 0.0,
		"cooldown": 1.65,
		"accuracy": 0.72,
		"projectile_speed": 360.0,
		"splash": 0.0,
		"arc_deg": 260.0,
		"salvo": 1,
		"color": "#ffd37a",
		"weapon_class": "Light",
		"mount_class": "Light",
		"assembly_profile": "yaw_pitch",
		"has_yaw": true,
		"has_pitch": true,
		"has_recoil": true,
		"has_muzzle": true,
		"muzzle_count": 1,
		"envelope_x": 2.815,
		"envelope_y": 1.41,
		"height": 1.613,
		"mount_scale": 1.0,
		"tier": 1,
		"weight": 9.0,
		"purchase_price": 380.0,
		"craft_cost": 170.0,
		"craft_time_hours": 4.0,
		"materials": [],
	}


func _broadside_weapon_data() -> Dictionary:
	## 舷侧炮列：broadside + yaw_pitch_multi + 多炮口，覆盖装配组另一条分支。
	return {
		"kind": "broadside",
		"damage": 8.0,
		"range": 285.0,
		"min_range": 20.0,
		"cooldown": 5.4,
		"accuracy": 0.64,
		"projectile_speed": 330.0,
		"splash": 0.0,
		"arc_deg": 76.0,
		"salvo": 4,
		"color": "#ffcf87",
		"weapon_class": "Side",
		"mount_class": "Side",
		"assembly_profile": "yaw_pitch_multi",
		"has_yaw": true,
		"has_pitch": true,
		"has_recoil": true,
		"has_muzzle": true,
		"muzzle_count": 4,
		"envelope_x": 4.2,
		"envelope_y": 1.1,
		"height": 1.35,
		"mount_scale": 1.0,
		"tier": 2,
		"weight": 22.0,
		"purchase_price": 640.0,
		"craft_cost": 300.0,
		"craft_time_hours": 6.0,
		"materials": [{"id": "core:item/boiler_plate", "amount": 2}],
	}


func _weapon_envelope(data: Dictionary, definition_id: String = "core:weapon/deck_gun") -> Dictionary:
	return {
		"schema_version": "2.0",
		"content_type": "weapons",
		"definitions": [
			{
				"id": definition_id,
				"name_key": "weapon.core.default.name",
				"description_key": "weapon.core.default.description",
				"tags": ["weapon.direct", "weapon.light", "weapon.mounted"],
				"enabled": true,
				"information": {"model": "model.weapon.deck_gun"},
				"data": data,
			},
		],
	}


func _validate_weapon_data(data: Dictionary) -> Array:
	return SchemaValidator.new().validate_file(_weapon_envelope(data), WEAPON_SCHEMA)


func _weapon_errors_with(overrides: Dictionary) -> Array:
	var data := _direct_weapon_data()
	for key in overrides.keys():
		data[String(key)] = overrides[key]
	return _validate_weapon_data(data)


func _hull_data() -> Dictionary:
	## 带 socket 镜像的合法 hull 1.0 定义（字段取自 Core 回填的镜像口径）。
	return {
		"tier": 1,
		"weight": 22.0,
		"purchase_price": 380.0,
		"craft_cost": 170.0,
		"craft_time_hours": 4.0,
		"materials": [],
		"base_speed": 14.0,
		"max_weight": 100.0,
		"max_durability": 100.0,
		"cargo_slots": 1,
		"cabin_slots": 0,
		"base_risk": 0.025,
		"size_tag": "small",
		"weapon_sockets": [
			{
				"name": "SN_Socket_Weapon_Port_1",
				"socket_class": "Light",
				"socket_index": 0,
				"position": [9.6, 0.8, 1.91],
				"clearance_r": 1.0,
				"clearance_x": 1.35,
				"clearance_y": 1.35,
				"clearance_h": 20.0,
				"mount_scale": 1.0,
				"note": "port light mount",
			},
			{
				"name": "SN_Socket_Weapon_Starboard_1",
				"socket_class": "Light",
				"socket_index": 1,
				"position": [9.6, -0.8, 1.91],
				"clearance_r": 1.0,
				"clearance_x": 1.35,
				"clearance_y": 1.35,
				"clearance_h": 20.0,
				"mount_scale": 1.0,
			},
		],
		"rig_sockets": [
			{
				"name": "SN_Socket_Mast_Fore",
				"socket_kind": "mast",
				"mast_id": "fore",
				"socket_index": 0,
				"position": [4.6, 0.0, 2.575],
				"rig_height": 12.4,
				"rig_deck_z": 2.575,
				"rig_stowed": false,
			},
			{
				"name": "SN_Socket_Yard_Fore",
				"socket_kind": "yard",
				"mast_id": "fore",
				"socket_index": 1,
				"position": [3.945, 0.0, 17.571],
				"rig_yard_z": 17.571,
				"rig_yard_length": 8.0,
				"rig_sail_area_m2": 24.0,
			},
		],
	}


func _hull_envelope(data: Dictionary) -> Dictionary:
	return {
		"schema_version": "2.0",
		"content_type": "hulls",
		"definitions": [
			{
				"id": "core:hull/socketed_test",
				"name_key": "module.core.socketed_test.name",
				"description_key": "module.core.socketed_test.description",
				"tags": ["module.hull", "module.small"],
				"enabled": true,
				"data": data,
			},
		],
	}


func _has_error(errors: Array, path: String, keyword: String) -> bool:
	for error in errors:
		if not (error is Dictionary):
			continue
		if String(error.get("path", "")) == path and String(error.get("keyword", "")) == keyword:
			return true
	return false


func _parse_json(path: String) -> Dictionary:
	var parsed := JsonUtils.parse_file(path)
	if not bool(parsed.get("ok", false)):
		fail("%s cannot be parsed: %s" % [path, String(parsed.get("error", ""))])
		return {}
	if not (parsed.get("value") is Dictionary):
		fail("%s root is not an object" % path)
		return {}
	return parsed["value"]


func test_weapon_v2_schema_accepts_direct_weapon() -> void:
	var validator := SchemaValidator.new()
	var errors := validator.validate_file(_weapon_envelope(_direct_weapon_data()), WEAPON_SCHEMA)
	assert_empty(errors, "valid direct weapon passes Schema 2.0 draft: %s" % str(errors))


func test_weapon_v2_schema_accepts_broadside_multi_mount_weapon() -> void:
	var validator := SchemaValidator.new()
	var envelope := _weapon_envelope(_broadside_weapon_data(), "core:weapon/broadside_battery")
	var errors := validator.validate_file(envelope, WEAPON_SCHEMA)
	assert_empty(errors, "valid broadside yaw_pitch_multi weapon passes Schema 2.0 draft: %s" % str(errors))


func test_weapon_v2_schema_rejects_missing_required_and_enum_errors() -> void:
	var missing_data := _direct_weapon_data()
	missing_data.erase("damage")
	var missing_errors := _validate_weapon_data(missing_data)
	assert_true(
		_has_error(missing_errors, "/definitions/0/data/damage", "required"),
		"missing required damage is rejected: %s" % str(missing_errors)
	)

	var enum_errors := _weapon_errors_with({
		"kind": "laser",
		"weapon_class": "Mega",
		"assembly_profile": "aim_bot",
	})
	assert_true(
		_has_error(enum_errors, "/definitions/0/data/kind", "enum"),
		"invalid kind enum is rejected: %s" % str(enum_errors)
	)
	assert_true(
		_has_error(enum_errors, "/definitions/0/data/weapon_class", "enum"),
		"invalid weapon_class enum is rejected: %s" % str(enum_errors)
	)
	assert_true(
		_has_error(enum_errors, "/definitions/0/data/assembly_profile", "enum"),
		"invalid assembly_profile enum is rejected: %s" % str(enum_errors)
	)


func test_weapon_v2_schema_rejects_out_of_range_and_pattern_errors() -> void:
	var range_errors := _weapon_errors_with({
		"damage": 0.0,
		"range": 20.0,
		"accuracy": 0.99,
		"salvo": 0,
		"cooldown": 0.1,
	})
	assert_true(
		_has_error(range_errors, "/definitions/0/data/damage", "minimum"),
		"damage below minimum is rejected: %s" % str(range_errors)
	)
	assert_true(
		_has_error(range_errors, "/definitions/0/data/range", "minimum"),
		"range below minimum is rejected: %s" % str(range_errors)
	)
	assert_true(
		_has_error(range_errors, "/definitions/0/data/accuracy", "maximum"),
		"accuracy above maximum is rejected: %s" % str(range_errors)
	)
	assert_true(
		_has_error(range_errors, "/definitions/0/data/salvo", "minimum"),
		"salvo below minimum is rejected: %s" % str(range_errors)
	)
	assert_true(
		_has_error(range_errors, "/definitions/0/data/cooldown", "minimum"),
		"cooldown below minimum is rejected: %s" % str(range_errors)
	)

	var color_errors := _weapon_errors_with({"color": "orange"})
	assert_true(
		_has_error(color_errors, "/definitions/0/data/color", "pattern"),
		"colour without #RRGGBB is rejected: %s" % str(color_errors)
	)

	var material_errors := _weapon_errors_with({
		"materials": [{"id": "not_an_id", "amount": 2}],
	})
	assert_true(
		_has_error(material_errors, "/definitions/0/data/materials/0/id", "pattern"),
		"material item without a definition ID is rejected: %s" % str(material_errors)
	)

	var extra_errors := _weapon_errors_with({"mass": 9.0})
	assert_true(
		_has_error(extra_errors, "/definitions/0/data/mass", "additionalProperties"),
		"unknown weapon data field is rejected: %s" % str(extra_errors)
	)


func test_weapon_v2_schema_rejects_wrong_envelope() -> void:
	var envelope := _weapon_envelope(_direct_weapon_data())
	envelope["schema_version"] = "1.0"
	envelope["content_type"] = "hulls"
	var errors := SchemaValidator.new().validate_file(envelope, WEAPON_SCHEMA)
	assert_true(
		_has_error(errors, "/schema_version", "const"),
		"non-2.0 schema_version is rejected: %s" % str(errors)
	)
	assert_true(
		_has_error(errors, "/content_type", "const"),
		"non-weapons content_type is rejected: %s" % str(errors)
	)


func test_weapon_type_matches_schema() -> void:
	var manifest := _parse_json(CONTENT_TYPES)
	var active_types: Dictionary = {}
	for entry in manifest.get("types", []):
		if entry is Dictionary:
			active_types[String(entry.get("key", ""))] = entry
	assert_true(active_types.has("weapons"), "weapons is an active runtime type")
	if not active_types.has("weapons"):
		return
	var weapon_entry: Dictionary = active_types["weapons"]
	assert_eq(
		String(weapon_entry.get("schema", "")),
		"schemas/v2/weapon.schema.json",
		"weapons points at the weapon schema"
	)
	assert_eq(String(weapon_entry.get("schema_version", "")), "2.0", "weapons declares 2.0")
	assert_eq(String(ContentTypes.schema_path(ContentTypes.WEAPON)), WEAPON_SCHEMA, "runtime schema path is the weapon schema")
	assert_eq(ContentTypes.schema_version(ContentTypes.WEAPON), "2.0", "runtime version is 2.0")
	assert_true(FileAccess.file_exists(WEAPON_SCHEMA), "weapon schema file exists")

	var schema := _parse_json(WEAPON_SCHEMA)
	if schema.is_empty():
		return
	var schema_version_property: Dictionary = schema.get("properties", {}).get("schema_version", {})
	var content_type_property: Dictionary = schema.get("properties", {}).get("content_type", {})
	assert_eq(String(schema_version_property.get("const", "")), "2.0", "weapon schema pins schema_version 2.0")
	assert_eq(String(content_type_property.get("const", "")), "weapons", "weapon schema pins content_type weapons")

	assert_eq(String(weapon_entry.get("singular", "")), "weapon", "weapons singular")
	assert_eq(String(weapon_entry.get("key_prefix", "")), "weapon", "weapons key prefix")
	assert_eq(String(weapon_entry.get("group", "")), "combat", "weapons group is combat")
	assert_eq(String(weapon_entry.get("default_file", "")), "content/weapons.json", "weapons default file")
	assert_eq(String(weapon_entry.get("capability", "")), "content.combat.v1", "weapons capability")
	assert_eq(
		String(weapon_entry.get("schema_version", "")),
		String(schema_version_property.get("const", "")),
		"runtime type schema_version matches the schema const"
	)


func test_weapon_type_is_active_runtime() -> void:
	var manifest := _parse_json(CONTENT_TYPES)
	for system in manifest.get("planned", []):
		if system is Dictionary and String(system.get("capability", "")) == "content.combat.v1":
			fail("content.combat.v1 must not stay planned now that its types are active")
	assert_true(ContentTypes.all().has(ContentTypes.WEAPON), "weapons is in ContentTypes.all()")
	assert_true(ContentTypes.registry_types().has(ContentTypes.WEAPON), "weapons has a runtime registry")
	assert_true(ContentTypes.is_known(ContentTypes.WEAPON), "weapons has a runtime schema mapping")
	assert_eq(ContentTypes.schema_version(ContentTypes.WEAPON), "2.0", "weapons runtime version is 2.0")


func test_hull_schema_accepts_socket_mirror_fields() -> void:
	var errors := SchemaValidator.new().validate_file(_hull_envelope(_hull_data()), HULL_SCHEMA)
	assert_empty(errors, "valid hull with weapon/rig socket mirrors passes: %s" % str(errors))


func test_hull_schema_rejects_invalid_socket_entries() -> void:
	var data := _hull_data()
	data["weapon_sockets"] = [
		{"name": "SN_Socket_Weapon_Port_1", "socket_class": "Giant", "socket_index": 0},
		{"socket_class": "Light", "socket_index": 1},
		{
			"name": "SN_Socket_Weapon_Aft_1",
			"socket_class": "Medium",
			"socket_index": 2,
			"clearance_r": 31.0,
		},
		{
			"name": "SN_Socket_Weapon_Bow_1",
			"socket_class": "Heavy",
			"socket_index": 3,
			"position": [1.0, 2.0],
		},
	]
	data["rig_sockets"] = [
		{"name": "SN_Socket_Mast_Fore", "socket_kind": "rope", "socket_index": 0},
		{"name": "SN_Socket_Yard_Fore", "socket_kind": "yard", "socket_index": 1, "position": [1.0, 2.0, 3.0, 4.0]},
	]
	var errors := SchemaValidator.new().validate_file(_hull_envelope(data), HULL_SCHEMA)
	assert_true(
		_has_error(errors, "/definitions/0/data/weapon_sockets/0/socket_class", "enum"),
		"invalid weapon socket_class is rejected: %s" % str(errors)
	)
	assert_true(
		_has_error(errors, "/definitions/0/data/weapon_sockets/1/name", "required"),
		"weapon socket without name is rejected: %s" % str(errors)
	)
	assert_true(
		_has_error(errors, "/definitions/0/data/weapon_sockets/2/clearance_r", "maximum"),
		"weapon socket clearance above maximum is rejected: %s" % str(errors)
	)
	assert_true(
		_has_error(errors, "/definitions/0/data/weapon_sockets/3/position", "minItems"),
		"weapon socket position shorter than 3 values is rejected: %s" % str(errors)
	)
	assert_true(
		_has_error(errors, "/definitions/0/data/rig_sockets/0/socket_kind", "enum"),
		"invalid rig socket_kind is rejected: %s" % str(errors)
	)
	assert_true(
		_has_error(errors, "/definitions/0/data/rig_sockets/1/position", "maxItems"),
		"rig socket position longer than 3 values is rejected: %s" % str(errors)
	)
	assert_true(errors.size() >= 6, "invalid socket mirrors report at least 6 errors: %d" % errors.size())


func test_hull_schema_accepts_legacy_content_without_sockets() -> void:
	var data := _hull_data()
	data.erase("weapon_sockets")
	data.erase("rig_sockets")
	var errors := SchemaValidator.new().validate_file(_hull_envelope(data), HULL_SCHEMA)
	assert_empty(errors, "hull 1.0 content without socket mirrors still passes: %s" % str(errors))


func test_core_hull_socket_mirrors_are_schema_valid() -> void:
	var parsed := JsonUtils.parse_file(CORE_HULLS)
	assert_true(bool(parsed.get("ok", false)), "core hulls.json parses")
	if not bool(parsed.get("ok", false)):
		return
	var hulls: Dictionary = parsed["value"]
	var errors := SchemaValidator.new().validate_file(hulls, HULL_SCHEMA)
	assert_empty(errors, "core hulls with socket mirrors pass the hull schema: %s" % str(errors))

	var weapon_total := 0
	var rig_total := 0
	for definition in hulls.get("definitions", []):
		if not (definition is Dictionary):
			continue
		var data: Dictionary = definition.get("data", {})
		weapon_total += (data.get("weapon_sockets", []) as Array).size()
		rig_total += (data.get("rig_sockets", []) as Array).size()
	assert_eq(weapon_total, 14, "core hulls mirror 14 weapon sockets")
	assert_eq(rig_total, 22, "core hulls mirror 22 rig sockets")
