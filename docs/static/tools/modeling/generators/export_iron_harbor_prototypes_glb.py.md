# `tools/modeling/generators/export_iron_harbor_prototypes_glb.py`

> 作用：批次 B 的 Blender 侧导出器：把工作台 y=200 / y=225 两排的三栋新原型（LOD0 + LOD1）逐件导出为单对象、根节点归零、内嵌贴图的 GLB 候选，并输出 tri/尺寸/材质槽/cell 报告；随后由 `glb_shared_textures.py` 外部化为共享贴图并安装进内容模组。

- 类型：项目配置/数据文件

### 契约与约束
- Blender 单写者：只在 Verifier 通过后由 Lead 在 live 工作台执行；不删改其它对象/集合（y=110/150/175 的 A 批 10 个对象、y=200 的三栋 LOD0 只在导出时临时归零位置，导出后恢复）。
- 每栋导出前按栋重写 `sn_iron_harbor_materials.apply_to_object(obj, cells=...)`：6 个 `SN_Town_*` 是全局 datablock，最后一栋的 cells 会覆盖全部。
- 候选写 `.design/buildings/iron_harbor/b4/embedded/`，不直接写内容 mod；旧内容 GLB 先备份到 `b4/legacy/`（不覆盖已有备份），`restore_legacy()` 可回滚。
- LOD0 的 tri 必须精确等于 §6 验收表（BH 7 388 / WR 7 312 / BT 9 376）；LOD1 只校验硬上限 2 800 / 2 800 / 4 900（精确值由 Builder 的 LOD1 报告提供后可在 EXPECTED 里补）。
- 导出后 `report_candidates()` 用 GLB 自身解析结果对账：单根节点、tri、内嵌贴图名、Godot 空间包围盒（Y-up，与 accessor 一致）与 Blender 本地包围盒一致。
- `save_workbench()` 只在人工验收后调用：先备份旧 `.blend` 再保存。

模块索引：[tools](../../README.md)
