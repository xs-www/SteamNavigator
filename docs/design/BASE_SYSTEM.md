# 基地系统（Base System，Phase D3）

> 状态：Draft 1（2026-10-23，D3 运行时 + 最小 UI 落地）。内容契约以
> [schemas/v2/](../../schemas/v2/) 与 [dev_mods/core/content/](../../dev_mods/core/content/) 为准；
> 本文说明运行态形状、命令/查询、tick 生产与验收边界。

## 1. 范围

D3 交付一个可玩的基地纵向切片：

- 在港口占领基地点，建造/升级建筑，雇工与派工；
- 仓储在港口仓库与基地仓储之间转移，容量按物品单位重量计算；
- 生产订单由确定性 tick 推进，成品进入基地仓储；
- 基地维护费、建筑维护费与工资每 tick 结算，欠费时停工；
- 至少一条生产链产出 `material.shipbuilding` 物品（精密齿轮），接入舰队船体建造。

不在本切片：世界地点绑定 / 探索发现、基地防御战斗、失守流亡、跨区调度、3D 基地舞台。

## 2. 内容类型（5 类 active 2.0，capability `content.base.v1`）

| 类型 | 关键字段 | Core 内容 |
| --- | --- | --- |
| `base_sites` | `slot_count` / `storage_capacity` / `maintenance_per_tick` / `defense` / `claim_cost_money` / `starting_workers` / `starting_storage` | 海岸前哨（3 槽）、工业堆场（5 槽） |
| `buildings` | `category` / `build_cost_money` / `build_cost_items` / `build_time_hours` / `worker_slots` / `worker_role` / `upkeep_per_tick` / `storage_capacity` / `defense` / `max_level` / `recipes` | 锯木厂、冶炼炉、铸造车间、仓库堆场、防御塔 |
| `building_upgrades` | `building_ref` / `from_level` / `to_level` / `cost_money` / `cost_items` / `time_hours` / `modifiers` | 5 栋建筑各 1 条 II 级升级 |
| `production_recipes` | `building_ref` / `inputs[]` / `outputs[]` / `duration_hours` / `workers_required` / `money_cost` | 木材、锅炉钢板、精密齿轮 |
| `worker_roles` | `wage_per_tick` / `hire_cost_money` / `speed_bonus` / `skill` | 劳工、冶炼工、工程师 |

`site.schema.json` 增加可选 `base_site_archetype`，Core `site/base_camp` 指向海岸前哨；
世界地点实例绑定留待后续切片。

## 3. 运行态 `data.base`

```json
{
  "site_id": "base",
  "site_archetype_id": "core:base_site/coastal_outpost",
  "port_id": "port_0",
  "buildings": [{
    "instance_id": "bld_1",
    "building_ref": "core:building/sawmill",
    "level": 1,
    "status": "ready",
    "remaining_hours": 0.0,
    "workers": {"core:worker_role/laborer": 2},
    "order": {"recipe_id": "core:production_recipe/timber", "remaining_hours": 1.2, "total_hours": 2.0},
    "upgrade_ref": ""
  }],
  "storage": {"core:item/timber": 6},
  "workers": {"core:worker_role/laborer": 2},
  "next_building": 2,
  "unpaid_ticks": 0,
  "upkeep_debt": 0.0,
  "halted": false
}
```

- 只在 `base.claim` 后存在；`base.view` 对旧档/损坏块只读规范化，不写状态。
- `status`：`building` / `ready` / `upgrading`；建造与升级用 `remaining_hours`。
- 容量 = 站点 `storage_capacity` + 已完工建筑容量 + 升级 `storage_capacity` 修正。
- 防御同理；生产速度 = 升级 `production_speed` 修正乘积 ×（1 + Σ 已派工 `speed_bonus`）。

## 4. 命令与查询

| 命令 | 说明 |
| --- | --- |
| `base.claim {base_site_id}` | 在港占领；唯一基地；扣 `claim_cost_money`，授予起始工人/仓储 |
| `base.build {building_id}` | 占 1 槽；扣金钱 + 基地仓储材料；按 `build_time_hours` 施工 |
| `base.upgrade {instance_id, upgrade_id}` | 要求建筑空闲且 `from_level` 匹配；施工完成后升级 |
| `base.deposit {item_id, amount}` | 港口仓库 → 基地仓储；要求人在基地港、容量足够 |
| `base.withdraw {item_id, amount}` | 基地仓储 → 港口仓库；要求人在基地港 |
| `base.hire_worker {role_id, amount}` | 扣 `hire_cost_money`，进入待派工池 |
| `base.assign_worker {instance_id, amount}` | 从池中派工；工种/槽位校验 |
| `base.start_production {instance_id, recipe_id}` | 建筑空闲、工人/材料/金钱满足时锁存输入并生成订单 |

查询 `base.view` 返回：站点、建筑（含订单/进度/工人/配方）、仓储、工人、
防御、每 tick 支出（维护 + 建筑维护 + 工资）、`halted` / `unpaid_ticks` / `upkeep_debt`。

## 5. Tick 生产

`BaseProductionSystem`（id `base.production`，priority 100）在 `sim.advance` 的每个
1 小时 tick 中：

1. 累加维护费/工资到 `upkeep_debt`，按整金币支付；余额不足 → `halted=true`、
   `unpaid_ticks += 1`，本 tick 不推进；
2. 建造/升级 `remaining_hours -= 1`，到 0 转 `ready` / 提升等级；
3. 生产按 `production_speed()` 递减，工人不足 `workers_required` 时暂停；
   完成时把 `outputs[]` 写入基地仓储。

系统只在基地存在时注册（`base.claim` 或 `sim.advance` 兜底），不污染 D0 调度器测试。

## 6. UI

最小基地页（`framework/ui/screens/port/base_screen.tscn`）随船厂一同解锁：

- 未占领：列出可占领基地点与费用；
- 已占领：状态徽章、建筑卡（施工/升级/订单/工人）、建造/派工/生产/升级按钮、
  仓储存取、雇工、等待 1/12 小时。

## 7. 验收

- `test_base.gd` 15 例：占领唯一性、建造扣料 + 工时、仓储存取/容量、雇工派工与工资、
  升级与速度、生产链产出精密齿轮、欠费停工、损坏数据、存档往返、确定性。
- `test_world_schema_refs.gd`：基地引用/升级等级/修正 stat/配方归属。
- `test_world_completeness.gd`：5 类 Core 最低数量 + 生产链到达 `material.shipbuilding`。
- 编辑器/CLI/SDK：`example_base` 模组，`content.base.v1` capability，发布门禁校验。
