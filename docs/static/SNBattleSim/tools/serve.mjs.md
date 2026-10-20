# `SNBattleSim/tools/serve.mjs`

> 作用：以零依赖本地 HTTP 服务启动 SNBattleSim，避免浏览器 file 协议阻止 ES 模块加载。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `json(response, status, value)` | L22 |
| `readBody(request)` | L23 |

## 契约与约束
- 静态文件只能读取 SNBattleSim 内路径；模组 API 可读取直接子目录和 ZIP，并导出 .snavmod.zip。
- 默认监听 127.0.0.1:4174，可用 PORT 环境变量覆盖端口。

模块索引：[SNBattleSim](../README.md)
