# `SNModMaker/js/validate.js`

> 作用：JSON Schema 子集校验器与 Steam Navigator 项目语义校验：Schema 版本、ID、引用、本地化、补丁与清单一致性。

- 关键依赖：`schema-bundle.js`、`catalog.js`、`core-index.js（可选外部引用检查）`
- 类型：浏览器经典脚本

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MAX_ERRORS` | L19 |
| `MAX_DEPTH` | L20 |
| `SEMVER_RE` | L21 |
| `MOD_ID_RE` | L22 |
| `ID_REF_RE` | L23 |
| `ASSET_URI_RE` | L24 |
| `ASSET_EXTENSIONS` | L25 |
| `FORBIDDEN_EXTENSIONS` | L26 |
| `SUPPORTED_SCHEMA_VERSIONS` | L29 |
| `DEFAULT_SCHEMA_VERSION` | L30 |
| `REF_TYPE_BY_FIELD` | L32 |
| `schemas()` | L48 |
| `catalog()` | L52 |
| `schemaVersionFor(typeKeyOrFile)` | L62 |
| `normalizeSchemaPath(file)` | L73 |
| `pointerEscape(text)` | L83 |
| `pointerUnescape(text)` | L87 |
| `joinPointer(base, key)` | L91 |
| `resolveRef(ref, baseFile)` | L104 |
| `deref(schema, file, seen)` | L136 |
| `flattenObject(schema, file, seen)` | L162 |
| `typeOf(value)` | L190 |
| `matchesType(value, type)` | L196 |
| `validateSchema(instance, schema, file)` | L203 |
| `runSchemaValidation(instance, schema, context, startDepth)` | L207 |
| `parseSemver(text)` | L367 |
| `versionRangeError(text)` | L378 |
| `safePath(path)` | L395 |
| `extensionOf(path)` | L405 |
| `isForbiddenPath(path)` | L411 |
| `walkStrings(value, path, callback, depth)` | L415 |
| `referencedIdType(id)` | L430 |
| `expectedRefType(path)` | L435 |
| `LOCAL_IDENTIFIER_FIELDS` | L450 |
| `SOCKET_CLASSES` | L455 |
| `RIG_SOCKET_KINDS` | L456 |
| `checkWeaponSemantics(definition, view, add)` | L459 |
| `checkHullSocketSemantics(definition, view, add)` | L493 |
| `validateProject(project, options)` | L566 |
| `finish(issues)` | L923 |
| `byDefinition(issues)` | L932 |
| `SNValidate (global)` | L945 |

## 契约与约束

- Schema 能力与 Godot `SchemaValidator` 的常用子集对齐；不支持远程 ref、if/then/else、format 断言。
- `resolveRef` 以基准 Schema 文件所在目录解析相对 `$ref`，使 `schemas/v2/*` 能引用 `v2/common.schema.json`；顶层 basename 基准行为不变。
- `schemaVersionFor(fileOrType)` 优先显式 `schema_version`，其次类型期望版本（Phase B 的 9 类 2.0 与 weapons 草案 2.0），最后回退 1.0。
- 内容文件的 `schema_version` 只接受 1.0 / 2.0；与类型期望版本不符报 `schema_version_mismatch`，其他值报 `schema_version_unsupported`。
- `draft_content` 警告只针对仍是草案的 `weapons`；Phase B 提升的 2.0 类型不再算草案，按其 capability 报 `capability_undeclared`（未声明时）。
- `LOCAL_IDENTIFIER_FIELDS`（当前含 `flow_id`）里的字段是本地标识符，不做跨定义引用检查，修复 story `flow_id` 的假阳性 `ref_missing`；Core 导入保持 0 error。
- 武器语义校验码：`weapon_range_order`（min_range ≥ range）、`weapon_assembly_pivot`（profile 与 has_yaw/has_pitch 不一致）、`weapon_muzzle_count`、`weapon_class_modular`（warning）；船体 socket 语义码：`socket_name_duplicate` / `socket_index_duplicate` / `socket_name_prefix` / `socket_class_unknown` / `socket_kind_unknown` / `rig_socket_mast_id`（后四者为 warning）。
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

- 先跑 Manifest Schema 与内容文件 Schema，再检查 schema_version、命名空间/类型段、重复 ID、本地化覆盖、跨引用与补丁目标。
- 草案实例缺省版本按类型取 2.0，避免 v2 Schema 的 `schema_version` const 误报。
- 资源裸键按当前模组 manifest.assets 解析；asset://core/<key> 使用嵌入 Core 索引校验，其他外部模组 URI 在无法读取其清单时给出未验证提示。
- 引用本模组缺失为 error；Core 缺失为 warning（草案文件跳过）；其他命名空间只提示外部引用。
- 结果包含 counts 与 stats（定义/文件/语言/资源数量）。

模块索引：[SNModMaker](../README.md)
