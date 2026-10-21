# `tools/modeling/generators/sn_crane_materials.py`

> 作用：起重机四件套的**共享贴图材质视图**（纯 Python，不 import bpy）：材质名 →

- 类型：项目配置/数据文件

线性回退色 / 粗糙度 / 金属度、贴图 / tile_m / 运行时 URI，以及每件资产的材质白名单。

设计原则：材质与模型分离，贴图与模型分离。
- 真源是 `docs/design/textures/shared_materials/shared_materials.spec.json` 与
  `tools/art/gen_shared_material_textures.py` 产出的 10 张 512² 无缝贴图；
  本模块只从 `sn_shared_materials` 读取参数，不另存一份颜色。
- 材质名用 `SN_Tex_*`：旧资产的 `SN_Metal` / `SN_Wood` 等**纯色材质被 160+ 个旧对象共用**，
  不能原地改成贴图；新资产用 `SN_Tex_*` 贴图材质，旧资产完成 UV 迁移后再逐批切换。
- Blender 侧由 `sn_shared_materials.apply_collection()` 写节点树与 UV；`assembly`
  只负责建对象 / 材质槽，不再决定最终材质外观。
- `ASSET_MATERIALS` 是验收白名单：干跑、GLB 自检与 Godot 验收都按它核对。
- 改颜色 / 贴图只改 spec 与贴图生成器，几何代码与生成器不动。

模块索引：[tools](../../README.md)
