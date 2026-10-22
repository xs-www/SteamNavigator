class_name SdkValidationCore
extends RefCounted
## @static-doc
## 作用：SDK 共享校验核心：提供 runtime（真实 Bootstrap 加载）与 draft（静态 Schema）两种校验，
## 并把结果统一成可直接用于 CI 的 `StartupReport` + 结构化错误。
##
## ## 契约与约束
## - 类型 / 版本 / Schema 路径的唯一真源是 `content_types.json`：active 类型读生成物
##   `ContentTypes`（`SCHEMA_PATHS` / `SCHEMA_VERSIONS`），草案类型读该 JSON 的
##   `draft_schemas` + `draft_types`。本文件不维护第二套类型或版本表。
## - runtime 模式：先做一次只读预扫描，发现草案内容就产出 `inactive_content_type`
##   结构化错误（`code` / `message` / `severity` / `mod` / `file` / `path`），再跑真实
##   `Bootstrap`，保留 `StartupReport` 的既有 JSON 形状；core 内的草案内容按 fatal 处理。
## - draft 模式：不启动运行时，按同一张类型表做静态 Schema 校验；草案 / 混合模组都可校验。
##   `forbidden_file` 等打包期文件白名单错误只在 runtime / release 判定，避免模板里的
##   README 之类文档文件挡住草案 Schema 校验。
## - 只读模组目录；不执行模组内容、不写 `dev_mods`。`stage_mod` 只在 `pack_mod --release`
##   需要隔离校验单个第三方模组时把文件复制到 `user://` 临时目录，校验后立即清理。
## @end-static-doc

const CONTENT_TYPES_MANIFEST := "res://content_types.json"
const SUPPORTED_SCHEMA_VERSIONS := ["1.0", "2.0"]
const MAX_CONTENT_FILE_BYTES := 8 * 1024 * 1024
const MODE_RUNTIME := "runtime"
const MODE_DRAFT := "draft"
const VALIDATION_SAVE_DIR := "user://sdk_validation_saves"
const STAGE_PREFIX := "user://sdk_release_validation_"
const STAGE_SKIP_SUFFIXES := [".import", ".uid", ".tmp"]

## content_types.json 是生成 ContentTypes 的源文件；草案表只在 SDK / 编辑器侧使用，
## 所以直接从 JSON 读取而不是塞进运行时生成物。
static var _draft_table: Dictionary = {}
static var _draft_table_loaded := false


static func modes() -> PackedStringArray:
	return PackedStringArray([MODE_RUNTIME, MODE_DRAFT])


static func is_mode(value: String) -> bool:
	return modes().has(value)


## { content_type: {schema_path: String, schema_version: String, draft: true} } from content_types.json.
static func draft_type_table() -> Dictionary:
	if _draft_table_loaded:
		return _draft_table
	_draft_table_loaded = true
	_draft_table.clear()
	var parsed := JsonUtils.parse_file(CONTENT_TYPES_MANIFEST)
	if not bool(parsed.get("ok", false)) or not (parsed.get("value") is Dictionary):
		return _draft_table
	var manifest: Dictionary = parsed["value"]
	var schemas: Variant = manifest.get("draft_schemas", {})
	if not (schemas is Dictionary):
		schemas = {}
	var types: Variant = manifest.get("draft_types", [])
	if not (types is Array):
		types = []
	for entry in types:
		if not (entry is Dictionary):
			continue
		var key := String(entry.get("key", ""))
		if key.is_empty():
			continue
		_draft_table[key] = {
			"schema_path": _res_path(String((schemas as Dictionary).get(key, ""))),
			"schema_version": String(entry.get("schema_version", "2.0")),
			"draft": true,
		}
	return _draft_table


## Resolve one content type against the active table first, then the draft table.
static func describe_type(content_type: StringName) -> Dictionary:
	if ContentTypes.is_known(content_type):
		return {
			"known": true,
			"draft": false,
			"schema_path": ContentTypes.schema_path(content_type),
			"schema_version": ContentTypes.schema_version(content_type),
		}
	var table := draft_type_table()
	var key := String(content_type)
	if table.has(key):
		var info: Dictionary = table[key]
		return {
			"known": true,
			"draft": true,
			"schema_path": String(info["schema_path"]),
			"schema_version": String(info["schema_version"]),
		}
	return {"known": false, "draft": false, "schema_path": "", "schema_version": ""}


