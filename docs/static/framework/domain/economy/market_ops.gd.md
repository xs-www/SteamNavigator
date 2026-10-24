# `framework/domain/economy/market_ops.gd`

> 作用：市场价格、买卖（可落船货舱或当前港仓库）、补给商品与维修结算；煤/水价格随港口库存浮动。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MarketOps` | L1 |
| `DEFAULT_TRADE_MARGIN` | L20 |
| `MIN_PRICE_FACTOR` | L21 |
| `MAX_PRICE_FACTOR` | L22 |
| `SELL_ONLY_PRICE_FACTOR` | L23 |
| `DEFAULT_PLAYER_PRICE_IMPACT` | L24 |
| `PRICE_HISTORY_LIMIT` | L25 |
| `create_market_entry(item_definition: ContentDefinition, stock: int, price_bias: float = 1.0) -> Dictionary` | L28 |
| `compute_price(entry: Dictionary) -> float` | L47 |
| `recalc(entry: Dictionary) -> void` | L63 |
| `market_for(state: GameState, port_id: String) -> Dictionary` | L87 |
| `entry_for(state: GameState, port_id: String, item_id: String) -> Dictionary` | L91 |
| `initialize_port_market(hub: RegistryHub, archetype: ContentDefinition, rng: RandomNumberGenerator) -> Dictionary` | L95 |
| `supply_kind_for(definition: ContentDefinition) -> String` | L137 |
| `supply_entry_for(state: GameState, port_id: String, kind: String) -> Dictionary` | L145 |
| `ensure_sell_only_entries(hub: RegistryHub, state: GameState) -> void` | L153 |
| `buy(state: GameState, hub: RegistryHub, port_id: String, item_id: String, amount: int, trade_margin: float = DEFAULT_TRADE_MARGIN, price_impact: float = DEFAULT_PLAYER_PRICE_IMPACT, destination: String = "cargo") -> Dictionary` | L177 |
| `sell(state: GameState, hub: RegistryHub, port_id: String, item_id: String, amount: int, trade_margin: float = DEFAULT_TRADE_MARGIN, price_impact: float = DEFAULT_PLAYER_PRICE_IMPACT, source: String = "cargo") -> Dictionary` | L232 |
| `buy_supply(state: GameState, hub: RegistryHub, port_id: String, kind: String, amount: int, price_impact: float = DEFAULT_PLAYER_PRICE_IMPACT) -> Dictionary` | L276 |
| `repair_cost(hub: RegistryHub, state: GameState, repair_per_point: float) -> Dictionary` | L316 |
| `repair(state: GameState, hub: RegistryHub, port_id: String, repair_per_point: float) -> Dictionary` | L334 |
| `total_market_value(state: GameState) -> float` | L361 |

## 契约与约束
- 本地品种价格 = base_price × bias × (base_stock / stock)^elasticity，限制在 0.55–2.2；非本地品种以 `buyable=false` 只收购。
- `buy()` 默认 `destination="cargo"`：校验可买、货币、库存、总重量与货舱容量，写 `cargo` stack 的 total_cost。
- `buy(destination="warehouse")`：可买/货币/库存校验同上，但跳过重量与货舱校验，改写当前港仓库材料区（`WarehouseOps.add_material`）。
- `sell()` 默认 `source="cargo"`：允许所有非合同货物；`sell(source="warehouse")` 从当前港仓库材料区扣减，船舱不变。
- 非法 `destination` / `source` 在扣款或任何状态变更之前返回 `invalid_destination` / `invalid_trade_source`。
- 玩家买卖只把价格向新均衡推进 `player_trade_impact`（默认 0.35）；每个可买入条目维护最多 8 个真实价格样本。
- 成功的买入/补给/维修调用 `state.record_expense()`，卖出调用 `record_income()`；失败返回带 message_key 的 Result，命令总线因此不提交工作副本。

## 重点逻辑
### `buy(...)` / `sell(...)`
- 所有前置条件通过后才扣款/入账、减/加港存、按 price_impact 平滑重算价格，最后写入货舱或仓库；返回 data 携带实际 `destination` / `source`。

模块索引：[framework/domain](../README.md)
