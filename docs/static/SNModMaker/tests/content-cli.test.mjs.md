# `SNModMaker/tests/content-cli.test.mjs`

> 作用：Content CLI 集成测试：用 node:test 子进程调用真实 CLI，在临时模组目录覆盖十个命令、保源写回、校验闸门与 JSON 输出；含 `weapons` 草案类型、「舰载武器包」模板，以及剧情 `story_arcs` / `story_levels` 草案与示例剧情包。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MOD_ID` | L37 |
| `GOODS_FILE` | L38 |
| `STORY_PACK_DIR` | L41 |
| `runCli(args)` | L47 |
| `jsonRun(args)` | L65 |
| `mustJson(result, label = 'CLI')` | L70 |
| `assertStatus(result, expected, label)` | L86 |
| `mustFailJson(result, label)` | L95 |
| `assertUsageError(result, label)` | L107 |
| `tempRoot(t)` | L117 |
| `createMod(t, { id = MOD_ID, name = '测试模组', template = 'goods', extra = [] } = {})` | L128 |
| `readText(file)` | L138 |
| `readJson(file)` | L142 |
| `writeJson(file, value)` | L150 |
| `manifestOf(mod)` | L154 |
| `contentFilesOf(mod)` | L158 |
| `contentFileOfType(mod, typeKey)` | L166 |
| `goodsFileOf(mod)` | L172 |
| `definitionsOf(mod)` | L176 |
| `definitionById(mod, id)` | L186 |
| `localeOf(mod, locale)` | L192 |
| `addGood(mod, id, extra = [])` | L199 |
| `sha256File(file)` | L216 |
| `snapshotDir(dir, { onlyJson = false } = {})` | L224 |
| `assertDirUnchanged(before, dir, label, options)` | L240 |
| `copyDir(source, target)` | L245 |
| `assertLinesPreservedInOrder(beforeText, afterText, label)` | L261 |
| `extractDefinitionSlices(text)` | L284 |
| `changedLineIndexes(beforeText, afterText)` | L324 |
| `isDefinitionRow(value)` | L340 |
| `collectRowArrays(value, out = [])` | L344 |
| `listRows(json, label)` | L356 |
| `expectedCoreDefinitionCount()` | L371 |

## 契约与约束

- 每个用例在 `fs.mkdtempSync(os.tmpdir())` 建临时模组；仓库 `dev_mods/core` 与 `sdk/templates/story_pack_iron_tide` 只读（部分用例比对前后 SHA-256），任何写操作都不落在仓库内。
- 覆盖 types / describe / list / new / add / set / loc / clone / rm / validate 的正常路径与用法错误、`--dry-run` 不写盘、最小 diff 与 add → rm 逐字节还原（含 BOM）、本地化专属键清理、`--json` 单一对象与退出码 0 / 1 / 2；`describe weapons` 与 `add --type weapons`（写 `schema_version: "2.0"`）在列。
- `new --template weapons` 生成 5 条 weapons 草案定义与 `content.combat.v1` capability、不生成 1.0 商品；`new --draft story_arcs --draft story_levels` 生成纯剧情包（`content.story.v1`、空篇章 / 孤儿关卡只警告）；未知模板拒绝时错误信息列出 weapons 在内的可用模板，`--draft world_profiles` 等已提升类型按用法错误拒绝。
- `validate --mod sdk/templates/story_pack_iron_tide` 断言 0 error / 2 个 `draft_content` warning；把 `goods` 内容加进剧情包副本后断言 `story_pack_off_whitelist` 与退出码 1。
- 运行：`node --test SNModMaker/tests/content-cli.test.mjs`（从仓库根执行），只用 Node 内置模块，不引入第三方依赖。

模块索引：[SNModMaker](../README.md)
