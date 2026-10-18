# `framework/modding/registries/definition_registry.gd`

> 作用：按内容类型保存定义，支持 ID/标签查询与冻结。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `DefinitionRegistry` | L1 |
| `_init(type: StringName = &"") -> void` | L15 |
| `register(definition: ContentDefinition, source_mod: String = "") -> Dictionary` | L19 |
| `get_by_id(id: String) -> ContentDefinition` | L39 |
| `contains(id: String) -> bool` | L43 |
| `get_all() -> Array[ContentDefinition]` | L47 |
| `query(required_tags: Array) -> Array[ContentDefinition]` | L54 |
| `with_tags(required_tags: Array) -> Array[ContentDefinition]` | L63 |
| `source_of(id: String) -> String` | L67 |
| `ids() -> Array[String]` | L71 |
| `size() -> int` | L75 |
| `is_frozen() -> bool` | L79 |
| `freeze() -> void` | L83 |

## 契约与约束

- 重复 ID 返回 `duplicate_id`，不覆盖。
- 冻结后注册返回 `registry_frozen`。
- 提供 contains/get_by_id/get_all/query/source_of/size/ids。

模块索引：[framework/modding](../README.md)
