# `tools/modeling/generators/glb_weapon_nodes.py`

> 作用：武器装配规范 v2 的 GLB 节点名归一化（纯 Python）。

- 类型：项目配置/数据文件

Blender 场景里多件资产并排，`SN_Mount` / `SN_Pivot_Yaw` 这类标准节点名会因
全局对象命名空间被加 `.001` 后缀；生成器因此先写 `<资产前缀>Mount`、
`<资产前缀>Pivot_Yaw` 等唯一名，导出 GLB 后再由本模块把节点名归一化为契约
规定的标准名：`<前缀>Mount` → `SN_Mount`，`<前缀>Pivot_Pitch` →
`SN_Pivot_Pitch`，`<前缀>Muzzle_2` → `SN_Muzzle_2`，甲板的
`<前缀>Socket_Weapon_Port` → `SN_Socket_Weapon_Port`。mesh / Root 名不受影响。

用法：`glb_weapon_nodes.standardize(path)`（导出脚本在 externalize 之后调用）。

模块索引：[tools](../../README.md)
