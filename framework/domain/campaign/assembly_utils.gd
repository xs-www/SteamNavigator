class_name CampaignAssembly
extends RefCounted
## @static-doc
## 作用：CampaignFactory 世界装配链路（区域 / 地点 / 航路 / 阵营 / 图鉴）共用的
## 确定性小工具：按 id 排序注册表结果、加权抽取、实例 id 生成与区域索引。
##
## ## 契约与约束
## - **确定性**：所有抽取都经过调用方提供的 `RandomNumberGenerator`（来自
##   `STREAM_CAMPAIGN_WORLD` 的上下文子流），本文件不访问全局 RNG、不读时间。
## - **不依赖字典遍历顺序**：注册表结果在抽取前必须经 `sorted_by_id()`；引用列表
##   （ports / regions / sites）一律使用调用方给定的稳定顺序。
## - **不写状态**：只返回新数组 / 新字典；装配器负责把它们交给 CampaignFactory。
## - 抽中权重 ≤ 0 的候选在加权抽取中被跳过；全部为 0 时退化为按索引均匀抽取，
##   保证「内容权重缺失」不会让装配静默失败。
## @end-static-doc


## Returns a new Array of definitions sorted by `id`. Registry order follows the
## mod load order, so sorting is what makes a campaign reproducible across mods
## that register the same definitions in a different order.
static func sorted_by_id(definitions: Array) -> Array:
	var sorted: Array = definitions.duplicate()
	sorted.sort_custom(func(left: Variant, right: Variant) -> bool:
		return String((left as ContentDefinition).id) < String((right as ContentDefinition).id)
	)
	return sorted


## Weighted pick over parallel `entries` / `weights` arrays. Returns null only
## when `entries` is empty. Contexts never draw more randomness than needed for
## the actual candidate set, so content changes stay local to one sub-stream.
static func pick_weighted(rng: RandomNumberGenerator, entries: Array, weights: Array) -> Variant:
	if entries.is_empty():
		return null
	var total := 0.0
	for index in entries.size():
		total += maxf(0.0, float(weights[index]))
	if total <= 0.0:
		return entries[rng.randi_range(0, entries.size() - 1)]
	var roll := rng.randf() * total
	for index in entries.size():
		var weight := maxf(0.0, float(weights[index]))
		if weight <= 0.0:
			continue
		roll -= weight
		if roll <= 0.0:
			return entries[index]
	return entries[entries.size() - 1]


## Samples `count` distinct entries (deterministic Fisher-Yates on a copy).
static func sample_distinct(rng: RandomNumberGenerator, entries: Array, count: int) -> Array:
	var pool := entries.duplicate()
	var result: Array = []
	var wanted := mini(count, pool.size())
	for _index in wanted:
		var picked := rng.randi_range(0, pool.size() - 1)
		result.append(pool[picked])
		pool.remove_at(picked)
	return result


## Indexes an instance array by its `id` field (`regions` / `sites`).
static func index_by_id(instances: Array) -> Dictionary:
	var index := {}
	for instance in instances:
		var entry: Dictionary = instance
		index[String(entry.get("id", ""))] = entry
	return index
