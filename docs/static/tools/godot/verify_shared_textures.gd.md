# `tools/godot/verify_shared_textures.gd`

> 作用：共享贴图建筑 GLB 的只读验收探针：通过 `ContentAssetLoader` 加载 5 栋 `SN_HT_*`，统计每栋 surfaces/tri/材质 albedo `Texture2D` 实例，验证同 cell 跨建筑共享同一实例、不同 cell 不塌缩、全局唯一贴图数 = 唯一 cell 数，并支持松散与挂载 ZIP 两种加载路径。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `BUILDING_NAMES` | L39 |
| `EXPECTED_TRIS` | L46 |
| `LOOSE_ROOT` | L53 |
| `ZIP_ROOT` | L54 |
| `PACK_PATH` | L55 |

## 契约与约束
- headless 可跑（不需要渲染）；`-- --mode=loose` 读 `res://dev_mods/core/...`，`-- --mode=zip` 把 `dev_mods/core` 打包装载后读 `res://mods/core/...`。
- 纹理实例 id 是 64 位，报告里以 JSON 数字/字典比较，避免转 float 丢失精度。
- 失败（缺失 URI、材质无贴图、跨建筑不共享、tri 与预期不符）退出码 1；最终 `[shared-textures] JSON {...}` 行为机器可读报告。
- 只读：不改资产、不写内容、不挂舞台。

模块索引：[tools](../README.md)
