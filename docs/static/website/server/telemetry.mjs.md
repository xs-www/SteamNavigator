# `website/server/telemetry.mjs`

> 作用：游玩数据（telemetry）接收端：校验客户端上传的会话 JSON、按来源限流、写入会话文件与索引，并做 180 天保留清理。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `DEFAULT_PORT` | L49 |
| `DEFAULT_DATA_DIR` | L50 |
| `DEFAULT_MAX_BODY_BYTES` | L51 |
| `DEFAULT_RATE_LIMIT_PER_HOUR` | L52 |
| `DEFAULT_RETENTION_DAYS` | L53 |
| `DEFAULT_CLEANUP_INTERVAL_MS` | L54 |
| `RATE_WINDOW_MS` | L55 |
| `RATE_BUCKET_PRUNE_THRESHOLD` | L56 |
| `HEALTH_PATH` | L57 |
| `SESSION_PATH` | L58 |
| `DAY_PATTERN` | L59 |
| `ISO_TIMESTAMP_PATTERN` | L60 |
| `JSON_CONTENT_TYPE_PATTERN` | L61 |
| `MILLIS_PER_DAY` | L62 |
| `isPlainObject(value)` | L81 |
| `isFiniteNumber(value)` | L85 |
| `isIsoTimestamp(value)` | L89 |
| `utcDayKey(date)` | L98 |
| `startOfUtcDay(date)` | L103 |
| `countCommands(payload)` | L107 |
| `validateSessionPayload(payload)` | L117 |
| `tokenMatches(provided, expected)` | L132 |
| `clientRateKey(req)` | L141 |
| `createRateLimiter(limitPerHour)` | L152 |
| `readRequestBody(req, maxBytes)` | L181 |
| `sendJson(res, statusCode, payload, extraHeaders = {})` | L216 |
| `sendEmpty(res, statusCode, extraHeaders = {})` | L230 |
| `defaultLogger(entry)` | L242 |
| `cleanupOldSessions(options = {})` | L250 |
| `createTelemetryHandler(options = {})` | L299 |
| `appendIndexLine(dayDir, line)` | L332 |
| `writeSession(payload, receivedAt, bodyBytes)` | L342 |
| `maybeCleanup(nowMs)` | L379 |
| `startServer(options = {})` | L521 |

## 契约与约束
- 唯一契约：`docs/design/TELEMETRY.md` §3「上传协议」与 §4「官网接收端」；不改 schema、路由、状态码与存储路径。
- 零第三方依赖：只用 Node 内置模块（node:http / node:fs / node:path / node:url / node:crypto），要求 Node >= 18。
- 隐私：进程日志只记请求结果与字节数，不记录客户端 IP、请求头或载荷内容；IP 只存在内存限流表里，进程退出即消失。
- 限流是单进程内存表；多副本部署时每个副本各自计数（`SN_TELEMETRY_TOKEN` 与实例数一起决定实际配额）。
- TLS / CORS / 请求体上限由前置 nginx 负责（`website/deploy/nginx.conf`）；本模块按 512 KiB 再校验一次。

## 导出
- `createTelemetryHandler(options)`：返回 `async (req, res)`，供 `tools/serve.mjs` 与测试复用。
- `startServer(options)`：监听端口并返回 `{ server, handler, host, port, url, dataDir, close }`。
- `cleanupOldSessions(options)`：180 天保留清理，测试与运维可单独调用。
- `validateSessionPayload(payload)`：校验函数，返回 `null`（合法）或第一个非法字段名。

## 重点逻辑
### 路由与状态码
- `GET /api/telemetry/health` → `200 {"ok":true,"service":"sn-telemetry","schema":"sn.telemetry.session/1"}`。
- `POST /api/telemetry/session` → 校验通过后 `204`（无响应体）；`400` 坏 JSON；`401` 令牌不匹配；
  `413` 超过 `maxBodyBytes`；`422` 字段或 Content-Type 不合法；`429` 超过每小时配额；
  `405` 方法不允许；`404` 未知路径；`500` 落盘失败（客户端下次启动重试）。
### 校验
- JSON 对象 + `schema` 精确等于 `sn.telemetry.session/1` + `session_id` 匹配 `^[A-Za-z0-9_-]{8,64}$`
  （该正则同时是路径穿越防线：文件名只取自 session_id）+ 起止时间为 ISO-8601 字符串 +
  `duration_seconds` 为有限数值。其它字段（commands / events / errors / run / mods）不校验内容，只做摘要计数。
### 存储
- `<dataDir>/sessions/<接收日期 YYYY-MM-DD>/<session_id>.json`：紧凑 JSON，先写临时文件再 rename，同名覆盖（幂等）。
- 同目录 `index.ndjson`：每行一条摘要（session_id / received_at / game_version / duration_seconds /
  commands / errors / bytes）；append 用 Promise 队列串行，避免多请求并发时行交错。
### 限流
- 来源键取 `X-Forwarded-For` 第一段（nginx 写入），否则 socket 地址；每小时 120 次，滑动窗口按桶重置。
- 限流表超过 4096 条时顺手清理过期桶，避免长期运行内存增长。
### 保留清理
- 每次成功写入后检查，最多每小时触发一次；只删除 `sessions/` 下匹配 `YYYY-MM-DD` 且早于
  （今天 UTC - 180 天）的目录，非日期目录/文件一律不动。

模块索引：[website](../README.md)
