# `framework/tests/cases/test_telemetry.gd`

> 作用：客户端游玩数据上传（Telemetry）契约测试：覆盖 `docs/design/TELEMETRY.md` §6 的客户端部分——默认关闭、开启后退出写出合法 `sn.telemetry.session/1` 载荷、缓冲/队列上限、命令参数白名单、关闭清队列、endpoint 回退、CommandBus 记录与上传器失败保留。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `TEMP_ROOT` | L11 |
| `SESSION_SCHEMA` | L12 |
| `test_disabled_service_records_and_writes_nothing() -> void` | L57 |
| `test_enabled_session_writes_a_contract_payload() -> void` | L74 |
| `test_buffers_trim_to_the_contract_limits() -> void` | L174 |
| `test_string_fields_are_clipped_to_contract_limits() -> void` | L205 |
| `test_command_params_are_whitelisted_and_clipped() -> void` | L237 |
| `test_pending_queue_caps_at_twenty_and_drops_the_oldest() -> void` | L287 |
| `test_serialize_with_budget_trims_old_data_before_writing() -> void` | L310 |
| `test_disabling_discards_the_queue_and_session_buffer() -> void` | L327 |
| `test_endpoint_normalization_falls_back_to_the_default() -> void` | L345 |
| `test_command_bus_records_commands_into_telemetry() -> void` | L383 |
| `test_uploader_keeps_pending_files_unless_the_response_is_2xx() -> void` | L425 |

## 契约与约束
- 断言必须直接反映 TELEMETRY.md 的 schema / 上限 / 文件名 / 默认值；不得为了让实现通过而放松期望。
- 测试只写 `user://test_telemetry/**` 临时目录；上传器失败分支用无效 endpoint / 纯结果处理验证，禁止真实外网请求。
- 上传器测试不等待 HTTP：`apply_response()` 是 2xx 删除/失败保留的唯一判决点，`flush()` 只验证无效 endpoint 不删文件。

模块索引：[framework/tests](../README.md)
