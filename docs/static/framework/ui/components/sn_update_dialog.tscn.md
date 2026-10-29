# `framework/ui/components/sn_update_dialog.tscn`

> 作用：主菜单「游戏更新」对话框的场景骨架：遮罩 + 居中面板（标题 / 版本 / 说明 / 进度条 / 状态 / 下载 / 取消 / 重启 / 稍后）；`sn_update_dialog.gd` 只把 `UpdateService` 的 state 映成文案与可见性，操作以信号交给 Shell。

- 类型：Godot 场景

## 节点结构

- `SNUpdateDialog`（Control，全屏锚点，`mouse_filter = STOP`，挂 `sn_update_dialog.gd`）
  - `Shade`（ColorRect，全屏，遮罩色由脚本从 `SNSkin.color("bg.abyss")` 写入）
  - `Center`（CenterContainer，全屏，`mouse_filter = IGNORE`）
    - `Panel`（PanelContainer，宽 600，`theme_type_variation = SNPanel`）
      - `Body`（VBoxContainer，separation 12）
        - `Title` / `Version` / `Summary`（Label，20 / 14 / 13，Summary 自动换行）
        - `Separator`（HSeparator）
        - `Progress`（ProgressBar，高 18，`visible = false`，不显示百分比）
        - `Status`（Label，12，自动换行）
        - `Actions`（HBoxContainer）→ `Spacer`、`DownloadButton`（SNPrimaryButton）、`CancelButton`（SNGhostButton）、`RestartButton`（SNPrimaryButton）、`LaterButton`（SNGhostButton）

## 契约

- 节点名 `Title` / `Version` / `Summary` / `Progress` / `Status` / `DownloadButton` / `CancelButton` / `RestartButton` / `LaterButton` 是 Shell 与测试的查找契约，改名必须同步测试。
- 文案走 `ui.update.*`；phase → 按钮可见性映射见 `docs/design/AUTO_UPDATE.md` §6.5，不在场景里写死任何状态。
- 对话框由 Shell 在发布版主菜单「检查更新」时实例化并置顶；关闭只隐藏，不销毁（下载过程中保持同一实例接收进度）。

模块索引：[framework/ui](../README.md)
