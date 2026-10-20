# `framework/ui/stages/port_stage.gd`

> 作用：固定 3/4 长焦港口舞台，也是一座连续港区：`_ready` 一次建静态层（L0 暖色 sky + 双层水面 + 160 m 桩基码头 + L1 兜底 painted backdrop + L6 前景框 + L7 3 组蒸汽粒子 + 相机），`bind()` 只重建 `_content` 下的数据层：L1 banner 背板、L2 双深度带剪影（仅无 banner 且无 town kit）、L2b 港口街坊 town kit（按 size/density 28/47/63 件）、站前道具（每站 5/8/11 件）、L3 设施、L5 玩家船、L7 雾带；随后把设施 + 街坊 + 站前道具 + 玩家船静态合批。市场 / 港务 / 补给是同一港区里从左到右的三个相邻站位，切换页面只平移镜头并把玩家船开到对应泊位（`focus_station()`），世界不重建。全程序化 + 内容模组 GLB，无外部框架贴图。

- 关键依赖：`LocationStage`、`StageKit`、`ContentAssetLoader`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `PortStage` | L1 |
| `FACILITY_ORDER` | L40 |
| `SIZE_SCALE` | L43 |
| `DOCK_TOP` | L45 |
| `DOCK_SIZE` | L50 |
| `DOCK_CENTER` | L51 |
| `DECK_SIZE` | L52 |
| `SHORE_SIZE` | L58 |
| `SHORE_CENTER` | L59 |
| `SHORE_TOP` | L60 |
| `CAMERA_POS` | L62 |
| `CAMERA_TARGET` | L63 |
| `CAMERA_FOV` | L64 |
| `SHIP_SPAWN` | L69 |
| `SHIP_YAW_DEG` | L70 |
| `SHIP_SCALE` | L71 |
| `BOB_AMPLITUDE` | L72 |
| `BOB_SPEED` | L73 |
| `STATION_ORDER` | L88 |
| `DEFAULT_STATION` | L89 |
| `STATION_FRAMINGS` | L90 |
| `STATIONS` | L91 |
| `PANEL_FRAMING_SHIFT_X` | L118 |
| `CAMERA_PAN_SECONDS` | L121 |
| `SHIP_TRANSIT_SPEED` | L122 |
| `SHIP_TURN_SPEED` | L123 |
| `MODEL_BY_TIER` | L125 |
| `FALLBACK_MODEL` | L130 |
| `SLOT_POSITIONS` | L136 |
| `SHIPYARD_PIECE_OFFSETS` | L145 |
| `SIGN_YAW_DEG` | L147 |
| `SIGN_COLORS` | L148 |
| `SKY_TOP` | L156 |
| `SKY_HORIZON` | L157 |
| `SKY_GROUND_HORIZON` | L160 |
| `SKY_GROUND_BOTTOM` | L161 |
| `FOG_COLOR` | L162 |
| `AMBIENT_COLOR` | L163 |
| `BACKDROP_SIZE` | L167 |
| `BACKDROP_POSITION` | L168 |
| `NEAR_WATER_SIZE` | L169 |
| `FAR_WATER_SIZE` | L170 |
| `SKY_CARD_DEPTH` | L175 |
| `SKY_CARD_SCREEN_CENTER` | L176 |
| `SKY_CARD_SCREEN_SIZE` | L177 |
| `SKYLINE_BUILDINGS_BY_SIZE` | L181 |
| `SKYLINE_CRANES_BY_SIZE` | L182 |
| `DENSITY_BY_SIZE` | L198 |
| `DENSITY_ORDER` | L199 |
| `TOWN_COUNTS` | L200 |
| `TOWN_QUAY_ORDER` | L217 |
| `TOWN_GROUND_Y` | L224 |
| `TOWN_PLAZA_SIZE` | L225 |
| `TOWN_PLAZA_CENTER` | L226 |
| `TOWN_SLOTS` | L234 |
| `TOWN_FENCE_X` | L242 |
| `TOWN_WORKER_SLOTS` | L246 |
| `TOWN_DECOR_SLOTS` | L259 |
| `TOWN_BOAT_SLOTS` | L273 |
| `TOWN_QUAY_SLOTS` | L283 |
| `STATION_PROP_COUNTS` | L335 |
| `STATION_PROPS` | L336 |
| `TOWN_BLOCKOUT_SIZES` | L379 |
| `FOREGROUND_COLOR` | L389 |
| `FOG_BAND_COLOR` | L390 |
| `FOG_BAND_ALPHA` | L391 |
| `ATMOSPHERE_PARTICLE_AMOUNT` | L392 |
| `SKY_GLOW_COLOR` | L393 |
| `MATERIAL_DEFAULTS` | L395 |
| `LANDMARK_POS` | L407 |
| `enter(payload: Dictionary = {}) -> void` | L508 |
| `exit() -> void` | L520 |
| `bind(view_model: Dictionary = {}) -> void` | L524 |
| `has_visual() -> bool` | L545 |
| `has_backdrop() -> bool` | L549 |
| `loaded_banner_path() -> String` | L554 |
| `facility_count() -> int` | L558 |
| `filler_count() -> int` | L564 |
| `facility_visual_kind(facility: String) -> String` | L570 |
| `facility_anchors() -> Dictionary` | L575 |
| `facility_screen_anchor(facility: String) -> Vector2` | L589 |
| `has_ship() -> bool` | L602 |
| `request_portal(facility: String) -> void` | L607 |
| `hotspot_anchors() -> Dictionary` | L611 |
| `foreground_frame() -> Node3D` | L618 |
| `atmosphere_particle_systems() -> int` | L623 |
| `atmosphere_layers() -> int` | L628 |
| `skyline_building_count() -> int` | L633 |
| `skyline_crane_count() -> int` | L638 |
| `town_prop_count() -> int` | L644 |
| `town_blockout_count() -> int` | L650 |
| `town_density() -> String` | L657 |
| `painted_backdrop_layer_count() -> int` | L664 |
| `batch_stats() -> Dictionary` | L682 |
| `ship_foam_bounds() -> AABB` | L705 |
| `ship_visual_is_rigid(visual: Node) -> bool` | L714 |
| `station_ids() -> Array[String]` | L767 |
| `current_station() -> String` | L774 |
| `current_station_framing() -> String` | L778 |
| `station_camera_pose(station_id: String, framing: String = "stage") -> Dictionary` | L784 |
| `station_ship_position(station_id: String) -> Vector3` | L797 |
| `station_ship_yaw(station_id: String) -> float` | L802 |
| `focus_station(station_id: String, framing: String = "stage", immediate: bool = false) -> bool` | L811 |
| `is_station_transitioning() -> bool` | L859 |
| `camera_position() -> Vector3` | L865 |
| `camera_target() -> Vector3` | L869 |
| `ship_x() -> float` | L874 |
| `station_ship_mooring_x() -> float` | L878 |
| `station_prop_count() -> int` | L884 |
| `camera_shift_x() -> float` | L889 |
| `advance_station(delta: float) -> void` | L897 |

