# `framework/tests/test_runner.gd`

> 作用：无头测试入口：按 `SUITE_PATHS` 声明顺序加载测试套件、逐个执行 `test_*` 方法并打印 PASS/FAIL，退出码由失败数决定（0 = 全绿）。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SUITE_PATHS` | L31 |

支持单套件过滤、显式套件列表与分片，供 `tools/test.ps1` 多进程并行调度；套件在首帧
而非 `_initialize` 执行，SceneTree 已就绪，UI 套件可真实挂载 shell 场景。

## 用法
```text
godot --headless --path . --script res://framework/tests/test_runner.gd
godot --headless --path . --script res://framework/tests/test_runner.gd -- --suite=ui_shell
godot --headless --path . --script res://framework/tests/test_runner.gd -- --suites=a,b --timings=C:/abs/timings.json
```

## CLI 参数（`-- --key=value`）
- `--suite=<片段>`：只跑文件名包含该片段的套件（沿用旧行为，开发时缩小范围）。
- `--suites=a,b,c`：只跑显式列出的套件（文件名去掉 `.gd`）；`tools/test.ps1` 用它
  给每个分片派发均衡后的套件列表。列出的套件不存在时直接报错退出，避免静默漏跑。
- `--shard=i/n`：手工分片，按声明顺序轮转把套件分给第 i 片（0-based）。
- `--timings=<路径>`：把本次每个套件的耗时写入 JSON（绝对路径或 `res://`），
  `tools/test.ps1` 用上一轮的耗时做下一轮的负载均衡（首次运行无缓存时退化为轮转）。
- `--list`：只打印套件名列表后退出，供 `tools/test.ps1` 获取分片清单，不执行测试。

## 契约
- 每片结束仍打印 `Tests: %d passed, %d failed, %d total in %dms`，与旧版输出兼容。
- 额外打印 `[SUITE] 名称: 通过/总数 in 耗时`，方便定位慢套件。
- 分片是进程级隔离：每个分片独立 `Bootstrap`，套件 fixture 用各自唯一 `user://` 目录，
  分片之间不共享内存状态；因此同一套件只能出现在一个分片里。

模块索引：[framework/tests](./README.md)
