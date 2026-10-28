# `tools/ui_snapshot.gd`

> 作用：真实渲染 UI 截图验收：以与框架测试一致的 bootstrap 启动 Core，挂载 main.tscn，截取船厂正常态/改装态/分类/操作坞页签/受损状态，并可选截取主界面（全窗 3D 港口舞台 + 紧凑 HUD + 两侧招牌）、2D 总览页（原详细总览抽屉在 2026-10-28 UI 轮移除），以及市场/补给页的泊位侧栏（舞台 + 右侧面板）及其 960×540 版本。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MAIN_SCENE` | L69 |
| `SHIPYARD_SCREEN_SCRIPT` | L70 |
| `OVERVIEW_SCREEN_SCRIPT` | L71 |
| `SN_SHIP_VIEW_SCRIPT` | L72 |
| `STEADY_BUILD` | L73 |
| `DEFAULT_SEED` | L74 |
| `DEFAULT_OUT_DIR` | L75 |
| `DEFAULT_WINDOW` | L76 |
| `LAYOUT_FRAMES` | L78 |
| `LAYOUT_SETTLE_SECONDS` | L79 |
| `REFIT_FRAMES` | L80 |
| `REFIT_SETTLE_SECONDS` | L81 |
| `STATION_SCREENS` | L84 |
| `STATION_SMALL_WINDOW` | L88 |
| `STATION_TIMEOUT_SECONDS` | L89 |
| `WATCHDOG_SECONDS` | L91 |
| `VICTORY_SCREEN_SCRIPT` | L96 |
| `EVENT_SCREEN_SCRIPT` | L97 |
| `UI_KIT_SCENE` | L98 |
| `STANDARD_STRATEGY` | L100 |
| `SKIN_PORT_SCREENS` | L102 |
| `SKIN_FLOW_SCREENS` | L108 |
| `SKIN_MENU_SCREENS` | L109 |
| `SKIN_ALL_SCREENS` | L110 |
| `FLOW_DRIVE_STEP` | L119 |
| `FLOW_DRIVE_MAX_SECONDS` | L120 |
| `EVENT_SEED_SEARCH` | L122 |
| `_init() -> void` | L148 |
| `SKIN_SCREEN_SCRIPTS` | L741 |
| `AUTO_TRADE_SCREEN_ID` | L759 |
| `FULL_CLEAR_MEDIUM_HULL` | L760 |
| `FULL_CLEAR_LARGE_HULL` | L761 |
| `FULL_CLEAR_CABIN` | L762 |

## 契约与约束

- 必须窗口模式运行：`--headless` 时视口纹理为空，脚本直接判失败。
- 参数走 `--` 之后：`--seed` / `--out-dir` / `--window` / `--category` / `--tabs` / `--damage` / `--skip-refit` / `--overview-stage` / `--overview-detail` / `--station-shots`。
- `--damage=slot[:index]:ratio` 在 run.start 后用 `ShipModules.damage()` 损坏模块实例，额外截取 `shipyard_normal_damaged` / `shipyard_refit_damaged` / `supply_damaged`；只影响截图进程，不进入游戏逻辑。
- `--tabs=buy,craft`：进入改装态后按操作坞页签各截一张 `shipyard_refit_<tab>.png`（购买 / 打造与装配分离），再切回装配页继续分类截图。`--overview-stage`：切到总览（默认即 3D 舞台，若处于 2D 回退才调 `_on_overview_stage_toggle()`）→ 断言 `_overview_stage_mode`、`PortStage` 宿主可见、设施数 > 0、`has_ship()`、招牌数 = 设施数（supply 并入 market 后无独立招牌）或设施数 + 1、`_top_chrome` 高度 ≤130、不存在 `PortStatusBar` → 保存 `overview_port_stage.png`。
- `--overview-detail`：在 `--overview-stage` 基础上把总览切到 2D 页面（顶部「2D 总览」同一入口；抽屉已在 2026-10-28 UI 轮移除），断言 2D 总览页挂载 → 保存 `overview_detail.png`。
- `--station-shots`：分别切到 market / supply 页，轮询 `_port_stage_host` 的 `has_stage()+is_stage_visible()`、`PortStage.current_station()==目标` 且 `is_station_transitioning()==false` 后截图，保存 `market_station.png` / `supply_station.png`，并在同一进程内把窗口缩到 960×540 补拍 `market_station_960.png`，用于验证缩放下舞台与侧栏都不裁切。
- 进入改装态优先点页面真实「改装」按钮，其次调 `_on_toggle_refit()`，最后按按钮文案兜底，页面小改版后工具仍可用；改装页画在 3D 港区 `shipyard` 站位上，截图前用 `_wait_port_stage_settled()` 轮询 `_port_stage_host` 的 `is_stage_visible()` / `PortStage.is_station_transitioning()`，等镜头平移与玩家船靠泊结束再拍。
- 纯色画面判定为失败；120 s watchdog 防止协程中断挂住窗口；成功退出码 0，失败 1。
- 只写 `docs/design/screenshots/`（或 `--out-dir` 临时目录），不修改游戏状态或源码。

模块索引：[tools](./README.md)
