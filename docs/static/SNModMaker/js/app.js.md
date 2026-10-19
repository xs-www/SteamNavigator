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
| `init()` | L70 |
| `probeBackend()` | L77 |
| `loadInitialProject()` | L87 |
| `setProject(project, options)` | L119 |
| `clearProject()` | L147 |
| `firstSelection(project)` | L159 |
| `currentFile()` | L173 |
| `currentDefinition()` | L178 |
| `selectedTypeInfo()` | L184 |
| `selectedDefinitionKey()` | L189 |
| `localizationDraft(definition, oldId, syncToId)` | L193 |
| `currentLocalizationDraft()` | L215 |
| `previewLocalizationValue(key, draft)` | L219 |
| `previewLocalizationKey(definition, field, draft)` | L227 |
| `setByPath(object, path, value)` | L231 |
| `getByPath(object, path)` | L247 |
| `deleteByPath(object, path)` | L257 |
| `snapshot()` | L270 |
| `pushHistory()` | L274 |
| `undo()` | L285 |
| `redo()` | L301 |
| `ensureSelection()` | L317 |
| `fallbackKey(uid)` | L333 |
| `loadFallbackProject()` | L337 |
| `saveNow(options)` | L348 |
| `flushDiskSave()` | L392 |
| `openProject(uid)` | L417 |
| `deleteProject(uid)` | L434 |
| `render(options)` | L465 |
| `renderChrome()` | L501 |
| `renderStatus()` | L528 |
| `saveStateText()` | L547 |
| `saveStateTitle()` | L557 |
| `updateSaveState()` | L562 |
| `timeText(date)` | L570 |
| `renderSidebar()` | L578 |
| `sideTypeLink(type, count, issues)` | L636 |
| `activeLocale(locale)` | L647 |
| `renderWorkspace()` | L655 |
| `renderWelcome()` | L677 |
| `loadRecent()` | L702 |
| `renderOverview()` | L758 |
| `ovField(labelText, control, hintText, wide)` | L867 |
| `depRow(list, dependency, index)` | L875 |
| `structureTree(project)` | L883 |
| `renderModuleTabs(activeType)` | L911 |
| `renderContent()` | L927 |
| `renderDefinitionEditor(selected, info)` | L1002 |
| `collectNeededKeys(project)` | L1058 |
| `renderLocalization()` | L1073 |
| `renderAssets()` | L1152 |
| `paintModelThumbnails()` | L1194 |
| `runModelThumbQueue()` | L1213 |
| `setModelThumbImage(node, dataUrl)` | L1232 |
| `renderValidation()` | L1242 |
| `issueLocation(issue)` | L1280 |
| `gotoIssue(index)` | L1292 |
| `attrSelector(value)` | L1332 |
| `inspectorData()` | L1340 |
| `renderInspector()` | L1354 |
| `inspectorLabel()` | L1377 |
| `bindEvents()` | L1395 |
| `closeAssetPickers(except)` | L1412 |
| `openAssetPicker(picker)` | L1421 |
| `filterAssetPicker(input)` | L1431 |
| `onClick(event)` | L1446 |
| `selectDefinition(filePath, index)` | L1478 |
| `navigate(kind, argument)` | L1487 |
| `onInput(event)` | L1523 |
| `onChange(event)` | L1571 |
| `onKeyDown(event)` | L1596 |
| `onFocusOut(event)` | L1654 |
| `applyField(element, fromChange)` | L1662 |
| `readValue(element)` | L1710 |
| `markChanged(structural)` | L1737 |
| `updateDefinitionLocalizationPreview(definition, draft)` | L1749 |
| `updateEntityLocaleDraft(element)` | L1768 |
| `updateLocaleValue(element)` | L1783 |
| `filterDefinitionCards()` | L1803 |
| `renderLocalizationListOnly()` | L1810 |
| `autoProjectId(name)` | L1823 |
| `filterCoreList(query)` | L1829 |
| `handleAction(element, event)` | L1840 |
| `saveDefinitionAction()` | L2072 |
| `gotoDefinitionLocalization(field, keyOverride)` | L2109 |
| `addDefinitionAction()` | L2126 |
| `cloneCoreAction(coreId)` | L2137 |
| `deleteDefinitionAction()` | L2153 |
| `duplicateDefinitionAction()` | L2178 |
| `applyRawJson()` | L2189 |
| `addDependency(list)` | L2212 |
| `removeDependency(list, index)` | L2222 |
| `syncNamespace()` | L2231 |
| `gotoKeyDefinition(filePath, index)` | L2276 |
| `deleteLocaleKey(key)` | L2285 |
| `fillMissingKeys()` | L2295 |
| `arrayAdd(path)` | L2317 |
| `defaultArrayItem(path, definition)` | L2331 |
| `arrayRemove(path, index)` | L2354 |
| `arrayMove(path, index, direction)` | L2365 |
| `addListValue(path, input, button)` | L2379 |
| `listRemove(path, index)` | L2403 |
| `enumToggle(path, value, element)` | L2416 |
| `addCondition(path, kind)` | L2433 |
| `removeCondition(path)` | L2445 |
| `changeConditionKind(element)` | L2454 |
| `changeConditionOp(element)` | L2474 |
| `changeEffectOp(element)` | L2494 |
| `addAssets()` | L2518 |
| `removeAsset(path)` | L2560 |
| `downloadAsset(path)` | L2576 |
| `showNewProject()` | L2586 |
| `createProjectFromModal()` | L2619 |
| `showImport()` | L2655 |
| `importFolder()` | L2675 |
| `importFile()` | L2680 |
| `importEntries(entries)` | L2685 |
| `showExport()` | L2725 |
| `exportZip()` | L2759 |
| `exportZipToDisk()` | L2781 |
| `deployGameMod()` | L2804 |
| `exportProjectFile()` | L2830 |
| `exportFolder()` | L2840 |
| `showProjectLibrary()` | L2852 |
| `openDiskProject(id)` | L2913 |
| `deleteDiskProject(id)` | L2930 |
| `showCoreClone()` | L2949 |
| `showAddLocale()` | L2975 |
| `createLocale()` | L2990 |
| `showAddLocaleKey()` | L3011 |
| `createLocaleKey()` | L3023 |
| `showHelp()` | L3040 |
| `onDragEnter(event)` | L3082 |
| `onDragOver(event)` | L3089 |
| `onDragLeave()` | L3093 |
| `onDrop(event)` | L3101 |
| `runValidation()` | L3118 |
| `copyText(text)` | L3124 |

## 契约与约束

- `state.project` 是唯一项目源；视图与选择状态不写入导出 JSON。
- 文本输入只更新模型并调度校验/保存，不整页重绘；结构操作才重绘并保留滚动位置。
- 历史快照最多 40 个；一次焦点内的连续输入只压入一个快照。
- 自动保存有 800ms 防抖，并用 revision 防止旧保存清除新改动；IDB 失败回退 localStorage。
- ID 修改与条目内翻译先进入 localizationDrafts；自动保存不写多语言键，只有“保存条目”提交键迁移。
- 船只与模块相关类型共享页面子分页，可直接切换而无需返回侧栏重新选择。
- 自定义资源选择器支持点击展开、输入搜索、清空和选择写回；点击外部或 Escape 关闭菜单。
- 检测到本地服务时，同一项目再经 1.6s 防抖镜像到 `mods/<id>/`；磁盘失败只降低提示，不阻断浏览器保存。
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
