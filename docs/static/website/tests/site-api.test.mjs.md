# `website/tests/site-api.test.mjs`

> 作用：官网只读内容 API（`server/site_api.mjs`）的 Node 测试：覆盖 health / release 响应、5 分钟缓存与并发共享、

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `asset(name, size, id)` | L25 |
| `release(overrides = {})` | L34 |
| `response(payload, ok = true, status = 200)` | L51 |
| `makeFallbackFile(data)` | L55 |
| `flickerClock(startIso)` | L63 |
| `withApi(options, fn)` | L73 |

GitHub 失败时旧缓存与镜像 fallback 的降级链、无数据 503、方法与路径错误，以及 token 不下发。

## 契约与约束
- 契约：`server/site_api.mjs` 文件头与 `docs/design/WEBSITE.md` §7/§8；不访问真实网络。
- `fetchImpl` 注入 GitHub 响应；`now` 注入时钟以验证缓存过期；每个用例用临时 fallback 文件 + 端口 0。
- 断言响应头 `Cache-Control`、`source` 字段与具体版本字段，不只断言 200。

模块索引：[website](../README.md)
