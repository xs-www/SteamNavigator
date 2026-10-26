# `website/README.md`

> 作用：官网使用说明：本地预览、目录结构、内容边界、版本更新清单、百科数据生成与部署方式。

- 类型：项目配置/数据文件

契约与约束
- 站点零依赖、无构建步骤；预览用 `node website/tools/serve.mjs`。
- 首页禁止开发 / 调试信息；版本信息只允许出现在下载页与开发日志页。
- `assets/data/wiki-data.js` 为生成物，不得手改；图片说明见 `assets/img/MANIFEST.md`。
- 生产镜像为 nginx alpine 单 worker 静态站；Compose 默认限制 32 MB 内存，只把端口绑定到 127.0.0.1，公网入口交给 Cloudflare Tunnel。

模块索引：[website](./README.md)
