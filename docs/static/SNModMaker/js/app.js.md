# `SNModMaker/js/app.js`

> 作用：应用控制器：视图状态、事件委托、表单写回、撤销/重做、自动保存、导入导出与 Modal 流程。

- 关键依赖：`store`、`validate`、`ui`、`io`、`catalog`、`zip（经 io）`
- 类型：浏览器经典脚本

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `UI` | L12 |
| `IO` | L14 |
| `init()` | L68 |
| `probeBackend()` | L75 |
| `loadInitialProject()` | L85 |
| `setProject(project, options)` | L117 |
| `clearProject()` | L144 |
| `firstSelection(project)` | L155 |
| `currentFile()` | L169 |
| `currentDefinition()` | L174 |
| `selectedTypeInfo()` | L180 |
| `setByPath(object, path, value)` | L185 |
| `getByPath(object, path)` | L201 |
| `deleteByPath(object, path)` | L211 |
| `snapshot()` | L224 |
| `pushHistory()` | L228 |
| `undo()` | L239 |
| `redo()` | L254 |
| `ensureSelection()` | L269 |
| `fallbackKey(uid)` | L285 |
| `loadFallbackProject()` | L289 |
| `saveNow(options)` | L300 |
| `flushDiskSave()` | L344 |
| `openProject(uid)` | L369 |
| `deleteProject(uid)` | L386 |
| `render(options)` | L417 |
| `renderChrome()` | L452 |
| `renderStatus()` | L479 |
| `saveStateText()` | L498 |
| `saveStateTitle()` | L508 |
| `updateSaveState()` | L513 |
| `timeText(date)` | L521 |
| `renderSidebar()` | L529 |
| `sideTypeLink(type, count, issues)` | L587 |
| `activeLocale(locale)` | L598 |
| `renderWorkspace()` | L606 |
| `renderWelcome()` | L628 |
| `loadRecent()` | L653 |
| `renderOverview()` | L709 |
| `ovField(labelText, control, hintText, wide)` | L818 |
| `depRow(list, dependency, index)` | L826 |
| `structureTree(project)` | L834 |
| `renderContent()` | L862 |
| `renderDefinitionEditor(selected, info)` | L935 |
| `collectNeededKeys(project)` | L987 |
| `renderLocalization()` | L1002 |
| `renderAssets()` | L1081 |
| `renderValidation()` | L1114 |
| `issueLocation(issue)` | L1152 |
| `gotoIssue(index)` | L1164 |
| `attrSelector(value)` | L1204 |
| `inspectorData()` | L1212 |
| `renderInspector()` | L1226 |
| `inspectorLabel()` | L1249 |
| `bindEvents()` | L1267 |
| `onClick(event)` | L1284 |
| `selectDefinition(filePath, index)` | L1310 |
| `navigate(kind, argument)` | L1319 |
| `onInput(event)` | L1355 |
| `onChange(event)` | L1396 |
| `onKeyDown(event)` | L1421 |
| `onFocusOut(event)` | L1478 |
| `applyField(element, fromChange)` | L1486 |
| `readValue(element)` | L1526 |
| `markChanged(structural)` | L1553 |
| `syncKeysAfterIdChange(definition, oldId)` | L1565 |
| `updateLocaleValue(element)` | L1603 |
| `filterDefinitionCards()` | L1623 |
| `renderLocalizationListOnly()` | L1630 |
| `autoProjectId(name)` | L1643 |
| `filterCoreList(query)` | L1649 |
| `handleAction(element, event)` | L1660 |
| `addDefinitionAction()` | L1865 |
| `cloneCoreAction(coreId)` | L1876 |
| `deleteDefinitionAction()` | L1892 |
| `duplicateDefinitionAction()` | L1917 |
| `applyRawJson()` | L1928 |
| `addDependency(list)` | L1951 |
| `removeDependency(list, index)` | L1961 |
| `syncNamespace()` | L1970 |
| `gotoKeyDefinition(filePath, index)` | L2015 |
| `deleteLocaleKey(key)` | L2024 |
| `fillMissingKeys()` | L2034 |
| `arrayAdd(path)` | L2056 |
| `defaultArrayItem(path, definition)` | L2070 |
| `arrayRemove(path, index)` | L2093 |
| `arrayMove(path, index, direction)` | L2104 |
| `addListValue(path, input, button)` | L2118 |
| `listRemove(path, index)` | L2142 |
| `enumToggle(path, value, element)` | L2155 |
| `addCondition(path, kind)` | L2172 |
| `removeCondition(path)` | L2184 |
| `changeConditionKind(element)` | L2193 |
| `changeConditionOp(element)` | L2213 |
| `changeEffectOp(element)` | L2233 |
| `addAssets()` | L2257 |
| `removeAsset(path)` | L2297 |
| `downloadAsset(path)` | L2312 |
| `showNewProject()` | L2322 |
| `createProjectFromModal()` | L2355 |
| `showImport()` | L2391 |
| `importFolder()` | L2411 |
| `importFile()` | L2416 |
| `importEntries(entries)` | L2421 |
| `showExport()` | L2461 |
| `exportZip()` | L2488 |
| `exportZipToDisk()` | L2510 |
| `exportProjectFile()` | L2533 |
| `exportFolder()` | L2543 |
| `showProjectLibrary()` | L2555 |
| `openDiskProject(id)` | L2616 |
| `deleteDiskProject(id)` | L2633 |
| `showCoreClone()` | L2652 |
| `showAddLocale()` | L2678 |
| `createLocale()` | L2693 |
| `showAddLocaleKey()` | L2714 |
| `createLocaleKey()` | L2726 |
| `showHelp()` | L2743 |
| `onDragEnter(event)` | L2785 |
| `onDragOver(event)` | L2792 |
| `onDragLeave()` | L2796 |
| `onDrop(event)` | L2804 |
| `runValidation()` | L2821 |
| `copyText(text)` | L2827 |

## 契约与约束

- `state.project` 是唯一项目源；视图与选择状态不写入导出 JSON。
- 文本输入只更新模型并调度校验/保存，不整页重绘；结构操作才重绘并保留滚动位置。
- 历史快照最多 40 个；一次焦点内的连续输入只压入一个快照。
- 自动保存有 800ms 防抖，并用 revision 防止旧保存清除新改动；IDB 失败回退 localStorage。
- 检测到本地服务时，同一项目再经 1.6s 防抖镜像到 `mods/<id>/`；磁盘失败只降低提示，不阻断浏览器保存。
- Ctrl+S/Z/Shift+Z/N/O/E 为全局快捷键；文本输入中不拦截撤销。

## 重点逻辑

### `applyField(element, fromChange)`

- 区分 manifest 与当前定义；数字/整数/布尔/JSON 各有解析，解析失败不写回。
- ID 输入按前缀重建完整 ID，并同步重命名以旧 `name_key` 为基的 `_key` 与翻译。
- 空描述键与空 checksum 会删除字段，避免违反可选字段的 pattern/minLength。

### `saveNow()`

- 写入 IndexedDB；失败时写 localStorage 并标记存储模式。
- 保存完成后比较 revision：有更新则保持 dirty 并排队下一次保存。

### `importEntries(entries)`

- 识别单个 `.zip`、单个 `.snmodproj.json` 或目录文件集；导入后立即保存并展示 warnings。
- 所有解析错误转换为 Toast，不改变当前项目。

模块索引：[SNModMaker](../README.md)
