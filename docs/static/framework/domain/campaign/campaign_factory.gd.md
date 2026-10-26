# `framework/domain/campaign/campaign_factory.gd`

> 作用：战役开局装配（WORLD_SCHEMA_V2_RUNTIME §6.2）。从 `start_profiles` 定义解析

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `CampaignFactory` | L1 |
| `DEFAULT_DIFFICULTY` | L51 |
| `create_campaign(context,, start_profile_id: String,, requested_seed: int = 0,, tutorial: bool = false,, starting_scenario_id: String = "") -> Dictionary` | L61 |
| `create_default_campaign(context,, starting_scenario_id: String = "",, requested_seed: int = 0,, tutorial: bool = false) -> Dictionary` | L237 |
| `default_start_profile(hub: RegistryHub) -> ContentDefinition` | L253 |

世界构成 / 场景调参 / 起始场景（`starting_scenarios`），用 `WorldGenerator.generate_chart`
生成**唯一世界**（海图 = 玩法地图：陆地 + 港口 + **完全图拓扑** + 路径/距离/风险），
`ChartWorldProjection.from_chart` 派生出 `GameState.world()`，再用
Region/Site/Route/Faction/Discovery 装配器把 2.0 世界内容实例化进 `GameState`。
`run.start` 的默认入口（`create_default_campaign`）也走这里，C4 起不再存在 1.0
`RunFactory.create_run` 几何路径；2026-10-26 起不再调用 `MapGenerator` 生成拓扑。

## 契约与约束
- **入口**：
  - `create_campaign(context, start_profile_id, requested_seed=0, tutorial=false,
    starting_scenario_id="")`：显式 start profile；第五参可覆盖起始场景。
  - `create_default_campaign(context, starting_scenario_id="", requested_seed=0,
    tutorial=false)`：`run.start` 无 `start_profile` 时使用，取注册表中 id 最小的
    `start_profiles` 定义（Core 声明的标准起始档案，按 `start.standard` tag 选择）。
- **返回**：`Result.ok({state, rng, start_profile, starting_scenario, world_profile,
  map_config, seed})`；失败使用 `Result.fail(error_code, message_key, data)`。
- **单一世界（海图唯一真相）**：
  `WorldGenerator.generate_chart` 产出的 `world_map` 就是唯一世界与唯一拓扑；
  它同时写入 `state.data["world_map"]`（海图 / 迷雾 / 演出读它）并经
  `ChartWorldProjection.from_chart` 变成 `state.world`（MapOps / 委托 / 航行 / BFS 读它）。
  两者不是两份数据：`routes[].distance ≡ WorldMap.edges[].distance ≡` 绘制路径折线长度。
  **拓扑恒为完全图**（任意两港物理可通航）；可出航性由 `campaign_world.unlocked_route_keys`
  门禁，新局该数组为空（委托 / 剧情 / 酒馆海图在装配过程中解锁各自航线）。
- **状态形状**：
  `data.run = {seed, game_time, started_at, starting_scenario}`；
  `data.campaign.setup = {start_profile_id, world_profile_id, map_config_id,
  starting_scenario_id, difficulty, seed, content_versions}`；
  `state.world` = 海图投影世界 + `start_profile_id / world_profile_id /
  map_config_id / starting_scenario_id`（`map_profiles` 已退役，无 map_profile_id）；
  `data.campaign.world = {profile_id, generated, regions[], sites[],
  visited_region_ids, discovered_site_ids, visited_port_ids, unlocked_route_keys[]}`；
  `data.campaign.codex / factions` 由装配器写入；`data.world_map` 为同一张海图的存档形态。
- **复用而非复制**：飞船用 `RunFactory.create_ship`；市场/补给/贷款参数入口
  `RunFactory.initialize_markets`；迷雾用 `RunFactory._initialize_world_fog`；主线与
  普通委托沿用 `ContractOps` 与 RunFactory 的私有 helper。
  tutorial=true 时最后调用 `StoryService.begin`（StoryService 走 `ContentRefs` 读
  `map_configs.story`）。
- **确定性**（§6.4）：几何 / 拓扑 / 航线风险都来自 `STREAM_MAP_GENERATION` 的命名子流
  （`"chart_world"`、`"route_risk:<pair>"`）；内容装配用 `STREAM_CAMPAIGN_WORLD` 的
  `"regions"/"sites"/"routes"/"factions"/"discoveries"` 子流；注册表结果在抽取前按 id
  排序。同 seed + 同内容 = 同世界实例。
- **D8**：本切片 `port_count` 上限 5（`MapGenerationSpec` clamp + warning），5 块陆地
  各放 1 港；更多港口需要更多陆地/每陆多港，当前不扩张。
- 本类不发领域事件（`run.started` 由 run_start 负责），不写 autosave。

模块索引：[framework/domain](../README.md)
