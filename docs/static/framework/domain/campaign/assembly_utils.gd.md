# `framework/domain/campaign/assembly_utils.gd`

> 作用：CampaignFactory 世界装配链路（区域 / 地点 / 航路 / 阵营 / 图鉴）共用的

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `CampaignAssembly` | L1 |
| `sorted_by_id(definitions: Array) -> Array` | L21 |
| `pick_weighted(rng: RandomNumberGenerator, entries: Array, weights: Array) -> Variant` | L32 |
| `sample_distinct(rng: RandomNumberGenerator, entries: Array, count: int) -> Array` | L52 |
| `index_by_id(instances: Array) -> Dictionary` | L64 |

确定性小工具：按 id 排序注册表结果、加权抽取、实例 id 生成与区域索引。

## 契约与约束
- **确定性**：所有抽取都经过调用方提供的 `RandomNumberGenerator`（来自
  `STREAM_CAMPAIGN_WORLD` 的上下文子流），本文件不访问全局 RNG、不读时间。
- **不依赖字典遍历顺序**：注册表结果在抽取前必须经 `sorted_by_id()`；引用列表
  （ports / regions / sites）一律使用调用方给定的稳定顺序。
- **不写状态**：只返回新数组 / 新字典；装配器负责把它们交给 CampaignFactory。
- 抽中权重 ≤ 0 的候选在加权抽取中被跳过；全部为 0 时退化为按索引均匀抽取，
  保证「内容权重缺失」不会让装配静默失败。

模块索引：[framework/domain](../README.md)
