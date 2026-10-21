# `tools/modeling/generators/sn_weapon_batch2_generator.py`

> 作用：舰载特殊武器三件套（舰载弩炮 / 载人箭塔 / 蒸汽鱼叉发射器）的参数化生成器

- 类型：项目配置/数据文件

与 Blender 装配入口；同时给出“不规则形态如何拼进 socket”的模型侧契约：
统一的 Mount 空节点 + mount_class、footprint、swept_radius、anchors 根属性。

工单：`tools/modeling/briefs/sn_weapon_batch2.json`
集合：每件武器一个 `SN_Weapon_<Name>_Prototype`；根节点 `SN_Weapon_<Name>_Root`
轴心：底座贴地面中心（z = 0），+X 为前向/炮口方向，+Z 向上，1 unit = 1 m。
层级：
- 弩炮 / 鱼叉：Root → Yaw_Pivot → Pitch_Pivot；另有 Mount + 4 个 Anchor。
- 箭塔：固定塔，无 Yaw/Pitch；Mount + 4 个 Anchor 定义底座与拉索点。

用法：
- Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
- 纯 Python 干跑：`python tools/modeling/generators/dryrun_weapon_batch2.py`
- 导出 GLB：`python tools/modeling/generators/export_weapon_batch2_glb.py`

模块索引：[tools](../../README.md)
