# `tools/gen_static_docs.mjs`

> 作用：从源码静态文档注释、sidecar 头文件和旧策展数据生成镜像文档、模块索引与 SHA-256 manifest。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ROOT` | L29 |
| `DOC_ROOT` | L30 |
| `HEADER_ROOT` | L31 |
| `MODE` | L32 |
| `RULE_VERSION` | L33 |
| `STATIC_COPY_PAGES` | L34 |
| `MODULE_PATHS` | L38 |
| `SKIP_SOURCES` | L59 |
| `MODULE_OF` | L67 |
| `GROUP_README` | L76 |
| `walk(dir, out = [])` | L79 |
| `read(relativePath)` | L96 |
| `sha256(relativePath)` | L100 |
| `lineAt(text, index)` | L111 |
| `extractSymbols(relativePath, text)` | L115 |
| `stripStaticDocComment(line)` | L166 |
| `parseStaticDocFragment(lines, source)` | L177 |
| `extractStaticDoc(relativePath, text)` | L192 |
| `readSidecarDoc(source)` | L211 |
| `metadataFor(source)` | L219 |
| `sourceTypeLabel(source)` | L237 |
| `ensureDir(dirPath)` | L250 |
| `writeDoc(docRoot, relativePath, content)` | L254 |
| `perFileDoc(docRoot, source)` | L260 |
| `fallbackRole(source)` | L320 |
| `repoSources()` | L342 |
| `moduleSources(modulePath)` | L357 |
| `renderModuleReadme(docRoot, modulePath)` | L366 |
| `moduleDescription(modulePath)` | L407 |
| `collectSources()` | L411 |
| `validateSidecars(sources)` | L422 |
| `inputDigests(sources)` | L434 |
| `assertInputsUnchanged(before)` | L444 |
| `currentCommit()` | L452 |
| `renderRootReadme(docRoot, generatedAt, commit)` | L462 |
| `buildDocs(docRoot, options = {})` | L536 |
| `fileDigests(root)` | L587 |
| `compareDocTrees(expectedRoot, actualRoot)` | L597 |
| `replaceDocsAtomically(tempRoot)` | L604 |
| `baselineGenerationInfo()` | L620 |
| `printHelp()` | L627 |
| `main(args = process.argv.slice(2)` | L634 |

## 契约与约束
- 新源码优先在前 120 行维护 `@static-doc`；不能写注释的格式使用 `docs/static_headers/<源码路径>.md`。
- 旧 `FILE_DOCS` 只作为迁移兼容层，优先级低于源码注释和 sidecar。
- 默认在临时目录完成构建后原子替换 `docs/static`；`--check` 只比较，不写工作区。
- 只收录仓库应有的源码（git 跟踪或未忽略）；`SNModMaker/mods` 等被 .gitignore 排除的本地工作区不进入 manifest，否则干净检出（CI）与本地生成结果不一致。
- 文本源文件按 LF 计算 SHA-256（二进制按原始字节）：Windows 工具可能写出 CRLF 工作副本，而 git 提交的文本是 LF。
- GDScript 符号提取支持普通/静态函数、推断/显式类型常量、类与信号。

模块索引：[tools](./README.md)
