# `framework/domain/contracts/contract_ops.gd`

> 作用：委托实例生成、装载、交付结算与接取规则。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ContractOps` | L1 |

## 契约与约束

- 实例 ID 由模板 ID + 单调 serial 构成；奖励数额在生成时锁定。
- 货物载荷必须声明 cargo_item_id；载重与旅客数来自 payload 范围。
- 装载前检查客舱容量、总重量与货舱容量；合同货物以 contract_id 绑定到实例。
- 交付时按准时、伤病赔偿、奖金、声誉与解锁结算；收入优先偿还债务。
- 主线 offer 与普通 offer 分开存储；主线同时只能有一个 active。

## 重点逻辑

### `create_instance(...)`

- 遍历 payload 汇总 cargo_weight/passengers；期限使用 FormulaRegistry 的安全公式 ID。
- 奖励使用同一命名随机流抽取范围；所有数据写入纯 Dictionary，便于存档。

### `complete(state, hub, instance, arrival_time)`

- 准时判定 arrival_time <= deadline；伤病每人扣 50 赔偿并降低声誉。
- `DebtService.receive_income()` 先还债再把余额入账；解锁 ID 写入 player.unlocks。
- 交付后移除对应 contract_id 的货物；实例标记 completed。

模块索引：[framework/domain](../README.md)
