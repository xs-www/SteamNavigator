# `framework/domain/base/base_ops.gd`

> 作用：Phase D3 基地（base）的纯结构与计算层：规范化 `data.base`、解析基地/建筑/

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `BaseOps` | L1 |
| `BASE_KEY` | L22 |
| `DEFAULT_BUILDING` | L23 |
| `DEFAULT_BASE` | L33 |
| `VALID_STATUS` | L45 |
| `has_base(state: GameState) -> bool` | L48 |
| `ensure_structure(state: GameState) -> Dictionary` | L58 |
| `view(state: GameState, hub: RegistryHub = null) -> Dictionary` | L72 |
| `site_definition(hub: RegistryHub, site_id: String) -> ContentDefinition` | L106 |
| `building_definition(hub: RegistryHub, building_id: String) -> ContentDefinition` | L112 |
| `recipe_definition(hub: RegistryHub, recipe_id: String) -> ContentDefinition` | L118 |
| `upgrade_definition(hub: RegistryHub, upgrade_id: String) -> ContentDefinition` | L124 |
| `worker_role_definition(hub: RegistryHub, role_id: String) -> ContentDefinition` | L130 |
| `building_entry(base: Dictionary, instance_id: String) -> Dictionary` | L136 |
| `next_instance_id(base: Dictionary) -> String` | L143 |
| `slot_count(hub: RegistryHub, base: Dictionary) -> int` | L157 |
| `item_unit_weight(hub: RegistryHub, item_id: String) -> float` | L162 |
| `storage_used(hub: RegistryHub, storage: Dictionary) -> float` | L169 |
| `storage_capacity(hub: RegistryHub, base: Dictionary) -> float` | L178 |
| `defense(hub: RegistryHub, base: Dictionary) -> int` | L195 |
| `maintenance_per_tick(hub: RegistryHub, base: Dictionary) -> float` | L212 |
| `upkeep_per_tick(hub: RegistryHub, base: Dictionary) -> float` | L217 |
| `wages_per_tick(hub: RegistryHub, base: Dictionary) -> float` | L227 |
| `money_due_per_tick(hub: RegistryHub, base: Dictionary) -> float` | L244 |
| `assigned_worker_count(entry: Dictionary) -> int` | L248 |
| `production_speed(hub: RegistryHub, base: Dictionary, entry: Dictionary) -> float` | L255 |
| `storage_view(hub: RegistryHub, base: Dictionary) -> Dictionary` | L276 |
| `workers_view(hub: RegistryHub, base: Dictionary) -> Dictionary` | L303 |
| `building_view(hub: RegistryHub, base: Dictionary, entry: Dictionary) -> Dictionary` | L328 |

升级/配方/工人工种引用、计算仓储、防御、每 tick 支出、生产速度，并给出只读
`base.view` 数据。持久状态只记录基地实例（站点、建筑、工人、仓储、生产订单），
不复制内容定义。

## 契约与约束
- `data.base` 只在 `base.claim` 成功后存在：`{site_id, site_archetype_id, port_id,
  buildings[], storage{}, workers{}, next_building, unpaid_ticks, halted}`。
- 建筑实例：`{instance_id, building_ref, level, status, remaining_hours,
  workers{role:qty}, order{recipe_id, remaining_hours, total_hours}}`；
  status = `building` / `ready` / `upgrading`。
- 仓储是 `{item_id: amount}`；容量 = 站点容量 + 已完工建筑的 `storage_capacity` +
  等级修正，单位与 item.data.unit_weight 一致。
- 生产速度 = 建筑等级修正乘积 ×（1 + Σ 已分配工人的 speed_bonus）；工人不足
  `workers_required` 时订单不推进，但仍支付工资与维护费。
- 损坏数据一律规范化或跳过，`view()` 绝不抛引擎错误且不写状态。

模块索引：[framework/domain](../README.md)
