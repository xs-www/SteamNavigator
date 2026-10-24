# `tools/modeling/generators/render_grand_harbour_terminal_preview.py`

> 作用：`SN_Grand_Harbour_Terminal` 大型航站楼的 EEVEE 预览渲染（Lead 人工验收用截图，

- 类型：项目配置/数据文件

不进游戏、不保存 .blend）。

在现有工作台里临时搭一个港口预览舞台：
- 只显示集合 `SN_GHT_Grand_Harbour_Terminal_Prototype`，其余 mesh 临时 hide_render；
- EEVEE Next（引擎不存在时回退 BLENDER_EEVEE）、采样 32，AgX 视图变换；
- 临时世界：地平线雾蓝 → 天顶深蓝的程序化渐变天空；
- 临时水面：z≈0 的大平面，深青绿色、低粗糙度、Noise→Bump 轻微波纹；
- 太阳主光 + 面积补光；相机按集合 bbox 自动取景（目标中心不硬编码世界坐标）。

4 个镜头（输出到 `.design/architecture/preview/` 与
`docs/design/screenshots/architecture/`，两处同名 `grand_terminal_*.png`）：
  grand_terminal_three_quarter.png   约 +X/-Y 45°、略高的 3/4 全景   1600x900
  grand_terminal_front.png           +X 正立面（略仰）               1600x900
  grand_terminal_aerial.png          高角度俯视                      1600x900
  grand_terminal_entrance_detail.png 中央拱门近景                    1400x900

渲染完成后逐项恢复 hide_render / 集合可见性 / 渲染设置 / 世界 / 视图变换，
删除全部临时对象与数据块；**不保存 .blend、不导出 GLB**。

用法（已连 Blender 的会话，先执行生成器 build_all()）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")

模块索引：[tools](../../README.md)
