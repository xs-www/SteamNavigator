# `framework/tests/cases/test_stage_host.gd`

> 作用：2.5D 舞台基础设施契约测试（9 个同步用例）：LocationStage 默认契约、SNStageHost 生命周期/回退/停更、ShipyardStage 场景、SNShipStage3D 适配器与 PortStage 装配/替换/缩放/portal。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `test_location_stage_default_contract_is_callable() -> void` | L73 |
| `test_host_mounts_stage_and_drives_enter_bind_exit_lifecycle() -> void` | L92 |
| `test_host_emits_fallback_for_missing_or_non_stage_scenes() -> void` | L168 |
| `test_shipyard_stage_scene_loads_and_binds_a_hull() -> void` | L194 |
| `test_ship_stage_3d_adapter_wraps_the_stage_host() -> void` | L215 |
| `test_port_stage_assembles_present_facilities_and_fills_empty_slots() -> void` | L266 |
| `test_port_stage_uses_facility_visual_models_and_falls_back_on_missing_files() -> void` | L305 |
| `test_port_stage_scales_facility_anchors_with_port_size() -> void` | L325 |
| `test_port_stage_mounts_the_player_hull_and_requests_portals() -> void` | L353 |

## 契约与约束

- 全部是同步函数（无 await）：节点在同一步内加入 SceneTree 即同步派发 `_ready` 与 `add_child` 通知，挂载/卸载可在一步内断言；每个用例自建节点并在结尾 free，避免残留节点影响其他套件。
- LocationStage：裸节点 `stage_id` 为空、`has_visual()` true、`hotspot_anchors()` 空、`portal_requested` 可发。
- SNStageHost：`stage_mounted` / `stage_unmounted` / `portal_requested` 转发；`enter` 先于 `bind` 且 payload 到达 enter；`bind_view_model` 重绑并缓存；隐藏 → 舞台 `PROCESS_MODE_DISABLED` + viewport `UPDATE_DISABLED`，显示恢复；卸载后 stage_id 清空且可挂新舞台（空 id 回退节点名）。
- 回退：缺失场景发 `stage_scene_missing:*`；根不是 LocationStage 的 `sn_badge.tscn` 发 `stage_not_location_stage:*` 且不挂载。
- ShipyardStage：真实场景可加载、根类型与 stage_id 正确；`hull_tier=1` 绑定后 `has_ship()` 且 `model_path()` 含 `SN_Paddle_Steamer`。
- SNShipStage3D 适配器：`_ready` 自动挂船厂舞台；`ship_view_update` 转发 `hull_model_path`；`ship_view_set_mode(1/0)` 隐藏/显示；`ship_view_highlight` 可调用。
- PortStage 四组：present 设施才有锚点/热点且缺席只 filler（缺省 billboard / missing）；`facility_visuals` GLB 替换与非法路径回退 billboard；`size` 0.9/1.15 缩放锚点；`hull_model_path` 挂玩家船 + `request_portal` 经 host 转发。
- PortStage 投影锚点断言有限值，缺席设施投影返回 `Vector2.ZERO`；`has_backdrop()` 在无 banner 时为 false。

模块索引：[framework/tests](../README.md)
