# `framework/ui/components/sn_ship_stage_3d.gd`

> 作用：船厂正常态的真实 3D 船体舞台（2.5D 首个切片）：SubViewport 渲染固定 3/4 机位的船体、海面与灯光；2D 槽位、拖拽与 HUD 仍由 SNShipView 和页面负责。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNShipStage3D` | L1 |
| `has_ship() -> bool` | L61 |
| `model_path() -> String` | L65 |
| `ship_view_update(model: Dictionary) -> void` | L71 |
| `ship_view_set_mode(mode: int) -> void` | L77 |
| `ship_view_highlight(_slot_ids: Array) -> void` | L83 |
| `set_mode_visible(visible_stage: bool) -> void` | L90 |

## 契约与约束

- 通过既有 `SNShipView.set_renderer()` 协议接入：实现 `ship_view_update(model)` / `ship_view_set_mode(mode)` / `ship_view_highlight(ids)`。
- 按 `model.hull_tier` 选择 `assets/models/ships/*.glb`，取模型网格包围盒动态计算机位距离与目标点，让 24 m 明轮船与 60 m 铁甲舰保持同一构图。
- EXTERIOR 显示 3D 视口；CUTAWAY 隐藏视口，让纵剖图贴图与槽位贴片接管，不改页面布局。
- 复用 `assets/materials/water/harbor_water.tres`（duplicate 后把 shore 参数推远、boat 泡沫环绑到当前船体包围盒、调整水平线淡出）；材质缺失时退回 StandardMaterial。
- `is_supported()` 静态判断是否存在可用船体 GLB；页面对 false 不挂空视口、保留 SNShipView 程序化占位，导出包与 CI 不依赖新资产。
- 只做表现层：不读 GameState / QueryBus / CommandBus；渲染器方法在 `_ready` 之前被调用时先缓存 model/mode，`_ready` 后统一应用。

## 重点逻辑

### `_build_stage()`

- SubViewportContainer(stretch) + SubViewport(own_world_3d, transparent_bg=false) + 独立 World3D；一个页面同一时间只存在这一个 3D 视口。
- 环境为 BG_COLOR + 环境光 + 线性雾，灯光只用一个主光一个补光且关闭实时阴影，保证 1440×900 下的静态舞台开销可控。

### `_frame_camera(visual)`

- 遍历 MeshInstance3D 累积世界包围盒（8 角点变换），半径 × 长焦 FOV 求距离，再沿固定 3/4 方向摆放相机并 look_at 包围盒中心。
- 船体尺寸变化只改相机，不缩放模型，避免材质/噪声随缩放变形。

模块索引：[framework/ui](../README.md)
