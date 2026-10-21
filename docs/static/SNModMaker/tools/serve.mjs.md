# `SNModMaker/tools/serve.mjs`

> 作用：零依赖本地静态服务器 + 磁盘 API：项目工作区、原生模组工作区（dev_mods 原地编辑）、普通导出与发布包模组覆盖部署。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `DRAFT_SCHEMA_VERSIONS` | L35 |
| `schemaVersionForContentType(contentType)` | L49 |
| `MODS_DIR` | L62 |
| `EXPORTS_DIR` | L63 |
| `GAME_MODS_DIR` | L64 |
| `MAX_BODY` | L65 |
| `MIME` | L67 |
| `sendJson(response, status, body)` | L81 |
| `readBody(request)` | L92 |
| `safeRelative(value)` | L112 |
| `projectDir(id)` | L120 |
| `projectFile(id)` | L124 |
| `WORKSPACE_ROOT` | L132 |
| `DEFAULT_WORKSPACE_ROOT` | L135 |
| `MIME_BY_EXT` | L137 |
| `workspaceDir(id)` | L149 |
| `workspaceIds()` | L153 |
| `countWorkspaceDefinitions(manifest)` | L166 |
| `listWorkspaces()` | L179 |
| `readWorkspaceProject(id)` | L203 |
| `runNodeTool(args, timeoutMs = 30000)` | L257 |
| `validateWorkspace(id)` | L274 |
| `syncCoreIndex()` | L302 |
| `saveWorkspaceProject(id, project, files, options)` | L312 |
| `listProjects()` | L363 |
| `saveProject(id, payload)` | L394 |
| `listExports()` | L429 |
| `safeExportName(value)` | L441 |
| `gameModName(id)` | L447 |
| `listGameMods()` | L451 |
| `deployGameMod(id, body)` | L462 |
| `handleApi(request, response, url)` | L484 |

## 契约与约束

- 默认只监听 `127.0.0.1`；`SNMODMAKER_HOST` 可改绑定地址（容器设 `0.0.0.0`），默认端口 8099。支持 `SNMODMAKER_MODS_DIR` / `SNMODMAKER_EXPORTS_DIR` / `SNMODMAKER_GAME_MODS_DIR` / `SNMODMAKER_WORKSPACE_ROOT` 覆盖目录；工作区根默认是仓库 `dev_mods/`。
- 默认部署目标由 `game_mods_dir.mjs` 解析为 `dist/build/<platform>/mods/`（优先已有的导出平台目录）。
- API：status、projects、workspace、exports 与 game-mods；请求体上限 128 MB。
- `/api/workspace/<id>` 直接读写 `dev_mods/<id>`：打开时返回 manifest/content/localization 与资产键占位（不含二进制），保存时只写文本文件并删掉 manifest 不再声明的 content/localization 文件；资产目录永远不动。
- 工作区内容文件缺失 `schema_version` 时按 `content_type` 推导（Schema 2.0 草案 2.0，未知类型回退 1.0）。
- 工作区保存允许删除/新增定义与内容文件；`/api/workspace/<id>` DELETE 被拒绝，避免误删整个原生模组。
- 游戏部署使用稳定文件名 `<id>.snavmod.zip`，临时文件写完后替换目标，并清理同 ID 的旧版本号包，避免重复模组。
- 项目先写临时目录再替换，文件路径拒绝绝对路径、`..`、盘符与超过 16 层。
- 静态文件带 `Cache-Control: no-store`，路径解析后必须位于 SNModMaker 目录内。

模块索引：[SNModMaker](../README.md)
