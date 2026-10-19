# `framework/application/queries/port_view.gd`

> 作用：主界面 ViewModel：当前港、市场、目的地、船只、委托、策略、情报、通知、统计与通关状态。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `PortViewQuery` | L1 |

## 契约与约束

- 所有数值只读复制；市场行同时给出库存、单价、持有、可售、buyable、持仓均价与价格历史。
- 市场行的 recent_prices 与 trend_percent 只来自真实 price_history；样本不足时 sparkline 不绘制折线。
- 目的地只列当前港的相邻航线，标记未知设施与风险。
- 委托 ViewModel 提供目的港名称键、剩余期限、预计航程、风险和说明键；风险/航程由查询层计算，卡片不调用航行公式。
- 委托区额外暴露 active_limit/active_count/normal_holds（普通委托持有上限）与 main_chain_complete（主线全完成）。
- 船只 ViewModel 的 cargo_cost_basis 与 average_cost 来自 ShipOps 的成本口径；额外暴露 transit_modules/transit_weight。
- 顶层 victory 字段给出 achieved/achieved_at 与 conditions（VictoryService.conditions），供总览目标、通关清单与通关页判断。
- 委托区给出 main_done/main_total（主线完成度），总览据此提示「主线完成后如何通关」。
- 船只 ViewModel 额外给出 free_weight 与 free_cargo_capacity（剩余载重/剩余货舱），顶部信息条直接显示，避免只显示已用载重。
- 船只 ViewModel 给出模块实例摘要 worst_module_condition / damaged_modules / disabled_modules / module_damage_points，顶部信息条据此显示「部件 N · NN%」，健康时不占位。
- stats 来自 GameState.stats()（收入/支出/利润惰性初始化），不返回 ContentDefinition 或 GameState 内部引用。
- `current_port` 额外给出 `archetype_id` 与 `size`（默认 medium），供 2D/2.5D 舞台选择港口构图与设施尺度。
- `ship.hull_model_key` 取船体定义的 `information.model`；`ship.hull_model_path` 经 `context.assets.resolve()`（`_asset_path`）转成物理路径，供 PortStage 直接加载内容模组 GLB；缺资产时为空串。

模块索引：[framework/application](../README.md)
