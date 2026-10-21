# `tools/modeling/generators/render_weapon_batch2_preview.py`

> 作用：舰载特殊武器三件套（弩炮 / 箭塔 / 蒸汽鱼叉）的预览渲染；复用

- 类型：项目配置/数据文件

`render_weapon_preview.py` 的隔离 / 相机 / 灯光 / 地面逻辑，只替换资产清单与
lineup 文件名。

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")
输出：.design/weapons/preview/ 与 docs/design/screenshots/weapons/

模块索引：[tools](../../README.md)
