# `framework/ui/screens/port/overview_screen.gd`

> 作用：港口总览页面场景：组合港口横幅、海图、主线目标、通关清单、船只摘要、快捷操作、财务与航行记录；三种呈现由 Shell 控制——裸 3D 舞台（页面只留 spacer）、详细总览抽屉（原 2D 面板覆盖舞台）与 2D 回退总览。

- 关键依赖：`MapCanvas`、`SNResourceMeter`、`SNBadge`、`SNSectionHeader`、`ClockService`、`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `OverviewScreen` | L1 |
| `navigation_requested (signal)` | L5 |
| `command_requested (signal)` | L6 |
| `map_port_clicked (signal)` | L7 |
| `stage_toggle_requested (signal)` | L10 |
| `detail_toggle_requested (signal)` | L13 |
| `MAP_CANVAS_SCENE` | L15 |
| `TEXT` | L16 |
| `MUTED` | L17 |
| `BRASS` | L18 |
| `TEAL` | L19 |
| `RED` | L20 |
| `GREEN` | L21 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L25 |

## 契约与约束

- bind(vm, translate) 接收 Shell 组合后的 banner_path、map、current_port、contracts、victory、ship、debt 与 notice_texts，不访问 AppContext、QueryBus、注册表或资产服务。
- 港口横幅来自内容模组：页面优先用 `ContentAssetLoader.load_texture(banner_path)` 读原始 PNG，`ResourceLoader.exists` 为真时退回 `load()`；两种路径都失败则不渲染横幅。
- 地图点击只发出 map_port_clicked；功能入口只发出 navigation_requested；等待与借款只发出 command_requested。
- 航行记录使用 Shell 已安全填充并本地化的 notice_texts，页面不重复解释 GameState 通报参数。
- 构筑胜利条件直接取 contracts 进度与 victory.conditions 展示，不在页面重新判断通关。
- 目标清单等密集横向字段保持单行，避免右侧说明被压缩成逐字竖排并撑高卡片。
- 页面可重复 bind，每次清理旧节点；海图仍由独立 map_canvas.tscn 负责绘制。
- 有两个意图信号：`stage_toggle_requested`（2D/3D 总览切换）与 `detail_toggle_requested`（详细总览抽屉开关）；舞台宿主、抽屉 backdrop、状态条与回退都在 Shell，页面不持有 SNStageHost。
- `bind(vm, translate)` 读 `stage_available/stage_mode/overview_detail`；当 `overview_detail && stage_available` 时先加 `_detail_header()`（「返回主界面」按钮 + `ui.hint.overview_detail` 提示），再 `_build_detail(vm)` 渲染原 2D 面板（含 victory plan），该路径是抽屉内容。
- stage_mode 且未开抽屉：只加 expanding spacer 后直接返回，让 Shell 的全窗 3D 舞台露出；2D 回退模式在 hero 前加 `_stage_control_row(false)`（`ui.button.port_stage`「俯瞰港口」，发 stage_toggle_requested），同时渲染完整 `_build_detail(vm)`。
- `_build_detail(vm)` 只是原总览面板的入口重构，横幅/海图/左右面板/通告布局与数据契约不变；页面仍不访问 AppContext、QueryBus 或资产服务。

模块索引：[framework/ui](../../README.md)
