# `SNBattleSim/js/combat_hud.mjs`

> 作用：把战斗中单个武器挂载的冷却数据转换为舰船头顶装填条可直接使用的显示状态。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `clamp(value, min, max)` | L9 |
| `mountReloadState(mount)` | L11 |

## 契约与约束
- 冷却为零时返回“就绪”；装填中按一位小数显示剩余秒数。
- progress 表示从刚开火的 0 到装填完成的 1，并始终限制在 0–1。

模块索引：[SNBattleSim](../README.md)
