# `framework/application/queries/intel_view.gd`

> 作用：情报独立界面 ViewModel：快照时间/年龄、商品 × 港口对比矩阵（含未探索港口列）与 NPC 预计动向。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `IntelViewQuery` | L1 |

## 契约与约束

- 矩阵 columns 顺序 = 当前港 → 已发现港 → 未发现港（各按 port_id 升序）；未发现港整列保留：name_key=ui.label.unknown_port、masked=true，单元格 known=false。
- rows 为商品全集（当前港实时普通商品 ∪ 快照普通商品，按 item_id 升序），cells 与 columns 同序等长；行含 item_id/name_key/unit_weight/ref_price。
- 价格口径与 MarketOps 一致：buy_price=floor(price*DEFAULT_TRADE_MARGIN)（港口收购价/玩家卖出），sell_price=round(price) 仅 buyable 否则 -1（港口出售价/玩家买入）；-1 由 UI 显示为 `-`，known=false 显示 `？`。
- 当前港列读实时市场（age_hours=0），其它港只读快照并给出 age_hours（快照未覆盖 = -1）。
- 旧字段 ports/npcs/has_report 保留；has_report=false 时仍返回可用矩阵（当前港实时列有价，其余 `？`）。
- 快照 market 行新增 trend_percent（见 intel_service）；每个市场行附带 item_name_key，NPC 行附带货物名和动作本地化键。
- `can_refresh` 由当前港情报站、港口状态和金币共同决定。

模块索引：[framework/application](../README.md)
