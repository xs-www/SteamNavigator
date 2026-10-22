# `framework/domain/campaign/campaign_factory.gd`

> 作用：战役开局装配（WORLD_SCHEMA_V2_RUNTIME §6.2）。从 `start_profiles` 定义解析

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `CampaignFactory` | L1 |
| `DEFAULT_DIFFICULTY` | L40 |
| `create_campaign(context,, start_profile_id: String,, requested_seed: int = 0,, tutorial: bool = false,, starting_scenario_id: String = "") -> Dictionary` | L47 |
| `create_default_campaign(context,, starting_scenario_id: String = "",, requested_seed: int = 0,, tutorial: bool = false) -> Dictionary` | L217 |
| `default_start_profile(hub: RegistryHub) -> ContentDefinition` | L233 |

世界构成 / 场景调参 / 起始场景（`starting_scenarios`），复用 `MapGenerator` 生成抽象
海图、`WorldGenerator` 生成孪生坐标世界，再用 Region/Site/Route/Faction/Discovery
装配器把 2.0 世界内容实例化进 `GameState`。`run.start` 的默认入口
（`create_default_campaign`）也走这里，C4 起不再存在 1.0 `RunFactory.create_run` 几何路径。

## 契约与约束
- **入口**：
  - `create_campaign(context, start_profile_id, requested_seed=0, tutorial=false,
    starting_scenario_id="")`：显式 start profile；第五参可覆盖起始场景。
  - `create_default_campaign(context, starting_scenario_id="", requested_seed=0,
    tutorial=false)`：`run.start` 无 `start_profile` 时使用，取注册表中 id 最小的
    `start_profiles` 定义（Core 声明的标准起始档案，按 `start.standard` tag 选择）。
- **返回**：`Result.ok({state, rng, start_profile, starting_scenario, world_profile,
  map_config, seed})`；失败使用 `Result.fail(error_code, message_key, data)`。
- **状态形状**：
  `data.run = {seed, game_time, started_at, starting_scenario}`；
  `data.campaign.setup = {start_profile_id, world_profile_id, map_config_id,
  starting_scenario_id, difficulty, seed, content_versions}`；
  `state.world` = MapGenerator 世界 + `start_profile_id / world_profile_id /
  map_config_id / starting_scenario_id`（`map_profiles` 已退役，无 map_profile_id）；
  `data.campaign.world = {profile_id, generated, regions[], sites[],
  visited_region_ids, discovered_site_ids, visited_port_ids}`；
  `data.campaign.codex / factions` 由装配器写入；`data.world_map` 为孪生海图世界。
- **复用而非复制**：飞船用 `RunFactory.create_ship`；市场/补给/贷款参数入口
  `RunFactory.initialize_markets`；孪生世界与迷雾用 `RunFactory._coordinate_world_profile`
  / `_initialize_world_fog`；主线与普通委托沿用 `ContractOps` 与 RunFactory 的私有 helper。
  tutorial=true 时最后调用 `StoryService.begin`（StoryService 走 `ContentRefs` 读
  `map_configs.story`）。
- **确定性**（§6.4）：几何用 `STREAM_MAP_GENERATION`；新增内容全部用
  `STREAM_CAMPAIGN_WORLD` 的 `"regions"/"sites"/"routes"/"factions"/"discoveries"`
  子流；注册表结果在抽取前按 id 排序。同 seed + 同内容 = 同世界实例。
- **D8**：本切片 `port_count` 上限 5（`MapGenerationSpec` clamp + warning）。
- 本类不发领域事件（`run.started` 由 run_start 负责），不写 autosave。

模块索引：[framework/domain](../README.md)
