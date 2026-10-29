class_name SNUpdateDialog
extends Control
## @static-doc
## 作用：主菜单的更新对话框：只负责把 `UpdateService` 的 state 映射成文案 / 进度 / 按钮，操作以信号交给 Shell，不访问网络与文件。
##
## - 关键依赖：`UpdateService` 的 phase 常量与 state 字段、`SNSkin`、Theme 变体 `SNPanel` / `SNPrimaryButton` / `SNGhostButton`
##
## ## 契约与约束
## - `bind(state, translate)` 可重复调用；节点名 `Title` / `Version` / `Summary` / `Progress` / `Status` / `DownloadButton` / `CancelButton` / `RestartButton` / `LaterButton` 是 Shell 与测试查找的契约。
## - 只发 `download_pressed` / `cancel_pressed` / `restart_pressed` / `close_pressed` 四种意图；是否真的下载、重启由 Shell + UpdateService 决定。
## - phase 文案：
##   `checking` 只显示关闭；`available` 显示下载；`downloading` 显示进度 + 取消；`staged` 显示重启；`error` 显示重试；`up_to_date` 只显示关闭。
## - 进度与大小只从 state 读取（`progress` / `downloaded` / `total`），不自行计时。
## @end-static-doc

signal download_pressed
signal cancel_pressed
signal restart_pressed
signal close_pressed

const PHASE_CHECKING := "checking"
const PHASE_UP_TO_DATE := "up_to_date"
const PHASE_AVAILABLE := "available"
const PHASE_DOWNLOADING := "downloading"
const PHASE_STAGED := "staged"
const PHASE_ERROR := "error"
const PHASE_IDLE := "idle"

var _tr: Callable = Callable()
var _state: Dictionary = {}

@onready var _shade: ColorRect = $Shade
@onready var _title: Label = $Center/Panel/Body/Title
@onready var _version: Label = $Center/Panel/Body/Version
@onready var _summary: Label = $Center/Panel/Body/Summary
@onready var _progress: ProgressBar = $Center/Panel/Body/Progress
@onready var _status: Label = $Center/Panel/Body/Status
@onready var _download: Button = $Center/Panel/Body/Actions/DownloadButton
@onready var _cancel: Button = $Center/Panel/Body/Actions/CancelButton
@onready var _restart: Button = $Center/Panel/Body/Actions/RestartButton
@onready var _later: Button = $Center/Panel/Body/Actions/LaterButton


func _ready() -> void:
	var dim := SNSkin.color("bg.abyss")
	dim.a = 0.82
	_shade.color = dim
	_title.add_theme_color_override("font_color", SNSkin.color("brass.highlight"))
	_version.add_theme_color_override("font_color", SNSkin.color("text.light"))
	_summary.add_theme_color_override("font_color", SNSkin.color("text.muted"))
	_status.add_theme_color_override("font_color", SNSkin.color("text.muted"))
	_download.pressed.connect(func() -> void: download_pressed.emit())
	_cancel.pressed.connect(func() -> void: cancel_pressed.emit())
	_restart.pressed.connect(func() -> void: restart_pressed.emit())
	_later.pressed.connect(func() -> void: close_pressed.emit())


## 绑定本地化回调并立即渲染当前 state。
func bind(state: Dictionary, translate: Callable) -> void:
	_tr = translate
	update(state)


