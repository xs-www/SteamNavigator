# `tools/modeling/generators/sn_kit_materials.py`

> 作用：模型素材库（批次 1 武器套件/船体部件 + 批次 2 机械/货物/码头套件 +

- 类型：项目配置/数据文件

批次 3 建筑/环境套件）的**共享贴图材质视图**（纯 Python，不 import bpy）：
材质名常量、每件资产的材质白名单与回退色。

与 `sn_weapon_materials.py` 同构：材质与模型分离、贴图与模型分离；真源是
`docs/design/textures/shared_materials/shared_materials.spec.json`，Blender 侧由
`sn_shared_materials.apply_collection()` 写节点树与世界空间盒式 UV。
本模块只给几何生成器提供 `MAT_*` 常量与每件资产的材质白名单，不另存颜色。
批次 2 新增 `SN_Tex_Coal`（碎煤），用于煤斗 / 煤堆；批次 3 不新增贴图。

模块索引：[tools](../../README.md)
