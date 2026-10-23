# `framework/application/queries/expedition_view.gd`

> 作用：`expedition.view` 只读查询：输出遗迹、房间序列、当前房间/事件选项、奖励日志

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ExpeditionViewQuery` | L1 |
| `execute(_params: Dictionary, context) -> Dictionary` | L14 |

与永久遗物列表；无远征时 `active:false`，不创建 `data.expedition`。

## 契约与约束
- 字段稳定：`active / ruin_id / ruin / phase / room_index / room_count / rooms[] /
  current_room / event_id / event / event_options[] / loot_money / loot_items[] /
  log[] / relics[]`。

模块索引：[framework/application](../README.md)
