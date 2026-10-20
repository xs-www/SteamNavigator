# `SNBattleSim/tools/mod_io.mjs`

> 作用：为本地服务和 CLI 安全读取散装或 ZIP 形式的 SNBattleSim 模组，并导出游戏可识别的模组包。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ZIP_LOCAL` | L15 |
| `MAX_ARCHIVE_BYTES` | L16 |
| `crc32(buffer)` | L19 |
| `zipPath(value)` | L32 |
| `findEocd(buffer)` | L38 |
| `readZipEntries(file)` | L44 |
| `packageFromZip(file, displayName)` | L84 |
| `readModPackages(modsRoot)` | L102 |
| `writeModBundle(modsRoot, bundle)` | L123 |
| `writeModArchive(modsRoot, bundle)` | L137 |

## 契约与约束
- 散装模组只处理 mods 的直接子目录；ZIP 必须只含一个 mods/<id>/manifest.json。
- ZIP 限 128 MB 包体、2000 个条目和 64 MB 解压总量，拒绝 Zip64、加密、路径穿越与非 store/deflate 压缩。
- 目录与 ZIP 导出均默认拒绝覆盖，由调用方生成唯一模组 ID。

模块索引：[SNBattleSim](../README.md)
