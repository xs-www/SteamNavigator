# `tools/godot/verify_legacy_uv_materials_b.gd`

> 作用：旧资产 UV 迁移 B 的 **运行时共享贴图验收**（只读）——12 件船模块 /

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MODULES_DIR` | L19 |
| `SHIPS_DIR` | L20 |
| `PROPS_DIR` | L21 |
| `MODULES` | L23 |
| `SHIPS` | L29 |
| `TOWN` | L32 |
| `EXPECTED_TRIS` | L36 |
| `EXPECTED_MESHES` | L37 |
| `EXPECTED_UNIQUE_TEXTURES` | L38 |
| `TEX_URI_PREFIX` | L39 |
| `_init() -> void` | L48 |

4 艘船 / 5 件旧小镇道具走 `ContentAssetLoader.load_scene()` 加载，核对每件 GLB
的外部贴图 URI、每个 surface 的 UV、每个材质的 albedo 贴图，以及同一
`shared_materials/<texture>.png` 在同一类别内命中同一个 `Texture2D` 实例。

用法：
  godot --headless --path . --script res://tools/godot/verify_legacy_uv_materials_b.gd

判定口径：
- `images[].uri` 必须是 `shared_materials/<texture>.png`，文件存在于 GLB 同级目录；
- 每个 surface 必须有 `ARRAY_TEX_UV`；每个材质必须是 `SN_Tex_*` 且有 albedo_texture；
- 同一 URI 在同类别的多个 GLB 之间必须命中同一个 `Texture2D` 实例 id；
- 三角面总数：modules 7492 / ships 45968 / town 1796（与迁移前一致）；
- 网格节点数：modules 12 / ships 101 / town 5（Ironclad 1 + 39 + 32 + 29）。

模块索引：[tools](../README.md)
