# `SNModMaker/tools/sync-core-index.mjs`

> 作用：从 `dev_mods/core` 生成 `js/core-index.js`：Manifest、内容文件、双语本地化与定义索引。

- 类型：Node ES 模块

## 契约与约束

- 索引用于引用候选、中文名、外部引用检查与从 Core 复制。
- 修改 Core 内容或本地化后必须重跑。

模块索引：[SNModMaker](../README.md)
