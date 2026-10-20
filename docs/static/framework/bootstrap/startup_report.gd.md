# `framework/bootstrap/startup_report.gd`

> 作用：启动结果 DTO：分级错误/警告、启用模组摘要、内容计数、耗时与注册表状态。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `StartupReport` | L1 |
| `STATUS_NAMES` | L7 |
| `add_error(code: String, message: String, fields: Dictionary = {}) -> void` | L24 |
| `add_warning(code: String, message: String, fields: Dictionary = {}) -> void` | L35 |
| `add_fatal(code: String, message: String, fields: Dictionary = {}) -> void` | L42 |
| `has_fatal() -> bool` | L48 |
| `fatal_errors() -> Array[Dictionary]` | L55 |
| `finalize() -> void` | L63 |
| `status_name() -> String` | L74 |
| `status_key() -> String` | L78 |
| `is_ok() -> bool` | L82 |
| `content_total() -> int` | L86 |
| `to_dict() -> Dictionary` | L93 |
| `format_text() -> String` | L111 |

## 契约与约束

- 状态分级：任一 `severity=fatal` → FATAL；否则有错误/警告/禁用模组 → DEGRADED；否则 OK。
- `to_dict()` 输出可直接给 UI/JSON 诊断；`format_text()` 用于控制台与无头测试。
- Core 加载失败必须体现为 fatal，而不是仅记录普通错误。

模块索引：[framework/bootstrap](./README.md)
