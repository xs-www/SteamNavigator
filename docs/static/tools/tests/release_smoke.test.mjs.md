# `tools/tests/release_smoke.test.mjs`

> 作用：成品启动门禁的 Node 回归测试；真实子进程覆盖成功、Godot 报错但退出 0、缺标记、崩溃和超时。

- 类型：Node ES 模块

- 不运行游戏、不读写玩家目录；验证隔离用户环境与 Windows 大小写环境变量覆盖。

模块索引：[tools](../README.md)
