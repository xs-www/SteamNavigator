# `framework/domain/world/land_generator.gd`

> 作用：程序化生成陆地多边形，支持大陆、大岛、小岛和环礁。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `LandGenerator` | L1 |
| `CONTINENT_SEGMENTS` | L20 |
| `ISLAND_SEGMENTS` | L21 |
| `ATOLL_SEGMENTS` | L22 |
| `SIMPLIFY_TOLERANCE` | L25 |
| `CONTINENT_HARMONICS` | L29 |
| `LARGE_ISLAND_HARMONICS` | L30 |
| `SMALL_ISLAND_HARMONICS` | L31 |
| `ATOLL_HARMONICS` | L32 |
| `generate_continent(id: String, center: Vector2, radius_x: float, radius_y: float, region_id: String, rng: RandomNumberGenerator) -> Landmass` | L82 |
| `generate_large_island(id: String, center: Vector2, radius_x: float, radius_y: float, region_id: String, rng: RandomNumberGenerator) -> Landmass` | L87 |
| `generate_small_island(id: String, center: Vector2, radius_x: float, radius_y: float, region_id: String, rng: RandomNumberGenerator) -> Landmass` | L92 |
| `generate_atoll(id: String, center: Vector2, outer_radius_x: float, outer_radius_y: float, region_id: String, rng: RandomNumberGenerator) -> Landmass` | L97 |
| `generate_region_landmasses(region: Region, world_bounds: Rect2, land_defs: Array, rng: RandomNumberGenerator) -> Array[Landmass]` | L102 |
| `simplify_polygon(polygon: PackedVector2Array, tolerance: float) -> PackedVector2Array` | L128 |

## 契约与约束
- 所有生成方法都接收 `rng`，保证同 seed 可复现。
- 海岸线是**相干**噪声：每个地形的谐波相位只抽一次，半径随角度连续变化；
  逐顶点 `randf()` 是白噪声，只会产生锯齿状尖刺。
- 轮廓必须保持星形（相对中心单值），避免自交导致多边形填充/三角形化出错。
- 生成后按 `SIMPLIFY_TOLERANCE` 做 Douglas-Peucker 简化，去掉近似共线的采样点。

## 重点逻辑
### `_make_profile` / `_profile_radius`
- 半径剖面 = base + Σ amplitude·sin(frequency·θ + phase)，相位在生成前一次性抽取。
### `generate_*`
- 各原型共用同一套剖面机制，只是谐波数量、频率与振幅不同。

模块索引：[framework/domain](../README.md)
