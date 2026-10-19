# `tools/ui_snapshot.gd`

> 作用：真实渲染 UI 截图验收：以与框架测试一致的 bootstrap 启动 Core，挂载 main.tscn，截取船厂正常态/改装态/分类/受损状态，并可选截取主界面（全窗 3D 港口舞台 + 紧凑 HUD + 两侧招牌 + 底部状态条）与详细总览抽屉。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `_init() -> void` | L66 |

## 契约与约束

- 必须窗口模式运行：`--headless` 时视口纹理为空，脚本直接判失败。
- 参数走 `--` 之后：`--seed` / `--out-dir` / `--window` / `--category` / `--damage` / `--skip-refit` / `--overview-stage` / `--overview-detail`。
- `--damage=slot[:index]:ratio` 在 run.start 后用 `ShipModules.damage()` 损坏模块实例，额外截取 `shipyard_normal_damaged` / `shipyard_refit_damaged` / `supply_damaged`；只影响截图进程，不进入游戏逻辑。
- `--overview-stage`：切到总览（默认即 3D 舞台，若处于 2D 回退才调 `_on_overview_stage_toggle()`）→ 断言 `_overview_stage_mode`、`PortStage` 宿主可见、设施数 > 0、`has_ship()`、招牌数 = 设施数 + 1、`_top_chrome` 高度 ≤130、底部状态条可见 → 保存 `overview_port_stage.png`。
- `--overview-detail`：在 `--overview-stage` 基础上点底部「详细总览」按钮（兜底直接置 `_overview_detail=true` 并 refresh），断言抽屉打开、总览页仍挂载 → 保存 `overview_detail.png`。
- 进入改装态优先点页面真实「改装」按钮，其次调 `_on_toggle_refit()`，最后按按钮文案兜底，页面小改版后工具仍可用。
- 纯色画面判定为失败；120 s watchdog 防止协程中断挂住窗口；成功退出码 0，失败 1。
- 只写 `docs/design/screenshots/`，不修改游戏状态或源码。

模块索引：[tools](./README.md)
