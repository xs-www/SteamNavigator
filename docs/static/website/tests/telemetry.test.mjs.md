# `website/tests/telemetry.test.mjs`

> 作用：游玩数据接收端 Node 测试（node:test，零第三方依赖）：覆盖 health、合法/非法上传、存储与索引、限流、令牌、方法/路径错误与 180 天保留清理。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MILLIS_PER_DAY` | L33 |
| `makeTempDir()` | L35 |
| `withServer(options, fn)` | L41 |
| `validPayload(overrides = {})` | L57 |
| `postSession(instance, payload, headers = {})` | L78 |
| `dayKey(offsetDays)` | L87 |
| `readSessionDirs(dataDir)` | L91 |
| `readIndex(dataDir)` | L106 |
| `sessionFiles(dataDir)` | L121 |

## 契约与约束
- 契约：`docs/design/TELEMETRY.md` §3（上传协议）与 §4（官网接收端）、§6 验收第 5 条。
- 只跑 `website/server/telemetry.mjs` 的导出，不依赖 nginx / Docker / 游戏端；每个用例用临时目录 + 端口 0。
- 用例之间不共享数据目录；`test.after` 统一删除临时目录。
- 断言状态码、响应体、落盘文件与 `index.ndjson` 摘要，避免只测“返回 2xx”。

## 重点逻辑
### 启动
- `withServer()` 起随机端口，`finally` 里关闭；`logger: null` 保持测试输出干净（日志用例单独注入 logger）。
### 数据
- `validPayload()` 是契约 §3 的完整载荷；`readSessionDirs` / `readIndex` / `sessionFiles` 读回落盘结果。
### 时间
- 保留清理用 UTC 日期目录（今天 ± 若干天），不依赖本地时区。

模块索引：[website](../README.md)
