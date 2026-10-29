class_name UpdateApplier
extends RefCounted
## @static-doc
## 作用：安装目录侧的更新落地。启动时（Bootstrap 扫描模组前）清理上一次自替换留下的旧 exe、应用 `user://updates/pending` 里已校验的 core 包，并重写 `config/install.json`；更新器下载完成后的 exe 自替换也复用这里的文件操作。
##
## - 关键依赖：`JsonUtils`、`FileAccess` / `DirAccess`、`OS.get_executable_path()`
##
## ## 契约与约束
## - 只由发布版启动链（`AppBootstrap`）或 `UpdateService` 调用；编辑器与 `--script` 测试不自动应用。
## - 允许写入的安装目录路径只有：`SteamNavigator.exe`（改名/备份）、`mods/core-*.snavmod.zip`、`config/install.json`。
## - pending 格式见 `docs/design/AUTO_UPDATE.md` §5：`apply.json` + 已校验的 core zip；core 文件必须位于 pending 根目录内，SHA-256 与大小必须与清单一致，校验失败绝不覆盖旧 core。
## - 应用顺序：备份旧 core → 写新 core 并复验 → 写 install.json → 删除 pending。任何一步失败都回滚旧 core。
## - `SteamNavigator.exe.old` 是自替换备份：新进程启动后删掉，它不在任何扫描路径里。
##
## ## 重点逻辑
## ### `apply_pending(exe_dir, pending_root)`
## - 默认参数在生产使用 exe 目录与 `user://updates/pending`；测试传临时目录。返回 `{ok, applied, error, tag}`，不抛异常。
## ### `swap_engine(staged_exe, exe_path)`
## - Windows 允许重命名正在运行的 exe（已实测）。先备份成 `.old`，再复制新 exe；复制失败时把 `.old` 改回，保证不出现“exe 缺失”状态。
## @end-static-doc

const PENDING_ROOT := "user://updates/pending"
const APPLY_FILE := "apply.json"
const INSTALL_FILE := "config/install.json"
const INSTALL_SCHEMA := 1
const CORE_SUFFIX := ".snavmod.zip"
const BACKUP_SUFFIX := ".snold"
const EXE_NAME := "SteamNavigator.exe"
const EXE_BACKUP := "SteamNavigator.exe.old"
const HEX64 := "0123456789abcdef"


static func default_exe_dir() -> String:
	var executable := OS.get_executable_path()
	if executable.is_empty():
		return ""
	return executable.get_base_dir()


static func install_path(exe_dir: String) -> String:
	return exe_dir.path_join(INSTALL_FILE)


## 启动时调用：清理上次遗留的 exe 备份并应用已下载的内容包。没有 pending 时零写入。
static func apply_pending(exe_dir: String = "", pending_root: String = "") -> Dictionary:
	var base := exe_dir if not exe_dir.is_empty() else default_exe_dir()
	var root := pending_root if not pending_root.is_empty() else PENDING_ROOT
	if base.is_empty():
		return _result(false, false, "exe_dir_unavailable", "")
	_remove_backup(base)
	var apply_file := root.path_join(APPLY_FILE)
	if not FileAccess.file_exists(apply_file):
		return _result(true, false, "", "")
	var parsed := JsonUtils.parse_file(apply_file)
	if not bool(parsed.get("ok", false)) or not (parsed.get("value") is Dictionary):
		return _discard_pending(root, "pending_invalid")
	var payload: Dictionary = parsed["value"]
	var problem := validate_pending(payload, root)
	if not problem.is_empty():
		return _discard_pending(root, problem)
	# 引擎版本必须与暂存描述一致：full 更新先自替换 exe 再落 core，若 exe 替换失败/被手动改回，
	# 不能把新 core 混进旧框架启动。
	var expected_engine := String(payload.get("engine_sha256", "")).to_lower()
	var installed_exe := base.path_join(EXE_NAME)
	if not expected_engine.is_empty() and FileAccess.file_exists(installed_exe):
		if FileAccess.get_sha256(installed_exe).to_lower() != expected_engine:
			return _discard_pending(root, "pending_engine_mismatch")
	var core_file := String(payload.get("core_file", ""))
	var core_name := core_file.get_file()
	var mods_dir := base.path_join("mods")
	var made := OK
	if not DirAccess.dir_exists_absolute(mods_dir):
		made = DirAccess.make_dir_recursive_absolute(mods_dir)
	if made != OK:
		return _result(false, false, "mods_directory_failed", String(payload.get("tag", "")))
	var backups: Array[String] = []
	var replaced := _backup_existing_cores(mods_dir, backups)
	if not bool(replaced.get("ok", false)):
		return _result(false, false, String(replaced.get("error", "core_backup_failed")), String(payload.get("tag", "")))
	var target := mods_dir.path_join(core_name)
	var copied := DirAccess.copy_absolute(core_file, target)
	if copied != OK:
		_restore_backups(mods_dir, backups)
		return _result(false, false, "core_copy_failed", String(payload.get("tag", "")))
	var copied_sha := FileAccess.get_sha256(target).to_lower()
	if copied_sha != String(payload.get("core_sha256", "")).to_lower():
		DirAccess.remove_absolute(target)
		_restore_backups(mods_dir, backups)
		return _discard_pending(root, "core_sha256_mismatch")
	var installed := _write_install_file(base, payload)
	if not bool(installed.get("ok", false)):
		DirAccess.remove_absolute(target)
		_restore_backups(mods_dir, backups)
		return _result(false, false, String(installed.get("error", "install_write_failed")), String(payload.get("tag", "")))
	for backup in backups:
		# backups stores the original file names; the renamed file has BACKUP_SUFFIX.
		DirAccess.remove_absolute(mods_dir.path_join(backup + BACKUP_SUFFIX))
	_remove_file(core_file)
	_remove_file(apply_file)
	_remove_empty_dir(root)
	return _result(true, true, "", String(payload.get("tag", "")))


