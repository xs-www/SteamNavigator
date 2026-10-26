# `website/tests/site-api-mirror.test.mjs`

> 作用：官网只读内容 API 的「最新 Windows zip 镜像」测试：覆盖后台流式下载 + SHA-256 校验、镜像可用后

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `makeTempDir(prefix)` | L25 |
| `sha256(buffer)` | L31 |
| `asset(name, size, url)` | L35 |
| `release({ tag = "v0.2.0-dev.4", windowsBytes, sumsHash } = {})` | L39 |
| `waitForAvailability(url, expected, timeoutMs = 8000)` | L67 |
| `withMirror(fixture, fn)` | L78 |

`data.downloads.windows` 暴露本地地址、旧 tag 目录清理、哈希不匹配不暴露、无 Windows 资产不下载。

## 契约与约束
- 契约：`server/site_api.mjs` 文件头「Windows 镜像」与小节；GitHub / 下载请求全部用 `fetchImpl` 注入，不访问真实网络。
- 每个用例用临时 `downloadDir` + 端口 0；下载是异步后台任务，用轮询等待「可用/保持不可用」。
- 断言落盘文件字节数、旧目录被删、API 的 `downloads.windows.url` 与 `github_url`，不只断言接口 200。

模块索引：[website](../README.md)
