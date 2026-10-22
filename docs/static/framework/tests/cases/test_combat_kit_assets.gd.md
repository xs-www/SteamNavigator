# `framework/tests/cases/test_combat_kit_assets.gd`

> 作用：`combat_kit` 敌舰套件（M2-1，4 艘 `SN_Enemy_*.glb`）的运行时守护用例：资产必须

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `COMBAT_DIR` | L29 |
| `WEAPON_SOCKET_PREFIX` | L30 |
| `GUN_PORT_PREFIX` | L31 |
| `COMBAT_KIT_SPEC` | L32 |
| `SOCKET_SPEC` | L33 |
| `GUN_PORT_SPEC` | L34 |
| `IRONCLAD` | L35 |
| `TOTAL_TRIS` | L36 |
| `GUN_PORT_NAMES` | L38 |
| `SHIPS` | L46 |
| `test_combat_kit_glbs_load_with_expected_geometry() -> void` | L102 |
| `test_combat_kit_surfaces_use_uvs_and_shared_textures() -> void` | L122 |
| `test_combat_kit_glb_materials_are_double_sided_shared_textures() -> void` | L149 |
| `test_combat_kit_root_extras_and_weapon_sockets_match_the_contract() -> void` | L169 |
| `test_ironclad_gun_ports_match_the_contract() -> void` | L253 |

能从 `res://dev_mods/core` 真实加载，且几何 / 材质 / socket 契约与生成器
`tools/modeling/generators/combat_kit_generator.py` 的交付口径一致。

## 覆盖范围
- **加载 + 几何**：4 个 GLB 均能经 `ContentAssetLoader.load_scene()` 加载；每艘
  mesh 节点数与三角面总数与常量一致（总 31,324 tri；逐艘 8,678 / 11,746 / 7,440 / 3,460）。
  口径：tri = 每个 surface 的 index 数 / 3（= Blender loop triangles，n-gon 三角化），
  与 `combat_kit_generator.report(asset)["tris"]` / `verify_combat_kit_glb.py` 完全一致；
  mesh 数 = 生成器对象数 `report(asset)["objects"]`（多节点船，root 不是单 mesh）。
  若最终导出因生成器改动而变化，需同时更新本表、`verify_combat_kit_glb.py` 与 catalog。
- **UV / 材质 / 外部贴图**：每个 surface 有 UV；材质名 `SN_Tex_*`、`albedo_texture`
  非空；`ContentAssetLoader.material_image_uris()` 返回的每个 URI 都是
  `shared_materials/<texture>.png` 且对应外部 PNG 文件存在（共享贴图外部化契约）。
- **GLB JSON 结构**：root extras（`asset` / `combat_kit="enemy-ships@1"` /
  `enemy_class` / `enemy_archetype` / `weapon_sockets` / `weapon_socket_count` /
  `socket_spec="hull-sockets@1"`）；4 艘武器 socket 数 3 / 6 / 4 / 3，名字有序、是
  root 直接子节点、无 mesh、`socket_class` / `clearance_*` / `mount_scale` 齐备；
  铁甲舰 8 个 `SN_Socket_GunPort_*`（每舷 4 个）与 root `gun_port_sockets` 名单，
  契约 `hull-gunports@1`；节点名无 Blender `.001` 后缀、无重名。

生成器 / 导出链：`combat_kit_generator.py` → `export_combat_kit_glb.py` →
`glb_enemy_sockets.normalize()` → `assets/models/combat/` + `dev_mods/core/...`。
静态验收（不进 Godot）：`python tools/modeling/generators/verify_combat_kit_glb.py`。

模块索引：[framework/tests](../README.md)
