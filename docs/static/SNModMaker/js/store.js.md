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
| `commitDefinitionLocalization(project, definition, typeKey, oldBase, newBase, translations)` | L509 |
| `duplicateDefinition(project, filePath, index)` | L549 |
| `coreIndex()` | L587 |
| `qualifyCoreAssetReferences(definition)` | L591 |
| `cloneCoreDefinition(project, coreDefinitionId)` | L600 |
| `addAsset(project, asset)` | L645 |
| `removeAsset(project, path)` | L655 |
| `syncManifest(project)` | L661 |
| `touch(project)` | L679 |
| `normalizeProject(raw, options)` | L684 |
| `serialize(project)` | L711 |
| `deserialize(text)` | L715 |
| `bytesToBase64(bytes)` | L719 |
| `base64ToBytes(base64)` | L728 |
| `mimeFor(path)` | L737 |
| `bytesToDataUrl(bytes, mime)` | L750 |
| `dataUrlToBytes(dataUrl)` | L754 |
| `decodeText(data)` | L758 |
| `encodeText(text)` | L763 |
| `toExportFiles(project, options)` | L768 |
| `stripRoot(paths)` | L794 |
| `fromFiles(entries)` | L807 |
| `definitionKeys(project, typeKey)` | L910 |
| `findDefinition(project, filePath, index)` | L914 |
| `localizationValue(project, definition, field, locale)` | L920 |
| `definitionTitle(project, definition)` | L927 |
| `dependencyOnCore(project)` | L935 |
| `SNStore (global)` | L939 |

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
- Core 定义中的贴图/模型裸键改写为 `asset://core/<key>`，使派生条目继续引用官方资源而不冒充当前模组资产。
- 新 ID 与键基使用当前模组命名空间，并在名称后追加“副本”。

### `commitDefinitionLocalization(project, definition, typeKey, oldBase, newBase, translations)`

- 保存条目时才把定义内全部 `_key` 与所有语言文件从旧键基原子迁移到新键基。
- 迁移前检查目标键冲突；成功后删除旧键并覆盖用户在条目内暂存的多语言文本。

### `toExportFiles(project, options)`

- 产出 manifest、内容、本地化与二进制资产；`prefix:false` 用于文件夹导出。
- 内容 envelope 只保留 `schema_version/content_type/definitions`。

### `fromFiles(entries)`

- 定位最短路径的 `manifest.json`，剥离根目录；按清单读取内容/本地化/资产。
- 缺失声明文件生成占位并返回 warnings；未知 content_type 跳过。

模块索引：[SNModMaker](../README.md)
