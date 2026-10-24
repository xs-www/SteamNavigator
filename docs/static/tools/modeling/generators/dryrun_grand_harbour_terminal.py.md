# `tools/modeling/generators/dryrun_grand_harbour_terminal.py`

> 作用：大型港口航站楼 SN_Grand_Harbour_Terminal 的纯 Python 干跑自检（不进 Blender）。

- 类型：项目配置/数据文件

校验：对象/命名、三角面预算、世界包围盒、zmin、材质白名单、每个 mesh 的
边界边 / 非流形边 / 退化面 / 孤立点、共享贴图（含 SN_Tex_Copper_Green）存在、
关键体量与部件清单。Blender 侧的文字铭牌不计入几何预算，但会单独留 allowance。

用法：python tools/modeling/generators/dryrun_grand_harbour_terminal.py

模块索引：[tools](../../README.md)
