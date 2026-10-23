# `SNModMaker/js/validate.js`

> 作用：JSON Schema 子集校验器与 Steam Navigator 项目语义校验：Schema 版本、ID、引用、本地化、补丁、清单一致性，以及剧情模式（故事包白名单 / 篇章 / 关卡固定地图与任务线）语义。

- 关键依赖：`schema-bundle.js`、`catalog.js`、`core-index.js（可选外部引用检查）`
- 类型：浏览器经典脚本

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MAX_ERRORS` | L22 |
| `MAX_DEPTH` | L23 |
| `SEMVER_RE` | L24 |
| `MOD_ID_RE` | L25 |
| `ID_REF_RE` | L26 |
| `ASSET_URI_RE` | L27 |
| `ASSET_EXTENSIONS` | L28 |
| `FORBIDDEN_EXTENSIONS` | L29 |
| `SUPPORTED_SCHEMA_VERSIONS` | L33 |
| `DEFAULT_SCHEMA_VERSION` | L34 |
| `REF_TYPE_BY_FIELD` | L36 |
| `schemas()` | L76 |
| `catalog()` | L80 |
| `schemaVersionFor(typeKeyOrFile)` | L91 |
| `normalizeSchemaPath(file)` | L102 |
| `pointerEscape(text)` | L112 |
| `pointerUnescape(text)` | L116 |
| `joinPointer(base, key)` | L120 |
| `resolveRef(ref, baseFile)` | L133 |
| `deref(schema, file, seen)` | L165 |
| `flattenObject(schema, file, seen)` | L191 |
| `typeOf(value)` | L219 |
| `matchesType(value, type)` | L225 |
| `validateSchema(instance, schema, file)` | L232 |
| `runSchemaValidation(instance, schema, context, startDepth)` | L236 |
| `parseSemver(text)` | L396 |
| `versionRangeError(text)` | L407 |
| `safePath(path)` | L424 |
| `extensionOf(path)` | L434 |
| `isForbiddenPath(path)` | L440 |
| `walkStrings(value, path, callback, depth)` | L444 |
| `referencedIdType(id)` | L459 |
| `expectedRefType(path)` | L464 |
| `LOCAL_IDENTIFIER_FIELDS` | L479 |
| `SOCKET_CLASSES` | L484 |
| `RIG_SOCKET_KINDS` | L485 |
| `checkWeaponSemantics(definition, view, add)` | L488 |
| `checkCombatAIProfileSemantics(definition, view, add)` | L522 |
| `checkLootTableSemantics(definition, view, add)` | L554 |
| `checkHullSocketSemantics(definition, view, add)` | L570 |
| `QUEST_EVENT_RE` | L652 |
| `checkQuestSemantics(definition, view, add)` | L655 |
| `STORY_TYPES` | L685 |
| `storyFieldView(view, field)` | L687 |
| `checkStoryArcSemantics(definition, view, add)` | L692 |
| `checkStoryLevelSemantics(definition, view, add)` | L736 |
| `checkStoryPack(contentFiles, add)` | L844 |
| `validateProject(project, options)` | L885 |
| `finish(issues)` | L1259 |
| `byDefinition(issues)` | L1268 |
| `SNValidate (global)` | L1281 |

## 契约与约束

- Schema 能力与 Godot `SchemaValidator` 的常用子集对齐；不支持远程 ref、if/then/else、format 断言。
- `resolveRef` 以基准 Schema 文件所在目录解析相对 `$ref`，使 `schemas/v2/*` 能引用 `v2/common.schema.json`；顶层 basename 基准行为不变。
- `schemaVersionFor(fileOrType)` 优先显式 `schema_version`，其次类型期望版本（D2 后全部 active 类型为 2.0；story_arcs / story_levels 草案为 2.0），未知类型最后回退 1.0。
- 内容文件的 `schema_version` 只接受 1.0 / 2.0；与类型期望版本不符报 `schema_version_mismatch`，其他值报 `schema_version_unsupported`。
- `draft_content` 警告只针对仍是草案的 `story_arcs` / `story_levels`；active 2.0 类型（D5 后全部 42 类）不再算草案，`capability_undeclared` 按 `schemaVersion = 2.0` 判定（42 类 + 草案族），同一 capability 每次校验只报一条。
- `LOCAL_IDENTIFIER_FIELDS`（当前含 `flow_id`）里的字段是本地标识符，不做跨定义引用检查，修复 story `flow_id` 的假阳性 `ref_missing`；Core 导入保持 0 error。
- `REF_TYPE_BY_FIELD` 覆盖剧情引用：`levels` → story_level、`map_config` → map_config、`starting_scenario` → starting_scenario，与已有的 hull / good 等字段共用 `ref_type` 提示。
- 武器语义校验码：`weapon_range_order`（min_range ≥ range）、`weapon_assembly_pivot`（profile 与 has_yaw/has_pitch 不一致）、`weapon_muzzle_count`、`weapon_class_modular`（warning）；船体 socket 语义码：`socket_name_duplicate` / `socket_index_duplicate` / `socket_name_prefix` / `socket_class_unknown` / `socket_kind_unknown` / `rig_socket_mast_id`（后四者为 warning）。
- 剧情语义码：`story_pack_off_whitelist`（故事包混入非剧情内容，error）、`story_arc_level_type`（篇章关卡列表只能引用 story_level）、`story_protagonist_unknown`、`story_character_duplicate`、`story_stage_duplicate`、`story_level_checkpoint_missing`、`story_beat_stage_unknown`、`story_fail_default_not_allowed`、`story_fixed_port_duplicate`、`story_fixed_start_port_unknown`、`story_fixed_edge_port_unknown`、`story_start_port_unknown`；`story_arc_empty_levels` / `story_level_orphan` / `story_fixed_map_disconnected` / `story_term_duplicate` / `story_multiple_protagonists` 为 warning（空篇章与暂存关卡不阻塞编辑器/CLI 写入）。
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

### `checkStoryArcSemantics(definition, view, add)`

- 校验 protagonist_id 在 characters 中、角色 ID 不重复、至多一个 protagonist；levels 为空只给 warning。

### `checkStoryLevelSemantics(definition, view, add)`

- 校验阶段 ID 唯一、至少一个 checkpoint、叙事 beat 的 stage_id 属于本关、fail.default_mode 在 allow 中。
- 校验固定地图港口 ID 唯一、start_port / start.port_id / 航道两端都引用已声明港口，并用 BFS 报告从起点走不到的港口（warning）。

### `checkStoryPack(contentFiles, add)`

- 出现剧情内容文件时，任何非 story_arcs / story_levels 内容都报 `story_pack_off_whitelist`，保证故事包无法改动自由模式。
- 篇章 levels 只能引用 story_level；未被任何篇章引用的关卡给 `story_level_orphan` warning。

### `validateProject(project)`

- 先跑 Manifest Schema 与内容文件 Schema，再检查 schema_version、命名空间/类型段、重复 ID、本地化覆盖、跨引用与补丁目标。
- 草案实例缺省版本按类型取 2.0，避免 v2 Schema 的 `schema_version` const 误报。
- 资源裸键按当前模组 manifest.assets 解析；asset://core/<key> 使用嵌入 Core 索引校验，其他外部模组 URI 在无法读取其清单时给出未验证提示。
- 引用本模组缺失为 error；Core 缺失为 warning（草案文件跳过）；其他命名空间只提示外部引用。
- 内容文件循环内按类型调用武器 / 船体 / 篇章 / 关卡语义检查，循环后调用一次故事包白名单检查。
- 结果包含 counts 与 stats（定义/文件/语言/资源数量）。

模块索引：[SNModMaker](../README.md)
