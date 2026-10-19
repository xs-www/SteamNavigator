# `framework/domain/contracts/run_factory.gd`

> 作用：新局工厂：选构筑/地图配置、生成船只与市场、NPC、仓库/运输/统计/通关结构、初始主线与普通委托。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `RunFactory` | L1 |

## 契约与约束

- 框架不引用具体 core ID：默认构筑/地图配置取该类型第一个注册定义。
- 创建顺序：船 → 地图 → 玩家/状态 → 仓库/运输/统计/通关字段 → 市场 → NPC → 主线 1 → 普通 offer。
- 主线 1 自动装载并接取；后续主线由 VoyageService 生成 offer。
- 普通委托初始池与抵达刷新共用 ContractOps.generate_normal_offers，初始键为 `initial:<port>`。
- 生成失败返回结构化 Result，不写入 AppContext。

## 重点逻辑

### `create_run(context, build_id, requested_seed)`

- 本地 RngService 由 seed 派生，成功后才由 run.start 写回 context，失败不污染现有随机流。
- 地图生成依赖初始船只属性（起始补给可达性检查）。
- 调用 WarehouseOps.ensure_structure 初始化每港仓库与 ship.transit_modules；写入 stats 默认值与 victory=null。
- 初始债务按 build.loan 写入 player.debt，之后由收入自动偿还。

模块索引：[framework/domain](../README.md)
