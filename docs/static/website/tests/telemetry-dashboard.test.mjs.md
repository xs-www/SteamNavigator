# `website/tests/telemetry-dashboard.test.mjs`

> 作用：本地游玩数据看板（`tools/telemetry_dashboard.mjs`）的 Node 测试（node:test，零第三方依赖）：

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `DAY` | L21 |
| `makeTempDir()` | L23 |
| `withDashboard(dataDir, fn)` | L33 |
| `payload(overrides = {})` | L42 |
| `seedSession(dataDir, overrides = {}, index = true, receivedAt = `${DAY}T12:00:00.000Z`)` | L60 |

覆盖页面/健康检查、列表摘要（索引与回退扫描）、日期/条数过滤、单条详情、404/405/422 与路径穿越拒绝、只读性。

## 契约与约束
- 契约：`docs/design/TELEMETRY.md` §4/§5 的存储结构（`sessions/<YYYY-MM-DD>/<id>.json` + `index.ndjson`）。
- 每个用例用临时目录 + 端口 0；只通过 HTTP 访问看板，不 mock 内部函数。
- 断言列表排序（received_at 倒序）、limit 上限裁剪、日期过滤、未知/非法 session_id 的状态码，避免只测 200。
- 测试结束删除临时目录，不依赖 Docker / nginx / 游戏端。

模块索引：[website](../README.md)
