# `tools/modeling/generators/dryrun_prototypes_lod1.py`

> 作用：批次 B 第二阶段（三栋新原型 **LOD1**）的纯 Python 干跑：不进 Blender，把

- 类型：项目配置/数据文件

`SN_HT_<Name>_LOD1` 的 tri / 硬上限 / ≤LOD0 35% / 与 LOD0 的包围盒与轴心一致性 /
网格健康 / 材质槽 / §6 轮廓识别点 tag 全部收敛，并把 LOD1 计划 + 结果落盘到
`.design/buildings/iron_harbor/b1/lod1_dryrun.json`。

## 契约与约束
- 只用同一份参数化真源：LOD0 geometry 由 `build_all_geometry()`、LOD1 由
  `build_all_geometry_lod1()` 生成，二者同文件、同常量、同闭合实体工具。
- LOD1 必须保留 §6 轮廓识别点（LOD1_SPECS[*].silhouette 的 tag 必须存在）；
  允许删除窗框/窗棂/窗台窗楣/隅石/落水管等小件。
- 尺寸门禁：LOD1 与 LOD0 的局部 bbox 逐轴 ≤0.02 m、轴心（x/y=0）与 zmin=0；
  硬上限 BH/WR 2 800、BT 4 900，且 ≤ 对应 LOD0 实测 tri 的 35%。
- 不依赖 bpy：stub `bpy`/`bmesh` 后 import 生成器；只写 `.design/buildings/iron_harbor/b1/`。

## 重点逻辑
### `main()`
- 逐栋：`measure_part(LOD0)` + `measure_part(LOD1)`；查 tri/cap/ratio、bbox/轴心/健康、
  材质槽与调色板、LOD1 轮廓 tag；失败返回码 1。

模块索引：[tools](../../README.md)
