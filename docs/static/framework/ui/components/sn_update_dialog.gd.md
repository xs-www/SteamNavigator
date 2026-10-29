# `framework/ui/components/sn_update_dialog.gd`

> 作用：主菜单的更新对话框：只负责把 `UpdateService` 的 state 映射成文案 / 进度 / 按钮，操作以信号交给 Shell，不访问网络与文件。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNUpdateDialog` | L1 |
| `download_pressed (signal)` | L16 |
| `cancel_pressed (signal)` | L17 |
| `restart_pressed (signal)` | L18 |
| `close_pressed (signal)` | L19 |
| `PHASE_CHECKING` | L21 |
| `PHASE_UP_TO_DATE` | L22 |
| `PHASE_AVAILABLE` | L23 |
| `PHASE_DOWNLOADING` | L24 |
| `PHASE_STAGED` | L25 |
| `PHASE_ERROR` | L26 |
| `PHASE_IDLE` | L27 |
| `bind(state: Dictionary, translate: Callable) -> void` | L59 |
| `update(state: Dictionary) -> void` | L64 |

- 关键依赖：`UpdateService` 的 phase 常量与 state 字段、`SNSkin`、Theme 变体 `SNPanel` / `SNPrimaryButton` / `SNGhostButton`

## 契约与约束
- `bind(state, translate)` 可重复调用；节点名 `Title` / `Version` / `Summary` / `Progress` / `Status` / `DownloadButton` / `CancelButton` / `RestartButton` / `LaterButton` 是 Shell 与测试查找的契约。
- 只发 `download_pressed` / `cancel_pressed` / `restart_pressed` / `close_pressed` 四种意图；是否真的下载、重启由 Shell + UpdateService 决定。
- phase 文案：
  `checking` 只显示关闭；`available` 显示下载；`downloading` 显示进度 + 取消；`staged` 显示重启；`error` 显示重试；`up_to_date` 只显示关闭。
- 进度与大小只从 state 读取（`progress` / `downloaded` / `total`），不自行计时。

模块索引：[framework/ui](../README.md)
