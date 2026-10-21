# `tools/modeling/generators/render_kit_batch3_preview.py`

> 作用：模型素材库批次 3（建筑 4 + 环境 4）的预览渲染（Lead 在人工验收前执行，

- 类型：项目配置/数据文件

不进游戏）。逐件 3/4 + 侧视、建筑 / 环境两组 lineup，以及一张「仓库 + 工坊 +
酒馆 + 厂房」街区和一张「礁石 + 灯塔 + 残骸 + 浮标」海岸拼装；渲染后删除临时
对象并恢复场景状态（不保存、不导出）。

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")
输出：.design/kits/preview/*.png 与 docs/design/screenshots/kits/*.png

模块索引：[tools](../../README.md)
