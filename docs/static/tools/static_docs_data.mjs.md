# `tools/static_docs_data.mjs`

> 作用：静态文档的兼容策展数据：保留尚未迁移文件的职责/契约，并维护模块简介与分组角色。

- 类型：Node ES 模块

## 契约与约束

- 新源码优先写 `@static-doc` 文件头；不能写注释的格式使用 `docs/static_headers/<源码路径>.md`，不再新增 FILE_DOCS 条目。
- FILE_DOCS 只服务尚未迁移的旧文件；MODULES 与 GROUPED_ROLES 继续维护模块级说明和无独立页文件的兜底职责。
- 只描述源码可证实的职责与约束；符号位置由生成器扫描，不手写行号。

模块索引：[tools](./README.md)
