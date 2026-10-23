# `SNModMaker/js/io.js`

> 作用：浏览器 I/O：IndexedDB 项目库、文件/文件夹/ZIP 导入、下载、目录导出与本地游戏模组部署 API。

- 类型：浏览器经典脚本

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `DB_NAME` | L8 |
| `DB_VERSION` | L9 |
| `PROJECT_STORE` | L10 |
| `LS_PREFIX` | L11 |
| `openDB()` | L15 |
| `withStore(mode, callback)` | L45 |
| `putProject(project)` | L63 |
| `getProject(uid)` | L67 |
| `deleteProject(uid)` | L77 |
| `listProjects()` | L81 |
| `rememberCurrent(uid)` | L95 |
| `currentUid()` | L104 |
| `setPreference(key, value)` | L112 |
| `getPreference(key, fallback)` | L120 |
| `downloadBytes(bytes, filename, mime)` | L129 |
| `downloadText(text, filename, mime)` | L141 |
| `fileToBytes(file)` | L145 |
| `fileListToEntries(fileList)` | L150 |
| `readDirectoryEntry(reader)` | L160 |
| `readEntry(entry, prefix)` | L175 |
| `dataTransferToEntries(dataTransfer)` | L194 |
| `importZip(file)` | L210 |
| `openFilePicker(options)` | L216 |
| `buildZip(project)` | L243 |
| `exportZip(project)` | L253 |
| `exportProjectFile(project)` | L259 |
| `writeFileTree(rootHandle, entries)` | L266 |
| `exportFolder(project)` | L282 |
| `pickSchemaDirectory()` | L293 |
| `detectBackend()` | L301 |
| `apiJson(url, options)` | L316 |
| `listDiskProjects()` | L330 |
| `getDiskProject(id)` | L335 |
| `projectPayload(project)` | L340 |
| `putDiskProject(project)` | L352 |
| `getWorkspaceProject(id)` | L361 |
| `readWorkspaceAsset(id, relativePath)` | L367 |
| `putWorkspaceProject(project, options)` | L375 |
| `deleteDiskProject(id)` | L386 |
| `listExports()` | L390 |
| `saveExportToDisk(filename, bytes)` | L395 |
| `deleteExport(name)` | L403 |
| `listGameMods()` | L407 |
| `deployGameMod(id, bytes)` | L412 |
| `deleteGameMod(id)` | L420 |
| `SNIO (global)` | L424 |

## 契约与约束

- IndexedDB 数据库 `snmodmaker`、对象仓库 `projects`（keyPath=uid）；打开超过 3 秒视为不可用，由 app 回退 localStorage。
- 文件夹/拖放导入递归读取 `webkitGetAsEntry`；ZIP 交给 `SNZip.read()`。
- 目录导出需要 Chromium 的 `showDirectoryPicker`，在所选父目录下创建 `<mod_id>/`。
- 检测到 `tools/serve.mjs` 时使用同源 `/api` 读写项目、普通导出与游戏模组目录；`detectBackend` 1.5s 超时后静默退化。
- `getWorkspaceProject/putWorkspaceProject` 走 `/api/workspace/<id>`，把 `dev_mods/<id>` 作为原生工作区直接读写；普通磁盘项目仍走 `/api/projects/<id>`，两者按 id 不会互相遮蔽。
- `readWorkspaceAsset(id, path)` 走 `/api/workspace/<id>/asset?path=...`，把工作区里的原始图片惰性转成 data URL；蓝图编辑器用它预览 Core 线稿，资产页仍保持轻量占位。
- deployGameMod(id, bytes) 把已构建 ZIP 交给本地服务覆盖部署；纯静态/file:// 模式不暴露该操作。
- 下载使用 Blob URL；不向外部网络上传任何内容。

模块索引：[SNModMaker](../README.md)
