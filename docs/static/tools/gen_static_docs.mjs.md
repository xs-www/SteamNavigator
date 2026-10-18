# `tools/gen_static_docs.mjs`

> 作用：静态文档生成器：读取本文件的 FILE_DOCS/MODULES，生成镜像文档、模块 README、总计索引与带 SHA-256 的 manifest。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ROOT` | L18 |
| `DOC_ROOT` | L19 |
| `MODE` | L20 |
| `RULE_VERSION` | L21 |
| `STATIC_COPY_PAGES` | L22 |
| `MODULE_PATHS` | L26 |
| `SKIP_SOURCES` | L45 |
| `MODULE_OF` | L52 |
| `GROUP_README` | L61 |
| `walk(dir, out = [])` | L64 |
| `read(relativePath)` | L81 |
| `sha256(relativePath)` | L85 |
| `lineAt(text, index)` | L89 |
| `extractSymbols(relativePath, text)` | L93 |
| `sourceTypeLabel(source)` | L144 |
| `ensureDir(dirPath)` | L154 |
| `writeDoc(relativePath, content)` | L158 |
| `perFileDoc(source)` | L164 |
| `fallbackRole(source)` | L220 |
| `moduleSources(modulePath)` | L237 |
| `renderModuleReadme(modulePath)` | L244 |
| `moduleDescription(modulePath)` | L285 |
| `main()` | L289 |

## 契约与约束

- GDScript 符号按 `class_name/signal/const/func` 提取；`.js/.mjs` 额外提取顶层 function、常量与 `root.SN*` 导出。
- 生成前清空 `docs/static`；`SKIP_SOURCES` 中的生成物不进入文档与 manifest。
- `STATIC_COPY_PAGES` 把策展型设计文档复制进静态索引，避免清理时丢失非源码页面。
- 修改规则或分类后重新运行；`commit` 取当前 HEAD 短哈希。

模块索引：[tools](./README.md)
