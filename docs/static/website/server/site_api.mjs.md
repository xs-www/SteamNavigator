# `website/server/site_api.mjs`

> 作用：官网只读内容 API：`GET /api/site/release` 在服务端拉取 GitHub Releases（内存缓存，默认 5 分钟），

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SERVER_DIR` | L48 |
| `DEFAULT_PORT` | L49 |
| `DEFAULT_HOST` | L50 |
| `DEFAULT_CACHE_TTL_MS` | L51 |
| `DEFAULT_FALLBACK_FILE` | L52 |
| `DEFAULT_MAX_DOWNLOAD_BYTES` | L53 |
| `RELEASE_PATH` | L54 |
| `UPDATE_PATH` | L55 |
| `HEALTH_PATH` | L56 |
| `UPDATE_MANIFEST_NAME` | L57 |
| `RESPONSE_CACHE_CONTROL` | L58 |
| `sendJson(res, statusCode, payload, extraHeaders = {})` | L60 |
| `readFallback(file)` | L72 |
| `fileSha256(filePath)` | L81 |
| `streamToFile(webStream, filePath, maxBytes)` | L88 |
| `createSiteApiHandler(options = {})` | L131 |
| `mirrorUrl(data)` | L164 |
| `withDownloads(data)` | L170 |
| `cleanupOtherTags(keepTag)` | L185 |
| `findAsset(assets, pattern)` | L200 |
| `parseChecksumLines(text)` | L214 |
| `fetchChecksums(fetchImpl, latest)` | L225 |
| `checksumFor(entries, fileName)` | L233 |
| `expectedSha256(fetchImpl, latest, fileName)` | L239 |
| `mirrorAsset(fetchImpl, latest, asset, expectedSha, expectedBytes, label)` | L247 |
| `downloadLatestWindows(data)` | L281 |
| `requireManifestSha256(value, label)` | L302 |
| `requireManifestSize(value, label)` | L308 |
| `requirePortablePath(value, label)` | L314 |
| `requireUtcTimestamp(value)` | L322 |
| `validateUpdateManifest(manifest, context)` | L339 |
| `loadUpdateData(data)` | L394 |
| `mirrorUpdateFiles(latest, core, manifestBytes, manifestExpected, state)` | L434 |
| `buildUpdateData(latest)` | L470 |
| `primeUpdate(data, options = {})` | L506 |
| `refresh()` | L530 |
| `getRelease()` | L540 |
| `startSiteApi(options = {})` | L636 |

供前端在不重新部署网站的情况下自动显示「最新版本」；`GET /api/site/update` 返回游戏内自动更新所需的
发布清单与文件地址（契约 `docs/design/AUTO_UPDATE.md` §4）；`GET /api/site/health` 供容器健康检查。

## 契约与约束
- 只读、无需登录；不接触遥测数据，也不下发任何 token（`GITHUB_TOKEN` 只用于服务端 API 调用）。
- 缓存：默认 300 秒；同一进程内只有一个进行中的刷新请求（避免并发打爆 GitHub 限流）。
- 失败降级顺序：新鲜缓存 → 过期但可用的旧缓存（source:"stale"）→ 镜像内 `release-data.js`
  （source:"fallback"）→ `503`。响应 `Cache-Control: public, max-age=60, stale-while-revalidate=600`。
- 响应 `data` 与 `assets/data/release-data.js` 的 `window.SN_RELEASE_DATA` 同构，前端 `release.js` 共用一套渲染。
- 可选下载镜像：把最新 Release 的 Windows zip、`core-*.snavmod.zip` 与 `update-manifest.json` 下载到
  `SN_SITE_API_DOWNLOAD_DIR`（不配置则关闭），校验字节数与 `SHA256SUMS.txt` 后暴露为
  `/downloads/<tag>/<file>`；只保留最新 tag，旧版本目录自动删除，历史版本仍由前端回退 GitHub 直链。
- `update-manifest.json` 只信任能通过 `SHA256SUMS.txt` 交叉校验的版本：清单自身、package、core 的
  SHA-256 必须与 sums 对应条目一致；`schema` 必须为 1、`tag` 必须等于最新 Release。engine 在平台 ZIP
  内、没有独立 sums 条目，接口只校验其路径 / 哈希字段形状，客户端解压后再按清单哈希校验。
- 校验清单兼容裸文件名与发布流程的 `dist/release/<文件名>`；校验和缺失、请求失败或不匹配时不提供镜像，
  也不提供 `/api/site/update` 数据（`503 { ok:false, error }`，客户端回退手动更新）。
  进程重启后也必须重新计算已有文件的 SHA-256；损坏副本移除后重新下载，不能只凭相同大小复用。
- 依赖 `tools/build-release-data.mjs` 的纯函数（fetchReleases / buildReleaseData / parseReleaseDataFile），
  零第三方依赖，Node >= 18。

## 重点逻辑
### `createSiteApiHandler(options)`
- 路由 `/api/site/release`、`/api/site/update` 与 `/api/site/health`；其它 404，非 GET/HEAD 405。
### `getRelease()`
- 缓存未过期直接返回；过期时复用同一个刷新 Promise；GitHub 失败时优先旧缓存，再读 fallback 文件。
### 下载镜像
- 刷新成功后后台下载最新 Windows zip（旧行为）、`update-manifest.json` 与 core 包；每个文件独立校验、
  独立就绪，镜像未就绪时 `/api/site/update` 的 `files.*.url` 为空字符串，由 `fallback_url`（GitHub）兜底。
### `/api/site/update`
- 清单来自 GitHub Release 资产并与 `SHA256SUMS.txt` 交叉校验后缓存（每个 tag 只加载一次，失败下次刷新重试）；
  刷新失败沿用旧 tag 的缓存（stale），无可用清单 / 无 Release 数据时 503。
### `startSiteApi(options)`
- 默认监听 `0.0.0.0:8092`（Compose 内由 nginx 反代），返回 `{server,url,close}`。

模块索引：[website](../README.md)
