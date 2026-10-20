# `SNBattleSim/js/loadout.mjs`

> 作用：维护模拟器舰船装配数据、固定船体派生数值与舰队默认配置，并集中给出非法装配原因。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `clamp(value, min, max)` | L16 |
| `createShip(overrides = {})` | L20 |
| `deriveShipStats(ship, weaponCatalog)` | L40 |
| `validateShip(ship, weaponCatalog)` | L71 |
| `createDefaultFleets()` | L86 |
| `cloneFleetConfig(fleets)` | L99 |

## 契约与约束
- 装配只保存定义引用与调校值，战斗中的位置、耐久和冷却不写回装配。
- 一艘船可以重复安装同一种武器，但总挂载数不得超过船体武器槽位。
- 非武器组件暂以装甲、引擎、操舵和货舱调校反映到最终船舶数值。
- 每艘船保存一份经限幅的声明式战术配置，旧配置自动使用默认战术。

模块索引：[SNBattleSim](../README.md)
