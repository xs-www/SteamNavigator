# `tools/modeling/generators/render_cranes_preview.py`

> 作用：四台起重机的预览渲染（Lead 验收截图，非游戏资产）。

- 类型：项目配置/数据文件

逐件临时相机 / 双太阳光 / 深色世界，隐藏场景中其它网格，渲 3/4 与正侧两个
视角到 `.design/props/preview/`（`.design` 被 gitignore，属本地产物）。
渲染后还原相机 / 引擎 / 世界 / 灯光 / 可见性，不保存 .blend。

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")

模块索引：[tools](../../README.md)
