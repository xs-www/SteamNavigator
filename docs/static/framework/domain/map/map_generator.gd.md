# `framework/domain/map/map_generator.gd`

> 作用：程序生成 4–5 港口连通分支网络，并验证 MVP 硬约束。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MapGenerator` | L1 |
| `MAX_ATTEMPTS` | L19 |
| `generate_spec(spec: Dictionary, hub: RegistryHub, rng_service: RngService, ship: Dictionary) -> Dictionary` | L31 |

## 契约与约束

- 先建随机生成树，再补边直到目标边数；要求存在环（非纯链）且起点度数 ≥2。
- 必需设施标签（造船厂/情报站）必须在起点 max_edges 内；否则重试最多 60 次。
- 起始煤水必须能抵达至少一个相邻港口，否则重试。
- 所有随机来自 `map_generation` 命名流；不使用全局 randf/shuffle。
- 生成的每个港口把所选原型的 `diorama` 深拷贝进 world 港口数据（与 `archetype_id/source_mod/banner_asset/facilities/size` 一起持久化），供 PortStage 的 town kit 使用；旧存档缺少该字段时由 port.view 按原型回填。

## 重点逻辑

### `_try_generate(profile, profile_data, hub, rng, ship, attempt)`

- 港口数与边数从 profile 范围抽样；起点原型按 start_archetype_tags 选择。
- 先分配起点，再为每个必需设施标签选择最近未分配节点；剩余节点随机补原型。
- 写港口数据时复制原型 `data.diorama`（含 `kit/town/facility_visuals/palette/landmark`），之后由 port.view 解析成舞台可用的 `town_visuals` 路径。
- 最后校验连通性、分支、必需设施距离与起始补给可达性，任一失败返回重试。

模块索引：[framework/domain](../README.md)
