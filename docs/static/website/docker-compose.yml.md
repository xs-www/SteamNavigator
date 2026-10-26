# `website/docker-compose.yml`

> 作用：官网 Docker Compose：低内存静态站容器 + 游玩数据接收端容器 + 可选 Cloudflare Tunnel 容器。

- 类型：项目配置/数据文件

## 契约与约束
- 契约：`docs/design/TELEMETRY.md` §4；`website` 通过 nginx 把 `/api/telemetry/` 反代到 `http://telemetry:8090`。
- 默认只把宿主机 8088 绑定到 127.0.0.1（容器内 8080），公网入口由 Cloudflare Tunnel 提供；
  `telemetry` 不映射宿主机端口，只能从 `website` 容器访问。
- 两个容器都只读、丢弃 capabilities、限制 CPU / 内存 / pids；运行期分别只写 `/tmp` 与 `/data`。
- `telemetry` 数据卷 `telemetry-data` 挂到 `/data`（会话 JSON 与 index.ndjson），备份与保留期见 `website/README.md`。
- `website` 在 `telemetry` healthcheck 通过后才启动，避免反代目标长期 502。
- `cloudflared` 使用 profile `tunnel`，未启用时不启动；origin 地址使用 Compose 服务名 `http://website:8080`。

## 重点逻辑
### 资源
- `website`：32 MB / 0.25 CPU；`telemetry`：64 MB / 0.5 CPU（Node 运行时 + 每小时清理扫描）。
### Cloudflare
- 用 Zero Trust Tunnel 的 token 运行 cloudflared；域名与 Public Hostname 在 Cloudflare 控制台配置。
- 若 cloudflared 跑在宿主机而不是容器里，把 origin 指向 `http://127.0.0.1:8088` 即可。
### 令牌
- `.env` 的 `SN_TELEMETRY_TOKEN` 非空时，接收端要求 `X-SN-Telemetry-Token`；必须与游戏发布配置一致。

模块索引：[website](./README.md)
