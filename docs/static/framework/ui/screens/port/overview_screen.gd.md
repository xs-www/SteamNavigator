# `framework/ui/screens/port/overview_screen.gd`

> 作用：港口总览页面场景：组合港口横幅、海图、主线目标、通关清单、船只摘要、快捷操作、财务与航行记录。

- 关键依赖：`MapCanvas`、`SNResourceMeter`、`SNBadge`、`SNSectionHeader`、`ClockService`、`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `OverviewScreen` | L1 |
| `navigation_requested (signal)` | L5 |
| `command_requested (signal)` | L6 |
| `map_port_clicked (signal)` | L7 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L19 |

## 契约与约束

- bind(vm, translate) 接收 Shell 组合后的 banner_path、map、current_port、contracts、victory、ship、debt 与 notice_texts，不访问 AppContext、QueryBus、注册表或资产服务。
- 地图点击只发出 map_port_clicked；功能入口只发出 navigation_requested；等待与借款只发出 command_requested。
- 航行记录使用 Shell 已安全填充并本地化的 notice_texts，页面不重复解释 GameState 通报参数。
- 构筑胜利条件直接取 contracts 进度与 victory.conditions 展示，不在页面重新判断通关。
- 目标清单等密集横向字段保持单行，避免右侧说明被压缩成逐字竖排并撑高卡片。
- 页面可重复 bind，每次清理旧节点；海图仍由独立 map_canvas.tscn 负责绘制。

模块索引：[framework/ui](../../README.md)
