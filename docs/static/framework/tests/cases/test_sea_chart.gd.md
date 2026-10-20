# `framework/tests/cases/test_sea_chart.gd`

> 作用：海图系统（阶段 2）的无头测试，验证 `sea_chart.view` 查询的输出结构、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `TestSeaChart` | L2 |
| `SEED_A` | L15 |
| `SEED_B` | L16 |
| `SEA_CHART_SCREEN_SCRIPT` | L20 |
| `TEST_PROFILE` | L21 |
| `test_sea_chart_query_returns_valid_structure() -> void` | L73 |
| `test_sea_chart_query_world_bounds_match() -> void` | L95 |
| `test_sea_chart_query_includes_all_landmasses() -> void` | L111 |
| `test_sea_chart_query_current_port_marked() -> void` | L133 |
| `test_sea_chart_query_routes_between_discovered_ports() -> void` | L156 |
| `test_sea_chart_routes_carry_voyage_estimates() -> void` | L186 |
| `test_sea_chart_panel_renders_voyage_estimates() -> void` | L271 |
| `test_sea_chart_query_fog_grid_downsampled() -> void` | L370 |
| `test_sea_chart_reads_precomputed_routes() -> void` | L406 |
| `test_legacy_world_without_route_table_still_renders() -> void` | L450 |
| `test_sea_chart_query_port_positions_within_bounds() -> void` | L468 |
| `test_sea_chart_query_no_run_returns_empty() -> void` | L486 |
| `test_sea_chart_query_serialization_roundtrip() -> void` | L497 |
| `test_sea_chart_query_reproducible() -> void` | L518 |
| `test_sea_chart_query_different_seeds_differ() -> void` | L540 |
| `test_sea_chart_query_discovered_port_count() -> void` | L567 |
| `test_sea_chart_query_archetype_names_valid() -> void` | L583 |
| `test_port_view_model_carries_display_name_keys() -> void` | L636 |
| `test_departure_tick_direction_uses_radians() -> void` | L663 |
| `test_center_on_port_before_layout_is_queued() -> void` | L680 |
| `test_sea_chart_screen_binds_chart_and_panel() -> void` | L714 |

陆地/港口/航线/迷雾数据正确性，以及同 seed 可复现性与 JSON 序列化往返。

## 契约与约束
- 每个用例通过 `bootstrap_core()` 获得真实 Core 注册表，再用内联 `TEST_PROFILE`
  生成世界；测试不实例化任何 UI 节点，只断言查询输出的纯数据。
- `_setup_world_and_state()` 把起始港与其首个邻居标为已发现/已访问，
  使航线用例具备两端可见的前提。
- 港口坐标断言使用宽松范围：大陆可能跨出 `world.bounds`，港口锚定在海岸线上。

模块索引：[framework/tests](../README.md)
