# `tools/modeling/generators/export_legacy_uv_b_glb.py`

> 作用：旧资产 UV 迁移 B 的 GLB 归档导出（验收通过后由 Lead 在 Blender 内执行）——

- 类型：项目配置/数据文件

导出 12 件船模块（11 件专用 + modules 占位副本）、4 艘船、5 件旧小镇剩余道具，
把内嵌贴图外部化为 `shared_materials/<texture>.png`，旧 GLB 备份到
`.design/legacy_uv_b/backup_glb/`，并同步 `dev_mods/core` 副本与共享贴图目录。

导出方式按资产类型区分：
- 单 mesh（模块 / 旧小镇 / 铁甲舰）：逐件 `location` 归零，只导该对象（`export_extras=False`）；
- 多节点船体（明轮货轮 / 明轮客船 / 纵帆船）：根节点归零后导出整个集合
  （`export_extras=True`，保留 Root extras 契约）。

目标目录：
- modules：`assets/models/modules/` + Core 副本；
- ships：`assets/models/ships/` + Core 副本；
- town：只写 `dev_mods/core/assets/models/props/`（旧小镇建筑 GLB 已是建筑套件产物，不覆盖）。

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")

模块索引：[tools](../../README.md)
