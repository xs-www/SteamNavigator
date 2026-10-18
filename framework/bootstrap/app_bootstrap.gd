extends Node
## Autoload entry point. Boots content before the main scene starts.
##
## Headless test scripts launch with `--script`; this autoload intentionally
## does nothing in that case so tests control bootstrap explicitly.

var context: AppContext = null
var report: StartupReport = null


func _ready() -> void:
	if _is_script_run():
		return
	var bootstrap := Bootstrap.new()
	report = bootstrap.run()
	context = bootstrap.context
	AppContext.set_active(context)
	if report != null and report.has_fatal():
		push_error("Steam Navigator failed to start: " + report.format_text())


func is_ready_for_scene() -> bool:
	return context != null and report != null and not report.has_fatal()


func _is_script_run() -> bool:
	for argument in OS.get_cmdline_args():
		if argument == "--script":
			return true
	for argument in OS.get_cmdline_user_args():
		if argument == "--run-tests":
			return true
	return false
