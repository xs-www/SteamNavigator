# `framework/modding/content_refs.gd`

> 作用：跨内容 Schema 版本的“这次 run 使用哪份场景调参”解析器。v2 战役读

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ContentRefs` | L1 |
| `map_config(state: GameState, hub: RegistryHub) -> ContentDefinition` | L20 |
| `map_config_data(state: GameState, hub: RegistryHub) -> Dictionary` | L36 |
| `is_v2_campaign(state: GameState) -> bool` | L42 |

`ContentTypes.MAP_CONFIG`（`state.world.map_config_id`），1.0 旧档读
`ContentTypes.MAP_PROFILE`（`state.world.map_profile_id`）；运行时其余系统只依赖
这个 helper，不再直接读 `MAP_PROFILE`。

## 契约与约束
- 解析顺序：`map_config_id` → `map_profile_id`；两者都为空或目标定义不存在时返回 null。
- 返回值是 ContentDefinition；调用方只读 `.data`，不缓存、不写回。
- `map_config_data()` 是常用读取入口：定义缺失时返回空 Dictionary（调用方走自己的兜底）。
- `is_v2_campaign()` 仅判断本 run 是否走 v2 战役（`map_config_id` 非空），不推断内容版本。
- 新增读取点必须走本 helper，禁止再写 `hub.get_by_id(ContentTypes.MAP_PROFILE, ...)`。

模块索引：[framework/modding](./README.md)
