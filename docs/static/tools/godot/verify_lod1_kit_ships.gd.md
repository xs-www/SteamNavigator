# `tools/godot/verify_lod1_kit_ships.gd`

> 作用：LOD1 基础套件（M0-5）的 Godot 运行时验收探针（只读、无头可跑）：把 30 个

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `CORE_ROOT` | L16 |
| `SHARED_URI` | L17 |
| `CAP_RATIO` | L18 |
| `EXPECTED_TOTAL` | L19 |
| `ASSETS` | L20 |
| `_init() -> void` | L58 |

`dev_mods/core/assets/models/<category>/SN_*_LOD1.glb` 走 `ContentAssetLoader.load_scene()`
真实加载，核对「单 mesh / 每个 surface 有 UV / 材质全是 `SN_Tex_*` 且绑定 albedo
贴图 / 外部 `shared_materials/<texture>.png` 都存在 / 三角面等于验收表」，并汇总
kit 10 824 tri、船 9 026 tri 两组总量。

用法：
  godot --headless --path . --script res://tools/godot/verify_lod1_kit_ships.gd

判定口径：任何一件缺文件 / 加载失败 / 多 mesh / 缺 UV / 缺贴图 / tri 不等于验收表
都记 failure 并以退出码 1 结束；该脚本只验证资产可加载，不验证运行时 LOD 切换。

模块索引：[tools](../README.md)
