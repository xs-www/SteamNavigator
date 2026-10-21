# `tools/modeling/generators/sn_weapon_materials.py`

> 作用：舰载武器五件套的**共享贴图材质视图**（纯 Python，不 import bpy）：材质名常量、

- 类型：项目配置/数据文件

线性回退色 / 粗糙度 / 金属度、贴图 / tile_m / 运行时 URI，以及每件武器的材质白名单。

设计原则与起重机批一致：材质与模型分离、贴图与模型分离；真源是
`docs/design/textures/shared_materials/shared_materials.spec.json`，Blender 侧由
`sn_shared_materials.apply_collection()` 写节点树与世界空间盒式 UV。
本模块只给几何生成器提供 `MAT_*` 常量与每件资产的白名单，不另存颜色。

模块索引：[tools](../../README.md)
