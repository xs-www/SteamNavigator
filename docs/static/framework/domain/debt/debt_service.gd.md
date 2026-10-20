# `framework/domain/debt/debt_service.gd`

> 作用：固定利率贷款：借款、收入优先还款、逾期扣声誉。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `DebtService` | L1 |
| `borrow(state: GameState, requested: float, limit: float, interest_rate: float, term_hours: float) -> Dictionary` | L5 |
| `receive_income(state: GameState, amount: int) -> Dictionary` | L32 |
| `check_overdue(state: GameState) -> Array[Dictionary]` | L56 |
| `remaining(state: GameState) -> float` | L79 |

## 契约与约束

- 同时只允许一笔贷款；总额 = 本金 × (1+利率)。
- `receive_income()` 先抵扣 remaining，余额才进入玩家货币。
- 逾期检查只触发一次（overdue 标记），剩余债务继续自动偿还。

模块索引：[framework/domain](../README.md)
