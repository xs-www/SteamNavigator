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
- 修改本 schema 或 Core 内容后按项目流程重跑 `node tools/gen_static_docs.mjs` 与 `node tools/gen_content_types.mjs --check`。
