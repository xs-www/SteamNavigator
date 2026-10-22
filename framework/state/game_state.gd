class_name GameState
extends RefCounted
## The complete mutable run state.
##
## GameState is a plain-data wrapper so it can be deep-cloned per command
## transaction, serialized directly, and fingerprinted for determinism tests.
## Content definitions never live here; only IDs and runtime values do.

const SCHEMA_VERSION := "2.0"

## Campaign metadata. The v2 state keeps the existing run fields and adds this
## block so persistent saves can carry identity and lifecycle information.
const CAMPAIGN_DEFAULTS := {
	"id": "",
	"name": "Steam Navigator",
	"created_at": "",
	"difficulty": "standard",
	"status": "active",
	"playtime_hours": 0.0,
}

## Campaign subsystem sections. A section is added when its runtime system lands
## and only stores generated instances / progress (ids and primitives), never
## content definitions. The top-level `world` block keeps the generated map
## layout; `campaign.world` is the exploration progress layered over it.
const CAMPAIGN_SECTION_DEFAULTS := {
	## Identity of the v2 campaign that produced this state. The 1.0 path keeps
	## the ids empty; old saves get the block lazily with empty ids.
	"setup": {
		"start_profile_id": "",
		"world_profile_id": "",
		"map_config_id": "",
		"starting_build_id": "",
		"difficulty": "standard",
		"seed": 0,
		"content_versions": {},
	},
	"world": {
		"profile_id": "",
		"generated": false,
		## v2 world assembly output. A 1.0 run leaves both lists empty; existing
		## saves keep their visited/discovered progress untouched.
		"regions": [],
		"sites": [],
		"visited_region_ids": [],
		"discovered_site_ids": [],
		"visited_port_ids": [],
	},
	"codex": {
		"discovered_ids": [],
		"entries": {},
	},
	"factions": {},
}

## Per-faction entry shape stored under `campaign.factions.<faction_id>`.
## Entries are created lazily; `attitude/discovered/met_at` are backfilled on
## existing 1.0 entries without rewriting the world.
const FACTION_ENTRY_DEFAULTS := {
	"reputation": 0,
	"attitude": "neutral",
	"discovered": false,
	"met_at": 0.0,
}

## Default run statistics. `profit` is always derived as `income - expense`.
const STATS_DEFAULTS := {
	"voyages": 0,
	"on_time": 0,
	"accidents": 0,
	"income": 0,
	"expense": 0,
	"profit": 0,
}

## Clue log (stage 4 exploration). Lazy: old saves simply get this block backfilled on
## first access, so no `schema_version` bump is needed. `expired` keeps the full
## snapshot of timed-out goods clues (stage 4.4) so the list page can show history.
const CLUES_DEFAULTS := {
	"next_id": 1,
	"active": [],
	"failed": [],
	"resolved": [],
	"expired": [],
}

## Stage 4.5 story / tutorial progress. Lazy: saves created before the tutorial
## system get `active=false, completed=true` (no gating, no story cards), so no
## `schema_version` bump is needed.
const STORY_DEFAULTS := {
	"flow_id": "",
	"stage_index": -1,
	"active": false,
	"completed": true,
	"skipped": false,
	"home_port_id": "",
	"seen": [],
	"counters": {},
	"flags": {},
	"unlocked_features": [],
	"unlocked_items": [],
	"unlocked_modules": [],
}

var data: Dictionary = {}
func _init(initial_data: Dictionary = {}) -> void:
	data = initial_data


func clone() -> GameState:
	return GameState.new(data.duplicate(true))


func replace_with(other: GameState) -> void:
	data = other.data.duplicate(true)


func to_dict() -> Dictionary:
	return data.duplicate(true)


static func from_dict(value: Dictionary) -> GameState:
	return GameState.new(value.duplicate(true))


func is_empty() -> bool:
	return data.is_empty()


func hash() -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JsonUtils.canonical_stringify(data).to_utf8_buffer())
	return context.finish().hex_encode()


func schema_version() -> String:
	return String(data.get("schema_version", ""))


func campaign() -> Dictionary:
	return ensure_campaign()


## Backfills campaign metadata for states created before Schema 2.0 or by tests.
func ensure_campaign() -> Dictionary:
	var current: Variant = data.get("campaign", null)
	if not (current is Dictionary):
		current = CAMPAIGN_DEFAULTS.duplicate(true)
		current["id"] = "campaign_%d" % self.seed()
		current["created_at"] = String(run().get("started_at", ""))
		current["playtime_hours"] = now()
		data["campaign"] = current
	var campaign: Dictionary = current
	for key in CAMPAIGN_DEFAULTS.keys():
		if not campaign.has(key):
			campaign[key] = CAMPAIGN_DEFAULTS[key]
	ensure_campaign_sections(campaign)
	return campaign


