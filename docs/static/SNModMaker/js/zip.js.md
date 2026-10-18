# `SNModMaker/js/zip.js`

> 作用：零依赖 ZIP 读写：中央目录解析、CRC32、store / deflate-raw 压缩，以及 ZIP 体积与路径限制。

- 类型：浏览器经典脚本

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `LOCAL_SIG` | L11 |
| `CENTRAL_SIG` | L12 |
| `EOCD_SIG` | L13 |
| `UTF8_FLAG` | L14 |
| `MAX_ENTRIES` | L15 |
| `MAX_TOTAL_UNCOMPRESSED` | L16 |
| `crcTable()` | L20 |
| `crc32(bytes)` | L33 |
| `normalizePath(path)` | L42 |
| `dosDateTime(date)` | L51 |
| `deflateRaw(bytes)` | L59 |
| `inflateRaw(bytes)` | L70 |
| `encodeText(text)` | L78 |
| `build(entries)` | L87 |
| `findEocd(view)` | L175 |
| `read(input)` | L188 |
| `SNZip (global)` | L245 |

## 契约与约束

- 写包使用 UTF-8 文件名标志；不支持 Zip64，读取时拒绝 0xFFFFFFFF 尺寸。
- 解压限制：最多 2000 条目、总解压体积 64 MB；每条校验 CRC。
- 压缩优先 `CompressionStream('deflate-raw')`，不可用或收益为负时退化为 store。
- `build()` 只接收逻辑路径；`mods/<id>/` 前缀由 `store.toExportFiles()` 添加。

## 重点逻辑

### `build(entries)`

- 先写本地文件头与数据，再写中央目录与 EOCD；偏移量按实际字节累计。
- 压缩失败不抛错，直接使用原始字节和 method=0。

### `read(input)`

- 从尾部扫描 EOCD，按中央目录读取路径与偏移，再定位本地头数据起点。
- method=8 使用 `DecompressionStream('deflate-raw')`；method=0 直接切片。

模块索引：[SNModMaker](../README.md)
