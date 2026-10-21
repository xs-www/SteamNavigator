# `tools/modeling/generators/dryrun_weapon_batch1.py`

> 作用：舰载武器五件套生成器的纯 Python 干跑（不起 Blender），在进 Blender 之前拦住

- 类型：项目配置/数据文件

几何 / 命名 / 材质 / Pivot 契约错误。

逐件核对：对象命名前缀、父级键、三角面预算、包围盒目标、落地（zmin = 0）、
边界边 / 非流形边 / 退化面、材质白名单、共享贴图存在性、Pivot 父子关系与原点。
用法：
    python tools/modeling/generators/dryrun_weapon_batch1.py
    python tools/modeling/generators/dryrun_weapon_batch1.py SN_Weapon_Mortar
通过标准：每件 ALL OK；任何一项失败返回非 0 退出码。

模块索引：[tools](../../README.md)
