# UI Icons

放置全局通用图标，统一 24×24 画布。

计划分类：

- `goods/`：商品图标
- `facilities/`：交易所、船厂、补给、情报站、港务
- `status/`：风险、声望、耐久、重量、金币、煤、水
- `actions/`：买入、卖出、接受、出航、维修

要求：

- 文件名 `snake_case`，例如 `good_iron_ore.svg`。
- 优先 SVG；需要位图时用透明 PNG，2× 导出（48×48）。
- 颜色通过 `modulate` 适配，不把主题色烘焙进图标。
