# `tools/modeling/generators/sn_legacy_uv_migration.py`

> 作用：旧资产 UV 迁移（A/B 两批）的核心模块 —— 把旧纯色 `SN_*` 材质按固定映射换成

- 类型：项目配置/数据文件

`SN_Tex_*` 共享贴图材质，并用盒式投影补 `UVMap`（几何、轴心、对象变换一律不动），
同时提供几何签名对比与只读验收。

范围（见 docs/design/MODELING_BACKLOG.md）：
- 批次 A（M0-1）：`SN_IronHarbor_Props` 31 件道具 + `SN_Port_Facilities` 6 件设施；
- 批次 B（M0-2）：11 件船模块 + modules/SN_Boiler_Unit 占位副本 + 4 艘船 + 旧小镇
  剩余 5 件（Fence_Row / Dock_Worker_A/B / Rowboat / Cargo_Lighter；另 5 栋旧小镇
  建筑已在建筑套件批次用 `SN_Town_*` 图集完成，不重复迁移）。

关键契约：
- 材质映射覆盖两批旧资产实际用到的旧名；`SN_Ore` → `SN_Tex_Iron_Red`（锈红铁矿色），
  `SN_Canvas` / `SN_Canvas_Shade` → 唯一 `SN_Tex_Canvas_Shade`；
  船体旧名：`SN_Iron_Hull` / `SN_Hull_Black` → `SN_Tex_Iron`（黑船身保留深色读感）、
  `SN_Ochre` → `SN_Tex_Wood_Deck`、`SN_White` / `SN_PS_UpperWhite` → `SN_Tex_Canvas_Shade`、
  `SN_Flag_Red` → `SN_Tex_Iron_Red`、`SN_Flag_White` → `SN_Tex_Canvas_Shade`、
  `SN_Flag_Blue` → `SN_Tex_Glass_Dark`。
- UV 空间：单 mesh 道具 / 模块 / 小镇用 `space="local"`；多节点船体用 `space="root"`
  （根节点局部坐标，跨子件连续且不烘入工作台摆位）。
- 迁移前记录几何签名（顶点坐标 + 面顶点索引 + 三角面数 + 对象变换），迁移后必须完全一致；
  任何几何变化都是失败，不允许用"重新生成"掩盖。
- 只改材质槽与 UV 层；材质 datablock 由 `sn_shared_materials.build_materials()` 统一创建，
  贴图真源仍是 `docs/design/textures/shared_materials/shared_materials.spec.json`。

用法（Blender 内，由 Lead 执行）：
  import runpy; ns = runpy.run_path(<本文件>, run_name="__main__")   # 默认批次 A
  ns["migrate_all_b"]()                                              # 批次 B
纯 Python 预检：dryrun_legacy_uv.py（A）/ dryrun_legacy_uv_b.py（B）

模块索引：[tools](../../README.md)
