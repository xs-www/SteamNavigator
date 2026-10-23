# `framework/domain/base/base_production_system.gd`

> 作用：Phase D3 基地的确定性 tick 系统：每游戏小时支付维护费/建筑维护/工人工资，

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `BaseProductionSystem` | L1 |
| `SYSTEM_ID` | L18 |
| `PRIORITY` | L19 |
| `register() -> void` | L22 |
| `ensure_registered() -> void` | L29 |
| `tick(state: GameState, _tick: int, context = null) -> void` | L34 |

推进建筑建造、升级与生产订单，完成时把产物写入基地仓储。由 `Bootstrap` 注册到
`TickScheduler`（id `base.production`，priority 100），`sim.advance` 驱动。

## 契约与约束
- 没有 `data.base` 或没有注册表上下文时完全 no-op；不创建 `data.base`。
- 每 tick 先把站点维护费、建筑维护费与工资累加到 `upkeep_debt`，按整金币支付；
  余额不足时置 `halted=true`、`unpaid_ticks += 1`，本 tick 不推进建造/升级/生产。
- 建造/升级按 1 小时递减；生产按 `BaseOps.production_speed()` 递减（≥1 tick 的
  离散步长），工人少于配方 `workers_required` 时订单不推进（工资照付）。
- 产物完成时直接进入基地仓储（允许短时超过容量；`base.view` 如实报告）。
- 系统只依赖 `state` / `context.registries`，不读时钟、不随机，保证同 tick 可复现。

模块索引：[framework/domain](../README.md)