## 契约与约束

- bind ViewModel 字段全部可选：`port.{id,size,facilities,banner_path,palette,facility_visuals,town_visuals,landmark_path}` 与 `ship.{hull_model_path,hull_tier}`；`facility_visuals` / `town_visuals` 也可放在根层。
- `bind()` 幂等：先按 `str(port) + str(ship) + str(root facility_visuals) + str(root town_visuals)` 计算签名，相同则直接返回；`enter(payload)` 的 payload 仅在 bind 收到不含 port/ship/facility_visuals/town_visuals 的数据时兜底。
- 设施顺序固定 `FACILITY_ORDER`（exchange/contracts/supply/intel/shipyard）；present 的设施才有锚点与热点，缺席只放程序化货堆 filler（`filler_count()`），`facility_visual_kind()` 返回 model/billboard/missing。
- `facility_visuals` 值可为 String 或 Array[String]：能 `ResourceLoader` 加载的按 PackedScene 实例化，否则走 `ContentAssetLoader.instantiate_model()`；路径缺失/实例化失败回退程序化 billboard。
- L1：有 `banner_path` 且贴图可加载时挂 banner 背板（albedo tint 黄昏化）并隐藏兜底层；无 banner 时 `has_backdrop()` 仍为 false，由 `FallbackBackdrop` 接管——暖霞渐变 `SkyCard` + 2 个 additive 太阳光晕，共 3 层程序化 painted backdrop，无黑盒、无外部贴图。
- L2（仅无 banner）：双深度带（近带深蓝灰 / 远带暖雾）各 2 簇 + 低矮仓房连接排 + 远岸低雾带 + 灯塔剪影；MultiMesh 批量（box / 塔身 / 塔冠 3 draw），严格站 `SHORE_TOP`、unshaded、无阴影、无发光窗；建筑数 small 7 / medium 10 / large 13、吊机 2 / 2 / 3，`skyline_building_count()` / `skyline_crane_count()` 报告实际数量（有 banner 时均为 0）。
- L2 实例总数 small 14 / medium 17 / large 20（建筑 + 吊机 + 仓房排/雾带/灯塔），仍在方案 L2 ≤20 预算内；small 的 7 栋低于任务描述的 8 下界，以源码为准。
- L2b 港口街景：`port.town_visuals`（slot → 已解析 GLB 路径）存在时在码头后方的抬升石广场（`TOWN_GROUND_Y=1.9`、`TOWN_PLAZA` 250×2.2×34）上装配建筑/围栏/工人/广场装饰/小船 + 码头工业件；密度由 `port.density` → `port.diorama.density` → `port.size` 推导（small→sparse、medium→normal、large→busy），每组按 tier 取前缀，`port.id.hash()` 只给自由摆放件加确定性 yaw 抖动（无全局 RNG）。normal = 5 建筑 + 7 围栏 + 7 工人 + 8 装饰 + 3 船 + 17 码头工业件 = **47 props**（sparse 28 / busy 63）。建筑缺失 GLB 时回退程序化 blockout，围栏/工人/船/装饰缺失则直接省略。
- town kit 存在时跳过 L2 程序化 skyline（`if _town_visuals.is_empty(): _rebuild_shoreline()`），因为街区已有近景轮廓；town 与 banner 相互独立（有 banner 也可有 town）。
- 连续港区与相邻站位：`STATION_ORDER = [market, harbor, supply]`（世界 X 从左到右），`STATIONS` 定义每个站位的 `center`、`camera`/`target`（同一 30° 长焦）、`ship` 泊位与 `ship_yaw`；码头甲板/木桩/系缆桩/煤气灯沿 160 m 连续铺开，`exchange` 与 `supply` 设施分别落在 -30 / +30 的站位上（contracts/intel/shipyard 仍集中在中心港务段）。
- `focus_station(station, framing, immediate)` 只重定向镜头与泊位，港口、街坊、设施、水面与合批层都不重建；`framing` = `stage`（全窗总览）或 `panel`（右侧 640 px 泊位面板，镜头整体右移 `PANEL_FRAMING_SHIFT_X=3 m`，让站位落在可见左半屏）。重复聚焦当前站位是 no-op，整页重建不会重启动画；`immediate` 只用于舞台首次挂载。
- 站位切换演出：镜头在 `CAMERA_PAN_SECONDS=0.6 s` 内平滑 pan；玩家船先转艏向沿岸方向，再以 `SHIP_TRANSIT_SPEED=24 m/s` 驶到新泊位并转回 `ship_yaw`，泡沫环 `boat_center` 随船移动。`advance_station(delta)` 以 50 ms 切片推进整段过渡（`_process` 每帧调用；测试/截图工具可直接步进，无需真实帧）；`is_station_transitioning()` 报告过渡是否结束。
- 镜头平移时的画幅层：`_apply_camera_shift()` 把相机朝向层（sky card/太阳光晕、painted backdrop、banner 背板、L6 前景框、雾带）按 `camera_shift_x` 平移保持构图，L2 剪影只平移一半保留视差；码头/街坊/设施/水面/船体是世界几何，随镜头真正移动。
- 站前道具：`STATION_PROPS`（每个站位一条有序列表）按密度 tier 取前缀（sparse/normal/busy = 每站 5/8/11 件），全部复用官方 town kit 已解析路径（`port.town_visuals`），缺失 GLB 直接省略；`station_prop_count()` 与 town kit 的 `town_prop_count()` 分开计数。
- 静态合批：`_batch_static_meshes()` 在 town/facilities 重建后、玩家船之前，把两棵静态根按材质折叠——BoxMesh 共享单位立方体走 MultiMeshInstance3D（每材质 1 batch），其余 static mesh 按材质签名烘焙成每材质 1 个 ArrayMesh；透明/ShaderMaterial/`material_overlay`/非三角面/带法线贴图材质安全跳过。玩家船在泡沫 AABB 计算后按 `_ship_root` 局部空间刚性合批（`_batch_ship_visual()`），带 AnimationPlayer/Skeleton/粒子/透明/法线贴图的船体整船回退保留原 GLB。
- `_apply_fallback_visibility()` 以 `use_fallback = not _has_backdrop` 统一控制 `FallbackBackdrop`、`ShoreShelf` 与 `ShoreSteam`：banner 自带天空/城市，兜底层必须整体隐藏；L2 剪影也只在无 banner 时生成。
- 只读访问器：`foreground_frame()`、`atmosphere_particle_systems()`（1..3，当前固定 3）、`atmosphere_layers()`（有 banner 2 / 无 banner 3）、`skyline_building_count()`（无 banner 7/10/13，有 banner 0）、`skyline_crane_count()`（2/2/3）、`town_prop_count()`（按 density 28/47/63，无 town 时为 0）、`town_blockout_count()`、`town_density()`、`painted_backdrop_layer_count()`（无 banner 3 / 有 banner 0）、`batch_stats()`（facilities/town 与 ship 的 batches、mesh/surface 前后计数、`ship_fallback`）、`ship_foam_bounds()`（批处理前捕获的船体 AABB）；`has_backdrop()` 语义仍只表示 banner。站位查询：`station_ids()`、`current_station()`、`current_station_framing()`、`station_camera_pose(id, framing)`、`station_ship_position(id)`、`station_ship_yaw(id)`、`is_station_transitioning()`、`camera_position()`、`camera_target()`、`camera_shift_x()`、`ship_x()`、`station_ship_mooring_x()`、`station_prop_count()`。
- L6 `foreground_frame()` 始终存在：3 根深色 unshaded 梁（吊臂 0.30 / 钢缆 0.12 / 桅杆 0.18 m）从左上角入镜，用 `_screen_point(u, v, depth)` 钉在固定 16:9 画幅；限定 u<0.24 / v<0.45，不遮挡 HUD、设施招牌与热点标签，不投阴影。
- L7 大气：常驻 3 个 `GPUParticles3D`（ShipSteam / QuaySteam / ShoreSteam，16–22 粒、3.4–4.6 s、低 alpha 暖灰 + 程序化 radial `GradientTexture2D`）；雾带 billboard 有 banner 2 层 / 无 banner 3 层，`port.id` hash 决定正弦漂移相位；宿主 `process_mode` 停更时粒子与雾带一起停。
- 预算目标 ≤120 draws / ≤60k tris；窗口实测（`tools/godot/measure_port_stage.gd`，含已合并玩家船）preview **63 draws / 47,604 tris**、sparse **56 / 38,150**、market **57 / 47,604**、harbor **63 / 47,604**、supply **61 / 47,604**（三站位均 ≤120 / ≤60k）。`batch_stats()` 报告批处理前后 mesh/surface 计数。官方内容目前只有铁港一张 banner，其余港口走 painted backdrop。
- 码头是薄甲板桩基栈桥（不是实心箱体）：160 m 连续甲板（`DOCK_SIZE` 160×0.6×12）+ 19 根入水木桩 + 桩帽、纵向横梁与甲板边梁，系缆桩每 12 m 一组、煤气灯沿前景 7 根；远景岸线底座 500×1.3×110 把镜头内的水面切边藏起来。
- `port.size` ∈ small/medium/large → 设施组整体 0.9/1.0/1.15（`SIZE_SCALE`），只缩放设施层，不缩放船与码头。
- `facility_anchors()` 返回设施 id → 世界坐标；`facility_screen_anchor()` 用舞台相机投影并按 viewport 尺寸归一化到 0..1（缺席或未投影时返回 ZERO）；`hotspot_anchors()` 同 `facility_anchors()`。
- 玩家船：`ship.hull_model_path` 优先，`hull_tier` 只作 dev 回退；船体在 `SHIP_SPAWN` 真尺度摆放，水面泡沫环按包围盒绑定并在 `_process` 做升沉/横摇。
- `request_portal(facility)` 只发 `portal_requested`；`has_visual()` 恒 true（程序化舞台无资产也可绘制）。
- 表现层：不读 GameState / QueryBus / CommandBus；所有资产路径已在 ViewModel 中解析。

