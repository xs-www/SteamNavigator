# `tools/modeling/generators/dryrun_lod1_kit_ships.py`

> 作用：LOD1 基础套件（M0-5）的纯 Python 干跑/计划生成：不进 Blender，读取 30 件

- 类型：项目配置/数据文件

LOD0 GLB 的真实世界包围盒与三角面，套用生成器的预算表（kit 30% / 船 25%，硬上限
35% / 30%）算出逐件 target / cap / big_ratio，并把计划落盘到
`.design/lod1_kit_ships/plan.json`；同时校验 LOD0 资产齐全、kit 三角面与
`kit_catalog.json` 一致、船体合计与既有迁移基线一致。

## 契约与约束
- 只读：只写 `.design/lod1_kit_ships/plan.json`，不改 GLB / 工作台 / 内容 JSON。
- LOD0 tri 以 GLB 的 indices 为准（与 `glb_world_bounds.world_bounds` 同源），
  不信任 catalog 手写值；catalog 只用于交叉校验。
- 计划失败（缺资产 / tri 不符 / 预算不可行）返回码 1；成功返回 0。

## 重点逻辑
### `main()`
- 逐件 `world_bounds(lod0_path)` → `budget_plan()`；kit 与 catalog tri 对账，
  ships 与 45 296 合计对账（铁甲舰 LOD0 于 2026-10-22 casemate 批次 8 830 → 8 158）；最后打印逐件表与分组预算。

模块索引：[tools](../../README.md)
