# `framework/ui/components/sn_cloud_veil.gd`

> 作用：航行演出的云层转场层（阶段 3）。全屏、不吃鼠标，用程序化云团把画面从

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNCloudVeil` | L1 |
| `COLOR_BASE` | L17 |
| `COLOR_MID` | L18 |
| `COLOR_HIGH` | L19 |
| `PUFF_COUNT` | L20 |
| `DRIFT_PIXELS` | L22 |
| `PUFF_TEXTURE_SIZE` | L25 |
| `SEED` | L26 |
| `advance(delta: float, speed: float = 0.06) -> void` | L53 |
| `is_covered() -> bool` | L59 |
| `is_clear() -> bool` | L63 |

3D 港口「盖住」，等界面切到海图后再「散开」；抵达时反向再用一次。

## 契约与约束
- **只渲染，不管时序**：`cover`（0 散开 – 1 盖满）由 `VoyagePresentation`
  逐帧算好推过来，本控件不做缓动、不发信号，因此演出顺序只有一处真源，
  也方便无头测试直接断言 `cover`。
- 云团位置在 `_ready` 里用固定种子一次性生成（同一次运行可复现），
  每帧只按 `cover` 与 `drift` 重排，不重抽随机。
- `cover <= 0` 时完全不绘制并隐藏，避免在港口页白吃一次全屏 blended 绘制。

模块索引：[framework/ui](../README.md)
