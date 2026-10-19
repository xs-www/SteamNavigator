# `SNModMaker/tools/serve.mjs`

> 作用：零依赖本地静态服务器 + 磁盘 API：项目工作区、普通导出与发布包模组覆盖部署。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MODS_DIR` | L31 |
| `EXPORTS_DIR` | L32 |
| `GAME_MODS_DIR` | L33 |
| `MAX_BODY` | L34 |
| `MIME` | L36 |
| `sendJson(response, status, body)` | L50 |
| `readBody(request)` | L61 |
| `safeRelative(value)` | L81 |
| `projectDir(id)` | L89 |
| `projectFile(id)` | L93 |
| `listProjects()` | L97 |
| `saveProject(id, payload)` | L128 |
| `listExports()` | L163 |
| `safeExportName(value)` | L175 |
| `gameModName(id)` | L181 |
| `listGameMods()` | L185 |
| `deployGameMod(id, body)` | L196 |
| `handleApi(request, response, url)` | L218 |

## 契约与约束

- 仅监听 127.0.0.1；默认端口 8099。支持 `SNMODMAKER_MODS_DIR` / `SNMODMAKER_EXPORTS_DIR` / `SNMODMAKER_GAME_MODS_DIR` 覆盖目录。
- 默认部署目标由 `game_mods_dir.mjs` 解析为 `dist/build/<platform>/mods/`（优先已有的导出平台目录）。
- API：status、projects、exports 与 game-mods；请求体上限 128 MB。
- 游戏部署使用稳定文件名 `<id>.snavmod.zip`，临时文件写完后替换目标，并清理同 ID 的旧版本号包，避免重复模组。
- 项目先写临时目录再替换，文件路径拒绝绝对路径、`..`、盘符与超过 16 层。
- 静态文件带 `Cache-Control: no-store`，路径解析后必须位于 SNModMaker 目录内。

模块索引：[SNModMaker](../README.md)
