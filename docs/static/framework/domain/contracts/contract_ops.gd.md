# `framework/domain/contracts/contract_ops.gd`

> 作用：委托实例生成、装载、交付结算、接取规则、普通委托池生成与抵达刷新。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ContractOps` | L1 |
| `ensure_structure(state: GameState) -> void` | L5 |
| `next_serial(state: GameState) -> int` | L28 |
| `create_instance(hub: RegistryHub, template: ContentDefinition, origin: String, destination: String, now: float, distance: float, serial: int, rng: RandomNumberGenerator) -> Dictionary` | L35 |
| `attach(state: GameState, hub: RegistryHub, instance: Dictionary) -> Dictionary` | L91 |
| `complete(state: GameState, hub: RegistryHub, instance: Dictionary, arrival_time: float) -> Dictionary` | L114 |
| `find_template_by_sequence(hub: RegistryHub, sequence: int) -> ContentDefinition` | L162 |
| `templates_by_kind(hub: RegistryHub, kind: String) -> Array[ContentDefinition]` | L169 |
| `active_limit(state: GameState) -> int` | L179 |
| `generate_normal_offers(state: GameState, hub: RegistryHub, rng_service: RngService, key: String) -> Array` | L187 |
| `refresh_normal_offers(state: GameState, hub: RegistryHub, rng_service: RngService, port_id: String, arrival_time: float) -> Array` | L217 |
| `generate_offer(state: GameState, hub: RegistryHub, template: ContentDefinition, rng_service: RngService, origin: String) -> Dictionary` | L223 |
| `accept_offer(state: GameState, hub: RegistryHub, instance_id: String) -> Dictionary` | L252 |
| `accepts_passengers(template: ContentDefinition) -> bool` | L279 |

## 契约与约束

- 实例 ID 由模板 ID + 单调 serial 构成；奖励数额在生成时锁定。
- 货物载荷必须声明 cargo_item_id；载重与旅客数来自 payload 范围。
- 装载前检查客舱容量、总重量与货舱容量；合同货物以 contract_id 绑定到实例。
- 交付时按准时、伤病赔偿、奖金、声誉与解锁结算；收入优先偿还债务，并记录 gross payout 为统计收入。
- 主线 offer 与普通 offer 分开存储；主线同时只能有一个 active。
- 普通委托持有上限 `active_limit = max(1, 1 + reputation/2)`；主线槽位不计入。
- `generate_normal_offers()` 从 normal 模板加权抽 3 个实例；`refresh_normal_offers()` 在每次抵达时以 <port>:<arrival>:<voyages> 为命名流键整池刷新，不动主线状态。

## 重点逻辑

### `create_instance(...)`

- 遍历 payload 汇总 cargo_weight/passengers；期限使用 FormulaRegistry 的安全公式 ID。
- 奖励使用同一命名随机流抽取范围；所有数据写入纯 Dictionary，便于存档。

### `complete(state, hub, instance, arrival_time)`

- 准时判定 arrival_time <= deadline；伤病每人扣 50 赔偿并降低声誉。
- `DebtService.receive_income()` 先还债再把余额入账；`record_income(payout)` 记录毛收入；解锁 ID 写入 player.unlocks。
- 交付后移除对应 contract_id 的货物；实例标记 completed。

### `generate_normal_offers(state, hub, rng_service, key)`

- 候选按模板权重抽样，最多生成 3 个实例；随机流为 STREAM_CONTRACT_GENERATION 的 `normal_offers::<key>`。
- 初始池键为 `initial:<port>`；抵达刷新键包含港口、到达时间与航次数，保证同 seed+命令序列可复现。

模块索引：[framework/domain](../README.md)
