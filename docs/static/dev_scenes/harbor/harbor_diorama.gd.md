# `dev_scenes/harbor/harbor_diorama.gd`

> 作用：港口样片根脚本：运行时给码头石墙套更暗的复制材质，压住黄昏逆光下的高光。

- 类型：GDScript 源文件

## 契约与约束

- 只改本场景实例的 `surface_material_override`，不改 GLB 导入材质。
- 依赖 `SN_Dock_Wall` 的表面顺序：surface 0 = `SN_Stone`；改 GLB 材质顺序时需同步 `STONE_SURFACE`。

模块索引：[dev_scenes](../README.md)
