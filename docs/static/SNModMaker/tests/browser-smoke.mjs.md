# `SNModMaker/tests/browser-smoke.mjs`

> 作用：Chrome DevTools Protocol 冒烟测试：新建项目、实体键事务、模块子分页与船体模块区 / 安装点面板、本地化、自定义资源选择器、ZIP、导入与撤销。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `sleep(ms)` | L21 |
| `waitFor(cdp, expression, timeoutMs, label)` | L83 |
| `check(name, fn)` | L93 |

## 契约与约束

- 需要 Chrome 以 `--remote-debugging-port=9222` 启动，并已有静态服务。
- 测试开始前清空该 origin 的存储；直接调用页面内 `SN*` 模块做导出/导入断言。
- 收集 `Runtime.exceptionThrown` 与 console error，任何一条都会导致非零退出。

模块索引：[SNModMaker](../README.md)
