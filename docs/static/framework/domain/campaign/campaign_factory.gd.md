# `framework/domain/campaign/campaign_factory.gd`

> 作用：v2 战役开局装配（WORLD_SCHEMA_V2_RUNTIME §6.2）。从 `start_profiles` 定义解析

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `CampaignFactory` | L1 |
| `DEFAULT_DIFFICULTY` | L35 |
| `create_campaign(context,, start_profile_id: String,, requested_seed: int = 0,, tutorial: bool = false) -> Dictionary` | L39 |

世界构成 / 场景调参 / 起始构筑，复用 `MapGenerator` 生成抽象海图、`WorldGenerator`
生成孪生坐标世界，再用 Region/Site/Route/Faction/Discovery 装配器把 2.0 世界内容实例化
进 `GameState`。返回与 `RunFactory.create_run` 同形的结果包，供 `run.start` 直接替换状态。

## 契约与约束
- **入口**：`create_campaign(context, start_profile_id, requested_seed=0, tutorial=false)`。
  仅由 `run.start` 显式携带 `start_profile` 时调用；1.0 路径完全不经过本类。
- **返回**：`Result.ok({state, rng, start_profile, world_profile, map_config, seed})`；
  失败使用 `Result.fail(error_code, message_key, data)`，与 RunFactory 同形。
- **状态形状**（§6.3）：
  `data.run = {seed, game_time, started_at, starting_build, map_profile_id:""}`；
  `data.campaign.setup = {start_profile_id, world_profile_id, map_config_id,
  starting_build_id, difficulty, seed, content_versions}`；
  `state.world` = MapGenerator 世界 + `start_profile_id / world_profile_id /
  map_config_id`（`map_profile_id` 显式留空）；
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
