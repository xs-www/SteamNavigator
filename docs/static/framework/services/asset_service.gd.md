# `framework/services/asset_service.gd`

> 作用：把 `asset://<mod>/<key>` 解析为已挂载物理路径，缺失时回退占位；并统一加载模组内原始 PNG/GLB 内容资源。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `AssetService` | L1 |
| `_init(logger: AppLogger = null) -> void` | L14 |
| `register(mod_id: String, key: String, relative_path: String, asset_prefix: String) -> void` | L18 |
| `resolve(logical_key: String) -> String` | L24 |
| `load_texture(logical_key: String) -> Texture2D` | L41 |
| `load_model(logical_key: String) -> Node3D` | L52 |
| `find_key(asset_key: String) -> String` | L68 |
| `has(logical_key: String) -> bool` | L79 |
| `count() -> int` | L83 |
| `keys() -> PackedStringArray` | L87 |
| `fallback_path() -> String` | L95 |

## 契约与约束

- 资源缺失只警告并回退，不导致崩溃或存档损坏。
- 支持直接传入 `res://` 框架资源路径。
- 注册发生在编译阶段，解析发生在 mount 之后。
- `find_key(asset_key)` 按裸键（如 `icon.money`）在已注册资产中按排序确定性扫描，返回首个 `asset://<pack>/<key>`；框架 UI 用它解析可选图标，不硬编码 mod 命名空间，未命中返回空串。
- `load_texture()/load_model()`：框架资源走 `ResourceLoader`，模组内原始 `.png/.glb`（挂载包或松散目录）走 `ContentAssetLoader`；失败返回 null，调用方保留 2D 回退。

模块索引：[framework/services](./README.md)
