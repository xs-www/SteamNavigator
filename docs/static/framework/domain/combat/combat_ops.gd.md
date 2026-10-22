# `framework/domain/combat/combat_ops.gd`

> 作用：Phase D1 战斗自动结算的纯规则层。把「玩家船 + encounter_table 抽出的敌舰组合 +

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `CombatOps` | L1 |
| `STREAM_COMBAT` | L41 |
| `MAX_ROUNDS` | L43 |
| `PLAYER_HIT_POINTS_PER_DURABILITY` | L45 |
| `PLAYER_ARMOR` | L47 |
| `PLAYER_RETREAT_RATIO` | L49 |
| `MIN_DURABILITY_AFTER_DEFEAT` | L51 |
| `STATUS_DURATION_ROUNDS` | L53 |
| `STATUS_DAMAGE_PER_ROUND` | L55 |
| `LOOT_ROLLS_PER_TABLE` | L61 |
| `WEAPON_SALVAGE_RATIO` | L63 |
| `MAX_LOG_ENTRIES` | L65 |
| `resolve(hub: RegistryHub,, ship: Dictionary,, encounter_table: ContentDefinition,, seed_value: int) -> Dictionary` | L71 |
| `battle_view(battle: Dictionary) -> Dictionary` | L121 |
| `encounter_summaries(hub: RegistryHub) -> Array` | L126 |
| `player_weapon_rows(hub: RegistryHub, ship: Dictionary) -> Array` | L150 |
| `unmounted_sockets(hub: RegistryHub, ship: Dictionary) -> Array` | L174 |
| `status_of(hub: RegistryHub, weapon: ContentDefinition) -> String` | L191 |
| `armor_pierce_of(hub: RegistryHub, weapon: ContentDefinition) -> float` | L202 |

武器/伤害类型/敌人原型/能力数据」解析成一次确定性、无状态副作用的自动战斗，输出
回合日志、双方耐久变化、击沉 / 撤退结论与战利品 roll。

关键依赖：`RegistryHub`（weapons / damage_types / combat_abilities /
enemy_archetypes / loot_tables）、`ShipOps.durability_max`、`RngService`。

## 契约与约束
- **纯函数**：只读 `hub` / `ship` / 内容定义，不读写 `GameState`；状态落盘与战利品
  发放由 `CombatService` 负责，便于单测与幂等控制。
- **确定性**：随机只来自调用方传入的 `RandomNumberGenerator`（`RngService` 的
  `combat` 命名流）。武器按解析顺序开火、敌舰按生成顺序行动；同 seed + 同初始
  耐久 + 同内容 = 完全相同的结果（日志与战利品都一致）。
- **抽象回合制**：1 回合 = 1 战斗秒；武器按 `cooldown` 就绪，双方同回合同时开火。
  没有空间/弹道模型（D1 明确不做战术层），射程只用于玩家默认武器的启发式选择。
- **伤害公式**：`effective = damage × (1 − armor × (1 − armor_pierce))`；
  `damage_types.armor_pierce` 是唯一穿甲来源；`status_effect != none` 的命中会给
  目标挂 3 秒持续伤害（burn 1.0 / shock 0.5 / flood 1.5 每回合，忽略护甲）。
- **玩家战斗耐久池**：`durability × PLAYER_HIT_POINTS_PER_DURABILITY`（内容层
  `max_durability` 是结构耐久 0–100，敌舰 `hull_points` 是战斗 HP；D1 用固定倍率
  把两者放到同一量级）。战后的结构耐久 = `hp / PLAYER_HIT_POINTS_PER_DURABILITY`，
  击沉时落到 1.0（救援/维修入口沿用现有维修系统）。
- **玩家护甲**：`PLAYER_ARMOR` 常量。hull Schema 目前没有 armor 字段，等 Phase E/
  模块 condition 派生后再内容化，注释即 TODO。
- **内容字段消费范围（D1）**：`enemy_archetypes` 的 `hull_points / armor /
  weapon_sockets / combat_ability / loot_table` 参与结算；`max_speed / turn_rate_deg /
  enemy_class` 只写入 battle 视图（战术层后置）。`combat_abilities` 目前只消费
  `retreat_hull`（撤退阈值）；`action / target_priority / preferred_range` 是给后续
  战术 AI 的声明式参数，D1 自动结算不使用。
- **结局**：`victory`（敌舰全灭）/ `enemy_retreated`（敌舰全部脱离）/ `retreated`
  （玩家耐久比例 ≤ `PLAYER_RETREAT_RATIO` 主动脱离）/ `defeat`（玩家 HP ≤ 0）。
  只有 `victory` 对**已击沉**敌舰 roll 战利品；撤退/击沉玩家不发奖励。
- 内容缺失（未知武器 class、未知 loot_table、非法条目）只跳过并记录 reason，
  不静默编造数值；调用方（CombatService）把空结果转成结构化错误。

模块索引：[framework/domain](../README.md)
