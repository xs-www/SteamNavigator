# 船舶模块实例化（Module Instance）

> 状态：已落地（2026-10 迭代）
> 适用：Save Schema 2.0 运行态、维修经济、船厂 UI，以及后续战斗持久伤害
> 相关：[实体契约 v2](../design/ENTITY_CONTRACT_V2.md)、[战斗系统架构评审](COMBAT_ARCHITECTURE_REVIEW.md)、[持久战役架构](PERSISTENT_CAMPAIGN_ARCHITECTURE.md)

## 1. 为什么现在做

战斗评审把「Module 实例化（id + condition + 失效状态）」列为战斗实现的前置依赖：当前 `ship` 只把已装模块存成定义 ID，没有实例身份也没有耐久，战斗无法「打坏一个具体部件」，维修也无法按部件计价。

这一步先把**实例身份与状态**落地，不改 Content Schema，也不做统一 Module 迁移：

- 每个已装模块有稳定 `instance_id` 与 `condition`（0..1）。
- 事件可以损坏指定槽位的模块；港口维修按部件损耗计价并恢复。
- 旧存档缺实例表时按满状态补齐，不阻断加载。

## 2. 数据形状

```json
"ship": {
  "hull_id": "core:hull/small_efficient",
  "boiler_id": "core:boiler/basic",
  "cargo_modules": ["core:cargo_module/basic"],
  "navigation_module_id": "", "safety_module_id": "", "passenger_cabin_id": "",
  "module_serial": 2,
  "module_instances": {
    "boiler": {"instance_id": "module_1", "condition": 1.0},
    "cargo":  [{"instance_id": "module_2", "condition": 1.0}]
  }
}
```

- `module_instances` 只含单槽（`boiler` / `navigation` / `safety` / `cabin`）与有序 `cargo` 数组；船体耐久仍由 `ship.durability` 承担，船体不进实例表。
- `module_serial` 是实例编号计数器，新实例按 `module_<n>` 递增；同 seed、同构筑、同操作序列产生相同 id。
- `condition`：1.0 完好，0.0 失效；中间值可参与维修计价。
- 实例只保存身份与状态；**已安装哪个定义**仍由扁平槽位键表达（`boiler_id` 等）。这是本阶段刻意保留的投影，统一 Module 迁移时再把 `definition_id` 移入实例、扁平键改为派生访问器。

## 3. 不变量

1. 实例表与扁平槽位键始终对齐：单槽有键才有实例，货舱数组长度等于 `cargo_modules` 长度且顺序一致。
2. 写入只发生在 `ShipModules`：`ensure()`、`install_slot()`、`append_cargo()`、`remove_cargo()`、`remove_slot()`、`damage()`、`repair_all()`。
3. 读接口在旧船上是安全的：缺表/缺条目按满状态返回，不抛异常、不隐式写状态。
4. `ensure()` 幂等：布局不变时 serial、instance_id、condition 都不变，存档哈希稳定。
5. 安装/替换生成全新实例（新 id、满状态）；替换旧件不会把旧条件带给新模块。
6. 存档写入快照与加载结果都会 `ensure()`，因此旧档加载后立即拥有完整实例表。

## 4. 损伤与维修

- 效果操作码：`{"op": "damage_module", "slot": "boiler", "amount": 0.2}`；`slot ∈ {boiler, navigation, safety, cabin, cargo}`，可选 `index`（默认 0）。`hull` 不是模块槽位。
- 成功发布领域事件 `ship.module_damaged`，payload 含 `slot/index/instance_id/condition/disabled/newly_disabled`。
- 失败返回 `unknown_module_slot` / `invalid_amount`，命令事务整体回滚。
- Core 的「锅炉过热」两个选项已接入：水冷轻微损伤锅炉、强行继续明显损伤锅炉——部件损耗不再只是数据字段。
- 维修报价：`missing = 船体缺失点数 + Σ(模块重量 × (1 - condition))`，再乘 `repair_per_point` 与安全设备/工程师的 `repair_cost_mul`；`repair()` 同时恢复船体与全部模块实例，返回 `modules_repaired`。
- 当前边界：**模块 condition 暂不影响航速/容量等派生属性**，只影响失效标记与维修费用；性能影响与战斗规则放到战斗阶段（见评审文档 §8）。

