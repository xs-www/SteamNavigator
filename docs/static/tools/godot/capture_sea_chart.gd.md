# `tools/godot/capture_sea_chart.gd`

> 作用：海图系统（阶段 2）的真实渲染截图工具，窗口 1440×900 挂载

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `PREVIEW_SCENE` | L23 |
| `OUT_DIR` | L24 |
| `WINDOW` | L25 |
| `SETTLE_FRAMES` | L26 |
| `SETTLE_SECONDS` | L27 |
| `READY_TIMEOUT_SECONDS` | L28 |
| `WATCHDOG_SECONDS` | L29 |
| `TMP_PREFIX` | L30 |
| `SHOTS` | L31 |
| `_init() -> void` | L43 |

`dev_scenes/sea_chart/sea_chart_preview.tscn`，依次切换预览变体并落盘 PNG。

用法（**必须窗口模式**，`--headless` 下视口纹理为空图）：
  godot --path . --resolution 1440x900 --script res://tools/godot/capture_sea_chart.gd

输出（全部 1440×900，写入 `docs/design/screenshots/sea_chart/`）：
  sea_chart_fresh.png     仅起点港已发现：大片黑雾 + 港口揭示光斑
  sea_chart_bare.png      诊断：整张图已揭示，单独看陆地/港口/航线拓扑
  sea_chart_explored.png  沿岸航行后：海岸灰雾带 + 整岛剪影 + 稀疏航线网络
  sea_chart_voyage.png    在航 + 选中目的港：右侧面板显示距离/风险/启航

## 契约与约束
- 每张图先写 `res://tmp_sea_chart_*`，全部成功后才移入 `docs/`；失败则以退出码 1
  结束且不留半套新截图。
- 纯色/近纯色画面视为"读到未绘制纹理"，判为失败（说明绘制逻辑没跑起来）。
- 90 s 看门狗兜底：脚本错误会让协程中断而不退出，避免窗口挂住。
- 从预览场景读取 `get_chart().view_model` 非空后再截图，避免拍到空海图。

模块索引：[tools](../README.md)
