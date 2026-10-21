# `tools/modeling/generators/render_weapon_preview.py`

> 作用：舰载武器五件套的预览渲染（Lead 在人工验收前执行，不进游戏）。

- 类型：项目配置/数据文件

在工作台里逐件隔离目标集合，临时创建相机 / 灯光 / 地面，渲染 3/4 与侧视；
最后把五件临时摆成一排渲染 lineup（正交相机，便于判断相互比例）。渲染完成后
删除临时对象并恢复所有 hide_render 状态，不保存 .blend、不导出 GLB。

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")
输出：.design/weapons/preview/*.png 与 docs/design/screenshots/weapons/*.png

模块索引：[tools](../../README.md)
