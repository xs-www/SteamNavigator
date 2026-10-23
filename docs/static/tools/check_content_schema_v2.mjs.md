# `tools/check_content_schema_v2.mjs`

> 作用：Phase E 发布门禁：确认 Content Schema 1.0 已冻结，内容类型、Schema 文件与

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `readJson(file)` | L25 |
| `rel(file)` | L34 |
| `schemaExists(relPath)` | L38 |
| `scanContentDir(dir)` | L97 |

Core/SDK 内容 envelope 全部为 2.0；发现 1.0 或非 2.0 内容时以清晰错误退出。

## 契约与约束
- 读取 `content_types.json`：所有 active 类型与草案类型必须声明 2.0，且 schema 路径存在。
- `FrameworkInfo.CONTENT_SCHEMA` 必须是 "2.0"（存档 header 基线）。
- `schemas/` 顶层只允许 common/manifest，其余类型 Schema 必须位于 `schemas/v2/`。
- 扫描 `dev_mods/core/content`、`sdk/examples/*/content`、`sdk/templates/*/content`
  的 `.json` 内容文件：带 `content_type` 的 envelope 的 `schema_version` 必须是 2.0。
- 退出码 0 = 全部通过；1 = 存在违规；2 = 输入读取失败。
- 无外部依赖，可在 CI / 本地任意 Node 22+ 运行。

模块索引：[tools](./README.md)
