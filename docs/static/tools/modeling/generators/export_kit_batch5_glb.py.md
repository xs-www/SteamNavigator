# `tools/modeling/generators/export_kit_batch5_glb.py`

> 作用：模型素材库批次 5（M1-2 base_kit 生产建筑，5 件）的 GLB 归档导出与运行时副本

- 类型：项目配置/数据文件

同步；沿用批次 1–4 的导出 / 贴图外部化 / Core 同步模式。

数据源：`kit_batch5_generator.py`（本批唯一生成器）的 `ASSETS` / `SPECS` /
`build_config(asset)` / `WORKBENCH_POS`；工单见
`tools/modeling/briefs/sn_kit_batch5_base_kit.json`。

约定（见 MODELING_WORKFLOW §8 / §12 与 ASSET_MAP）：
- 逐件导出：导出前把根空物体 location 临时归零，导出后还原；轴心即 root datum
  （全部为地面件，根在体量底面中心，zmin=0）；
- 只导出该集合内的对象（root / socket / mesh），不导相机、灯光、其它资产；
- glTF 默认 +Y 向上，进入 Godot 后尺寸为 (Blender X, Blender Z, Blender Y)；
- 覆盖前把旧 GLB 备份到 `.design/base/backup_glb/`（仅旧文件存在时）；
- 贴图外部化复用 `glb_shared_textures.externalize_glb(..., prefer_authored=True)`，
  URI 写 `shared_materials/<texture>.png`；
- base 是新类别目录：GLB 落 `assets/models/base/` 并同步
  `dev_mods/core/assets/models/base/`，共享贴图
  （`sn_shared_materials.texture_report()` 的 11 张授权 tile）补齐到两处
  `shared_materials/`；`shared_materials.spec.json` 已登记这两条 runtime_dirs；
- 全部导出后保存工作台 `.design/SN_Asset_Workbench.blend`。

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")

模块索引：[tools](../../README.md)