## 重点逻辑

### `_ensure_static() / _build_environment()`

- 静态层只建一次，顺序：材质 → 环境 → L1 兜底 → 双层水面 → 桩基码头 → 相机 → L6 前景框 → L7 粒子。环境为 sky 模式黄昏调色 + 深度雾 70–450 m + 环境光 0.6 + 暖 key(1.7)/冷 fill(0.5) 无阴影；`ProceduralSkyMaterial` 调 `sky_energy_multiplier=1.12`、`sun_angle_max=18`、`sun_curve=0.22`，让程序化天空与兜底 painted sky 同属一个暖色 grade。

### `_apply_view_model(port, ship, root_data)`

- 解析 size/scale/palette/visuals/town_visuals/banner 后 `_clear_dynamic()`，按 backdrop → shoreline（仅 `_town_visuals` 为空且无 banner 才建）→ `_apply_fallback_visibility()` → `_rebuild_fog_layers()` → `_rebuild_town()` → facilities → landmark → `_batch_static_meshes()` → ship 的顺序重建；静态层与 L7 粒子跨 bind 复用。

### `_add_fallback_backdrop() / _add_sky_glow() / _add_painted_backdrop_layers()`

- `FallbackBackdrop` 在 `_ready` 建一次：8×256 `GradientTexture2D` 暖霞 SkyCard（`SKY_CARD_SIZE` 340×100）+ `SunHalo`（90 m，alpha 0.12）+ `SunCore`（18 m，alpha 0.62）；太阳位置由 `_screen_point(0.70, 0.10, 118)` 钉在画幅右上。SkyCard 现改为固定 260 m 深度的 camera-facing quad，避免旧斜置 quad 在右侧近处遮断远景。
- 光晕是 additive、camera-facing quad；radial 纹理只用到 72% UV 半径（fill_to 0.86），四边始终透明。有 banner 时整组 `visible=false`；无 banner 时再叠加 3 层低对比 unshaded 剪影（山脊 / 远城塔楼 / 港口屋脊+烟囱），合并为 1 个 MultiMesh（vertex color），`painted_backdrop_layer_count()` 报告 3。

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

