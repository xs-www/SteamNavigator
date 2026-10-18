class_name Bootstrap
extends RefCounted
## Composition-root startup. Safe to call from tests with overrides.

var context: AppContext = null


func run(overrides: Dictionary = {}) -> StartupReport:
	var started_at := Time.get_ticks_msec()
	var config := _build_config(overrides)
	context = AppContext.new(config)
	AppContext.set_active(context)
	context.localization.load_base_tables()

	var loader := ModLoader.new(context.logger)
	loader.bind_context(context)
	var report := loader.load_mods(config)
	context.report = report
	context.mod_order = loader.order

	FrameworkApi.register(context)
	report.content_counts = context.registries.counts()
	report.timings_ms["bootstrap"] = Time.get_ticks_msec() - started_at
	report.finalize()
	context.logger.info("bootstrap finished", {
		"status": report.status_name(),
		"content": report.content_total(),
		"mods": Array(loader.order),
	})
	return report


func _build_config(overrides: Dictionary) -> Dictionary:
	var defaults := {
		"scan_roots": _default_scan_roots(),
		"allow_loose": bool(ProjectSettings.get_setting("framework/mods/allow_loose_mods", true)),
		"mount_packs": bool(ProjectSettings.get_setting("framework/mods/mount_packs", true)),
		"autosave": bool(ProjectSettings.get_setting("framework/mods/autosave", true)),
		"locale": String(ProjectSettings.get_setting("framework/locale", "zh_CN")),
		"save_directory": String(ProjectSettings.get_setting("framework/save_directory", "user://saves")),
		"log_to_console": bool(ProjectSettings.get_setting("framework/log_to_console", true)),
	}
	for key in overrides.keys():
		defaults[String(key)] = overrides[key]
	return defaults


func _default_scan_roots() -> PackedStringArray:
	var configured: Variant = ProjectSettings.get_setting(
		"framework/mods/scan_roots",
		PackedStringArray(["res://dev_mods", "res://dist/mods", "user://mods_dev", "user://mods"])
	)
	var roots := PackedStringArray()
	if configured is PackedStringArray:
		roots = configured
	elif configured is Array:
		for entry in configured:
			roots.append(String(entry))
	if OS.has_feature("template"):
		roots.append(OS.get_executable_path().get_base_dir() + "/mods")
	return roots


static func active_context() -> AppContext:
	return AppContext.get_active()
