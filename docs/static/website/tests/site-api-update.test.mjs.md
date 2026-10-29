# `website/tests/site-api-update.test.mjs`

> 作用：官网只读内容 API 的「游戏内自动更新」测试：覆盖 `update-manifest.json` 与 package / core 镜像、

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `TAG` | L25 |
| `PUBLISHED_AT` | L26 |
| `CORE_NAME` | L27 |
| `MANIFEST_NAME` | L28 |
| `makeTempDir(prefix)` | L35 |
| `sha256(bytes)` | L41 |
| `asset(name, bytes, url)` | L45 |
| `makeFixture(options = {})` | L49 |
| `response(body, status = 200)` | L126 |
| `createFetch(fixture, counters, options = {})` | L133 |
| `withUpdateApi(fixture, options, fn)` | L167 |
| `getJson(url)` | L187 |
| `waitForHttp(url, predicate, timeoutMs = 8000)` | L192 |
| `waitFor(predicate, timeoutMs = 4000)` | L207 |
| `updateUrl(instance)` | L216 |

`GET /api/site/update` 契约 §4 字段（url / fallback_url / sha256 / size / tag / published_at）、镜像未就绪时
空 url + GitHub 兜底、清单缺失 / 清单 SHA 与 `SHA256SUMS.txt` 不一致 / 清单内部哈希不一致、schema / tag 漂移，
以及 GitHub 失败时的降级（旧缓存无清单、静态 fallback）、无 Release 数据 503。

## 契约与约束
- 契约：`docs/design/AUTO_UPDATE.md` §4 / §8 与 `server/site_api.mjs` 文件头；GitHub / 下载请求全部用
  `fetchImpl` 注入，不访问真实网络。
- 清单由真实 `tools/build_update_manifest.mjs` 生成（临时文件 + 真实 SHA-256），测试同时验证发布链路两侧一致。
- 每个用例临时 `downloadDir` + 端口 0；镜像下载是后台任务，用轮询等待「就绪 / 保持不可用」，并断言落盘字节。

模块索引：[website](../README.md)
