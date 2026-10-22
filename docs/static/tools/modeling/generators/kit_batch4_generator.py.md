# `tools/modeling/generators/kit_batch4_generator.py`

> 作用：模型素材库批次 4（M1-1：architecture_kit 扩展 / 可围合基地建筑件）的参数化

- 类型：项目配置/数据文件

生成器与 Blender 装配入口。

6 件模块化资产：SN_Arch_Perimeter_Wall（围墙段）/ Gate（大门门楼）/ Road（道路段）/
Loading_Platform（装卸平台）/ Warehouse_Variant（仓库变体）/ Workshop_Annex（工坊扩建）。
沿用 kit 批次 1–3 的契约：每件 Root + Mount 空节点 + 语义接口（Module_Next/Prev、
Wall_Top、Gateway、Door_Hinge_L/R、Hoist、Dock_Edge、Stair_Foot、Drive_Shaft、
Chimney、Coal_Hatch、Sign…），Root extras 写 kit_family / part_role / datum /
module_x/y / module_grid / base_footprint / envelope / height / tri_budget。

工单：`tools/modeling/briefs/sn_kit_batch4_architecture_extension.json`
约定：1 unit = 1 m；+X 前向、+Z 向上；全部为地面件，根在体量底面中心（zmin=0）。
材质：共享贴图 `SN_Tex_*`（本批不新增贴图），见 `sn_kit_materials.py`；
UV 由 `sn_shared_materials.apply_collection()` 按世界空间盒式投影写入。
立面工具（_face_box / _slab / _window / _door / _gable_roof / _chimney / _rivets）
直接复用批次 3 生成器，保证与既有 4 栋建筑同一套低模语言。

用法：
- Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
- 纯 Python 干跑：`python tools/modeling/generators/dryrun_kit_batch4.py`
- 导出 GLB：`python tools/modeling/generators/export_kit_batch4_glb.py`

模块索引：[tools](../../README.md)
