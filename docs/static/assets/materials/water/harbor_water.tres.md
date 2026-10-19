# `assets/materials/water/harbor_water.tres`

> 作用：近处水面材质：港口样片的主水面参数（波浪、反射、岸线与船体泡沫、太阳方向）。

- 类型：Godot 资源

## 契约与约束

- 参数必须与 `harbor_water.gdshader` 的默认值同步；材质才是场景实际生效值。
- `sun_direction` 与场景 `Sun` 的朝向对应；`boat_*` 与 `World/ShipBob` 的位置/朝向对应。
- `shore_z` 是码头前沿水线（世界 z），`shore_span` 覆盖码头宽度。
