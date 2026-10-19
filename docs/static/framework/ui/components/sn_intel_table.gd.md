# `framework/ui/components/sn_intel_table.gd`

> 作用：商品 × 港口对比表控件：一次渲染情报矩阵的列头、价格/趋势单元格与图例。

- 关键依赖：`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNIntelTable` | L1 |
| `bind(columns: Array, rows: Array, current_port_id: String, tr: Callable) -> void` | L41 |

## 契约与约束

- bind(columns, rows, current_port_id, tr) 为纯数据入口，可在 headless 下实例化；重复 bind 会清空旧内容后重建。
- known=false 显示 `？`；buy_price/sell_price 为 -1 表示该侧不经营，显示 `-`（两侧都缺则整格 `-`）。
- 趋势只显示红降/绿升的百分比数字（trend_percent×100），不使用文字；当前港口列用黄铜高亮。
- 商品/单位重量/参考价列保持紧凑固定宽度，仅港口列均分剩余空间并保留 120 像素最小宽度；普通单元格显式使用深青背景，禁止回退到 StyleBoxFlat 默认灰色。
- 全部文案经 tr: Callable 取本地化键（含 ui.intel.col_age 格式串），缺键回退键名，不硬编码中文。

模块索引：[framework/ui](../README.md)
