# `docker-compose.yml`

> 作用：SNModMaker 的 Docker Compose 部署：构建零依赖镜像，数据持久化到命名卷 `snmodmaker-data`，只发布到宿主机 loopback。

- 类型：项目配置/数据文件

## 契约与约束

- `ports` 固定 `127.0.0.1:${SNMODMAKER_PORT:-8099}:8099`；远程访问由宿主机 `tailscale serve --bg 8099` 提供 HTTPS，不要用 tailscale funnel。
- `snmodmaker-data` → `/app/data`：容器内保存项目、导出、部署包与空的工作区根，不挂载宿主机仓库，因此不会改 `dev_mods/core`。
- healthcheck 用 Node 内置 fetch 探测 `/api/status`；静态文件变更后需重新 build 镜像。
