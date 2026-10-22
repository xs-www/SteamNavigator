# `framework/tests/cases/test_lod1_assets.gd`

> 作用：LOD1 基础套件（M0-5）的资产守护用例：30 个 `SN_*_LOD1.glb`（kit 26 + 船 4）

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `KIT` | L13 |
| `SHIPS` | L29 |
| `CAP_RATIO` | L33 |
| `EXPECTED_TRIS` | L34 |
| `EXPECTED_LOD0_TRIS` | L35 |
| `MANIFEST_LOD1` | L36 |
| `CORE_ROOT` | L42 |
| `test_lod1_assets_load_as_single_mesh_with_shared_textures() -> void` | L45 |
| `test_lod1_assets_within_budget_and_match_lod0_bounds() -> void` | L79 |
| `test_lod1_ship_manifest_keys_resolve() -> void` | L107 |

必须能从 `dev_mods/core` 运行时加载，单 mesh、每个 surface 有 UV、材质全是
`SN_Tex_*` 且绑定外部 `shared_materials/<texture>.png`；LOD1 三角面必须 ≤ 对应 LOD0
的 35%（kit）/ 30%（船），且与 LOD0 世界包围盒逐轴 ≤0.05 m；4 个船的
`model.ship.*_lod1` manifest 键必须存在并指向真实文件。

这组用例守护的是「远景低模套件可在 Godot 里被真实加载」，不验证运行时 LOD 切换
（本批为资产交付，切换属于后续接线）。

模块索引：[framework/tests](../README.md)
