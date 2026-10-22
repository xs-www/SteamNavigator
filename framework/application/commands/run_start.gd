class_name RunStartCommand
extends RefCounted
## @static-doc
## 作用：`run.start` 命令入口（C4 起所有开局统一走 CampaignFactory）。无
## `start_profile` 时调用 `CampaignFactory.create_default_campaign`（默认 start
## profile + `starting_scenarios` 选择）；显式 `start_profile` 时走
## `CampaignFactory.create_campaign`。成功后替换 `AppContext` 的 state / rng，发
## `run.started` 事件并请求自动存档。
##
## - 关键依赖：`CampaignFactory.create_campaign` / `create_default_campaign`、
##   `GameState.world()` 的 `start_profile_id / world_profile_id / map_config_id /
##   starting_scenario_id`、`Result`
##
## ## 契约与约束
## - 参数：`starting_scenario`（完整 ID，可空 = core start profile 默认场景）、
##   `start_profile`（完整 ID，可空 = 默认 start profile）、`seed`、`tutorial`、`force`。
##   C4 起不再有 `build_id` / `map_profiles`。
## - 主线委托 / 普通委托 / notice / tutorial 的 `StoryService.begin` 由工厂负责，
##   本命令只做提交与事件。
## - `run.started` payload：`starting_scenario / start_profile / world_profile /
##   map_config`；id 一律从已提交的 `state.world` 读取，避免与工厂返回值两套真源。
## @end-static-doc


static func execute(params: Dictionary, context) -> Dictionary:
	if context.has_run() and not bool(params.get("force", false)):
		return Result.fail("run_already_started", "ui.error.run_already_started")
	var starting_scenario_id := String(params.get("starting_scenario", ""))
	var seed := int(params.get("seed", 0))
	var tutorial := bool(params.get("tutorial", false))
	var start_profile_id := String(params.get("start_profile", ""))
	var created: Dictionary
	if start_profile_id.is_empty():
		created = CampaignFactory.create_default_campaign(context, starting_scenario_id, seed, tutorial)
	else:
		created = CampaignFactory.create_campaign(context, start_profile_id, seed, tutorial, starting_scenario_id)
	if not bool(created["ok"]):
		return created
	var data: Dictionary = created["data"]
	var new_state: GameState = data["state"]
	context.state.replace_with(new_state)
	context.rng = data["rng"]
	context.pre_voyage_state = null
	var state: GameState = context.state
	var resolved_scenario_id := String(state.world().get("starting_scenario_id", ""))
	if resolved_scenario_id.is_empty():
		resolved_scenario_id = String(state.campaign_setup().get("starting_scenario_id", state.run().get("starting_scenario", "")))
	var main_contract: Variant = state.contracts().get("main", null)
	return {
		"ok": true,
		"error_code": "",
		"message_key": "",
		"data": {
			"starting_scenario_id": resolved_scenario_id,
			"seed": int(data.get("seed", seed)),
			"money": state.money(),
			"current_port_id": state.current_port_id(),
			"main_contract": main_contract.duplicate(true) if main_contract is Dictionary else null,
		},
		"events": [{
			"type": "run.started",
			"payload": {
				"starting_scenario": resolved_scenario_id,
				"seed": int(data.get("seed", seed)),
				"start_profile": String(state.world().get("start_profile_id", "")),
				"world_profile": String(state.world().get("world_profile_id", "")),
				"map_config": String(state.world().get("map_config_id", "")),
			},
		}],
		"autosave": true,
	}