- 码头/系缆桩/煤气灯等重复件全部走 MultiMesh（`DockPlatform`、`DockDeck`、`DockWood`、`DockPiles`、`Bollards`、`BollardCaps`、`LampPoles`、`LampGlow`、`LampCaps`）：薄甲板 `DOCK_SIZE` 160×0.6×12 + 19 根木桩（含桩帽）+ 横梁/护舷，岸线底座 `SHORE_SIZE` 500×1.3×110 放 `SHORE_CENTER`（0, -0.55, -65）。

### `_add_camera()`

- 相机固定在当前站位的 `STATIONS[station].camera` 看向 `target`（三站位共用 30° 长焦、near/far 0.5/1200）；`_add_camera()` 用 `_station`/`_station_framing` 取初始 pose（默认 harbor/stage），并立即 `_apply_camera_shift()`。换构图只改站位常量，不在运行时缩放模型。

### `_focus_station(station_id, framing, immediate) / advance_station(delta) / _advance_camera() / _advance_ship()`

- `focus_station()` 校验站位与 framing（非法 framing 回退 stage），记录 `_station`/`_station_framing`，把 `_ship_moor_x/_ship_moor_z/_ship_moor_yaw` 指向该泊位；`immediate` 时把 `_camera_from/_camera_to` 都设为目标并同步 `_camera`/`_ship_x`/`_ship_yaw`，否则从当前 pose 起调，`_camera_t=0`（重复聚焦当前站位直接返回，不重启动画）。
- `advance_station(delta)` 把 delta 切成 ≤50 ms 的步进（`_process` 每帧调用；测试/工具可直接步进整段）；过渡中再次 `focus_station()` 会以*当前相机位姿*为新起点续 pan（不瞬跳回旧目标）：`_advance_camera()` 用 `smoothstep` 在 `CAMERA_PAN_SECONDS` 内插值 position/target/fov 并 `_apply_camera_shift()`；`_advance_ship()` 先 `rotate_toward` 把艏向转到沿岸方向（目标方位 0 或 π），再按 `SHIP_TRANSIT_SPEED*对齐度` `move_toward` 泊位 X，到泊位后转回 `_ship_moor_yaw`，每步更新 `_apply_ship_pose()`（升沉、横摇、蒸汽跟随、泡沫）。

