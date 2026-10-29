# `framework/bootstrap`

> 启动与组合根。负责在场景加载前完成内容加载，并向 UI/用例暴露 AppContext。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `app_bootstrap.gd` | SceneTree Autoload：首场景加载前运行 Bootstrap 并保存 context / report；发布版还会先应用已校验的自动更新 pending（core 包替换 + exe 备份清理）。 | [查看](./app_bootstrap.gd.md) |
| `app_context.gd` | 应用组合根：持有服务、总线、GameState 与启动报告，交给命令/查询/UI 使用；`telemetry` 是可选的本局游玩日志记录器（默认 null，未开启上传时不创建）。 | [查看](./app_context.gd.md) |
| `bootstrap.gd` | 组合根启动编排：创建 AppContext、调用 ModLoader、注册公共 API 并把结果汇总为 StartupReport。 | [查看](./bootstrap.gd.md) |
| `framework_runtime.gd` | 进程退出前清理静态操作码/公式注册表。 | 本页 |
| `startup_report.gd` | 启动结果 DTO：分级错误/警告、启用模组摘要、内容计数、耗时与注册表状态。 | [查看](./startup_report.gd.md) |

## 模块契约

- Autoload 与主场景的边界：Autoload 只做一次 Bootstrap，UI 只读 AppContext/Query。
- 启动失败仍进入诊断界面，不允许开始游戏。
