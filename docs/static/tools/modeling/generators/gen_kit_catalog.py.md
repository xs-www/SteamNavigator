# `tools/modeling/generators/gen_kit_catalog.py`

> 作用：从批次 1/2/3 生成器的纯几何数据生成机器可读的模型素材库目录

- 类型：项目配置/数据文件

`tools/modeling/kit_catalog.json`（资产 / 尺寸 / tri / 材质 / socket 接口 / 装配
配方），并把 M0-5 的 LOD1 计划（`lod1_kit_ships_plan.json`）合并成逐件 `lod1` 块与
顶层 `lod1` 汇总（路径 / LOD1 tri / 比例 / 上限 / 字节 / bbox）。

用法：
    python tools/modeling/generators/gen_kit_catalog.py

约定：LOD1 段只合并 `kind == "kit"` 的 26 件（船 LOD1 在 Core manifest 登记）；
计划文件缺失时目录照常生成，只是没有 `lod1` 字段（向后兼容）。

模块索引：[tools](../../README.md)