### `_apply_camera_shift() / _sync_boat_foam() / _rebuild_station_dressing()`

- `_apply_camera_shift()`：`_camera_shift_x = _camera_target.x - CAMERA_TARGET.x`，据此平移 `FallbackBackdrop`（天空/光晕/painted layers）、`ForegroundFrame`、banner `Backdrop`（`BACKDROP_POSITION.x + shift`）与 `Shoreline`（×0.5 视差）；雾带在 `_process` 里把 shift 加到基准位置，保证镜头平移时画幅层不跑出构图。
- `_sync_boat_foam()`：用 `_ship_bounds_offset`（船体本地 AABB 中心，在泊位重建时捕获）+ `_ship_x`/`_ship_moor_z` 重算 `boat_center`，并写 `boat_yaw`，让泡沫环跟着船在站位间移动，而不是留在旧泊位。
- `_rebuild_station_dressing()`：按 `_station_prop_count_for_density()`（sparse/normal/busy = 每站 5/8/11）遍历 `STATION_ORDER`，把 `STATION_PROPS[station]` 前缀挂进 `_town_root`（`station=true`）；缺失 visual 的槽直接跳过，不生成占位盒。

### `_rebuild_facilities() / _build_facility_visual()`

- 按 `FACILITY_ORDER` 建锚点组（`_facilities_root` 放在码头顶面 `DOCK_TOP`，局部位置 `SLOT_POSITIONS`）；船厂可挂两件（干船坞 + 龙门吊，`SHIPYARD_PIECE_OFFSETS`）。
- 有 facility_visuals 时逐路径实例化，至少成功一件即返回 `model`；否则走五种程序化 billboard 原型，失败/缺席由 kind 报告。

