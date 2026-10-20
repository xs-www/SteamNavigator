# `SNBattleSim/js/simulation.mjs`

> 作用：执行确定性的 2D 俯视角舰队战斗，处理视野接触、货船行为、多武器冷却、炮弹飞行与战斗终局。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `TAU` | L16 |
| `clamp(value, min, max)` | L18 |
| `distance(a, b)` | L19 |
| `angleDelta(a, b)` | L20 |
| `seededRandom(seed = 1)` | L27 |
| `runtimeShip(config, faction, index, weaponCatalog)` | L38 |

## 契约与约束
- 战斗使用无限世界坐标，不存在地图边缘；镜头取景属于表现层。
- 战斗只读取已校验装配快照，不修改装配器中的舰队配置。
- 舰船丢失视野后会追向短时最后已知位置；直射要求当前视野，炮击可对新鲜的最后已知位置盲射。
- 每个武器挂载拥有独立冷却；侧弦炮只在左右舷射界内以多发齐射开火。
- 舰船机动与目标选择读取自身 tactic 配置，状态机本身不执行任意脚本。
- 相同 seed、装配与 tick 序列必须产生相同结果。

模块索引：[SNBattleSim](../README.md)
