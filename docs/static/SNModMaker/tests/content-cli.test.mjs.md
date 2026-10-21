# `SNModMaker/tests/content-cli.test.mjs`

> 作用：Content CLI 集成测试：用 node:test 子进程调用真实 CLI，在临时模组目录覆盖十个命令、保源写回、校验闸门与 JSON 输出。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MOD_ID` | L36 |
| `GOODS_FILE` | L37 |
| `runCli(args)` | L43 |
| `jsonRun(args)` | L61 |
| `mustJson(result, label = 'CLI')` | L66 |
| `assertStatus(result, expected, label)` | L82 |
| `mustFailJson(result, label)` | L91 |
| `assertUsageError(result, label)` | L103 |
| `tempRoot(t)` | L113 |
| `createMod(t, { id = MOD_ID, name = '测试模组', template = 'goods', extra = [] } = {})` | L124 |
| `readText(file)` | L134 |
| `readJson(file)` | L138 |
| `writeJson(file, value)` | L146 |
| `manifestOf(mod)` | L150 |
| `contentFilesOf(mod)` | L154 |
| `contentFileOfType(mod, typeKey)` | L162 |
| `goodsFileOf(mod)` | L168 |
| `definitionsOf(mod)` | L172 |
| `definitionById(mod, id)` | L182 |
| `localeOf(mod, locale)` | L188 |
| `addGood(mod, id, extra = [])` | L195 |
| `sha256File(file)` | L212 |
| `snapshotDir(dir, { onlyJson = false } = {})` | L220 |
| `assertDirUnchanged(before, dir, label, options)` | L236 |
| `assertLinesPreservedInOrder(beforeText, afterText, label)` | L245 |
| `extractDefinitionSlices(text)` | L268 |
| `changedLineIndexes(beforeText, afterText)` | L308 |
| `isDefinitionRow(value)` | L324 |
| `collectRowArrays(value, out = [])` | L328 |
| `listRows(json, label)` | L340 |
| `expectedCoreDefinitionCount()` | L355 |

## 契约与约束

- 每个用例在 `fs.mkdtempSync(os.tmpdir())` 建临时模组；仓库 `dev_mods/core` 只读（部分用例比对前后 SHA-256），任何写操作都不落在仓库内。
- 覆盖 types / describe / list / new / add / set / loc / clone / rm / validate 的正常路径与用法错误、`--dry-run` 不写盘、最小 diff 与 add → rm 逐字节还原（含 BOM）、本地化专属键清理、`--json` 单一对象与退出码 0 / 1 / 2。
- 运行：`node --test SNModMaker/tests/content-cli.test.mjs`（从仓库根执行），只用 Node 内置模块，不引入第三方依赖。

模块索引：[SNModMaker](../README.md)
