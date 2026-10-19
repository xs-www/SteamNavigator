# `assets/materials/water/harbor_water_far.tres`

> 作用：远处水面材质：同一 shader，关闭波浪/细节/泡沫与反射，只输出地平线雾色。

- 类型：Godot 资源

## 契约与约束

- `horizon_fade_start` / `horizon_fade_end` 设为 0 / 0.001，让整层水面恒为 `horizon_color`。
- `horizon_color` 必须与 `harbor_water.tres` 一致，否则主水面网格边缘会出现色差。
