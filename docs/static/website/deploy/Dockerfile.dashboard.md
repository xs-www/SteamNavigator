# `website/deploy/Dockerfile.dashboard`

> 作用：本地「游玩数据看板」镜像：node:22-alpine 跑 `tools/telemetry_dashboard.mjs`，只读挂载遥测数据卷，在容器 8091 提供看板页面。

- 类型：项目配置/数据文件

## 契约与约束
- 契约：`docs/design/TELEMETRY.md` §4/§5、`docs/design/WEBSITE.md` §10；看板只读数据目录，不写业务数据。
- 构建上下文是 `website/`，只复制 `tools/telemetry_dashboard.mjs`；测试、页面与 README 不进入镜像。
- 默认绑定容器内 `0.0.0.0` 仅为让 compose 端口映射可达；compose 只发布到宿主机 `127.0.0.1:8091`（本地运维，不做公网鉴权）。
- 以非 root `node` 用户运行；运行期只写 `/tmp`（tmpfs），数据目录 `/data` 以只读卷挂载。
- 数据目录结构由遥测接收端约定：`/data/sessions/<YYYY-MM-DD>/<session_id>.json` 与 `index.ndjson`。

## 重点逻辑
### 健康检查
- 内置健康检查请求 `/api/health`，供 Compose 判断容器就绪。
### 低占用
- 零第三方依赖，无 npm install；单文件 Node 服务 + 内联前端，空闲内存约 20 MB。

模块索引：[website](../README.md)
