extends SceneTree
## @static-doc
## 作用：SDK 无头校验入口：默认 `runtime` 模式跑真实 Bootstrap，`draft` 模式对草案 / 混合模组做静态 Schema 校验。
##
## ## 用法
## ```text
## godot --headless --path . --script res://sdk/validate.gd -- \
##     --mod-root=sdk/examples/example_roles_1_0 [--mode=runtime|draft] [--json]
## ```
##
## ## 契约与约束
## - 不传 `--mode` 时等价 `--mode=runtime`，保留既有调用（包括 SNModMaker `validate --godot`）兼容。
## - runtime：Core 从 `dev_mods` 加载，额外根追加在扫描列表里；未激活草案内容被显式拒绝，
##   错误码 `inactive_content_type`，每条含 `code` / `message` / `severity` / `mod` / `file` / `path`。
## - draft：不启动运行时，按 `ContentTypes` + `content_types.json` 的 `draft_schemas` / `draft_types`
##   做静态 Schema 校验；草案模组只应出现在 draft，不得据此发布。
## - `--json` 输出 `StartupReport` 既有字段，附加 `mode` 与 `ok`；`errors[]` 统一为结构化条目。
## - 退出码：0 无 error / fatal；1 存在 error 或 fatal；2 用法错误（未知 `--mode`）。
## @end-static-doc

const DEFAULT_MODE := "runtime"
const MODE_PREFIX := "--mode="


func _initialize() -> void:
	var roots := PackedStringArray(["res://dev_mods"])
	var json_output := false
	var mode := DEFAULT_MODE
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mod-root="):
			var root := argument.trim_prefix("--mod-root=")
			if not root.begins_with("res://") and not root.begins_with("user://"):
				root = "res://" + root.trim_prefix("/")
			if FileAccess.file_exists(root.rstrip("/") + "/manifest.json"):
				root = root.rstrip("/").get_base_dir()
			roots.append(root)
		elif argument.begins_with(MODE_PREFIX):
			mode = argument.trim_prefix(MODE_PREFIX)
		elif argument == "--json":
			json_output = true
	if not SdkValidationCore.is_mode(mode):
		printerr("unknown --mode '%s'; expected one of: %s" % [mode, ", ".join(SdkValidationCore.modes())])
		quit(2)
		return

	var report: StartupReport = SdkValidationCore.run_runtime(roots) if mode == SdkValidationCore.MODE_RUNTIME else SdkValidationCore.run_draft(roots)
	FrameworkRuntime.shutdown()

	var payload := report.to_dict()
	payload["mode"] = mode
	payload["ok"] = not report.has_fatal() and report.errors.is_empty()
	if json_output:
		print(JsonUtils.canonical_stringify(payload, "  "))
	else:
		print("mode: %s" % mode)
		print(report.format_text())
	quit(1 if report.has_fatal() or not report.errors.is_empty() else 0)
