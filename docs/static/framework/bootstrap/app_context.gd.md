# `framework/bootstrap/app_context.gd`

> 作用：组合根对象：持有服务、注册表、总线、当前 GameState 与启动报告。

- 关键依赖：`Logger/AppLogger`、`LocalizationService`、`AssetService`、`RegistryHub`、`DomainEventBus`、`CommandBus`、`QueryBus`、`SaveService`、`RngService`、`GameState`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `AppContext` | L1 |
| `FRAMEWORK_VERSION` | L8 |
| `API_MAJOR` | L9 |
| `API_MINOR` | L10 |
| `KNOWN_CAPABILITIES` | L11 |
| `_init(app_config: Dictionary = {}) -> void` | L33 |
| `set_active(context: AppContext) -> void` | L51 |
| `get_active() -> AppContext` | L55 |
| `is_ready() -> bool` | L59 |
| `has_run() -> bool` | L63 |
| `reset_state() -> void` | L67 |
| `set_state(new_state: GameState) -> void` | L71 |
| `set_seed(seed_value: int) -> void` | L75 |
| `content_count(content_type: StringName) -> int` | L79 |
| `content_total() -> int` | L84 |
| `mod_summaries() -> Array[Dictionary]` | L88 |
| `save_meta(extra: Dictionary = {}) -> Dictionary` | L92 |
| `autosave(extra: Dictionary = {}) -> Dictionary` | L105 |
| `translate(key: String, fallback: String = "") -> String` | L111 |
| `format_time(game_time: float = -1.0) -> String` | L115 |

## 契约与约束

- UI 与用例共享同一个 AppContext；状态修改只能经 CommandBus。
- `translate()` 是 UI 取本地化文本的唯一入口，缺失键回退到 fallback 或键名。
- `save_meta()` 把模组清单、当前港与种子写入存档头，供兼容性检查。
- `pre_voyage_state` 仅用于同一进程内的出航失败回滚；跨会话回滚依赖 `pre_voyage` 存档槽。

模块索引：[framework/bootstrap](./README.md)
