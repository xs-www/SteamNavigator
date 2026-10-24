# `framework/ui/components/sn_intel_table.gd`

> 作用：商品 × 港口对比表控件：一次渲染情报矩阵的列头、价格/趋势单元格与图例。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNIntelTable` | L1 |
| `KEY_UNKNOWN_PORT` | L29 |
| `KEY_GOODS` | L30 |
| `KEY_UNIT_WEIGHT` | L31 |
| `KEY_REF_PRICE` | L32 |
| `KEY_COL_AGE` | L33 |
| `KEY_LEGEND_CELL` | L34 |
| `KEY_LEGEND_GAP` | L35 |
| `KEY_LEGEND_TREND` | L36 |
| `UNKNOWN_TEXT` | L38 |
| `GAP_TEXT` | L39 |
| `bind(columns: Array, rows: Array, current_port_id: String, tr: Callable) -> void` | L47 |

The current port column reads the live market while every other column is a
frozen intelligence snapshot; undiscovered ports keep a masked column so the
player can still see how many ports are left to explore. All copy goes
through the `tr` callable, so the component never hardcodes a language.

Cell rules:
- `？`  : the port is unknown or the snapshot does not cover this commodity.
- `-`  : the port neither buys nor sells the commodity (per side otherwise).
- price: "port buy price / port sell price", i.e. player sell / player buy.

## 外观来源（外部贴图 + SNSkin）
- 面板底层用 Theme 变体 `SNElevatedPanel`（钢制抬高面）；每个表头 / 数值单元格
  用 `SNSkin.style("panel_recess")`（普通格，承袭仪表凹槽纹理）与
  `SNSkin.style("panel_steel")`（当前港高亮格），内容边距固定回 8 / 2 以保持旧
  表格行高与列宽，不插入新布局。
- 文字与趋势色一律取 `SNSkin.color(token)`（text.light / text.muted /
  brass.highlight / state.success / state.danger），本文件不写十六进制颜色。
- 尺寸约束：商品 180 px、单位重量 120 px、参考价 100 px、港口列 ≥120 px 的
  固定最小宽度不变；网格列数、行数与 `Content/Grid` 节点结构不变。
- 旧断言 `test_ui_shell.gd:201-202` 按 `StyleBoxFlat.bg_color` 检查单元格，换成
  纹理 StyleBoxTexture 后需由验收侧改为检查纹理来源（本文件不修改测试）。

模块索引：[framework/ui](../README.md)