### `_build_filler()`

- 用 `port.id` 与设施序号派生 2–4 个木箱 + 木桶 + 可选麻袋，只做货堆，不建锚点/热点，也不参与 `facility_anchors()`。

### `_rebuild_ship(ship)`

- 船体按当前站位泊位（`_ship_moor_x/_ship_moor_z`）与 `ship_yaw` 20° 真尺度摆放；重绑（货舱/船体变化）时新船直接建在玩家当前站位，不会瞬移回港务参考位。成功时先按 `StageKit.visual_aabb()` 配泡沫环（覆盖 `boat_yaw` / `boat_foam_width`）并保存 `ship_foam_bounds()` 与本地 AABB 偏移，随后 `_batch_ship_visual()` 把船体按 `_ship_root` 局部空间刚性合批（`ShipBatches` 挂在船下，站位航行/升沉/摇摆仍作用于整船）；最后 `_sync_boat_foam()` 把泡沫对齐到泊位。失败时 `_disable_boat_foam()` 把泡沫环推到不可见处。

### `_rebuild_town() / _resolve_town_density() / _add_town_prop() / _build_town_blockout()`

- `_rebuild_town()` 在 `_content` 下建 `HarborTown`：抬升广场 `TOWN_PLAZA_SIZE` 250×2.2×34（`plaza` 调色板材质）+ MultiMesh 铺装线（31 条，覆盖 -120..120）+ 广场边梁；随后按 `DENSITY_BY_SIZE` / `port.diorama.density` 解析 `_town_density`，依次装配建筑（固定 5 座）、`TOWN_FENCE_X` 前缀、`TOWN_WORKER_SLOTS` 前缀、`TOWN_DECOR_SLOTS` 前缀、`TOWN_BOAT_SLOTS` 前缀，以及 `TOWN_QUAY_ORDER` + `TOWN_QUAY_SLOTS` 的工业件（市场摊/吊车/麻袋堆/钢板堆/矿堆/托盘/跳板/系缆桩/绞盘/浮标），最后 `_rebuild_station_dressing()`。
- `_add_town_prop(slot, pos, yaw, scale, blockout_fallback, station = false)`：从 `_town_visuals[slot]` 取已解析路径并 `_instantiate_visual()`；建筑槽（blockout_fallback=true）失败时用 `_build_town_blockout()` 生成 box 体 + 双坡屋顶 + 窗/门节奏并计入 `_town_blockout_count`，其余槽失败直接跳过。每个 prop 包在带 yaw/scale 的 holder 下；`station=true` 的站前道具计入 `_station_prop_count`（节点名 `Station_*`），其余计入 `_town_prop_count`（`Town_*`）；`_town_jitter_yaw()` 只对自由摆放件加确定性抖动。

