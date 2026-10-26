# `website/assets/js/site.js`

> 作用：官网全站交互（导航抽屉、滚动状态、滚动揭示、图片灯箱、页脚年份、Hero 视差）。

- 类型：浏览器经典脚本

## 契约与约束
- 无依赖、无构建：直接以经典脚本加载，所有增强都必须可降级。
- 内容默认可见；仅当 <html class="js"> 存在时才隐藏 `[data-reveal]`，避免无 JS 时白屏。
- 尊重 `prefers-reduced-motion`：不接管动画，也不做滚动视差。
- 不修改页面业务文案；年份只在 `[data-year]` 占位元素内更新。
- 灯箱在首次点击时惰性创建，关闭后恢复触发元素焦点。

## 重点逻辑
### 导航
- 移动端抽屉通过 body.nav-open + aria-expanded 同步；Esc、点击链接、窗口放大都会关闭。
### 灯箱
- 由 `[data-lightbox]` 触发，图片地址取 data-lightbox；caption 取 data-caption 或图片 alt。
- 使用原生 <dialog>，因此 Esc 与焦点管理由浏览器负责；点击遮罩也关闭。

模块索引：[website](../../README.md)
