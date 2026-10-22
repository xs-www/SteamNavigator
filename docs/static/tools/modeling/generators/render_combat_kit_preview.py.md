# `tools/modeling/generators/render_combat_kit_preview.py`

> 作用：`combat_kit` 敌舰套件（M2-1）预览渲染（人工 / 独立 Verifier 验收前由 Builder

- 类型：项目配置/数据文件

在 Blender 内执行，不进游戏）—— 逐艘隔离目标集合，临时创建相机 / 双太阳灯 / 水面，
渲染 3/4 与侧视；再输出一张四艘 lineup。渲染结束删除临时对象并恢复 hide_render /
相机 / 渲染器 / 世界背景，不保存 .blend、不导出 GLB。

输出：`.design/combat/preview/<asset>_<view>.png` + `combat_lineup.png`；
便于文档使用的副本写到 `docs/design/screenshots/combat/`。

用法（已连 Blender、4 艘敌舰已构建的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")

模块索引：[tools](../../README.md)
