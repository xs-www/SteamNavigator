# `framework/tests/cases/test_ship_visual_assembler.gd`

> 作用：守护运行时整船装配层（`ShipVisualPlan` / `ShipVisualAssembler` / `ShipRigAssembly`）与 Core 内容契约：4 艘船的 hull/rig 计划解析、rig_kit 挂接与烘焙节点替换、武器 class 门禁、缺 socket / 缺套件 / 缺 hull 的回退，以及「同一计划重复装配得到相同节点树」的确定性。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SHIPYARD_STAGE_SCENE` | L15 |
| `PORT_STAGE_SCENE` | L16 |
| `HULL_IDS` | L18 |
| `PF_MAST_NODES` | L25 |
| `PF_YARD_NODES` | L26 |
| `SF_MAST_NODES` | L27 |
| `test_plan_resolves_rig_plans_for_the_four_core_hulls() -> void` | L66 |
| `test_plan_normalises_the_weapon_loadout_and_reports_missing_assets() -> void` | L101 |
| `test_assembler_builds_all_four_hulls_with_stable_rig_nodes() -> void` | L134 |
| `test_assembler_is_deterministic_for_the_same_plan() -> void` | L176 |
| `test_rig_mount_aligns_sn_mount_with_the_socket_frame() -> void` | L193 |
| `test_weapon_loadout_enforces_the_socket_class_gate() -> void` | L233 |
| `test_assembler_falls_back_to_the_prototype_when_the_hull_is_missing() -> void` | L292 |
| `test_assembler_keeps_the_baked_rig_when_a_kit_asset_is_missing() -> void` | L319 |
| `test_assembler_reports_missing_rig_sockets_without_crashing() -> void` | L342 |
| `test_shipyard_stage_assembles_the_planned_ship_and_keeps_the_legacy_path() -> void` | L371 |
| `test_port_stage_assembles_and_batches_the_planned_player_ship() -> void` | L393 |

## 契约与约束
- 计划解析用真实 `bootstrap_core()` 的 `RegistryHub` + `AssetService`，验证 Core manifest 资源键（`model.ship.*` / `model.rig.*` / `model.weapon.*`）与 `hulls.json` 的 `data.rig_plan` 真的能驱动装配，不在测试里写死物理路径。
- 装配在真实 SceneTree 根下的临时 holder 中进行，`global_transform` 与游戏一致；每个用例结尾释放 holder。
- 断言 rig 替换是「全有或全无」：任一套件缺失 → `rig.mode=baked` 且原船烘焙节点仍在；全部成功 → `hide_nodes` 名单里的节点必须消失、`Rig_*` 节点数量与 socket 数一致。
- 武器只做逐件门禁：class 匹配即挂载（净空是软判定），class 不匹配 / `Modular` kit 件 / 缺 socket 只跳过并记录，不影响 rig。
- 确定性断言比较两次装配的 `snapshot()` 数组（路径 + 量化 1e-4 变换），以及 `report.rig.mounted` 的字符串字段。
- 测试不写 GameState、不依赖存档；GLB 通过 `ShipVisualAssembler.instantiate_model()` 加载（与游戏同一路径）。

模块索引：[framework/tests](../README.md)
