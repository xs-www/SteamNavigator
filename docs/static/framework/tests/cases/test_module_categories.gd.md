# `framework/tests/cases/test_module_categories.gd`

> 作用：C1 统一模块类型 `modules` 的 category 运行时测试：`ModuleOps` 的查询 / 槽位映射 /

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `STEADY_BUILD` | L17 |
| `STEADY_HULL` | L18 |
| `SPYGLASS` | L19 |
| `CHART_ROOM` | L20 |
| `LIFEBOAT` | L21 |
| `SAFETY_VALVE` | L22 |
| `SMALL_HOLD` | L23 |
| `STANDARD_BOILER` | L24 |
| `PASSENGER_CABIN` | L25 |
| `test_core_modules_expose_categories() -> void` | L66 |
| `test_slot_category_mapping_and_accepts() -> void` | L85 |
| `test_utility_slot_resolution_prefers_tags_then_free_slot() -> void` | L105 |
| `test_required_category_fields_match_the_merged_schema() -> void` | L130 |
| `test_new_run_uses_category_modules_in_flat_slots() -> void` | L146 |
| `test_installing_utility_modules_routes_by_tag_and_drag_slot() -> void` | L163 |
| `test_craft_ops_accepts_hulls_and_merged_modules() -> void` | L208 |
| `test_cross_reference_validator_checks_category_blocks() -> void` | L220 |

utility tag 路由，以及 ship_ops / ship_commands / craft_ops / cross_reference 在真实
Core 内容上的分类行为。

## 契约与约束
- `ModuleOps.category_of` 读取 `data.v2_category`（boiler / cargo / utility / cabin）；
  `SLOT_CATEGORIES` 把扁平 ship 槽位映射到 category，`accepts` 按 category 判定。
- utility 覆盖原导航/安全模块：`module.navigation` → `navigation_module` 槽，
  `module.safety` → `safety_module` 槽；无标签兜底第一个空 utility 槽。
- `ship.install_module` 可用 `slot` 参数指定 utility 拖放目标；boiler / cargo / cabin
  的槽位由 category 固定。`ship` 存档仍保留扁平槽位与 module_instances 形状。
- 合成 fixture 只用 `modules` 定义 + `v2_category`，不依赖旧 1.0 模块类型。

模块索引：[framework/tests](../README.md)
