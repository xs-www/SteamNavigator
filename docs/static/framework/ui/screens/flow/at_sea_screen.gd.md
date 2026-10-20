# `framework/ui/screens/flow/at_sea_screen.gd`

> 作用：航行演出页（海图系统阶段 3）：整幅海图 + 底部航程条。船只 icon 沿

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `AtSeaScreen` | L1 |
| `skip_requested (signal)` | L18 |
| `COLOR_TEXT` | L20 |
| `COLOR_MUTED` | L21 |
| `COLOR_TEAL` | L22 |
| `COLOR_BRASS` | L23 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L41 |
| `set_presentation(snapshot: Dictionary) -> void` | L55 |
| `get_chart() -> SNSeaChartView` | L78 |
| `get_progress() -> float` | L83 |
| `get_ship_world_position() -> Vector2` | L88 |

`sea_chart.view` 里那条航线的贝塞尔折线、按弧长行进，航程条显示进度、
预计抵达时间、时间倍率，并提供「跳过演出」。

## 契约与约束
- 本页不查询、不执行命令、不推进时间：Shell 把 `sea_chart.view` 结果和
  `VoyagePresentation.snapshot()` 推进来（`bind()` / `set_presentation()`）。
- 船只坐标只通过 `SNSeaChartView.set_ship_position()` 覆盖，不重新绑定整个
  视图模型（每帧重绑会把迷雾纹理与取景一起重建）。
- 缺航线路径（例如孪生世界 MST 上没有这段边）时退回「起点→终点直线」，
  演出仍然成立，不出现船停在原地不动。
- `skip_requested` 只表达意图；跳过后事件仍由 Shell 推给玩家。

模块索引：[framework/ui](../../README.md)
