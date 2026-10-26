# `framework/tests/cases/test_route_unlock.gd`

> 作用：锁定「任意两港可通航 + 航线需要解锁」的运行时契约（2026-10-26）。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `TestRouteUnlock` | L2 |
| `STEADY_SCENARIO` | L26 |
| `STANDARD_STRATEGY` | L27 |
| `SEED` | L28 |
| `test_route_keys_are_canonical_and_a_new_state_has_none() -> void` | L33 |
| `test_new_run_unlocks_only_the_routes_its_contracts_carry() -> void` | L44 |
| `test_normal_offer_refresh_unlocks_each_generated_route() -> void` | L73 |
| `test_tutorial_opening_unlocks_the_main_route() -> void` | L97 |
| `test_story_unlock_route_effect_resolves_semantic_tokens() -> void` | L110 |
| `test_chart_buy_unlocks_the_route_charges_gold_and_survives_save_load() -> void` | L156 |
| `test_chart_buy_fails_cleanly_in_every_invalid_case() -> void` | L203 |
| `test_tavern_view_offers_charts_for_discovered_harbours() -> void` | L252 |
| `test_route_locked_blocks_preview_start_and_clue_travel() -> void` | L293 |
| `test_queries_expose_the_unlock_state_and_filter_locked_routes() -> void` | L344 |
| `test_chart_panel_disables_sailing_for_a_locked_route() -> void` | L380 |
| `test_tavern_screen_renders_chart_offers_and_emits_chart_buy() -> void` | L413 |

## 契约与约束
- **物理连通 = 完全图**：`generate_chart` 为每对港口生成航线；发现港口不解锁航线。
- **运行时解锁名册**：`state.campaign_world().unlocked_route_keys` 存规范无向 pair key
  （`a|b` 排序）；`WorldOps.route_key / is_route_unlocked / unlock_route /
  unlocked_neighbor_ids` 是唯一读写入口。新 `GameState` 的该数组为空。
- **三种解锁来源**：①委托自带海图（`ContractOps.generate_offer` 主线 / 普通都解锁
  origin↔destination，`StoryService._grant_tutorial_contract` 按最终目的地解锁）；
  ②剧情效果 `unlock_route {from, to}`（`current` / `home` / `contract_destination` /
  具体港口 id）；③酒馆 `chart.buy {port_id}`（当前港有酒馆、目标已发现、非当前港、
  未解锁、金币够；扣 Core `map_config.chart_cost`，发 `chart.purchased`）。
- **航行门禁**：未解锁航线 `voyage.preview` / `voyage.start` / `clue.travel` 返回
  `route_locked` + `ui.error.route_locked`；`explore.start` 不受限（由
  `test_exploration` 锁定探索路径）。
- **查询 / UI**：`sea_chart.view` 每条 route 带 `unlocked`；`map.view` 与
  `port.view.destinations` 只列已解锁航线；海图面板未解锁时禁用启航并显示
  「未测绘航线：在酒馆购买海图解锁」；酒馆页按 `tavern.view.chart_offers` 售卖海图。
- 测试只通过公开命令 / 查询与领域 API 驱动；测试夹具会把「脚本直接开船」需要的航线
  标记为解锁（等价于委托自带海图），但不绕过被测命令本身的门禁。

模块索引：[framework/tests](../README.md)
