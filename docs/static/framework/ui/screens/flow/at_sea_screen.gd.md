# `framework/ui/screens/flow/at_sea_screen.gd`

> 作用：航行演出页（海图系统阶段 3）：整幅海图 + 底部航程条。船只 icon 沿

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `AtSeaScreen` | L1 |
| `skip_requested (signal)` | L26 |
| `COLOR_TEXT` | L28 |
| `COLOR_MUTED` | L29 |
| `COLOR_TEAL` | L30 |
| `COLOR_BRASS` | L31 |
| `HEADING_SAMPLE` | L34 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L57 |
| `set_presentation(snapshot: Dictionary) -> void` | L77 |
| `get_chart() -> SNSeaChartView` | L101 |
| `get_route_path() -> PackedVector2Array` | L107 |
| `get_world_route_path() -> PackedVector2Array` | L112 |
| `get_unknown_destination() -> Dictionary` | L117 |
| `get_progress() -> float` | L122 |
| `get_ship_world_position() -> Vector2` | L127 |
| `get_ship_heading() -> float` | L133 |
| `unpack_route_path(raw: Variant) -> PackedVector2Array` | L222 |

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
- `skip_requested` 只表达意图；跳过后事件仍由 Shell 推给玩家。

模块索引：[framework/ui](../../README.md)
