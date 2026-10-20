# `SNBattleSim/js/catalog.mjs`

> 作用：定义战斗模拟器固定的三种船体、内置武器与视野组件，并提供可编辑武器的规范化入口。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `WEAPON_LIMITS` | L66 |
| `finiteNumber(value, fallback)` | L72 |
| `clamp(value, min, max)` | L77 |
| `normalizeWeapon(input, existingIds = [])` | L81 |
| `createWeaponCatalog(customWeapons = [])` | L101 |

## 契约与约束
- 船体只有 small / medium / large 三种，用户配置不能创建第四种船体。
- 武器与视野组件是纯数据；模拟器不按组件 ID 写死行为，行为由 kind 与数值字段决定。
- 用户武器经 normalizeWeapon 校验与限幅后才进入目录。

模块索引：[SNBattleSim](../README.md)
