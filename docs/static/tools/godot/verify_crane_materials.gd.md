# `tools/godot/verify_crane_materials.gd`

> 作用：四台起重机 GLB 的**共享贴图运行时验收**（只读）：外部贴图 URI 解析、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `CRANES` | L18 |
| `_init() -> void` | L30 |

每个网格有 UV、每个材质都绑定贴图，且同一贴图在多个 GLB 之间是同一个 Texture2D 实例。

用法：
  godot --headless --path . --script res://tools/godot/verify_crane_materials.gd

判定口径：
- 走 `ContentAssetLoader.load_scene()`（运行时模组资产路径），而不是 `ResourceLoader`；
- GLB 的 `images[].uri` 必须是 `shared_materials/<texture>.png`，文件存在；
- 每个 surface 必须有 `ARRAY_TEX_UV`（UV 箱投影已烘焙）；
- 每个材质必须有 `albedo_texture`；
- 同一材质名（= 同一贴图）在不同 GLB 里必须命中同一个 `Texture2D` 实例 id；
- 记录材质名 / 贴图实例 / UV 数量，失败返回非 0。

模块索引：[tools](../README.md)
