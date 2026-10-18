# `framework/application/queries/intel_view.gd`

> 作用：情报独立界面 ViewModel：快照时间/年龄、已发现港口市场表和 NPC 预计动向。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `IntelViewQuery` | L1 |

## 契约与约束

- 只返回已发现港口；未发现港口不会出现在快照中。
- 每个市场行附带 item_name_key；每个 NPC 行附带货物名和动作本地化键。
- `can_refresh` 由当前港情报站、港口状态和金币共同决定。

模块索引：[framework/application](../README.md)
