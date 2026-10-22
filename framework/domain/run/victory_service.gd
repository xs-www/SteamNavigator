class_name VictoryService
extends RefCounted
## Run completion: the whole main chain plus a minimum viable large ship
## assembled at a shipyard.
##
## Victory is only evaluated after a successful shipyard install
## (`ShipCommands.install_module` calls `check`). `check` is idempotent: only the
## first satisfying call writes `state.data.victory` and reports
## `newly_achieved: true`.


static func achieved(state: GameState) -> bool:
	var victory: Variant = state.data.get("victory", null)
	return victory is Dictionary and bool(victory.get("achieved", false))


## True when every registered `kind == "main"` contract template is present in
## `contracts.completed`. A hub without main templates can never be complete.
static func main_chain_complete(hub: RegistryHub, state: GameState) -> bool:
	var mains := ContractOps.templates_by_kind(hub, "main")
	if mains.is_empty():
		return false
	var completed: Array = state.contracts().get("completed", [])
	for template in mains:
		if not completed.has(template.id):
			return false
	return true


## Individual victory gates, useful for UI hints and tests.
static func conditions(hub: RegistryHub, state: GameState) -> Dictionary:
	var ship := state.ship()
	var port_data := MapOps.port(state.world(), state.current_port_id())
	var shipyard := MapOps.has_facility(port_data, "shipyard")
	var main_complete := main_chain_complete(hub, state)
	var ship_stats := ShipOps.stats(hub, ship)
	var large_hull := int(ship_stats.get("hull_tier", 0)) >= 3
	var boiler := ModuleOps.category_of_id(hub, String(ship.get("boiler_id", ""))) == "boiler"
	var cargo := not ShipOps.cargo_module_ids(ship).is_empty()
	var ready := shipyard and main_complete and large_hull and boiler and cargo
	return {
		"shipyard": shipyard,
		"main_complete": main_complete,
		"large_hull": large_hull,
		"boiler": boiler,
		"cargo": cargo,
		"ready": ready,
	}


## Called after a successful shipyard install. Returns
## `{newly_achieved, achieved, conditions, summary}`; `summary` is only filled
## on the call that actually awards the run.
static func check(state: GameState, hub: RegistryHub) -> Dictionary:
	var gates := conditions(hub, state)
	if achieved(state):
		return {
			"newly_achieved": false,
			"achieved": true,
			"conditions": gates,
			"summary": {},
		}
	if not bool(gates.get("ready", false)):
		return {
			"newly_achieved": false,
			"achieved": false,
			"conditions": gates,
			"summary": {},
		}
	var run_summary := summary(hub, state)
	state.data["victory"] = {
		"achieved": true,
		"achieved_at": state.now(),
		"summary": run_summary.duplicate(true),
	}
	return {
		"newly_achieved": true,
		"achieved": true,
		"conditions": gates,
		"summary": run_summary,
	}


## Full run summary for the victory screen. Plain JSON data only.
static func summary(hub: RegistryHub, state: GameState) -> Dictionary:
	var ship := state.ship()
	var stats: Dictionary = state.stats()
	var voyages := int(stats.get("voyages", 0))
	var on_time := int(stats.get("on_time", 0))
	var income := int(stats.get("income", 0))
	var expense := int(stats.get("expense", 0))
	var run_data: Dictionary = state.run()
	var starting_build := String(run_data.get("starting_build", ""))
	var build := hub.get_by_id(ContentTypes.STARTING_BUILD, starting_build)
	var hull_id := String(ship.get("hull_id", ""))
	var hull := hub.get_by_id(ContentTypes.HULL, hull_id)
	var modules: Array = []
	for module in ShipOps.installed_modules(hub, ship):
		modules.append({
			"content_type": String(module.content_type),
			"category": ModuleOps.category_of(module),
			"name_key": module.name_key,
			"module_id": module.id,
		})
	return {
		"seed": state.seed(),
		"starting_build": starting_build,
		"starting_build_name_key": build.name_key if build != null else starting_build,
		"game_time": state.now(),
		"voyages": voyages,
		"on_time": on_time,
		"on_time_rate": float(on_time) / float(voyages) if voyages > 0 else 0.0,
		"accidents": int(stats.get("accidents", 0)),
		"income": income,
		"expense": expense,
		"profit": income - expense,
		"money": state.money(),
		"debt_remaining": DebtService.remaining(state),
		"reputation": int(state.player().get("reputation", 0)),
		"durability": float(ship.get("durability", 0.0)),
		"max_durability": ShipOps.durability_max(hub, ship),
		"hull_id": hull_id,
		"hull_name_key": hull.name_key if hull != null else hull_id,
		"cargo_capacity": ShipOps.cargo_capacity(hub, ship),
		"modules": modules,
	}
