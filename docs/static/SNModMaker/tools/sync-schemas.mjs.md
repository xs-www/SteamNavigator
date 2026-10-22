# `SNModMaker/tools/sync-schemas.mjs`

> 作用：把 `schemas/` 下全部 `*.schema.json`（含 `v2/` 草案）递归打包为可直接 `<script>` 引入的 `js/schema-bundle.js`。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `collectSchemas(directory)` | L24 |

## 契约与约束

- bundle key 是相对 `schemas/` 的 posix 路径：顶层仍是 basename，`v2/`（含 Phase B 9 类、C1 module/hull、C2 item、C3 quest 与 weapon/story 草案）为 `v2/...`，与磁盘文件一一对应（当前 27 个：10 顶层 + 17 个 v2）。
- 生成文件头带 AUTO-GENERATED 标记；修改任何 Schema 后必须重跑。
- 只做 JSON 解析与嵌入，不校验 Schema 自身。

模块索引：[SNModMaker](../README.md)
