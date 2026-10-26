# `framework/domain/contracts/run_factory.gd`

> 作用：开局装配的共享 helper（C4 起不再持有 1.0 `map_profiles` 几何路径）。提供

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `RunFactory` | L1 |
| `available_scenarios(hub: RegistryHub) -> Array[ContentDefinition]` | L25 |
| `default_starting_scenario(hub: RegistryHub) -> ContentDefinition` | L30 |
| `starting_scenario_summaries(hub: RegistryHub) -> Array[Dictionary]` | L41 |
| `create_ship(hub: RegistryHub, scenario: ContentDefinition) -> Dictionary` | L57 |
| `initialize_markets(state: GameState, hub: RegistryHub, _scenario: ContentDefinition, rng: RngService) -> void` | L104 |

`starting_scenarios` 读取与摘要、飞船构造（`create_ship`）、市场初始化
（`initialize_markets`）以及战役工厂复用的迷雾 / 主线委托 / 种子 helper。

## 契约与约束
- **入口**：`run.start` 无 `start_profile` 时统一走
  `CampaignFactory.create_default_campaign()`（默认 start profile +
  `starting_scenarios` 选择）；本类不再提供 `create_run()`。
- **世界生成已迁出本类**（2026-10-26 海图唯一真相）：坐标布局在
  `CampaignFactory._chart_world_profile`，唯一世界由 `WorldGenerator.generate_chart`
  生成；本类只保留 `_initialize_world_fog()`（迷雾比例来自
  `ExplorationRules.fog_radii()`）。
- 框架永不写死具体 `core:*` 内容 ID：场景 / 世界 / 地图调参全部按注册表类型解析。
- `create_ship(hub, scenario)` 的字段名保持扁平槽位（hull / boiler / cargo_modules /
  navigation_module / safety_module / passenger_cabin / engineer / navigator）。
- 本类不使用 RNG 之外的外部状态；`_random_seed()` 只供 CampaignFactory 在
  `seed == 0` 时使用。

模块索引：[framework/domain](../README.md)
