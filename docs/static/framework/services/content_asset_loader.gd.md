# `framework/services/content_asset_loader.gd`

> 作用：运行时读取模组内容资产：用 `Image.load_from_file` 读原始 PNG、用 `GLTFDocument.append_from_file` 读原始 GLB，并按路径缓存。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ContentAssetLoader` | L1 |

## 契约与约束

- 模组是挂载的普通资源包（含原始文件），`ResourceLoader` 无法直接 load 其中的 .png/.glb，因此必须走本项目加载器。
- `load_texture(path)` 返回 ImageTexture；`load_scene(path)` 返回 GLTF 场景根；`instantiate_model()` 返回可挂到舞台的副本（缓存节点不被父级占用）。
- 解析失败按路径记入 failures 缓存，重复调用不反复尝试；`clear_cache()` 在 FrameworkRuntime.shutdown 中调用。
- 只负责表现资源，不读写 GameState、注册表或存档。

模块索引：[framework/services](./README.md)
