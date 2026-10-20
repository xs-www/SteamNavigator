# `tools/godot/capture_harbor_diorama.gd`

> 作用：港口样片真实渲染截图（窗口模式）：加载 harbor_diorama.tscn，等水面/浮船稳定后抓固定 3/4 机位与纵帆船近景两张 1440×900 截图。

- 关键依赖：`dev_scenes/harbor/harbor_diorama.tscn`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SCENE_PATH` | L14 |
| `OUT_DIR` | L15 |
| `WINDOW` | L16 |
| `SETTLE_FRAMES` | L17 |
| `SETTLE_SECONDS` | L18 |
| `DETAIL_FRAMES` | L19 |
| `DETAIL_SECONDS` | L20 |
| `WATCHDOG_SECONDS` | L21 |
| `_init() -> void` | L27 |

## 契约与约束

- 必须窗口模式运行：`--headless` 时视口纹理为空，脚本直接判失败。
- 等待 90 帧 + 1 s 后再抓第一张；近景把 Camera3D 移到 (30, 11, 34) 并对准船体中部。
- 输出 `docs/design/screenshots/harbor_diorama_schooner.png` 与 `harbor_diorama_schooner_detail.png`；120 s watchdog；失败退出码 1。
- 只写截图，不修改场景/源码。

模块索引：[tools](../README.md)
