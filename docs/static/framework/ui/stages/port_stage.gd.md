# `framework/ui/stages/port_stage.gd`

> 作用：固定 3/4 长焦港口舞台：`_ready` 一次建静态层（L0 暖色 sky + 双层水面 + 桩基码头 + L1 兜底 painted backdrop + L6 前景框 + L7 3 组蒸汽粒子 + 相机），`bind()` 只重建 `_content` 下的数据层：L1 banner 背板、L2 双深度带剪影（仅无 banner）、L3 设施、L5 玩家船、L7 雾带；全程序化、无外部新贴图。

- 关键依赖：`LocationStage`、`StageKit`、`ContentAssetLoader`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `PortStage` | L1 |
| `enter(payload: Dictionary = {}) -> void` | L192 |
| `exit() -> void` | L198 |
| `bind(view_model: Dictionary = {}) -> void` | L202 |
| `has_visual() -> bool` | L222 |
| `has_backdrop() -> bool` | L226 |
| `loaded_banner_path() -> String` | L231 |
| `facility_count() -> int` | L235 |
| `filler_count() -> int` | L241 |
| `facility_visual_kind(facility: String) -> String` | L247 |
| `facility_anchors() -> Dictionary` | L252 |
| `facility_screen_anchor(facility: String) -> Vector2` | L266 |
| `has_ship() -> bool` | L279 |
| `request_portal(facility: String) -> void` | L284 |
| `hotspot_anchors() -> Dictionary` | L288 |
| `foreground_frame() -> Node3D` | L295 |
| `atmosphere_particle_systems() -> int` | L300 |
| `atmosphere_layers() -> int` | L305 |
| `skyline_building_count() -> int` | L310 |
| `skyline_crane_count() -> int` | L315 |

## 契约与约束

- bind ViewModel 字段全部可选：`port.{id,size,facilities,banner_path,palette,facility_visuals,landmark_path}` 与 `ship.{hull_model_path,hull_tier}`；`facility_visuals` 也可放在根层。
- `bind()` 幂等：先按 `str(port) + str(ship) + str(root facility_visuals)` 计算签名，相同则直接返回；`enter(payload)` 的 payload 仅在 bind 收到不含 port/ship/facility_visuals 的数据时兜底。
- 设施顺序固定 `FACILITY_ORDER`（exchange/contracts/supply/intel/shipyard）；present 的设施才有锚点与热点，缺席只放程序化货堆 filler（`filler_count()`），`facility_visual_kind()` 返回 model/billboard/missing。
- `facility_visuals` 值可为 String 或 Array[String]：能 `ResourceLoader` 加载的按 PackedScene 实例化，否则走 `ContentAssetLoader.instantiate_model()`；路径缺失/实例化失败回退程序化 billboard。
- L1：有 `banner_path` 且贴图可加载时挂 banner 背板（albedo tint 黄昏化）并隐藏兜底层；无 banner 时 `has_backdrop()` 仍为 false，由 `FallbackBackdrop` 接管——暖霞渐变 `SkyCard` + 2 个 additive 太阳光晕，共 3 层程序化 painted backdrop，无黑盒、无外部贴图。
- L2（仅无 banner）：双深度带（近带深蓝灰 / 远带暖雾）各 2 簇 + 低矮仓房连接排 + 远岸低雾带 + 灯塔剪影；MultiMesh 批量（box / 塔身 / 塔冠 3 draw），严格站 `SHORE_TOP`、unshaded、无阴影、无发光窗；建筑数 small 7 / medium 10 / large 13、吊机 2 / 2 / 3，`skyline_building_count()` / `skyline_crane_count()` 报告实际数量（有 banner 时均为 0）。
- L2 实例总数 small 14 / medium 17 / large 20（建筑 + 吊机 + 仓房排/雾带/灯塔），仍在方案 L2 ≤20 预算内；small 的 7 栋低于任务描述的 8 下界，以源码为准。
- `_apply_fallback_visibility()` 以 `use_fallback = not _has_backdrop` 统一控制 `FallbackBackdrop`、`ShoreShelf` 与 `ShoreSteam`：banner 自带天空/城市，兜底层必须整体隐藏；L2 剪影也只在无 banner 时生成。
- L6 `foreground_frame()` 始终存在：3 根深色 unshaded 梁（吊臂 0.30 / 钢缆 0.12 / 桅杆 0.18 m）从左上角入镜，用 `_screen_point(u, v, depth)` 钉在固定 16:9 画幅；限定 u<0.24 / v<0.45，不遮挡 HUD、设施招牌与热点标签，不投阴影。
- L7 大气：常驻 3 个 `GPUParticles3D`（ShipSteam / QuaySteam / ShoreSteam，16–22 粒、3.4–4.6 s、低 alpha 暖灰 + 程序化 radial `GradientTexture2D`）；雾带 billboard 有 banner 2 层 / 无 banner 3 层，`port.id` hash 决定正弦漂移相位；宿主 `process_mode` 停更时粒子与雾带一起停。
- 预算：全程序化、无新资产；preview ≈114 draws / 17,954 tris，sparse ≈73 / 19,228，控制在 ≤120 draws / ≤60k tris。官方内容目前只有铁港一张 banner，其余港口走 painted backdrop（L2 是常规路径而非罕见回退）。
- 只读访问器：`foreground_frame()`、`atmosphere_particle_systems()`（1..3，当前固定 3）、`atmosphere_layers()`（有 banner 2 / 无 banner 3）、`skyline_building_count()`（无 banner 7/10/13，有 banner 0）、`skyline_crane_count()`（2/2/3）；`has_backdrop()` 语义仍只表示 banner。
- 码头是薄甲板桩基栈桥（不是实心箱体）：甲板前缘下方 7 根入水木桩 + 桩帽、纵向横梁与甲板边梁；远景岸线底座 500×1.3×110 把镜头内的水面切边藏起来。
- `port.size` ∈ small/medium/large → 设施组整体 0.9/1.0/1.15（`SIZE_SCALE`），只缩放设施层，不缩放船与码头。
- `facility_anchors()` 返回设施 id → 世界坐标；`facility_screen_anchor()` 用舞台相机投影并按 viewport 尺寸归一化到 0..1（缺席或未投影时返回 ZERO）；`hotspot_anchors()` 同 `facility_anchors()`。
- 玩家船：`ship.hull_model_path` 优先，`hull_tier` 只作 dev 回退；船体在 `SHIP_SPAWN` 真尺度摆放，水面泡沫环按包围盒绑定并在 `_process` 做升沉/横摇。
- `request_portal(facility)` 只发 `portal_requested`；`has_visual()` 恒 true（程序化舞台无资产也可绘制）。
- 表现层：不读 GameState / QueryBus / CommandBus；所有资产路径已在 ViewModel 中解析。

