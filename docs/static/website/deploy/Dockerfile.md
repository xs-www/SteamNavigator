# `website/deploy/Dockerfile`

> 作用：官网生产镜像：nginx alpine 运行静态页面，单 worker、非 root、8080 端口，面向低内存自托管与 Cloudflare Tunnel。

- 类型：项目配置/数据文件

## 契约与约束
- 构建上下文是 `website/`，只复制运行时需要的页面、`assets/` 与 nginx 配置；工具、README 与 MANIFEST 不进入镜像。
- nginx 以非 root `nginx` 用户运行，配置固定监听 8080；必须与 `deploy/nginx.conf` 的 pid / temp 路径一致。
- 容器只读运行：运行期只写 `/tmp`；日志走 stdout/stderr。
- 镜像不包含游戏本体、构建工具或 Node 运行时，体积与内存占用保持在静态站级别。

## 重点逻辑
### 低内存
- `worker_processes 1` + 精简 nginx.conf；单个静态站不需要多 worker。
- 使用 `nginx:1.27-alpine` 作为运行时基座，避免额外 OS 层。
### 健康检查
- `/healthz` 由 nginx 直接返回 200，供 Docker / Compose / CI 等待就绪。

模块索引：[website](../README.md)
