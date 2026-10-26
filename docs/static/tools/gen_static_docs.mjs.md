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
| `SKIP_SOURCES` | L61 |
| `MODULE_OF` | L70 |
| `GROUP_README` | L79 |
| `walk(dir, out = [])` | L82 |
| `read(relativePath)` | L99 |
| `sha256(relativePath)` | L103 |
| `lineAt(text, index)` | L114 |
| `extractSymbols(relativePath, text)` | L118 |
| `stripStaticDocComment(line)` | L169 |
| `parseStaticDocFragment(lines, source)` | L183 |
| `extractStaticDoc(relativePath, text)` | L198 |
| `readSidecarDoc(source)` | L219 |
| `metadataFor(source)` | L227 |
| `sourceTypeLabel(source)` | L245 |
| `ensureDir(dirPath)` | L258 |
| `writeDoc(docRoot, relativePath, content)` | L262 |
| `perFileDoc(docRoot, source)` | L268 |
| `fallbackRole(source)` | L328 |
| `repoSources()` | L350 |
| `moduleSources(modulePath)` | L365 |
| `renderModuleReadme(docRoot, modulePath)` | L374 |
| `moduleDescription(modulePath)` | L415 |
| `collectSources()` | L419 |
| `validateSidecars(sources)` | L430 |
| `inputDigests(sources)` | L442 |
| `assertInputsUnchanged(before)` | L452 |
| `currentCommit()` | L460 |
| `renderRootReadme(docRoot, generatedAt, commit)` | L470 |
| `buildDocs(docRoot, options = {})` | L546 |
| `fileDigests(root)` | L597 |
| `compareDocTrees(expectedRoot, actualRoot)` | L607 |
| `replaceDocsAtomically(tempRoot)` | L614 |
| `baselineGenerationInfo()` | L630 |
| `printHelp()` | L637 |
| `main(args = process.argv.slice(2)` | L644 |

## 契约与约束
- 新源码优先在前 120 行维护 `@static-doc`；不能写注释的格式使用 `docs/static_headers/<源码路径>.md`。
- 旧 `FILE_DOCS` 只作为迁移兼容层，优先级低于源码注释和 sidecar。
- 默认在临时目录完成构建后原子替换 `docs/static`；`--check` 只比较，不写工作区。
- 只收录仓库应有的源码（git 跟踪或未忽略）；`SNModMaker/mods` 等被 .gitignore 排除的本地工作区不进入 manifest，否则干净检出（CI）与本地生成结果不一致。
- 文本源文件按 LF 计算 SHA-256（二进制按原始字节）：Windows 工具可能写出 CRLF 工作副本，而 git 提交的文本是 LF。
- GDScript 符号提取支持普通/静态函数、推断/显式类型常量、类与信号。

模块索引：[tools](./README.md)
