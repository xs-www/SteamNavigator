# `framework/services/asset_service.gd`

> 作用：把 `asset://<mod>/<key>` 解析为已挂载物理路径，缺失时回退占位图。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `AssetService` | L1 |
| `_init(logger: AppLogger = null) -> void` | L14 |
| `register(mod_id: String, key: String, relative_path: String, asset_prefix: String) -> void` | L18 |
| `resolve(logical_key: String) -> String` | L24 |
| `has(logical_key: String) -> bool` | L39 |
| `count() -> int` | L43 |
| `keys() -> PackedStringArray` | L47 |
| `fallback_path() -> String` | L55 |

## 契约与约束

- 资源缺失只警告并回退，不导致崩溃或存档损坏。
- 支持直接传入 `res://` 框架资源路径。
- 注册发生在编译阶段，解析发生在 mount 之后。

模块索引：[framework/services](./README.md)
