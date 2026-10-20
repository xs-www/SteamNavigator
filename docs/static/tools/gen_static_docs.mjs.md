# `tools/gen_static_docs.mjs`

> 作用：从源码静态文档注释、sidecar 头文件和旧策展数据生成镜像文档、模块索引与 SHA-256 manifest。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ROOT` | L27 |
| `DOC_ROOT` | L28 |
| `HEADER_ROOT` | L29 |
| `MODE` | L30 |
| `RULE_VERSION` | L31 |
| `STATIC_COPY_PAGES` | L32 |
| `MODULE_PATHS` | L36 |
| `SKIP_SOURCES` | L57 |
| `MODULE_OF` | L65 |
| `GROUP_README` | L74 |
| `walk(dir, out = [])` | L77 |
| `read(relativePath)` | L94 |
| `sha256(relativePath)` | L98 |
| `lineAt(text, index)` | L102 |
| `extractSymbols(relativePath, text)` | L106 |
| `stripStaticDocComment(line)` | L157 |
| `parseStaticDocFragment(lines, source)` | L168 |
| `extractStaticDoc(relativePath, text)` | L183 |
| `readSidecarDoc(source)` | L202 |
| `metadataFor(source)` | L210 |
| `sourceTypeLabel(source)` | L228 |
| `ensureDir(dirPath)` | L241 |
| `writeDoc(docRoot, relativePath, content)` | L245 |
| `perFileDoc(docRoot, source)` | L251 |
| `fallbackRole(source)` | L311 |
| `moduleSources(modulePath)` | L328 |
| `renderModuleReadme(docRoot, modulePath)` | L335 |
| `moduleDescription(modulePath)` | L376 |
| `collectSources()` | L380 |
| `validateSidecars(sources)` | L391 |
| `inputDigests(sources)` | L403 |
| `assertInputsUnchanged(before)` | L413 |
| `currentCommit()` | L421 |
| `renderRootReadme(docRoot, generatedAt, commit)` | L431 |
| `buildDocs(docRoot, options = {})` | L505 |
| `fileDigests(root)` | L556 |
| `compareDocTrees(expectedRoot, actualRoot)` | L566 |
| `replaceDocsAtomically(tempRoot)` | L573 |
| `baselineGenerationInfo()` | L589 |
| `printHelp()` | L596 |
| `main(args = process.argv.slice(2)` | L603 |

## 契约与约束
- 新源码优先在前 120 行维护 `@static-doc`；不能写注释的格式使用 `docs/static_headers/<源码路径>.md`。
- 旧 `FILE_DOCS` 只作为迁移兼容层，优先级低于源码注释和 sidecar。
- 默认在临时目录完成构建后原子替换 `docs/static`；`--check` 只比较，不写工作区。
- GDScript 符号提取支持普通/静态函数、推断/显式类型常量、类与信号。

模块索引：[tools](./README.md)
