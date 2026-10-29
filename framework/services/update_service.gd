class_name UpdateService
extends Node
## @static-doc
## 作用：游戏内自动更新：读取网站 `/api/site/update`、比较本地安装哈希、按「只换 core 包 / 换整个 exe」两种粒度下载并校验，最后交给 `UpdateApplier` 完成文件替换。契约见 `docs/design/AUTO_UPDATE.md`。
##
## - 关键依赖：`HTTPRequest`、`UpdateApplier`、`JsonUtils`、`FileAccess.get_sha256`、`ZIPReader`
##
## ## 契约与约束
## - 只在发布版（`OS.has_feature("template")`）真正联网；编辑器与 `--script` 测试永不发请求，静态函数可直接单测。
## - 清单必须 `schema = 1`；所有下载先写 `*.part`，校验字节数与 SHA-256 通过后才改名并应用；失败保留旧安装。
## - 允许写入：`user://updates/**`、`mods/core-*.snavmod.zip`（经 `UpdateApplier` 暂存）、`SteamNavigator.exe`（自替换）。
## - 不做降级：远端 `published_at` 早于本地 `install.json` 时视为已是最新。
## - 断网/清单异常不阻塞启动：自动检查静默失败；手动检查显示可读错误。
##
## ## 重点逻辑
## ### `decide(info, local)`
## - engine 哈希不同 → `full`（下载平台 ZIP，解压后自替换 exe + core）；只有 core 不同 → `core`（约 40 MB）；都相同 → `none`。
## ### `download()`
## - 优先同源镜像 URL（相对路径按 endpoint 的 origin 解析），为空时回退 GitHub；失败重试一次 fallback；`_process` 每 200 ms 发一次进度。
## @end-static-doc

signal state_changed(state: Dictionary)
signal restart_requested()

const DEFAULT_ENDPOINT := "https://steamnavigator.playthought.cn/api/site/update"
const MANIFEST_SCHEMA := 1
const UPDATE_ROOT := "user://updates"
const CORE_SUFFIX := ".snavmod.zip"
const CHECK_TIMEOUT := 8.0
const MAX_DOWNLOAD_BYTES := 512 * 1024 * 1024
const RETRY_LIMIT := 1

const PHASE_IDLE := "idle"
const PHASE_CHECKING := "checking"
const PHASE_UP_TO_DATE := "up_to_date"
const PHASE_AVAILABLE := "available"
const PHASE_DOWNLOADING := "downloading"
const PHASE_STAGED := "staged"
const PHASE_ERROR := "error"

var endpoint: String = DEFAULT_ENDPOINT
var auto_check: bool = true
var state: Dictionary = _idle_state()

var _http: HTTPRequest = null
var _mode := ""
var _manual := false
var _info: Dictionary = {}
var _decision: Dictionary = {}
var _kind := ""
var _target_final := ""
var _target_tmp := ""
var _remote_url := ""
var _fallback_url := ""
var _expected_size := 0
var _expected_sha := ""
var _retried := false
var _last_progress_emit := 0
var _cancel_requested := false
var _staging_dir := ""


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "UpdateHTTP"
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	set_process(false)


func configure(endpoint_value: String, auto: bool) -> void:
	endpoint = normalize_endpoint(endpoint_value)
	auto_check = auto


func snapshot() -> Dictionary:
	return state.duplicate(true)


## 手动检查；`auto` 为 true 时失败静默回到 idle。
func check(manual: bool = true) -> void:
	if _mode != "":
		return
	if not OS.has_feature("template") or endpoint.is_empty():
		_set_state({"phase": PHASE_IDLE if not manual else PHASE_ERROR, "error": "" if not manual else "unsupported_build"})
		return
	_manual = manual
	_mode = "check"
	_cancel_requested = false
	_set_state({"phase": PHASE_CHECKING, "error": "", "progress": 0.0, "downloaded": 0, "total": 0})
	_http.timeout = CHECK_TIMEOUT
	var started := _http.request(endpoint, PackedStringArray(["Accept: application/json"]))
	if started != OK:
		_finish_check_error("check_request_failed")


