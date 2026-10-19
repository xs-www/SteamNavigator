# `framework/domain/run/victory_service.gd`

> 作用：通关判定与服务：主线全部完成 + 造船厂内组装最低可运行大型船（大型船体 + 锅炉 + ≥1 货舱）。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `VictoryService` | L1 |

## 契约与约束

- 通关只由船厂安装成功后的 `check()` 触发；检查本身幂等，只在首次满足时写入 state.data.victory 并返回 newly_achieved=true。
- main_chain_complete 遍历注册表中 kind==main 的模板，全部出现在 contracts.completed 才为真；无主线模板返回 false。
- conditions 暴露 shipyard/main_complete/large_hull/boiler/cargo/ready 六个门槛供 UI/测试使用；large_hull 以 hull tier>=3 判断。
- summary 为纯 JSON：seed、构筑、航次、准时率、事故、收入/支出/利润、货币、债务、耐久、船体与已安装模块。
- 框架不引用具体 core ID；门槛全部来自注册表数据与 ShipOps 派生属性。

## 重点逻辑

### `check(state, hub)`

- 已通关时立即返回 achieved=true、newly_achieved=false，不覆盖 achieved_at/summary。
- 未满足门槛返回 achieved=false 与 conditions，不写入任何状态。
- 满足时先 summary() 再写入 victory，返回 summary 供命令层写入 data.victory 与领域事件。

模块索引：[framework/domain](../README.md)
