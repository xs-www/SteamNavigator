# `framework/ui`

> 展示层。当前只有一个最小可玩外壳，后续可拆分为海图/面板/出航等场景。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `shell/main.gd` | 可玩 UI 外壳：总览/市场/委托/船厂/情报/出航六个独立界面，以及海图、事件选择与诊断。 | [查看](./shell/main.gd.md) |
| `shell/main.tscn` | 框架源文件：main.tscn | 本页 |

## 模块契约

- UI 只识别 Query/Command 与定义类型，不识别 core 内容。
