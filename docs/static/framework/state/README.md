# `framework/state`

> 运行态数据模型。GameState 是唯一持久化状态，定义对象永不进入存档。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `game_state.gd` | 纯数据运行态：可深克隆、可序列化、可哈希、事务替换。 | [查看](./game_state.gd.md) |

## 模块契约

- GameState 可深克隆、可哈希，JSON 往返哈希一致。
