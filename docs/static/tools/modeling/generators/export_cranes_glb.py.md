# `tools/modeling/generators/export_cranes_glb.py`

> 作用：四台起重机的 GLB 归档导出脚本（人工/自动验收通过后由 Lead 执行）。

- 类型：项目配置/数据文件

约定（见 docs/design/MODELING_WORKFLOW.md 第 8 节）：
- 逐件导出：导出前把根空物体 `location` 临时归零，导出后还原；根空物体归零后
  几何即根局部坐标，轴心落在底面中心 / 轨道面中心；
- 只导出该集合内的对象（根 / Pivot / 网格），不导相机 / 灯光 / 其它资产；
- glTF 默认 +Y 向上，进入 Godot 后尺寸为 (Blender X, Blender Z, Blender Y)；
- 覆盖前把旧 GLB 备份到 `.design/props/backup_glb/`；
- 塔吊沿用 Core 既有资产键 `model.prop.harbor_crane`，导出后同步
  `dev_mods/core/assets/models/props/` 副本；新增三件暂不接 Core manifest。
- 全部导出后保存工作台 `.design/SN_Asset_Workbench.blend`。

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")
或后台：
    blender -b .design/SN_Asset_Workbench.blend -P tools/modeling/generators/export_cranes_glb.py

模块索引：[tools](../../README.md)