func download() -> void:
	if _mode != "" or String(state.get("phase", "")) != PHASE_AVAILABLE:
		return
	var file: Dictionary = _decision.get("file", {})
	var url := resolve_url(endpoint, String(file.get("url", "")), String(file.get("fallback_url", "")))
	if url.is_empty():
		_set_state({"phase": PHASE_ERROR, "error": "download_url_missing"})
		return
	_kind = String(_decision.get("action", ""))
	_target_final = _download_path()
	_target_tmp = _target_final + ".part"
	if _target_final.is_empty():
		_set_state({"phase": PHASE_ERROR, "error": "update_path_unavailable"})
		return
	if not _ensure_directory(_target_final.get_base_dir()):
		_set_state({"phase": PHASE_ERROR, "error": "update_directory_failed"})
		return
	_remove_file(_target_tmp)
	_remote_url = url
	_fallback_url = resolve_url(endpoint, "", String(file.get("fallback_url", "")))
	_expected_size = int(file.get("size", 0))
	_expected_sha = String(file.get("sha256", "")).to_lower()
	_retried = false
	_start_download(url)


func cancel() -> void:
	if _mode != "download":
		return
	_cancel_requested = true
	_http.cancel_request()


func restart_game() -> void:
	if String(state.get("phase", "")) != PHASE_STAGED:
		return
	restart_requested.emit()


func _start_download(url: String) -> void:
	_mode = "download"
	_http.timeout = 0.0
	_http.download_file = _target_tmp
	_set_state({
		"phase": PHASE_DOWNLOADING,
		"error": "",
		"progress": 0.0,
		"downloaded": 0,
		"total": _expected_size,
	})
	set_process(true)
	var started := _http.request(url)
	if started != OK:
		_finish_download_error("download_request_failed")


func _process(_delta: float) -> void:
	if _mode != "download" or _http == null:
		return
	var body_size := int(_http.get_body_size())
	var downloaded := int(_http.get_downloaded_bytes())
	if body_size <= 0:
		return
	var now := Time.get_ticks_msec()
	if now - _last_progress_emit < 200:
		return
	_last_progress_emit = now
	var progress := clampf(float(downloaded) / float(body_size), 0.0, 1.0)
	_set_state({"downloaded": downloaded, "total": body_size, "progress": progress})


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _mode == "check":
		_handle_check(result, response_code, body)
	elif _mode == "download":
		_handle_download(result, response_code)


func _handle_check(result: int, response_code: int, body: PackedByteArray) -> void:
	_mode = ""
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_finish_check_error("network_error")
		return
	var payload: Variant = JSON.parse_string(body.get_string_from_utf8())
	var parsed := parse_update_payload(payload)
	if not bool(parsed.get("ok", false)):
		_finish_check_error(String(parsed.get("error", "payload_invalid")))
		return
	_info = parsed["info"]
	var local := local_state(OS.get_executable_path(), _mods_dir(), UpdateApplier.install_path(UpdateApplier.default_exe_dir()))
	_decision = decide(_info, local)
	match String(_decision.get("action", "none")):
		"full", "core":
			var file: Dictionary = _decision.get("file", {})
			_set_state({
				"phase": PHASE_AVAILABLE,
				"error": "",
				"tag": String(_info.get("tag", "")),
				"current_tag": String(local.get("tag", "")),
				"action": String(_decision.get("action", "")),
				"size": int(file.get("size", 0)),
				"progress": 0.0,
				"downloaded": 0,
				"total": 0,
			})
		"unavailable":
			_finish_check_error("update_package_unavailable")
		_:
			_set_state({
				"phase": PHASE_UP_TO_DATE,
				"error": "",
				"tag": String(_info.get("tag", "")),
				"current_tag": String(local.get("tag", "")),
				"progress": 0.0,
			})


func _handle_download(result: int, response_code: int) -> void:
	_mode = ""
	set_process(false)
	if _cancel_requested:
		_cleanup_partial()
		_set_state({"phase": PHASE_AVAILABLE, "error": "", "progress": 0.0, "downloaded": 0, "total": 0})
		return
	if result != HTTPRequest.RESULT_SUCCESS or (response_code != 200 and response_code != 206):
		_retry_or_fail("network_error")
		return
	if not FileAccess.file_exists(_target_tmp):
		_retry_or_fail("download_missing")
		return
	var size := UpdateApplier.file_size(_target_tmp)
	if _expected_size > 0 and size != _expected_size:
		_retry_or_fail("download_size_mismatch")
		return
	if _expected_size > MAX_DOWNLOAD_BYTES:
		_retry_or_fail("download_too_large")
		return
	var sha := FileAccess.get_sha256(_target_tmp).to_lower()
	if not _expected_sha.is_empty() and sha != _expected_sha:
		_retry_or_fail("download_sha256_mismatch")
		return
	if not _ensure_directory(_target_final.get_base_dir()) \
			or DirAccess.rename_absolute(_target_tmp, _target_final) != OK:
		_retry_or_fail("download_finalize_failed")
		return
	_apply_download()


