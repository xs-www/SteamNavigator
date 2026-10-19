# `dev_scenes/harbor/bobbing_boat.gd`

> 作用：浮船：采样与水面着色器同源的波浪，驱动升沉、纵摇、横摇和极缓慢系泊漂移。

- 类型：GDScript 源文件

## 契约与约束

- `SWELL_HEIGHT` / `WAVE_SPEED` 必须与 `harbor_water.gdshader` 的 `swell_height` / `wave_speed` 保持一致。
- 只在 `_process` 写 `position` / `rotation`；`_base_position` / `_base_rotation` 在 `_ready` 缓存，改初始位姿请改场景里的 `ShipBob`。
- 模型 +X 为船首、+Z 为右舷；横摇取负号，避免波面抬升一侧时船向反方向倾斜。
- 不做航行/碰撞/物理，仅表现层。

模块索引：[dev_scenes](../README.md)
