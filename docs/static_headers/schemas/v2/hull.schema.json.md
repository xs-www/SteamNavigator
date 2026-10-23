作用：hull 内容类型（`schemas/v2/hull.schema.json`）的 Content Schema 2.0 JSON Schema 契约：船体定义 = 2.0 envelope + `hull_data`（经济 / 航行属性 / 槽位 / 内容侧武器与帆索安装点镜像 / 运行时帆索装配计划）。

## 契约与约束

- `schema_version` 固定 `"2.0"`、`content_type` 固定 `"hulls"`；C1 起类型与 ID 不变，仅升级 envelope 版本。
- `$defs/hull_data` 必填 `tier / weight / purchase_price / base_speed / max_weight / max_durability / cargo_slots / cabin_slots / base_risk`（1.0 的 `module_common` 字段已内联）；`size_tag` ∈ small/medium/large；`additionalProperties: false`，新增字段必须同时补 schema。
- `materials` 是打造材料数组（`{id, amount}`，`id` 为 `items` 完整 ID，例如 `core:item/boiler_plate`）；`modifiers` 为 `{stat, op, value}` 属性修正。
- `$defs/rig_plan`（运行时 `ShipVisualAssembler` 使用）：
  - `kind` 必填，`sail`（帆船桅套件族）或 `steam`（蒸汽船桅套件族）；
  - `mount_kinds` 可选，`mast` / `yard` / `sail` 子集，缺省 `[mast]`；只声明实测与烘焙件 1:1 吻合的类型；
  - `hide_nodes` 可选，被套件替换的 GLB 烘焙节点名（最多 64 项），装配成功后才隐藏；
  - `mast_asset` / `yard_asset` / `sail_asset` / `per_mast_assets` 是 **manifest 资源键**（`model.rig.*`），不是物理路径，由 `ShipVisualPlan` 经 `AssetService.find_key()` 解析；
  - `yaw_deg` 可选，套件绕 socket 局部 +Y 的附加旋转。
- 缺省（无 `rig_plan`）= 保留 GLB 内烘焙帆索（运行时 `rig.mode=baked`）；schema 只校验键的形状与取值，不校验资源是否存在。
- `weapon_sockets` / `rig_sockets` 是**内容侧镜像**（与 GLB `SN_Socket_Weapon_*` / `SN_Socket_Mast/Yard/Sail_*` 节点 extras 同口径）；船体侧 socket 名与 extras 的唯一真源仍是 GLB，运行时装配读 extras。
- `weapon_socket.blueprint` 是**可选**的蓝图坐标：`blueprint.side` / `blueprint.top` 是 JSON Vector2（`[x, y]`），至少提供一个视图；坐标以绑定线稿的左上角为原点并归一化到 `0..1`。它可以由离线投影工具生成，作者只在需要时手工覆盖。
- `weapon_socket.pair` 是可选的对端 socket 名（左右舷同型约束），省略表示独立安装位；成对校验与命令语义由游戏侧实现，schema 只约束命名形状。
- `base_cargo_capacity` 可选，船体自带的初始货舱空间；总货舱容量 = 本值 + Σ(货舱模块 capacity × condition)。
- `blueprint_views` 可选，按 `side` / `top` 绑定线稿资源键（`image`，可选 `width/height/space`）。每个视图的 `space` 决定坐标基准（`trimmed` 裁切后纹理 / `canvas` 未裁切画布）；编辑器（SNModMaker 蓝图槽位编辑器）在此绑定图片并拖动槽位写回坐标。
- `compartments` 可选，船体提供的舱位安装位数组：每项有稳定 `id`、可选 `blueprint_position`、`max_tier` 与 `allowed_types`（省略或空数组 = 全部类型）。数组长度即数量上限。
- `module_slots` 可选，船体提供的模块安装位数组：每项有稳定 `id`、可选 `blueprint_position`、`allowed_categories` 与可选 GLB `socket`（外部模块装配点）。
- 修改本 schema 或 Core 内容后按项目流程重跑 `node tools/gen_static_docs.mjs` 与 `node tools/gen_content_types.mjs --check`；改 schema 还要重跑 `node SNModMaker/tools/sync-schemas.mjs`。
