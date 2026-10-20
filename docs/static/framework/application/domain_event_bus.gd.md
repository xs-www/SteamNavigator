# `framework/application/domain_event_bus.gd`

> 作用：已提交领域事件的 envelope、历史与订阅信号。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `DomainEventBus` | L1 |
| `event_published (signal)` | L5 |
| `MAX_HISTORY` | L7 |
| `SCHEMA_VERSION` | L8 |
| `publish(event_type: StringName, payload: Dictionary = {}, game_time: float = 0.0, source: String = "framework") -> Dictionary` | L16 |
| `publish_many(events: Array, game_time: float = 0.0, source: String = "framework") -> Array[Dictionary]` | L33 |
| `get_history(event_type: StringName = &"", limit: int = 100) -> Array[Dictionary]` | L46 |
| `last_event(event_type: StringName = &"") -> Dictionary` | L55 |
| `has_event(event_type: StringName) -> bool` | L60 |
| `count() -> int` | L64 |
| `clear() -> void` | L68 |

## 契约与约束

- 事件 envelope 包含 event_id/event_type/game_time/source/payload/schema_version。
- 只发布已提交事实；历史最多 500 条，按需截取。
- 订阅者用于 UI 刷新/表现，不承担规则计算。

模块索引：[framework/application](./README.md)
