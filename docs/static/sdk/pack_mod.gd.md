# `sdk/pack_mod.gd`

> 作用：把松散模组目录打包为 `mods/<id>/...` 的 `.snavmod.zip`。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SKIP_SUFFIXES` | L8 |

## 契约与约束

- 跳过 Godot `.import`/`.uid`/`.tmp` 与隐藏目录。
- 输出文件名固定 `<mod_id>-<version>.snavmod.zip`。
- 仅打包，不修改 manifest checksum；发布签名/哈希是后续工作。

模块索引：[sdk](./README.md)
