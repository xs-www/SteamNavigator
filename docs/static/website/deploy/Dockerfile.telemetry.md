# `website/deploy/Dockerfile.telemetry`

> 作用：游玩数据接收端生产镜像：node:22-alpine 跑零依赖 `server/telemetry.mjs`，非 root、8090 端口、`/data` 数据卷。

- 类型：项目配置/数据文件

## 契约与约束
- 契约：`docs/design/TELEMETRY.md` §4；镜像只含接收端代码，不含官网静态页面与 nginx。
- 构建上下文是 `website/`，只复制 `server/telemetry.mjs`；测试、README、.env 不进入镜像。
- 进程以非 root `node` 用户运行，监听 8090；数据目录固定 `/data`，由 Compose 卷持久化。
- 容器只读运行：运行期只写 `/data`（以及 tmpfs `/tmp`）；日志走 stdout/stderr。
- 环境变量：`SN_TELEMETRY_PORT`（8090）、`SN_TELEMETRY_DATA_DIR`（/data）、`SN_TELEMETRY_TOKEN`（可选，空 = 不校验）。

## 重点逻辑
### 健康检查
- 内置健康检查直接请求 `/api/telemetry/health`，不经过 nginx，供 Docker / Compose / CI 等待就绪。
### 低占用
- 零第三方依赖，无 npm install；镜像只有 Node 运行时与一个 .mjs 文件。

模块索引：[website](../README.md)
