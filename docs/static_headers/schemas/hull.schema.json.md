作用：hull 内容类型（`schemas/hull.schema.json`）的 1.0 JSON Schema 契约：船体定义 = `common.schema.json#/$defs/module_common` + 船体字段（速度 / 载重 / 耐久 / 槽位 / size_tag），2026-10-22 新增 `$defs/rig_plan` 运行时帆索装配计划。

## 契约与约束

- `$defs/hull_data` 必填 `base_speed / max_weight / max_durability / cargo_slots / cabin_slots / base_risk`；`size_tag` ∈ small/medium/large；`additionalProperties` 由 `module_common` 放开，因此新增字段必须同时补 schema 才能被契约文档记录。
- `$defs/rig_plan`（2026-10-22，切片 `ship-visual-assembly`）：
  - `kind` 必填，`sail`（帆船桅套件族）或 `steam`（蒸汽船桅套件族）；
  - `mount_kinds` 可选，`mast` / `yard` / `sail` 子集，缺省 `[mast]`；只声明实测与烘焙件 1:1 吻合的类型；
  - `hide_nodes` 可选，被套件替换的 GLB 烘焙节点名（最多 64 项），装配成功后才隐藏；
  - `mast_asset` / `yard_asset` / `sail_asset` / `per_mast_assets` 是 **manifest 资源键**（`model.rig.*`），不是物理路径，由 `ShipVisualPlan` 经 `AssetService.find_key()` 解析；
  - `yaw_deg` 可选，套件绕 socket 局部 +Y 的附加旋转。
- 缺省（无 `rig_plan`）= 保留 GLB 内烘焙帆索（运行时 `rig.mode=baked`）；schema 只校验键的形状与取值，不校验资源是否存在。
- 船体侧 socket 名与 extras 的唯一真源仍是 GLB（`SN_Socket_Mast/Yard/Sail_*` / `SN_Socket_Weapon_*`），本 schema 不重复定义 socket 列表。
- 修改本 schema 或 Core 内容后按项目流程重跑 `node tools/gen_static_docs.mjs` 与 `node tools/gen_content_types.mjs --check`。
