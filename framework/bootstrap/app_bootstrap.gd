extends Node
## @static-doc
## 作用：SceneTree Autoload：首场景加载前运行 Bootstrap 并保存 context / report；发布版还会先应用已校验的自动更新 pending（core 包替换 + exe 备份清理）。
##
## ## 契约与约束
## - `--script` 测试 / `-- --run-tests` 时完全跳过（测试自行控制 Bootstrap）。
## - 启动失败不抛异常：交给 `StartupReport` 与 Shell 的诊断界面；`is_ready_for_scene()` 只反映是否有可用 context。
## - 自动更新应用失败只 `push_warning`，不得阻塞旧版本启动；编辑器构建不应用 `user://updates/pending`。
## @end-static-doc

var context: AppContext = null
var report: StartupReport = null


func _ready() -> void:
	if _is_script_run():
		return
	# 自动更新（docs/design/AUTO_UPDATE.md §6.4）：在 ModLoader 扫描前应用上次下载并校验过的
	# core 包，并清理自替换留下的 exe 备份。失败只告警，不能让更新问题阻塞旧版本启动。
	if OS.has_feature("template"):
		var applied := UpdateApplier.apply_pending()
		if not bool(applied.get("ok", false)):
			push_warning("Steam Navigator pending update was not applied: " + String(applied.get("error", "")))
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
