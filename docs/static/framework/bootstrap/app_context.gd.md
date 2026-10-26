# `framework/bootstrap/app_context.gd`

> 作用：应用组合根：持有服务、总线、GameState 与启动报告，交给命令/查询/UI 使用；`telemetry` 是可选的本局游玩日志记录器（默认 null，未开启上传时不创建）。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `AppContext` | L1 |
| `FRAMEWORK_VERSION` | L18 |
| `API_MAJOR` | L19 |
| `API_MINOR` | L20 |
| `KNOWN_CAPABILITIES` | L21 |
| `_init(app_config: Dictionary = {}) -> void` | L46 |
| `set_active(context: AppContext) -> void` | L64 |
| `get_active() -> AppContext` | L68 |
| `is_ready() -> bool` | L72 |
| `has_run() -> bool` | L76 |
| `reset_state() -> void` | L80 |
| `set_state(new_state: GameState) -> void` | L84 |
| `set_seed(seed_value: int) -> void` | L88 |
| `content_count(content_type: StringName) -> int` | L92 |
| `content_total() -> int` | L97 |
| `mod_summaries() -> Array[Dictionary]` | L101 |
| `save_meta(extra: Dictionary = {}) -> Dictionary` | L105 |
| `autosave(extra: Dictionary = {}) -> Dictionary` | L118 |
| `translate(key: String, fallback: String = "") -> String` | L124 |
| `format_time(game_time: float = -1.0) -> String` | L128 |

- 关键依赖：`AppLogger`、`LocalizationService`、`RegistryHub`、`DomainEventBus`、`CommandBus`、`QueryBus`、`SaveService`、`TelemetryService`

## 契约与约束
- 系统只通过 AppContext 取依赖，但只有 CommandBus 能改 GameState；查询/UI 走 ViewModel。
- `telemetry` 必须 null 安全：菜单/启动失败/旧工具链没有记录器时，CommandBus 等调用方直接跳过记录（`docs/design/TELEMETRY.md` §3、§5）。
- 启动链路不创建记录器：由 `main.gd` 在首次拿到 context 后按设置创建并绑定，避免无头工具意外产生上传数据。

## 重点逻辑
### `autosave()/save_meta()`
- 自动存档只在 `autosave_enabled` 且有本局状态时写入，并把版本/模组/港口/种子写进头信息。

模块索引：[framework/bootstrap](./README.md)
