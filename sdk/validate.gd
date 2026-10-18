extends SceneTree
## Headless mod validation.
##
## Usage:
##   godot --headless --path . --script res://sdk/validate.gd -- \
##       --mod-root=sdk/examples/example_boilers
##
## Core is always loaded from dev_mods. Extra roots are appended so a content
## mod can be checked against the real official content.

func _initialize() -> void:
	var roots := PackedStringArray(["res://dev_mods"])
	var json_output := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mod-root="):
			var root := argument.trim_prefix("--mod-root=")
			if not root.begins_with("res://") and not root.begins_with("user://"):
				root = "res://" + root.trim_prefix("/")
			if FileAccess.file_exists(root.rstrip("/") + "/manifest.json"):
				root = root.rstrip("/").get_base_dir()
			roots.append(root)
		elif argument == "--json":
			json_output = true
	var bootstrap := Bootstrap.new()
	var report := bootstrap.run({
		"scan_roots": roots,
		"allow_loose": true,
		"mount_packs": false,
		"log_to_console": false,
		"autosave": false,
		"save_directory": "user://sdk_validation_saves",
	})
	if json_output:
		print(JsonUtils.canonical_stringify(report.to_dict(), "  "))
	else:
		print(report.format_text())
	FrameworkRuntime.shutdown()
	quit(1 if report.has_fatal() or not report.errors.is_empty() else 0)
