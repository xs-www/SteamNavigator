# `framework/tests/cases/test_ship_weapon_assembly.gd`

> 作用：守护运行时武器装配层（`ShipWeaponAssembly` / `ShipWeaponMount`）与契约 v2 / M0-3 船体安装点：socket 发现与排序、武器 Root extras 读取、class 硬门禁、`SN_Mount` 精确对齐、`mount_scale`、机制节点与多联装、瞄准 / 后坐轴、净空软判定（socket 局部实测、非 envelope / base_footprint）以及 `clear_mounted`。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `HULLS_DIR` | L32 |
| `WEAPONS_DIR` | L33 |
| `SOCKET_PREFIX` | L34 |
| `MOUNT_NAME` | L35 |
| `SOCKET_SPEC` | L36 |
| `ASSEMBLY_SPEC` | L37 |
| `HULL_SOCKETS` | L40 |
| `WEAPON_EXPECTED` | L79 |
| `test_find_sockets_returns_declared_sockets_in_index_order() -> void` | L117 |
| `test_socket_info_exposes_contract_fields_and_safe_defaults() -> void` | L163 |
| `test_weapon_root_and_info_read_the_assembly_extras() -> void` | L205 |
| `test_class_gate_rejects_mismatches_and_modular_parts() -> void` | L257 |
| `test_mount_aligns_sn_mount_exactly_with_the_socket() -> void` | L327 |
| `test_mount_scale_scales_the_weapon_geometry() -> void` | L390 |
| `test_mount_scale_halves_the_reported_clearance_extents() -> void` | L436 |
| `test_mechanism_nodes_follow_the_standard_names() -> void` | L470 |
| `test_multi_muzzle_broadside_moves_every_muzzle() -> void` | L503 |
| `test_aim_yaw_moves_muzzle_and_positive_pitch_raises_it() -> void` | L549 |
| `test_recoil_moves_along_negative_x_and_is_absolute() -> void` | L600 |
| `test_clearance_report_is_soft_and_uses_the_pad_not_envelope() -> void` | L652 |
| `test_clear_mounted_frees_every_weapon_on_the_hull() -> void` | L736 |
| `test_arrow_tower_pairs_with_no_hull_socket() -> void` | L776 |

## 契约与约束
- 资产用 `ContentAssetLoader.instantiate_model()` 读 4 艘船与 8+1 件武器原始 GLB，挂到 SceneTree 根下的临时 holder，保证 `global_transform` 与实际游戏一致；每个测试自建 / 释放 holder。
- class 是唯一硬门禁：class 匹配必定装配成功（即使净空 `fits=false`），class 不匹配、`Modular` kit 件、缺 `SN_Mount` 返回 `null` 并释放实例。
- 对齐断言用 0.001 m / 角度容差；`mount_scale=0.5` 必须让 socket 局部 pad 与 height 同步减半（防空/防未缩放回归）。
- 净空口径锁定 §8.3：pad 排除 pitch/recoil 子树、在 socket 帧实测；F1 陷阱（`base_footprint_*` = envelope）用正向用例守死：DeckGun / HeavyCannon 能装进 clearance 较小的 socket。
- 测试不依赖场景 / UI / 存档；不写 GameState。注册在 `framework/tests/test_runner.gd` 的 `SUITE_PATHS`。

模块索引：[framework/tests](../README.md)
