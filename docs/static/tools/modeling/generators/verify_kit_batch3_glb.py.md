# `tools/modeling/generators/verify_kit_batch3_glb.py`

> 作用：模型素材库批次 3（建筑 / 环境）GLB 结构与共享贴图自检（纯 Python，不进

- 类型：项目配置/数据文件

Blender）。期望值从 `kit_batch3_generator.py` 的纯几何推导；额外核对建筑
module_x/module_y、环境 waterline extras、每个图元有 UV、贴图 URI 与字节一致。

用法：
    python tools/modeling/generators/verify_kit_batch3_glb.py

模块索引：[tools](../../README.md)
