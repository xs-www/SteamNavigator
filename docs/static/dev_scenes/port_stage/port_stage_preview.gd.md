# `dev_scenes/port_stage/port_stage_preview.gd`

> 作用：PortStage 独立预览场景根（不接入主流程）：构建铺满窗口的 `SNStageHost`、挂载 `port_stage.tscn`、提供 preview / sparse 两份样例 ViewModel，并支持三站位切换与 town 资源根覆盖，供截图、draw call 实测与三条资产加载路径复现。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `STAGE_SCENE` | L50 |
| `BANNER_PATH` | L51 |
| `TOWN_VISUALS` | L56 |
| `VARIANT_PREVIEW` | L84 |
| `VARIANT_SPARSE` | L85 |
| `set_variant(variant_name: String) -> void` | L108 |
| `current_variant() -> String` | L114 |
| `current_stage() -> Node` | L120 |
| `set_station(station_id: String = "harbor", framing: String = "stage") -> bool` | L131 |
| `station_id() -> String` | L149 |
| `station_framing() -> String` | L154 |
| `PROTOTYPE_ROOT` | L180 |
| `COMBO_OVERRIDES` | L181 |

- 关键依赖：`SNStageHost`、`framework/ui/stages/port_stage.tscn`

## 契约与约束
- `set_variant("preview"|"sparse")` 不重挂舞台，只重新 bind 样例 payload；`current_variant()` 返回当前样例。
- `set_station(station_id = "harbor", framing = "stage")` 调 `PortStage.focus_station(id, framing, true)`（立即生效，截图确定性），返回是否被接受；`station_id()`/`station_framing()`/`current_stage()` 供截图与实测工具轮询。
- `TOWN_VISUALS` 是 26 项 dev 路径映射（10 个 `res://dev_mods/core/assets/models/props/SN_HT_*.glb` + 道具/设施）的样例；`_town_visuals()` 把其中位于松散 core props 目录的路径按 `SN_TOWN_ASSET_ROOT` 重新定根，从而让同一场景能从挂载的 `.snavmod.zip`（`res://mods/core/assets/models/props`，原始 `ContentAssetLoader` 路径）加载整套街景；框架自有资产（如 `market_stall`）保持原路径。
- `sparse` 覆盖：无 banner（painted backdrop + 3 层远景 + 3 层雾带）、small→sparse 密度、根层 `facility_visuals`、`hull_model_path` 为空时按 `hull_tier` 回退；`preview` 走铁港 banner + normal 47 件 town 街景 + 24 件站前道具。
- 每个 variant / 站位打印设施 kinds、filler 数、backdrop、density、town_props、painted_layers、合批前后（batches、mesh/surface before→after）与投影后的设施锚点；`_print_scene_fill()` 只读统计粒子/雾/远景/前景框/三角面预算。
- 运行：`godot --path . res://dev_scenes/port_stage/port_stage_preview.tscn`；截图 `tools/godot/capture_port_stage.gd`；实测 `tools/godot/measure_port_stage.gd`（加 `-- --core-zip` 切到 ZIP 加载路径）。

模块索引：[dev_scenes](../README.md)
