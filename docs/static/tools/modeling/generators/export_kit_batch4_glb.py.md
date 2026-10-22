# `tools/modeling/generators/export_kit_batch4_glb.py`

> 作用：模型素材库批次 4（M1-1 architecture_kit 扩展，6 件建筑可拼装件）的 GLB

- 类型：项目配置/数据文件

归档导出与运行时副本同步；沿用批次 1–3 的导出 / 贴图外部化 / Core 同步模式。

数据源：`kit_batch4_generator.py`（本批唯一生成器）的 `ASSETS` / `SPECS` /
`build_config(asset)` / `WORKBENCH_POS`；工单见
`tools/modeling/briefs/sn_kit_batch4_architecture_extension.json`。

约定（见 MODELING_WORKFLOW §8 / §12 与 ASSET_MAP）：
- 逐件导出：导出前把根空物体 location 临时归零，导出后还原；轴心即 root datum
  （全部为地面件，根在体量底面中心，zmin=0）；
- 只导出该集合内的对象（root / socket / mesh），不导相机、灯光、其它资产；
- glTF 默认 +Y 向上，进入 Godot 后尺寸为 (Blender X, Blender Z, Blender Y)；
- 覆盖前把旧 GLB 备份到 `.design/architecture/backup_glb/`（仅旧文件存在时）；
- 贴图外部化复用 `glb_shared_textures.externalize_glb(..., prefer_authored=True)`，
  URI 写 `shared_materials/<texture>.png`；
- 同步 `assets/models/architecture/` 与
  `dev_mods/core/assets/models/architecture/` 两处 GLB 副本，并把共享贴图
  （`sn_shared_materials.texture_report()` 的 11 张授权 tile）补齐到两处
  `shared_materials/`；
- 全部导出后保存工作台 `.design/SN_Asset_Workbench.blend`。

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")

模块索引：[tools](../../README.md)
