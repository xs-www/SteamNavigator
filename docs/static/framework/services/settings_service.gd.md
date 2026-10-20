# `framework/services/settings_service.gd`

> 作用：持久化 UI 设置：编辑器读 `res://config/config.json`；发布版优先读写 exe 同级 `config/config.json`，不可写时回退 `user://config/config.json`。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SettingsService` | L1 |
| `DEFAULT_PATH` | L12 |
| `USER_PATH` | L13 |
| `EXE_CONFIG_PATH` | L14 |
| `VALID_LOCALES` | L15 |
| `_init(user_path_override: String = "", default_path_override: String = "") -> void` | L23 |
| `load_settings(user_path_override: String = "", default_path_override: String = "") -> SettingsService` | L28 |
| `load() -> void` | L58 |
| `locale() -> String` | L82 |
| `autosave() -> bool` | L86 |
| `set_locale(value: String) -> void` | L90 |
| `set_autosave(value: bool) -> void` | L95 |
| `save() -> Dictionary` | L99 |

## 契约与约束

- 只接受 zh_CN / en 两种语言；非法值回退 zh_CN。
- 自动存档为布尔值；首次启动会把默认配置写入可用的配置路径。
- 模板构建优先使用 exe 同级 `config/config.json`；若已存在 `user://config/config.json` 则以用户配置优先。
- 安装目录不可写时 `save()` 自动切换到 `user://config/config.json`，不丢失本次修改。
- 保存失败返回结构化 Result，不抛异常；调用方负责提示。
- 测试可覆盖 user/default 路径，避免污染真实用户配置。

模块索引：[framework/services](./README.md)
