# `SNModMaker/tools/content.mjs`

> 作用：SNModMaker 内容 CLI（零依赖 Node ESM）：types / describe / list / add / set / loc / rm / clone / validate / new 十个无头命令，按 Schema 增删改定义、补本地化并校验；类型清单含 16 个运行时类型与 8 个 Schema 2.0 草案类型。

- 关键依赖：`SNStore`、`SNValidate`、`SNCatalog`、`content_json.mjs`、`Node 内置模块`
- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNMODMAKER` | L25 |
| `draftTypes()` | L39 |
| `allTypeInfos()` | L45 |
| `findTypeInfo(typeKey)` | L49 |
| `knownTypeKeys()` | L54 |
| `schemaVersionFor(target)` | L59 |
| `USAGE` | L72 |
| `BOOLEAN_FLAGS` | L129 |
| `parseArgv(argv)` | L134 |
| `flagTrue(ctx, name)` | L177 |
| `flagValue(ctx, name)` | L184 |
| `flagValues(ctx, name)` | L194 |
| `requireFlag(ctx, name, label)` | L200 |
| `jsonEqual(a, b)` | L214 |
| `isPlainObject(value)` | L218 |
| `sha256(buffer)` | L222 |
| `splitLines(text)` | L226 |
| `unifiedDiff(oldText, newText, context = 3)` | L234 |
| `printJson(payload)` | L301 |
| `stripChanges(changes)` | L305 |
| `changeLines(changes)` | L313 |
| `issueSummary(after, newIssues)` | L320 |
| `buildStats(project)` | L334 |
| `respond(ctx, payload, humanText, exitCode = 0)` | L342 |
| `issueKey(issue)` | L354 |
| `newIssuesBetween(baseline, after)` | L358 |
| `listFilesRecursive(root)` | L367 |
| `loadMod(ctx, modArg)` | L383 |
| `fileText(load, rel)` | L408 |
| `resolveInside(root, relative)` | L415 |
| `validateContentFilePath(filePath)` | L428 |
| `atomicWrite(absolute, buffer)` | L438 |
| `collectChanges(load, writes, deletes, wouldWrite)` | L456 |
| `verifyBaseline(load, writes, deletes)` | L485 |
| `commitChanges(load, writes, deletes)` | L496 |
| `planAppendDefinition(load, project, file, definition, index, writes, detail)` | L510 |
| `insertLocaleEntries(oldText, oldEntries, newEntries)` | L540 |
| `planLocaleChanges(load, project, writes, localeNames)` | L559 |
| `patchManifestText(originalText, manifest)` | L593 |
| `planManifest(load, project, writes)` | L623 |
| `runSyncCoreIndex(ctx)` | L635 |
| `runNodeTests(ctx)` | L647 |
| `finalizeWrite(ctx, options)` | L663 |
| `parseDataPath(input)` | L737 |
| `resolveTokenFile(reference)` | L782 |
| `readTextFile(reference)` | L794 |
| `parseValueToken(raw)` | L800 |
| `parseJsonOrFile(raw, label)` | L825 |
| `parseAssignmentSpec(raw)` | L835 |
| `setByPath(target, pathSegments, value)` | L857 |
| `getByPath(target, pathSegments)` | L871 |
| `deepMerge(base, extra)` | L880 |
| `buildData(typeKey, ctx)` | L891 |
| `findLocalIdConflict(project, info, localId, exclude)` | L912 |
| `validateLocalId(localId)` | L922 |
| `collectStrings(value, output, depth = 0)` | L929 |
| `applyValueAssignment(definition, assignment)` | L949 |
| `nestValue(segments, value)` | L979 |
| `insertValueAtPath(text, rootNode, pathSegments, value)` | L995 |
| `applyAssignmentToText(text, definitionNode, assignment)` | L1027 |
| `editDefinitionText(load, file, index, assignments, expectedDefinitions)` | L1054 |
| `describeFields(info)` | L1102 |
| `collectObject(node, file)` | L1114 |
| `inferType(target, raw)` | L1142 |
| `expand(pathText, node, isRequired, file, depth)` | L1165 |
| `describePayload(typeKey)` | L1203 |
| `commandTypes(ctx)` | L1266 |
| `commandDescribe(ctx)` | L1310 |
| `commandList(ctx)` | L1340 |
| `commandAdd(ctx)` | L1388 |
| `commandSet(ctx)` | L1511 |
| `commandLoc(ctx)` | L1567 |
| `commandRm(ctx)` | L1619 |
| `commandClone(ctx)` | L1689 |
| `commandValidate(ctx)` | L1748 |
| `commandNew(ctx)` | L1812 |
| `COMMANDS` | L1896 |
| `handleError(ctx, error)` | L1909 |
| `main(argv)` | L1927 |

## 契约与约束

- 十个命令由 `COMMANDS` 分发表进入；`parseArgv` 支持 `--flag value` / `--flag=value`、重复 flag 收集为数组与 `--` 之后的按位置参数，`--help` 退出 0。
- 复用网页端引擎而非另写规则：经典脚本按 schema-bundle → core-index → content-types → catalog → validate → store 的顺序 require 到 `globalThis`，校验、注册与本地化都走 `SNStore` / `SNValidate` / `SNCatalog`。
- `types` 同时列出运行时类型与 Schema 2.0 草案（`draft: true`、`schema_version`、`capability`；JSON 附 `activeTypes` / `draftTypes`）；`describe` 标草案并提示运行时不加载；`add` / `set` / `new` 写出的 `schema_version` 按类型推导（草案恒 2.0）。
- `--mod` 必须是含 `manifest.json` 的目录；所有写入经 `resolveInside` 限制在目录内，拒绝绝对路径、盘符与 `..`。
- 输出契约：`--json` 时 stdout 只有一个 JSON 对象（成功 / 失败 / 用法错误都是），人读日志写 stderr；退出码 0 成功、1 执行失败 / 校验未通过 / 冲突、2 用法错误。
- 写命令统一预检：改动前后各跑 `Validate.validateProject`，按 `severity|code|message|view` 求新增问题；new error 默认整批不写并退出 1，`--force` 只解除拦截、结果仍 `ok:false`。
- 外部命令只在真实写入后执行：`--sync` 仅在 `manifest.id === 'core'` 时跑 `sync-core-index.mjs`，`--test` 跑 `SNModMaker/tests/run-tests.js`；`validate --godot` 需 `GODOT_BIN`，未设置只记 notes 不算失败。

## 重点逻辑

### `loadMod(ctx, modArg)`

- 递归排序读取模组目录得到 `{path, data}` 条目，交 `Store.fromFiles` 生成 project / warnings；每个文件保存 buffer 与加载时的 SHA-256 供冲突检测。
- 文本按需 UTF-8 解码并缓存；`resolveInside` 对相对路径做前缀校验，越界抛 `path` 错误。

### `collectChanges / verifyBaseline / commitChanges`

- `collectChanges` 只保留与加载缓冲不同的文件，输出 create / update / delete（`--dry-run` 时加 `would-` 前缀）、bytes 与行级 LCS unified diff；内容相同的写入项直接丢弃。
- `verifyBaseline` 写前重新读取每个待写 / 待删文件并与加载时 SHA-256 比对，不一致抛 `conflict`；`commitChanges` 先整体校验再逐个写入，因此冲突时零写入。
- 单文件写入用同目录 `.tmp-<pid>-<rand>` 写完 `fs.renameSync` 覆盖，失败清理临时文件。

### `finalizeWrite(ctx, options)`

- 所有写命令的公共收尾：计算 newIssues、决定是否写盘、组装 `changes / issues / stats / notes` 与统一摘要。
- `--dry-run` 或被 new error 拦截时只产出 `would-*` 变更；`--force` 只放开拦截，不改变失败状态与退出码。
- 真实写入成功后才执行 `--sync` / `--test`；无真实写入或非 core 时只往 notes 记录跳过原因。

### `planAppendDefinition / planLocaleChanges / planManifest`

- 内容文件：解析源文本后定位 `definitions` 数组，用 `insertArrayItem` 在尾部插入；只有新建内容文件才整份序列化写出。
- 本地化：只写有实际变化的 locale 文件；纯新增键用 `insertLocaleEntries` 插到最后一个成员之前以保留既有字节，增删改混合时才整份 `JSON.stringify(entries, null, 2)`。
- manifest：只对 `content` / `localization` 数组做元素级增删（`insertArrayItem` / `removeArrayItem` / 缺字段时 `insertObjectMember`），不重写其他字段。

### `editDefinitionText / applyAssignmentToText`

- `set` 先在内存定义上执行赋值，再在源文本上改写目标节点：标量 `replaceNodeValue`、数组插删、缺失路径插到最深的已存在父节点。
- 改写后用 `JSON.parse` 与内存期望值全等校验；不一致时兜底为只替换该 definition 节点并再次校验，仍不一致报 internal 且不写盘。

### `commandRm`

- 删除前收集定义的全部键；删除后以所有剩余定义的键与任意字符串值作为保留集合，只删除未被保留的本地化键（`--keep-loc` 跳过）。
- 内容文件仍有定义时精确删除数组项；变空时改为删除该内容文件，并同步移除 manifest 声明。

### `describeFields / describePayload`

- 字段表来自 `SN_SCHEMAS`：envelope `definitions.items` 的 allOf 用 `Validate.deref` 合并并保留属性所属 Schema 文件（跨文件 `$ref` 才正确），`data` 再展开一层；object 与数组元素递归到深度 4，路径写成 `data.market[].stock_range`。
- 每行只带实际存在的约束键；`defaults` 来自 `SNCatalog.DEFAULTS[type]?.()`，patches 的 defaults 为 null 并给出 target / operations 骨架。

### `commandNew`

- `Store.createProject` + `toExportFiles(prefix:false)` 写出模板文件树，内容文件用 `formatStyled` 统一风格；目标目录非空且无 `--force` 时退出 1。
- 真实写入后重新 `loadMod` 再校验；`--dry-run` 只列 `would-create`，不落盘。

模块索引：[SNModMaker](../README.md)
