# `tools/godot/capture_story_act1.gd`

> 作用：阶段 4.5.3「市场并市 + 第二主线」真实渲染截图工具（窗口模式）。走完教学首段，

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MAIN_SCENE` | L21 |
| `OUT_DIR` | L22 |
| `WINDOW` | L23 |
| `SEED` | L24 |
| `STEADY_BUILD` | L25 |
| `WATCHDOG_SECONDS` | L26 |
| `SHOTS` | L28 |
| `_init() -> void` | L37 |

抓两张 1440×900 截图：开局市场页的「补给区块」，以及第二港市场只开放两种贸易货物。

用法（**必须窗口模式**，`--headless` 下视口纹理为空图）：
  godot --path . --resolution 1440x900 --script res://tools/godot/capture_story_act1.gd

输出（1440×900，写入 `docs/design/screenshots/story/`）：
  tutorial_market_supply.png  开局市场页：补给（煤 / 水）区块 + 非阻塞目标条
  tutorial_market_goods.png   第二港市场：只有纺织品 / 香料两种贸易货物 + 补给区块

## 契约与约束
- 全程用真实 Shell / 真实命令推进（story.advance / supply.buy_* / trade 视图），
  不伪造渲染数据。
- 硬性断言：开局市场出现 `MarketSupply` 且 trade rows 为 0；第二港市场出现 2 条
  贸易货物；失败返回非零退出码。
- 强制 zh_CN、窗口 1440×900、`_settings_applied = true`。

模块索引：[tools](../README.md)
