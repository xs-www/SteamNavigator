# `framework/ui/stages/port_stage.gd`

> 作用：固定 3/4 长焦港口舞台骨架：`_ready` 一次建静态层（天空/雾/灯光/双层水面/桩基码头/岸线底座/兜底 sky card/相机），`bind()` 只重建 `_content` 下的数据层：L1 banner 背板、L2 确定性岸线剪影（仅无 banner）、L3 设施（`facility_visuals` GLB 或程序化 billboard + 空槽货堆）、L5 玩家船随波。

- 关键依赖：`LocationStage`、`StageKit`、`ContentAssetLoader`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `PortStage` | L1 |
| `enter(payload: Dictionary = {}) -> void` | L169 |
| `exit() -> void` | L175 |
| `bind(view_model: Dictionary = {}) -> void` | L179 |
| `has_visual() -> bool` | L199 |
| `has_backdrop() -> bool` | L203 |
| `loaded_banner_path() -> String` | L208 |
| `facility_count() -> int` | L212 |
| `filler_count() -> int` | L218 |
| `facility_visual_kind(facility: String) -> String` | L224 |
| `facility_anchors() -> Dictionary` | L229 |
| `facility_screen_anchor(facility: String) -> Vector2` | L243 |
| `has_ship() -> bool` | L256 |
| `request_portal(facility: String) -> void` | L261 |
| `hotspot_anchors() -> Dictionary` | L265 |

## 契约与约束

- bind ViewModel 字段全部可选：`port.{id,size,facilities,banner_path,palette,facility_visuals,landmark_path}` 与 `ship.{hull_model_path,hull_tier}`；`facility_visuals` 也可放在根层。
- `bind()` 幂等：先按 `str(port) + str(ship) + str(root facility_visuals)` 计算签名，相同则直接返回；`enter(payload)` 的 payload 仅在 bind 收到不含 port/ship/facility_visuals 的数据时兜底。
- 设施顺序固定 `FACILITY_ORDER`（exchange/contracts/supply/intel/shipyard）；present 的设施才有锚点与热点，缺席只放程序化货堆 filler（`filler_count()`），`facility_visual_kind()` 返回 model/billboard/missing。
- `facility_visuals` 值可为 String 或 Array[String]：能 `ResourceLoader` 加载的按 PackedScene 实例化，否则走 `ContentAssetLoader.instantiate_model()`；路径缺失/实例化失败回退程序化 billboard。
- L1 banner：`port.banner_path` 缺失或贴图加载失败时**不放黑盒**：兜底层由 `SkyCard`（黄昏渐变卡片）+ `ShoreShelf` + L2 剪影组成；贴图加载成功才挂 banner，并隐藏兜底层。`has_backdrop()` / `loaded_banner_path()` 报告实际加载结果。
- L2 岸线：仅在无 banner 时生成 **9 栋剪影 + 2 台吊机**（部分建筑带斜屋顶/烟囱，无发光窗），由 `port.id` 的稳定 hash 派生（`_hash01`，不用 RNG），同一港口每次绑定完全一致。
- `_apply_sky_card_visibility()` 以 `use_fallback = not _has_backdrop` 统一控制 `_sky_card.visible` 与 `_shore_shelf.visible`：banner 自带天空/城市，兜底层必须隐藏，避免渐变卡片或岸线底座压住画好的画面。
- 码头是薄甲板桩基栈桥（不是实心箱体）：甲板前缘下方 7 根入水木桩 + 桩帽、一道纵向横梁（Waler）与甲板边梁；远景岸线底座 500×1.3×110 把镜头内的水面切边藏起来。
- `port.size` ∈ small/medium/large → 设施组整体 0.9/1.0/1.15（`SIZE_SCALE`），只缩放设施层，不缩放船与码头。
- `facility_anchors()` 返回设施 id → 世界坐标；`facility_screen_anchor()` 用舞台相机投影并按 viewport 尺寸归一化到 0..1（缺席或未投影时返回 ZERO）；`hotspot_anchors()` 同 `facility_anchors()`。
- 玩家船：`ship.hull_model_path` 优先，`hull_tier` 只作 dev 回退；船体在 `SHIP_SPAWN` 真尺度摆放，水面泡沫环按包围盒绑定并在 `_process` 做升沉/横摇。
- `request_portal(facility)` 只发 `portal_requested`；`has_visual()` 恒 true（程序化舞台无资产也可绘制）。
- 表现层：不读 GameState / QueryBus / CommandBus；所有资产路径已在 ViewModel 中解析。

