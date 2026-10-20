# `framework/modding/registries/content_definition.gd`

> 作用：单条内容定义的通用 envelope 与只读数据视图，包含运行数据与新版展示资源信息。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ContentDefinition` | L1 |
| `from_raw(raw_definition: Dictionary, type: StringName, mod_id: String, file: String) -> ContentDefinition` | L19 |
| `has_tag(tag: String) -> bool` | L42 |
| `has_all_tags(required_tags: Array) -> bool` | L46 |
| `to_raw() -> Dictionary` | L53 |
| `get_data_value(key: String, fallback: Variant = null) -> Variant` | L69 |
| `get_information_value(key: String, fallback: Variant = null) -> Variant` | L73 |
| `asset_uri(field: String) -> String` | L77 |

## 契约与约束

- 包含 ID、类型、本地化键、标签、enabled、information、data、来源模组/文件与 patch 记录。
- `information` 和 `data` 与 `raw` 保持同步；注册表冻结后按约定禁止修改。
- `to_raw()` 返回深拷贝，供 Patch 与二次 Schema 校验使用。
- `asset_uri(field)` 保留完整 asset:// URI；裸键自动补成 asset://<source_mod>/<key>。

## 重点逻辑

### `from_raw(raw_definition, type, mod_id, file)`

- 深拷贝 information/data，缺失 information 归一化为空字典且不向序列化结果添加空对象。

### `asset_uri(field)`

- 空字段返回空字符串，完整逻辑 URI 原样返回，裸资源键使用定义来源模组作为命名空间。

模块索引：[framework/modding](../README.md)
