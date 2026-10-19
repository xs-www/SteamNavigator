# `SNModMaker/js/app.js`

> 作用：应用控制器：视图状态、事件委托、表单写回、撤销/重做、自动保存、导入导出与 Modal 流程。

- 关键依赖：`store`、`validate`、`ui`、`io`、`catalog`、`zip（经 io）`
- 类型：浏览器经典脚本

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `UI` | L12 |
| `IO` | L14 |
| `MODULE_PAGE_TYPES` | L16 |
| `init()` | L71 |
| `probeBackend()` | L78 |
| `loadInitialProject()` | L88 |
| `setProject(project, options)` | L120 |
| `clearProject()` | L149 |
| `firstSelection(project)` | L161 |
| `currentFile()` | L175 |
| `currentDefinition()` | L180 |
| `selectedTypeInfo()` | L186 |
| `selectedDefinitionKey()` | L191 |
| `localizationDraft(definition, oldId, syncToId)` | L195 |
| `currentLocalizationDraft()` | L217 |
| `previewLocalizationValue(key, draft)` | L221 |
| `previewLocalizationKey(definition, field, draft)` | L229 |
| `setByPath(object, path, value)` | L233 |
| `getByPath(object, path)` | L249 |
| `deleteByPath(object, path)` | L259 |
| `snapshot()` | L272 |
| `pushHistory()` | L276 |
| `undo()` | L287 |
| `redo()` | L303 |
| `ensureSelection()` | L319 |
| `fallbackKey(uid)` | L335 |
| `loadFallbackProject()` | L339 |
| `saveNow(options)` | L350 |
| `flushDiskSave()` | L394 |
| `openProject(uid)` | L422 |
| `deleteProject(uid)` | L439 |
| `render(options)` | L470 |
| `renderChrome()` | L506 |
| `renderStatus()` | L533 |
| `saveStateText()` | L552 |
| `saveStateTitle()` | L562 |
| `updateSaveState()` | L567 |
| `timeText(date)` | L575 |
| `renderSidebar()` | L583 |
| `sideTypeLink(type, count, issues)` | L641 |
| `activeLocale(locale)` | L652 |
| `renderWorkspace()` | L660 |
| `renderWelcome()` | L682 |
| `loadRecent()` | L707 |
| `renderOverview()` | L763 |
| `ovField(labelText, control, hintText, wide)` | L872 |
| `depRow(list, dependency, index)` | L880 |
| `structureTree(project)` | L888 |
| `renderModuleTabs(activeType)` | L916 |
| `renderContent()` | L932 |
| `renderDefinitionEditor(selected, info)` | L1007 |
| `collectNeededKeys(project)` | L1063 |
| `renderLocalization()` | L1078 |
| `renderAssets()` | L1157 |
| `paintModelThumbnails()` | L1199 |
| `runModelThumbQueue()` | L1218 |
| `setModelThumbImage(node, dataUrl)` | L1237 |
| `renderValidation()` | L1247 |
| `issueLocation(issue)` | L1285 |
| `gotoIssue(index)` | L1297 |
| `attrSelector(value)` | L1337 |
| `inspectorData()` | L1345 |
| `renderInspector()` | L1359 |
| `inspectorLabel()` | L1382 |
| `bindEvents()` | L1400 |
| `closeAssetPickers(except)` | L1417 |
| `openAssetPicker(picker)` | L1426 |
| `filterAssetPicker(input)` | L1436 |
| `onClick(event)` | L1451 |
| `selectDefinition(filePath, index)` | L1483 |
| `navigate(kind, argument)` | L1492 |
| `onInput(event)` | L1528 |
| `onChange(event)` | L1576 |
| `onKeyDown(event)` | L1601 |
| `onFocusOut(event)` | L1659 |
| `applyField(element, fromChange)` | L1667 |
| `readValue(element)` | L1715 |
| `markChanged(structural)` | L1742 |
| `updateDefinitionLocalizationPreview(definition, draft)` | L1754 |
| `updateEntityLocaleDraft(element)` | L1773 |
| `updateLocaleValue(element)` | L1788 |
| `filterDefinitionCards()` | L1808 |
| `renderLocalizationListOnly()` | L1815 |
| `autoProjectId(name)` | L1828 |
| `filterCoreList(query)` | L1834 |
| `handleAction(element, event)` | L1845 |
| `saveDefinitionAction()` | L2080 |
| `gotoDefinitionLocalization(field, keyOverride)` | L2117 |
| `addDefinitionAction()` | L2134 |
| `cloneCoreAction(coreId)` | L2145 |
| `deleteDefinitionAction()` | L2161 |
| `duplicateDefinitionAction()` | L2186 |
| `applyRawJson()` | L2197 |
| `addDependency(list)` | L2220 |
| `removeDependency(list, index)` | L2230 |
| `syncNamespace()` | L2239 |
| `gotoKeyDefinition(filePath, index)` | L2284 |
| `deleteLocaleKey(key)` | L2293 |
| `fillMissingKeys()` | L2303 |
| `arrayAdd(path)` | L2325 |
| `defaultArrayItem(path, definition)` | L2339 |
| `arrayRemove(path, index)` | L2362 |
| `arrayMove(path, index, direction)` | L2373 |
| `addListValue(path, input, button)` | L2387 |
| `listRemove(path, index)` | L2411 |
| `enumToggle(path, value, element)` | L2424 |
| `addCondition(path, kind)` | L2441 |
| `removeCondition(path)` | L2453 |
| `changeConditionKind(element)` | L2462 |
| `changeConditionOp(element)` | L2482 |
| `changeEffectOp(element)` | L2502 |
| `addAssets()` | L2526 |
| `removeAsset(path)` | L2568 |
| `downloadAsset(path)` | L2584 |
| `showNewProject()` | L2594 |
| `createProjectFromModal()` | L2627 |
| `showImport()` | L2663 |
| `importFolder()` | L2683 |
| `importFile()` | L2688 |
| `importEntries(entries)` | L2693 |
| `showExport()` | L2733 |
| `exportZip()` | L2767 |
| `exportZipToDisk()` | L2789 |
| `deployGameMod()` | L2812 |
| `exportProjectFile()` | L2838 |
| `exportFolder()` | L2848 |
| `showProjectLibrary()` | L2860 |
| `openDiskProject(id)` | L2921 |
| `openWorkspaceProject(id)` | L2940 |
| `deleteDiskProject(id)` | L2958 |
| `showCoreClone()` | L2977 |
| `showAddLocale()` | L3003 |
| `createLocale()` | L3018 |
| `showAddLocaleKey()` | L3039 |
| `createLocaleKey()` | L3051 |
| `showHelp()` | L3068 |
| `onDragEnter(event)` | L3110 |
| `onDragOver(event)` | L3117 |
| `onDragLeave()` | L3121 |
| `onDrop(event)` | L3129 |
| `runValidation()` | L3146 |
| `copyText(text)` | L3152 |