## 重点逻辑

### `_ensure_static() / _build_environment()`

- 静态层只建一次：sky 模式黄昏调色 + 深度雾（默认 70–450 m，低于地平线的天空半球镜像暖雾色）+ 暖 key/冷 fill 无阴影；近水 `harbor_water.tres`（600 m）与远水 `harbor_water_far.tres`（2400 m，只输出雾色）；同一 `_ready` 里建桩基码头、岸线底座、SkyCard 与相机。

### `_apply_view_model(port, ship, root_data)`

- 解析 size/scale/palette/visuals/banner 后 `_clear_dynamic()`，按 backdrop → shoreline（无 banner 才建）→ SkyCard/岸线底座可见性 → facilities → landmark → ship 的顺序重建；静态层跨 bind 复用。

### `_rebuild_backdrop()`

- 只有 banner 贴图加载成功才建 `BACKDROP_SIZE`（260×76）的 unshaded quad 并放到 `BACKDROP_POSITION`（-70, 12, -70），albedo tint 成黄昏色调；失败直接返回，绝不创建黑色占位面。

### `_add_sky_card() / _apply_sky_card_visibility()`

- `SkyCard` 是 340×100 的 unshaded quad（`SKY_CARD_POSITION` -135, 25, -56），用 8×256 的 `GradientTexture2D` 画黄昏渐变，遮住远水网格与程序化天空下半球；`visible = not _has_backdrop`，不投阴影。

### `_rebuild_shoreline()`

- `port.id.hash()` 作种子，`_hash01` 生成 9 栋建筑的宽/高/深/偏移（近/远两档蓝灰 tone）；每 3 栋一个斜屋顶、每 4 栋一根烟囱，另加 2 台吊机剪影；有 banner 时首行直接 return，不生成任何剪影。

### `_add_quay()`

- 薄甲板 `DOCK_SIZE`（54×0.6×12）坐在 7 根木桩（x = -24…24 步长 8，含 `PileCap`）上；另有 `DeckEdgeBeam`、纵向 `Waler`、护舷与木饰条，整体读作桩基栈桥。岸线底座 `SHORE_SIZE` 500×1.3×110 放在 `SHORE_CENTER`（0, -0.55, -65），灯柱与系缆桩同在这一步建。

### `_add_camera()`

- 相机固定在 `CAMERA_POS`（46, 28, 64）看向 `CAMERA_TARGET`（0, 12, -8），30° 长焦、near/far 0.5/1200；换港口构图只改常量，不在运行时缩放模型。

### `_rebuild_facilities() / _build_facility_visual()`

- 按 `FACILITY_ORDER` 建锚点组（`_facilities_root` 放在码头顶面 `DOCK_TOP`，局部位置 `SLOT_POSITIONS`）；船厂可挂两件（干船坞 + 龙门吊，`SHIPYARD_PIECE_OFFSETS`）。
- 有 facility_visuals 时逐路径实例化，至少成功一件即返回 `model`；否则走五种程序化 billboard 原型，失败/缺席由 kind 报告。

### `_build_filler()`

- 用 `port.id` 与设施序号派生 2–4 个木箱 + 木桶 + 可选麻袋，只做货堆，不建锚点/热点，也不参与 `facility_anchors()`。

### `_rebuild_ship(ship)`

- 船体在 `SHIP_SPAWN`（-13.5, 0, 9）、`SHIP_YAW_DEG` 20° 真尺度摆放；复用 `_instantiate_visual()`，成功时按 `StageKit.visual_aabb()` 配泡沫环（覆盖 `boat_yaw` / `boat_foam_width`），失败时 `_disable_boat_foam()` 把泡沫环推到不可见处。

模块索引：[framework/ui](../README.md)
