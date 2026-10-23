# `framework/domain/base/base_service.gd`

> 作用：Phase D3 基地的领域用例：占领基地、建造/升级建筑、雇工/派工、仓储存取与

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `BaseService` | L1 |
| `claim(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary` | L27 |
| `build(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary` | L70 |
| `upgrade(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary` | L114 |
| `deposit(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary` | L167 |
| `withdraw(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary` | L209 |
| `hire_worker(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary` | L244 |
| `assign_worker(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary` | L278 |
| `start_production(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary` | L327 |

启动生产。所有入口返回 `Result`，由应用层命令在 CommandBus 事务内调用；状态只落在
`data.base`，生产推进由 `BaseProductionSystem` 在 tick 中完成。

关键依赖：`RegistryHub`（base_sites / buildings / building_upgrades /
production_recipes / worker_roles）、`BaseOps`、`WarehouseOps`、`GameState`

## 契约与约束
- 占领：同一存档只能有一个基地；要求当前在港，扣除站点 `claim_cost_money`，授予
  `starting_workers` / `starting_storage`，基地绑定当前港口。
- 建造/升级：金钱直接扣；材料从基地仓储扣；建筑有建造/升级工时，tick 完成后才可用。
- 仓储：`deposit` 从当前港口仓库转入、`withdraw` 转回，均要求人在基地港口；容量
  按 item.unit_weight 计算，超容量返回 `base_storage_full`。
- 雇工：扣除 `hire_cost_money` 后进入待派工池；派工要求建筑已完工、工种匹配、
  不超过 worker_slots，并从池中转移。
- 生产：建筑空闲、配方属于该建筑、工人/材料/金钱满足时锁存输入并生成订单；
  tick 推进期间不再重复扣费，完成后输出进基地仓储。
- 领域事件：`base.claimed` / `base.building_started` / `base.upgrade_started` /
  `base.worker_hired` / `base.worker_assigned` / `base.production_started` /
  `base.storage_changed`。

模块索引：[framework/domain](../README.md)
