# `assets/materials/water/harbor_water.tres`

> 作用：近处水面材质：港口样片的主水面参数（波浪、反射、岸线与船体泡沫、太阳方向）。

- 类型：Godot 资源

## 契约与约束

- 参数必须与 `harbor_water.gdshader` 的默认值同步；材质才是场景实际生效值。
- `sun_direction` 与场景 `Sun` 的朝向对应；`boat_*` 与 `World/ShipBob` 的位置/朝向对应。
- 浮船为 SN_Schooner_Fame 时 `boat_half_size` 取 (13.2, 3.9)（船体 LOA 24.4 m），换船或改船体比例时同步。
- `shore_z` 是码头前沿水线（世界 z），`shore_span` 覆盖码头宽度。
