class_name ContentRefs
extends RefCounted
## @static-doc
## 作用：跨内容 Schema 版本的“这次 run 使用哪份场景调参”解析器（C4 起唯一来源是
## `ContentTypes.MAP_CONFIG`，`state.world.map_config_id`）。`map_profiles` 已退役，
## 不再保留 1.0 fallback。
##
## ## 契约与约束
## - 解析顺序：只读 `map_config_id`；为空或目标定义不存在时返回 null。
## - 返回值是 ContentDefinition；调用方只读 `.data`，不缓存、不写回。
## - `map_config_data()` 是常用读取入口：定义缺失时返回空 Dictionary（调用方走自己的兜底）。
## - `is_v2_campaign()`：新 run 一律是 campaign 形态，这里保留为“是否已绑定
##   map_config”的兼容判断（旧档 / 裸 GameState 为 false）。
## - 新增读取点必须走本 helper，禁止再写 `hub.get_by_id(ContentTypes.MAP_CONFIG, ...)`。
## @end-static-doc


## Returns the scenario config definition for the current run. Null when the run has
## no resolvable map config (bare GameState / pre-C4 save).
static func map_config(state: GameState, hub: RegistryHub) -> ContentDefinition:
	if state == null or hub == null:
		return null
	var map_config_id := String(state.world().get("map_config_id", ""))
	if map_config_id.is_empty():
		return null
	return hub.get_by_id(ContentTypes.MAP_CONFIG, map_config_id)


## Convenience accessor for the most common use: the scenario `data` block.
static func map_config_data(state: GameState, hub: RegistryHub) -> Dictionary:
	var definition := map_config(state, hub)
	return definition.data if definition != null else {}


## True when the run has a resolvable map config binding (all C4 runs do).
static func is_v2_campaign(state: GameState) -> bool:
	if state == null:
		return false
	return not String(state.world().get("map_config_id", "")).is_empty()
