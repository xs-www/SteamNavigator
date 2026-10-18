# `framework/modding/schema_validator.gd`

> 作用：项目自带的 JSON Schema 子集校验器，支持本地与同目录文件 `$ref`。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SchemaValidator` | L1 |
| `validate(instance: Variant, schema: Dictionary, base_dir: String = "", root_schema: Dictionary = {}) -> Array[Dictionary]` | L23 |
| `validate_file(instance: Variant, schema_path: String) -> Array[Dictionary]` | L31 |

## 契约与约束

- 支持 type/properties/required/additionalProperties/patternProperties、数组/字符串/数字约束、组合器与 `$ref`。
- 不支持远程 HTTP ref、if/then/else、dependencies、contains、format 断言。
- 错误统一为 `{path, keyword, message}`；最多 200 条，嵌套深度上限 64。
- Schema 文件必须位于 `res://schemas/` 或被其相对引用，加载结果按路径缓存。

## 重点逻辑

### `_validate(value, schema, pointer, context)`

- 先处理 `$ref` 并切换 root/base_dir；同一 schema 的递归结构依赖深度上限防环。
- 组合器使用临时错误缓冲区：anyOf/oneOf/not 的成功分支不会污染最终错误。
- 错误路径使用 JSON Pointer 转义，直接对应内容文件中的位置。

模块索引：[framework/modding](./README.md)
