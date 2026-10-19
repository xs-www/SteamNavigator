# `SNModMaker/tests/content-cli.test.mjs`

> 作用：Content CLI 集成测试：用 node:test 子进程调用真实 CLI，在临时模组目录覆盖十个命令、保源写回、校验闸门与 JSON 输出。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MOD_ID` | L33 |
| `GOODS_FILE` | L34 |
| `runCli(args)` | L40 |
| `jsonRun(args)` | L58 |
| `mustJson(result, label = 'CLI')` | L63 |
| `assertStatus(result, expected, label)` | L79 |
| `mustFailJson(result, label)` | L88 |
| `assertUsageError(result, label)` | L100 |
| `tempRoot(t)` | L110 |
| `createMod(t, { id = MOD_ID, name = '测试模组', template = 'goods', extra = [] } = {})` | L121 |
| `readText(file)` | L131 |
| `readJson(file)` | L135 |
| `writeJson(file, value)` | L143 |
| `manifestOf(mod)` | L147 |
| `contentFilesOf(mod)` | L151 |
| `contentFileOfType(mod, typeKey)` | L159 |
| `goodsFileOf(mod)` | L165 |
| `definitionsOf(mod)` | L169 |
| `definitionById(mod, id)` | L179 |
| `localeOf(mod, locale)` | L185 |
| `addGood(mod, id, extra = [])` | L192 |
| `sha256File(file)` | L209 |
| `snapshotDir(dir, { onlyJson = false } = {})` | L217 |
| `assertDirUnchanged(before, dir, label, options)` | L233 |
| `assertLinesPreservedInOrder(beforeText, afterText, label)` | L242 |
| `extractDefinitionSlices(text)` | L265 |
| `changedLineIndexes(beforeText, afterText)` | L305 |
| `isDefinitionRow(value)` | L321 |
| `collectRowArrays(value, out = [])` | L325 |
| `listRows(json, label)` | L337 |
| `expectedCoreDefinitionCount()` | L352 |

## 契约与约束

- 每个用例在 `fs.mkdtempSync(os.tmpdir())` 建临时模组；仓库 `dev_mods/core` 只读（部分用例比对前后 SHA-256），任何写操作都不落在仓库内。
- 覆盖 types / describe / list / new / add / set / loc / clone / rm / validate 的正常路径与用法错误、`--dry-run` 不写盘、最小 diff 与 add → rm 逐字节还原（含 BOM）、本地化专属键清理、`--json` 单一对象与退出码 0 / 1 / 2。
- 运行：`node --test SNModMaker/tests/content-cli.test.mjs`（从仓库根执行），只用 Node 内置模块，不引入第三方依赖。

模块索引：[SNModMaker](../README.md)
