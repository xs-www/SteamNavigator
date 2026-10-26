class_name TelemetryUploader
extends Node
## @static-doc
## 作用：把 `TelemetryService` 的 pending 会话文件串行 POST 到 telemetry_endpoint：请求成功的 200/201/204 删除该文件，其余（超时/网络错误/非 2xx）保留文件并结束本轮；Node + HTTPRequest 实现，不含记录/裁剪业务逻辑。
##
## - 关键依赖：`TelemetryService`（`pending_files()` / `pending_count()`）、`HTTPRequest`（8 秒超时）
##
## ## 契约与约束
## - 唯一契约是 `docs/design/TELEMETRY.md` §3「上传协议」：POST JSON、`Content-Type` / `Accept: application/json`、可选 `X-SN-Telemetry-Token`、每次只传一个文件串行、成功 200/201/204 删除、超时 8 秒、失败保留并停止本轮（避免雪崩），下次启动重试。
## - 失败绝不弹框；退出流程只在 `_graceful_quit()` 里最多等 3 秒（预算由 Shell 控制），上传器本身不做时限。
## - `flush(endpoint, token)` 是协程：`await uploader.flush(...)` 等到本轮结束并返回汇总；启动时的后台补传用 `uploader.call("flush", ...)`（不等待）触发。
## - `abort()` 供退出预算打断在途请求：取消 HTTP 请求并立即结束本轮，pending 保留。
##
## ## 重点逻辑
## ### `flush(endpoint, token)`
## - 校验 endpoint / service / 树内状态后，按 `pending_files()`（先进先出）逐个发；不同分支都通过 `flush_finished` 返回同一种汇总，方便 Shell 统一等待。
## ### `apply_response(file_path, request_result, response_code)`
## - 纯结果处理（无网络）：只有 `RESULT_SUCCESS` + 200/201/204 才删除文件，其它一律保留；测试与 `_on_request_completed` 共用。
## ### `_send_next()`
## - 一次只发一个文件；成功递减队列继续，任何失败都停住本轮，让下一次启动再试。
## @end-static-doc

## §3「上传协议」：单请求超时 8 秒。
const REQUEST_TIMEOUT_SECONDS := 8.0
const SUCCESS_CODES: Array[int] = [200, 201, 204]

signal flush_finished(summary: Dictionary)

var service: TelemetryService = null

var _http: HTTPRequest = null
var _busy := false
var _cancelled := false
var _pending: PackedStringArray = PackedStringArray()
var _index := 0
var _uploaded := 0
var _attempted := 0
var _endpoint := ""
var _token := ""
var _last_summary: Dictionary = {}


func bind(telemetry: TelemetryService) -> void:
	service = telemetry


func is_busy() -> bool:
	return _busy


func last_summary() -> Dictionary:
	return _last_summary.duplicate(true)


static func validate_endpoint(endpoint: String) -> Dictionary:
	## 与设置层同一套规范化规则：非法 endpoint 不发请求（测试用无效值验证失败分支）。
	if TelemetryService.is_valid_endpoint(endpoint):
		return {"ok": true, "error": ""}
	return {"ok": false, "error": "invalid_endpoint"}


static func is_success_response(request_result: int, response_code: int) -> bool:
	## §3：只有请求成功且状态码 200/201/204 才算上传成功；3xx/4xx/5xx 都保留文件。
	return request_result == HTTPRequest.RESULT_SUCCESS and SUCCESS_CODES.has(response_code)


static func apply_response(file_path: String, request_result: int, response_code: int) -> Dictionary:
	## 纯结果处理：成功删除 pending 文件，失败原样保留（§3）。
	if is_success_response(request_result, response_code):
		DirAccess.remove_absolute(file_path)
		return {"ok": not FileAccess.file_exists(file_path), "deleted": not FileAccess.file_exists(file_path), "file": file_path}
	return {"ok": false, "deleted": false, "file": file_path}


## 串行补传 pending 文件；返回 `{ok, error, endpoint, attempted, uploaded, remaining}`。
func flush(endpoint: String, token: String = "") -> Dictionary:
	if _busy:
		return _summary(false, "busy")
	var validation := validate_endpoint(endpoint)
	if not bool(validation.get("ok", false)):
		return _summary(false, String(validation.get("error", "invalid_endpoint")))
	if service == null:
		return _summary(false, "no_service")
	if not is_inside_tree():
		# HTTPRequest 需要场景树才能处理轮询；测试/工具不该在这里发真实请求。
		return _summary(false, "not_in_tree")
	var files := service.pending_files()
	if files.is_empty():
		return _summary(true, "")
	_endpoint = endpoint
	_token = token
	_pending = files
	_index = 0
	_uploaded = 0
	_attempted = 0
	_cancelled = false
	_busy = true
	_send_next()
	if not _busy:
		# 请求没能启动（同步失败）：结果已经通过 flush_finished 发出，直接返回汇总。
		return _last_summary.duplicate(true) if not _last_summary.is_empty() else _summary(false, "request_failed")
	var result: Variant = await flush_finished
	return result if result is Dictionary else _summary(false, "no_result")


## 退出预算到期时打断在途请求：取消 HTTP 并结束本轮，pending 保留给下次启动。
func abort() -> void:
	if not _busy:
		return
	_cancelled = true
	if _http != null and is_instance_valid(_http):
		_http.cancel_request()
	_finish(false, "aborted")


func _ensure_http() -> void:
	if _http != null and is_instance_valid(_http):
		return
	_http = HTTPRequest.new()
	_http.name = "HTTPRequest"
	_http.timeout = REQUEST_TIMEOUT_SECONDS
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)


func _send_next() -> void:
	if _cancelled:
		_finish(false, "aborted")
		return
	if _index >= _pending.size():
		_finish(true, "")
		return
	var file_path := _pending[_index]
	var body := JsonUtils.read_text(file_path)
	if body.is_empty():
		_finish(false, "empty_file")
		return
	_ensure_http()
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	if not _token.is_empty():
		headers.append("X-SN-Telemetry-Token: %s" % _token)
	_attempted += 1
	var error := _http.request(_endpoint, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		_finish(false, "request_failed")


func _on_request_completed(request_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if not _busy or _cancelled:
		return
	var file_path := _pending[_index]
	var applied := apply_response(file_path, request_result, response_code)
	if not bool(applied.get("deleted", false)):
		# §3：失败保留文件并停止本轮，下次启动再试。
		var failure := "request_error"
		if request_result == HTTPRequest.RESULT_SUCCESS:
			failure = "http_%d" % response_code
		_finish(false, failure)
		return
	_uploaded += 1
	_index += 1
	_send_next()


func _finish(ok: bool, error: String) -> void:
	_busy = false
	var summary := _summary(ok, error)
	_last_summary = summary
	flush_finished.emit(summary)


func _summary(ok: bool, error: String) -> Dictionary:
	return {
		"ok": ok,
		"error": error,
		"endpoint": _endpoint,
		"attempted": _attempted,
		"uploaded": _uploaded,
		"remaining": service.pending_count() if service != null else 0,
	}
