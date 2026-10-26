# `website/devlog.html`

> 作用：开发日志页：版本时间线、已交付系统与下一阶段方向；允许出现版本号与开发状态。

- 类型：HTML 应用外壳

契约与约束
- 按时间倒序维护条目；页头「最新版本 / 最近更新」由 `assets/data/release-data.js`（GitHub Releases 生成）
+ `assets/js/release.js` 自动填充，`data-release="tag|date"` 是契约，静态文案是 fallback。
- 时间线条目仍由人工维护（发布说明的叙事内容不自动抓取）。
- 只写对玩家有意义的变更，不粘贴内部测试或构建流水账。

模块索引：[website](./README.md)
