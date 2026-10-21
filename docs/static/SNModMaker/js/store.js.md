# `SNModMaker/js/store.js`

> 作用：项目模型与纯数据操作：模板、定义增删改复制、Manifest 同步、导入导出映射与 Core 克隆。

- 关键依赖：`catalog.js`、`core-index.js`
- 类型：浏览器经典脚本

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `FORMAT` | L12 |
| `FORMAT_VERSION` | L13 |
| `MANIFEST_SCHEMA_URL` | L14 |
| `DEFAULT_OPTION_NAMES` | L15 |
| `catalog()` | L22 |
| `schemaVersionFor(typeKey)` | L31 |
| `fileSchemaVersion(file)` | L38 |
| `deepClone(value)` | L46 |
| `uid()` | L50 |
| `slugify(text, fallback)` | L55 |
| `localPart(id)` | L66 |
| `namespaceOf(id)` | L72 |
| `keyBase(typeKey, modId, localId)` | L76 |
| `keyBaseOf(definition, typeKey, modId, localId)` | L85 |
| `blankManifest(id, name)` | L93 |
| `createProject(options)` | L116 |
| `applyTemplate(project, templateKey)` | L145 |
| `ensureContentFile(project, typeKey)` | L269 |
| `allDefinitions(project)` | L291 |
| `draftContentFiles(project)` | L306 |
| `hasDraftContent(project)` | L317 |
| `definitionIdSet(project)` | L321 |
| `uniqueLocalId(project, typeKey, preferred)` | L329 |
| `getLoc(project, locale)` | L347 |
| `addLocale(project, locale, path)` | L351 |
| `removeLocale(project, locale)` | L366 |
| `setLocalization(project, locale, key, value)` | L371 |
| `collectAutoNameKeys(definition)` | L379 |
| `collectDefinitionKeys(definition)` | L398 |
| `fillNestedKeys(definition, typeKey, modId, localId)` | L417 |
| `addDefinition(project, typeKey, options)` | L435 |
| `removeDefinition(project, filePath, index)` | L507 |
| `rewriteKeyBase(value, oldBase, newBase)` | L518 |
| `commitDefinitionLocalization(project, definition, typeKey, oldBase, newBase, translations)` | L549 |
| `duplicateDefinition(project, filePath, index)` | L589 |
| `coreIndex()` | L627 |
| `qualifyCoreAssetReferences(definition)` | L631 |
| `cloneCoreDefinition(project, coreDefinitionId)` | L640 |
| `addAsset(project, asset)` | L685 |
| `removeAsset(project, path)` | L695 |
| `syncManifest(project)` | L701 |
| `touch(project)` | L719 |
| `normalizeProject(raw, options)` | L724 |
| `serialize(project)` | L751 |
| `deserialize(text)` | L755 |
| `bytesToBase64(bytes)` | L759 |
| `base64ToBytes(base64)` | L768 |
| `mimeFor(path)` | L777 |
| `bytesToDataUrl(bytes, mime)` | L790 |
| `dataUrlToBytes(dataUrl)` | L794 |
| `decodeText(data)` | L798 |
| `encodeText(text)` | L803 |
| `toExportFiles(project, options)` | L808 |
| `stripRoot(paths)` | L834 |
| `fromFiles(entries)` | L847 |
| `definitionKeys(project, typeKey)` | L950 |
| `findDefinition(project, filePath, index)` | L954 |
| `localizationValue(project, definition, field, locale)` | L960 |
| `definitionTitle(project, definition)` | L967 |
| `dependencyOnCore(project)` | L975 |
| `SNStore (global)` | L979 |

## 契约与约束

- 项目以 `contentFiles/localization/assets` 为真源，`manifest.content/localization/assets` 每次由 `syncManifest()` 重建。
- `schema_version` 由内容类型推导（运行时类型 1.0、Schema 2.0 草案 2.0）：新建文件、归一化、导出都写类型版本，导出/重新导入保留草案 2.0。
- 所有定义 ID 必须使用本模组命名空间；local ID 在共享 `keyPrefix` 的类型间也保持唯一，避免本地化键碰撞。
- `keyBaseOf()` 优先信任 `name_key` 去掉 `.name` 的前缀，兼容 Core 中 ID local 与键前缀不一致的情况。
- 导出固定加 `mods/<id>/` 前缀；导入接受带/不带前缀的目录与 ZIP，并保留缺失文件为占位以便报错。
- 资产以 data URL 存项目；导出时解码为字节；`checksum` 不在网页端计算。

## 重点逻辑

### `createProject(options)`

- 创建 Manifest + zh_CN/en 两个语言文件，再按模板写入定义；模板包含 goods / boiler / event / starter_kit / blank。
- 模板只使用默认值与 Core 引用，生成后立即由 `syncManifest()` 对齐清单。

### `addDefinition(project, typeKey, options)`

- 生成唯一 local ID、完整 ID、名称/描述键，填充嵌套选项键，并同步创建/更新双语翻译。
- `localeExtras` 用于模板中的公告文本；`optionNamesZh/En` 用于事件选项的可读名。

### `cloneCoreDefinition(project, coreDefinitionId)`

- 深拷贝 Core 定义，按 `name_key` 推导旧键基，改写全部 `_key` 字符串与本地化条目。
- Core 定义中的贴图/模型裸键改写为 `asset://core/<key>`，使派生条目继续引用官方资源而不冒充当前模组资产。
- 新 ID 与键基使用当前模组命名空间，并在名称后追加“副本”。

### `commitDefinitionLocalization(project, definition, typeKey, oldBase, newBase, translations)`

- 保存条目时才把定义内全部 `_key` 与所有语言文件从旧键基原子迁移到新键基。
- 迁移前检查目标键冲突；成功后删除旧键并覆盖用户在条目内暂存的多语言文本。

### `toExportFiles(project, options)`

- 产出 manifest、内容、本地化与二进制资产；`prefix:false` 用于文件夹导出。
- 内容 envelope 保留 `schema_version/content_type/definitions`，`schema_version` 按类型推导。

### `fromFiles(entries)`

- 定位最短路径的 `manifest.json`，剥离根目录；按清单读取内容/本地化/资产。
- 内容文件保留显式 payload 版本（缺失时回退类型版本），让 1.0↔2.0 误配被校验器报出。
- 缺失声明文件生成占位并返回 warnings；未知 content_type 跳过。

模块索引：[SNModMaker](../README.md)
