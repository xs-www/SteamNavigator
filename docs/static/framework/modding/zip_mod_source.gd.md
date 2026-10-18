# `framework/modding/zip_mod_source.gd`

> 作用：未挂载前通过 ZIPReader 读取包内文件，并提供挂载后的 `res://mods/<id>/` 资源前缀。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ZipModSource` | L1 |
| `_init(pack_path: String) -> void` | L15 |
| `is_open() -> bool` | L48 |
| `exists(relative_path: String) -> bool` | L52 |
| `read_text(relative_path: String) -> String` | L56 |
| `read_bytes(relative_path: String) -> PackedByteArray` | L63 |
| `list_files() -> PackedStringArray` | L69 |
| `get_asset_prefix() -> String` | L77 |
| `get_pack_path() -> String` | L81 |
| `is_pack() -> bool` | L85 |
| `get_display_name() -> String` | L89 |
| `close() -> void` | L93 |

## 契约与约束

- 构造时推断唯一 manifest 前缀；路径不合规时写入 `error`，扫描器据此拒绝。
- 内容读取使用 `mods/<id>/...` 前缀；资源前缀为挂载后的 `res://mods/<id>/`。
- 挂载 ZIP 后即可用 FileAccess 访问资源路径；ZIPReader 可在编译结束后关闭。

模块索引：[framework/modding](./README.md)
