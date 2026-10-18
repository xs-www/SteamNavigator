# `framework/modding/registries/content_definition.gd`

> 作用：单条内容定义的通用 envelope 与只读数据视图。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ContentDefinition` | L1 |
| `has_tag(tag: String) -> bool` | L35 |
| `has_all_tags(required_tags: Array) -> bool` | L39 |
| `to_raw() -> Dictionary` | L46 |
| `get_data_value(key: String, fallback: Variant = null) -> Variant` | L58 |

## 契约与约束

- 包含 ID、类型、本地化键、标签、enabled、data、来源模组/文件与 patch 记录。
- `data` 与 `raw` 共享运行期引用；注册表冻结后按约定禁止修改。
- `to_raw()` 返回深拷贝，供 Patch 与二次 Schema 校验使用。

模块索引：[framework/modding](../README.md)
