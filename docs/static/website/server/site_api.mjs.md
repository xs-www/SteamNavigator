# `website/server/site_api.mjs`

> 作用：官网只读内容 API：`GET /api/site/release` 在服务端拉取 GitHub Releases（内存缓存，默认 5 分钟），

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SERVER_DIR` | L41 |
| `DEFAULT_PORT` | L42 |
| `DEFAULT_HOST` | L43 |
| `DEFAULT_CACHE_TTL_MS` | L44 |
| `DEFAULT_FALLBACK_FILE` | L45 |
| `DEFAULT_MAX_DOWNLOAD_BYTES` | L46 |
| `RELEASE_PATH` | L47 |
| `HEALTH_PATH` | L48 |
| `RESPONSE_CACHE_CONTROL` | L49 |
| `sendJson(res, statusCode, payload, extraHeaders = {})` | L51 |
| `readFallback(file)` | L63 |
| `fileSha256(filePath)` | L72 |
| `streamToFile(webStream, filePath, maxBytes)` | L79 |
| `createSiteApiHandler(options = {})` | L122 |
| `mirrorUrl(data)` | L149 |
| `withDownloads(data)` | L155 |
| `cleanupOtherTags(keepTag)` | L170 |
| `expectedSha256(fetchImpl, latest, fileName)` | L184 |
| `downloadLatestWindows(data)` | L197 |
| `refresh()` | L240 |
| `getRelease()` | L248 |
| `startSiteApi(options = {})` | L319 |

供前端在不重新部署网站的情况下自动显示「最新版本」；GitHub/网络失败时回退到镜像内烘焙的
`release-data.js`，两者都没有才返回 503。`GET /api/site/health` 供 Docker / Compose 健康检查。

## 契约与约束
- 只读、无需登录；不接触遥测数据，也不下发任何 token（`GITHUB_TOKEN` 只用于服务端 API 调用）。
- 缓存：默认 300 秒；同一进程内只有一个进行中的刷新请求（避免并发打爆 GitHub 限流）。
- 失败降级顺序：新鲜缓存 → 过期但可用的旧缓存（source:"stale"）→ 镜像内 `release-data.js`
  （source:"fallback"）→ `503`。响应 `Cache-Control: public, max-age=60, stale-while-revalidate=600`。
- 响应 `data` 与 `assets/data/release-data.js` 的 `window.SN_RELEASE_DATA` 同构，前端 `release.js` 共用一套渲染。
- 可选 Windows 镜像：把最新 Release 的 Windows zip 流式下载到 `SN_SITE_API_DOWNLOAD_DIR`（不配置则关闭），
  校验字节数与 `SHA256SUMS.txt` 后暴露为 `data.downloads.windows.url`（`/downloads/<tag>/<file>`）；只保留
  最新 tag，旧版本目录自动删除，历史版本仍由前端回退 GitHub 直链。
- 校验清单兼容裸文件名与发布流程的 `dist/release/<文件名>`；校验和缺失、请求失败或不匹配时不提供镜像。
  进程重启后也必须重新计算已有文件的 SHA-256；损坏副本移除后重新下载，不能只凭相同大小复用。
- 依赖 `tools/build-release-data.mjs` 的纯函数（fetchReleases / buildReleaseData / parseReleaseDataFile），
  零第三方依赖，Node >= 18。

## 重点逻辑
### `createSiteApiHandler(options)`
- 路由 `/api/site/release` 与 `/api/site/health`；其它 404，非 GET/HEAD 405。
### `getRelease()`
- 缓存未过期直接返回；过期时复用同一个刷新 Promise；GitHub 失败时优先旧缓存，再读 fallback 文件。
### Windows 镜像
- 刷新成功后后台下载最新 Windows zip（流式 + SHA-256 校验），完成后 `downloads.windows.available=true`；
  下载进行中/失败时 API 仍正常返回，前端用 `links.windows`（GitHub）兜底。
### `startSiteApi(options)`
- 默认监听 `0.0.0.0:8092`（Compose 内由 nginx 反代），返回 `{server,url,close}`。

模块索引：[website](../README.md)
