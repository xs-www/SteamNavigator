# `tools/modeling/generators/weapon_kit.py`

> 作用：Steam Navigator 舰载武器资产的共用低模几何部件库（纯 Python，不 import bpy）。

- 类型：项目配置/数据文件

供 `sn_weapon_batch1_generator.py` 复用：炮管 / 炮口箍 / 耳轴 / 摇架 / 炮座、
俯仰弧齿、手轮、辐条轮、铆钉排、地脚螺栓、蒸汽管、弹斗、炮弹、炮架滑轨等。
所有基本体都是闭合壳体，便于 `dryrun_weapon_batch1.py` 检查边界边 / 非流形边 /
退化面；几何只追加进调用方提供的 `Part`，不创建对象、不碰 bpy。

约定：1 unit = 1 m；+X 为炮口方向、+Z 向上、+Y 为左舷；材质名走共享贴图材质
（`SN_Tex_*`，见 `sn_weapon_materials.py`），不新增材质。

模块索引：[tools](../../README.md)
