# `dev_scenes/port_stage/port_stage_preview.gd`

> 作用：PortStage 独立预览场景根（不接入主流程）：构建铺满窗口的 `SNStageHost`，挂载 `port_stage.tscn`，提供 `preview`（铁港全设施 + banner + 街道 town kit + 明轮船）与 `sparse`（香料港 small、三设施、无 banner、根层 facility_visuals/town_visuals）两份样例 ViewModel；`set_station()` 可把镜头切到 market/harbor/supply 三个相邻站位（stage 或 panel 构图）并打印站位自查。

- 关键依赖：`SNStageHost`、`framework/ui/stages/port_stage.tscn`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `set_variant(variant_name: String) -> void` | L86 |
| `current_variant() -> String` | L92 |
| `current_stage() -> Node` | L98 |
| `set_station(station_id: String = "harbor", framing: String = "stage") -> bool` | L109 |
| `station_id() -> String` | L127 |
| `station_framing() -> String` | L132 |

## 契约与约束

- `set_variant("preview"|"sparse")` 不重挂舞台，只重新 bind 样例 payload；`current_variant()` 返回当前样例。
- `set_station(station_id = "harbor", framing = "stage")` 调 `PortStage.focus_station(id, framing, true)`（立即生效，截图确定性），返回是否被接受；`station_id()`/`station_framing()`/`current_stage()` 供截图与实测工具轮询。
- `_print_station()` 打印站位/current/transitioning/station_props、相机 pose（position/target/fov）与实际相机、船位/船 X、设施屏幕锚点与 `station_ids()`，便于核对 panel 构图是否把设施留在可见左半屏。
- `TOWN_VISUALS` 是 26 项 dev 路径映射（10 个 `res://dev_mods/core/assets/models/props/SN_HT_*.glb` + crate/barrel/coal_pile/timber_stack/handcart/gas_lamp + market_stall/harbor_crane/sack_pile/plate_stack/ore_pile/pallet/gangway/mooring_bollard/capstan/buoy），两份 payload 都带 `town_visuals`，模拟 `port.view` 解析后的结果；站前道具复用同一批 key。
- `sparse` 同时覆盖：L1 无 banner（painted backdrop + 3 层远景 + 3 层雾带）、small→sparse 密度、根层 `facility_visuals`、`hull_model_path` 为空时按 `hull_tier` 回退；`preview` 走铁港 banner + normal 47 件 town 街景 + 24 件站前道具（town 与 banner 独立）。
- 每个 variant 打印设施 kinds / filler 数 / backdrop / ship / density / town_props / painted_layers / static batches（batches、mesh/surface before→after）与投影后的设施锚点，便于截图时核对。
- `_print_scene_fill()` 只读自查：打印 particles / fog_layers / skyline_buildings / skyline_cranes / town_props / town_blockouts / town_density / painted_layers / static batches、`foreground_frame()` 的屏幕 uv bbox、mesh/particle/tri 预算，以及 `FallbackBackdrop` 各子节点的可见性/尺寸与中心 uv；`_count_meshes()` / `_mesh_triangles()` 递归统计 MultiMesh / GPUParticles3D / MeshInstance3D。
- 运行：`godot --path . res://dev_scenes/port_stage/port_stage_preview.tscn`；截图用 `tools/godot/capture_port_stage.gd`。

模块索引：[dev_scenes](../README.md)
