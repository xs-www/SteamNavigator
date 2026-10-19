# `framework/domain/economy/market_ops.gd`

> 作用：市场价格、买卖、补给商品与维修结算；煤/水价格随港口库存浮动。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MarketOps` | L1 |

## 契约与约束

- 本地品种价格 = base_price × bias × (base_stock / stock)^elasticity，限制在 0.55–2.2。
- 非本地品种以 `buyable=false` 进入市场：只收购、不卖给你；价格按 base_price × 0.9 × 库存折减。
- 煤/水以 `is_supply=true` 的补给商品进入每个港口市场，初始库存 90–180，价格与普通商品同一供需公式。
- 买入检查 buyable、货币、库存、总重量与货舱容量；卖出允许所有非合同货物；补给商品只能走补给码头。
- 玩家买卖只把价格向新均衡推进 `player_trade_impact`（默认 0.35）；NPC 交易仍完整重算。
- 每个可买入市场条目维护最多 8 个真实价格样本 `price_history`；非本地收购项不写历史，避免伪造趋势。
- 买入把成交总额写入 cargo stack 的 total_cost，卖出按数量比例扣减成本。
- 补给只检查设施、库存、重量与货币；维修费用乘安全设备/工程师的 repair_cost 修正。
- 维修报价 = (船体缺失点数 + `ShipOps.module_damage_points()` 部件损耗点数) × repair_per_point × repair_cost_mul；`repair()` 同时把船体耐久与所有模块实例恢复到满状态，返回 modules_repaired。
- 成功的买入/补给/维修调用 `state.record_expense()`，卖出调用 `record_income()`，形成通关总结的收入/支出/利润口径。
- `ensure_sell_only_entries()` 为旧存档补齐非本地收购项与补给商品。

## 重点逻辑

### `buy(state, hub, port_id, item_id, amount, trade_margin, price_impact)`

- 所有前置条件通过后才扣款、减库存、按 price_impact 平滑重算价格、写入 cargo stack 和成本。
- 失败返回带 message_key 的 Result；命令总线因此不会提交工作副本。

### `buy_supply(state, hub, port_id, kind, amount, price_impact)`

- 按 `supply_entry_for()` 找到煤/水市场条目，使用当前价格和库存；购买后按玩家冲击平滑更新价格。

### `compute_price(entry)`

- buyable=true 走本地市场供需公式；buyable=false 使用单向收购价，库存越多价格越低。

### `repair_cost(hub, state, repair_per_point)`

- 返回缺失耐久、费用、耐久上限与维修修正；supply.view 和 supply.repair 共用。

模块索引：[framework/domain](../README.md)
