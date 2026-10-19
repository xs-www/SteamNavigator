# `framework/ui/screens/port/overview_screen.gd`

> 作用：港口总览页面场景：组合港口横幅、海图、主线目标、通关清单、船只摘要、快捷操作、财务与航行记录；支持 2D 总览与 3D 港口舞台两种密度（stage 模式只留控制行，让 Shell 的全窗舞台露出）。

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
| `bind(vm: Dictionary, translate: Callable) -> void` | L22 |

## 契约与约束

- bind(vm, translate) 接收 Shell 组合后的 banner_path、map、current_port、contracts、victory、ship、debt 与 notice_texts，不访问 AppContext、QueryBus、注册表或资产服务。
- 港口横幅来自内容模组：页面优先用 `ContentAssetLoader.load_texture(banner_path)` 读原始 PNG，`ResourceLoader.exists` 为真时退回 `load()`；两种路径都失败则不渲染横幅。
- 地图点击只发出 map_port_clicked；功能入口只发出 navigation_requested；等待与借款只发出 command_requested。
- 航行记录使用 Shell 已安全填充并本地化的 notice_texts，页面不重复解释 GameState 通报参数。
- 构筑胜利条件直接取 contracts 进度与 victory.conditions 展示，不在页面重新判断通关。
- 目标清单等密集横向字段保持单行，避免右侧说明被压缩成逐字竖排并撑高卡片。
- 页面可重复 bind，每次清理旧节点；海图仍由独立 map_canvas.tscn 负责绘制。
- 新增 `signal stage_toggle_requested`：页面只表达「切换 2D/3D 总览」意图；舞台宿主的创建、显隐与回退都在 Shell，页面不持有 SNStageHost。
- `bind(vm, translate)` 读 `stage_available` / `stage_mode`（`stage_mode` 需同时 stage_available）；stage 模式下只添加 `_stage_control_row(true)` + expanding spacer 后直接返回，不渲染横幅/海图/面板。
- 普通模式在 hero 之前添加同一行 `_stage_control_row(false)`：按钮文案 `ui.button.port_stage`（俯瞰港口）/ stage 模式 `ui.button.overview_back`（返回总览），旁边是 `ui.hint.port_stage` 提示；按钮发 `stage_toggle_requested`。
- `_stage_control_row(in_stage)` 是本次唯一新增的 UI；其余布局与数据契约不变，页面仍不访问 AppContext、QueryBus 或资产服务。

模块索引：[framework/ui](../../README.md)
