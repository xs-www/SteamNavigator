# `dev_scenes/port_stage/port_stage_preview.gd`

> 作用：PortStage 独立预览场景根（不接入主流程）：构建铺满窗口的 `SNStageHost`，挂载 `port_stage.tscn`，提供 `preview`（铁港全设施 + banner + 明轮船）与 `sparse`（香料港 small、三设施、无 banner、根层 facility_visuals GLB）两份样例 ViewModel，并打印场景填充/前景框投影/预算自查。

- 关键依赖：`SNStageHost`、`framework/ui/stages/port_stage.tscn`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `set_variant(variant_name: String) -> void` | L42 |
| `current_variant() -> String` | L48 |

## 契约与约束

- `set_variant("preview"|"sparse")` 不重挂舞台，只重新 bind 样例 payload；`current_variant()` 返回当前样例。
- `sparse` 同时覆盖三条回退分支：L1 无 banner（painted backdrop + L2 剪影 + 3 层雾带）、根层 `facility_visuals` GLB 替换、`hull_model_path` 为空时按 `hull_tier` 回退；`preview` 走铁港 banner，L2 建筑/吊机数为 0。
- 每个 variant 打印设施 kinds / filler 数 / backdrop / ship 与投影后的设施锚点，便于截图时核对。
- `_print_scene_fill()` 只读自查：打印 particles / fog_layers / skyline_buildings / skyline_cranes、`foreground_frame()` 的屏幕 uv bbox、mesh/particle/tri 预算，以及 `FallbackBackdrop` 各子节点的可见性/尺寸与中心 uv；`_count_meshes()` / `_mesh_triangles()` 递归统计 MultiMesh / GPUParticles3D / MeshInstance3D。
- 运行：`godot --path . res://dev_scenes/port_stage/port_stage_preview.tscn`；截图用 `tools/godot/capture_port_stage.gd`。

模块索引：[dev_scenes](../README.md)
