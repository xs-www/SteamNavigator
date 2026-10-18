# `SNModMaker/tools/sync-schemas.mjs`

> 作用：把 `schemas/*.schema.json` 打包为可直接 `<script>` 引入的 `js/schema-bundle.js`。

- 类型：Node ES 模块

## 契约与约束

- 生成文件头带 AUTO-GENERATED 标记；修改 Schema 后必须重跑。
- 只做 JSON 解析与嵌入，不校验 Schema 自身。

模块索引：[SNModMaker](../README.md)
