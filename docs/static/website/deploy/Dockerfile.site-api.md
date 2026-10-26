# `website/deploy/Dockerfile.site-api`

> 作用：官网只读内容 API 镜像：node:22-alpine 跑 `server/site_api.mjs`，在容器 8092 提供 `/api/site/release`，

- 类型：项目配置/数据文件

服务端缓存 GitHub Releases 数据，让网站在发版后无需重新部署也能显示最新版本。

## 契约与约束
- 契约：`docs/design/WEBSITE.md` §7/§8 与 `server/site_api.mjs` 文件头；只读、不下发 token。
- 构建上下文是 `website/`，只复制 `server/site_api.mjs`、`tools/build-release-data.mjs` 与烘焙的
  `assets/data/release-data.js`（作为 GitHub 不可用时的 fallback）。
- 默认非 root 用户运行，容器内 8092；不映射宿主机端口，只由 nginx `/api/site/` 反代。
- `GITHUB_TOKEN` 可选，仅用于提高 GitHub API 限流额度；不写入镜像 / 响应。

## 重点逻辑
### 缓存
- 进程内缓存默认 5 分钟（`SN_SITE_API_CACHE_SECONDS`），并发请求共享同一次刷新；
  GitHub 失败时先返回旧缓存（`source:"stale"`），再回退镜像内 release-data.js（`source:"fallback"`）。
### 健康检查
- 内置健康检查请求 `/api/site/health`，不依赖 GitHub 可用性。

模块索引：[website](../README.md)