## 重点逻辑

### `_ensure_static() / _build_environment()`

- 静态层只建一次，顺序：材质 → 环境 → L1 兜底 → 双层水面 → 桩基码头 → 相机 → L6 前景框 → L7 粒子。环境为 sky 模式黄昏调色 + 深度雾 70–450 m + 环境光 0.6 + 暖 key(1.7)/冷 fill(0.5) 无阴影；`ProceduralSkyMaterial` 调 `sky_energy_multiplier=1.12`、`sun_angle_max=18`、`sun_curve=0.22`，让程序化天空与兜底 painted sky 同属一个暖色 grade。

### `_apply_view_model(port, ship, root_data)`

- 解析 size/scale/palette/visuals/banner 后 `_clear_dynamic()`，按 backdrop → shoreline（无 banner 才建）→ `_apply_fallback_visibility()` → `_rebuild_fog_layers()` → facilities → landmark → ship 的顺序重建；静态层与 L7 粒子跨 bind 复用。

### `_add_fallback_backdrop() / _add_sky_glow()`

- `FallbackBackdrop` 在 `_ready` 建一次：8×256 `GradientTexture2D` 暖霞 SkyCard（`SKY_CARD_SIZE` 340×100）+ `SunHalo`（90 m，alpha 0.12）+ `SunCore`（18 m，alpha 0.62）；太阳位置由 `_screen_point(0.70, 0.10, 118)` 钉在画幅右上。
- 光晕是 additive、camera-facing quad；radial 纹理只用到 72% UV 半径（fill_to 0.86），四边始终透明。有 banner 时整组 `visible=false`；无 banner 时与 L2 剪影、雾带组成 3 层 painted backdrop，避免地平线硬边。

### `_rebuild_backdrop()`

- 只有 banner 贴图加载成功才建 `BACKDROP_SIZE`（260×76）的 unshaded quad 放到 `BACKDROP_POSITION`（-70, 12, -70），albedo tint（0.72, 0.68, 0.64）成黄昏色调；失败直接返回，绝不创建黑色占位面。

