# `SNBattleSim/js/app.mjs`

> 作用：连接战斗画布、Mod 蓝图舰体装配、双层工程持久化、配置交换与实时模拟控制。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `STORAGE_KEY` | L24 |
| `catalog()` | L48 |
| `sensors()` | L49 |
| `selectedFleet()` | L50 |
| `selectedShip()` | L51 |
| `workspaceData()` | L53 |
| `applyWorkspace(saved)` | L57 |
| `saveLocal()` | L72 |
| `loadLocal()` | L76 |
| `saveWorkspaceFile()` | L86 |
| `loadWorkspaceFile()` | L94 |
| `shipBuilderTemplates()` | L105 |
| `shipDraftFromBuilder()` | L113 |
| `updateShipBuilderValidation()` | L123 |
| `renderShipBuilder(templateKey = "combat")` | L129 |
| `openShipBuilder()` | L140 |
| `optionRows(values, selectedIds)` | L142 |
| `renderFleetTabs()` | L146 |
| `renderFleetList()` | L155 |
| `renderEditor()` | L172 |
| `slider(key, label, value, min, max)` | L249 |
| `tacticSlider(key, label, value, min, max)` | L252 |
| `stat(key, label, value)` | L256 |
| `shipSheet(stats, ship)` | L258 |
| `refreshShipSheet(host, ship, weaponCatalog, sensorCatalog = sensors()` | L275 |
| `saveAndRender()` | L289 |
| `renderWeapons()` | L291 |
| `renderBattleStatus()` | L306 |
| `renderRuntimeShipStatus(battle)` | L324 |
| `eventLabel(event)` | L347 |
| `startBattle()` | L356 |
| `draw()` | L368 |
| `TAU` | L406 |
| `shipObservation(battle, ship)` | L407 |
| `RANGE_COLORS` | L414 |
| `drawRangeRings(context, camera, canvas, ship)` | L416 |
| `drawAnnularCircle(context, point, outerRadius, innerRadius)` | L441 |
| `drawAnnularSector(context, point, outerRadius, innerRadius, startAngle, endAngle)` | L450 |
| `drawRangeLabel(context, point, radius, angle, label, color)` | L460 |
| `drawWorldGrid(context, camera, width, height)` | L469 |
| `drawGhost(context, camera, canvas, contact, ship)` | L483 |
| `drawTargetHighlight(context, camera, canvas, battle, selectedShip)` | L491 |
| `drawShip(context, camera, canvas, ship)` | L504 |
| `drawWeaponStatusBar(context, point, shipRadius, mounts)` | L522 |
| `selectedMachine()` | L542 |
| `openTacticsWorkspace()` | L546 |
| `closeTacticsWorkspace()` | L552 |
| `renderTacticsWorkspace()` | L558 |
| `loadModsFromDirectory()` | L588 |
| `exportCurrentAsMod()` | L610 |
| `renderAll()` | L620 |
| `bindStaticControls()` | L622 |
| `loop(timestamp)` | L666 |

## 契约与约束
- UI 只修改装配配置；开始/重置战斗时才创建独立 BattleSimulation 快照。
- 工程自动保存到 localStorage，也可手动持久化到 user_data/workspace.json；两者恢复时共用校验。
- 画布可切换蓝方、红方或全知视角；阵营视角只显示已发现目标及其最后已知位置。
- 每艘可见舰在舰名上方显示逐挂载武器装填条；隐藏目标不泄露武器冷却状态。
- 战斗事件覆盖在战场右上角；下方状态面板跟随选中舰，其攻击目标同时在战场上红色高亮。
- 独立战术工作台维护状态定义与状态机库；本地服务负责 mods/ 导入和游戏约定格式导出。

模块索引：[SNBattleSim](../README.md)
