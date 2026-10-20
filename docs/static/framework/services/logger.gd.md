# `framework/services/logger.gd`

> 作用：有界结构化日志（DEBUG–FATAL），带模组/文件上下文字段。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `AppLogger` | L1 |
| `LEVEL_NAMES` | L7 |
| `MAX_ENTRIES` | L8 |
| `_init(minimum: int = Level.INFO, echo: bool = true) -> void` | L17 |
| `debug(message: String, fields: Dictionary = {}) -> void` | L22 |
| `info(message: String, fields: Dictionary = {}) -> void` | L26 |
| `warn(message: String, fields: Dictionary = {}) -> void` | L30 |
| `error(message: String, fields: Dictionary = {}) -> void` | L34 |
| `fatal(message: String, fields: Dictionary = {}) -> void` | L38 |
| `get_entries(minimum: int = Level.DEBUG, limit: int = 200) -> Array[Dictionary]` | L64 |
| `to_text() -> String` | L73 |
| `clear() -> void` | L80 |
| `count() -> int` | L85 |

## 契约与约束

- 最多保留 1000 条，超出丢弃最旧。
- 默认 INFO 以上输出到控制台；测试可关闭 echo。
- 条目包含 seq、UTC 时间、级别、消息与 fields。

模块索引：[framework/services](./README.md)
