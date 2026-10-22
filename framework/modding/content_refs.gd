class_name ContentRefs
extends RefCounted
## @static-doc
## 作用：跨内容 Schema 版本的“这次 run 使用哪份场景调参”解析器。v2 战役读
## `ContentTypes.MAP_CONFIG`（`state.world.map_config_id`），1.0 旧档读
## `ContentTypes.MAP_PROFILE`（`state.world.map_profile_id`）；运行时其余系统只依赖
## 这个 helper，不再直接读 `MAP_PROFILE`。
##
## ## 契约与约束
## - 解析顺序：`map_config_id` → `map_profile_id`；两者都为空或目标定义不存在时返回 null。
## - 返回值是 ContentDefinition；调用方只读 `.data`，不缓存、不写回。
## - `map_config_data()` 是常用读取入口：定义缺失时返回空 Dictionary（调用方走自己的兜底）。
## - `is_v2_campaign()` 仅判断本 run 是否走 v2 战役（`map_config_id` 非空），不推断内容版本。
## - 新增读取点必须走本 helper，禁止再写 `hub.get_by_id(ContentTypes.MAP_PROFILE, ...)`。
## @end-static-doc


## Returns the scenario config definition for the current run: v2 map config first,
## legacy 1.0 map profile as the fallback. Null when neither id resolves.
static func map_config(state: GameState, hub: RegistryHub) -> ContentDefinition:
	if state == null or hub == null:
		return null
	var world: Dictionary = state.world()
	var map_config_id := String(world.get("map_config_id", ""))
	if not map_config_id.is_empty():
		var config := hub.get_by_id(ContentTypes.MAP_CONFIG, map_config_id)
		if config != null:
			return config
	var map_profile_id := String(world.get("map_profile_id", ""))
	if not map_profile_id.is_empty():
		return hub.get_by_id(ContentTypes.MAP_PROFILE, map_profile_id)
	return null


## Convenience accessor for the most common use: the scenario `data` block.
static func map_config_data(state: GameState, hub: RegistryHub) -> Dictionary:
	var definition := map_config(state, hub)
	return definition.data if definition != null else {}


## True when the run was created through the v2 campaign path (map config set).
static func is_v2_campaign(state: GameState) -> bool:
	if state == null:
		return false
	return not String(state.world().get("map_config_id", "")).is_empty()
