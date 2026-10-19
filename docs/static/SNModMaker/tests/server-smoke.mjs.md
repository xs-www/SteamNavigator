# `SNModMaker/tests/server-smoke.mjs`

> 作用：本地服务磁盘 API 冒烟测试：在隔离临时目录验证游戏模组部署、覆盖、枚举、删除与旧版本清理。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `waitForServer()` | L30 |

## 契约与约束

- 启动真实 tools/serve.mjs 子进程，并通过三个环境变量把所有写入限制在临时目录。
- 测试结束终止服务并删除临时目录；任何断言失败以非零退出码结束。

模块索引：[SNModMaker](../README.md)
