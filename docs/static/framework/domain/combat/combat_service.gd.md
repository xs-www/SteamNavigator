# `framework/domain/combat/combat_service.gd`

> 作用：Phase D1 战斗自动结算的运行时门面：解析遭遇表、调用 `CombatOps` 纯规则层，

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `CombatService` | L1 |
| `COMBAT_KEY` | L35 |
| `SCHEMA_VERSION` | L36 |
| `MAX_BATTLES` | L38 |
| `DEFAULT_STATE` | L39 |
| `ensure_state(state: GameState) -> Dictionary` | L49 |
| `resolve(hub: RegistryHub,, state: GameState,, encounter_table_id: String = "",, requested_seed: int = 0,, settlement_key: String = "") -> Dictionary` | L82 |
| `view(state: GameState, hub: RegistryHub) -> Dictionary` | L200 |
| `last_battle(state: GameState) -> Dictionary` | L228 |
| `battle_records(state: GameState) -> Array` | L236 |
| `log_rows(state: GameState, limit: int = 20) -> Array` | L247 |

把结果落到 `GameState`（结构耐久、战利品、`data.combat` 惰性战斗记录），并给命令 /
查询提供稳定的 view 形状。命令 `combat.resolve` 与查询 `combat.view` / `combat.log`
都只是本服务的薄封装。

关键依赖：`CombatOps`、`RegistryHub`、`GameState`、`ShipOps`、`WarehouseOps`、
`StableHash`、`RngService`。

## 契约与约束
- **确定性**：显式 `requested_seed` 直接决定本场战斗；省略时按
  `StableHash.seed_from(run.seed, "combat", "battle:<序号>")` 派生，因此同存档 + 同
  战斗序号的连续结算也可复现。战斗随机流固定为 `RngService` 的 `combat` 命名流。
- **一次遭遇一次结算**：结算成功才写状态；`data.combat` 记录每场战斗的 JSON 快照
  （含回合日志，最多 `CombatOps.MAX_LOG_ENTRIES` 条）；最多保留 `MAX_BATTLES` 场，
  超出从最旧开始丢弃。旧档没有该块时惰性补齐，不改 `schema_version`。
- **结算幂等（可选 settlement key）**：`resolve(..., settlement_key)` 用
  `data.combat.settlements`（key → battle id）保证同一 key 只结算一次；重复调用返回
  已有 battle（`data.already_settled=true`），不发奖、不追加记录、不推进序号。key 为空
  时保持旧语义（每次调用都是新战斗）；被 `MAX_BATTLES` 淘汰的战斗会同时清理其 key。
- **耐久语义**：战后把 `player.durability_after` 写回 `ship.durability`（0–100）；
  击沉落到 `CombatOps.MIN_DURABILITY_AFTER_DEFEAT`，维修入口沿用现有港口维修。
- **战利品发放**：`victory` 才发放。金钱 → `player.money` + `stats.income`；item →
  船上货舱（`ShipOps.add_cargo`，D1 不做容量拦截；超载由现有载重/市场规则处理）；
  module → 当前港仓库（`WarehouseOps.add_module`）；weapon 掉落由 `CombatOps` 折算成
  残骸回收金钱，因此没有「武器背包」存档分区。
- **错误**：`no_run` / `no_ship` / `unknown_encounter` / `combat_resolve_failed`；
  失败不提交状态（命令事务负责）。
- 本服务不发领域事件（命令层负责）；不接 `voyage` 风险结算（D1 只提供 commander
  可调用入口，接入航行留给后续切片）。

模块索引：[framework/domain](../README.md)
