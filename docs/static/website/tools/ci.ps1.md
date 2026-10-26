# `website/tools/ci.ps1`

> 作用：官网本地 CI：构建生产镜像，以生产资源限制跑容器冒烟，通过后用 Docker Compose 部署到本机。

- 类型：项目配置/数据文件

## 契约与约束
- 只在本地构建/测试/部署，不推任何 registry；镜像默认标签 `steam-navigator-website:local`。
- 冒烟容器必须使用与生产一致的约束：read-only rootfs、32 MB 内存、0.25 CPU、丢弃 capabilities。
- 冒烟覆盖 `/healthz`、首页、游戏信息、百科、CSS、404、gzip 与缓存头；任一项失败则不部署。
- 部署使用 `website/docker-compose.yml`，只更新 `website` 服务；Cloudflare Tunnel 另行启动。
- 构建前先跑 `node website/tools/build-release-data.mjs`：从 GitHub Releases API 刷新版本数据
  （下载页 / 开发日志页的版本号、日期、大小、直链），网络失败时保留上一次生成的文件；
  `-SkipReleaseData` 可跳过（离线构建）。
- 不修改站点内容（除生成数据外），不触碰 `dev_mods/`；可从任意工作目录运行。

## 重点逻辑
### 先测后部署
- 先用临时容器在 `-SmokePort`（默认 18080）验证镜像，再执行
  `docker compose -f website/docker-compose.yml up -d --build website`。
### 清理
- 冒烟容器在 `finally` 中删除；部署后的健康检查失败会以非零退出码结束。

模块索引：[website](../README.md)
