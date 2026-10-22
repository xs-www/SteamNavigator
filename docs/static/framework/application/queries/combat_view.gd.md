# `framework/application/queries/combat_view.gd`

> 作用：`combat.view` 只读查询：输出玩家当前武装 / 结构耐久、可选遭遇表摘要与最近

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `CombatViewQuery` | L1 |
| `execute(_params: Dictionary, context) -> Dictionary` | L18 |

一场战斗结果，供调试 UI 与 D1 验收使用。

## 契约与约束
- 只读：不创建 `data.combat` 块；无 run / 旧档返回 `{has_run:false, player:null,
  encounters:[], last_battle:null}`，形状稳定。
- `player.weapons` 是 `CombatOps.player_weapon_rows` 的行（socket / weapon_id /
  weapon_class / damage / range / cooldown / accuracy）；`unmounted_sockets` 暴露
  没有可用武器定义的 hull socket（内容缺口可见）。
- `encounters` 按 id 排序，字段 `{id, name_key, description_key, kind, danger,
  entry_count}`；`last_battle` 是 `data.combat.battles` 最后一条的深拷贝。

模块索引：[framework/application](../README.md)
