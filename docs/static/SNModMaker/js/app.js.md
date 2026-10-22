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
| `draftSchemaFootText()` | L660 |
| `renderDraftSideGroup(counts, typeIssues)` | L665 |
| `sideTypeLink(type, count, issues, draft)` | L677 |
| `activeLocale(locale)` | L691 |
| `renderWorkspace()` | L699 |
| `renderWelcome()` | L721 |
| `loadRecent()` | L746 |
| `renderOverview()` | L802 |
| `ovField(labelText, control, hintText, wide)` | L912 |
| `depRow(list, dependency, index)` | L920 |
| `structureTree(project)` | L928 |
| `renderModuleTabs(activeType)` | L956 |
| `renderContent()` | L972 |
| `renderDefinitionEditor(selected, info)` | L1052 |
| `collectNeededKeys(project)` | L1109 |
| `renderLocalization()` | L1124 |
| `renderAssets()` | L1203 |
| `paintModelThumbnails()` | L1245 |
| `runModelThumbQueue()` | L1264 |
| `setModelThumbImage(node, dataUrl)` | L1283 |
| `renderValidation()` | L1293 |
| `issueLocation(issue)` | L1332 |
| `gotoIssue(index)` | L1344 |
| `attrSelector(value)` | L1384 |
| `inspectorData()` | L1392 |
| `renderInspector()` | L1406 |
| `inspectorLabel()` | L1429 |
| `bindEvents()` | L1447 |
| `closeAssetPickers(except)` | L1464 |
| `openAssetPicker(picker)` | L1473 |
| `filterAssetPicker(input)` | L1483 |
| `onClick(event)` | L1498 |
| `selectDefinition(filePath, index)` | L1530 |
| `navigate(kind, argument)` | L1539 |
| `onInput(event)` | L1575 |
| `onChange(event)` | L1623 |
| `onKeyDown(event)` | L1648 |
| `onFocusOut(event)` | L1706 |
| `applyField(element, fromChange)` | L1714 |
| `readValue(element)` | L1762 |
| `markChanged(structural)` | L1789 |
| `updateDefinitionLocalizationPreview(definition, draft)` | L1801 |
| `updateEntityLocaleDraft(element)` | L1820 |
| `updateLocaleValue(element)` | L1835 |
| `filterDefinitionCards()` | L1855 |
| `renderLocalizationListOnly()` | L1862 |
| `autoProjectId(name)` | L1875 |
| `filterCoreList(query)` | L1881 |
| `handleAction(element, event)` | L1892 |
| `saveDefinitionAction()` | L2127 |
| `gotoDefinitionLocalization(field, keyOverride)` | L2164 |
| `addDefinitionAction()` | L2181 |
| `cloneCoreAction(coreId)` | L2192 |
| `deleteDefinitionAction()` | L2208 |
| `duplicateDefinitionAction()` | L2233 |
| `applyRawJson()` | L2244 |
| `addDependency(list)` | L2267 |
| `removeDependency(list, index)` | L2277 |
| `syncNamespace()` | L2286 |
| `gotoKeyDefinition(filePath, index)` | L2331 |
| `deleteLocaleKey(key)` | L2340 |
| `fillMissingKeys()` | L2350 |
| `arrayAdd(path)` | L2372 |
| `nextSocketItem(existing, kind)` | L2387 |
| `defaultArrayItem(path, definition)` | L2416 |
| `arrayRemove(path, index)` | L2441 |
| `arrayMove(path, index, direction)` | L2452 |
| `addListValue(path, input, button)` | L2466 |
| `listRemove(path, index)` | L2490 |
| `enumToggle(path, value, element)` | L2503 |
| `addCondition(path, kind)` | L2520 |
| `removeCondition(path)` | L2532 |
| `changeConditionKind(element)` | L2541 |
| `changeConditionOp(element)` | L2561 |
| `changeEffectOp(element)` | L2581 |
| `addAssets()` | L2605 |
| `removeAsset(path)` | L2647 |
| `downloadAsset(path)` | L2663 |
| `showNewProject()` | L2673 |
| `createProjectFromModal()` | L2706 |
| `showImport()` | L2742 |
| `importFolder()` | L2762 |
| `importFile()` | L2767 |
| `importEntries(entries)` | L2772 |
| `unsupportedContentFiles()` | L2816 |
| `unsupportedContentLabel(files)` | L2820 |
| `unsupportedExportNotice(files)` | L2824 |
| `confirmUnsupportedExport(files, actionLabel)` | L2834 |
| `showExport()` | L2844 |
| `exportZip()` | L2887 |
| `exportZipToDisk()` | L2910 |
| `deployGameMod()` | L2934 |
| `exportProjectFile()` | L2964 |
| `exportFolder()` | L2974 |
| `showProjectLibrary()` | L2987 |
| `openDiskProject(id)` | L3048 |
| `openWorkspaceProject(id)` | L3067 |
| `deleteDiskProject(id)` | L3085 |
| `showCoreClone()` | L3104 |
| `showAddLocale()` | L3135 |
| `createLocale()` | L3150 |
| `showAddLocaleKey()` | L3171 |
| `createLocaleKey()` | L3183 |
| `showHelp()` | L3200 |
| `onDragEnter(event)` | L3242 |
| `onDragOver(event)` | L3249 |
| `onDragLeave()` | L3253 |
| `onDrop(event)` | L3261 |
| `runValidation()` | L3278 |
| `copyText(text)` | L3284 |