## Backfills campaign subsystem sections without touching existing values.
## `warnings` (optional) receives one entry per backfilled section or field.
static func ensure_campaign_sections(campaign: Dictionary, warnings: Array = []) -> void:
	for section_key in CAMPAIGN_SECTION_DEFAULTS.keys():
		var defaults: Dictionary = CAMPAIGN_SECTION_DEFAULTS[section_key]
		var current: Variant = campaign.get(section_key, null)
		if not (current is Dictionary):
			campaign[section_key] = defaults.duplicate(true)
			warnings.append("campaign.%s backfilled" % section_key)
			continue
		var section: Dictionary = current
		for key in defaults.keys():
			if not section.has(key):
				section[key] = _copy_default(defaults[key])
				warnings.append("campaign.%s.%s backfilled" % [section_key, key])
		if section_key == "factions":
			for faction_id in section.keys():
				var entry: Variant = section[faction_id]
				if not (entry is Dictionary):
					entry = {}
					section[faction_id] = entry
				for key in FACTION_ENTRY_DEFAULTS.keys():
					if not (entry as Dictionary).has(key):
						(entry as Dictionary)[key] = _copy_default(FACTION_ENTRY_DEFAULTS[key])
						warnings.append("campaign.factions.%s.%s backfilled" % [faction_id, key])


