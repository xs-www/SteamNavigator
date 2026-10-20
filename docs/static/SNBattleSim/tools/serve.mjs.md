# `SNBattleSim/tools/serve.mjs`

> 作用：以零依赖本地 HTTP 服务启动 SNBattleSim，避免浏览器 file 协议阻止 ES 模块加载。

- 类型：Node ES 模块

## 契约与约束
- 只允许读取 SNBattleSim 目录内的已存在文件，路径解析后越界直接返回 403。
- 默认监听 127.0.0.1:4174，可用 PORT 环境变量覆盖端口。

模块索引：[SNBattleSim](../README.md)
