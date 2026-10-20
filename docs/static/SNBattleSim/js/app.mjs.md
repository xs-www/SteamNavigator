# `SNBattleSim/js/app.mjs`

> 作用：连接战斗画布、舰队装配器、自定义武器表单、配置导入导出与实时模拟控制。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `STORAGE_KEY` | L20 |
| `catalog()` | L39 |
| `selectedFleet()` | L40 |
| `selectedShip()` | L41 |
| `saveLocal()` | L43 |
| `loadLocal()` | L47 |
| `optionRows(values, selectedIds)` | L62 |
| `renderFleetTabs()` | L66 |
| `renderFleetList()` | L75 |
| `renderEditor()` | L91 |
| `slider(key, label, value, min, max)` | L188 |
| `tacticSlider(key, label, value, min, max)` | L191 |
| `stat(key, label, value)` | L195 |
| `shipSheet(stats, ship)` | L197 |
| `refreshShipSheet(host, ship, weaponCatalog)` | L214 |
| `saveAndRender()` | L228 |
| `renderWeapons()` | L230 |
| `renderBattleStatus()` | L244 |
| `renderRuntimeShipStatus(battle)` | L262 |
| `eventLabel(event)` | L285 |
| `startBattle()` | L294 |
| `draw()` | L304 |
| `TAU` | L341 |
| `shipObservation(battle, ship)` | L342 |
| `RANGE_COLORS` | L349 |
| `drawRangeRings(context, camera, canvas, ship)` | L351 |
| `drawAnnularCircle(context, point, outerRadius, innerRadius)` | L376 |
| `drawAnnularSector(context, point, outerRadius, innerRadius, startAngle, endAngle)` | L385 |
| `drawRangeLabel(context, point, radius, angle, label, color)` | L395 |
| `drawWorldGrid(context, camera, width, height)` | L404 |
| `drawGhost(context, camera, canvas, contact, ship)` | L418 |
| `drawShip(context, camera, canvas, ship)` | L426 |
| `drawWeaponStatusBar(context, point, shipRadius, mounts)` | L444 |
| `renderAll()` | L464 |
| `bindStaticControls()` | L466 |
| `addShip(role)` | L497 |
| `loop(timestamp)` | L502 |

## 契约与约束
- UI 只修改装配配置；开始/重置战斗时才创建独立 BattleSimulation 快照。
- 自定义武器保存在浏览器 localStorage，导入配置仍需经过目录规范化与舰船校验。
- 画布可切换蓝方、红方或全知视角；阵营视角只显示已发现目标及其最后已知位置。
- 每艘可见舰在舰名上方显示逐挂载武器装填条；隐藏目标不泄露武器冷却状态。
- 战斗事件覆盖在战场右上角；下方状态面板跟随装配器当前选中的舰船。

模块索引：[SNBattleSim](../README.md)
