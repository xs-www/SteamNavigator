# `tools/gen_content_types.mjs`

> 作用：从 content_types.json 生成框架 ContentTypes 与 SNModMaker 的类型目录（active `TYPES` + Schema 2.0 草案 `DRAFT_TYPES`）；提供 `--check` 过期检查。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ROOT` | L17 |
| `MANIFEST` | L18 |
| `GD_OUTPUT` | L19 |
| `JS_OUTPUT` | L20 |
| `CHECK` | L21 |
| `fail(message)` | L23 |
| `readJson(relativePath)` | L28 |
| `schemaVersionFromSchema(versionField)` | L41 |
| `readManifest()` | L51 |
| `validate(data)` | L66 |
| `validateDraftTypes(data, context)` | L128 |
| `constantName(type)` | L180 |
| `generatedHeader(commentPrefix)` | L184 |
| `renderGd(data)` | L191 |
| `renderJs(data)` | L268 |
| `SNContentTypes (global)` | L329 |
| `compareOrWrite(relativePath, content)` | L334 |

## 契约与约束

- 单一真源是 `content_types.json`；生成物 `framework/modding/content_types.gd` 与 `SNModMaker/js/content-types.js` 禁止手改。
- 生成前校验格式版本、key/singular/schema 唯一、分组与 v2 模块分类引用、Schema 文件存在、Patch 数量、planned 不覆盖 active、draft_schemas 只指向 planned 类型。
- `draft_types` 必须与 `draft_schemas` 键集合完全一致，且不得自带 schema 路径；生成器校验 singular/abbr/color/default_file 唯一、group 已声明、`schema_version` 等于对应 Schema 的 const、capability 等于该类型所属 planned system 的 capability。
- `framework/modding/content_types.gd` 只输出可加载的 active 类型（C4 后 20 类全部为 2.0）；草案仅进入编辑器与 CLI 的 `DRAFT_TYPES`；编辑器 `TYPES` 条目同时输出 `capability` 供 2.0 capability 校验。
- `--check` 不写文件，生成物缺失或过期时以退出码 1 结束，供 CI/发布门禁使用。

模块索引：[tools](./README.md)
