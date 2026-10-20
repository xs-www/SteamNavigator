# `framework/ui/stages/stage_kit.gd`

> 作用：固定机位 2.5D 舞台的公共构建器：程序化天空/颜色环境、无阴影方向光、近/远水面材质、船体泡沫环、世界空间 AABB 与长焦取景。

- 关键依赖：`assets/materials/water/harbor_water.tres`、`assets/materials/water/harbor_water_far.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `StageKit` | L1 |
| `WATER_MATERIAL` | L13 |
| `WATER_FAR_MATERIAL` | L14 |
| `WATER_FALLBACK_COLOR` | L15 |
| `DEFAULT_SKY_TOP` | L17 |
| `DEFAULT_SKY_HORIZON` | L18 |
| `DEFAULT_GROUND_HORIZON` | L19 |
| `DEFAULT_GROUND_BOTTOM` | L20 |
| `DEFAULT_FOG_COLOR` | L21 |
| `DEFAULT_AMBIENT_COLOR` | L22 |
| `add_environment(parent: Node3D, config: Dictionary = {}) -> WorldEnvironment` | L33 |
| `add_directional_light(parent: Node3D,, node_name: String,, color: Color,, energy: float,, rotation_degrees: Vector3) -> DirectionalLight3D` | L68 |
| `add_water(parent: Node3D,, material_path: String = WATER_MATERIAL,, plane_size: float = 600.0,, position_y: float = -0.05,, overrides: Dictionary = {}) -> MeshInstance3D` | L87 |
| `load_water_material(material_path: String, overrides: Dictionary = {}) -> ShaderMaterial` | L116 |
| `configure_boat_foam(material: ShaderMaterial, bounds: AABB) -> void` | L129 |
| `frame_camera(camera: Camera3D,, bounds: AABB,, direction: Vector3,, fov: float,, margin: float) -> void` | L144 |
| `visual_aabb(root: Node) -> AABB` | L160 |
| `transform_aabb(xform: Transform3D, box: AABB) -> AABB` | L183 |

## 契约与约束

- 纯表现层：不读 GameState / 服务 / 内容 ID；相机取景只读 `visual_aabb()` 结果，不缩放模型。
- `load_water_material()` 对共享 `harbor_water.tres` 做 `duplicate(true)` 再写 shader 参数，避免污染其他场景使用的同一资源。
- `add_water()` 在材质缺失或路径非法时回退 `StandardMaterial3D`（`WATER_FALLBACK_COLOR`），舞台不会因框架材质缺失而失去水面。
- `add_environment()` 支持 `mode="sky"`（`ProceduralSkyMaterial` 调色板）与 `mode="color"`（仅 BG_COLOR）；两种都开线性雾、FILMIC tonemap 与颜色环境光。
- `add_directional_light()` 生成的灯 `shadow_enabled=false`：固定舞台只付一个 key + 一个 fill 的开销。
- `configure_boat_foam()` 把泡沫椭圆贴到船体世界包围盒（`boat_center` / `boat_half_size`，`boat_yaw` 置 0）；换船后调用方需按实际船艏向覆盖 yaw。

## 重点逻辑

### `visual_aabb(root) / transform_aabb(xform, box)`

- 遍历 Node3D 层级（显式栈 + 累积变换），对每个 MeshInstance3D 的 mesh AABB 做 8 角点变换后 merge；无网格时返回 12×5×12 的兜底盒。
- 只反映静态网格包围盒；骨骼蒙皮、粒子或运行时改 mesh 不在计算内。

### `frame_camera(camera, bounds, direction, fov, margin)`

- 距离 = 包围盒半径 / tan(fov/2) × margin，再沿固定方向摆放并 `look_at` 包围盒中心；船体尺寸变化只改相机，不缩放模型。

模块索引：[framework/ui](../README.md)
