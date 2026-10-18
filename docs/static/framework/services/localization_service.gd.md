# `framework/services/localization_service.gd`

> 作用：合并框架与模组本地化表，提供活动语言回退与缺失检测。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `LocalizationService` | L1 |
| `_init(locale: String = "zh_CN", logger: AppLogger = null) -> void` | L20 |
| `load_base_tables() -> void` | L25 |
| `load_file(source: ModSource, relative_path: String, mod_id: String) -> Dictionary` | L37 |
| `add_table(table: Dictionary, mod_id: String, locale: String) -> void` | L63 |
| `set_locale(locale: String) -> void` | L92 |
| `tr_key(key: String, fallback: String = "") -> String` | L96 |
| `tr_format(key: String, args: Array, fallback: String = "") -> String` | L108 |
| `has_key(key: String, locale: String = "") -> bool` | L115 |
| `count(locale: String = "") -> int` | L120 |
| `available_locales() -> PackedStringArray` | L125 |
| `missing_keys(keys: Array, locale: String = "") -> Array[String]` | L133 |
| `source_of(key: String, locale: String = "") -> String` | L141 |

## 契约与约束

- 同名键后加载模组覆盖先加载者，并记录 duplicates 警告。
- 查询顺序：活动语言 → en → 调用方 fallback → 键名。
- CSV 本地化不支持，必须在打包前转换为 JSON。

模块索引：[framework/services](./README.md)
