# `sdk/pack_mod.gd`

> 作用：把松散模组目录打包成 `<mod_id>-<version>.snavmod.zip`；`--release` 在打包前强制跑一遍真实 runtime 校验。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SKIP_SUFFIXES` | L25 |

## 用法
```text
# 普通打包（行为与旧版一致，不做发布门禁）
godot --headless --path . --script res://sdk/pack_mod.gd -- \
    --source=dev_mods/core --out=dist/mods

# 正式发布：先按 runtime 语义校验，存在未激活草案或任何 error 时拒绝打包
godot --headless --path . --script res://sdk/pack_mod.gd -- \
    --source=dev_mods/core --out=dist/mods --release
```

## 契约与约束
- 不加 `--release` 时保持旧行为：只校验 manifest 可读且含 id/version，然后按原结构打包。
- `--release` 复用 `SdkValidationCore.run_runtime`：Core 从 `dev_mods` 加载；第三方模组先复制到
  `user://` 隔离目录，再按真实 Bootstrap 校验，避免同目录下其它示例模组影响结果。
- 未激活草案内容（`inactive_content_type`）或任何 error / fatal 都会让退出码为 1，且不写出 zip。
- `.snavmod.zip` 内部结构固定为 `mods/<mod_id>/...`；跳过 `.import` / `.uid` / `.tmp` 与隐藏目录。
- 发布签名 / 哈希不在本脚本内处理。

模块索引：[sdk](./README.md)
