# `tools/modeling/generators/render_lod1_kit_ships_preview.py`

> 作用：LOD1 基础套件（M0-5）的预览渲染：在工作台里逐件把 `SN_<Asset>_LOD1` 临时摆到

- 类型：项目配置/数据文件

LOD0 右侧同机位渲染对比图（kit 26 + 船 4），再按类别输出 8 张 LOD1 lineup；渲染用
Workbench TEXTURE（与 kit 预览一致），临时相机 / 灯光 / 地面 / hide_render 在 finally
里全部还原，不保存 .blend、不改资产变换。

## 契约与约束
- 只读资产：唯一写操作是 LOD1 对象的临时 location 与场景渲染设置，渲染后还原。
- 输出双份：`.design/lod1_kit_ships/preview/*.png`（本地）与
  `docs/design/screenshots/lod1/*.png`（文档证据；仓库对 screenshots 目录 gitignore，
  提交时需要 `git add -f`，与历史批次一致）。
- 对比图机位：3/4 视角、LOD1 放在 LOD0 包围盒右侧 2 m，地面/水线对齐；两侧用同一
  包围盒取景，因此可以直接比较轮廓与尺寸。

## 重点逻辑
### `render_comparisons(assets=None)`
- 逐件隐藏其它对象 → 摆 LOD1 → 取 LOD0+LOD1 世界包围盒 → 相机取景 → 渲染 1024×640。
### `render_lineups()`
- 按 category 取 LOD1 对象（工作台 y=780 一排）→ 正交构图渲染 1440×620。

模块索引：[tools](../../README.md)
