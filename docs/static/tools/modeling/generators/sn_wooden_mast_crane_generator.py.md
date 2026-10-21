# `tools/modeling/generators/sn_wooden_mast_crane_generator.py`

> 作用：SN_Wooden_Mast_Crane 木制桅杆起重机（历史港口吊）的参数化生成器。

- 类型：项目配置/数据文件

工单：`tools/modeling/briefs/sn_crane_batch1.json`（木制桅杆起重机条目）
集合：`SN_Wooden_Mast_Crane_Prototype`；根节点 `SN_WM_Root`
（工作台摆位 (30, 260, 0)）。
轴心：地面中心（z = 0），+X 为吊臂伸出方向，+Z 向上，1 unit = 1 m。
预算：<= 4000 tri；材质：SN_Wood / SN_Wood_Dark / SN_Wood_Deck / SN_Metal /
      SN_Stone / SN_Brass / SN_Canvas_Shade。

结构：石砌台基 + 木梁底盘 + 方形木桅杆（铁箍 + 斜撑）+ 后倾木吊臂（双颊板 +
铁箍 + 端部滑轮）+ 桅顶四根后拉索与地锚 + 吊臂俯仰滑车组 + 手摇绞车
（木卷筒 / 棘轮 / 摇杆）+ 吊钩组 + 桅杆爬梯 + 甲板木料与盘绳。

用法：
- Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
- 纯 Python 干跑：`python tools/modeling/generators/dryrun_cranes.py`
- 导出 GLB：`python tools/modeling/generators/export_cranes_glb.py`

模块索引：[tools](../../README.md)
