# `tools/art/gen_iron_harbor_trim_sheet.py`

> 作用：铁港建筑套件**共享 trim sheet 的确定性画图器**：按 `docs/design/textures/iron_harbor/iron_harbor_trim_sheet_2048.spec.json` 画出 4×4×512 px 图集（评审件）与 16 张 512² 独立平铺贴图（运行时采样件），并写 stats。

- 类型：项目配置/数据文件

## 契约与约束

- 唯一输入是 spec JSON（含 16 个 cell 的 id/col/row/kind/palette/mean_rgb/detail），不读代码；`--out-root` 默认仓库根，`--spec/--stats` 可覆盖；两跑必须字节一致（cell 级种子由 cell id 派生，不依赖遍历顺序）。
- 每 cell 内容自身 U/V 无缝（512 内容按 mod 坐标生成，无 gutter），砖层 512/26 px、石层 120 px、屋面肋 36 px、木板 53 px 等尺度常量由 `px_per_m=256` 与 `tile_m=2.0` 推得。
- 自检：每 cell 实测 mean 与目标差 ≤±14（实测 ≤±0.5）、接缝率（自身边界差/内部差）<2.5（实测 0.26–1.18）、cell 完整/索引不撞、PNG 尺寸、确定性；任一失败非 0 退出。
- 产出：`iron_harbor_trim_sheet_2048.png`（2048²，行 0 在顶部）+ `tiles/<cell>.png`（PNG-8 ≤96 色，单张 145–187 KB）+ `.stats.json`（每 cell mean/seam/bytes 与图集 sha256）。
- 只画图不建材质：材质↔cell 的映射在 `sn_iron_harbor_materials.MATERIAL_SURFACES`，改 cell 语义要两边一起改。重跑：`python tools/art/gen_iron_harbor_trim_sheet.py`。

模块索引：[tools](../README.md)