### `_rebuild_shoreline()`

- 有 banner 时首行 return。无 banner 时 `port.id.hash()` 作种子、`_hash01` 生成双深度带：约 55% 近带（深蓝灰、2 簇、仓房/屋顶/烟囱）+ 45% 远带（暖雾色、2 簇）+ 2 条低矮仓房连接排 + 2–3 条远岸低雾带 + 1–2 座灯塔。所有 box 追加到 3 个 MultiMesh（`SkylineBoxes` / `SkylineLighthouseBodies` / `SkylineLighthouseCaps`，vertex color + custom AABB），整层 3 draw、unshaded、无阴影、无发光窗；实例总数 small 14 / medium 17 / large 20（≤20 方案预算）。

### `_rebuild_fog_layers()`

- `FogBands` 为 bind 时重建：有 banner 2 条（u 0.50/0.72、v 0.76/0.86），无 banner 追加 1 条远景地平线雾带（u 0.50、v 0.44、depth 135）；每条是 radial alpha 的 camera-facing quad，`port.id` hash 决定漂移相位；`_process` 用 `sin(t*0.055+phase)*5 m` 缓慢横移，`_fog_layer_count` 递增。

### `_add_foreground_frame()`

- `ForegroundFrame` 在 `_ready` 建一次：`_add_beam()` 生成吊臂（0.30 m）/钢缆（0.12 m）/桅杆（0.18 m）3 根细构件，两端由 `_screen_point()` 的 u/v/depth 定位；材质 unshaded + 0.45 emission 暖轮廓，无阴影；位置限制在左上角（u<0.24 / v<0.45），不遮 HUD 与热点。

### `_add_atmosphere() / _add_particle_system()`

- 3 个 GPUParticles3D 固定一次：ShipSteam（22 粒 / 4.2 s）、QuaySteam（16 / 3.4 s）、ShoreSteam（18 / 4.6 s，跟随无 banner 显隐）；ParticleProcessMaterial 球形发射、向上初速、轻重力；材质为 unshaded + billboard particles + 程序化 radial puff 贴图。

### `_add_quay()`

- 码头/系缆桩/煤气灯等重复件全部走 MultiMesh（`DockPlatform`、`DockDeck`、`DockWood`、`DockPiles`、`Bollards`、`BollardCaps`、`LampPoles`、`LampGlow`、`LampCaps`）：薄甲板 `DOCK_SIZE` 54×0.6×12 + 7 根木桩（含桩帽）+ 横梁/护舷，岸线底座 `SHORE_SIZE` 500×1.3×110 放 `SHORE_CENTER`（0, -0.55, -65）。

### `_add_camera()`

- 相机固定在 `CAMERA_POS`（46, 28, 64）看向 `CAMERA_TARGET`（0, 12, -8），30° 长焦、near/far 0.5/1200；换构图只改常量，不在运行时缩放模型。

### `_rebuild_facilities() / _build_facility_visual()`

- 按 `FACILITY_ORDER` 建锚点组（`_facilities_root` 放在码头顶面 `DOCK_TOP`，局部位置 `SLOT_POSITIONS`）；船厂可挂两件（干船坞 + 龙门吊，`SHIPYARD_PIECE_OFFSETS`）。
- 有 facility_visuals 时逐路径实例化，至少成功一件即返回 `model`；否则走五种程序化 billboard 原型，失败/缺席由 kind 报告。

### `_build_filler()`

- 用 `port.id` 与设施序号派生 2–4 个木箱 + 木桶 + 可选麻袋，只做货堆，不建锚点/热点，也不参与 `facility_anchors()`。

### `_rebuild_ship(ship)`

- 船体在 `SHIP_SPAWN`（-13.5, 0, 9）、`SHIP_YAW_DEG` 20° 真尺度摆放；复用 `_instantiate_visual()`，成功时按 `StageKit.visual_aabb()` 配泡沫环（覆盖 `boat_yaw` / `boat_foam_width`），失败时 `_disable_boat_foam()` 把泡沫环推到不可见处。

### `_screen_point(u, v, depth) / _screen_units(...)`

- 用固定 FOV 与 16:9（1440/900）把归一化屏幕坐标换算成沿相机前向 `depth` 米处的世界点，供 SunHalo/SunCore、L6 前景框与 L7 雾带共用；换机位或窗口比例时这三层随画幅一起重算。

模块索引：[framework/ui](../README.md)
