# `SNModMaker/tests/content-cli.test.mjs`

> 作用：Content CLI 集成测试：用 node:test 子进程调用真实 CLI，在临时模组目录覆盖十个命令、保源写回、校验闸门与 JSON 输出；含 `weapons` 草案类型与「舰载武器包」模板。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MOD_ID` | L38 |
| `GOODS_FILE` | L39 |
| `runCli(args)` | L45 |
| `jsonRun(args)` | L63 |
| `mustJson(result, label = 'CLI')` | L68 |
| `assertStatus(result, expected, label)` | L84 |
| `mustFailJson(result, label)` | L93 |
| `assertUsageError(result, label)` | L105 |
| `tempRoot(t)` | L115 |
| `createMod(t, { id = MOD_ID, name = '测试模组', template = 'goods', extra = [] } = {})` | L126 |
| `readText(file)` | L136 |
| `readJson(file)` | L140 |
| `writeJson(file, value)` | L148 |
| `manifestOf(mod)` | L152 |
| `contentFilesOf(mod)` | L156 |
| `contentFileOfType(mod, typeKey)` | L164 |
| `goodsFileOf(mod)` | L170 |
| `definitionsOf(mod)` | L174 |
| `definitionById(mod, id)` | L184 |
| `localeOf(mod, locale)` | L190 |
| `addGood(mod, id, extra = [])` | L197 |
| `sha256File(file)` | L214 |
| `snapshotDir(dir, { onlyJson = false } = {})` | L222 |
| `assertDirUnchanged(before, dir, label, options)` | L238 |
| `assertLinesPreservedInOrder(beforeText, afterText, label)` | L247 |
| `extractDefinitionSlices(text)` | L270 |
| `changedLineIndexes(beforeText, afterText)` | L310 |
| `isDefinitionRow(value)` | L326 |
| `collectRowArrays(value, out = [])` | L330 |
| `listRows(json, label)` | L342 |
| `expectedCoreDefinitionCount()` | L357 |

## 契约与约束

- 每个用例在 `fs.mkdtempSync(os.tmpdir())` 建临时模组；仓库 `dev_mods/core` 只读（部分用例比对前后 SHA-256），任何写操作都不落在仓库内。
- 覆盖 types / describe / list / new / add / set / loc / clone / rm / validate 的正常路径与用法错误、`--dry-run` 不写盘、最小 diff 与 add → rm 逐字节还原（含 BOM）、本地化专属键清理、`--json` 单一对象与退出码 0 / 1 / 2；`describe weapons` 与 `add --type weapons`（写 `schema_version: "2.0"`）在列。
- `new --template weapons` 生成 5 条 weapons 草案定义与 `content.combat.v1` capability、不生成 1.0 商品；未知模板拒绝时错误信息列出 weapons 在内的可用模板。
- 运行：`node --test SNModMaker/tests/content-cli.test.mjs`（从仓库根执行），只用 Node 内置模块，不引入第三方依赖。

模块索引：[SNModMaker](../README.md)
