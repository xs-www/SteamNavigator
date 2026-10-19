class_name SaveMigrations
extends RefCounted
## Save payload migrations.
##
## `save_schema` describes the payload/state wrapper. `state_schema` describes
## the CampaignState data. The first v2 schema keeps the existing run fields and
## adds a campaign metadata block; later v2 systems extend the state in place.

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


static func _fail(payload: Dictionary, from: String, message: String, warnings: Array[String] = []) -> Dictionary:
	return {
		"ok": false,
		"error": message,
		"payload": payload,
		"from": from,
		"migrated": false,
		"warnings": warnings,
	}
