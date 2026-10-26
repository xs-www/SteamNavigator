# `website/deploy/nginx.conf`

> 作用：官网镜像内的 nginx 配置：单 worker、8080 端口、gzip、静态缓存、健康检查、基础安全响应头，以及 /api/telemetry/ 反代。

- 类型：项目配置/数据文件

## 契约与约束
- 与 `deploy/Dockerfile` 配套：nginx 以非 root 运行，pid 和临时文件写入 `/tmp`，日志写 stdout/stderr。
- 不使用 `add_header` 覆盖 server 级安全头；缓存用 `expires` 指令，避免 location 丢失继承。
- HTML 不缓存，`assets/` 缓存 7 天；发布新版本后由浏览器重新校验入口页。
- `/api/telemetry/` 反代到 Compose 服务 `telemetry:8090`（对应 `deploy/Dockerfile.telemetry`）；其余请求只服务静态文件。
- 接收端 location 关闭 access_log：nginx 默认访问日志会写客户端 IP，与 `docs/design/TELEMETRY.md` 的隐私红线冲突。

## 重点逻辑
### 低内存
- `worker_processes 1`、`worker_connections 512`，足够支撑静态站。
### 健康检查
- `/healthz` 直接返回 `ok`，不写访问日志。
### 游玩数据反代
- 用 `resolver` + 变量形式的 `proxy_pass` 在请求时解析服务名：`telemetry` 未启动或重建时 nginx 仍能启动，
  只让该 location 返回 502，不影响静态站；`proxy_pass` 不带 URI，原样转发 `/api/telemetry/<path>`。
- 只放行 GET / POST，请求体上限 1 MB，超时按客户端 8 秒上传预算收紧。

模块索引：[website](../README.md)
