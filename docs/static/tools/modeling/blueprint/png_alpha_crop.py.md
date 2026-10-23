# `tools/modeling/blueprint/png_alpha_crop.py`

> 作用：对 Blender 输出的 8-bit RGBA PNG 做无第三方依赖的 Alpha 包围框裁切；保留颜色配置块，

- 类型：项目配置/数据文件

用确定性的 filter-0 + zlib 重编码覆盖原图，并返回原始画布、内容框、留白框与最终尺寸元数据。

## 契约与约束
- 只接受 Blender 线稿管线使用的非交错 RGBA8 PNG；其它 PNG 类型明确报错，不静默转码。
- 内容像素判据为 `alpha > threshold`；裁切框使用左/上包含、右/下不包含坐标。
- 写入采用同目录临时文件 + `os.replace`，失败时不破坏已有 PNG。

模块索引：[tools](../../README.md)
