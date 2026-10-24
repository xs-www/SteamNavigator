# `framework/application/queries/market_view.gd`

> 作用：市场页聚合 ViewModel：复用 `port.view` 的行情行，补充「船舱货物 / 当前港仓库材料」与图标资产键，供「左侧船只背包 + 右侧市场」的图标直接交互页使用。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MarketViewQuery` | L1 |
| `execute(params: Dictionary, context) -> Dictionary` | L18 |

- 关键依赖：`PortViewQuery`（行情 / 船摘要 / 港信息）、`IntelViewQuery`（价格趋势）、`ShipOps`、`WarehouseOps`、`ContentDefinition.information["texture"]`。
- 写作用域：只读；不修改 GameState，不解析纹理（纹理由 Shell 用 `AssetService` 解析）。

## 契约与约束
- 输出字段以 `docs/design/MARKET_UI_REFACTOR.md` §3 为准；`market` 行继承 `port.view` 的全部字段，只追加 `icon_key`。
- `ship.hold` 按 `item_id + 是否委托货` 聚合：普通货一行（`sellable_amount` = 该品种非委托数量），委托货一行且 `is_contract=true`、`sellable_amount=0`。
- `warehouse.materials` 只列当前港仓库材料区；排序按 item_id 保证确定性。
- `trends` 沿用 Shell 旧 `_market_trends()` 的语义：当前港情报报告里的价格趋势；无报告时为空字典。
- 未开局（`has_run=false`）时仍返回完整空结构，页面无需做键存在性判断。

模块索引：[framework/application](../README.md)