## 校验 pending 描述与暂存文件；返回空串表示通过，否则返回错误码。
static func validate_pending(payload: Dictionary, pending_root: String = PENDING_ROOT) -> String:
	if int(payload.get("schema", 0)) != INSTALL_SCHEMA:
		return "pending_schema_unsupported"
	if String(payload.get("tag", "")).is_empty():
		return "pending_tag_missing"
	for key in ["engine_sha256", "core_sha256"]:
		if not is_hex64(String(payload.get(key, ""))):
			return "pending_%s_invalid" % key
	var core_file := String(payload.get("core_file", ""))
	if core_file.is_empty() or not core_file.begins_with(pending_root + "/"):
		return "pending_core_path_invalid"
	if not core_file.get_file().ends_with(CORE_SUFFIX):
		return "pending_core_name_invalid"
	if not FileAccess.file_exists(core_file):
		return "pending_core_missing"
	if int(payload.get("core_size", 0)) > 0 and file_size(core_file) != int(payload.get("core_size", 0)):
		return "pending_core_size_mismatch"
	if FileAccess.get_sha256(core_file).to_lower() != String(payload.get("core_sha256", "")).to_lower():
		return "pending_core_sha256_mismatch"
	return ""


## 自替换：备份正在运行的 exe 后复制暂存 exe 到原路径；失败回滚，不留半更新状态。
static func swap_engine(staged_exe: String, exe_path: String) -> Dictionary:
	if not FileAccess.file_exists(staged_exe):
		return _op(false, "staged_exe_missing")
	if not FileAccess.file_exists(exe_path):
		return _op(false, "installed_exe_missing")
	var directory := exe_path.get_base_dir()
	var backup := directory.path_join(EXE_BACKUP)
	_remove_file(backup)
	var renamed := DirAccess.rename_absolute(exe_path, backup)
	if renamed != OK:
		return _op(false, "exe_rename_failed")
	var copied := DirAccess.copy_absolute(staged_exe, exe_path)
	if copied != OK:
		DirAccess.rename_absolute(backup, exe_path)
		return _op(false, "exe_copy_failed")
	return _op(true, "")


## 生成 pending 目录：复制已校验 core 包 + 写 apply.json，供下次启动应用。返回 {ok, pending_dir, error}。
static func stage_content(core_source: String, payload: Dictionary, pending_root: String = PENDING_ROOT) -> Dictionary:
	if not FileAccess.file_exists(core_source):
		return {"ok": false, "error": "core_source_missing", "pending_dir": pending_root}
	var core_name := core_source.get_file()
	if not core_name.ends_with(CORE_SUFFIX):
		return {"ok": false, "error": "core_name_invalid", "pending_dir": pending_root}
	if not DirAccess.dir_exists_absolute(pending_root):
		var made := DirAccess.make_dir_recursive_absolute(pending_root)
		if made != OK:
			return {"ok": false, "error": "pending_directory_failed", "pending_dir": pending_root}
	var staged := pending_root.path_join(core_name)
	var temp := staged + ".tmp"
	_remove_file(temp)
	var copied := DirAccess.copy_absolute(core_source, temp)
	if copied != OK:
		return {"ok": false, "error": "pending_copy_failed", "pending_dir": pending_root}
	var data := payload.duplicate(true)
	data["schema"] = INSTALL_SCHEMA
	data["core_file"] = staged
	# 暂存文件此时还是 temp，必须从实际存在的副本计算大小/哈希（改名前 staged 不存在）。
	data["core_size"] = file_size(temp)
	data["core_sha256"] = FileAccess.get_sha256(temp).to_lower()
	var wrote := _write_json(pending_root.path_join(APPLY_FILE), data)
	if not bool(wrote.get("ok", false)):
		_remove_file(temp)
		return {"ok": false, "error": "pending_write_failed", "pending_dir": pending_root}
	var renamed := DirAccess.rename_absolute(temp, staged)
	if renamed != OK:
		return {"ok": false, "error": "pending_rename_failed", "pending_dir": pending_root}
	return {"ok": true, "error": "", "pending_dir": pending_root}


