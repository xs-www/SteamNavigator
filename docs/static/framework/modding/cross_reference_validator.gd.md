# `framework/modding/cross_reference_validator.gd`

> 作用：Schema 之后的语义校验：材料、构筑、委托奖励、事件条件/效果、港口市场与地图配置的引用完整性。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `CrossReferenceValidator` | L1 |
| `validate(hub: RegistryHub) -> Dictionary` | L13 |

## 契约与约束

- 所有可引用 ID 必须在已注册定义中存在；未知条件/效果操作码直接报错。
- 主线序列必须覆盖 1–5；普通委托至少一个模板；最终委托应同时包含货物与旅客。
- 港口原型必须提供 exchange 与 contracts；市场引用商品/材料必须存在。
- 地图配置的港口数、名称键数量、必需设施标签与默认构筑均被检查。

模块索引：[framework/modding](./README.md)