func _retry_or_fail(code: String) -> void:
	_cleanup_partial()
	if not _retried and not _fallback_url.is_empty() and _fallback_url != _remote_url:
		_retried = true
		_remote_url = _fallback_url
		_start_download(_fallback_url)
		return
	_set_state({"phase": PHASE_ERROR, "error": code, "progress": 0.0})


func _finish_check_error(code: String) -> void:
	if _manual:
		_set_state({"phase": PHASE_ERROR, "error": code})
	else:
		_set_state({"phase": PHASE_IDLE, "error": ""})


func _finish_download_error(code: String) -> void:
	_cleanup_partial()
	_set_state({"phase": PHASE_ERROR, "error": code, "progress": 0.0})


## 下载完成后的应用：core 只暂存；full 先自替换 exe，再把新 core 暂存，重启后统一生效。
func _apply_download() -> void:
	var windows: Dictionary = _info.get("manifest", {}).get("platforms", {}).get("windows", {})
	if _kind == "core":
		var exe_dir := UpdateApplier.default_exe_dir()
		var local := local_state(OS.get_executable_path(), _mods_dir(), UpdateApplier.install_path(exe_dir))
		var staged := UpdateApplier.stage_content(_target_final, {
			"tag": String(_info.get("tag", "")),
			"published_at": String(_info.get("published_at", "")),
			"engine_sha256": String(local.get("engine_sha256", "")),
			"core_sha256": String(windows.get("core", {}).get("sha256", "")),
		})
		if not bool(staged.get("ok", false)):
			_finish_download_error(String(staged.get("error", "stage_failed")))
			return
		_remove_file(_target_final)
		_staged_success()
		return
	# full：解压平台包里的 exe 与 core，exe 自替换成功后再暂存 core。
	var staging := UPDATE_ROOT.path_join("staging")
	_remove_tree(staging)
	var extracted := extract_package(_target_final, staging, windows)
	if not bool(extracted.get("ok", false)):
		_finish_download_error(String(extracted.get("error", "extract_failed")))
		return
	var swapped := UpdateApplier.swap_engine(String(extracted.get("engine_path", "")), OS.get_executable_path())
	if not bool(swapped.get("ok", false)):
		_remove_tree(staging)
		_finish_download_error(String(swapped.get("error", "engine_swap_failed")))
		return
	var staged := UpdateApplier.stage_content(String(extracted.get("core_path", "")), {
		"tag": String(_info.get("tag", "")),
		"published_at": String(_info.get("published_at", "")),
		"engine_sha256": String(windows.get("engine", {}).get("sha256", "")),
		"core_sha256": String(windows.get("core", {}).get("sha256", "")),
	})
	if not bool(staged.get("ok", false)):
		_finish_download_error(String(staged.get("error", "stage_failed")))
		return
	_remove_tree(staging)
	_remove_file(_target_final)
	_staged_success()


func _staged_success() -> void:
	_set_state({
		"phase": PHASE_STAGED,
		"error": "",
		"tag": String(_info.get("tag", "")),
		"can_restart": true,
		"progress": 1.0,
	})


func _mods_dir() -> String:
	return UpdateApplier.default_exe_dir().path_join("mods")


func _download_path() -> String:
	var tag := String(_info.get("tag", ""))
	var file: Dictionary = _decision.get("file", {})
	var name := String(file.get("name", ""))
	if name.is_empty():
		name = String(_decision.get("file_name", ""))
	if tag.is_empty() or name.is_empty() or name.contains("/") or name.contains("\\") or name.contains(".."):
		return ""
	return UPDATE_ROOT.path_join(tag).path_join(name)


func _cleanup_partial() -> void:
	if not _target_tmp.is_empty():
		_remove_file(_target_tmp)


static func _idle_state() -> Dictionary:
	return {
		"phase": PHASE_IDLE,
		"tag": "",
		"current_tag": "",
		"action": "",
		"error": "",
		"progress": 0.0,
		"downloaded": 0,
		"total": 0,
		"can_restart": false,
	}


func _set_state(patch: Dictionary) -> void:
	state = state.duplicate(true)
	for key in patch.keys():
		state[key] = patch[key]
	state_changed.emit(snapshot())


