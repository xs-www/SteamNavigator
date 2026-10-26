# `website/tools/serve.mjs`

> 作用：零依赖本地静态预览服务器，用于开发与验收官网（不对公网部署）。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ROOT` | L22 |
| `HOST` | L23 |
| `PORT` | L24 |
| `MIME` | L26 |

## 契约与约束
- 只读服务 website/ 目录；禁止路径穿越与目录列表。
- 根路径与目录路径自动回退到 index.html；未知文件返回 404。
- 仅用于本地预览（默认 127.0.0.1:4173），生产环境交给任意静态托管。
- 输出中文页面使用 UTF-8 Content-Type；不注入构建步骤。

## 重点逻辑
### 路径解析
- 先 decodeURIComponent，再 path.resolve 到站点根，并用 path.relative 判断是否越界。
### 缓存
- 预览服务器固定 `Cache-Control: no-cache`，避免改完 CSS/JS 后浏览器仍读旧文件。

模块索引：[website](../README.md)
