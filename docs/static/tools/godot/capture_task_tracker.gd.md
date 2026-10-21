# `tools/godot/capture_task_tracker.gd`

> 作用：阶段 4.6 Phase A「任务追踪聚合」真实渲染截图工具（窗口模式）。用普通

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MAIN_SCENE` | L19 |
| `OUT_DIR` | L20 |
| `WINDOW` | L21 |
| `SEED` | L22 |
| `STEADY_BUILD` | L23 |
| `WATCHDOG_SECONDS` | L24 |
| `SHOTS` | L26 |
| `_init() -> void` | L35 |

非教程新局抓两张 1440×900 截图：HUD 任务追踪条（主线委托当前步骤），以及委托页
顶部的完整任务追踪面板（任务 + 步骤）。

用法（**必须窗口模式**，`--headless` 下视口纹理为空图）：
  godot --path . --resolution 1440x900 --script res://tools/godot/capture_task_tracker.gd

输出（1440×900，写入 `docs/design/screenshots/task/`）：
  task_tracker_hud.png        HUD 任务追踪：主线委托 + 当前步骤
  task_tracker_contracts.png  委托页任务追踪面板：任务与全部步骤

## 契约与约束
- 全程真实 Shell / 真实 `run.start`；不伪造 task.view 数据。
- 硬性断言：HUD 出现 `TaskTracker` 且当前步骤含「前往」；委托页含任务追踪面板。

模块索引：[tools](../README.md)
