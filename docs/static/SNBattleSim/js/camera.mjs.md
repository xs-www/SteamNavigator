# `SNBattleSim/js/camera.mjs`

> 作用：为无限 2D 战场计算能容纳全部在场舰船的跟随镜头，并提供世界坐标到画布坐标的转换。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `clamp(value, min, max)` | L10 |
| `createCamera()` | L14 |
| `cameraTarget(ships, width, height, padding = 86)` | L18 |
| `updateCamera(camera, ships, width, height, smoothing = 0.09)` | L38 |
| `worldToScreen(camera, point, width, height)` | L51 |
| `screenWorldBounds(camera, width, height)` | L58 |

## 契约与约束
- 镜头只改变表现，不参与战斗物理或逃脱判定。
- 取景范围来自全部未脱离战场的舰船；失能船仍属于战场并保留在画面中。
- 镜头中心与缩放平滑追随目标包围盒，初次取景可以直接吸附。

模块索引：[SNBattleSim](../README.md)
