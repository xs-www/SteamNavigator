# `framework/application/commands/base_commands.gd`

> 作用：Phase D3 基地的命令入口：`base.claim` / `base.build` / `base.upgrade` /

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `BaseCommands` | L1 |
| `claim(params: Dictionary, context) -> Dictionary` | L18 |
| `build(params: Dictionary, context) -> Dictionary` | L24 |
| `upgrade(params: Dictionary, context) -> Dictionary` | L30 |
| `deposit(params: Dictionary, context) -> Dictionary` | L36 |
| `withdraw(params: Dictionary, context) -> Dictionary` | L42 |
| `hire_worker(params: Dictionary, context) -> Dictionary` | L48 |
| `assign_worker(params: Dictionary, context) -> Dictionary` | L54 |
| `start_production(params: Dictionary, context) -> Dictionary` | L60 |

`base.deposit` / `base.withdraw` / `base.hire_worker` / `base.assign_worker` /
`base.start_production`。都经 CommandBus 事务执行，失败不提交 `data.base`；成功时
把 `base.*` 领域事件交给 CommandBus 发布。

## 契约与约束
- 所有命令都要求已有 run（`context.has_run()`），否则 `no_run`。
- 校验/引用规则全部在 `BaseService`（基地唯一、建筑槽位、配方归属、工人槽位、
  仓储容量、在基地港口存取等）。
- `base.claim` 绑定当前港口；`deposit` / `withdraw` 要求当前港 == 基地港。
- 生产由 tick 系统推进，命令只负责锁存输入与订单。

模块索引：[framework/application](../README.md)
