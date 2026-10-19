# `SNModMaker/js/validate.js`

> 作用：JSON Schema 子集校验器与 Steam Navigator 项目语义校验：ID、引用、本地化、补丁与清单一致性。

- 关键依赖：`schema-bundle.js`、`catalog.js`、`core-index.js（可选外部引用检查）`
- 类型：浏览器经典脚本

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MAX_ERRORS` | L15 |
| `MAX_DEPTH` | L16 |
| `SEMVER_RE` | L17 |
| `MOD_ID_RE` | L18 |
| `ID_REF_RE` | L19 |
| `ASSET_URI_RE` | L20 |
| `ASSET_EXTENSIONS` | L21 |
| `FORBIDDEN_EXTENSIONS` | L22 |
| `REF_TYPE_BY_FIELD` | L25 |
| `schemas()` | L41 |
| `catalog()` | L45 |
| `pointerEscape(text)` | L49 |
| `pointerUnescape(text)` | L53 |
| `joinPointer(base, key)` | L57 |
| `resolveRef(ref, baseFile)` | L61 |
| `deref(schema, file, seen)` | L84 |
| `flattenObject(schema, file, seen)` | L110 |
| `typeOf(value)` | L138 |
| `matchesType(value, type)` | L144 |
| `validateSchema(instance, schema, file)` | L151 |
| `runSchemaValidation(instance, schema, context, startDepth)` | L155 |
| `parseSemver(text)` | L315 |
| `versionRangeError(text)` | L326 |
| `safePath(path)` | L343 |
| `extensionOf(path)` | L353 |
| `isForbiddenPath(path)` | L359 |
| `walkStrings(value, path, callback, depth)` | L363 |
| `referencedIdType(id)` | L378 |
| `expectedRefType(path)` | L383 |
| `validateProject(project, options)` | L393 |
| `finish(issues)` | L721 |
| `byDefinition(issues)` | L730 |
| `SNValidate (global)` | L743 |

## 契约与约束

- Schema 能力与 Godot `SchemaValidator` 的常用子集对齐；不支持远程 ref、if/then/else、format 断言。
- 错误路径使用 JSON Pointer；项目问题附带 `view` 提示供 UI 跳转。
- 语义规则不替代 Godot 领域校验与 Core 完整性检查；网页端只做静态内容检查。
- 实体 information.texture/model 支持当前模组裸资源键与完整 asset:// URI；当前模组和 Core 引用必须存在且格式匹配。
- 同一问题按 severity/code/message/view 去重，最多收集 300 条 Schema 错误。

## 重点逻辑

### `validateSchema(instance, schema, file)`

- 递归处理 `$ref`、allOf、anyOf/oneOf/not 探测、类型/枚举/范围/数组/对象约束。
- `additionalProperties: false` 报告未知字段；组合器探测使用独立 context，避免文件基准污染。

### `flattenObject(schema, file)`

- 合并 `$ref` 与 allOf 的 properties/required，仅用于表单渲染，不用于替代校验。

### `validateProject(project)`

- 先跑 Manifest Schema 与内容文件 Schema，再检查命名空间/类型段、重复 ID、本地化覆盖、跨引用与补丁目标。
- 资源裸键按当前模组 manifest.assets 解析；asset://core/<key> 使用嵌入 Core 索引校验，其他外部模组 URI 在无法读取其清单时给出未验证提示。
- 引用本模组缺失为 error；Core 缺失为 warning；其他命名空间只提示外部引用。
- 结果包含 counts 与 stats（定义/文件/语言/资源数量）。

模块索引：[SNModMaker](../README.md)
