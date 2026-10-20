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
| `SKIP_SOURCES` | L56 |
| `MODULE_OF` | L64 |
| `GROUP_README` | L73 |
| `walk(dir, out = [])` | L76 |
| `read(relativePath)` | L93 |
| `sha256(relativePath)` | L97 |
| `lineAt(text, index)` | L101 |
| `extractSymbols(relativePath, text)` | L105 |
| `stripStaticDocComment(line)` | L156 |
| `parseStaticDocFragment(lines, source)` | L167 |
| `extractStaticDoc(relativePath, text)` | L182 |
| `readSidecarDoc(source)` | L201 |
| `metadataFor(source)` | L209 |
| `sourceTypeLabel(source)` | L227 |
| `ensureDir(dirPath)` | L240 |
| `writeDoc(docRoot, relativePath, content)` | L244 |
| `perFileDoc(docRoot, source)` | L250 |
| `fallbackRole(source)` | L310 |
| `moduleSources(modulePath)` | L327 |
| `renderModuleReadme(docRoot, modulePath)` | L334 |
| `moduleDescription(modulePath)` | L375 |
| `collectSources()` | L379 |
| `validateSidecars(sources)` | L390 |
| `inputDigests(sources)` | L402 |
| `assertInputsUnchanged(before)` | L412 |
| `currentCommit()` | L420 |
| `renderRootReadme(docRoot, generatedAt, commit)` | L430 |
| `buildDocs(docRoot, options = {})` | L503 |
| `fileDigests(root)` | L554 |
| `compareDocTrees(expectedRoot, actualRoot)` | L564 |
| `replaceDocsAtomically(tempRoot)` | L571 |
| `baselineGenerationInfo()` | L587 |
| `printHelp()` | L594 |
| `main(args = process.argv.slice(2)` | L601 |

## 契约与约束
- 新源码优先在前 120 行维护 `@static-doc`；不能写注释的格式使用 `docs/static_headers/<源码路径>.md`。
- 旧 `FILE_DOCS` 只作为迁移兼容层，优先级低于源码注释和 sidecar。
- 默认在临时目录完成构建后原子替换 `docs/static`；`--check` 只比较，不写工作区。
- GDScript 符号提取支持普通/静态函数、推断/显式类型常量、类与信号。

模块索引：[tools](./README.md)
