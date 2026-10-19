# `tools/gen_content_types.mjs`

> 作用：从 content_types.json 生成框架 ContentTypes 与 SNModMaker 的类型目录；提供 `--check` 过期检查。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ROOT` | L15 |
| `MANIFEST` | L16 |
| `GD_OUTPUT` | L17 |
| `JS_OUTPUT` | L18 |
| `CHECK` | L19 |
| `fail(message)` | L21 |
| `readManifest()` | L26 |
| `validate(data)` | L41 |
| `constantName(type)` | L94 |
| `generatedHeader(commentPrefix)` | L98 |
| `renderGd(data)` | L105 |
| `renderJs(data)` | L174 |
| `SNContentTypes (global)` | L208 |
| `compareOrWrite(relativePath, content)` | L213 |

## 契约与约束

- 单一真源是 `content_types.json`；生成物 `framework/modding/content_types.gd` 与 `SNModMaker/js/content-types.js` 禁止手改。
- 生成前校验格式版本、key/singular/schema 唯一、分组与 v2 模块分类引用、Schema 文件存在、Patch 数量、planned 不覆盖 active、draft_schemas 只指向 planned 类型。
- `--check` 不写文件，生成物缺失或过期时以退出码 1 结束，供 CI/发布门禁使用。

模块索引：[tools](./README.md)
