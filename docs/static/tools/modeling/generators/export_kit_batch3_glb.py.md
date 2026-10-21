# `tools/modeling/generators/export_kit_batch3_glb.py`

> 作用：模型素材库批次 3（建筑 4 + 环境 4）的 GLB 归档导出；复用

- 类型：项目配置/数据文件

`export_kit_glb.py` 的导出 / 贴图外部化 / Core 同步逻辑，替换资产清单与目录，
并把 11 张共享贴图补齐到 architecture / environment 两处 shared_materials。

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")

模块索引：[tools](../../README.md)