## 契约与约束

- `state.project` 是唯一项目源；视图与选择状态不写入导出 JSON。
- 文本输入只更新模型并调度校验/保存，不整页重绘；结构操作才重绘并保留滚动位置。
- 历史快照最多 40 个；一次焦点内的连续输入只压入一个快照。
- 自动保存有 800ms 防抖，并用 revision 防止旧保存清除新改动；IDB 失败回退 localStorage。
- ID 修改与条目内翻译先进入 localizationDrafts；自动保存不写多语言键，只有“保存条目”提交键迁移。
- 船只与模块相关类型共享页面子分页，可直接切换而无需返回侧栏重新选择。
- 自定义资源选择器支持点击展开、输入搜索、清空和选择写回；点击外部或 Escape 关闭菜单。
- 检测到本地服务时，同一项目再经 1.6s 防抖镜像到 `mods/<id>/`；磁盘失败只降低提示，不阻断浏览器保存。
- 项目库的「磁盘」区同时列出 `mods/` 项目与 `dev_mods/` 工作区：工作区行标「工作区」且不提供删除；`state.workspace` 为真时保存改走 `putWorkspaceProject`，直接写回原生模组目录。
- 导出菜单在本地服务可用时提供发布包部署入口：先保存项目、构建 ZIP，再覆盖 `dist/build/<platform>/mods/<id>.snavmod.zip` 并报告旧包清理数量。
- 没有本地服务时，发布包部署入口以禁用项 + 启动服务指引呈现，而不是完全隐藏。
- 资源页对带 dataUrl 的 GLB 卡片异步生成缩略图；渲染队列逐张执行，失败时保留 GLB 占位。
- Ctrl+S/Z/Shift+Z/N/O/E 为全局快捷键；文本输入中不拦截撤销。

## 重点逻辑

### `applyField(element, fromChange)`

- 区分 manifest 与当前定义；数字/整数/布尔/JSON 各有解析，解析失败不写回。
- ID 输入按前缀重建完整 ID，只更新多语言键预览，不直接改定义 `_key` 或语言文件。
- 空描述键、空 checksum 与空 information 资源字段会删除，避免违反可选字段的 pattern/minLength。

### `saveDefinitionAction()`

- 把当前实体暂存的所有语言值映射到最终预览键，并调用 store 原子迁移旧键。
- 提交成功后清理草稿、重新校验并立即保存项目；冲突时保留草稿并提示错误。

### `saveNow()`

- 写入 IndexedDB；失败时写 localStorage 并标记存储模式。
- 保存完成后比较 revision：有更新则保持 dirty 并排队下一次保存。

### `importEntries(entries)`

- 识别单个 `.zip`、单个 `.snmodproj.json` 或目录文件集；导入后立即保存并展示 warnings。
- 所有解析错误转换为 Toast，不改变当前项目。

模块索引：[SNModMaker](../README.md)
