# `framework/ui/screens/flow/at_sea_screen.gd`

> 作用：航行演出页（海图系统阶段 3）：整幅海图 + 底部航程条。船只 icon 沿

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `AtSeaScreen` | L1 |
| `skip_requested (signal)` | L30 |
| `COLOR_TEXT` | L32 |
| `COLOR_MUTED` | L33 |
| `COLOR_TEAL` | L34 |
| `COLOR_BRASS` | L35 |
| `HEADING_SAMPLE` | L38 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L64 |
| `set_presentation(snapshot: Dictionary) -> void` | L85 |
| `get_chart() -> SNSeaChartView` | L110 |
| `get_route_path() -> PackedVector2Array` | L116 |
| `get_world_route_path() -> PackedVector2Array` | L121 |
| `get_unknown_destination() -> Dictionary` | L126 |
| `get_progress() -> float` | L131 |
| `get_ship_world_position() -> Vector2` | L136 |
| `get_ship_heading() -> float` | L142 |
| `get_ship_vision_radius() -> float` | L147 |
| `unpack_route_path(raw: Variant) -> PackedVector2Array` | L247 |

**世界航线表里的真实航线**（Shell 通过 `route_path` 传入）按弧长行进，航程条
显示进度、预计抵达时间、时间倍率，并提供「跳过演出」。

## 契约与约束
- 本页不查询、不执行命令、不推进时间：Shell 把 `sea_chart.view` 结果、
  完整航线路点（`route_path`）和 `VoyagePresentation.snapshot()` 推进来
  （`bind()` / `set_presentation()`）。
- **航线数据源**：优先用 `route_path`（来自 `WorldMap.edges` 的完整世界航线表，
  与战争迷雾无关——迷雾只决定"画不画在图上"，不决定演出数据）。它缺失时
  才退回海图查询的已发现航线，最后才退回「起点→终点直线」。
- 船只坐标只通过 `SNSeaChartView.set_ship_pose()` 覆盖（位置 + 航线切线艏向），
  不重新绑定整个视图模型（每帧重绑会把迷雾纹理与取景一起重建）。艏向取航线
  切线，船 icon 因此始终朝着实际移动方向。
- 航行页的海图是演出取景（`set_presentation_mode`）：铺满可用窗口，并由
  `snapshot()["chart_zoom_scale"]` 驱动「云层散开时由近拉远 / 入港前推近」。
- **探索演出**（探索系统 4.1）：`bind()` 收到 `unknown_destination: {x, y, label_key}`
  时把未知终点交给海图（虚线预测线 + `?` 标记），航程条右侧目的地显示 `？`
  （`label_key`，通常 `ui.label.unknown_destination`），起点仍显示港口名。
- **随船照亮**（4.3.3 / U4）：演出视野半径取 `sea_chart.view` 的
  `fog_radii.vision`（与领域同源，由 Core 比例推导），`bind()` 重建海图后与每次
  `set_presentation()` 都推给 `SNSeaChartView.set_ship_vision()`。纯表现：本页
  不查询后端、不写领域状态。
- `skip_requested` 只表达意图；跳过后事件仍由 Shell 推给玩家。

模块索引：[framework/ui](../../README.md)
