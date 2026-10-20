# `framework/services/content_asset_loader.gd`

> 作用：运行时读取模组内容资产（原始 PNG / 原始 GLB），并把 GLB 内嵌贴图之外的外部共享贴图按 URI 归一到同一个 `Texture2D` 实例，让多栋建筑在 Godot 里真正共享材质资源。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ContentAssetLoader` | L25 |
| `GLB_MAGIC` | L47 |
| `GLB_CHUNK_JSON` | L48 |
| `load_texture(path: String) -> Texture2D` | L56 |
| `material_image_uris(path: String) -> PackedStringArray` | L74 |
| `load_scene(path: String) -> Node3D` | L113 |
| `instantiate_model(path: String) -> Node3D` | L174 |
| `clear_cache() -> void` | L184 |

- 关键依赖：`FileAccess`、`Image.load_from_file`、`GLTFDocument` / `GLTFState`、`StandardMaterial3D`

## 契约与约束
- 模组是挂载的普通资源包（含原始文件），`ResourceLoader` 无法直接 load 其中的 `.png` / `.glb`，因此内容资产必须走本加载器。
- `load_texture(path)` 返回按路径缓存的 `ImageTexture`；`load_scene(path)` 返回 GLTF 场景根；`instantiate_model()` 返回可挂到舞台的副本（缓存节点不被父级占用）。
- 解析失败按路径记入 `failures` 缓存，重复调用不反复尝试；`clear_cache()` 在 `FrameworkRuntime.shutdown` 中调用。
- 旧格式（贴图内嵌在 GLB bufferView 里）行为不变：没有外部 image URI 时不做任何材质改写。
- GLB 的外部 image URI 只在 GLB 自行声明时处理；`data:` URI 与内部资源 URI 不接管。缺失的外部贴图不会让整个模型加载失败（保留 GLTF 解析出的占位材质）。
- 贴图共享是"按 URI 缓存 `Texture2D` 实例"：同一外部 PNG 被多份 GLB 引用时只解一张、只建一个实例，`PortStage` 的材质签名合批才能跨建筑合并。
- 只负责表现资源，不读写 GameState、注册表或存档。

## 重点逻辑
### `material_image_uris(path)`
- 直接解析 GLB 的 JSON chunk（12 字节头 + chunk 头），按 `materials[i].pbrMetallicRoughness.baseColorTexture.index -> textures[].source -> images[].uri` 取出每材质的主色图 URI；解析失败返回空数组，调用方退回旧行为。
- 只读 GLB 头部与 JSON chunk，不读 BIN chunk，工具/测试可用它核对 `image.uri` 是否已外部化。
### `load_scene(path)`
- `append_from_file()` 之后、`generate_scene()` 之前改写 `GLTFState` 里的材质：把 albedo 贴图换成本加载器缓存的外部 `Texture2D`。放在 `append` 与 `generate` 之间，是因为 `generate_scene()` 会用 state 里的材质实例生成 primitive，改写才能落到最终网格。
### `_resolve_image_path(base_dir, uri)`
- 相对 URI 按 GLB 所在目录拼接（松散目录与挂载 ZIP 内的 res:// 路径都成立），不依赖 `..` 解析层。

模块索引：[framework/services](./README.md)
