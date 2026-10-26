# `website/deploy/nginx.conf`

> 作用：官网镜像内的 nginx 配置：单 worker、8080 端口、gzip、静态缓存、健康检查与基础安全响应头。

- 类型：项目配置/数据文件

## 契约与约束
- 与 `deploy/Dockerfile` 配套：nginx 以非 root 运行，pid 和临时文件写入 `/tmp`，日志写 stdout/stderr。
- 不使用 `add_header` 覆盖 server 级安全头；缓存用 `expires` 指令，避免 location 丢失继承。
- HTML 不缓存，`assets/` 缓存 7 天；发布新版本后由浏览器重新校验入口页。
- 只服务静态文件，不做反向代理、不执行脚本、不开放目录列表。

## 重点逻辑
### 低内存
- `worker_processes 1`、`worker_connections 512`，足够支撑静态站。
### 健康检查
- `/healthz` 直接返回 `ok`，不写访问日志。

模块索引：[website](../README.md)
