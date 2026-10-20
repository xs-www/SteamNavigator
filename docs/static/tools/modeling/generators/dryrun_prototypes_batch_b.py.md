# `tools/modeling/generators/dryrun_prototypes_batch_b.py`

> 作用：批次 B 第一阶段（三栋新原型 LOD0）的**纯 Python 干跑**：不进 Blender，先收敛

- 类型：项目配置/数据文件

Boiler House / Workshop Row / Brick Tenement 的 tri 目标区间 / 硬上限 / 尺寸 ±0.10 /
网格健康 / 材质槽 / 必须包含项 tag，并把结果落盘到
`.design/buildings/iron_harbor/b1/dryrun_prototypes.json`。

## 契约与约束
- 不依赖 bpy：stub `bpy` / `bmesh` 后 import 生成器，只调用 `build_all_geometry()` 与
  纯 Python 度量函数；任何 Blender 入口都不得在干跑路径被调用。
- 只读仓库：除 `.design/buildings/iron_harbor/b1/dryrun_prototypes.json` 外不写文件。
- 门禁：BH/WR tri ∈ [6000, 7500] 且 ≤8000；BT tri ∈ [9000, 12000] 且 ≤14000；
  尺寸与 `PROTOTYPES.target` 差 ≤0.10；zmin=0；轴心 x/y=0；边界边/非流形/退化面=0；
  材质槽 ≤6 且全 `SN_Town_*`。

## 重点逻辑
### `main()`
- 逐栋 `measure(part)` + `feature_report(part)`：tri/尺寸/bbox/健康 + 必须项 tag 证据
  （如 chimney 的 bbox 顶 z、fire_escape 的 bbox、sawtooth_roof 的面数），失败返回码 1。

模块索引：[tools](../../README.md)
