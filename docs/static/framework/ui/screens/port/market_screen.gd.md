# `framework/ui/screens/port/market_screen.gd`

> 作用：港口市场页面场景：展示行情、真实价格历史、持仓成本及买卖操作。

- 关键依赖：`SNSparkline`、`SNSectionHeader`、`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MarketScreen` | L1 |
| `command_requested (signal)` | L8 |
| `bind(view_model: Dictionary, translate: Callable) -> void` | L20 |

## 契约与约束

- bind(view_model, translate) 接收 Shell 组合后的 current_port/money/ship/market/trends，不访问 AppContext 或任何总线。
- 买卖按钮只发出 trade.buy/trade.sell command_requested；可买性、港存和可售数量只决定展示与按钮禁用。
- 折线只使用 recent_prices 真实样本；少于两个样本显示缺省状态，趋势颜色为红降绿升。
- 九列市场表的字段文字保持单行，单元格、趋势和买卖按钮组保留可读最小宽度。
- 仅收购商品隐藏买入数量组并明确显示 sell-only；平均成本缺失时显示破折号。

模块索引：[framework/ui](../../README.md)