static func _remove_file(path: String) -> void:
	if not path.is_empty() and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _ensure_directory(path: String) -> bool:
	if path.is_empty():
		return false
	if DirAccess.dir_exists_absolute(path):
		return true
	return DirAccess.make_dir_recursive_absolute(path) == OK


static func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var files := DirAccess.get_files_at(path)
	for name in files:
		DirAccess.remove_absolute(path.path_join(name))
	var dirs := DirAccess.get_directories_at(path)
	for name in dirs:
		_remove_tree(path.path_join(name))
	DirAccess.remove_absolute(path)


## ---------------------------------------------------------------------------
## 纯函数（可单测，不碰网络）
## ---------------------------------------------------------------------------


static func normalize_endpoint(value: String) -> String:
	var text := value.strip_edges()
	if not (text.begins_with("http://") or text.begins_with("https://")):
		return DEFAULT_ENDPOINT
	var rest := text.trim_prefix("https://").trim_prefix("http://")
	var host := rest.get_slice("/", 0)
	if host.is_empty() or host.contains(" "):
		return DEFAULT_ENDPOINT
	return text


## 把镜像相对路径（/downloads/...）解析成 endpoint 同源绝对地址；空串时用 fallback。
static func resolve_url(endpoint_value: String, value: String, fallback: String) -> String:
	var path := value.strip_edges()
	if _is_http(path):
		return path
	if path.begins_with("/") and not path.begins_with("//"):
		var scheme := "https"
		var rest := endpoint_value
		if rest.begins_with("http://"):
			scheme = "http"
			rest = rest.trim_prefix("http://")
		elif rest.begins_with("https://"):
			rest = rest.trim_prefix("https://")
		var host := rest.get_slice("/", 0)
		if not host.is_empty():
			return "%s://%s%s" % [scheme, host, path]
	var direct := fallback.strip_edges()
	return direct if _is_http(direct) else ""


static func _is_http(value: String) -> bool:
	return value.begins_with("http://") or value.begins_with("https://")


## 解析 /api/site/update 的 JSON：{ok, data:{tag, published_at, manifest, files}} → {ok, info} / {ok:false, error}。
static func parse_update_payload(payload: Variant) -> Dictionary:
	if typeof(payload) != TYPE_DICTIONARY:
		return {"ok": false, "error": "payload_invalid"}
	if not bool((payload as Dictionary).get("ok", false)):
		return {"ok": false, "error": String((payload as Dictionary).get("error", "api_error"))}
	var data: Variant = (payload as Dictionary).get("data")
	if typeof(data) != TYPE_DICTIONARY:
		return {"ok": false, "error": "data_invalid"}
	var tag := String((data as Dictionary).get("tag", ""))
	var published_at := String((data as Dictionary).get("published_at", ""))
	if tag.is_empty() or not UpdateApplier.is_utc_timestamp(published_at):
		return {"ok": false, "error": "tag_or_timestamp_invalid"}
	var manifest: Variant = (data as Dictionary).get("manifest")
	var validated := validate_manifest(manifest)
	if not bool(validated.get("ok", false)):
		return {"ok": false, "error": String(validated.get("error", "manifest_invalid"))}
	var windows: Dictionary = validated["windows"]
	var files_result := _validate_files((data as Dictionary).get("files", {}))
	if not bool(files_result.get("ok", false)):
		return {"ok": false, "error": String(files_result.get("error", "files_invalid"))}
	return {
		"ok": true,
		"error": "",
		"info": {
			"tag": tag,
			"published_at": published_at,
			"manifest": validated["manifest"],
			"windows": windows,
			"files": files_result["files"],
		},
	}


