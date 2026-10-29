# `tools/tests/update_manifest.test.mjs`

> 作用：自动更新清单生成器 `tools/build_update_manifest.mjs` 的 node:test 用例：覆盖契约 §3 字段 / 哈希 / 大小、

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SCRIPT` | L31 |
| `TAG` | L33 |
| `PUBLISHED_AT` | L34 |
| `makeTempDir()` | L36 |
| `writeFixture(dir, name, bytes)` | L42 |
| `sha256(bytes)` | L48 |
| `createFixture(overrides = {})` | L52 |
| `build(fixture)` | L69 |

便携布局路径（engine 裸名、core `mods/` 前缀、package 文件名）、非法 `published_at` / tag、缺失 / 非文件路径，
以及 CLI 成功落盘与失败退出码（stderr）。

## 契约与约束
- 契约：`docs/design/AUTO_UPDATE.md` §3 / §8；清单 schema 固定 1，不包含自身哈希。
- 全部用 `node:fs` 临时目录构造真实文件，不访问网络、不依赖仓库构建产物。
- CLI 用 `spawnSync(process.execPath, ...)` 真实子进程验证退出码与 stderr，避免只测函数不测入口。

模块索引：[tools](../README.md)
