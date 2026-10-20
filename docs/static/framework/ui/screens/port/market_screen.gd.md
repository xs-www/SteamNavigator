# `framework/ui/screens/port/market_screen.gd`

> 作用：港口市场页面场景：展示行情、真实价格历史、持仓成本及买卖操作；作为泊位侧栏时按 620 px 窄列设计（纵向商品条目列表，替代旧九列表格），外层 PageScroll 负责竖向滚动。

- 关键依赖：`SNSparkline`、`SNSectionHeader`、`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MarketScreen` | L1 |
| `command_requested (signal)` | L14 |
| `SPARKLINE_SCENE` | L16 |
| `COLOR_TEXT` | L17 |
| `COLOR_MUTED` | L18 |
| `COLOR_TEAL` | L19 |
| `COLOR_RED` | L20 |
| `COLOR_GREEN` | L21 |
| `ENTRY_SEPARATION` | L23 |
| `bind(view_model: Dictionary, translate: Callable) -> void` | L28 |

## 契约与约束

- bind(view_model, translate) 接收 Shell 组合后的 current_port/money/ship/market/trends，不访问 AppContext 或任何总线。
- 买卖按钮只发出 trade.buy/trade.sell command_requested；可买性、港存和可售数量只决定展示与按钮禁用。
- 折线只使用 recent_prices 真实样本；少于两个样本显示缺省状态，趋势颜色为红降绿升。
- 窄列布局：每件商品是 `SNInsetPanel` + 三行（名称/仅收购标记 + 趋势 sparkline 与百分比；单价/库存/持有/可售/均价/单位重量；买入 1/5/10 与卖出 1/5），行内 HBox 不允许横向裁切；`_grid_label(text, size, color)` 保留 72 px 最小宽（现有 UI 测试依赖）。
- 摘要（金币/重量、货舱/库存成本）与市场提示单独成段，长提示用 `_paragraph()`（AUTOWRAP_WORD_SMART），密集字段标签仍保持单行。
- 仅收购商品隐藏买入数量组并明确显示 sell-only；平均成本缺失时显示破折号；点击发出 {item_id, amount}。

模块索引：[framework/ui](../../README.md)
