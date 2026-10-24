# `framework/ui/components/sn_sparkline.gd`

> 作用：市场价格历史迷你折线；只有两个以上真实样本才绘制。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNSparkline` | L1 |
| `set_values(prices: Array, color: Color = Color.TRANSPARENT) -> void` | L26 |

Small price-history sparkline. Shows "样本不足" until at least two samples exist.

## 外观来源（外部贴图 + SNSkin）
- 折线 / 端点颜色由调用页面按趋势传入；未传色时默认取
  `SNSkin.color("brass.highlight")`，占位文案取 `SNSkin.color("text.muted")`。
  文件内不写十六进制颜色，`Color.TRANSPARENT` 只作为「未指定颜色」的哨兵。
- 尺寸约束：`custom_minimum_size = (64, 24)`、线宽 1.8、端点 2.2、占位字号 9
  与 `set_values(prices: Array, color: Color)` 调用签名保持不变（调用方可继续传色）。

模块索引：[framework/ui](../README.md)
