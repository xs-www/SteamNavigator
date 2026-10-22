# `tools/modeling/generators/render_kit_batch5_preview.py`

> 作用：模型素材库批次 5（M1-2 `base_kit` 生产建筑 5 件）的预览渲染（Lead 在人工

- 类型：项目配置/数据文件

验收前执行，不进游戏）。逐件 3/4 + 侧视、一张 5 件 lineup，以及一张「生产链基地」
拼装（锯木厂 → 冶炼炉 → 铸造车间 → 堆场 → 防御塔）+ 一张冶炼/铸造近景；渲染后删除
临时对象并恢复场景状态（不保存、不导出）。

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")
输出：.design/kits/preview/*.png 与 docs/design/screenshots/kits/*.png

模块索引：[tools](../../README.md)
