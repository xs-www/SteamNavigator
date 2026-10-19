# `SNModMaker/js/model_thumb.js`

> 作用：用共享 WebGL 上下文把 GLB 渲染成自动取景的 PNG 缩略图，并按键缓存结果。

- 关键依赖：`glb.js`、`store.js（dataUrlToBytes）`
- 类型：浏览器经典脚本

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `WIDTH` | L15 |
| `HEIGHT` | L16 |
| `CACHE` | L17 |
| `UP` | L18 |
| `VIEW_DIRECTION` | L19 |
| `normalize(vector)` | L28 |
| `subtract(a, b)` | L33 |
| `cross(a, b)` | L37 |
| `dot(a, b)` | L41 |
| `lookAt(eye, target, up)` | L45 |
| `perspective(fieldOfView, aspect, near, far)` | L57 |
| `multiply(a, b)` | L67 |
| `compile(vertexSource, fragmentSource)` | L81 |
| `ensureContext()` | L100 |
| `drawPrimitive(primitive, mvp)` | L141 |
| `draw(model)` | L175 |
| `cacheKey(asset)` | L203 |
| `cached(asset)` | L208 |
| `forget(path)` | L213 |
| `render(asset)` | L219 |
| `SNModelThumb (global)` | L230 |

## 契约与约束

- 固定 480×360、透明背景、单方向光 + 环境光；相机按 bbox 自动取景，不提供旋转交互。
- 单例 canvas/context 复用，每张图渲染后立即 `toDataURL` 并缓存，避免资源卡片重绘时重复解析与绘制。
- 没有 WebGL 或解析失败时返回 null，调用方保留 GLB 占位，不影响编辑/导出。

模块索引：[SNModMaker](../README.md)
