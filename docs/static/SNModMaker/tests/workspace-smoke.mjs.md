# `SNModMaker/tests/workspace-smoke.mjs`

> 作用：原生工作区冒烟测试：用 `/api/workspace/<id>` 打开 dev_mods/<id>，验证删除定义、新增内容文件、删除本地化、资产不被改写与禁止整体删除。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `writeJson(file, value)` | L20 |
| `waitForServer()` | L82 |

## 契约与约束

- 在临时目录构造一个 workspace 根与 core 模组，并用 SNMODMAKER_WORKSPACE_ROOT 指向它，不触碰仓库 dev_mods。
- 保存使用与浏览器相同的 `{project, files}` 载荷；断言磁盘上定义集合、内容文件与本地化删除结果。
- 断言 `assets/models/*.glb` 字节不变，且 DELETE `/api/workspace/<id>` 返回 400。

模块索引：[SNModMaker](../README.md)
