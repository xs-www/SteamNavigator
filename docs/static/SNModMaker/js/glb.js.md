# `SNModMaker/js/glb.js`

> 作用：最小 GLB（glTF 2.0 二进制）解析器，为资源卡片提供场景节点、三角形网格、法线与材质基色。

- 关键依赖：`WebGL 渲染层 model_thumb.js`
- 类型：浏览器经典脚本

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `COMPONENTS` | L14 |
| `TYPE_COMPONENTS` | L22 |
| `GLB_MAGIC` | L23 |
| `JSON_CHUNK` | L24 |
| `BIN_CHUNK` | L25 |
| `identity()` | L27 |
| `multiply(a, b)` | L32 |
| `fromTRS(node)` | L46 |
| `localMatrix(node)` | L71 |
| `transformPoint(matrix, x, y, z)` | L76 |
| `transformNormal(matrix, x, y, z)` | L84 |
| `decodeDataUri(uri)` | L92 |
| `resolveBuffers(gltf, bin)` | L106 |
| `readAccessor(gltf, buffers, index)` | L117 |
| `materialColor(gltf, materialIndex)` | L139 |
| `buildPrimitive(gltf, buffers, primitive, world)` | L147 |
| `parse(input)` | L190 |
| `SNGLB (global)` | L268 |

## 契约与约束

- 只解析 JSON/BIN chunk、bufferView/accessor、node TRS/矩阵、TRIANGLES primitive 与 baseColorFactor；不支持贴图、Draco/KTX2、骨骼、变形目标与稀疏 accessor。
- 结果预变换到世界坐标并汇总 bbox、三角形数、节点数与材质数；无法预览的 primitive 跳过而不是整体失败。
- 纯函数、不依赖 DOM/WebGL，可在 Node 中直接测试。

模块索引：[SNModMaker](../README.md)
