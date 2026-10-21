# `tools/modeling/generators/sn_rig_materials.py`

> 作用：船体帆索部件库 `rig_kit` 套件（12 件 `SN_Rig_*`）的**共享贴图材质视图**

- 类型：项目配置/数据文件

（纯 Python，不 import bpy）：材质名常量、每件资产的材质白名单与回退色。

与 `sn_kit_materials.py` 同构：材质真源是
`docs/design/textures/shared_materials/shared_materials.spec.json`；Blender 侧由
`sn_shared_materials.apply_collection()` 写节点树与盒式 UV。本模块只提供
`MAT_*` 常量、白名单与 `colors_for()`，不另存颜色。

模块索引：[tools](../../README.md)
