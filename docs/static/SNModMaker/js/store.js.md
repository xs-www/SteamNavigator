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
| `deepClone(value)` | L26 |
| `uid()` | L30 |
| `slugify(text, fallback)` | L35 |
| `localPart(id)` | L46 |
| `namespaceOf(id)` | L52 |
| `keyBase(typeKey, modId, localId)` | L56 |
| `keyBaseOf(definition, typeKey, modId, localId)` | L65 |
| `blankManifest(id, name)` | L73 |
| `createProject(options)` | L96 |
| `applyTemplate(project, templateKey)` | L125 |
| `ensureContentFile(project, typeKey)` | L249 |
| `allDefinitions(project)` | L271 |
| `definitionIdSet(project)` | L281 |
| `uniqueLocalId(project, typeKey, preferred)` | L289 |
| `getLoc(project, locale)` | L307 |
| `addLocale(project, locale, path)` | L311 |
| `removeLocale(project, locale)` | L326 |
| `setLocalization(project, locale, key, value)` | L331 |
| `collectAutoNameKeys(definition)` | L339 |
| `collectDefinitionKeys(definition)` | L358 |
| `fillNestedKeys(definition, typeKey, modId, localId)` | L377 |
| `addDefinition(project, typeKey, options)` | L395 |
| `removeDefinition(project, filePath, index)` | L467 |
| `rewriteKeyBase(value, oldBase, newBase)` | L478 |
| `duplicateDefinition(project, filePath, index)` | L503 |
| `coreIndex()` | L541 |
| `cloneCoreDefinition(project, coreDefinitionId)` | L545 |
| `addAsset(project, asset)` | L589 |
| `removeAsset(project, path)` | L599 |
| `syncManifest(project)` | L605 |
| `touch(project)` | L623 |
| `normalizeProject(raw, options)` | L628 |
| `serialize(project)` | L655 |
| `deserialize(text)` | L659 |
| `bytesToBase64(bytes)` | L663 |
| `base64ToBytes(base64)` | L672 |
| `mimeFor(path)` | L681 |
| `bytesToDataUrl(bytes, mime)` | L693 |
| `dataUrlToBytes(dataUrl)` | L697 |
| `decodeText(data)` | L701 |
| `encodeText(text)` | L706 |
| `toExportFiles(project, options)` | L711 |
| `stripRoot(paths)` | L737 |
| `fromFiles(entries)` | L750 |
| `definitionKeys(project, typeKey)` | L853 |
| `findDefinition(project, filePath, index)` | L857 |
| `localizationValue(project, definition, field, locale)` | L863 |
| `definitionTitle(project, definition)` | L870 |
| `dependencyOnCore(project)` | L878 |
| `SNStore (global)` | L882 |

## 契约与约束

- 项目以 `contentFiles/localization/assets` 为真源，`manifest.content/localization/assets` 每次由 `syncManifest()` 重建。
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
- 新 ID 与键基使用当前模组命名空间，并在名称后追加“副本”。

### `toExportFiles(project, options)`

- 产出 manifest、内容、本地化与二进制资产；`prefix:false` 用于文件夹导出。
- 内容 envelope 只保留 `schema_version/content_type/definitions`。

### `fromFiles(entries)`

- 定位最短路径的 `manifest.json`，剥离根目录；按清单读取内容/本地化/资产。
- 缺失声明文件生成占位并返回 warnings；未知 content_type 跳过。

模块索引：[SNModMaker](../README.md)
