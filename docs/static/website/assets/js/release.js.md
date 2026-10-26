# `website/assets/js/release.js`

> 作用：官网版本信息填充脚本：先用构建期生成的 `assets/data/release-data.js` 立即填充下载页 / 开发日志页，

- 类型：浏览器经典脚本

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `formatSize(bytes)` | L26 |
| `assetSize(latest, pattern)` | L34 |
| `textFor(latest, key)` | L42 |
| `applyData(data)` | L63 |
| `refreshFromApi()` | L91 |

再异步请求同域 `/api/site/release`（服务端缓存 GitHub Releases）刷新到最新版本；API 不可用时静默保留静态值。

## 契约与约束
- 静态数据优先渲染：断网 / API 未部署 / 纯静态托管时页面仍有可用版本信息。
- Windows 下载优先使用后端镜像：API 的 `data.downloads.windows.available` 为真时用 `/downloads/<tag>/...`，
  否则回退 `data.links.windows`（GitHub）；镜像目录只保留最新版本，历史版本始终走 GitHub。
- 只做 `textContent` / `href` 赋值，不插入 HTML（tag / 名称按纯文本处理，避免注入）。
- 找不到数据、字段为 null 或元素不存在时保持页面原有静态 fallback 文案，不隐藏内容、不报错。
- 约定属性：`data-release="tag|date|state|windows-size|linux-size|banner-note"` 填文本；
  `data-release-link="releases|windows|linux|checksums"` 填链接。契约见 `docs/design/WEBSITE.md` §2/§7。

## 重点逻辑
### 静态 → API 两段式
- 首屏用 `window.SN_RELEASE_DATA`；随后 `fetch("/api/site/release", {cache:"no-cache"})`，
  成功则用响应里的 `data`（与静态文件同构）重新填充，实现「发布 Release 后网站自动更新」。
### 填充
- 版本：`latest.tag`；日期：`latest.date`；状态：预发布 / 正式版；大小：字节 → `约 N MB`。
- 链接：只使用 release 的真实 asset 直链；缺失的平台保持原静态 href。

模块索引：[website](../../README.md)
