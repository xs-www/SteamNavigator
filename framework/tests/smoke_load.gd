extends SceneTree
## Headless smoke check used while building the framework.

func _initialize() -> void:
	var bootstrap := Bootstrap.new()
	var report := bootstrap.run({
		"scan_roots": PackedStringArray(["res://dev_mods"]),
		"log_to_console": true,
		"autosave": false,
		"save_directory": "user://smoke_saves",
	})
	print(report.format_text())
	FrameworkRuntime.shutdown()
	quit(0 if not report.has_fatal() else 1)
