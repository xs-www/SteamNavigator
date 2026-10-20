# `tools/godot/capture_port_stage.gd`

> 作用：PortStage 真实渲染截图（窗口模式 1440×900）：加载 `port_stage_preview.tscn`，依次抓 `preview`（harbor/stage）、`sparse`、`market` 站位、`supply` 站位与 `harbor` 的 panel 构图共 5 张，输出到 `docs/design/screenshots/port_stage/`。

- 关键依赖：`dev_scenes/port_stage/port_stage_preview.tscn`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `_init() -> void` | L59 |

## 契约与约束

- 必须窗口模式：`DisplayServer.get_name() == "headless"` 时直接失败（视口纹理为空）。
- 稳定窗口：首次 90 帧 + 1 s，切换 variant/站位后 30 帧 + 0.5 s；每张额外轮询 `is_station_transitioning()==false` 且 `StageCamera` 位置接近 `station_camera_pose()`（≤0.75 m、朝向 dot>0.999）再截，空图/保存失败计为 failures。
- 成功条件：5 张图都保存且 failures=0，否则退出码 1；文件名 `port_stage_preview/sparse/market/supply/harbor_page.png`。
- 先写 `res://tmp_*`，全部成功后才搬进 docs 并删除 tmp；120 s watchdog 防止协程挂住窗口；只写截图，不修改场景/源码。

模块索引：[tools](../README.md)
