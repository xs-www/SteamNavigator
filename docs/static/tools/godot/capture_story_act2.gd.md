# `tools/godot/capture_story_act2.gd`

> 作用：阶段 4.5.4「酒馆 / 线索 / 保底探索」真实渲染截图工具（窗口模式）。走完教学

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MAIN_SCENE` | L22 |
| `OUT_DIR` | L23 |
| `WINDOW` | L24 |
| `SEED` | L25 |
| `STEADY_BUILD` | L26 |
| `WATCHDOG_SECONDS` | L27 |
| `SHOTS` | L29 |
| `_init() -> void` | L40 |

第二幕，抓三张 1440×900 截图：酒馆页（物价情报 + 港口线索）、第三种货上架后的
起始港市场、以及第二条 L3 线索在海图上的搜索圈。

用法（**必须窗口模式**，`--headless` 下视口纹理为空图）：
  godot --path . --resolution 1440x900 --script res://tools/godot/capture_story_act2.gd

输出（1440×900，写入 `docs/design/screenshots/story/`）：
  tutorial_tavern.png              酒馆：物价情报矩阵 + 港口线索列表
  tutorial_market_third_good.png   起始港市场：纺织品 / 香料 / 木材三种货
  tutorial_sea_chart_clue.png      海图：第二条 L3 线索的方向与搜索圈

## 契约与约束
- 全程用真实 Shell / 真实命令推进（story.advance / trade / intel.refresh），
  只把「抵达」事件按 Shell 的真实时序喂给 `story.observe`，不伪造渲染数据。
- 硬性断言：酒馆页出现物价情报表与线索购买入口、活跃线索 = 1 且等级 1；
  第三件货上架后市场 = 3 条贸易货物；第二条线索等级 3、带搜索圈。

模块索引：[tools](../README.md)
