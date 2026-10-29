extends TestCase
## @static-doc
## 作用：SettingsService 持久化测试：语言/自动存档/reload 往返，以及游玩数据上传开关、endpoint 与 token 的往返与规范化。
##
## ## 契约与约束
## - 期望值来自 `docs/design/TELEMETRY.md` §2：telemetry 默认 false、非法 endpoint 回退 `TelemetryService.DEFAULT_ENDPOINT`、token 默认空串。
## - 每个用例只写 `user://test_settings*` 临时目录并在结束时清理，不碰真实用户配置。
## @end-static-doc


func _cleanup(directory: String) -> void:
	var path := directory + "/config.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute(directory):
		DirAccess.remove_absolute(directory)


func test_settings_round_trip() -> void:
	var directory := "user://test_settings"
	_cleanup(directory)
	var service := SettingsService.load_settings(directory + "/config.json", "res://config/config.json")
	assert_eq(service.locale(), "zh_CN", "default locale comes from config/config.json")
	assert_true(service.autosave(), "default autosave is on")
	assert_true(FileAccess.file_exists(directory + "/config.json"), "user config is created on first load")
	service.set_locale("en")
	service.set_autosave(false)
	var saved := service.save()
	assert_true(bool(saved["ok"]), "settings save succeeds: %s" % str(saved))
	var reloaded := SettingsService.load_settings(directory + "/config.json", "res://config/config.json")
	assert_eq(reloaded.locale(), "en", "locale round-trips")
	assert_false(reloaded.autosave(), "autosave round-trips")
	_cleanup(directory)


func test_telemetry_settings_round_trip() -> void:
	var directory := "user://test_settings_telemetry"
	_cleanup(directory)
	var service := SettingsService.load_settings(directory + "/config.json", "res://config/config.json")
	assert_false(service.telemetry(), "telemetry defaults to false (opt-in)")
	assert_eq(service.telemetry_endpoint(), TelemetryService.DEFAULT_ENDPOINT,
		"the shipped config resolves to the official telemetry endpoint")
	assert_eq(service.telemetry_token(), "", "the default telemetry token is empty")
	service.set_telemetry(true)
	service.set_telemetry_endpoint("http://127.0.0.1:4173/api/telemetry/session")
	service.set_telemetry_token("local-token")
	var saved := service.save()
	assert_true(bool(saved["ok"]), "telemetry settings save succeeds: %s" % str(saved))
	var reloaded := SettingsService.load_settings(directory + "/config.json", "res://config/config.json")
	assert_true(reloaded.telemetry(), "telemetry flag round-trips through config.json")
	assert_eq(reloaded.telemetry_endpoint(), "http://127.0.0.1:4173/api/telemetry/session",
		"a valid telemetry endpoint round-trips")
	assert_eq(reloaded.telemetry_token(), "local-token", "telemetry token round-trips")
	# 非法 endpoint 不允许落盘成假地址：normalize 在 set/load 两侧都回退默认值。
	reloaded.set_telemetry_endpoint("ftp://example.invalid/session")
	assert_eq(reloaded.telemetry_endpoint(), TelemetryService.DEFAULT_ENDPOINT,
		"an invalid endpoint is normalized back to the default before saving")
	_cleanup(directory)


func test_update_settings_defaults_and_round_trip() -> void:
	var directory := "user://test_settings_update"
	_cleanup(directory)
	var service := SettingsService.load_settings(directory + "/config.json", "res://config/config.json")
	assert_true(service.auto_check_updates(), "auto update checks default to on")
	assert_eq(service.update_endpoint(), UpdateService.DEFAULT_ENDPOINT, "default update endpoint is the official one")
	service.set_auto_check_updates(false)
	service.set_update_endpoint("http://127.0.0.1:8088/api/site/update")
	assert_true(bool(service.save()["ok"]), "update settings save")
	var reloaded := SettingsService.load_settings(directory + "/config.json", "res://config/config.json")
	assert_false(reloaded.auto_check_updates(), "auto update toggle round-trips")
	assert_eq(reloaded.update_endpoint(), "http://127.0.0.1:8088/api/site/update", "update endpoint round-trips")
	reloaded.set_update_endpoint("ftp://example.invalid/update")
	assert_eq(reloaded.update_endpoint(), UpdateService.DEFAULT_ENDPOINT, "invalid update endpoint falls back to default")
	_cleanup(directory)
