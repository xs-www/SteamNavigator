# `tools/modeling/generators/render_kit_batch2_preview.py`

> 作用：模型素材库批次 2（机械 / 货物 / 码头 10 件）的预览渲染（Lead 在人工验收前

- 类型：项目配置/数据文件

执行，不进游戏）。逐件 3/4 + 侧视、三组 lineup，以及一张「码头 + 栈桥 + 系缆 +
货箱」拼装演示；渲染后删除临时对象并恢复场景状态。

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")
输出：.design/kits/preview/*.png 与 docs/design/screenshots/kits/*.png

模块索引：[tools](../../README.md)
