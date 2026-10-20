# `framework/modding/mod_scanner.gd`

> 作用：发现松散目录与 `.snavmod.zip`，执行文件安全扫描并解析 Manifest。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ModScanner` | L1 |
| `MAX_FILES` | L6 |
| `MAX_PACK_BYTES` | L7 |
| `MAX_MANIFEST_BYTES` | L8 |
| `MAX_CONTENT_FILE_BYTES` | L9 |
| `_init(schema_validator: SchemaValidator = null) -> void` | L14 |
| `scan(roots: PackedStringArray, allow_loose: bool = true) -> Dictionary` | L18 |

## 契约与约束

- ZIP 必须只有一个 manifest，且路径为 `mods/<id>/manifest.json`。
- 松散目录允许 Godot 生成的 `.import`/`.uid` 元数据；ZIP 不允许。
- 未知扩展名、脚本/动态库、路径穿越、超大包/文件数量均拒绝。
- Manifest 同时经过 JSON Schema 与 `ModManifest` 语义检查。
- 同名松散目录优先于 ZIP；core 的 ZIP 构建产物被松散 core 静默忽略，其他重复 ID 产生 warning。

模块索引：[framework/modding](./README.md)
