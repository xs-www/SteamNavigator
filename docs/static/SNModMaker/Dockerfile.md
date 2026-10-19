# `SNModMaker/Dockerfile`

> 作用：零依赖容器镜像：Node 22 Alpine 打包静态编辑器与 tools/，以 node 用户运行，所有可写目录重定向到 /app/data 命名卷。

- 类型：项目配置/数据文件

## 契约与约束

- 构建上下文是 `SNModMaker/`（`.dockerignore` 排除本地 `mods/`、`exports/`），支持 `docker build -t snmodmaker:local SNModMaker`。
- 设置 `SNMODMAKER_HOST=0.0.0.0` 仅用于容器端口映射；宿主机 compose 仍只发布到 `127.0.0.1`，远程访问交给 tailscale serve。
- `SNMODMAKER_MODS_DIR` / `EXPORTS_DIR` / `GAME_MODS_DIR` / `WORKSPACE_ROOT` 全部指向 `/app/data/*`，镜像层保持只读；工作区根在容器内，不写回宿主机 `dev_mods/core`。
- 镜像内预创建 `/app/data/*` 并 `chown node:node`，配合命名卷首挂载继承属主。

模块索引：[SNModMaker](./README.md)
