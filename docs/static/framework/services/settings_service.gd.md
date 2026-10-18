# `framework/services/settings_service.gd`

> 作用：持久化 UI 设置：默认读取 `res://config/config.json`，运行时写入 `user://config/config.json`。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SettingsService` | L1 |
| `_init(user_path_override: String = USER_PATH, default_path_override: String = DEFAULT_PATH) -> void` | L19 |
| `load() -> void` | L30 |
| `locale() -> String` | L54 |
| `autosave() -> bool` | L58 |
| `set_locale(value: String) -> void` | L62 |
| `set_autosave(value: bool) -> void` | L67 |
| `save() -> Dictionary` | L71 |

## 契约与约束

- 只接受 zh_CN / en 两种语言；非法值回退 zh_CN。
- 自动存档为布尔值；首次启动会把默认配置写入 user://。
- 保存失败返回结构化 Result，不抛异常；调用方负责提示。
- 测试可覆盖 user/default 路径，避免污染真实用户配置。

模块索引：[framework/services](./README.md)
