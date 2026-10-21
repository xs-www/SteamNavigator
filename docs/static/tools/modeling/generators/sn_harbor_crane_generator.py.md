# `tools/modeling/generators/sn_harbor_crane_generator.py`

> 作用：SN_Harbor_Crane 锤头式塔吊的参数化生成器（补全此前缺失的几何真源）。

- 类型：项目配置/数据文件

工单：`tools/modeling/briefs/sn_crane_batch1.json`（塔吊条目）
集合：`SN_Harbor_Crane_Prototype`；根节点 `SN_Crane_Root`（工作台摆位 (0, 16, 0)）；
回转 Pivot `SN_Crane_Slew_Pivot`（根局部 z = 17.3）。
轴心：底面中心（z = 0），+X 为吊臂前方，+Z 向上，1 unit = 1 m。
预算：<= 4000 tri；材质：SN_Metal / SN_Wood / SN_Wood_Dark / SN_Stone。

结构：石砌基座 + 收分格构塔身（4 弦 + 横框 + 斜撑 + 爬梯）+ 回转环 / 平台
+ 20 m 水平桁架主臂 + 6 m 配重臂 + 3 块石配重 + A 字塔头与拉杆 + 司机室
+ 主副卷扬机组（卷筒 / 电机 / 齿轮 / 制动盘）+ 小车 + 吊钩组。

用法：
- Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
- 纯 Python 干跑：`python tools/modeling/generators/dryrun_cranes.py`
- 导出 GLB：`python tools/modeling/generators/export_cranes_glb.py`

模块索引：[tools](../../README.md)
