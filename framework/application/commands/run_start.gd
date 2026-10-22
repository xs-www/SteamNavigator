class_name RunStartCommand
extends RefCounted
## @static-doc
## 作用：`run.start` 命令入口（Phase B B3）。保持 1.0 路径原样：无 `start_profile`
## 时调用 `RunFactory.create_run`（旧构筑 + map profile）；显式传完整
## `start_profile` id 时改走 v2 `CampaignFactory.create_campaign`（世界装配 +
## campaign.setup）。成功后替换 `AppContext` 的 state / rng，发 `run.started` 事件并
## 请求自动存档。
##
## - 关键依赖：`RunFactory.create_run`、`CampaignFactory.create_campaign`、
##   `GameState.world()` 的 `start_profile_id / world_profile_id / map_config_id /
##   map_profile_id`、`Result`
##
## ## 契约与约束
## - 参数：`build_id`（1.0 构筑，保留）、`start_profile`（完整 ID，v2）、`seed`、
##   `tutorial`、`force`。`start_profile` 为空 → 1.0 路径行为零变化。
## - 两条路径的工厂返回同形 `{ok,error_code,message_key,data:{state,rng,...},events}`；
##   主线委托 / 普通委托 / notice / tutorial 的 `StoryService.begin` 由各自工厂负责，
##   本命令只做提交与事件。
## - `run.started` payload 增加 `start_profile / world_profile / map_config`；1.0 路径
##   三者均为空串（`map_profile` 仍为 1.0 profile id）。
## - 事件里的 id 一律从已提交的 `state.world` 读取，避免与工厂返回值两套真源。
## @end-static-doc


static func execute(params: Dictionary, context) -> Dictionary:
	if context.has_run() and not bool(params.get("force", false)):
		return Result.fail("run_already_started", "ui.error.run_already_started")
	var build_id := String(params.get("build_id", ""))
	var seed := int(params.get("seed", 0))
	var tutorial := bool(params.get("tutorial", false))
	var start_profile_id := String(params.get("start_profile", ""))
	var created: Dictionary
	if start_profile_id.is_empty():
		created = RunFactory.create_run(context, build_id, seed, tutorial)
	else:
		created = CampaignFactory.create_campaign(context, start_profile_id, seed, tutorial)
	if not bool(created["ok"]):
		return created
	var data: Dictionary = created["data"]
	var new_state: GameState = data["state"]
	context.state.replace_with(new_state)
	context.rng = data["rng"]
	context.pre_voyage_state = null
	var state: GameState = context.state
	var resolved_build_id := ""
	var build_definition: Variant = data.get("build", null)
	if build_definition is ContentDefinition:
		resolved_build_id = String((build_definition as ContentDefinition).id)
	if resolved_build_id.is_empty():
		resolved_build_id = String(state.campaign_setup().get("starting_build_id", state.run().get("starting_build", "")))
	var main_contract: Variant = state.contracts().get("main", null)
	return {
		"ok": true,
		"error_code": "",
		"message_key": "",
		"data": {
			"build_id": resolved_build_id,
			"seed": int(data.get("seed", seed)),
			"money": state.money(),
			"current_port_id": state.current_port_id(),
			"main_contract": main_contract.duplicate(true) if main_contract is Dictionary else null,
		},
		"events": [{
			"type": "run.started",
			"payload": {
				"build_id": resolved_build_id,
				"seed": int(data.get("seed", seed)),
				"map_profile": String(state.world().get("map_profile_id", "")),
				"start_profile": String(state.world().get("start_profile_id", "")),
				"world_profile": String(state.world().get("world_profile_id", "")),
				"map_config": String(state.world().get("map_config_id", "")),
			},
		}],
		"autosave": true,
	}
