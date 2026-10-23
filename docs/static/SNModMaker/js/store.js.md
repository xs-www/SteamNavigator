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
| `addDraftStarter(project, typeKey)` | L118 |
| `createProject(options)` | L134 |
| `applyTemplate(project, templateKey)` | L170 |
| `ensureContentFile(project, typeKey)` | L320 |
| `allDefinitions(project)` | L342 |
| `runtimeSupportsFile(file)` | L365 |
| `unsupportedContentFiles(project)` | L381 |
| `draftContentFiles(project)` | L388 |
| `hasDraftContent(project)` | L392 |
| `definitionIdSet(project)` | L396 |
| `uniqueLocalId(project, typeKey, preferred)` | L404 |
| `getLoc(project, locale)` | L422 |
| `addLocale(project, locale, path)` | L426 |
| `removeLocale(project, locale)` | L441 |
| `setLocalization(project, locale, key, value)` | L446 |
| `collectAutoNameKeys(definition, typeKey)` | L454 |
| `collectDefinitionKeys(definition)` | L488 |
| `fillNestedKeys(definition, typeKey, modId, localId)` | L507 |
| `addDefinition(project, typeKey, options)` | L536 |
| `removeDefinition(project, filePath, index)` | L615 |
| `rewriteKeyBase(value, oldBase, newBase)` | L626 |
| `commitDefinitionLocalization(project, definition, typeKey, oldBase, newBase, translations)` | L657 |
| `duplicateDefinition(project, filePath, index)` | L697 |
| `coreIndex()` | L735 |
| `qualifyCoreAssetReferences(definition)` | L739 |
| `cloneCoreDefinition(project, coreDefinitionId)` | L748 |
| `assetKindOf(asset)` | L794 |
| `assetKeyPrefixFor(sourcePath, mime)` | L803 |
| `assetKeySegments(sourcePath)` | L810 |
| `assetKeyFromPath(sourcePath, mime, existingKeys)` | L823 |
| `assetStoragePath(sourcePath, mime, existingPaths)` | L835 |
| `migrateAssetReferences(project, oldKey, newKey)` | L864 |
| `addAsset(project, asset)` | L898 |
| `removeAsset(project, path)` | L908 |
| `syncManifest(project)` | L914 |
| `touch(project)` | L932 |
| `normalizeProject(raw, options)` | L937 |
| `serialize(project)` | L967 |
| `deserialize(text)` | L971 |
| `bytesToBase64(bytes)` | L975 |
| `base64ToBytes(base64)` | L984 |
| `mimeFor(path)` | L993 |
| `bytesToDataUrl(bytes, mime)` | L1006 |
| `dataUrlToBytes(dataUrl)` | L1010 |
| `decodeText(data)` | L1014 |
| `encodeText(text)` | L1019 |
| `toExportFiles(project, options)` | L1024 |
| `stripRoot(paths)` | L1050 |
| `fromFiles(entries)` | L1063 |
| `definitionKeys(project, typeKey)` | L1166 |
| `findDefinition(project, filePath, index)` | L1170 |
| `localizationValue(project, definition, field, locale)` | L1176 |
| `definitionTitle(project, definition)` | L1183 |
| `dependencyOnCore(project)` | L1191 |
| `SNStore (global)` | L1195 |

## 契约与约束

- 项目以 `contentFiles/localization/assets` 为真源，`manifest.content/localization/assets` 每次由 `syncManifest()` 重建。
- `schema_version` 由内容类型推导（D2 后全部 active 类型与草案均写 2.0）：新建文件、归一化、导出都写类型版本，导出/重新导入保留 2.0。
- `runtimeSupportsFile()` / `unsupportedContentFiles()` 判断当前运行时能否加载：未知类型、草案类型（`story_arcs` / `story_levels`）、`schema_version` 与类型期望版本不符 → 不支持；D5 后 42 类 active 2.0 类型全部受支持。`draftContentFiles` / `hasDraftContent` 保留为兼容 alias，供 G8 导出守卫使用。
- 所有定义 ID 必须使用本模组命名空间；local ID 在共享 `keyPrefix` 的类型间也保持唯一，避免本地化键碰撞。
- `keyBaseOf()` 优先信任 `name_key` 去掉 `.name` 的前缀，兼容 Core 中 ID local 与键前缀不一致的情况。
- 导出固定加 `mods/<id>/` 前缀；导入接受带/不带前缀的目录与 ZIP，并保留缺失文件为占位以便报错。
- 资产以 data URL 存项目；导出时解码为字节；`checksum` 不在网页端计算。
- 内容只引用资源键：`assets[]` 保存 `{key,path,...}`，`manifest.assets[key]` 映射相对路径；`assetKeyFromPath()` / `assetStoragePath()` 从导入时的相对路径生成可区分的键与存储路径，重名自动加 `_2` 后缀。

## 重点逻辑

### `createProject(options)`

- 创建 Manifest + zh_CN/en 两个语言文件，再按模板写入定义；模板包含 items / boiler / event / weapons / starter_kit / blank。
- `template: null` 时不写内容模板；`drafts` 数组里的每个 Schema 2.0 草案类型由 `addDraftStarter()` 生成一个 contentType/2.0 内容文件与起始定义，并把该类型的 capability 去重写入 `manifest.capabilities`（纯 2.0 项目不附带默认 items 起始定义）。
- 模板只使用默认值与 Core 引用，生成后立即由 `syncManifest()` 对齐清单。
- `applyTemplate(project, 'weapons')` 从 `catalog.WEAPON_PRESETS` 生成 5 条 weapons 定义（`content/weapons.json`、`schema_version` 2.0），`information.model` 写 `asset://core/model.weapon.<local_id>`，并把 `content.combat.v1` 去重加入 `manifest.capabilities`；D1 起 weapons 是 active 运行时类型，但模板仍只写编辑器项目、不触碰 Core。
- `applyTemplate(project, '<draft_type>')` 与 `new --draft <type>` 的单条起始定义不同：前者是成品包（weapons 5 件），后者走 `addDraftStarter()` 的单条默认值。

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
- 内容文件保留显式 payload 版本（缺失时回退类型版本），让版本误配被校验器报出。
- 缺失声明文件生成占位并返回 warnings；未知 content_type 跳过。

### `assetKeyFromPath(sourcePath, mime, existingKeys) / assetStoragePath(sourcePath, mime, existingPaths)`

- 把 `blueprints/ship_a/side.png` 这类带上层目录的导入路径转成 `icon.blueprints.ship_a.side` 与 `assets/icons/blueprints/ship_a/side.png`；单文件仍退化为文件名。
- 键与路径都在调用方传入的已用集合上去重，重名追加 `_2`、`_3`；`assetKindOf()` 统一图片/模型/音频/其他的分类。

### `migrateAssetReferences(project, oldKey, newKey)`

- 递归遍历全部内容定义，把裸键与 `asset://<本模组>/<旧键>` 改写为新键并返回替换数量；manifest.assets 由 syncManifest 重建。

模块索引：[SNModMaker](../README.md)