## 读取 `config/install.json`；缺失或非法时 found=false。
static func read_install(path: String) -> Dictionary:
	var parsed := JsonUtils.parse_file(path)
	if not bool(parsed.get("ok", false)) or not (parsed.get("value") is Dictionary):
		return {"found": false, "tag": "", "published_at": "", "engine_sha256": "", "core_sha256": ""}
	var value: Dictionary = parsed["value"]
	return {
		"found": true,
		"tag": String(value.get("tag", "")),
		"published_at": String(value.get("published_at", "")),
		"engine_sha256": String(value.get("engine_sha256", "")).to_lower(),
		"core_sha256": String(value.get("core_sha256", "")).to_lower(),
	}


## 文件字节数；文件不存在或打不开时返回 -1（`FileAccess.get_length` 是实例方法，静态调用会解析失败）。
static func file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var size := file.get_length()
	file.close()
	return size


static func is_hex64(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in value.length():
		if not HEX64.contains(value[index].to_lower()):
			return false
	return true


static func is_utc_timestamp(value: String) -> bool:
	if value.length() != 20 or value[4] != "-" or value[7] != "-" or value[10] != "T" or value[13] != ":" or value[16] != ":" or value[19] != "Z":
		return false
	for index in [0, 1, 2, 3, 5, 6, 8, 9, 11, 12, 14, 15, 17, 18]:
		if not "0123456789".contains(value[index]):
			return false
	return true


static func timestamp_value(value: String) -> int:
	if not is_utc_timestamp(value):
		return -1
	var unix := Time.get_unix_time_from_datetime_string(value.substr(0, 19))
	return int(unix)


static func iso_now() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"


static func _write_install_file(exe_dir: String, payload: Dictionary) -> Dictionary:
	var engine_sha := String(payload.get("engine_sha256", "")).to_lower()
	var exe_file := exe_dir.path_join(EXE_NAME)
	if FileAccess.file_exists(exe_file):
		engine_sha = FileAccess.get_sha256(exe_file).to_lower()
	var install := {
		"schema": INSTALL_SCHEMA,
		"tag": String(payload.get("tag", "")),
		"published_at": String(payload.get("published_at", "")),
		"engine_sha256": engine_sha,
		"core_sha256": String(payload.get("core_sha256", "")).to_lower(),
		"updated_at": iso_now(),
	}
	var target := install_path(exe_dir)
	if not DirAccess.dir_exists_absolute(target.get_base_dir()):
		var made := DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		if made != OK:
			return {"ok": false, "error": "install_directory_failed"}
	return _write_json(target, install)


static func _write_json(path: String, data: Dictionary) -> Dictionary:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "write_open_failed"}
	file.store_string(JsonUtils.canonical_stringify(data, "\t") + "\n")
	file.close()
	var renamed := DirAccess.rename_absolute(temp, path)
	if renamed != OK:
		_remove_file(temp)
		return {"ok": false, "error": "write_rename_failed"}
	return {"ok": true, "error": ""}


static func _backup_existing_cores(mods_dir: String, backups: Array[String]) -> Dictionary:
	var files := DirAccess.get_files_at(mods_dir)
	if files.is_empty():
		return {"ok": true}
	for name in files:
		if not _is_core_pack(name):
			continue
		var backup := name + BACKUP_SUFFIX
		_remove_file(mods_dir.path_join(backup))
		var renamed := DirAccess.rename_absolute(mods_dir.path_join(name), mods_dir.path_join(backup))
		if renamed != OK:
			_restore_backups(mods_dir, backups)
			return {"ok": false, "error": "core_backup_failed"}
		backups.append(name)
	return {"ok": true}


static func _restore_backups(mods_dir: String, backups: Array[String]) -> void:
	for name in backups:
		var backup := mods_dir.path_join(name + BACKUP_SUFFIX)
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup, mods_dir.path_join(name))


static func _is_core_pack(file_name: String) -> bool:
	return file_name.begins_with("core-") and file_name.ends_with(CORE_SUFFIX)


static func _discard_pending(root: String, code: String) -> Dictionary:
	_remove_file(root.path_join(APPLY_FILE))
	var files := DirAccess.get_files_at(root)
	if not files.is_empty():
		for name in files:
			if name.ends_with(CORE_SUFFIX):
				_remove_file(root.path_join(name))
	_remove_empty_dir(root)
	return _result(false, false, code, "")


static func _remove_backup(exe_dir: String) -> void:
	var backup := exe_dir.path_join(EXE_BACKUP)
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)


static func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _remove_empty_dir(path: String) -> void:
	if DirAccess.dir_exists_absolute(path) and DirAccess.get_files_at(path).is_empty():
		DirAccess.remove_absolute(path)


static func _result(ok: bool, applied: bool, error: String, tag: String) -> Dictionary:
	return {"ok": ok, "applied": applied, "error": error, "tag": tag}


static func _op(ok: bool, error: String) -> Dictionary:
	return {"ok": ok, "error": error}


