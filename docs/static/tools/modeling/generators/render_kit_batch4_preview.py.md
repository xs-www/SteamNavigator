# `tools/modeling/generators/render_kit_batch4_preview.py`

> 作用：模型素材库批次 4（M1-1 architecture_kit 扩展 6 件）的预览渲染（Lead 在人工

- 类型：项目配置/数据文件

验收前执行，不进游戏）。逐件 3/4 + 侧视、一张 6 件 lineup，以及一张「围墙 + 大门 +
道路 + 装卸平台 + 仓库变体 + 工坊扩建」的可围合基地拼装街景 + 近景；渲染后删除临时
对象并恢复场景状态（不保存、不导出）。

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")
输出：.design/kits/preview/*.png 与 docs/design/screenshots/kits/*.png

模块索引：[tools](../../README.md)
