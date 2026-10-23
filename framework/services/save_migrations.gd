class_name SaveMigrations
extends RefCounted
## Save payload migrations.
##
## `save_schema` describes the payload/state wrapper. `state_schema` describes
## the CampaignState data. The first v2 schema keeps the existing run fields and
## adds a campaign metadata block; later v2 systems extend the state in place.
## @static-doc
## 作用：存档 payload 版本迁移与内容版本表（B5）：1.x → 2.0、campaign 元数据回填、
## `campaign.setup.content_versions` 快照/推断/漂移警告，以及保存前的版本快照。
##
## ## 契约与约束
## - `save_schema`/`state_schema` 当前 2.0；1.x 只做兼容增量，保留 run/world/ship 字段。
##   Phase E 冻结的是 Content Schema 1.0（内容 envelope），存档 payload 迁移仍保留。
## - D3：新档由 `prepare_for_save()` 从 `ContentTypes.SCHEMA_VERSIONS` 快照全部类型版本；
##   旧档缺表时用当前注册表补齐缺失类型（C4 起 `starting_scenarios` / `map_configs` 均为
##   2.0，`map_profiles` 已退役，不再做 1.0 类型推断）。
## - 存档里已记录的版本与当前运行时不符时只写 `content version drift: <type> save=... current=...`
##   warning；存档仍可读，不重排世界、不重新随机。
## - 缺失的 campaign 分区由 `GameState.ensure_campaign_sections` 逐段回填并写入 warnings；
##   未知主版本直接拒绝。
## @end-static-doc

const CURRENT_SAVE_SCHEMA := "2.0"
const CURRENT_STATE_SCHEMA := "2.0"


## Returns {ok, error, payload, from, migrated, warnings}.
static func migrate(payload: Dictionary) -> Dictionary:
	var from := String(payload.get("save_schema", ""))
	if from == CURRENT_SAVE_SCHEMA:
		var checked := _ensure_current(payload, false)
		checked["from"] = from
		checked["migrated"] = false
		return checked
	if from.begins_with("1."):
		var migrated := _migrate_1_to_2(payload, from)
		migrated["from"] = from
		migrated["migrated"] = true
		return migrated
	return _fail(payload, from, "unsupported save schema: %s" % from)


static func _migrate_1_to_2(payload: Dictionary, from: String) -> Dictionary:
	var next: Dictionary = payload.duplicate(true)
	var warnings: Array[String] = []
	var state_value: Variant = next.get("state", null)
	if not (state_value is Dictionary):
		return _fail(next, from, "save is missing state", warnings)
	var state: Dictionary = state_value
	state["schema_version"] = CURRENT_STATE_SCHEMA
	_ensure_campaign(state, next, warnings)
	_ensure_content_versions(state, warnings)
	next["save_schema"] = CURRENT_SAVE_SCHEMA
	next["state_schema"] = CURRENT_STATE_SCHEMA
	next["content_schema"] = FrameworkInfo.CONTENT_SCHEMA
	next["migrated_from"] = from
	return {
		"ok": true,
		"error": "",
		"payload": next,
		"warnings": warnings,
	}


static func _ensure_current(payload: Dictionary, backfill_only: bool) -> Dictionary:
	var next: Dictionary = payload.duplicate(true)
	var warnings: Array[String] = []
	var state_value: Variant = next.get("state", null)
	if not (state_value is Dictionary):
		return _fail(next, String(next.get("save_schema", "")), "save is missing state", warnings)
	var state: Dictionary = state_value
	if not backfill_only:
		state["schema_version"] = CURRENT_STATE_SCHEMA
		next["state_schema"] = CURRENT_STATE_SCHEMA
		if not next.has("content_schema"):
			next["content_schema"] = FrameworkInfo.CONTENT_SCHEMA
	_ensure_campaign(state, next, warnings)
	_ensure_content_versions(state, warnings)
	return {
		"ok": true,
		"error": "",
		"payload": next,
		"warnings": warnings,
	}


static func _ensure_campaign(state: Dictionary, payload: Dictionary, warnings: Array[String]) -> void:
	var current: Variant = state.get("campaign", null)
	if current is Dictionary:
		var campaign: Dictionary = current
		for key in GameState.CAMPAIGN_DEFAULTS.keys():
			if not campaign.has(key):
				campaign[key] = GameState.CAMPAIGN_DEFAULTS[key]
				warnings.append("campaign.%s backfilled" % key)
		GameState.ensure_campaign_sections(campaign, warnings)
		return
	var run_value: Variant = state.get("run", {})
	var run: Dictionary = run_value if run_value is Dictionary else {}
	var seed_value := int(payload.get("seed", run.get("seed", 0)))
	var created_at := String(payload.get("created_at", run.get("started_at", "")))
	var campaign := GameState.CAMPAIGN_DEFAULTS.duplicate(true)
	campaign["id"] = "campaign_%d" % seed_value
	campaign["created_at"] = created_at
	campaign["playtime_hours"] = float(run.get("game_time", 0.0))
	GameState.ensure_campaign_sections(campaign, warnings)
	state["campaign"] = campaign
	warnings.append("campaign metadata added")


## Snapshots the current per-type content schema versions for a fresh save.
## The live state is not mutated: SaveService calls this on its clone.
static func prepare_for_save(state: Dictionary) -> void:
	var warnings: Array[String] = []
	_ensure_content_versions(state, warnings)


## Fills `campaign.setup.content_versions` (D3): missing types are completed from the
## current registry, and recorded versions that differ from the runtime produce a
## drift warning without blocking the load or re-generating the world.
static func _ensure_content_versions(state: Dictionary, warnings: Array[String]) -> void:
	var campaign_value: Variant = state.get("campaign", null)
	if not (campaign_value is Dictionary):
		return
	var campaign: Dictionary = campaign_value
	var setup_value: Variant = campaign.get("setup", null)
	if not (setup_value is Dictionary):
		return
	var setup: Dictionary = setup_value
	var versions_value: Variant = setup.get("content_versions", null)
	var versions: Dictionary = versions_value.duplicate(true) if versions_value is Dictionary else {}
	for type_key in ContentTypes.SCHEMA_VERSIONS.keys():
		var key := String(type_key)
		if not versions.has(key):
			versions[key] = String(ContentTypes.SCHEMA_VERSIONS[type_key])
	for key in versions.keys():
		var content_type := StringName(String(key))
		var current := String(ContentTypes.SCHEMA_VERSIONS.get(content_type, ""))
		if current.is_empty():
			continue
		var saved := String(versions[key])
		if saved != current:
			warnings.append("content version drift: %s save=%s current=%s" % [key, saved, current])
	setup["content_versions"] = versions


static func _fail(payload: Dictionary, from: String, message: String, warnings: Array[String] = []) -> Dictionary:
	return {
		"ok": false,
		"error": message,
		"payload": payload,
		"from": from,
		"migrated": false,
		"warnings": warnings,
	}
