# `SNBattleSim/js/tactic_library.mjs`

> 作用：维护默认与自定义状态机库，迁移旧版随舰战术，并解析每艘船唯一挂载的状态机。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `createDefaultTacticLibrary()` | L9 |
| `normalizeTacticLibrary(value)` | L11 |
| `migrateTacticalData(fleets, rawLibrary)` | L12 |
| `resolveShipTactic(ship, library)` | L13 |
| `uniqueMachineId(library, prefix="tactic")` | L14 |

## 契约与约束
- default 可编辑但不可删除；舰船只保存 tacticId；删除自定义状态机时挂载回退至 default。

模块索引：[SNBattleSim](../README.md)
