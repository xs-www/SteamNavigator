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
| `ensureContentFile(project, typeKey)` | L318 |
| `allDefinitions(project)` | L340 |
| `draftContentFiles(project)` | L355 |
| `hasDraftContent(project)` | L366 |
| `definitionIdSet(project)` | L370 |
| `uniqueLocalId(project, typeKey, preferred)` | L378 |
| `getLoc(project, locale)` | L396 |
| `addLocale(project, locale, path)` | L400 |
| `removeLocale(project, locale)` | L415 |
| `setLocalization(project, locale, key, value)` | L420 |
| `collectAutoNameKeys(definition)` | L428 |
| `collectDefinitionKeys(definition)` | L447 |
| `fillNestedKeys(definition, typeKey, modId, localId)` | L466 |
| `addDefinition(project, typeKey, options)` | L484 |
| `removeDefinition(project, filePath, index)` | L556 |
| `rewriteKeyBase(value, oldBase, newBase)` | L567 |
| `commitDefinitionLocalization(project, definition, typeKey, oldBase, newBase, translations)` | L598 |
| `duplicateDefinition(project, filePath, index)` | L638 |
| `coreIndex()` | L676 |
| `qualifyCoreAssetReferences(definition)` | L680 |
| `cloneCoreDefinition(project, coreDefinitionId)` | L689 |
| `addAsset(project, asset)` | L734 |
| `removeAsset(project, path)` | L744 |
| `syncManifest(project)` | L750 |
| `touch(project)` | L768 |
| `normalizeProject(raw, options)` | L773 |
| `serialize(project)` | L800 |
| `deserialize(text)` | L804 |
| `bytesToBase64(bytes)` | L808 |
| `base64ToBytes(base64)` | L817 |
| `mimeFor(path)` | L826 |
| `bytesToDataUrl(bytes, mime)` | L839 |
| `dataUrlToBytes(dataUrl)` | L843 |
| `decodeText(data)` | L847 |
| `encodeText(text)` | L852 |
| `toExportFiles(project, options)` | L857 |
| `stripRoot(paths)` | L883 |
| `fromFiles(entries)` | L896 |
| `definitionKeys(project, typeKey)` | L999 |
| `findDefinition(project, filePath, index)` | L1003 |
| `localizationValue(project, definition, field, locale)` | L1009 |
| `definitionTitle(project, definition)` | L1016 |
| `dependencyOnCore(project)` | L1024 |
| `SNStore (global)` | L1028 |

## 契约与约束

- 项目以 `contentFiles/localization/assets` 为真源，`manifest.content/localization/assets` 每次由 `syncManifest()` 重建。
- `schema_version` 由内容类型推导（运行时类型 1.0、Schema 2.0 草案 2.0）：新建文件、归一化、导出都写类型版本，导出/重新导入保留草案 2.0。
- 所有定义 ID 必须使用本模组命名空间；local ID 在共享 `keyPrefix` 的类型间也保持唯一，避免本地化键碰撞。
- `keyBaseOf()` 优先信任 `name_key` 去掉 `.name` 的前缀，兼容 Core 中 ID local 与键前缀不一致的情况。
- 导出固定加 `mods/<id>/` 前缀；导入接受带/不带前缀的目录与 ZIP，并保留缺失文件为占位以便报错。
- 资产以 data URL 存项目；导出时解码为字节；`checksum` 不在网页端计算。

## 重点逻辑

### `createProject(options)`

- 创建 Manifest + zh_CN/en 两个语言文件，再按模板写入定义；模板包含 goods / boiler / event / weapons / starter_kit / blank。
- `template: null` 时不写 1.0 模板；`drafts` 数组里的每个 Schema 2.0 草案类型由 `addDraftStarter()` 生成一个 contentType/2.0 内容文件与起始定义，并把该类型的 capability 去重写入 `manifest.capabilities`（纯 2.0 项目不附带 1.0 商品起始定义）。
- 模板只使用默认值与 Core 引用，生成后立即由 `syncManifest()` 对齐清单。
- `applyTemplate(project, 'weapons')` 从 `catalog.WEAPON_PRESETS` 生成 5 条 weapons 草案定义（`content/weapons.json`、`schema_version` 2.0），`information.model` 写 `asset://core/model.weapon.<local_id>`，并把 `content.combat.v1` 去重加入 `manifest.capabilities`；只写编辑器项目，不触碰 Core。
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
- 内容文件保留显式 payload 版本（缺失时回退类型版本），让 1.0↔2.0 误配被校验器报出。
- 缺失声明文件生成占位并返回 warnings；未知 content_type 跳过。

模块索引：[SNModMaker](../README.md)