## schema=1 + 平台字段校验；返回规范化后的 windows 字典（数值统一为 int，哈希转小写）。
static func validate_manifest(manifest: Variant) -> Dictionary:
	if typeof(manifest) != TYPE_DICTIONARY:
		return {"ok": false, "error": "manifest_not_object"}
	var value: Dictionary = manifest
	if int(value.get("schema", 0)) != MANIFEST_SCHEMA:
		return {"ok": false, "error": "manifest_schema_unsupported"}
	if String(value.get("tag", "")).is_empty() or not UpdateApplier.is_utc_timestamp(String(value.get("published_at", ""))):
		return {"ok": false, "error": "manifest_tag_or_timestamp_invalid"}
	var platforms: Variant = value.get("platforms")
	if typeof(platforms) != TYPE_DICTIONARY:
		return {"ok": false, "error": "manifest_platforms_invalid"}
	var windows_raw: Variant = (platforms as Dictionary).get("windows")
	if typeof(windows_raw) != TYPE_DICTIONARY:
		return {"ok": false, "error": "manifest_windows_missing"}
	var windows: Dictionary = windows_raw
	var normalized := {}
	for key in ["engine", "core", "package"]:
		var entry: Variant = windows.get(key)
		if typeof(entry) != TYPE_DICTIONARY:
			return {"ok": false, "error": "manifest_%s_missing" % key}
		var sha := String((entry as Dictionary).get("sha256", "")).to_lower()
		var size := int((entry as Dictionary).get("size", 0))
		if not UpdateApplier.is_hex64(sha) or size <= 0:
			return {"ok": false, "error": "manifest_%s_invalid" % key}
		var entry_name := String((entry as Dictionary).get("path", (entry as Dictionary).get("name", "")))
		if key == "engine" and entry_name != "SteamNavigator.exe":
			return {"ok": false, "error": "manifest_engine_path_invalid"}
		if key == "core" and not (entry_name.begins_with("mods/") and entry_name.ends_with(".snavmod.zip")):
			return {"ok": false, "error": "manifest_core_path_invalid"}
		if key == "package" and (not entry_name.ends_with("-windows.zip") or entry_name.contains("/")):
			return {"ok": false, "error": "manifest_package_name_invalid"}
		normalized[key] = {"name": entry_name.get_file(), "path": entry_name, "size": size, "sha256": sha}
	var result := value.duplicate(true)
	result["platforms"] = {"windows": normalized}
	return {"ok": true, "error": "", "manifest": result, "windows": normalized}


