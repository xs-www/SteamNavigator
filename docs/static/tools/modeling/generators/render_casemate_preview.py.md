# `tools/modeling/generators/render_casemate_preview.py`

> 作用：casemate gun 模块化的**预览渲染**（Lead 验收截图，非游戏资产，Blender 内执行）：

- 类型：项目配置/数据文件

- 单件：`SN_Weapon_CasemateGun` 的 3/4 与正侧（照 `docs/design/screenshots/weapons/` 惯例）；
- 装舰：把模块临时实例化到铁甲舰 12 个炮门 socket 上，出 3/4 全景与炮列近景；
- 空载：同一近景机位、不装模块，对照“空炮门”读感。
临时实例只在本脚本内创建，渲染后删除；相机/灯光/世界/可见性全部还原，不改资产。

输出：`docs/design/screenshots/weapons/casemate_gun_{three_quarter,side}.png`、
      `docs/design/screenshots/ironclad_casemate_{three_quarter,guns_closeup,empty_closeup}.png`

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")

模块索引：[tools](../../README.md)
