# `framework/domain/contracts/contract_ops.gd`

> 作用：委托实例生成、装载、交付结算、接取规则、普通委托池生成与抵达刷新。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ContractOps` | L1 |
| `ensure_structure(state: GameState) -> void` | L43 |
| `next_serial(state: GameState) -> int` | L66 |
| `create_instance(hub: RegistryHub, template: ContentDefinition, origin: String, destination: String, now: float, distance: float, serial: int, rng: RandomNumberGenerator) -> Dictionary` | L73 |
| `attach(state: GameState, hub: RegistryHub, instance: Dictionary) -> Dictionary` | L147 |
| `missing_player_cargo(state: GameState, instance: Dictionary) -> Dictionary` | L185 |
| `complete(state: GameState, hub: RegistryHub, instance: Dictionary, arrival_time: float) -> Dictionary` | L214 |
| `is_untimed(instance: Dictionary) -> bool` | L276 |
| `find_template_by_sequence(hub: RegistryHub, sequence: int) -> ContentDefinition` | L282 |
| `templates_by_kind(hub: RegistryHub, kind: String) -> Array[ContentDefinition]` | L289 |
| `active_limit(state: GameState) -> int` | L299 |
| `generate_normal_offers(state: GameState, hub: RegistryHub, rng_service: RngService, key: String) -> Array` | L307 |
| `refresh_normal_offers(state: GameState, hub: RegistryHub, rng_service: RngService, port_id: String, arrival_time: float) -> Array` | L337 |
| `generate_offer(state: GameState, hub: RegistryHub, template: ContentDefinition, rng_service: RngService, origin: String) -> Dictionary` | L343 |
| `accept_offer(state: GameState, hub: RegistryHub, instance_id: String) -> Dictionary` | L399 |
| `accepts_passengers(template: ContentDefinition) -> bool` | L429 |

## 契约与约束
- 实例 ID 由模板 ID + 单调 serial 构成；奖励数额在生成时锁定。
- 货物载荷必须声明 cargo_item_id；载重与旅客数来自 payload 范围。
- 装载前检查客舱容量、总重量与货舱容量；合同货物以 contract_id 绑定到实例。
- 交付时按准时、伤病赔偿、奖金、声誉与解锁结算；收入优先偿还债务，并记录 gross payout 为统计收入。
- 主线 offer 与普通 offer 分开存储；主线同时只能有一个 active。
- 普通委托持有上限 `active_limit = max(1, 1 + reputation/2)`；主线槽位不计入。
- `generate_normal_offers()` 从 normal 模板加权抽 3 个实例；`refresh_normal_offers()` 在每次抵达时
  以 `<port>:<arrival>:<voyages>` 为命名流键整池刷新，不动主线状态。
- 反馈 #2：主线 offer 生成即揭示目的港（`MapOps.discover` + `WorldOps.discover_port_id`，
  与剧情同口径）；普通委托目的地在发现前由 `port.view` 过滤，池内实例保持不变。
- **委托自带海图**（2026-10-26 航线解锁）：`generate_offer` 生成主线 / 普通实例后
  立即 `WorldOps.unlock_route(origin, destination)`，保证委托卡片的「规划出航」
  永远可执行，不会出现「有委托但航线未测绘」。普通委托的目的地仍只在已发现港口中
  选取（见 `_destination_candidates`），发现港口本身不解锁任何航线。
- 反馈 #3：`deadline_formula = "none"` 求值 0 = 无期限哨兵；`create_instance` 存
  `deadline = 0.0`，`complete` 视为准时并照发 `on_time_bonus`（完成奖励），结果带 `timed`；
  负值（未知公式）仍回退 24h 防御。

## 重点逻辑
### `create_instance(...)`
- 遍历 payload 汇总 cargo_weight/passengers；期限使用 FormulaRegistry 的安全公式 ID。
- 奖励使用同一命名随机流抽取范围；所有数据写入纯 Dictionary，便于存档。

### `complete(state, hub, instance, arrival_time)`
- 准时判定 `arrival_time <= deadline`；无期限实例恒准时（不发 contract.late），伤病每人扣 50 赔偿并降低声誉。
- `DebtService.receive_income()` 先还债再把余额入账；`record_income(payout)` 记录毛收入；解锁 ID 写入 player.unlocks。
- 交付后移除对应 contract_id 的货物；实例标记 completed。

### `is_untimed(instance)`
- `deadline <= 0` 或（`kind=main` 且 `sequence >= 3` 的旧存档实例）都视为无期限；不写存档迁移。

### `generate_normal_offers(state, hub, rng_service, key)`
- 候选按模板权重抽样，最多生成 3 个实例；随机流为 STREAM_CONTRACT_GENERATION 的 `normal_offers::<key>`。
- 初始池键为 `initial:<port>`；抵达刷新键包含港口、到达时间与航次数，保证同 seed+命令序列可复现。

模块索引：[framework/domain](../README.md)
