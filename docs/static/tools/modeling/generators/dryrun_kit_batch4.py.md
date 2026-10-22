# `tools/modeling/generators/dryrun_kit_batch4.py`

> 作用：模型素材库批次 4（M1-1 architecture_kit 扩展 6 件）生成器的纯 Python 干跑；

- 类型：项目配置/数据文件

核对命名、父级、tri、包围盒、zmin=0、网格健康（边界 / 非流形 / 退化面）、材质
白名单、共享贴图，以及 Mount / Module_Next/Prev/Left/Right / Wall_Top / Gateway /
Door_Hinge / Hoist / Dock_Edge / Stair_Foot / Drive_Shaft / Chimney / Coal_Hatch
等接口契约与地面基准。

用法：
    python tools/modeling/generators/dryrun_kit_batch4.py
    python tools/modeling/generators/dryrun_kit_batch4.py SN_Arch_Gate

模块索引：[tools](../../README.md)
