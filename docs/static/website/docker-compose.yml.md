# `website/docker-compose.yml`

> 作用：官网 Docker Compose：低内存静态站容器 + 可选 Cloudflare Tunnel 容器。

- 类型：项目配置/数据文件

## 契约与约束
- 默认只把宿主机 8088 绑定到 127.0.0.1（容器内 8080），公网入口由 Cloudflare Tunnel 提供。
- 容器只读、丢弃 capabilities、限制 CPU / 内存 / pids；运行期只写 `/tmp`。
- `website` 服务 32 MB 内存上限、0.25 CPU；静态 nginx 实际占用通常远低于此。
- `cloudflared` 使用 profile `tunnel`，未启用时不启动；origin 地址使用 Compose 服务名 `http://website:8080`。

## 重点逻辑
### Cloudflare
- 用 Zero Trust Tunnel 的 token 运行 cloudflared；域名与 Public Hostname 在 Cloudflare 控制台配置。
- 若 cloudflared 跑在宿主机而不是容器里，把 origin 指向 `http://127.0.0.1:8088` 即可。

模块索引：[website](./README.md)
