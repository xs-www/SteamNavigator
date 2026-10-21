# `tools/godot/verify_legacy_uv_materials.gd`

> 作用：旧资产 UV 迁移 A 的 **运行时共享贴图验收**（只读）——37 件铁港道具 / 港口设施

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `PROPS` | L19 |
| `PORT` | L20 |
| `PROPS_ASSETS` | L22 |
| `PORT_ASSETS` | L32 |
| `EXPECTED_TRIS` | L36 |
| `EXPECTED_UNIQUE_TEXTURES` | L37 |
| `TEX_URI_PREFIX` | L38 |
| `_init() -> void` | L46 |

走 `ContentAssetLoader.load_scene()` 加载，核对每件 GLB 的
外部贴图 URI、每个 surface 的 UV、每个材质的 albedo 贴图，以及同一
`shared_materials/<texture>.png` 在同一类别内命中同一个 `Texture2D` 实例。

用法：
  godot --headless --path . --script res://tools/godot/verify_legacy_uv_materials.gd

判定口径：
- `images[].uri` 必须是 `shared_materials/<texture>.png`，文件存在于 GLB 同级目录；
- 每个 surface 必须有 `ARRAY_TEX_UV`（盒式投影已烘焙）；
- 每个材质必须是 `SN_Tex_*` 且有 albedo_texture；
- 同一 URI 在多个 GLB 之间必须命中同一个 `Texture2D` 实例 id；
- 三角面总数：props 6282 / port 4996（与迁移前一致，证明只改材质与 UV）。

模块索引：[tools](../README.md)
