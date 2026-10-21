# `tools/modeling/generators/export_weapon_glb.py`

> 作用：舰载武器五件套的 GLB 归档导出脚本（人工验收通过后由 Lead 执行）；导出后把

- 类型：项目配置/数据文件

GLB 内嵌材质贴图外部化为 `shared_materials/<texture>.png` 共享 URI，并同步
`assets/models/weapons/` 与 `dev_mods/core/assets/models/weapons/` 两处副本。

约定（见 docs/design/MODELING_WORKFLOW.md 第 8 节与 docs/design/ASSET_MAP.md）：
- 逐件导出：导出前把根空物体 `location` 临时归零，导出后还原；轴心落在炮座底面中心；
- 只导出该集合内的对象（根 / Pivot / 网格），不导相机 / 灯光 / 其它资产；
- glTF 默认 +Y 向上，进入 Godot 后尺寸为 (Blender X, Blender Z, Blender Y)；
- 覆盖前把旧 GLB 备份到 `.design/weapons/backup_glb/`；
- 贴图外部化复用 `glb_shared_textures.externalize_glb(..., prefer_authored=True)`；
- 本批不登记 Core manifest 键，只交付资产副本；
- 全部导出后保存工作台 `.design/SN_Asset_Workbench.blend`。

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")
或后台：
    blender -b .design/SN_Asset_Workbench.blend -P tools/modeling/generators/export_weapon_glb.py

模块索引：[tools](../../README.md)
