# SNBattleSim 状态、状态机与模组数据约定 v1

本约定用于战斗模拟器试验数据和后续正式战斗系统之间的交接。模拟器沿用 Steam Navigator 的模组目录外壳，但下列 `battle_*` 内容类型属于 `content.combat.simulator.v1`，在正式战斗 Schema 接入前不由 Godot 主流程加载。

> **正式内容类型（D-AI，schema 先行）**：FSM 决策已登记为 Content Schema 2.0 **草案**类型 `combat_ai_profiles`（Schema：[schemas/v2/combat_ai_profile.schema.json](../../schemas/v2/combat_ai_profile.schema.json)，编辑器 / CLI 可编辑、可 draft 校验，**运行时不加载**、不写 Core）。其 `data` 的 `target_priority` / `preferred_range` / `initial` / `nodes[].runtime_action` / `transitions[].conditions` 与本契约的 `tactic` / `fsm` 数据对齐；`battle_state_machines` 仍是模拟器导入格式，待战斗运行时接入时再迁移。

## 目录与 Manifest

模组可以是 `SNBattleSim/mods/<mod_id>/` 散装目录：

```text
<mod_id>/
├── manifest.json
├── content/
│   ├── battle_weapons.json
│   ├── battle_sensors.json
│   ├── battle_ships.json
│   ├── battle_states.json
│   └── battle_state_machines.json
└── localization/zh_CN.json
```

也可以是 `SNBattleSim/mods/*.zip` 或 `*.snavmod.zip`。ZIP 包内必须且只能有一个 `mods/<mod_id>/manifest.json`，其余文件均位于同一 `mods/<mod_id>/` 前缀下；`manifest.id` 必须与路径中的 `<mod_id>` 一致。不支持加密、分卷或 Zip64 包。

`manifest.json` 使用游戏现有的 Mod Manifest 1.0 字段，并在 `content` 中显式列出内容文件。建议声明 capability `content.combat.simulator.v1`。浏览器通过本地服务读取该目录；不能用 `file://` 直接访问。

所有内容文件统一使用游戏 definitions 外壳：

```json
{
  "schema_version": "1.0",
  "content_type": "battle_state_machines",
  "definitions": [
    {
      "id": "example:battle_state_machine/escort",
      "name_key": "example.battle_state_machine.escort.name",
      "enabled": true,
      "data": {}
    }
  ]
}
```

实体 ID 必须是 `<mod_id>:<type>/<local_id>`。禁用定义使用 `enabled: false`。

## 内容类型

### `battle_weapons`

`data` 字段：`name`、`kind`（`direct|artillery|broadside`）、`damage`、`range`、`minRange`、`cooldown`、`accuracy`、`projectileSpeed`、`splash`、`mass`、`arc`、`salvo`、`color`。

### `battle_sensors`

`data` 字段：`name`、`rangeBonus`、`accuracyBonus`、`mass`。

### `battle_ships`

`data` 使用模拟器装配结构：`name`、`faction`（0 蓝/1 红）、`hullId`（只允许 `small|medium|large`）、`role`、`weaponIds`、`sensorIds`、`tuning`、`cargoValue`、`isCommander`。状态机通过完整 ID 引用：

```json
"tactic_ref": "example:battle_state_machine/escort"
```

### `battle_states`

状态定义是编辑器素材与开发文档，不是任意脚本：

```json
{
  "name": "迂回",
  "description": "侧向绕开最近敌人，并远离敌方集群中心",
  "runtime_action": "flank"
}
```

`runtime_action` 必须是：`recon`、`cruise`、`approach`、`flank`、`evade`、`maneuver`、`withdraw`、`flee`、`engage`、`focus` 之一。多个状态定义可以复用同一安全动作，以表达不同的战术语义和节点名称。

### `battle_state_machines`

`data.name` 是显示名称，`data.tactic` 包含目标选择参数和 `fsm`：

```json
{
  "name": "护航战术",
  "tactic": {
    "targetPriority": "cargo",
    "chaseLastKnown": true,
    "preferredRange": 0.72,
    "fsm": {
      "initial": "cruise",
      "nodes": [
        { "id": "cruise", "name": "巡航", "action": "cruise", "x": 0.2, "y": 0.3 },
        { "id": "engage", "name": "交火", "action": "engage", "x": 0.7, "y": 0.3 }
      ],
      "transitions": [
        {
          "id": "spot_and_ready",
          "from": "cruise",
          "to": "engage",
          "logic": "all",
          "conditions": ["visible_target", "weapon_ready"]
        }
      ]
    }
  }
}
```

`logic: "all"` 表示条件之间为“且”，`logic: "any"` 表示“或”。每条转移至少一个、最多八个条件。旧版单一 `condition` 字段仍可导入，但新数据必须写 `conditions`。

条件枚举：`cargo_threatened`、`no_target`、`visible_target`、`last_known_target`、`withdraw_trigger`、`withdraw_recovered`、`enemy_in_range`、`enemy_out_of_range`、`weapon_ready`、`broadside_ready`、`commander_present`、`hull_below`、`has_target`、`target_far`、`target_band`、`always`。

同一 `from` 状态的转移按数组顺序判定，第一条满足条件的转移生效。状态机最多 20 个节点、80 条转移，每条转移最多 8 个条件。

## 导入、导出与 CLI

- 页面“读取 mods/”会重新扫描目录，并替换上一次从目录载入的数据；浏览器本地创建的数据保留。
- Mod 的 `battle_ships` 定义作为“舰体装配”蓝图载入，由用户选择阵营并组装成实例，不在扫描时直接改写当前舰队。
- “导出为 Mod”会创建带时间戳的新 `.snavmod.zip`，不覆盖既有模组包。导出包括自定义武器、视野组件、两支舰队、状态定义和全部状态机。
- 快速校验：`node SNBattleSim/tools/cli.mjs validate-mods`
- 查看摘要：`node SNBattleSim/tools/cli.mjs inspect`
- 确定性快跑：`node SNBattleSim/tools/cli.mjs simulate --ticks 1200 --seed 5201`
- 生成示例：`node SNBattleSim/tools/cli.mjs export-sample --id agent_debug`

正式战斗系统若采纳本约定，应新增正式 Schema 与 `content_types.json` 注册项；在此之前不要把这些试验类型加入 Core Manifest。
