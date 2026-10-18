extends TestCase


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
