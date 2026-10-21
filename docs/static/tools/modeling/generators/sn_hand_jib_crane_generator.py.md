# `tools/modeling/generators/sn_hand_jib_crane_generator.py`

> 作用：SN_Hand_Jib_Crane 手摇悬臂吊（码头小型回转吊）的参数化生成器。

- 类型：项目配置/数据文件

工单：`tools/modeling/briefs/sn_crane_batch1.json`（手摇悬臂吊条目）
集合：`SN_Hand_Jib_Crane_Prototype`；根节点 `SN_HJ_Root`
（工作台摆位 (55, 260, 0)）。
轴心：地面中心（z = 0），+X 为悬臂伸出方向，+Z 向上，1 unit = 1 m。
预算：<= 1500 tri；材质：SN_Metal / SN_Iron / SN_Wood_Dark / SN_Stone /
      SN_Brass / SN_Canvas_Shade。

结构：石砌基座 + 木垫板 + 立柱（铁箍 / 柱帽）+ 收分悬臂 + 拉杆与斜撑 +
手摇绞车（卷筒 / 棘轮 / 摇柄）+ 导向滑轮 + 吊钩组 + 立柱踏步。

用法：
- Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
- 纯 Python 干跑：`python tools/modeling/generators/dryrun_cranes.py`
- 导出 GLB：`python tools/modeling/generators/export_cranes_glb.py`

模块索引：[tools](../../README.md)
