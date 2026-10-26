# `website/tools/telemetry_dashboard.mjs`

> 作用：本地「游玩数据看板」：零依赖 Node 服务，在 127.0.0.1:8091 提供单页前端，只读展示遥测接收端落盘在

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `TOOLS_DIR` | L31 |
| `SITE_ROOT` | L32 |
| `DEFAULT_DATA_DIR` | L33 |
| `DEFAULT_HOST` | L34 |
| `DEFAULT_PORT` | L35 |
| `DEFAULT_LIMIT` | L36 |
| `MAX_LIMIT` | L37 |
| `SESSION_ID_PATTERN` | L38 |
| `DAY_PATTERN` | L39 |
| `SESSIONS_PATH` | L40 |
| `isPlainObject(value)` | L42 |
| `parseLimit(raw)` | L46 |
| `normalizeDay(raw)` | L52 |
| `countCommands(payload)` | L57 |
| `summarizePayload(payload, extra)` | L63 |
| `readDayIndex(dayDir)` | L88 |
| `summaryFromIndexRow(row, day)` | L108 |
| `readDaySummaries(day)` | L132 |
| `listDays(dataDir)` | L169 |
| `collectSessions(dataDir, options = {})` | L184 |
| `readSession(dataDir, sessionId, options = {})` | L201 |
| `sendJson(res, statusCode, payload, extraHeaders = {})` | L220 |
| `sendHtml(res, html)` | L233 |
| `createDashboardHandler(options = {})` | L253 |
| `startDashboard(options = {})` | L323 |
| `parseArgs(argv)` | L376 |
| `DASHBOARD_HTML` | L388 |
| `fmtDuration(seconds)` | L485 |
| `fmtTime(iso)` | L492 |
| `fmtBytes(bytes)` | L498 |
| `setStatus(text, isError)` | L504 |
| `setText(id, value)` | L508 |
| `fetchJson(url)` | L510 |
| `renderCards(total, count, dates, sessions)` | L519 |
| `renderDateOptions(dates)` | L530 |
| `renderRows(sessions)` | L539 |
| `renderDetail(body)` | L568 |
| `loadDetail(sessionId)` | L604 |
| `load()` | L612 |

`<dataDir>/sessions/<YYYY-MM-DD>/` 的会话 JSON（列表 + 单条完整载荷）。生产容器挂载同一个数据卷只读运行，
本地预览直接读 `website/.data/telemetry/`。

## 契约与约束
- 契约：`docs/design/TELEMETRY.md` §4/§5（存储结构）与 `docs/design/WEBSITE.md` §10；本工具只读，绝不写数据目录。
- 默认只绑定 `127.0.0.1`，不对外网暴露；生产 compose 也只发布到 `127.0.0.1:8091`，故不做登录（本地单人运维工具）。
- 数据目录结构固定为 `<dataDir>/sessions/<YYYY-MM-DD>/<session_id>.json` 与同目录 `index.ndjson`；
  索引优先，缺失时回退读 JSON（按 mtime/size 现场摘要），不迁移、不修补历史数据。
- `session_id` 必须匹配 `^[A-Za-z0-9_-]{8,64}$`、日期必须匹配 `YYYY-MM-DD`，其余路径参数一律拒绝（防路径穿越）。
- 只使用 Node 内置模块（node:http / node:fs / node:path / node:url），无构建步骤、无外部字体 / CDN。

## 重点逻辑
### 路由
- `GET /` 单页看板；`GET /api/health` 健康检查；`GET /api/sessions?limit=&date=` 列表；
  `GET /api/sessions/<session_id>` 单条完整载荷；其余路径 404，非 GET 405。
### 列表
- 读 `sessions/` 下所有日期目录，优先解析每天的 `index.ndjson`；索引缺失时回退逐文件读取。
  `limit` 默认 100、上限 500；`date` 精确过滤；结果按 `received_at` 倒序，并返回完整日期列表供前端筛选。
### 前端
- 单文件内联 HTML/CSS/JS：日期筛选、条数上限、手动 / 10 秒自动刷新、指标卡、可点击表格与 JSON 详情面板。
- 前端只调用相对路径 `/api/*`，不依赖站点域名、不带任何第三方脚本。

模块索引：[website](../README.md)
