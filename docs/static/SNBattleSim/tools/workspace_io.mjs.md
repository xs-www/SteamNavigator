# `SNBattleSim/tools/workspace_io.mjs`

> 作用：在 SNBattleSim/user_data 中原子读写模拟器工程，作为浏览器 localStorage 之外的明确持久化副本。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MAX_BYTES` | L12 |
| `readWorkspace(userDataRoot)` | L14 |
| `writeWorkspace(userDataRoot, value)` | L23 |

## 契约与约束
- 只读写固定文件 user_data/workspace.json，不接受客户端路径。
- 工程必须是对象且 JSON 不超过 5 MB；写入经临时文件原子替换。

模块索引：[SNBattleSim](../README.md)
