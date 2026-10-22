# `tools/modeling/generators/gen_kit_catalog.py`

> 作用：从批次 1/2/3/4 生成器的纯几何数据生成机器可读的模型素材库目录

- 类型：项目配置/数据文件

`tools/modeling/kit_catalog.json`（资产 / 尺寸 / tri / 材质 / socket 接口 / 装配
配方），并把 M0-5 的 LOD1 计划（`lod1_kit_ships_plan.json`）合并成逐件 `lod1` 块与
顶层 `lod1` 汇总（路径 / LOD1 tri / 比例 / 上限 / 字节 / bbox）。

批次 4（M1-1 architecture_kit 扩展）加入 6 件可围合建筑件；配方新增「可围合基地」
「道路平铺」「工坊扩建接动力」「仓库变体装卸」四条。
批次 5（M1-2 base_kit）加入 5 件生产建筑（锯木厂 / 冶炼炉 / 铸造车间 / 仓库堆场 /
防御塔）；配方新增「木料生产链」「冶炼-铸造链」「堆场入库」「防御塔炮位」四条。

用法：
    python tools/modeling/generators/gen_kit_catalog.py

约定：LOD1 段只合并 `kind == "kit"` 的 26 件（船 LOD1 在 Core manifest 登记）；
计划文件缺失时目录照常生成，只是没有 `lod1` 字段（向后兼容）。

模块索引：[tools](../../README.md)
