# `SNModMaker/tools/serve.mjs`

> 作用：零依赖本地静态服务器 + 磁盘 API：项目写入 `mods/<id>/`，ZIP 写入 `exports/`。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MODS_DIR` | L29 |
| `EXPORTS_DIR` | L30 |
| `MAX_BODY` | L31 |
| `MIME` | L33 |
| `sendJson(response, status, body)` | L47 |
| `readBody(request)` | L58 |
| `safeRelative(value)` | L78 |
| `projectDir(id)` | L86 |
| `projectFile(id)` | L90 |
| `listProjects()` | L94 |
| `saveProject(id, payload)` | L125 |
| `listExports()` | L160 |
| `safeExportName(value)` | L172 |
| `handleApi(request, response, url)` | L178 |

## 契约与约束

- 仅监听 127.0.0.1；默认端口 8099。支持 `SNMODMAKER_MODS_DIR` / `SNMODMAKER_EXPORTS_DIR` 覆盖数据目录。
- API：status、projects 的 GET/PUT/DELETE、exports 的 GET/POST/DELETE；请求体上限 128 MB。
- 项目先写临时目录再替换，文件路径拒绝绝对路径、`..`、盘符与超过 16 层。
- 静态文件带 `Cache-Control: no-store`，路径解析后必须位于 SNModMaker 目录内。

模块索引：[SNModMaker](../README.md)
