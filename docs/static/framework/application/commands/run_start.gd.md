# `framework/application/commands/run_start.gd`

> 作用：`run.start` 命令入口（C4 起所有开局统一走 CampaignFactory）。无

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `RunStartCommand` | L1 |
| `execute(params: Dictionary, context) -> Dictionary` | L25 |

`start_profile` 时调用 `CampaignFactory.create_default_campaign`（默认 start
profile + `starting_scenarios` 选择）；显式 `start_profile` 时走
`CampaignFactory.create_campaign`。成功后替换 `AppContext` 的 state / rng，发
`run.started` 事件并请求自动存档。

- 关键依赖：`CampaignFactory.create_campaign` / `create_default_campaign`、
  `GameState.world()` 的 `start_profile_id / world_profile_id / map_config_id /
  starting_scenario_id`、`Result`

## 契约与约束
- 参数：`starting_scenario`（完整 ID，可空 = core start profile 默认场景）、
  `start_profile`（完整 ID，可空 = 默认 start profile）、`seed`、`tutorial`、`force`。
  C4 起不再有 `build_id` / `map_profiles`。
- 主线委托 / 普通委托 / notice / tutorial 的 `StoryService.begin` 由工厂负责，
  本命令只做提交与事件。
- `run.started` payload：`starting_scenario / start_profile / world_profile /
  map_config`；id 一律从已提交的 `state.world` 读取，避免与工厂返回值两套真源。

模块索引：[framework/application](../README.md)
