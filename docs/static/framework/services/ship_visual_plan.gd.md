# `framework/services/ship_visual_plan.gd`

> 作用：把「当前船体 + Core 内容」解析成舞台可直接执行的视觉装配计划（hull GLB 物理路径、rig_kit 替换计划、武器 loadout 路径），让表现层只消费路径、不读注册表，也不写死任何 core 内容 ID 或资产键。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ShipVisualPlan` | L14 |
| `RIG_KINDS` | L17 |
| `empty() -> Dictionary` | L21 |
| `empty_rig() -> Dictionary` | L31 |
| `resolve(hub: RegistryHub, assets: AssetService, ship: Dictionary) -> Dictionary` | L48 |
| `resolve_rig(hull: ContentDefinition, assets: AssetService, warnings: Array[String]) -> Dictionary` | L79 |
| `resolve_weapons(assets: AssetService, ship: Dictionary, warnings: Array[String]) -> Dictionary` | L139 |
| `resolve_asset(assets: AssetService, key: String) -> String` | L174 |

- 关键依赖：`RegistryHub`（hull 定义）、`AssetService`（`find_key` / `resolve`）、Core `manifest.json` 的 `model.ship.*` / `model.rig.*` / `model.weapon.*` 键与 `hulls.json` 的 `data.rig_plan`

## 契约与约束
- 只读：不写 GameState、不注册命令/查询；缺 hull / 缺 rig_plan / 缺资源键都返回可执行的最小计划 + `warnings`，不抛错。
- `rig.mode` 只有 `replace`（内容声明了 `data.rig_plan`）与 `baked`（保留 GLB 内焊死帆索）两种。`replace` 计划里**任一必需套件解析不到**都会整体降级为 `baked`，避免「隐藏了烘焙桅却没装上套件」的空船。
- 资源键一律走 `AssetService.find_key()`（裸键 → 第一个声明该键的已挂载模组）再 `resolve()`；也接受 `res://` / `user://` 直接路径。`asset://` 前缀视为调用方已完成 find_key。
- 武器 loadout 是表现数据：`ship.weapon_loadout`（Array[Dictionary] 或 socket→asset 字典）优先，其次 `ship.weapons`；这里只解析 socket 名与路径，class 门禁在装配层（`ShipWeaponAssembly`）。
- 本类是纯数据；节点装配在 `framework/ui/stages/ship_visual_assembler.gd`。

模块索引：[framework/services](./README.md)
