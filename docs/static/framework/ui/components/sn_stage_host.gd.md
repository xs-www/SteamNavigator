# `framework/ui/components/sn_stage_host.gd`

> 作用：通用 3D 舞台宿主（SubViewportContainer）：持有独占 SubViewport/World3D，加载并挂载一个 `LocationStage`，驱动 enter→bind 生命周期、舞台显隐与渲染停更，并转发 `portal_requested` / `fallback_requested`；同时是船厂 `SNShipView` 的渲染器后端。

- 关键依赖：`LocationStage`、`SNShipStage3D`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNStageHost` | L1 |
| `stage_mounted (signal)` | L16 |
| `stage_unmounted (signal)` | L17 |
| `portal_requested (signal)` | L18 |
| `fallback_requested (signal)` | L19 |
| `load_stage(path: String, payload: Dictionary = {}) -> bool` | L72 |
| `mount_stage(stage: Node, payload: Dictionary = {}) -> bool` | L100 |
| `unmount_stage() -> void` | L122 |
| `bind_view_model(view_model: Dictionary) -> void` | L139 |
| `has_stage() -> bool` | L145 |
| `current_stage() -> Node` | L149 |
| `stage_id() -> String` | L153 |
| `view_model() -> Dictionary` | L157 |
| `stage_world() -> Node3D` | L161 |
| `stage_viewport() -> SubViewport` | L165 |
| `set_stage_visible(value: bool) -> void` | L170 |
| `is_stage_visible() -> bool` | L176 |

## 契约与约束

- 一个宿主同一时间只承载一个舞台；`mount_stage()` 先卸载旧舞台再挂新的。
- `load_stage(path, payload)` 在未进树（`_ready` 前）调用时只缓存 path/payload 并返回 false，由 `_ready` 补加载；场景缺失 / 非 PackedScene / 根不是 `LocationStage` 时发 `fallback_requested(reason)` 并返回 false。
- 挂载顺序固定 `enter(payload)` → `bind(_view_model)`；`stage_id` 取 `LocationStage.stage_id`，为空时回退节点名。
- `bind_view_model()` 深拷贝缓存最新 ViewModel 并转发；之后挂载的舞台会自动收到最近一次 ViewModel。
- `set_stage_visible(false)` 同时隐藏宿主、把 SubViewport 置 `UPDATE_DISABLED`、舞台 `process_mode=DISABLED`；显示时恢复 `UPDATE_WHEN_VISIBLE` / `PROCESS_MODE_INHERIT`。
- `unmount_stage()` 先 `exit()` 再移出并 `free()` 舞台，发 `stage_unmounted(old_id)`。
- `_ready` 设 `clip_contents`、`MOUSE_FILTER_IGNORE`、`PRESET_FULL_RECT` 与 `stretch_shrink=max(1, render_shrink)`；`auto_load` 且有 `stage_scene_path` 时立即加载。
- `_exit_tree()` 对已挂舞台调用 `exit()`，避免离开树后舞台动画继续。

## 重点逻辑

### `_build_host()`

- SubViewport（`own_world_3d=true`、`gui_disable_input=true`、默认 1440×900、初始 `UPDATE_DISABLED`）+ `StageWorld` 根；宿主不持有相机/灯光/水面，它们属于舞台场景。

### `_apply_render_state()`

- active = `_stage_visible and is_inside_tree() and is_visible_in_tree()`；隐藏时停 viewport 更新与舞台 process，符合「同一时间只渲染一个 3D 舞台」。

模块索引：[framework/ui](../README.md)