static func _copy_default(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value


## Exploration progress: visited / discovered ids over the generated map.
func campaign_world() -> Dictionary:
	return ensure_campaign().get("world", {})


## v2 campaign identity block (start/world/map config ids, difficulty, seed,
## content versions). Lazy: 1.0 states get empty ids instead of a migration.
func campaign_setup() -> Dictionary:
	return ensure_campaign().get("setup", {})


func campaign_codex() -> Dictionary:
	return ensure_campaign().get("codex", {})


## Faction runtime state keyed by faction definition id; each value is a dict
## with at least `reputation`.
func campaign_factions() -> Dictionary:
	return ensure_campaign().get("factions", {})


## Returns one faction's runtime entry, creating it with neutral defaults
## (`reputation/attitude/discovered/met_at`) on first access.
func campaign_faction(faction_id: String) -> Dictionary:
	if faction_id.is_empty():
		return {}
	var factions := campaign_factions()
	var current: Variant = factions.get(faction_id, null)
	if not (current is Dictionary):
		current = FACTION_ENTRY_DEFAULTS.duplicate(true)
		factions[faction_id] = current
	return current


func mark_region_visited(region_id: String) -> bool:
	return _remember_id(campaign_world(), "visited_region_ids", region_id)


func is_region_visited(region_id: String) -> bool:
	return _contains_id(campaign_world(), "visited_region_ids", region_id)


func mark_port_visited(port_id: String) -> bool:
	return _remember_id(campaign_world(), "visited_port_ids", port_id)


func is_port_visited(port_id: String) -> bool:
	return _contains_id(campaign_world(), "visited_port_ids", port_id)


func discover_site(site_id: String) -> bool:
	return _remember_id(campaign_world(), "discovered_site_ids", site_id)


func is_site_discovered(site_id: String) -> bool:
	return _contains_id(campaign_world(), "discovered_site_ids", site_id)


## Records a codex entry; returns true only when the id is newly discovered.
func discover_codex(discovery_id: String) -> bool:
	return _remember_id(campaign_codex(), "discovered_ids", discovery_id)


func is_codex_discovered(discovery_id: String) -> bool:
	return _contains_id(campaign_codex(), "discovered_ids", discovery_id)


func set_faction_reputation(faction_id: String, value: int) -> void:
	if faction_id.is_empty():
		return
	campaign_faction(faction_id)["reputation"] = clampi(value, -100, 100)


func faction_reputation(faction_id: String) -> int:
	var current: Variant = campaign_factions().get(faction_id, null)
	if not (current is Dictionary):
		return 0
	return int(current.get("reputation", 0))


func _remember_id(section: Dictionary, key: String, id: String) -> bool:
	if id.is_empty():
		return false
	var ids: Array = _id_list(section, key)
	if ids.has(id):
		return false
	ids.append(id)
	section[key] = ids
	return true


func _contains_id(section: Dictionary, key: String, id: String) -> bool:
	if id.is_empty():
		return false
	return _id_list(section, key).has(id)


func _id_list(section: Dictionary, key: String) -> Array:
	var current: Variant = section.get(key, null)
	if current is Array:
		return current
	var ids: Array = []
	section[key] = ids
	return ids


func run() -> Dictionary:
	return data.get("run", {})


func player() -> Dictionary:
	return data.get("player", {})


func world() -> Dictionary:
	return data.get("world", {})


func ship() -> Dictionary:
	return data.get("ship", {})


func market() -> Dictionary:
	return data.get("market", {})


func contracts() -> Dictionary:
	return data.get("contracts", {})


## Returns the run statistics, creating/repairing them lazily so old saves and
## partially initialized test states never need a migration pass.
func stats() -> Dictionary:
	return ensure_stats()


## Exploration clue log. Missing in saves created before stage 4; backfilled lazily.
func clues() -> Dictionary:
	return ensure_clues()


func ensure_clues() -> Dictionary:
	var current: Variant = data.get("clues", null)
	if not (current is Dictionary):
		current = CLUES_DEFAULTS.duplicate(true)
		data["clues"] = current
	var clues_data: Dictionary = current
	for key in CLUES_DEFAULTS.keys():
		if not clues_data.has(key):
			clues_data[key] = GameState._copy_default(CLUES_DEFAULTS[key])
	return clues_data


## Story / tutorial progress. Missing in saves created before stage 4.5; backfilled
## lazily as "already completed" so old saves keep every feature and never see the
## tutorial card.
func story() -> Dictionary:
	return ensure_story()


func ensure_story() -> Dictionary:
	var current: Variant = data.get("story", null)
	if not (current is Dictionary):
		current = STORY_DEFAULTS.duplicate(true)
		data["story"] = current
	var story_data: Dictionary = current
	for key in STORY_DEFAULTS.keys():
		if not story_data.has(key):
			story_data[key] = GameState._copy_default(STORY_DEFAULTS[key])
	return story_data


## Active exploration voyage (pure data) or null when not exploring.
func explore_voyage() -> Variant:
	return data.get("explore_voyage", null)


func set_explore_voyage(voyage: Variant) -> void:
	data["explore_voyage"] = voyage


func is_exploring() -> bool:
	return explore_voyage() is Dictionary


func ensure_stats() -> Dictionary:
	var current: Variant = data.get("stats", null)
	if not (current is Dictionary):
		current = STATS_DEFAULTS.duplicate(true)
		data["stats"] = current
	var stats_data: Dictionary = current
	for key in STATS_DEFAULTS.keys():
		if not stats_data.has(key):
			stats_data[key] = STATS_DEFAULTS[key]
	stats_data["profit"] = int(stats_data.get("income", 0)) - int(stats_data.get("expense", 0))
	return stats_data


func record_income(amount: int) -> void:
	if amount <= 0:
		return
	var stats_data := ensure_stats()
	stats_data["income"] = int(stats_data.get("income", 0)) + amount
	stats_data["profit"] = int(stats_data["income"]) - int(stats_data.get("expense", 0))


func record_expense(amount: int) -> void:
	if amount <= 0:
		return
	var stats_data := ensure_stats()
	stats_data["expense"] = int(stats_data.get("expense", 0)) + amount
	stats_data["profit"] = int(stats_data.get("income", 0)) - int(stats_data["expense"])


func now() -> float:
	return float(run().get("game_time", 0.0))


func set_now(value: float) -> void:
	if not data.has("run"):
		data["run"] = {}
	data["run"]["game_time"] = maxf(0.0, value)


func advance_time(hours: float) -> void:
	set_now(now() + maxf(0.0, hours))


func money() -> int:
	return int(player().get("money", 0))


func set_money(value: int) -> void:
	if not data.has("player"):
		data["player"] = {}
	data["player"]["money"] = value


func add_money(amount: int) -> void:
	set_money(money() + amount)


func current_port_id() -> String:
	return String(world().get("current_port_id", ""))


func is_at_port() -> bool:
	return not current_port_id().is_empty() and data.get("voyage", null) == null


func seed() -> int:
	return int(run().get("seed", 0))


func push_notice(text_key: String, params: Dictionary = {}) -> void:
	if not data.has("notices"):
		data["notices"] = []
	var notices: Array = data["notices"]
	notices.append({
		"text_key": text_key,
		"params": params.duplicate(true),
		"game_time": now(),
	})
	if notices.size() > 50:
		notices.pop_front()


func recent_notices(limit: int = 10) -> Array:
	var notices: Array = data.get("notices", [])
	var start := maxi(0, notices.size() - limit)
	return notices.slice(start, notices.size())


func get_value(path: Array, fallback: Variant = null) -> Variant:
	var current: Variant = data
	for segment in path:
		if current is Dictionary and current.has(segment):
			current = current[segment]
		elif current is Array and String(segment).is_valid_int():
			var index := int(segment)
			if index < 0 or index >= current.size():
				return fallback
			current = current[index]
		else:
			return fallback
	return current
