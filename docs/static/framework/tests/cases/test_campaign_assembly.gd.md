# `framework/tests/cases/test_campaign_assembly.gd`

> 作用：Phase B B3-A 战役世界装配测试（WORLD_SCHEMA_V2_RUNTIME §6.2/§6.3/§6.4）：用

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `START_PROFILE_ID` | L23 |
| `START_PROFILE_NO_MAP_CONFIG` | L24 |
| `START_PROFILE_MISSING_WORLD` | L25 |
| `START_PROFILE_MISSING_MAP_CONFIG` | L26 |
| `START_PROFILE_MISSING_BUILD` | L27 |
| `WORLD_PROFILE_ID` | L28 |
| `MAP_CONFIG_ID` | L29 |
| `STARTING_BUILD_ID` | L30 |
| `SITES_PER_REGION` | L31 |
| `REGION_COUNT` | L32 |
| `FACTION_COUNT` | L33 |
| `PORT_COUNT` | L34 |
| `build_synthetic_context() -> AppContext` | L41 |
| `synthetic_hub(baseline: RegistryHub = null) -> RegistryHub` | L51 |
| `synthetic_start_profile_id() -> String` | L66 |
| `synthetic_map_config_id() -> String` | L70 |
| `synthetic_world_profile_id() -> String` | L74 |
| `test_create_campaign_returns_full_state_shape() -> void` | L351 |
| `test_same_seed_is_fully_deterministic() -> void` | L423 |
| `test_different_seed_changes_the_generated_world() -> void` | L431 |
| `test_region_site_and_route_references_are_consistent() -> void` | L440 |
| `test_missing_map_config_falls_back_to_available_map_config() -> void` | L513 |
| `test_missing_start_profile_returns_structured_error() -> void` | L522 |
| `test_missing_world_profile_returns_structured_error() -> void` | L535 |
| `test_missing_map_config_or_build_reference_returns_structured_error() -> void` | L542 |
| `test_tutorial_branch_initializes_story_state() -> void` | L552 |
| `test_faction_reputation_and_attitude_are_derived_from_content() -> void` | L563 |

`bootstrap_core()` 的 1.0 基线 + 合成 2.0 定义驱动 `CampaignFactory.create_campaign`，
覆盖完整 state 形状、同 seed 确定性、不同 seed 差异、区域/地点/航路一致性、
map_config 缺省回退与 start_profile / world_profile / map_config / starting_build
缺失的结构化错误、教程分支 StoryService.begin、阵营声望与态度派生。

## 契约与约束
- **不依赖 B4 core v2 内容**：合成 hub 只抄 1.0 类型定义，再注册 `test:*` 的
  world_profile / map_config / region / site / route_template / faction / discovery /
  start_profile；`core:map_config/standard` 从不出现在断言里。
- **fixture 复用**：`build_synthetic_context()` / `synthetic_hub()` /
  `synthetic_start_profile_id()` 是非 test_ 前缀的 public 方法，B3-B 的
  `test_campaign_start.gd` 可直接 `preload(...).new()` 复用，避免两套 fixture 漂移。
- **确定性断言不比较时间戳**：`run.started_at` / `campaign.created_at` 是唯一非确定
  字段，指纹里剔除；其余（world / campaign / market / npcs / contracts / world_map）
  必须逐层相等。
- 断言世界实例的**引用完整性**（region→port、site→region、route→template）而不是
  固定随机结果，避免内容权重微调就把测试写死。

模块索引：[framework/tests](../README.md)
