# `SNBattleSim/js/loadout.mjs`

> 作用：维护模拟器舰船装配数据、固定船体派生数值与舰队默认配置，并集中给出非法装配原因。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `clamp(value, min, max)` | L15 |
| `createShip(overrides = {})` | L19 |
| `deriveShipStats(ship, weaponCatalog, sensorCatalog = SENSORS)` | L41 |
| `validateShip(ship, weaponCatalog, sensorCatalog = SENSORS)` | L72 |
| `createDefaultFleets()` | L87 |
| `cloneFleetConfig(fleets)` | L100 |

## 契约与约束
- 装配只保存定义引用与调校值，战斗中的位置、耐久和冷却不写回装配。
- 一艘船可以重复安装同一种武器，但总挂载数不得超过船体武器槽位。
- 非武器组件暂以装甲、引擎、操舵和货舱调校反映到最终船舶数值。
- 每艘船只保存一个 tacticId；战术库在开战时解析为 tactic 快照。

模块索引：[SNBattleSim](../README.md)
