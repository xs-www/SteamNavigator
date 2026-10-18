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
| `MODULE_PATHS` | L23 |
| `SKIP_SOURCES` | L42 |
| `MODULE_OF` | L49 |
| `GROUP_README` | L58 |
| `walk(dir, out = [])` | L61 |
| `read(relativePath)` | L78 |
| `sha256(relativePath)` | L82 |
| `lineAt(text, index)` | L86 |
| `extractSymbols(relativePath, text)` | L90 |
| `sourceTypeLabel(source)` | L141 |
| `ensureDir(dirPath)` | L151 |
| `writeDoc(relativePath, content)` | L155 |
| `perFileDoc(source)` | L161 |
| `fallbackRole(source)` | L217 |
| `moduleSources(modulePath)` | L234 |
| `renderModuleReadme(modulePath)` | L241 |
| `moduleDescription(modulePath)` | L282 |
| `main()` | L286 |

## 契约与约束

- GDScript 符号按 `class_name/signal/const/func` 提取；`.js/.mjs` 额外提取顶层 function、常量与 `root.SN*` 导出。
- 生成前清空 `docs/static`；`SKIP_SOURCES` 中的生成物不进入文档与 manifest。
- 修改规则或分类后重新运行；`commit` 取当前 HEAD 短哈希。

模块索引：[tools](./README.md)
