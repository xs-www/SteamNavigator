# `framework/application/commands/run_start.gd`

> 作用：`run.start` 命令入口（Phase B B3）。保持 1.0 路径原样：无 `start_profile`

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `RunStartCommand` | L1 |
| `execute(params: Dictionary, context) -> Dictionary` | L26 |

时调用 `RunFactory.create_run`（旧构筑 + map profile）；显式传完整
`start_profile` id 时改走 v2 `CampaignFactory.create_campaign`（世界装配 +
campaign.setup）。成功后替换 `AppContext` 的 state / rng，发 `run.started` 事件并
请求自动存档。

- 关键依赖：`RunFactory.create_run`、`CampaignFactory.create_campaign`、
  `GameState.world()` 的 `start_profile_id / world_profile_id / map_config_id /
  map_profile_id`、`Result`

## 契约与约束
- 参数：`build_id`（1.0 构筑，保留）、`start_profile`（完整 ID，v2）、`seed`、
  `tutorial`、`force`。`start_profile` 为空 → 1.0 路径行为零变化。
- 两条路径的工厂返回同形 `{ok,error_code,message_key,data:{state,rng,...},events}`；
  主线委托 / 普通委托 / notice / tutorial 的 `StoryService.begin` 由各自工厂负责，
  本命令只做提交与事件。
- `run.started` payload 增加 `start_profile / world_profile / map_config`；1.0 路径
  三者均为空串（`map_profile` 仍为 1.0 profile id）。
- 事件里的 id 一律从已提交的 `state.world` 读取，避免与工厂返回值两套真源。

模块索引：[framework/application](../README.md)
