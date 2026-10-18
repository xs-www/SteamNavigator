# `framework/bootstrap/bootstrap.gd`

> 作用：组合根启动编排：创建 AppContext、调用 ModLoader、注册公共 API 并把结果汇总为 StartupReport。

- 关键依赖：`AppContext`、`ModLoader`、`FrameworkApi`、`StartupReport`、`ProjectSettings`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `Bootstrap` | L1 |
| `run(overrides: Dictionary = {}) -> StartupReport` | L8 |

## 契约与约束

- 加载失败不抛异常：所有可预期错误进入 StartupReport，UI 据此进入诊断界面。
- 即使 fatal，也会注册命令/查询并冻结空注册表，保证后续调用返回结构化错误。
- 测试可通过 `run(overrides)` 覆盖扫描根、存档目录、日志开关与自动存档。

## 重点逻辑

### `run(overrides)`

- 创建 AppContext 后立即加载框架基础本地化，再交给 ModLoader 完成扫描、解析、编译、校验与冻结。
- 最终调用 `FrameworkApi.register(context)`；命令/查询在内容加载失败时仍可用，便于诊断。
- `AppContext.set_active(context)` 是进程级单例入口，测试每次启动都会覆盖。

模块索引：[framework/bootstrap](./README.md)
