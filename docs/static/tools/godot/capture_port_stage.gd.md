# `tools/godot/capture_port_stage.gd`

> 作用：PortStage 真实渲染截图（窗口模式 1440×900）：加载 `port_stage_preview.tscn`，等水面/船体稳定后抓 `preview`，再切 `sparse` 抓第二张，输出到 `docs/design/screenshots/port_stage/`。

- 关键依赖：`dev_scenes/port_stage/port_stage_preview.tscn`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `_init() -> void` | L28 |

## 契约与约束

- 必须窗口模式：`DisplayServer.get_name() == "headless"` 时直接失败（视口纹理为空）。
- 稳定窗口：首次 90 帧 + 1 s，切换 variant 后 30 帧 + 0.5 s；空图/保存失败计为 failures。
- 成功条件：2 张图都保存且 failures=0，否则退出码 1；输出 `port_stage_preview.png` 与 `port_stage_sparse.png`。
- 120 s watchdog 防止协程挂住窗口；只写截图，不修改场景/源码。

模块索引：[tools](../README.md)
