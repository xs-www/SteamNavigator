# `SNBattleSim/js/tactics.mjs`

> 作用：定义开发者模式 FSM 的状态动作、模块化条件、AND/OR 聚合转移和确定性状态转换。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `DEFAULT_NODES` | L43 |
| `DEFAULT_EDGES` | L48 |
| `defaultFsm()` | L57 |
| `normalizeFsm(value)` | L65 |
| `normalizeTactic(value = {})` | L92 |
| `conditionResult(condition, context)` | L110 |
| `CONDITION_REASONS` | L128 |
| `tacticalDecision({ tactic: rawTactic, role, hullRatio, hasTarget, targetVisible = hasTarget, hasLastKnown = false, targetDistance = Infinity, maxRange = 120, threatened = false, wasThreatened = false, previousState = "cruise", previousNodeId = "", lowHullCrossed = false, weaponReady = false, broadsideReady = false, commanderPresent = false })` | L130 |
| `tacticalState(input)` | L148 |

## 契约与约束
- 状态动作和条件来自稳定枚举；状态定义可导出供后续开发读取，但不执行用户脚本。
- 每条转移包含 conditions 数组与 all/any 聚合方式；旧 condition 字段自动迁移为单条件数组。
- 同一状态的转移按数组顺序判定，第一条满足者生效；图上限 20 状态、80 转移。

模块索引：[SNBattleSim](../README.md)
