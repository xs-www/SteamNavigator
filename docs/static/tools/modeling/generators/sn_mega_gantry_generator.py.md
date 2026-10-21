# `tools/modeling/generators/sn_mega_gantry_generator.py`

> 作用：SN_Mega_Gantry 大型龙门吊（巨型钢结构 + 可读复杂传动）的参数化生成器。

- 类型：项目配置/数据文件

工单：`tools/modeling/briefs/sn_crane_batch1.json`（龙门吊条目）
集合：`SN_Mega_Gantry_Prototype`；根节点 `SN_MG_Root`（工作台摆位 (-20, 260, 0)）。
轴心：轨道面中心（z = 0），+X 为大车运行方向，+Z 向上，1 unit = 1 m。
预算：<= 12000 tri；材质：SN_Metal / SN_Iron / SN_Iron_Red / SN_Wood_Dark /
      SN_Brass / SN_Stone / SN_Glass_Dark。

结构：地面轨道 + 4 台带齿轮传动的台车（大车） + 4 条收分格构腿 + 两条顶部
格构横梁（顺桥向）+ 40 m 主桁架桥（双弦 + 斜腹杆 + 横框 + 走台栏杆）+
桥面上的小车与卷扬机构 + 桥端机械房（双卷筒 / 电机 / 齿轮箱 / 齿轮组 /
制动盘 / 排气管） + 双吊钩横担与吊装中的集装箱 + 爬梯 / 平台 / 栏杆。

用法：
- Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
- 纯 Python 干跑：`python tools/modeling/generators/dryrun_cranes.py`
- 导出 GLB：`python tools/modeling/generators/export_cranes_glb.py`

模块索引：[tools](../../README.md)
