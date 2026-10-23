# `framework/domain/ruins/ruin_ops.gd`

> 作用：Phase D5 遗迹远征的纯结构/计算层：生成确定性房间序列、掷危险、结算事件效果、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `RuinOps` | L1 |
| `EXPEDITION_KEY` | L19 |
| `RELICS_KEY` | L20 |
| `SERIAL_KEY` | L21 |
| `DEFAULT_EXPEDITION` | L22 |
| `has_expedition(state: GameState) -> bool` | L35 |
| `ensure_structure(state: GameState) -> Dictionary` | L42 |
| `ruin_definition(hub: RegistryHub, id: String) -> ContentDefinition` | L53 |
| `room_definition(hub: RegistryHub, id: String) -> ContentDefinition` | L57 |
| `event_definition(hub: RegistryHub, id: String) -> ContentDefinition` | L61 |
| `hazard_definition(hub: RegistryHub, id: String) -> ContentDefinition` | L65 |
| `relic_definition(hub: RegistryHub, id: String) -> ContentDefinition` | L69 |
| `generate_rooms(hub: RegistryHub, ruin: ContentDefinition, seed_value: int, serial: int) -> Array` | L73 |
| `roll_hazard(state: GameState, hub: RegistryHub, table_id: String, serial: int, room_index: int) -> Dictionary` | L120 |
| `apply_event_effect(state: GameState, hub: RegistryHub, effect: Dictionary) -> Dictionary` | L160 |
| `grant_completion(state: GameState, hub: RegistryHub, ruin: ContentDefinition, expedition: Dictionary) -> Dictionary` | L184 |
| `kind_to_type(kind: String) -> StringName` | L233 |
| `view(state: GameState, hub: RegistryHub = null) -> Dictionary` | L244 |

结算战利品与遗物，并输出只读 `expedition.view` 数据。

## 契约与约束
- `data.expedition` 只在 `expedition.start` 后存在；`data.relics` 保存永久遗物 id 列表，
  `data.expedition_serial` 是新远征序号。
- 房间序列由 ruin_archetypes 的 `room_tags` 过滤 room_templates，按 `weight` 权重抽取；
  随机种子 = run seed + ruin id + serial，同序号可复现。
- 危险表按权重抽 type/amount；durability 扣当前船耐久，money 扣钱，cargo 从船货舱扣除，
  无货时转为等值耐久损失。
- 事件选项只执行 `add_money` / `damage_ship` / `add_item` 三个操作码（Core 内容只用这三个）。
- 完成时按 loot_table 的 money_range 与 entries 发奖（item 进当前港仓库，其他类型折算金币），
  并从 `relic_pool` 抽 1 件遗物写入 `data.relics`。

模块索引：[framework/domain](../README.md)
