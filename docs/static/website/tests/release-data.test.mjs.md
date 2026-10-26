# `website/tests/release-data.test.mjs`

> 作用：官网 Release 版本数据生成器（`tools/build-release-data.mjs`）的 Node 测试：覆盖 latest/stable 选择、

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `makeTempFile()` | L31 |
| `asset(name, size, id)` | L37 |
| `release(overrides = {})` | L46 |
| `response(payload, ok = true, status = 200)` | L64 |

资产直链与大小推导、生成文件往返、`--check` 陈旧检测，以及 GitHub API 失败时“保留旧文件 / strict 失败”的降级契约。

## 契约与约束
- 契约：`docs/design/WEBSITE.md` §2/§7 与 `website/tools/build-release-data.mjs` 文件头；不访问真实网络。
- 网络用注入的 `fetchImpl` 模拟；每个用例用 `os.tmpdir()` 下的独立输出文件，结束后删除。
- 断言生成数据的具体字段（tag/date/links/size）与失败分支，不只断言“文件存在”。

模块索引：[website](../README.md)
