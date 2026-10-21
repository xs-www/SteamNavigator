# `tools/modeling/generators/sn_weapon_batch1_generator.py`

> 作用：舰载武器五件套（甲板速射炮 / 重型舰炮 / 曲射迫击炮 / 机关连发炮 / 侧弦炮列）

- 类型：项目配置/数据文件

的参数化生成器与 Blender 装配入口。

工单：`tools/modeling/briefs/sn_weapon_batch1.json`
集合：每件武器一个 `SN_Weapon_<Name>_Prototype`；根节点 `SN_Weapon_<Name>_Root`
轴心：炮座底面中心（z = 0），+X 为炮口方向，+Z 向上，1 unit = 1 m。
层级：Root → Yaw_Pivot（绕 Z 回转）→ Pitch_Pivot（绕 Y 俯仰，轴心在耳轴）。
侧弦炮列沿 Y 排 4 门炮、共用一条回转滑轨，因此上船时绕 Z 旋转 -90° 让炮口朝舷外。

用法：
- Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
- 纯 Python 干跑：`python tools/modeling/generators/dryrun_weapon_batch1.py`
- 导出 GLB：`python tools/modeling/generators/export_weapon_glb.py`

模块索引：[tools](../../README.md)