static func is_draft_type(content_type: StringName) -> bool:
	return draft_type_table().has(String(content_type))


## Normalize scan roots: strip trailing slashes and drop duplicates. Without this,
## `--mod-root=dev_mods/core` resolves to `res://dev_mods` and would be scanned a
## second time next to the default root, producing a duplicate `core` package.
static func normalize_roots(roots: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	for root in roots:
		var normalized := String(root).rstrip("/")
		if normalized.is_empty():
			continue
		if not result.has(normalized):
			result.append(normalized)
	return result


## Runtime validation: reject draft content explicitly, then run the real Bootstrap.
static func run_runtime(roots: PackedStringArray, overrides: Dictionary = {}) -> StartupReport:
	var runtime_roots := normalize_roots(roots)
	var inactive := find_inactive_draft_content(runtime_roots)
	var config := {
		"scan_roots": runtime_roots,
		"allow_loose": true,
		"mount_packs": false,
		"log_to_console": false,
		"autosave": false,
		"save_directory": VALIDATION_SAVE_DIR,
	}
	for key in overrides.keys():
		config[String(key)] = overrides[key]
	var report := Bootstrap.new().run(config)

	# The compiler reports unregistered draft types as `unknown_content_type`; replace
	# those entries with the explicit `inactive_content_type` diagnostics so CI gets a
	# stable, self-explaining code instead of two errors for one file.
	var flagged: Dictionary = {}
	for issue in inactive:
		flagged["%s|%s" % [String(issue["mod"]), String(issue["file"])]] = true
	var filtered: Array[Dictionary] = []
	for entry in report.errors:
		var key := "%s|%s" % [String(entry.get("mod_id", "")), String(entry.get("file", ""))]
		if String(entry.get("code", "")) == "unknown_content_type" and flagged.has(key):
			continue
		filtered.append(entry)
	report.errors = filtered
	for issue in inactive:
		report.add_error(String(issue["code"]), String(issue["message"]), {
			"severity": String(issue["severity"]),
			"mod": String(issue["mod"]),
			"mod_id": String(issue["mod"]),
			"file": String(issue["file"]),
			"path": String(issue["path"]),
			"pointer": String(issue["path"]),
		})
	report.finalize()
	enrich_errors(report)
	return report


## Static draft validation: schema-check active and draft content without booting the runtime.
static func run_draft(roots: PackedStringArray) -> StartupReport:
	var report := StartupReport.new()
	var started := Time.get_ticks_msec()
	var validator := SchemaValidator.new()
	var scan := ModScanner.new(validator).scan(normalize_roots(roots), true)
	report.scanned_roots = scan["scanned_roots"]
	for entry in scan["errors"]:
		_add_report_error(
			report,
			String(entry.get("code", "scan_error")),
			String(entry.get("message", "")),
			String(entry.get("mod_id", "")),
			String(entry.get("file", "")),
			String(entry.get("path", "")),
			String(entry.get("severity", "error"))
		)
	for entry in scan["warnings"]:
		report.add_warning(String(entry.get("code", "scan_warning")), String(entry.get("message", "")), entry)

	var counts: Dictionary = {}
	for package in scan["packages"]:
		if package.manifest != null:
			report.mods.append(package.manifest.to_summary())
		for error in package.errors:
			if String(error.get("code", "")) == "forbidden_file":
				continue
			_add_report_error(
				report,
				String(error.get("code", "scan_error")),
				String(error.get("message", "")),
				package.id,
				String(error.get("file", "")),
				String(error.get("pointer", "")),
				"error"
			)
		for warning in package.warnings:
			report.add_warning(String(warning.get("code", "scan_warning")), String(warning.get("message", "")), {
				"mod": package.id,
				"file": String(warning.get("file", "")),
				"path": String(warning.get("pointer", "")),
			})
		if package.manifest == null:
			continue
		for relative_path in package.manifest.content_files:
			_validate_content_file(report, validator, package, relative_path, counts)
	for package in scan["packages"]:
		package.close()

	report.content_counts = counts
	report.timings_ms["validate"] = Time.get_ticks_msec() - started
	report.timings_ms["total"] = Time.get_ticks_msec() - started
	report.finalize()
	enrich_errors(report)
	return report


## Content files whose `content_type` is still a Schema 2.0 draft (the runtime will not load them).
static func find_inactive_draft_content(roots: PackedStringArray) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var scan := ModScanner.new().scan(normalize_roots(roots), true)
	for package in scan["packages"]:
		if package == null or package.manifest == null:
			continue
		for relative_path in package.manifest.content_files:
			var envelope := read_envelope(package.source, relative_path)
			if not bool(envelope["ok"]):
				continue
			var content_type := String(envelope["content_type"])
			if not draft_type_table().has(content_type):
				continue
			issues.append({
				"code": "inactive_content_type",
				"message": "content type '%s' is a Schema 2.0 draft the runtime does not load (file %s); validate it with --mode=draft and do not publish it" % [content_type, relative_path],
				"mod": package.id,
				"file": relative_path,
				"path": "/content_type",
				"severity": "fatal" if package.id == DependencyResolver.CORE_ID else "error",
			})
	for package in scan["packages"]:
		package.close()
	return issues


## Read only the envelope fields the draft gate needs.
static func read_envelope(source: ModSource, relative_path: String) -> Dictionary:
	if source == null or not source.exists(relative_path):
		return {"ok": false}
	var bytes := source.read_bytes(relative_path)
	if bytes.is_empty() or bytes.size() > MAX_CONTENT_FILE_BYTES:
		return {"ok": false}
	var parsed := JsonUtils.parse(bytes.get_string_from_utf8())
	if not bool(parsed.get("ok", false)) or not (parsed.get("value") is Dictionary):
		return {"ok": false}
	var envelope: Dictionary = parsed["value"]
	return {"ok": true, "content_type": String(envelope.get("content_type", "")), "envelope": envelope}


## `pack_mod --release` stages one mod into user:// so Bootstrap only sees core + that mod,
## instead of every sibling directory of the source path.
static func stage_mod(source_path: String, mod_id: String) -> String:
	var stage_root := "%s%d" % [STAGE_PREFIX, Time.get_ticks_usec()]
	_remove_tree(stage_root)
	_copy_tree(source_path.rstrip("/"), stage_root.rstrip("/") + "/" + mod_id, "")
	return stage_root


static func cleanup_stage(stage_root: String) -> void:
	if not stage_root.is_empty():
		_remove_tree(stage_root)


## Keep the StartupReport shape but guarantee the normalized CI fields on every error.
static func enrich_errors(report: StartupReport) -> void:
	for entry in report.errors:
		if not entry.has("mod"):
			entry["mod"] = String(entry.get("mod_id", ""))
		if not entry.has("path"):
			entry["path"] = String(entry.get("pointer", ""))
		if not entry.has("file"):
			entry["file"] = ""


static func _validate_content_file(
	report: StartupReport,
	validator: SchemaValidator,
	package: ModPackage,
	relative_path: String,
	counts: Dictionary
) -> void:
	# Missing / oversized files are already reported by ModScanner.
	if not package.source.exists(relative_path):
		return
	var bytes := package.source.read_bytes(relative_path)
	if bytes.size() > MAX_CONTENT_FILE_BYTES:
		_add_report_error(
			report,
			"content_file_too_large",
			"content file exceeds %d bytes" % MAX_CONTENT_FILE_BYTES,
			package.id,
			relative_path,
			"",
			"error"
		)
		return
	var parsed := JsonUtils.parse(bytes.get_string_from_utf8())
	if not bool(parsed.get("ok", false)):
		_add_report_error(
			report,
			"content_parse_error",
			"line %d: %s" % [int(parsed.get("line", 0)), String(parsed.get("error", ""))],
			package.id,
			relative_path,
			"",
			"error"
		)
		return
	if not (parsed.get("value") is Dictionary):
		_add_report_error(
			report,
			"content_not_object",
			"content file root must be an object",
			package.id,
			relative_path,
			"",
			"error"
		)
		return
	var envelope: Dictionary = parsed["value"]
	var content_type_name := String(envelope.get("content_type", ""))
	var info := describe_type(StringName(content_type_name))
	if not bool(info["known"]):
		_add_report_error(
			report,
			"unknown_content_type",
			"unknown content_type '%s'" % content_type_name,
			package.id,
			relative_path,
			"/content_type",
			"error"
		)
		return
	var declared := String(envelope.get("schema_version", ""))
	var expected := String(info["schema_version"])
	if not SUPPORTED_SCHEMA_VERSIONS.has(declared):
		_add_report_error(
			report,
			"schema_version_unsupported",
			"schema_version must be one of %s for content type '%s', got '%s'" % [
				str(SUPPORTED_SCHEMA_VERSIONS), content_type_name, declared
			],
			package.id,
			relative_path,
			"/schema_version",
			"error"
		)
		return
	if declared != expected:
		_add_report_error(
			report,
			"schema_version_mismatch",
			"schema_version must be '%s' for content type '%s', got '%s'" % [
				expected, content_type_name, declared
			],
			package.id,
			relative_path,
			"/schema_version",
			"error"
		)
		return
	var schema_errors := validator.validate_file(envelope, String(info["schema_path"]))
	for schema_error in schema_errors:
		_add_report_error(
			report,
			"schema_error",
			"%s: %s" % [String(schema_error.get("message", "")), String(schema_error.get("path", "/"))],
			package.id,
			relative_path,
			String(schema_error.get("path", "")),
			"error"
		)
	var definitions: Variant = envelope.get("definitions", [])
	if definitions is Array:
		counts[content_type_name] = int(counts.get(content_type_name, 0)) + definitions.size()


static func _add_report_error(
	report: StartupReport,
	code: String,
	message: String,
	mod_id: String,
	file: String,
	path: String,
	severity: String
) -> void:
	report.add_error(code, message, {
		"severity": severity,
		"mod": mod_id,
		"mod_id": mod_id,
		"file": file,
		"path": path,
		"pointer": path,
	})


static func _res_path(value: String) -> String:
	if value.is_empty():
		return ""
	if value.begins_with("res://") or value.begins_with("user://"):
		return value
	return "res://" + value.trim_prefix("/")


static func _copy_tree(source_root: String, target_root: String, relative: String) -> void:
	var current_source := source_root if relative.is_empty() else source_root + "/" + relative
	var directory := DirAccess.open(current_source)
	if directory == null:
		return
	var current_target := target_root if relative.is_empty() else target_root + "/" + relative
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(current_target))
	for file_name in directory.get_files():
		var skip := file_name.begins_with(".")
		for suffix in STAGE_SKIP_SUFFIXES:
			if file_name.ends_with(suffix):
				skip = true
		if skip:
			continue
		var bytes := FileAccess.get_file_as_bytes(current_source + "/" + file_name)
		var target_file := FileAccess.open(current_target + "/" + file_name, FileAccess.WRITE)
		if target_file == null:
			continue
		target_file.store_buffer(bytes)
		target_file.close()
	for directory_name in directory.get_directories():
		if directory_name.begins_with("."):
			continue
		_copy_tree(source_root, target_root, directory_name if relative.is_empty() else relative + "/" + directory_name)


static func _remove_tree(path: String) -> void:
	_remove_absolute(ProjectSettings.globalize_path(path))


static func _remove_absolute(absolute_path: String) -> void:
	var directory := DirAccess.open(absolute_path)
	if directory == null:
		return
	var base := absolute_path.rstrip("/")
	for file_name in directory.get_files():
		DirAccess.remove_absolute(base + "/" + file_name)
	for directory_name in directory.get_directories():
		_remove_absolute(base + "/" + directory_name)
	DirAccess.remove_absolute(base)
