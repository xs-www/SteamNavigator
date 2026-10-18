# `framework/ui/components/sn_sparkline.gd`

> 作用：市场价格历史迷你折线；只有两个以上真实样本才绘制。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNSparkline` | L1 |

## 契约与约束

- 样本不足时显示“样本不足”，不根据 up/down 状态伪造折线。
- 输入为真实价格历史数组；颜色由调用页面按趋势传入。

模块索引：[framework/ui](../README.md)
