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
| `SKIP_SOURCES` | L60 |
| `MODULE_OF` | L68 |
| `GROUP_README` | L77 |
| `walk(dir, out = [])` | L80 |
| `read(relativePath)` | L97 |
| `sha256(relativePath)` | L101 |
| `lineAt(text, index)` | L112 |
| `extractSymbols(relativePath, text)` | L116 |
| `stripStaticDocComment(line)` | L167 |
| `parseStaticDocFragment(lines, source)` | L181 |
| `extractStaticDoc(relativePath, text)` | L196 |
| `readSidecarDoc(source)` | L217 |
| `metadataFor(source)` | L225 |
| `sourceTypeLabel(source)` | L243 |
| `ensureDir(dirPath)` | L256 |
| `writeDoc(docRoot, relativePath, content)` | L260 |
| `perFileDoc(docRoot, source)` | L266 |
| `fallbackRole(source)` | L326 |
| `repoSources()` | L348 |
| `moduleSources(modulePath)` | L363 |
| `renderModuleReadme(docRoot, modulePath)` | L372 |
| `moduleDescription(modulePath)` | L413 |
| `collectSources()` | L417 |
| `validateSidecars(sources)` | L428 |
| `inputDigests(sources)` | L440 |
| `assertInputsUnchanged(before)` | L450 |
| `currentCommit()` | L458 |
| `renderRootReadme(docRoot, generatedAt, commit)` | L468 |
| `buildDocs(docRoot, options = {})` | L544 |
| `fileDigests(root)` | L595 |
| `compareDocTrees(expectedRoot, actualRoot)` | L605 |
| `replaceDocsAtomically(tempRoot)` | L612 |
| `baselineGenerationInfo()` | L628 |
| `printHelp()` | L635 |
| `main(args = process.argv.slice(2)` | L642 |

## 契约与约束
- 新源码优先在前 120 行维护 `@static-doc`；不能写注释的格式使用 `docs/static_headers/<源码路径>.md`。
- 旧 `FILE_DOCS` 只作为迁移兼容层，优先级低于源码注释和 sidecar。
- 默认在临时目录完成构建后原子替换 `docs/static`；`--check` 只比较，不写工作区。
- 只收录仓库应有的源码（git 跟踪或未忽略）；`SNModMaker/mods` 等被 .gitignore 排除的本地工作区不进入 manifest，否则干净检出（CI）与本地生成结果不一致。
- 文本源文件按 LF 计算 SHA-256（二进制按原始字节）：Windows 工具可能写出 CRLF 工作副本，而 git 提交的文本是 LF。
- GDScript 符号提取支持普通/静态函数、推断/显式类型常量、类与信号。

模块索引：[tools](./README.md)
