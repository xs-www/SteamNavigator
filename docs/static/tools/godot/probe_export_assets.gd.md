# `tools/godot/probe_export_assets.gd`

> 作用：发布路径资产探针（只读）：挂载真实发布包 `release/SteamNavigator/mods/core-1.0.0.snavmod.zip`（或 `-- --pack=<abs path>`），在 headless 下逐项验证「发布构建的模组内原始 PNG/GLB 能否被 `ContentAssetLoader` 加载」，并统计贴图尺寸/未压缩 RGBA 显存量、重复内容、加载耗时与缺失资产行为，输出机器可读 JSON。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `DEFAULT_PACK` | L24 |
| `PACK_ROOT` | L25 |

## 契约与约束
- 只读：不改内容、不写存档；唯一副作用是可选 `--report=<path>` 的 JSON 落盘。
- headless 可跑（不需要 GPU）；`-- --pack=<zip>` 覆盖默认发布包路径，`-- --limit=<n>` 限制 GLB 抽样数（默认全部）。
- 退出码 0 = 关键断言全过；1 = 有失败项（此时仍打印完整报告便于取证）。
- 断言：FileAccess 能看到 zip 内 manifest/GLB/PNG；Image.load_from_file 读 zip 内 PNG 成功；GLB 外部 image URI 能解析到 zip 内文件且 albedo_texture 非空；缺失资产返回 null 且重复调用不再尝试。
- 统计口径：`ImageTexture.create_from_image()` 默认无 mipmap、无 VRAM 压缩 → RGBA8 显存 = w*h*4。

模块索引：[tools](../README.md)
