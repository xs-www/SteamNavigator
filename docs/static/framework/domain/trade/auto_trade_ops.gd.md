# `framework/domain/trade/auto_trade_ops.gd`

> 作用：Phase D4 自动贸易的纯结构/计算层：规范化 `data.trade`、读取贸易策略与

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `AutoTradeOps` | L1 |
| `TRADE_KEY` | L21 |
| `PHASES` | L22 |
| `DEFAULT_TRADE` | L23 |
| `LOG_LIMIT` | L39 |
| `has_auto_trade(state: GameState) -> bool` | L42 |
| `ensure_structure(state: GameState) -> Dictionary` | L50 |
| `policy_definition(hub: RegistryHub, policy_id: String) -> ContentDefinition` | L61 |
| `rule_definition(hub: RegistryHub, rule_id: String) -> ContentDefinition` | L67 |
| `policy_rules(hub: RegistryHub, policy: ContentDefinition) -> Array` | L74 |
| `condition_met(state: GameState, hub: RegistryHub, trade: Dictionary, policy: ContentDefinition, rule: ContentDefinition) -> bool` | L92 |
| `apply_rule_action(state: GameState, hub: RegistryHub, trade: Dictionary, rule: ContentDefinition, tick: int) -> void` | L116 |
| `cargo_units(trade: Dictionary) -> int` | L140 |
| `cargo_view(hub: RegistryHub, trade: Dictionary) -> Array` | L147 |
| `choose_target(state: GameState, hub: RegistryHub, policy: ContentDefinition, home_port_id: String) -> Dictionary` | L166 |
| `buy_and_depart(state: GameState, hub: RegistryHub, trade: Dictionary, tick: int, policy: ContentDefinition) -> bool` | L211 |
| `sell_cargo(state: GameState, hub: RegistryHub, trade: Dictionary, tick: int) -> bool` | L215 |
| `evaluate_rules(state: GameState, hub: RegistryHub, trade: Dictionary, tick: int, when: String = "tick") -> bool` | L223 |
| `view(state: GameState, hub: RegistryHub = null) -> Dictionary` | L243 |

自动化规则、挑选买卖港口与商品、维护自动货舱、直接按港口市场价结算买卖，并给出
只读 `auto_trade.view` 数据。

## 契约与约束
- `data.trade` 只在 `auto_trade.start` 后存在：`{active, policy_id, phase,
  paused, home_port_id, target_port_id, at_port_id, travel_remaining,
  cargo{item:qty}, legs, spent, earned, profit, log[]}`。
- phase：`idle`（在母港等待）/ `outbound`（前往目标港）/ `returning`（返航）。
- 只在已发现港口之间自动贸易；目标港按策略的 `sell_port_tags` / `buy_port_tags`
  过滤，按“售价 - 买价”的利润率挑最高且 ≥ `min_margin` 的组合。
- 自动货舱按 `max_cargo` 计件，不使用玩家船货舱；买卖直接改对应港口市场库存与
  价格（`MarketOps.compute_price/recalc`），金额计入收入/支出统计。
- 风险只在抵达目标港时掷一次；随机种子由 policy_id + tick 派生，保证同 tick 可复现。
- 损坏数据一律规范化，`view()` 不写状态且不抛引擎错误。

模块索引：[framework/domain](../README.md)
