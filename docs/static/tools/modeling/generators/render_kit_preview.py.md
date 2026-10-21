# `tools/modeling/generators/render_kit_preview.py`

> 作用：模型素材库批次 1（武器套件 + 船体部件）的预览渲染（Lead 在人工验收前执行，

- 类型：项目配置/数据文件

不进游戏）。

在工作台里逐件隔离目标集合，临时创建相机 / 灯光 / 地面，渲染 3/4 与侧视；再输出
两组 lineup（武器套件 / 船体部件）与两张拼装演示（火炮+炮架、甲板+桅杆+烟囱+
货舱盖+炮塔+基座）。渲染完成后删除临时对象并恢复所有 hide_render、root 变换与
视口 shading（工作台约定 Solid = SINGLE 灰模，渲染时临时切 TEXTURE 后恢复），
不保存 .blend、不导出 GLB。

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")
输出：.design/kits/preview/*.png 与 docs/design/screenshots/kits/*.png

模块索引：[tools](../../README.md)
