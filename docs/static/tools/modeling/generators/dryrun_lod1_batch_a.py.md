# `tools/modeling/generators/dryrun_lod1_batch_a.py`

> 作用：批次 A（5 栋建筑 LOD1）的**纯 Python 干跑**：不进 Blender，先把 LOD1 的 tri / 上限 /

- 类型：项目配置/数据文件

LOD0 35% 比例 / 包围盒 / zmin / 轴心 / 边界边 / 非流形边 / 退化面 / 材质槽全部收敛到门禁内，
并把结果落盘到 `.design/buildings/iron_harbor/a1/dryrun_lod1.json`。

## 契约与约束
- 与 `dryrun_props.py` 的分工：后者按 `ITEMS` 做通用单件检查；本脚本额外用**同一份参数化
  真源重建 LOD0**，用 LOD0 的实测 tri 计算 35% 门禁，并逐轴比较包围盒（容差 0.02 m）。
- 只能用纯 Python：stub `bpy` / `bmesh` 后 import LOD1 生成器；任何需要 Blender 的入口
  （build_all/report/render_previews）都不得在干跑路径被调用。
- 只读仓库：除 `.design/buildings/iron_harbor/a1/dryrun_lod1.json` 外不写任何文件。

## 重点逻辑
### `main()`
- 逐栋：`measure(LOD1 part)` + 用 `mod.lod0(asset)` 重建 LOD0 part 再 `measure`，比较
  `tris / size / zmin / 轴心 / boundary / non-manifold / degenerate / materials`；
  任一失败返回码 1，并在 `failures` 中列出对象与失败项。

模块索引：[tools](../../README.md)
