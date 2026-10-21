# `tools/modeling/generators/export_rig_kit_glb.py`

> 作用：`rig_kit` 独立套件（12 件 `SN_Rig_*`）的 GLB 归档导出（Blender 内执行，

- 类型：项目配置/数据文件

人工验收通过后由 Lead 运行）——逐件根节点归零导出，把内嵌共享贴图外部化为
`shared_materials/<texture>.png`，调 `glb_rig_kit.standardize()` 归一化接口节点名
并写 Root extras，备份旧 GLB，同步 `assets/models/rig/` 与
`dev_mods/core/assets/models/rig/` 两份副本，最后保存工作台。

约定：轴心 = 该资产的 Root datum（桅杆/艏斜桁/索具在甲板，桁/帆在各自挂点）；
只导出目标集合；不导相机/灯光；旧 GLB 备份到 `.design/rig_kit/backup_glb/`。

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")

模块索引：[tools](../../README.md)
