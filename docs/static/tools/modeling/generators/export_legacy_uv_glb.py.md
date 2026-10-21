# `tools/modeling/generators/export_legacy_uv_glb.py`

> 作用：旧资产 UV 迁移 A 的 GLB 归档导出（验收通过后由 Lead 在 Blender 内执行）——

- 类型：项目配置/数据文件

逐件导出 31 件铁港道具 + 6 件港口设施，把 GLB 内嵌贴图外部化为
`shared_materials/<texture>.png` 共享 URI，旧 GLB 备份到 `.design/legacy_uv/backup_glb/`，
并把 GLB + 共享贴图同步到 `dev_mods/core` 副本，最后保存工作台。

约定（见 docs/design/MODELING_WORKFLOW.md 第 8 节）：
- 迁移必须已由 `sn_legacy_uv_migration.migrate_all()` 完成并通过 `verify_scene()`；
- 逐件导出：导出前把 `object.location` 临时归零（轴心 = 底面中心）、只选该对象，导出后还原；
- glTF 默认 +Y 向上；每个 .glb 只含一个网格节点；
- 贴图外部化复用 `glb_shared_textures.externalize_glb(..., prefer_authored=True)`：
  共享 PNG 使用 `docs/design/textures/shared_materials/tiles/` 的授权源字节；
- props / port 各自持有一份 `shared_materials/` 运行时副本（与现有分类目录约定一致）；
- 全部导出后保存 `.design/SN_Asset_Workbench.blend`，报告写
  `.design/legacy_uv/export_report.json`（本地产物）。

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")
或后台：
    blender -b .design/SN_Asset_Workbench.blend -P tools/modeling/generators/export_legacy_uv_glb.py

模块索引：[tools](../../README.md)
