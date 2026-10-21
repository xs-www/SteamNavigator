# `tools/modeling/generators/verify_kit_batch2_glb.py`

> 作用：模型素材库批次 2（机械 / 货物 / 码头）GLB 结构与共享贴图自检（纯 Python，

- 类型：项目配置/数据文件

不进 Blender）。期望值从 `kit_batch2_generator.py` 的纯几何推导；额外核对煤材质
`SN_Tex_Coal` 已随 GLB 外部化、每个图元有 UV、根 extras 字段齐全。

用法：
    python tools/modeling/generators/verify_kit_batch2_glb.py

模块索引：[tools](../../README.md)
