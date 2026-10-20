# `framework/modding/core_completeness_checker.gd`

> 作用：检查官方 core 包是否提供 MVP 所需的最少内容与构筑。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `CoreCompletenessChecker` | L1 |
| `check(hub: RegistryHub, packages: Dictionary, order: Array[String]) -> Dictionary` | L7 |

## 契约与约束

- 要求 core 存在、required=true 且进入加载顺序。
- 最低数量：3 船体、2 锅炉、3 策略、4 港口原型、5 主线、2 事件、2 岗位等。
- 要求存在 `strategy.economy/standard/fast`、大型船体、工程师/领航员与风险事件标签。
- 至少一套初始构筑可解析为 hull + boiler + cargo。

模块索引：[framework/modding](./README.md)
