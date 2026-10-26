# `tools/godot/measure_port_stage.gd`

> 作用：PortStage 真实渲染预算实测（窗口 1440×900）：挂载 `port_stage_preview.tscn`，依次采样 `preview`、`sparse` 与舞台 `station_ids()` 的全部站位（当前 market/harbor/shipyard/supply，stage 构图），优先用 `RenderingServer.get_rendering_info()` 读取整帧 draw calls / primitives，并输出场景 mesh/MultiMesh/粒子/surface/triangle 分析、舞台分层 surface、`batch_stats()`、`town_density()`、`station_prop_count()`、`painted_backdrop_layer_count()` 与「排除玩家船后的 stage draws」。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `PREVIEW_SCENE` | L52 |
| `WINDOW` | L53 |
| `SETTLE_FRAMES` | L54 |
| `SETTLE_SECONDS` | L55 |
| `SWITCH_FRAMES` | L56 |
| `SWITCH_SECONDS` | L57 |
| `STATION_FRAMES` | L58 |
| `STATION_SECONDS` | L59 |
| `STATION_TIMEOUT_SECONDS` | L60 |
| `SAMPLE_FRAMES` | L61 |
| `WATCHDOG_SECONDS` | L62 |
| `DRAW_CALL_BUDGET` | L63 |
| `TRIANGLE_BUDGET` | L64 |
| `STATIONS` | L66 |
| `STATION_FRAMING` | L67 |
| `_init() -> void` | L80 |

- 关键依赖：`dev_scenes/port_stage/port_stage_preview.tscn`、`RenderingServer`、`PortStage.batch_stats()`

## 契约与约束
- 必须窗口模式才能读到真实 draw calls；headless 时打印明确说明并走 mesh/surface 分析口径，不视为失败、不挂窗口。
- 采样 6 帧取峰值，避免 resize / 首帧低值；成功条件为 `2 + station_ids().size()` 个样本（preview/sparse + 每个站位，当前 4 个站位共 6 个）都完成测量，否则退出码 1。
- 预算阈值 120 draws / 60,000 tris；每个站位单独输出 ≤120 / ≤60k 判定与一行汇总，超出只报告 OVER 不改变退出码（测量工具不替代验收）。注意 60k 是整场景 tri 口径；§5.1 的「同屏城镇建筑 ≤60k / LOD1 组合 ≤20k」需用 5 栋 GLB 求和另行复算。
- `-- --core-zip` 会把 `dev_mods/core` 打成 `.snavmod.zip` 并挂载，把 `SN_TOWN_ASSET_ROOT` 指向 `res://mods/core/assets/models/props`，从而以原始 `ContentAssetLoader` 路径实测 ZIP 加载；`-- --core-zip=PATH` 挂载既有包（如 `dist/mods/core-1.0.0.snavmod.zip`）。不传时仍是松散 `dev_mods`（导入资源路径）。
- 180 s watchdog；只读场景，不修改游戏状态或源码。
- 输出包含总 draw calls（含已合并玩家船）与 stage 自身（excl. hull），便于区分舞台预算与不可批的船体开销。

模块索引：[tools](../README.md)
