# `framework/tests/cases/test_item_categories.gd`

> 作用：Phase C C2（goods + materials → `items` 2.0）的运行时合并回归：类型表 /

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MANIFEST_PATH` | L19 |
| `test_items_is_the_single_active_2_0_type() -> void` | L34 |
| `test_core_items_resolve_materials_by_flag() -> void` | L50 |
| `test_market_covers_every_item_kind() -> void` | L69 |
| `test_item_views_expose_category_fields() -> void` | L95 |
| `test_goods_clues_skip_crafting_only_materials() -> void` | L141 |

Schema 版本、Core 12 条 item 定义、市场条目覆盖（含前 materials 的买/卖语义）、
crafting_material 判定、港口 / 船厂 / 打造 ViewModel 的 category 分类字段，以及
货物线索只命中普通贸易货物（`good.trade`）而不是材料。

- 关键依赖：`bootstrap_core()`、`ContentTypes.ITEM`、`ShipOps.item_definition` /
  `is_crafting_material`、`MarketOps.initialize_port_market`、`PortViewQuery`、
  `ShipyardViewQuery`、`CraftOps.material_plan`、`ClueService.goods_candidates`

## 契约与约束
- 不引用已删除的 `ContentTypes.GOOD` / `ContentTypes.MATERIAL`；材料判定只用
  `data.crafting_material`（旧 goods 里可打造的三条也为 true），不再有内容类型分割。
- 市场语义保持：所有 item 都有卖入口；港口 assortments 里的可买；煤/水走补给条目。
- UI 分类只读 `category` / `crafting_material` / `tier` 字段，不做类型分支。

模块索引：[framework/tests](../README.md)
