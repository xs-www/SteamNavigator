# `framework/tests/cases/test_sea_chart.gd`

> 作用：海图系统的无头测试——阶段 2 验证 `sea_chart.view` 的输出结构与陆地/港口/

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `TestSeaChart` | L2 |
| `SEED_A` | L20 |
| `SEED_B` | L21 |
| `SEA_CHART_SCREEN_SCRIPT` | L25 |
| `CLUE_LOG_SCREEN_SCRIPT` | L26 |
| `TEST_PROFILE` | L27 |
| `test_sea_chart_query_returns_valid_structure() -> void` | L79 |
| `test_sea_chart_query_world_bounds_match() -> void` | L101 |
| `test_sea_chart_query_includes_all_landmasses() -> void` | L117 |
| `test_sea_chart_query_current_port_marked() -> void` | L139 |
| `test_sea_chart_query_routes_between_discovered_ports() -> void` | L162 |
| `test_sea_chart_routes_carry_voyage_estimates() -> void` | L192 |
| `test_sea_chart_panel_renders_voyage_estimates() -> void` | L277 |
| `test_sea_chart_query_fog_grid_downsampled() -> void` | L376 |
| `test_sea_chart_reads_precomputed_routes() -> void` | L412 |
| `test_legacy_world_without_route_table_still_renders() -> void` | L456 |
| `test_sea_chart_query_port_positions_within_bounds() -> void` | L474 |
| `test_sea_chart_query_no_run_returns_empty() -> void` | L492 |
| `test_sea_chart_query_serialization_roundtrip() -> void` | L503 |
| `test_sea_chart_query_reproducible() -> void` | L524 |
| `test_sea_chart_query_different_seeds_differ() -> void` | L546 |
| `test_sea_chart_query_discovered_port_count() -> void` | L573 |
| `test_sea_chart_query_archetype_names_valid() -> void` | L589 |
| `test_port_view_model_carries_display_name_keys() -> void` | L642 |
| `test_departure_tick_direction_uses_radians() -> void` | L669 |
| `test_center_on_port_before_layout_is_queued() -> void` | L686 |
| `test_presentation_framing_fills_the_window_and_keeps_the_route_visible() -> void` | L718 |
| `test_presentation_framing_gives_way_to_a_long_route() -> void` | L755 |
| `test_presentation_framing_ignores_the_manual_zoom_cap() -> void` | L778 |
| `test_ship_icon_points_along_its_heading() -> void` | L805 |
| `test_sea_chart_screen_binds_chart_and_panel() -> void` | L851 |
| `test_sea_chart_screen_renders_the_departure_confirm_dialog() -> void` | L904 |
| `test_routes_are_only_visible_for_the_selected_port() -> void` | L994 |
| `CLUE_VM` | L1027 |
| `test_clue_geometry_helpers_and_hit_test() -> void` | L1072 |
| `test_clue_compass_key_conversion() -> void` | L1108 |
| `test_clue_view_geometry_and_selection() -> void` | L1119 |
| `test_clue_name_text_localizes_and_falls_back() -> void` | L1172 |
| `test_unknown_destination_roundtrip() -> void` | L1189 |
| `test_unknown_destination_marker_is_clamped_below_the_hud() -> void` | L1207 |
| `test_sea_chart_panel_renders_clue_section() -> void` | L1229 |
| `test_sea_chart_screen_binds_clue_panel_and_forwards_signals() -> void` | L1323 |
| `test_sea_chart_panel_investigation_button_and_screen_forwarding() -> void` | L1368 |
| `test_route_distance_labels_follow_any_visible_route() -> void` | L1484 |
| `test_ghost_button_hover_does_not_change_layout_margins() -> void` | L1504 |
| `test_sea_chart_panel_renders_goods_lead_and_offers_travel() -> void` | L1527 |
| `test_goods_clue_has_no_chart_geometry() -> void` | L1612 |
| `test_sea_chart_header_opens_clue_list_and_preselects_a_clue() -> void` | L1631 |
| `test_clue_log_screen_lists_active_and_expired_leads() -> void` | L1660 |

航线/迷雾数据；阶段 4.1 追加线索可视化（视图几何、点击命中、面板线索区块、
未知终点）和整页信号转发；阶段 4.4 追加货物行情线索面板（类型 / 港口 / 分级行情 /
时效 /「前往该港」）与「货物线索不画海图几何」。

## 契约与约束
- 每个用例通过 `bootstrap_core()` 获得真实 Core 注册表，再用内联 `TEST_PROFILE`
  生成世界；纯几何/组件用例直接构造视图模型或面板，不渲染、不驱动帧。
- `_setup_world_and_state()` 把起始港与其首个邻居标为已发现/已访问，
  使航线用例具备两端可见的前提。
- 线索用例用 `CLUE_VM`（含 level 2/3/4 线索与缺失参照港）断言：几何换算是
  纯静态函数（`clue_arrow_endpoint` / `clue_circle_screen` / `clue_hit_test`），
  面板/整页只验证接线与文案，不依赖真实对局。
- 港口坐标断言使用宽松范围：大陆可能跨出 `world.bounds`，港口锚定在海岸线上。

模块索引：[framework/tests](../README.md)