## 契约与约束

- `state.project` 是唯一项目源；视图与选择状态不写入导出 JSON。
- 文本输入只更新模型并调度校验/保存，不整页重绘；结构操作才重绘并保留滚动位置。
- 历史快照最多 40 个；一次焦点内的连续输入只压入一个快照。
- 自动保存有 800ms 防抖，并用 revision 防止旧保存清除新改动；IDB 失败回退 localStorage。
- ID 修改与条目内翻译先进入 localizationDrafts；自动保存不写多语言键，只有“保存条目”提交键迁移。
- 船只与模块相关类型共享页面子分页，可直接切换而无需返回侧栏重新选择。
- 「新建模组」对话框的模板卡片来自 `Catalog.TEMPLATES`（goods / boiler / event / weapons / starter_kit / blank）；选 `weapons` 即「舰载武器包」，仅创建编辑器项目内容、不写 Core。
- 侧栏在运行时类型分组之后渲染「Schema 2.0 草案 / 运行时不加载」分区（`DRAFT_TYPES` 为空则隐藏）；草案内容页显示 2.0 徽标与提示，并隐藏「从 Core 复制」。
- 自定义资源选择器支持点击展开、输入搜索、清空和选择写回；点击外部或 Escape 关闭菜单。
- 检测到本地服务时，同一项目再经 1.6s 防抖镜像到 `mods/<id>/`；磁盘失败只降低提示，不阻断浏览器保存。
- 项目库的「磁盘」区同时列出 `mods/` 项目与 `dev_mods/` 工作区：工作区行标「工作区」且不提供删除；`state.workspace` 为真时保存改走 `putWorkspaceProject`，直接写回原生模组目录。
- 导出菜单在本地服务可用时提供发布包部署入口：先保存项目、构建 ZIP，再覆盖 `dist/build/<platform>/mods/<id>.snavmod.zip` 并报告旧包清理数量；若项目含当前运行时不支持的内容（`weapons` 草案 / 未知类型 / 版本不符）则禁用部署，ZIP/目录导出改为二次确认（`unsupportedContentFiles` / `confirmUnsupportedExport`）。Phase B 提升的 2.0 运行时类型可直接部署。
- 没有本地服务时，发布包部署入口以禁用项 + 启动服务指引呈现，而不是完全隐藏。
- 资源页对带 dataUrl 的 GLB 卡片异步生成缩略图；渲染队列逐张执行，失败时保留 GLB 占位。
- Ctrl+S/Z/Shift+Z/N/O/E 为全局快捷键；文本输入中不拦截撤销。

## 重点逻辑

### `applyField(element, fromChange)`

- 区分 manifest 与当前定义；数字/整数/布尔/JSON 各有解析，解析失败不写回。
- 船体安装点的 `array-add` 走 `nextSocketItem` 生成默认 socket 行（weapon / rig 两套默认值），写回仍走 `data-field` 路径与既有撤销 / 校验流程。
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
