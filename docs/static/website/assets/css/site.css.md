# `website/assets/css/site.css`

> 作用：官网唯一设计系统与全站样式：色彩/排版 token、导航、Hero、卡片、百科、下载、页脚、响应式与动效降级。

- 类型：样式表

契约与约束
- 只使用系统字体栈，不引入外部字体 / CDN；页面在断网环境仍完整可读。
- 全站共享同一套 token 与组件类；页面不得内联业务颜色或覆盖核心布局。
- 响应式断点固定为 1100 / 860 / 600 px；移动端不得出现横向滚动。
- 所有动画必须被 `prefers-reduced-motion` 关闭；`[data-reveal]` 仅在 `<html class="js">` 下隐藏。

模块索引：[website](../../README.md)
