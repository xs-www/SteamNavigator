# `tools/modeling/generators/dryrun_kit_batch5.py`

> 作用：模型素材库批次 5（M1-2 `base_kit` 生产建筑 5 件）生成器的纯 Python 干跑；

- 类型：项目配置/数据文件

核对命名、父级、tri、包围盒、zmin=0、网格健康（边界 / 非流形 / 退化面）、材质
白名单、共享贴图，以及 Mount / Module_Next/Prev / Drive_Shaft / Log_Input /
Timber_Output / Coal_Input / Ore_Input / Molten_In/Out / Pour_Point / Hoist /
Scale / Storage / Gate_In / Weapon_Mount / Searchlight / Flag / Magazine /
Ladder_Foot / Chimney 等接口契约与生产链布局断言。

用法：
    python tools/modeling/generators/dryrun_kit_batch5.py
    python tools/modeling/generators/dryrun_kit_batch5.py SN_Base_Smelter

模块索引：[tools](../../README.md)
