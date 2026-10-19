# `tools/godot/measure_port_stage.gd`

> 作用：PortStage 真实渲染预算实测（窗口 1440×900）：挂载 `port_stage_preview.tscn`，等场景稳定后分别采样 `preview` 与 `sparse`，优先用 `RenderingServer.get_rendering_info()` 读取整帧 draw calls / primitives，并输出场景 mesh/MultiMesh/粒子/surface/triangle 分析、舞台分层 surface、`batch_stats()`（facilities/town 与船体合批前后）、`town_density()`、`painted_backdrop_layer_count()` 与「排除玩家船后的 stage draws」。

- 关键依赖：`dev_scenes/port_stage/port_stage_preview.tscn`、`RenderingServer`、`StageKit`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `_init() -> void` | L40 |

## 契约与约束

- 必须窗口模式才能读到真实 draw calls；headless 时打印明确说明并走 mesh/surface 分析口径，不视为失败、不挂窗口。
- 采样 6 帧取峰值，避免 resize / 首帧低值；成功条件为两个 variant 都完成测量，否则退出码 1。
- 预算阈值 120 draws / 60,000 tris；超出只报告 OVER 不改变退出码（测量工具不替代验收）。
- 180 s watchdog；只读场景，不修改游戏状态或源码。
- 输出包含总 draw calls（含已合并玩家船）与 stage 自身（excl. hull），便于区分舞台预算与不可批的船体开销。

模块索引：[tools](../README.md)
