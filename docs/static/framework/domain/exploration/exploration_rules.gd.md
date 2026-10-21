# `framework/domain/exploration/exploration_rules.gd`

> 作用：读取并合并探索系统规则（`map_profiles` 定义的 `data.exploration`），

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ExplorationRules` | L1 |
| `DEFAULTS` | L30 |
| `read(state: GameState, hub: RegistryHub) -> Dictionary` | L96 |
| `fog_radii(state: GameState, hub: RegistryHub, world: WorldMap = null) -> Dictionary` | L115 |
| `discovery_chance(rules: Dictionary, credibility: float) -> float` | L130 |
| `roll_succeeds(rng: RandomNumberGenerator, chance: float) -> bool` | L137 |
| `roll_hits(roll: float, chance: float) -> bool` | L145 |

把 Core JSON 的数值与框架兜底常量统一成一份纯数据字典，供线索、探索预览、结算与
战争迷雾半径共享。

- 关键依赖：`ContentTypes.MAP_PROFILE`、`GameState.world()`、`RegistryHub`、`WorldMap`

## 契约与约束
- 规则只来自当前 `map_profile_id` 对应 `map_profiles` 定义的 `data.exploration`；
  框架不写死可调数值。`DEFAULTS` 只用于旧存档 / 内容缺字段的**防御兜底**，不参与调参；
  正常内容（core 的 `standard` profile）必须覆盖全部键。
- 合并只覆盖 `DEFAULTS` 里已知的键，未知键被忽略；`level_weights` /
  `credibility_range` 这类两级结构逐来源子键合并，缺一个来源不影响另一个。
- 读取无副作用、不缓存：注册表冻结后内容不变，重复读取开销可忽略。
- `discovery_chance` / `roll_succeeds` 是规则数学的单一真源：线索服务、探索预览与
  结算都调用这里，避免「展示概率」和「实际判定」用两套公式。
- `fog_radii()` 是雾半径的单一真源：`radius = min(world.w, world.h) * ratio`
  （阶段 4.3 起比例来自 Core，不再用固定世界单位）；世界缺失时退回 400 单位的
  历史默认世界，保证旧存档 / 测试夹具仍有确定的雾。
- 4.4 起同一份规则还承载货物行情线索的时效（`goods_clue_expiry_hours`）、报价误差
  （`goods_clue_price_error_ratio`）、等待 / 委托解锁概率（`wait_clue_*` /
  `contract_clue_chance`）与 4.4.3 的调查成功率（`investigation_success_chance`），
  线索 / 查询 / UI 都只读这一份，不在框架里写死数字。

模块索引：[framework/domain](../README.md)
