# `framework/services/telemetry_uploader.gd`

> 作用：把 `TelemetryService` 的 pending 会话文件串行 POST 到 telemetry_endpoint：请求成功的 200/201/204 删除该文件，其余（超时/网络错误/非 2xx）保留文件并结束本轮；Node + HTTPRequest 实现，不含记录/裁剪业务逻辑。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `TelemetryUploader` | L1 |
| `REQUEST_TIMEOUT_SECONDS` | L24 |
| `SUCCESS_CODES` | L25 |
| `flush_finished (signal)` | L27 |
| `bind(telemetry: TelemetryService) -> void` | L43 |
| `is_busy() -> bool` | L47 |
| `last_summary() -> Dictionary` | L51 |
| `validate_endpoint(endpoint: String) -> Dictionary` | L55 |
| `is_success_response(request_result: int, response_code: int) -> bool` | L62 |
| `apply_response(file_path: String, request_result: int, response_code: int) -> Dictionary` | L67 |
| `flush(endpoint: String, token: String = "") -> Dictionary` | L76 |
| `abort() -> void` | L107 |

- 关键依赖：`TelemetryService`（`pending_files()` / `pending_count()`）、`HTTPRequest`（8 秒超时）

## 契约与约束
- 唯一契约是 `docs/design/TELEMETRY.md` §3「上传协议」：POST JSON、`Content-Type` / `Accept: application/json`、可选 `X-SN-Telemetry-Token`、每次只传一个文件串行、成功 200/201/204 删除、超时 8 秒、失败保留并停止本轮（避免雪崩），下次启动重试。
- 失败绝不弹框；退出流程只在 `_graceful_quit()` 里最多等 3 秒（预算由 Shell 控制），上传器本身不做时限。
- `flush(endpoint, token)` 是协程：`await uploader.flush(...)` 等到本轮结束并返回汇总；启动时的后台补传用 `uploader.call("flush", ...)`（不等待）触发。
- `abort()` 供退出预算打断在途请求：取消 HTTP 请求并立即结束本轮，pending 保留。

## 重点逻辑
### `flush(endpoint, token)`
- 校验 endpoint / service / 树内状态后，按 `pending_files()`（先进先出）逐个发；不同分支都通过 `flush_finished` 返回同一种汇总，方便 Shell 统一等待。
### `apply_response(file_path, request_result, response_code)`
- 纯结果处理（无网络）：只有 `RESULT_SUCCESS` + 200/201/204 才删除文件，其它一律保留；测试与 `_on_request_completed` 共用。
### `_send_next()`
- 一次只发一个文件；成功递减队列继续，任何失败都停住本轮，让下一次启动再试。

模块索引：[framework/services](./README.md)
