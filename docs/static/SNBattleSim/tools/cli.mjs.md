# `SNBattleSim/tools/cli.mjs`

> 作用：提供无浏览器的模组校验、状态机检查、确定性战斗快跑与示例模组导出，供 Agent 快速调试。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `load()` | L24 |

## 契约与约束
- 默认读取 SNBattleSim/mods 下的散装目录与 ZIP；export-sample 创建不覆盖的 .snavmod.zip。
- simulate 使用固定时间步长，输出机器可读 JSON；非零退出码表示校验或运行失败。

模块索引：[SNBattleSim](../README.md)
