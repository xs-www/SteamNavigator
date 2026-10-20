# `SNBattleSim/js/mod_format.mjs`

> 作用：定义模拟器扩展模组的数据类型，解析游戏约定 definitions 外壳，并生成可写入 mods/ 的标准模组文件集合。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `importSimulatorMods(packages, existing = {})` | L20 |
| `buildSimulatorMod({ id = "simulator_custom", name = "SNBattleSim Custom Data", customWeapons = [], customSensors = [], fleets = [[], []], tacticLibrary = [], stateDefinitions = FSM_STATE_DEFINITIONS })` | L54 |

## 契约与约束
- 文件沿用 manifest.json + content/*.json + localization/*.json 结构，实体 ID 必须带模组命名空间。
- 模拟器扩展类型为 battle_weapons、battle_sensors、battle_ships、battle_states、battle_state_machines。
- 船体仍只允许 small/medium/large；状态 runtime_action 必须映射到内置安全动作。

模块索引：[SNBattleSim](../README.md)
