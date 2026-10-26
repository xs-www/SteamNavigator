# `website/tools/serve.mjs`

> 作用：零依赖本地静态预览服务器，用于开发与验收官网（不对公网部署）；同时挂载游玩数据接收端方便游戏端联调。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ROOT` | L29 |
| `HOST` | L30 |
| `PORT` | L31 |
| `TELEMETRY_PREFIX` | L32 |
| `TELEMETRY_DATA_DIR` | L33 |
| `MIME` | L40 |

## 契约与约束
- 只读服务 website/ 目录；禁止路径穿越与目录列表。
- 根路径与目录路径自动回退到 index.html；未知文件返回 404。
- 仅用于本地预览（默认 127.0.0.1:4173），生产环境交给 `deploy/` 的 nginx + telemetry 容器。
- 输出中文页面使用 UTF-8 Content-Type；不注入构建步骤。
- `/api/telemetry/*` 交给 `server/telemetry.mjs` 的同一 handler（契约见 `docs/design/TELEMETRY.md` §4），
  本地数据写 `website/.data/telemetry/`（已 gitignore），不进入静态文件服务。

## 重点逻辑
### 路径解析
- 先 decodeURIComponent，再 path.resolve 到站点根，并用 path.relative 判断是否越界。
### 缓存
- 预览服务器固定 `Cache-Control: no-cache`，避免改完 CSS/JS 后浏览器仍读旧文件。
### 接收端
- 在方法检查之前按路径前缀分派，POST 只对 `/api/telemetry/*` 放行；其它路径仍只允许 GET / HEAD。
- `SN_TELEMETRY_TOKEN` 非空时，本地接收端同样要求 `X-SN-Telemetry-Token`。

模块索引：[website](../README.md)
