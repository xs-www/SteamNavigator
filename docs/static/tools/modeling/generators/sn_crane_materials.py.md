# `tools/modeling/generators/sn_crane_materials.py`

> 作用：起重机四件套的**共享材质库**（纯 Python，不 import bpy）：材质名 → 线性色 /

- 类型：项目配置/数据文件

粗糙度 / 金属度，以及每件资产允许使用的材质白名单。

设计原则：材质是与几何分离的真源。四个生成器只引用这里的材质名与参数表，
不各自维护颜色；Blender 侧由 `ship_parts.assembly._ensure_material()` 按名字
复用工作台里的共享 datablock（不存在时才用这里的参数新建），因此四台起重机
以及既有的船 / 道具 / 建筑共享同一套 `SN_*` 材质，不会因为新资产而复制材质。

- 不新增材质：只使用工作台调色板里已有的 10 个 `SN_*` 材质。
- 材质参数是**线性空间**值（与 Blender Principled Base Color 一致）。
- `ASSET_MATERIALS` 是验收白名单：干跑与 GLB 自检都按它核对每件资产。
- 改颜色只改这一处；生成器与 GLB 重新导出即可，不需要动几何代码。

模块索引：[tools](../../README.md)
