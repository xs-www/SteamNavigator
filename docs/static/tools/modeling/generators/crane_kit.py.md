# `tools/modeling/generators/crane_kit.py`

> 作用：Steam Navigator 起重机类资产的共用低模几何部件库（纯 Python，不 import bpy）。

- 类型：项目配置/数据文件

供 `sn_harbor_crane_generator.py` / `sn_mega_gantry_generator.py` /
`sn_wooden_mast_crane_generator.py` / `sn_hand_jib_crane_generator.py` 复用：
桁架臂（lattice boom）、格构柱（lattice column）、梯子、栏杆、平台、车轮、
卷筒、滑轮、齿轮、钢缆、吊钩组、手摇绞车。所有基本体都是闭合壳体，
便于 `dryrun_cranes.py` 检查边界边 / 非流形边 / 退化面。

约定：1 unit = 1 m；+X 为前向（臂架伸出方向）、+Z 向上；材质名走调色板
（SN_Metal / SN_Wood / SN_Wood_Dark / SN_Stone / SN_Brass / SN_Iron /
SN_Iron_Red / SN_Canvas_Shade），不新增材质。

部件函数只把几何追加进调用方提供的 `Part`，不创建对象、不碰 bpy；
装配仍走 `ship_parts.assembly.build_collection()`。

模块索引：[tools](../../README.md)