static func _validate_files(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {"ok": false, "error": "files_not_object"}
	var files := {}
	for key in ["package", "core"]:
		var entry: Variant = (raw as Dictionary).get(key)
		if typeof(entry) != TYPE_DICTIONARY:
			return {"ok": false, "error": "files_%s_missing" % key}
		var value: Dictionary = entry
		var url := String(value.get("url", ""))
		var fallback := String(value.get("fallback_url", ""))
		if not url.is_empty() and not (url.begins_with("/") or _is_http(url)):
			return {"ok": false, "error": "files_%s_url_invalid" % key}
		if fallback.is_empty() or not _is_http(fallback):
			return {"ok": false, "error": "files_%s_fallback_invalid" % key}
		files[key] = {
			"url": url,
			"fallback_url": fallback,
			"size": int(value.get("size", 0)),
			"sha256": String(value.get("sha256", "")).to_lower(),
		}
	return {"ok": true, "error": "", "files": files}


## 本地安装状态：`config/install.json` 是更新器自己写的版本事实（避免每次检查重算 115 MB exe / 40 MB core）；
## 缺失或字段为空时用实际文件哈希兜底。实际应用前 `UpdateApplier` 仍会逐文件复验 SHA。
static func local_state(exe_path: String, mods_dir: String, install_path: String) -> Dictionary:
	var install: Dictionary = UpdateApplier.read_install(install_path) if not install_path.is_empty() else {"found": false}
	var engine_sha := String(install.get("engine_sha256", "")).to_lower()
	if engine_sha.is_empty() and FileAccess.file_exists(exe_path):
		engine_sha = FileAccess.get_sha256(exe_path).to_lower()
	var core_path := find_core_pack(mods_dir)
	var core_sha := String(install.get("core_sha256", "")).to_lower()
	if core_sha.is_empty() and not core_path.is_empty():
		core_sha = FileAccess.get_sha256(core_path).to_lower()
	return {
		"found": bool(install.get("found", false)),
		"tag": String(install.get("tag", "")),
		"published_at": String(install.get("published_at", "")),
		"engine_sha256": engine_sha,
		"core_sha256": core_sha,
		"core_path": core_path,
	}


static func find_core_pack(mods_dir: String) -> String:
	if mods_dir.is_empty() or not DirAccess.dir_exists_absolute(mods_dir):
		return ""
	var files := DirAccess.get_files_at(mods_dir)
	if files.is_empty():
		return ""
	for name in files:
		if name.begins_with("core-") and name.ends_with(CORE_SUFFIX):
			return mods_dir.path_join(name)
	return ""


## 决策：full（换 exe+core）/ core（只换 content）/ none / unavailable（有更新但无可用下载）。
static func decide(info: Dictionary, local: Dictionary) -> Dictionary:
	var windows: Dictionary = info.get("windows", {})
	var files: Dictionary = info.get("files", {})
	var remote_published := String(info.get("published_at", ""))
	var local_published := String(local.get("published_at", ""))
	if not local_published.is_empty() and UpdateApplier.timestamp_value(local_published) > UpdateApplier.timestamp_value(remote_published) \
			and UpdateApplier.timestamp_value(remote_published) >= 0:
		return {"action": "none", "reason": "local_newer"}
	var remote_engine := String(windows.get("engine", {}).get("sha256", ""))
	var remote_core := String(windows.get("core", {}).get("sha256", ""))
	if remote_engine != String(local.get("engine_sha256", "")).to_lower():
		var package: Dictionary = files.get("package", {})
		if not _download_ready(package, windows.get("package", {})):
			return {"action": "unavailable", "reason": "package_unavailable"}
		var payload := package.duplicate(true)
		payload["name"] = String(windows.get("package", {}).get("name", ""))
		return {"action": "full", "reason": "engine_changed", "file": payload, "engine": windows.get("engine", {}), "core": windows.get("core", {})}
	if remote_core != String(local.get("core_sha256", "")).to_lower():
		var core_file: Dictionary = files.get("core", {})
		if not _download_ready(core_file, windows.get("core", {})):
			return {"action": "unavailable", "reason": "core_unavailable"}
		var payload := core_file.duplicate(true)
		payload["name"] = String(windows.get("core", {}).get("name", ""))
		return {"action": "core", "reason": "core_changed", "file": payload, "engine": windows.get("engine", {}), "core": windows.get("core", {})}
	return {"action": "none", "reason": "up_to_date"}


static func _download_ready(file: Dictionary, manifest_entry: Dictionary) -> bool:
	if file.is_empty() or manifest_entry.is_empty():
		return false
	if String(file.get("url", "")).is_empty() and String(file.get("fallback_url", "")).is_empty():
		return false
	var expected := String(manifest_entry.get("sha256", "")).to_lower()
	if expected.is_empty():
		return false
	var declared := String(file.get("sha256", "")).to_lower()
	if not declared.is_empty() and declared != expected:
		return false
	var size := int(manifest_entry.get("size", 0))
	return size > 0 and (int(file.get("size", 0)) <= 0 or int(file.get("size", 0)) == size)


## 从平台 ZIP 中只取 exe 与 core zip；逐个校验大小/SHA 后写入 staging。返回 {ok, engine_path, core_path}。
static func extract_package(package_path: String, staging_dir: String, windows: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(package_path):
		return {"ok": false, "error": "package_missing"}
	var zip := ZIPReader.new()
	if zip.open(package_path) != OK:
		return {"ok": false, "error": "package_open_failed"}
	var targets := {
		"engine": String(windows.get("engine", {}).get("path", "")),
		"core": String(windows.get("core", {}).get("path", "")),
	}
	var found := {}
	for key in targets.keys():
		var entry_path: String = targets[key]
		if entry_path.is_empty() or entry_path.contains(".."):
			zip.close()
			return {"ok": false, "error": "manifest_%s_path_invalid" % key}
		var zip_entry := _find_zip_entry(zip.get_files(), entry_path)
		if zip_entry.is_empty():
			zip.close()
			return {"ok": false, "error": "package_%s_missing" % key}
		var data := zip.read_file(zip_entry)
		var destination := staging_dir.path_join(entry_path)
		if not _ensure_directory(destination.get_base_dir()):
			zip.close()
			return {"ok": false, "error": "staging_directory_failed"}
		var file := FileAccess.open(destination, FileAccess.WRITE)
		if file == null:
			zip.close()
			return {"ok": false, "error": "staging_write_failed"}
		file.store_buffer(data)
		file.close()
		var expected: Dictionary = windows.get(key, {})
		if int(expected.get("size", 0)) > 0 and UpdateApplier.file_size(destination) != int(expected.get("size", 0)):
			zip.close()
			return {"ok": false, "error": "package_%s_size_mismatch" % key}
		if FileAccess.get_sha256(destination).to_lower() != String(expected.get("sha256", "")).to_lower():
			zip.close()
			return {"ok": false, "error": "package_%s_sha256_mismatch" % key}
		found[key] = destination
	zip.close()
	return {"ok": true, "error": "", "engine_path": found.get("engine", ""), "core_path": found.get("core", "")}


static func _find_zip_entry(entries: PackedStringArray, relative_path: String) -> String:
	var normalized := relative_path.replace("\\", "/")
	for entry in entries:
		var value := entry.replace("\\", "/")
		if value == normalized or value.ends_with("/" + normalized):
			return entry
	return ""

