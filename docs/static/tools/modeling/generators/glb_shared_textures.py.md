# `tools/modeling/generators/glb_shared_textures.py`

> 作用：把铁港建筑 GLB 的内嵌 trim-sheet 贴图外部化为稳定共享 URI（`iron_harbor_shared/<cell>.png`）并压缩 BIN chunk，使多栋建筑在 Godot 中共享同一 `Texture2D`；纯 Python（无 bpy），支持 dry-run / GLB 结构报告。

- 类型：项目配置/数据文件

## 契约与约束
- 只把 `images[].bufferView` 的内嵌图改成 `images[].uri`；保留 image 顺序，因此 `textures[].source` 与材质索引不动。
- 共享 PNG 必须与手写源 `docs/design/textures/iron_harbor/tiles/<cell>.png` 逐字节一致（`tile_matches`）；不一致时写出实际导出的字节并在报告里标 false，不静默换皮肤。
- 重写 BIN 时只保留被 accessor 引用的 bufferView，按 4 字节对齐重建并重映射 accessor 索引；`buffers[0].byteLength` 取新 BIN 长度。
- 输出 GLB 保持 spec 对齐（JSON chunk 空格补齐、BIN chunk 0 补齐、header 总长自洽）。
- 外部 PNG 放在 GLB 同目录子目录（`iron_harbor_shared/`），相对 URI 不使用 `..`，松散目录与挂载 ZIP 内路径都成立。
- 不修改内容清单 / manifest / 运行时接线；接线由 Lead 在验收后执行。

## 重点逻辑
### `externalize_glb(src, dst)`
- 提取每张内嵌图的字节 → 按 image name 归一 cell → 写共享 PNG → 改 URI → 去掉 image bufferView → 压缩 BIN 重写；返回逐图字节/tile 一致性/前后体积。
### `structure_report(path)`
- 只读解析节点/材质/贴图 URI/tri/glTF 与 Godot 两套包围盒（glTF Y-up ↔ Godot Z-up 映射），供结构验收与 LOD0/LOD1 对账。

模块索引：[tools](../../README.md)
