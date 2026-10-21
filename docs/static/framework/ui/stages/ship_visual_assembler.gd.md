# `framework/ui/stages/ship_visual_assembler.gd`

> 作用：`ShipVisualAssembler` —— 运行时把一条船拼成可见的整船：实例化船体 GLB，按船体 Root `SN_Socket_Mast/Yard/Sail_*` 挂 rig_kit 套件（并隐藏被替换的烘焙节点），再按 `SN_Socket_Weapon_*` 挂武器；返回装配根、可读报告与确定性快照，供船厂 / 港口 / 航行演出共用。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ShipVisualAssembler` | L15 |
| `FALLBACK_HULL_PATH` | L18 |
| `assemble(plan: Dictionary, parent: Node3D, options: Dictionary = {}) -> Dictionary` | L24 |
| `empty_report() -> Dictionary` | L58 |
| `instantiate_model(path: String, options: Dictionary = {}) -> Node3D` | L82 |
| `hull_asset_of(visual: Node) -> String` | L110 |

- 关键依赖：`framework/services/content_asset_loader.gd`（原始 GLB 加载）、`framework/services/ship_visual_plan.gd`（输入计划）、`framework/ui/stages/ship_rig_assembly.gd`（rig 规则）、`framework/ui/stages/ship_weapon_assembly.gd`（武器规则）

## 契约与约束
- 输入是**已解析路径**的计划（`ShipVisualPlan.resolve()` 的结果），本类不读注册表、不写 GameState；装配结果是纯表现节点。
- 回退优先级：hull 路径加载失败 → 计划里的 fallback 路径 / `SN_Ship_Prototype` → 返回 `visual=null`（舞台保留自己的 2D 占位），任何一步都不抛错。
- rig 是**全有或全无**：计划声明的挂件只要有一件缺 socket / 缺 GLB / 加载失败，就整体放弃 rig 替换、保留原船（`rig.mode=baked`、`fallback=rig_mount_failed`），绝不出现「烘焙桅被隐藏但套件没装上」的空船。全成功后按 `hide_nodes` 移除烘焙件。
- 武器是**逐件尽力**：单个 socket 缺模型 / class 不匹配 / 缺 `SN_Mount` 只跳过该件并记录原因，不影响 rig 与其它武器（class 门禁见 `WEAPON_SOCKET_CONTRACT` §5）。
- 节点命名稳定可断言：`Rig_<kind>_<socket>`、`Rig_<kind>_<socket>_<asset>`、`Weapon_<socket>`；同一计划重复装配得到相同 `snapshot()`（量化 1e-4）。
- 顺序确定：socket 按 `ShipRigAssembly.find_sockets()` / `ShipWeaponAssembly.find_sockets()` 的 `socket_index → name` 排序，loadout 按计划数组顺序。

模块索引：[framework/ui](../README.md)
