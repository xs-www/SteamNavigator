# `sdk/validate.gd`

> 作用：SDK 无头校验入口：默认 `runtime` 模式跑真实 Bootstrap，`draft` 模式对草案 / 混合模组做静态 Schema 校验。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `DEFAULT_MODE` | L21 |
| `MODE_PREFIX` | L22 |

## 用法
```text
godot --headless --path . --script res://sdk/validate.gd -- \
    --mod-root=sdk/examples/example_roles_1_0 [--mode=runtime|draft] [--json]
```

## 契约与约束
- 不传 `--mode` 时等价 `--mode=runtime`，保留既有调用（包括 SNModMaker `validate --godot`）兼容。
- runtime：Core 从 `dev_mods` 加载，额外根追加在扫描列表里；未激活草案内容被显式拒绝，
  错误码 `inactive_content_type`，每条含 `code` / `message` / `severity` / `mod` / `file` / `path`。
- draft：不启动运行时，按 `ContentTypes` + `content_types.json` 的 `draft_schemas` / `draft_types`
  做静态 Schema 校验；草案模组只应出现在 draft，不得据此发布。
- `--json` 输出 `StartupReport` 既有字段，附加 `mode` 与 `ok`；`errors[]` 统一为结构化条目。
- 退出码：0 无 error / fatal；1 存在 error 或 fatal；2 用法错误（未知 `--mode`）。

模块索引：[sdk](./README.md)
