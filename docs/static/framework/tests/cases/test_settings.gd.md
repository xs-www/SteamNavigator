# `framework/tests/cases/test_settings.gd`

> 作用：SettingsService 持久化测试：语言/自动存档/reload 往返，以及游玩数据上传开关、endpoint 与 token 的往返与规范化。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `test_settings_round_trip() -> void` | L19 |
| `test_telemetry_settings_round_trip() -> void` | L36 |
| `test_update_settings_defaults_and_round_trip() -> void` | L61 |

## 契约与约束
- 期望值来自 `docs/design/TELEMETRY.md` §2：telemetry 默认 false、非法 endpoint 回退 `TelemetryService.DEFAULT_ENDPOINT`、token 默认空串。
- 每个用例只写 `user://test_settings*` 临时目录并在结束时清理，不碰真实用户配置。

模块索引：[framework/tests](../README.md)
