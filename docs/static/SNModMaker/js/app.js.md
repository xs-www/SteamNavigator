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
| `flushDiskSave(options)` | L394 |
| `openProject(uid)` | L438 |
| `deleteProject(uid)` | L455 |
| `render(options)` | L486 |
| `renderChrome()` | L522 |
| `renderStatus()` | L549 |
| `saveStateText()` | L568 |
| `saveStateTitle()` | L578 |
| `updateSaveState()` | L583 |
| `timeText(date)` | L591 |
| `renderSidebar()` | L599 |
| `sideTypeLink(type, count, issues)` | L657 |
| `activeLocale(locale)` | L668 |
| `renderWorkspace()` | L676 |
| `renderWelcome()` | L698 |
| `loadRecent()` | L723 |
| `renderOverview()` | L779 |
| `ovField(labelText, control, hintText, wide)` | L888 |
| `depRow(list, dependency, index)` | L896 |
| `structureTree(project)` | L904 |
| `renderModuleTabs(activeType)` | L932 |
| `renderContent()` | L948 |
| `renderDefinitionEditor(selected, info)` | L1023 |
| `collectNeededKeys(project)` | L1079 |
| `renderLocalization()` | L1094 |
| `renderAssets()` | L1173 |
| `paintModelThumbnails()` | L1215 |
| `runModelThumbQueue()` | L1234 |
| `setModelThumbImage(node, dataUrl)` | L1253 |
| `renderValidation()` | L1263 |
| `issueLocation(issue)` | L1301 |
| `gotoIssue(index)` | L1313 |
| `attrSelector(value)` | L1353 |
| `inspectorData()` | L1361 |
| `renderInspector()` | L1375 |
| `inspectorLabel()` | L1398 |
| `bindEvents()` | L1416 |
| `closeAssetPickers(except)` | L1433 |
| `openAssetPicker(picker)` | L1442 |
| `filterAssetPicker(input)` | L1452 |
| `onClick(event)` | L1467 |
| `selectDefinition(filePath, index)` | L1499 |
| `navigate(kind, argument)` | L1508 |
| `onInput(event)` | L1544 |
| `onChange(event)` | L1592 |
| `onKeyDown(event)` | L1617 |
| `onFocusOut(event)` | L1675 |
| `applyField(element, fromChange)` | L1683 |
| `readValue(element)` | L1731 |
| `markChanged(structural)` | L1758 |
| `updateDefinitionLocalizationPreview(definition, draft)` | L1770 |
| `updateEntityLocaleDraft(element)` | L1789 |
| `updateLocaleValue(element)` | L1804 |
| `filterDefinitionCards()` | L1824 |
| `renderLocalizationListOnly()` | L1831 |
| `autoProjectId(name)` | L1844 |
| `filterCoreList(query)` | L1850 |
| `handleAction(element, event)` | L1861 |
| `saveDefinitionAction()` | L2096 |
| `gotoDefinitionLocalization(field, keyOverride)` | L2133 |
| `addDefinitionAction()` | L2150 |
| `cloneCoreAction(coreId)` | L2161 |
| `deleteDefinitionAction()` | L2177 |
| `duplicateDefinitionAction()` | L2202 |
| `applyRawJson()` | L2213 |
| `addDependency(list)` | L2236 |
| `removeDependency(list, index)` | L2246 |
| `syncNamespace()` | L2255 |
| `gotoKeyDefinition(filePath, index)` | L2300 |
| `deleteLocaleKey(key)` | L2309 |
| `fillMissingKeys()` | L2319 |
| `arrayAdd(path)` | L2341 |
| `defaultArrayItem(path, definition)` | L2355 |
| `arrayRemove(path, index)` | L2378 |
| `arrayMove(path, index, direction)` | L2389 |
| `addListValue(path, input, button)` | L2403 |
| `listRemove(path, index)` | L2427 |
| `enumToggle(path, value, element)` | L2440 |
| `addCondition(path, kind)` | L2457 |
| `removeCondition(path)` | L2469 |
| `changeConditionKind(element)` | L2478 |
| `changeConditionOp(element)` | L2498 |
| `changeEffectOp(element)` | L2518 |
| `addAssets()` | L2542 |
| `removeAsset(path)` | L2584 |
| `downloadAsset(path)` | L2600 |
| `showNewProject()` | L2610 |
| `createProjectFromModal()` | L2643 |
| `showImport()` | L2679 |
| `importFolder()` | L2699 |
| `importFile()` | L2704 |
| `importEntries(entries)` | L2709 |
| `showExport()` | L2749 |
| `exportZip()` | L2783 |
| `exportZipToDisk()` | L2805 |
| `deployGameMod()` | L2828 |
| `exportProjectFile()` | L2854 |
| `exportFolder()` | L2864 |
| `showProjectLibrary()` | L2876 |
| `openDiskProject(id)` | L2937 |
| `openWorkspaceProject(id)` | L2956 |
| `deleteDiskProject(id)` | L2974 |
| `showCoreClone()` | L2993 |
| `showAddLocale()` | L3019 |
| `createLocale()` | L3034 |
| `showAddLocaleKey()` | L3055 |
| `createLocaleKey()` | L3067 |
| `showHelp()` | L3084 |
| `onDragEnter(event)` | L3126 |
| `onDragOver(event)` | L3133 |
| `onDragLeave()` | L3137 |
| `onDrop(event)` | L3145 |
| `runValidation()` | L3162 |
| `copyText(text)` | L3168 |

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