func update(state: Dictionary) -> void:
	_state = state
	if not is_node_ready():
		return
	var phase := String(state.get("phase", PHASE_IDLE))
	var tag := String(state.get("tag", ""))
	var current := String(state.get("current_tag", ""))
	var action := String(state.get("action", ""))
	var size := int(state.get("size", 0))
	var progress := clampf(float(state.get("progress", 0.0)), 0.0, 1.0)
	_title.text = _loc("ui.update.title", "游戏更新")
	_summary.text = ""
	_status.text = ""
	_progress.visible = false
	_download.visible = false
	_cancel.visible = false
	_restart.visible = false
	_later.visible = true
	_later.text = _loc("ui.update.close", "关闭")
	match phase:
		PHASE_CHECKING:
			_version.text = _loc("ui.update.checking", "正在检查更新……")
			_later.visible = false
		PHASE_UP_TO_DATE:
			_version.text = _loc("ui.update.up_to_date", "已是最新版本")
			if not tag.is_empty():
				_summary.text = _loc("ui.update.current_version", "当前版本：%s") % tag
		PHASE_AVAILABLE:
			_title.text = _loc("ui.update.available_title", "发现新版本")
			_version.text = _loc("ui.update.available_version", "当前 %s → %s") % [current if not current.is_empty() else "?", tag]
			_summary.text = _available_summary(action, size)
			_download.visible = true
			_download.text = _loc("ui.update.download", "下载并更新")
			_download.disabled = false
		PHASE_DOWNLOADING:
			_title.text = _loc("ui.update.downloading_title", "正在下载更新")
			_version.text = _loc("ui.update.available_version", "当前 %s → %s") % [current if not current.is_empty() else "?", tag]
			_summary.text = _available_summary(action, size)
			_progress.visible = true
			_progress.value = progress * 100.0
			_status.text = _loc("ui.update.progress", "已下载 %s / %s（%d%%）") % [
				_mb(int(state.get("downloaded", 0))), _mb(size), int(round(progress * 100.0)),
			]
			_cancel.visible = true
			_cancel.text = _loc("ui.update.cancel", "取消下载")
			_later.visible = false
		PHASE_STAGED:
			_title.text = _loc("ui.update.staged_title", "更新已就绪")
			_version.text = _loc("ui.update.staged_version", "新版本 %s 将在重启后生效") % tag
			_summary.text = _loc("ui.update.staged_summary", "文件已下载并校验完成，重启游戏即可完成更新。")
			_progress.visible = true
			_progress.value = 100.0
			_status.text = _loc("ui.update.staged_status", "重启时自动替换旧版本，无需手动解压。")
			_restart.visible = true
			_restart.text = _loc("ui.update.restart", "立即重启")
			_later.text = _loc("ui.update.later", "稍后")
		PHASE_ERROR:
			_title.text = _loc("ui.update.error_title", "更新失败")
			_version.text = _error_text(String(state.get("error", "")))
			_download.visible = true
			_download.text = _loc("ui.update.retry", "重试")
			_later.text = _loc("ui.update.later", "稍后")
		_:
			_version.text = ""
			_later.visible = false


func _available_summary(action: String, size: int) -> String:
	if action == "full":
		return _loc("ui.update.full_summary", "完整更新：下载 %s，自动替换游戏本体（含内容包），无需手动解压。") % _mb(size)
	return _loc("ui.update.core_summary", "内容更新：只下载 %s 的内容包，重启后生效。") % _mb(size)


func _error_text(code: String) -> String:
	var fallbacks := {
		"network_error": "网络连接失败，请稍后重试。",
		"download_sha256_mismatch": "下载文件校验失败，已保留旧版本。",
		"download_size_mismatch": "下载文件不完整，请重试。",
		"engine_swap_failed": "无法替换游戏本体，请确认安装目录可写。",
		"update_package_unavailable": "更新包暂不可用，请稍后再试。",
		"unsupported_build": "当前版本不支持自动更新。",
	}
	var fallback := String(fallbacks.get(code, "更新未完成（%s），已保留旧版本。" % code))
	return _loc("ui.update.error.%s" % code, fallback)


func _mb(bytes: int) -> String:
	if bytes <= 0:
		return "? MB"
	return "%.1f MB" % (float(bytes) / 1048576.0)


func _loc(key: String, fallback: String) -> String:
	var text := String(_tr.call(key)) if _tr.is_valid() else fallback
	return fallback if text.is_empty() or text == key else text
