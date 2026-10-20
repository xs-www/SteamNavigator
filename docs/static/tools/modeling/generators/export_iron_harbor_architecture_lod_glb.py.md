# `tools/modeling/generators/export_iron_harbor_architecture_lod_glb.py`

> 作用：批次 A 的 Blender 侧导出器：把工作台里 5 栋 LOD0 + 5 栋 LOD1 逐件导出为单对象、根节点归零、内嵌贴图的 GLB 候选，并输出逐件 tri/尺寸/材质槽/cell/结构报告；后续由 `glb_shared_textures.py`（纯 Python、Blender 外）统一外部化共享贴图并安装进内容模组。

- 类型：项目配置/数据文件

### 契约与约束
- Blender 单写者：只在 Verifier 通过后由 Lead 在 live 工作台执行；不删改其它对象与集合。
- 每栋导出前必须重新 `sn_iron_harbor_materials.apply_to_object(obj, cells=...)`：6 个 `SN_Town_*` 材质是全局 datablock，最后一栋的 cells 会覆盖全部（BATCH2 §3 坑）。
- 导出用 `use_selection + 根节点临时归零 + export_yup`；导出后恢复 location/选择/active；候选写 `.design/buildings/iron_harbor/a4/embedded/`，不直接写内容 mod。
- 旧内容 GLB 先备份到 `.design/buildings/iron_harbor/a4/legacy/`（不覆盖已有备份），`restore_legacy()` 可回滚。
- `save_workbench()` 只在人工验收后调用：先备份旧 `.blend` 再保存 `.design/SN_Asset_Workbench.blend`。
- `report_candidates()` 用 GLB 自身解析结果对账：tri 必须等于验收表、单根节点、内嵌贴图、bbox 与 Blender 本地包围盒一致。

模块索引：[tools](../../README.md)
