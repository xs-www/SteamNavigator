# `assets/shaders/water/harbor_water.gdshader`

> 作用：港口水面空间着色器：顶点正弦波位移、噪声法线、菲涅耳天空反射、太阳耀斑路径、岸线与船体泡沫，以及远处雾色淡出。

- 关键依赖：`assets/textures/water/water_normal.png`、`assets/textures/water/water_foam.png`
- 类型：Godot 着色器

## 契约与约束

- GL Compatibility 安全：不使用深度纹理/屏幕纹理，也不依赖光照 shadow map（`shadows_disabled`）；水面自身发光项负责主要观感。
- `swell_height` / `wave_speed` 与 `bobbing_boat.gd` 的常量同源；两边必须一起改。
- 使用 `world_vertex_coords`，水面节点的世界变换应只有 XZ 平移，不要旋转或缩放。
- 岸边泡沫只在水侧（世界 z > `shore_z`）生成；船体泡沫用椭圆近似，参数 `boat_center` / `boat_half_size` / `boat_yaw` 由场景材质维护。
- 远处淡出到 `horizon_color`；`harbor_water_far.tres` 用同一 shader 并关掉波浪/细节/泡沫，保证两层水面在网格边缘颜色一致。

## 重点逻辑

### `swell(p, t) / swell_gradient(p, t)`

- 三条方向、波数、相速不同的正弦叠加，返回约 [-1, 1] 的无量纲波高。
- 顶点位移与片元坡度共用这一函数；改公式等于同时改船的采样。
- 坡度用 ±0.8 m 的有限差分求得，用于构造世界空间法线，避免与顶点法线不一致。

### `fragment()`

- 先用法线计算菲涅耳反射与太阳耀斑，再用 `shore_z` / `boat_*` 生成泡沫，最后按相机距离淡出到地平线色。
- `ALBEDO` 只承担少量环境光，主要颜色放在 `EMISSION`；这样不受黄昏暖环境光和阴影质量影响。
- `light()` 只叠加太阳高光/宽高光，不重复对齐天空反射。