### `_batch_static_meshes() / _batch_into() / _batch_ship_visual() / ship_visual_is_rigid()`

- `_batch_into(container, candidates, space_inverse, prefix)` 是共享合批实现：BoxMesh 用共享单位立方体 + 每实例 scale 生成每材质 MultiMeshInstance3D；其它 static mesh 把顶点/法线/UV/Color 按 `space_inverse` 烘焙到目标空间、按材质签名分组生成每材质 1 个 ArrayMesh，索引按 base_index 偏移；custom AABB 防裁剪。
- `_batch_static_meshes()` 依次批 `_facilities_root` 与 `_town_root`（139→34 mesh / 238→34 surfaces，33 batches），再 `_recount` 写 `_batch_meshes_before/after`、`_batch_surfaces_before/after`。
- `_batch_ship_visual()` 用 `_ship_root` 的全局逆变换烘焙船体，32→9 mesh / 90→9 surfaces；`ship_visual_is_rigid()` 在出现 AnimationPlayer/AnimationTree、Skeleton/Bone、GPU/CPU 粒子、MultiMesh、Skin/BlendShape、透明/ShaderMaterial/overlay、非三角面或 normal map 时返回 false，整船保留原 GLB 并置 `ship_fallback=true`。

### `_screen_point(u, v, depth) / _screen_units(...)`

- 用固定 FOV 与 16:9（1440/900）把归一化屏幕坐标换算成沿相机前向 `depth` 米处的世界点，供 SunHalo/SunCore、L6 前景框与 L7 雾带共用；换机位或窗口比例时这三层随画幅一起重算。

模块索引：[framework/ui](../README.md)
