# `tools/modeling/generators/export_kit_glb.py`

> 作用：模型素材库批次 1（武器套件 4 件 + 船体部件 4 件）的 GLB 归档导出（人工验收

- 类型：项目配置/数据文件

通过后由 Lead 执行）；导出后把内嵌材质贴图外部化为 `shared_materials/<texture>.png`
共享 URI，并同步 `assets/models/{weapons,ship_parts}/` 与
`dev_mods/core/assets/models/{weapons,ship_parts}/` 两处副本。

约定（见 MODELING_WORKFLOW §8 / §12 与 ASSET_MAP）：
- 逐件导出：导出前把根空物体 location 临时归零，导出后还原；轴心即 root datum
  （火炮 = 耳轴轴心，其余 = 底面中心）；
- 只导出该集合内的对象（root / socket / mesh），不导相机、灯光、其它资产；
- glTF 默认 +Y 向上，进入 Godot 后尺寸为 (Blender X, Blender Z, Blender Y)；
- 覆盖前把旧 GLB 备份到 `.design/kits/backup_glb/`；
- 贴图外部化复用 `glb_shared_textures.externalize_glb(..., prefer_authored=True)`；
- 本批不登记 Core manifest 键，只交付资产副本；
- 全部导出后保存工作台 `.design/SN_Asset_Workbench.blend`。

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")

模块索引：[tools](../../README.md)
