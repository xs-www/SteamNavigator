# `framework/domain/world/land_generator.gd`

> 作用：程序化生成陆地多边形，支持大陆、大岛、小岛、环礁四种原型。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `LandGenerator` | L1 |

## 契约与约束

- 所有生成方法都接受 `rng` 参数，确保同 seed 可复现。
- 大陆生成时会自动调整位置以贴边。
- 环礁生成需要额外参数（内圈半径比例）。
- 简化算法的 `tolerance` 参数控制简化程度（建议 1.0-5.0）。

## 重点逻辑

### `generate_continent(center, size, seed)`

- 生成大陆原型：占据世界边缘，形状狭长，使用低频噪声+正弦波。

### `generate_large_island(center, size, seed)`

- 生成大岛原型：圆形或椭圆形基础形状，中等频率噪声扰动，半径约 15-25 单位。

### `generate_small_island(center, size, seed)`

- 生成小岛原型：不规则形状，高频噪声扰动，半径约 4-8 单位。

### `generate_atoll(center, size, seed)`

- 生成环礁原型：环形结构（外圈+内圈），中心有泻湖，半径约 2-4 单位。

模块索引：[framework/domain](../README.md)
