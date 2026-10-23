# 自动贸易系统（Auto Trade System，Phase D4）

> 状态：Draft 1（2026-10-23，D4 运行时 + 最小 UI 落地）。内容契约以
> [schemas/v2/](../../schemas/v2/) 与 [dev_mods/core/content/](../../dev_mods/core/content/) 为准。

## 1. 范围

D4 交付可观察的自动贸易纵向切片：

- `trade_policies` 定义商品、买卖港口标签、预算/储备金、自动货舱、航程、风险与规则；
- `automation_rules` 按优先级评估条件（金钱 / 载货 / 利润率 / 风险）并执行暂停、恢复、
  立即买卖；
- tick 中自动选择已发现港口、买入、航行、抵达时掷风险、卖出并返航；
- 玩家金钱、港口市场库存与价格真实变化，利润计入统计；
- 最小自动贸易页（策略启动/停止/暂停/恢复、货舱、利润与日志）。

不在本切片：多船/多航线并行、跨区域低细节模拟、玩家船实际航行演出、贸易船被劫战斗。

## 2. 内容类型（2 类 active 2.0，capability `content.trade.v1`）

| 类型 | 关键字段 | Core 内容 |
| --- | --- | --- |
| `trade_policies` | `goods` / `buy_port_tags` / `sell_port_tags` / `budget` / `reserve_money` / `max_cargo` / `travel_hours` / `risk` / `min_margin` / `rules` | 大宗航线、奢侈品快线 |
| `automation_rules` | `policy_ref` / `when` / `condition{op,value}` / `action` / `priority` | 5 条暂停/恢复/满载规则 |

`condition.op`：`always` / `money_gte` / `money_lte` / `cargo_gte` / `cargo_lte` /
`margin_gte` / `risk_gte`；`action`：`pause` / `resume` / `sell_now` / `buy_now`。

`when` 决定规则触发阶段：`tick` 在每 tick 开始评估，`departure` 在买入后评估，
`arrival` 在抵达目标港后、风险与卖出前评估（因此满载 `sell_now` 规则可在到港时生效）。

## 3. 运行态 `data.trade`

```json
{
  "active": true,
  "policy_id": "core:trade_policy/bulk_lane",
  "phase": "outbound",
  "paused": false,
  "home_port_id": "port_0",
  "target_port_id": "port_1",
  "at_port_id": "port_0",
  "travel_remaining": 5.0,
  "cargo": {"core:item/timber": 21},
  "legs": 1,
  "spent": 766,
  "earned": 0,
  "profit": 0,
  "log": [{"tick": 3, "event": "bought", "item_id": "core:item/timber", "amount": 21, "money": 766}]
}
```

- 只在 `auto_trade.start` 后存在；`auto_trade.view` 只读规范化。
- phase：`idle` / `outbound` / `returning`；`paused` 与 phase 正交。
- 母港 = 启动时所在港；目标港来自已发现港口中满足 `sell_port_tags` 且利润率最高的组合。
- 自动货舱按 `max_cargo` 计件，不影响玩家船货舱。

## 4. Tick 行为

`AutoTradeSystem`（id `auto_trade`，priority 110）：

1. 按 priority 评估策略规则；`pause` 后本 tick 不再推进；
2. `idle`：选目标港与商品，按预算/储备/货舱/库存买入，进入 `outbound`；
3. `outbound`：每 tick 递减航程；抵达时按 `risk` 掷确定性风险（损失一半货舱），
   然后按目标港市场价卖出全部货物，进入 `returning`；
4. `returning`：抵达母港回到 `idle`，下一 tick 重新评估路线。

风险随机种子 = `hash(policy_id + tick)`，同 tick 可复现。

## 5. 命令与查询

| 命令 | 说明 |
| --- | --- |
| `auto_trade.start {policy_id}` | 在港启动；母港 = 当前港；唯一运行实例 |
| `auto_trade.stop` | 清空运行态与自动货舱 |
| `auto_trade.set_policy {policy_id}` | 空闲且无货时切换策略 |
| `auto_trade.pause` / `auto_trade.resume` | 手动暂停 / 恢复 |

查询 `auto_trade.view`：策略、阶段、母港/目标港/当前港、航程剩余、自动货舱、
累计花费/收入/利润、最近 8 条日志。

## 6. UI

最小自动贸易页（`framework/ui/screens/port/auto_trade_screen.tscn`）随船厂解锁：
未启动列出策略；运行中显示状态、货舱、利润/航次、暂停/恢复/停止、等待 1/12 小时。

## 7. 验收

- `test_auto_trade.gd` 11 例：命令/查询、启动校验、买入-航行-卖出-返航、规则暂停/恢复、
  切策略/停止、存档往返、损坏数据、确定性。
- `test_world_schema_refs.gd`：策略 goods/规则与 rule→policy 反向引用。
- `test_world_completeness.gd`：Core 最低策略/规则数量 + 策略必须带规则。
- 编辑器/CLI/SDK：`example_trade` 模组、`content.trade.v1` capability、发布门禁校验。
