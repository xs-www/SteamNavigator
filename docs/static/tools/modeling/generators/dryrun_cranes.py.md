# `tools/modeling/generators/dryrun_cranes.py`

> 作用：四台起重机生成器的纯 Python 干跑（不起 Blender），进 Blender 前拦几何缺陷。

- 类型：项目配置/数据文件

对每个生成器调用 `build_all_geometry()`，逐对象核对：命名前缀、父级键、
三角面预算、包围盒目标、边界边 / 非流形边 / 退化面、材质白名单、空几何；
并检查整体落地（zmin=0）与总三角面。用法：

    python tools/modeling/generators/dryrun_cranes.py
    python tools/modeling/generators/dryrun_cranes.py sn_mega_gantry_generator.py

通过标准：每个生成器 ALL OK；任何一项失败返回非 0 退出码。

模块索引：[tools](../../README.md)
