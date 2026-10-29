extends TestCase
## @static-doc
## 作用：自动更新纯逻辑与落地测试：清单/接口校验、内容包与本体两条决策、URL 解析、core 暂存与启动应用、exe 自替换与回滚、解压白名单。
##
## - 契约：docs/design/AUTO_UPDATE.md §3–§6；测试只读写 `user://test_update_*` 临时目录，不联网、不碰真实安装目录。
## - `UpdateService` 的 HTTP 部分不在单测范围（需要真实 socket）；这里覆盖能被下载结果影响的全部决策与文件操作。
## @end-static-doc

const ROOT := "user://test_update"


func _hex(character: String) -> String:
	var text := ""
	for _index in 64:
		text += character
	return text


func _sha(text: String) -> String:
	var bytes := text.to_utf8_buffer()
	var tmp := ROOT.path_join("hash.tmp")
	_write(tmp, bytes)
	return FileAccess.get_sha256(tmp)


func _write(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _write_text(path: String, text: String) -> void:
	_write(path, text.to_utf8_buffer())


func _clean(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var files := DirAccess.get_files_at(path)
	for name in files:
		DirAccess.remove_absolute(path.path_join(name))
	var dirs := DirAccess.get_directories_at(path)
	for name in dirs:
		_clean(path.path_join(name))
	DirAccess.remove_absolute(path)


func _fresh() -> void:
	_clean(ROOT)
	DirAccess.make_dir_recursive_absolute(ROOT)


func _manifest(engine_sha: String, core_sha: String) -> Dictionary:
	return {
		"schema": 1,
		"tag": "v0.2.0-dev.5",
		"published_at": "2026-10-30T05:00:00Z",
		"platforms": {
			"windows": {
				"engine": {"path": "SteamNavigator.exe", "size": 11, "sha256": engine_sha},
				"core": {"path": "mods/core-1.0.0.snavmod.zip", "size": 7, "sha256": core_sha},
				"package": {"name": "SteamNavigator-v0.2.0-dev.5-windows.zip", "size": 100, "sha256": _hex("a")},
			},
		},
	}


func _payload(manifest: Dictionary, core_url: String = "/downloads/v0.2.0-dev.5/core-1.0.0.snavmod.zip") -> Dictionary:
	return {
		"ok": true,
		"data": {
			"tag": "v0.2.0-dev.5",
			"published_at": "2026-10-30T05:00:00Z",
			"manifest": manifest,
			"files": {
				"package": {"url": "/downloads/v0.2.0-dev.5/package.zip", "size": 100, "sha256": _hex("a"), "fallback_url": "https://github.com/x/package.zip"},
				"core": {"url": core_url, "size": 7, "sha256": String(manifest["platforms"]["windows"]["core"]["sha256"]), "fallback_url": "https://github.com/x/core.zip"},
			},
		},
	}


func _info(manifest: Dictionary) -> Dictionary:
	var parsed := UpdateService.parse_update_payload(_payload(manifest))
	return parsed["info"] if bool(parsed.get("ok", false)) else {}


func _local(engine_sha: String, core_sha: String) -> Dictionary:
	return {
		"found": true,
		"tag": "v0.2.0-dev.4-fixed",
		"published_at": "2026-10-29T03:57:48Z",
		"engine_sha256": engine_sha,
		"core_sha256": core_sha,
	}


func test_parse_payload_and_manifest_validation() -> void:
	_fresh()
	_clean(ROOT)
	var engine := _sha("engine")
	var core := _sha("core")
	var parsed := UpdateService.parse_update_payload(_payload(_manifest(engine, core)))
	assert_true(bool(parsed.get("ok", false)), "valid payload parses: %s" % str(parsed.get("error", "")))
	assert_eq(String(parsed["info"].get("tag", "")), "v0.2.0-dev.5", "tag survives parsing")
	assert_eq(int(parsed["info"].get("windows", {}).get("core", {}).get("size", 0)), 7, "manifest sizes are ints")
	var bad_schema := UpdateService.validate_manifest({"schema": 2, "tag": "v1", "published_at": "2026-10-30T05:00:00Z", "platforms": {}})
	assert_false(bool(bad_schema.get("ok", false)), "unsupported schema is rejected")
	assert_eq(String(bad_schema.get("error", "")), "manifest_schema_unsupported", "schema error is explicit")
	var bad_path := _manifest(engine, core)
	bad_path["platforms"]["windows"]["engine"]["path"] = "other.exe"
	assert_false(bool(UpdateService.validate_manifest(bad_path).get("ok", false)), "unknown engine path is rejected")
	var bad_files := _payload(_manifest(engine, core))
	bad_files["data"]["files"]["core"]["fallback_url"] = ""
	assert_false(bool(UpdateService.parse_update_payload(bad_files).get("ok", false)), "missing fallback URL is rejected")


func test_decide_picks_core_full_none_and_blocks_downgrade() -> void:
	_fresh()
	var engine := _sha("engine")
	var core := _sha("core")
	var remote := _info(_manifest(engine, core))
	var content := UpdateService.decide(remote, _local(engine, _hex("b")))
	assert_eq(String(content.get("action", "")), "core", "only core changed -> content update")
	assert_eq(String(content.get("file", {}).get("name", "")), "core-1.0.0.snavmod.zip", "core download uses manifest name")
	var full := UpdateService.decide(remote, _local(_hex("c"), _hex("b")))
	assert_eq(String(full.get("action", "")), "full", "engine changed -> full update")
	assert_eq(String(full.get("reason", "")), "engine_changed", "full update reports engine change")
	var same := UpdateService.decide(remote, _local(engine, core))
	assert_eq(String(same.get("action", "")), "none", "same hashes -> no update")
	assert_eq(String(same.get("reason", "")), "up_to_date", "same hashes report up_to_date")
	var newer_local := _local(engine, _hex("b"))
	newer_local["published_at"] = "2026-10-31T00:00:00Z"
	assert_eq(String(UpdateService.decide(remote, newer_local).get("action", "")), "none", "never downgrade")
	var no_urls := _payload(_manifest(engine, core))
	no_urls["data"]["files"]["package"]["url"] = ""
	no_urls["data"]["files"]["package"]["fallback_url"] = ""
	var no_urls_info := UpdateService.parse_update_payload(no_urls)
	assert_false(bool(no_urls_info.get("ok", false)), "a file without any URL fails payload validation")


func test_local_state_uses_install_then_falls_back_to_files() -> void:
	_fresh()
	var exe_dir := ROOT.path_join("install")
	var mods := exe_dir.path_join("mods")
	var exe := exe_dir.path_join("SteamNavigator.exe")
	var core := mods.path_join("core-1.0.0.snavmod.zip")
	_write_text(exe, "fake engine")
	_write_text(core, "fake core")
	var engine_sha := FileAccess.get_sha256(exe).to_lower()
	var core_sha := FileAccess.get_sha256(core).to_lower()
	_write_text(exe_dir.path_join("config/install.json"), JSON.stringify({
		"schema": 1, "tag": "v0.2.0-dev.5", "published_at": "2026-10-30T05:00:00Z",
		"engine_sha256": engine_sha, "core_sha256": core_sha,
	}))
	var state := UpdateService.local_state(exe, mods, UpdateApplier.install_path(exe_dir))
	assert_eq(String(state.get("tag", "")), "v0.2.0-dev.5", "install.json tag is used")
	assert_eq(String(state.get("engine_sha256", "")), engine_sha, "install engine hash is used")
	assert_eq(String(state.get("core_sha256", "")), core_sha, "core hash is computed from the pack")
	DirAccess.remove_absolute(exe_dir.path_join("config/install.json"))
	var fallback := UpdateService.local_state(exe, mods, UpdateApplier.install_path(exe_dir))
	assert_false(bool(fallback.get("found", true)), "missing install.json is reported")
	assert_eq(String(fallback.get("engine_sha256", "")), engine_sha, "missing install.json falls back to file hash")


func test_resolve_url_relative_absolute_and_fallback() -> void:
	var endpoint := "https://steamnavigator.playthought.cn/api/site/update"
	assert_eq(UpdateService.resolve_url(endpoint, "/downloads/v/x.zip", "https://github.com/x.zip"),
		"https://steamnavigator.playthought.cn/downloads/v/x.zip", "relative mirror URL joins the endpoint origin")
	assert_eq(UpdateService.resolve_url(endpoint, "https://cdn.example/x.zip", "https://github.com/x.zip"),
		"https://cdn.example/x.zip", "absolute URLs win")
	assert_eq(UpdateService.resolve_url(endpoint, "", "https://github.com/x.zip"),
		"https://github.com/x.zip", "empty mirror URL falls back to GitHub")
	assert_eq(UpdateService.resolve_url(endpoint, "", "ftp://bad/x.zip"), "", "non-http fallback is rejected")
	assert_eq(UpdateService.normalize_endpoint("ftp://bad"), UpdateService.DEFAULT_ENDPOINT, "invalid endpoint normalizes to the official one")


func test_stage_content_and_apply_on_next_start() -> void:
	_fresh()
	var exe_dir := ROOT.path_join("install2")
	var mods := exe_dir.path_join("mods")
	var pending := ROOT.path_join("pending")
	_write_text(exe_dir.path_join("SteamNavigator.exe"), "fake engine")
	# 同名旧 core：更新器必须先备份再写新包，删备份时不能误删新包（v0.2.0-dev.5 回归）。
	_write_text(mods.path_join("core-1.0.0.snavmod.zip"), "old core")
	var new_core := ROOT.path_join("downloads/core-1.0.0.snavmod.zip")
	_write_text(new_core, "new core payload")
	var engine_sha := FileAccess.get_sha256(exe_dir.path_join("SteamNavigator.exe")).to_lower()
	var new_sha := FileAccess.get_sha256(new_core).to_lower()
	var staged := UpdateApplier.stage_content(new_core, {
		"tag": "v0.2.0-dev.5", "published_at": "2026-10-30T05:00:00Z",
		"engine_sha256": engine_sha, "core_sha256": new_sha,
	}, pending)
	assert_true(bool(staged.get("ok", false)), "stage_content copies the pack into pending: %s" % str(staged.get("error", "")))
	assert_true(FileAccess.file_exists(pending.path_join("apply.json")), "pending apply.json exists")
	var applied := UpdateApplier.apply_pending(exe_dir, pending)
	assert_true(bool(applied.get("ok", false)), "apply_pending succeeds: %s" % str(applied.get("error", "")))
	assert_true(bool(applied.get("applied", false)), "apply_pending reports the content swap")
	assert_eq(UpdateService.find_core_pack(mods).get_file(), "core-1.0.0.snavmod.zip", "new core name is in mods/")
	assert_eq(FileAccess.get_file_as_string(UpdateService.find_core_pack(mods)), "new core payload", "new core bytes are in place")
	var install := UpdateApplier.read_install(UpdateApplier.install_path(exe_dir))
	assert_eq(String(install.get("tag", "")), "v0.2.0-dev.5", "install.json records the new tag")
	assert_eq(String(install.get("core_sha256", "")), new_sha, "install.json records the new core hash")
	assert_false(FileAccess.file_exists(pending.path_join("apply.json")), "pending is consumed")


func test_apply_pending_rejects_wrong_engine_and_keeps_old_core() -> void:
	_fresh()
	var exe_dir := ROOT.path_join("install3")
	var mods := exe_dir.path_join("mods")
	var pending := ROOT.path_join("pending3")
	_write_text(exe_dir.path_join("SteamNavigator.exe"), "old engine")
	_write_text(mods.path_join("core-0.9.0.snavmod.zip"), "old core")
	var new_core := ROOT.path_join("downloads/core-1.0.0.snavmod.zip")
	_write_text(new_core, "new core payload")
	var staged := UpdateApplier.stage_content(new_core, {
		"tag": "v0.2.0-dev.5", "published_at": "2026-10-30T05:00:00Z",
		"engine_sha256": _hex("d"), "core_sha256": FileAccess.get_sha256(new_core),
	}, pending)
	assert_true(bool(staged.get("ok", false)), "staging succeeds")
	var applied := UpdateApplier.apply_pending(exe_dir, pending)
	assert_false(bool(applied.get("ok", true)), "engine mismatch fails the apply")
	assert_eq(String(applied.get("error", "")), "pending_engine_mismatch", "engine mismatch is the reported reason")
	assert_eq(FileAccess.get_file_as_string(mods.path_join("core-0.9.0.snavmod.zip")), "old core", "old core is untouched")
	assert_false(FileAccess.file_exists(pending.path_join("apply.json")), "mismatched pending is discarded")


func test_swap_engine_keeps_backup_and_startup_cleans_it() -> void:
	_fresh()
	var exe_dir := ROOT.path_join("install4")
	DirAccess.make_dir_recursive_absolute(exe_dir)
	var exe := exe_dir.path_join("SteamNavigator.exe")
	var staged := ROOT.path_join("staged/SteamNavigator.exe")
	_write_text(exe, "old engine")
	_write_text(staged, "new engine")
	var swapped := UpdateApplier.swap_engine(staged, exe)
	assert_true(bool(swapped.get("ok", false)), "swap_engine succeeds: %s" % str(swapped.get("error", "")))
	assert_eq(FileAccess.get_file_as_string(exe), "new engine", "new exe is in place")
	assert_eq(FileAccess.get_file_as_string(exe_dir.path_join("SteamNavigator.exe.old")), "old engine", "old exe is kept as .old")
	var applied := UpdateApplier.apply_pending(exe_dir, ROOT.path_join("no-pending"))
	assert_true(bool(applied.get("ok", false)), "startup without pending still succeeds")
	assert_false(FileAccess.file_exists(exe_dir.path_join("SteamNavigator.exe.old")), "startup removes the .old backup")


func test_extract_package_only_takes_exe_and_core() -> void:
	_fresh()
	var package := ROOT.path_join("release/windows.zip")
	DirAccess.make_dir_recursive_absolute(package.get_base_dir())
	var exe_bytes := "engine bytes".to_utf8_buffer()
	var core_bytes := "core bytes".to_utf8_buffer()
	var packer := ZIPPacker.new()
	assert_eq(packer.open(package), OK, "fixture zip opens")
	packer.start_file("SteamNavigator/SteamNavigator.exe")
	packer.write_file(exe_bytes)
	packer.close_file()
	packer.start_file("SteamNavigator/mods/core-1.0.0.snavmod.zip")
	packer.write_file(core_bytes)
	packer.close_file()
	packer.start_file("SteamNavigator/config/config.json")
	packer.write_file("{}".to_utf8_buffer())
	packer.close_file()
	packer.start_file("SteamNavigator/other.bin")
	packer.write_file("skip".to_utf8_buffer())
	packer.close_file()
	packer.close()
	var windows := {
		"engine": {"path": "SteamNavigator.exe", "size": exe_bytes.size(), "sha256": _sha("engine bytes")},
		"core": {"path": "mods/core-1.0.0.snavmod.zip", "size": core_bytes.size(), "sha256": _sha("core bytes")},
	}
	var staging := ROOT.path_join("staging")
	var extracted := UpdateService.extract_package(package, staging, windows)
	assert_true(bool(extracted.get("ok", false)), "extract_package succeeds: %s" % str(extracted.get("error", "")))
	assert_true(FileAccess.file_exists(staging.path_join("SteamNavigator.exe")), "exe is extracted")
	assert_true(FileAccess.file_exists(staging.path_join("mods/core-1.0.0.snavmod.zip")), "core is extracted")
	assert_false(FileAccess.file_exists(staging.path_join("config/config.json")), "config is never touched by the updater")
	assert_false(FileAccess.file_exists(staging.path_join("other.bin")), "unrelated entries are ignored")
	windows["engine"]["sha256"] = _hex("e")
	var tampered := UpdateService.extract_package(package, ROOT.path_join("staging2"), windows)
	assert_false(bool(tampered.get("ok", true)), "a tampered exe entry fails extraction")
	assert_eq(String(tampered.get("error", "")), "package_engine_sha256_mismatch", "tamper error is explicit")
	_clean(ROOT)

