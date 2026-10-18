# `tools/static_docs_data.mjs`

> 作用：静态文档的策展数据：文件职责/契约/L2、模块简介与分组角色。

- 类型：Node ES 模块

## 契约与约束

- 只描述源码可证实的职责与约束；符号位置由生成器扫描，不手写行号。
- 新增源文件或模块时同步 FILE_DOCS、MODULES、GROUPED_ROLES 与 MODULE_PATHS。

模块索引：[tools](./README.md)