## 5. 界面

- `shipyard.view` 的 `ship.modules[]` 行新增 `slot/index/condition/disabled`；`ship` 块新增 `worst_module_condition`、`damaged_modules`、`disabled_modules`、`module_damage_points`。
- 船厂槽位卡在 condition < 1 时显示「状态 NN%」徽标：0 为红色失效、其余为警告色；满状态不显示，避免正常界面噪音。
- 船厂「已有船舶」船卡在多件受损时多一行「受损部件 1 · 50%」。
- 顶部信息条在存在受损部件时追加「部件 1 · 50%」chip（失效为红色）；健康时不占位。
- 补给页维修卡把报价拆成「缺失耐久 X（船体 A · 部件 B）」，有部件损耗时额外显示「含部件损耗」徽标。

### 5.1 在游戏里怎么看

自然触发路径：航行风险事件「锅炉过热」→ 选择「水冷」或「强行继续」会损坏锅炉实例 → 顶部信息条出现部件 chip → 船厂看槽位状态 → 补给页维修报价含部件损耗 → 维修后恢复。

稳定复现（截图工具，不动游戏逻辑）：

```powershell
pwsh ./tools/capture_ui.ps1 -OutDir res://docs/design/screenshots/module_condition -Damage boiler:0.5
```

| 画面 | 截图 |
| --- | --- |
| 正常态船厂 + 顶部部件 chip + 船卡受损行 | [shipyard_normal_damaged.png](../design/screenshots/module_condition/shipyard_normal_damaged.png) |
| 改装态锅炉槽「状态 50%」 | [shipyard_refit_damaged.png](../design/screenshots/module_condition/shipyard_refit_damaged.png) |
| 补给页维修报价「含部件损耗」 | [supply_damaged.png](../design/screenshots/module_condition/supply_damaged.png) |

`--damage=boiler:0.5` 是截图工具的调试参数（`tools/ui_snapshot.gd`），只作用于截图进程；游戏内损坏仍由 `damage_module` 效果驱动。

## 6. 测试

[test_ship_modules.gd](../../framework/tests/cases/test_ship_modules.gd)：

- 新局实例创建、id 唯一、serial 覆盖。
- 旧船 `ensure()` 补齐且幂等。
- damage 夹取、失效转换只报一次、`repair_all` 计数。
- 货舱追加/删除后逐位对齐、幸存实例 id 不变。
- 单槽替换生成满状态新实例。
- `damage_module` 操作码成功/非法槽位、事件类型。
- 维修报价含模块损耗、不伪造船体缺失。
- 损伤状态与实例 id 随存档往返、哈希一致。

另外 [test_shipyard_refit.gd](../../framework/tests/cases/test_shipyard_refit.gd) 守护「健康船无状态徽标 / 50% 损耗显示状态徽标」的界面契约。

## 7. 兼容与迁移

- Save Schema 仍为 2.0：新增字段通过 `ShipModules.ensure()` 惰性补齐，不提升主版本。
- 1.x 旧档 → 2.0 迁移后同样走 `ensure()`；旧船没有锅炉/导航等键时不生成对应实例。
- 新字段 `module_instances` / `module_serial` 只存在于存档，不写回内容定义。
- `damage_module` 已加入 `schemas/common.schema.json` 的效果枚举，与 `EffectOpRegistry` 同步；SNModMaker 的 schema bundle 需重新生成。

## 8. 下一步

1. 战斗/敌方攻击按实例造成伤害，condition 影响能力输出（速度、容量、安全修正）。
2. 统一 Module 迁移：`definition_id` 进实例，扁平槽位键改为派生访问器，提供 ID 别名迁移。
3. 部件维修单（按槽位单独修理/更换）与备件库存。
4. UI：船卡与海图显示最差部件状态、维修预览拆分船体/部件。
