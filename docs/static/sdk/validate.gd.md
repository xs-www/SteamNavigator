# `sdk/validate.gd`

> 作用：无头校验 Core + 可选第三方模组，输出文本或 JSON 报告。

- 类型：GDScript 源文件

## 契约与约束

- 若 `--mod-root` 指向单个模组目录（含 manifest.json），自动改用其父目录作为扫描根。
- 任何 fatal 或普通错误均以退出码 1 结束；纯警告退出码 0。
- 使用 `dev_mods` 中的 Core，便于第三方内容依赖官方内容。

模块索引：[sdk](./README.md)
