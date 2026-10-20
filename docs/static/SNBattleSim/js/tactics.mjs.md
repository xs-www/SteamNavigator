# `SNBattleSim/js/tactics.mjs`

> 作用：定义可随舰船配置保存的声明式战术状态机，并把战场量测转换为侦索、接近、交战、脱离或规避状态。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `normalizeTactic(value = {})` | L31 |
| `tacticalDecision({ tactic: rawTactic, role, hullRatio, hasTarget, targetDistance = Infinity, maxRange = 120, threatened = false, wasThreatened = false, previousState = "search", previousReason = "", lowHullCrossed = false })` | L48 |
| `tacticalState(input)` | L62 |

## 契约与约束
- 战术配置只包含受限枚举、布尔值和限幅数值，不执行用户脚本。
- 脱离状态使用进入/退出双阈值；低耐久仅在首次跌破阈值时触发，避免永久锁定。
- 状态判定保持确定性；同一战场量测、前态与配置必须得到相同状态。
- 旧配置缺少 tactic 时由 normalizeTactic 补齐默认战术。

模块索引：[SNBattleSim](../README.md)
