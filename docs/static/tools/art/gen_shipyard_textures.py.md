# `tools/art/gen_shipyard_textures.py`

> 作用：船厂两张授权贴图的确定性生成器：纵剖图 `ship_section.png`（1792×1008）与船卡缩略图 `ship_thumb_ironclad.png`（640×360）。

- 类型：项目配置/数据文件

## 契约与约束

- 只依赖 Pillow + numpy；同一版本环境像素确定，几何/配色/构图锚点集中在文件顶部常量表。
- 输出路径相对 `--out-root`（默认仓库根）：`assets/ui/shipyard/`；`--section-only` / `--thumb-only` 可单独重建。
- 纵剖图不烘焙文字与 UI 边框；`ANCHORS` 必须与 `sn_ship_view.gd._chip_anchor()` 的舱室比例同步。
- 缩略图从 `docs/design/screenshots/ironclad_broadside.png` 裁切并替换为 UI 调色板背景。
- 重跑命令：`python tools/art/gen_shipyard_textures.py`；改完图不需要改页面代码。

模块索引：[tools](../README.md)
