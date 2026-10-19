# `SNModMaker/tools/serve.mjs`

> 作用：零依赖本地静态服务器 + 磁盘 API：项目工作区、原生模组工作区（dev_mods 原地编辑）、普通导出与发布包模组覆盖部署。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MODS_DIR` | L37 |
| `EXPORTS_DIR` | L38 |
| `GAME_MODS_DIR` | L39 |
| `MAX_BODY` | L40 |
| `MIME` | L42 |
| `sendJson(response, status, body)` | L56 |
| `readBody(request)` | L67 |
| `safeRelative(value)` | L87 |
| `projectDir(id)` | L95 |
| `projectFile(id)` | L99 |
| `WORKSPACE_ROOT` | L107 |
| `DEFAULT_WORKSPACE_ROOT` | L110 |
| `MIME_BY_EXT` | L112 |
| `workspaceDir(id)` | L124 |
| `workspaceIds()` | L128 |
| `countWorkspaceDefinitions(manifest)` | L141 |
| `listWorkspaces()` | L154 |
| `readWorkspaceProject(id)` | L178 |
| `runNodeTool(args, timeoutMs = 30000)` | L231 |
| `validateWorkspace(id)` | L248 |
| `syncCoreIndex()` | L276 |
| `saveWorkspaceProject(id, project, files, options)` | L286 |
| `listProjects()` | L337 |
| `saveProject(id, payload)` | L368 |
| `listExports()` | L403 |
| `safeExportName(value)` | L415 |
| `gameModName(id)` | L421 |
| `listGameMods()` | L425 |
| `deployGameMod(id, body)` | L436 |
| `handleApi(request, response, url)` | L458 |

## 契约与约束

- 仅监听 127.0.0.1；默认端口 8099。支持 `SNMODMAKER_MODS_DIR` / `SNMODMAKER_EXPORTS_DIR` / `SNMODMAKER_GAME_MODS_DIR` / `SNMODMAKER_WORKSPACE_ROOT` 覆盖目录；工作区根默认是仓库 `dev_mods/`。
- 默认部署目标由 `game_mods_dir.mjs` 解析为 `dist/build/<platform>/mods/`（优先已有的导出平台目录）。
- API：status、projects、workspace、exports 与 game-mods；请求体上限 128 MB。
- `/api/workspace/<id>` 直接读写 `dev_mods/<id>`：打开时返回 manifest/content/localization 与资产键占位（不含二进制），保存时只写文本文件并删掉 manifest 不再声明的 content/localization 文件；资产目录永远不动。
- 工作区保存允许删除/新增定义与内容文件；`/api/workspace/<id>` DELETE 被拒绝，避免误删整个原生模组。
- 游戏部署使用稳定文件名 `<id>.snavmod.zip`，临时文件写完后替换目标，并清理同 ID 的旧版本号包，避免重复模组。
- 项目先写临时目录再替换，文件路径拒绝绝对路径、`..`、盘符与超过 16 层。
- 静态文件带 `Cache-Control: no-store`，路径解析后必须位于 SNModMaker 目录内。

模块索引：[SNModMaker](../README.md)
