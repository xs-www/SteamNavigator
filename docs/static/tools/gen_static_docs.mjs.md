# `tools/gen_static_docs.mjs`

> 作用：从源码静态文档注释、sidecar 头文件和旧策展数据生成镜像文档、模块索引与 SHA-256 manifest。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ROOT` | L28 |
| `DOC_ROOT` | L29 |
| `HEADER_ROOT` | L30 |
| `MODE` | L31 |
| `RULE_VERSION` | L32 |
| `STATIC_COPY_PAGES` | L33 |
| `MODULE_PATHS` | L37 |
| `SKIP_SOURCES` | L58 |
| `MODULE_OF` | L66 |
| `GROUP_README` | L75 |
| `walk(dir, out = [])` | L78 |
| `read(relativePath)` | L95 |
| `sha256(relativePath)` | L99 |
| `lineAt(text, index)` | L103 |
| `extractSymbols(relativePath, text)` | L107 |
| `stripStaticDocComment(line)` | L158 |
| `parseStaticDocFragment(lines, source)` | L169 |
| `extractStaticDoc(relativePath, text)` | L184 |
| `readSidecarDoc(source)` | L203 |
| `metadataFor(source)` | L211 |
| `sourceTypeLabel(source)` | L229 |
| `ensureDir(dirPath)` | L242 |
| `writeDoc(docRoot, relativePath, content)` | L246 |
| `perFileDoc(docRoot, source)` | L252 |
| `fallbackRole(source)` | L312 |
| `repoSources()` | L334 |
| `moduleSources(modulePath)` | L349 |
| `renderModuleReadme(docRoot, modulePath)` | L358 |
| `moduleDescription(modulePath)` | L399 |
| `collectSources()` | L403 |
| `validateSidecars(sources)` | L414 |
| `inputDigests(sources)` | L426 |
| `assertInputsUnchanged(before)` | L436 |
| `currentCommit()` | L444 |
| `renderRootReadme(docRoot, generatedAt, commit)` | L454 |
| `buildDocs(docRoot, options = {})` | L528 |
| `fileDigests(root)` | L579 |
| `compareDocTrees(expectedRoot, actualRoot)` | L589 |
| `replaceDocsAtomically(tempRoot)` | L596 |
| `baselineGenerationInfo()` | L612 |
| `printHelp()` | L619 |
| `main(args = process.argv.slice(2)` | L626 |

## 契约与约束
- 新源码优先在前 120 行维护 `@static-doc`；不能写注释的格式使用 `docs/static_headers/<源码路径>.md`。
- 旧 `FILE_DOCS` 只作为迁移兼容层，优先级低于源码注释和 sidecar。
- 默认在临时目录完成构建后原子替换 `docs/static`；`--check` 只比较，不写工作区。
- 只收录仓库应有的源码（git 跟踪或未忽略）；`SNModMaker/mods` 等被 .gitignore 排除的本地工作区不进入 manifest，否则干净检出（CI）与本地生成结果不一致。
- GDScript 符号提取支持普通/静态函数、推断/显式类型常量、类与信号。

模块索引：[tools](./README.md)
