# `tools/godot/capture_port_stage_res.gd`

> 作用：铁港建筑验收的 PortStage 实机截图（分辨率参数化）：加载 `port_stage_preview.tscn`，把窗口设到命令行给定尺寸后抓一张 PNG，并顺带打印内容 GLB 的材质/贴图自证行；第三个参数可切换 LOD0/LOD1 标签与 tri 期望，用于 LOD1 临时入舞台的 960×540 可读性证据。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `PREVIEW_SCENE` | L30 |
| `OUT_DIR` | L31 |
| `SETTLE_FRAMES` | L32 |
| `SETTLE_SECONDS` | L33 |
| `RESIZE_FRAMES` | L34 |
| `WATCHDOG_SECONDS` | L35 |
| `TOWN_ASSETS` | L41 |
| `EXPECTED_ASSET_TRIS` | L51 |
| `EXPECTED_LOD1_TRIS` | L63 |
| `_init() -> void` | L79 |

## 契约与约束
- 用法：`godot --path . --script res://tools/godot/capture_port_stage_res.gd -- <w> <h> [LOD0|LOD1] [tag]`；必须窗口模式（headless 下视口纹理为空）。`tag` 可选，用于批次 B 的五栋组合截图（如 `combo_a`），配合环境变量 `SN_TOWN_COMBO=a|b` 选择街景建筑混搭。
- 输出 `docs/design/screenshots/iron_harbor_architecture/SN_HT_Warehouse_Long_<LABEL>[_<tag>]_port_stage_<w>x<h>.png`；失败以非 0 退出码结束。
- `_report_asset_materials()` 逐个 `load()` 5 个槽位 GLB（`TOWN_ASSETS`：warehouse_long / warehouse_short / harbor_office / cargo_shed / tavern，stage 采样同一路径），打印每栋 `[asset] ... surfaces/tris/uv_surfaces/textured_surfaces/materials/textures`；有面缺贴图/缺 UV、或 tri 数与期望表（LOD0 7436 / 3788 / 10336 / 3356 / 5116；LOD1 1584 / 1060 / 1896 / 776 / 1248）不符都记为失败。stage 里 static batching 会把逐对象节点合并释放，所以**不能**在场景树里找它。
- `budget: ... tris=` 是整台 stage 的总量（含并行工作流往城镇加的道具），**不能**当单资产增量证据，单资产证据看 `[asset]` 行。
- 与既有 `capture_port_stage.gd`（固定 1440×900、preview+sparse 两张）并行存在，不改后者行为。

模块索引：[tools](../README.md)
