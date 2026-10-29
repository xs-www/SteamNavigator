# `tools/build_update_manifest.mjs`

> 作用：生成游戏内自动更新的发布清单 `dist/release/update-manifest.json`（契约见

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `TAG_PATTERN` | L33 |
| `CLI_FLAGS` | L34 |
| `fail(message)` | L43 |
| `validatePublishedAt(value)` | L48 |
| `validateTag(value)` | L58 |
| `normalizePortablePath(value, label)` | L65 |
| `fileFingerprint(filePath, label, fsImpl)` | L73 |
| `buildUpdateManifest(options = {})` | L103 |
| `renderUpdateManifest(manifest)` | L138 |
| `parseArguments(argv = [])` | L143 |
| `writeUpdateManifestFile(argv = [], options = {})` | L161 |

`docs/design/AUTO_UPDATE.md` §3 / §8）：记录 tag、构建时间，以及 Windows 便携布局中
`SteamNavigator.exe`、`mods/core-*.snavmod.zip`、平台 ZIP 的路径 / 字节数 / SHA-256。

## 契约与约束
- 零依赖、Node >= 18；`buildUpdateManifest` 是可 import 的同步函数（文件读取可注入 `fs`），CLI 与测试共用。
- `schema` 固定 `1`；`published_at` 必须是 UTC ISO（`YYYY-MM-DDTHH:MM:SSZ`），只用于阻止客户端降级。
- 位置字段描述**发布包内**的便携布局，不是构建机路径：`engine.path` / `package.name` 取 basename，
  `core.path` 固定写 `mods/<core 文件名>`（core 包在便携包内位于 `mods/`）。
- 路径字段只允许相对路径，拒绝绝对路径 / `..` / 空段（客户端按契约只写 exe、`mods/`、`config/install.json`）。
- 输出键顺序固定（schema → tag → published_at → platforms.windows.engine/core/package），同一输入生成结果可 diff。
- 清单**不包含自身哈希**：`release.yml` 在清单生成后把它并入 `SHA256SUMS.txt`，由 sums 记录清单哈希。
- CLI 参数缺失、文件不存在 / 不是普通文件、`published_at` 或 `tag` 非法时写 stderr 并 exit 1；成功打印输出路径。

## 重点逻辑
### `buildUpdateManifest({ tag, publishedAt, enginePath, corePath, packagePath, fs? })`
- 校验参数 → 逐文件 stat + SHA-256（一次只读一个文件）→ 返回契约 §3 的对象。
### `renderUpdateManifest(manifest)`
- `JSON.stringify(manifest, null, 2) + "\n"`，供 CLI 落盘、测试断言稳定文本。
### CLI
- `node tools/build_update_manifest.mjs --tag <tag> --published-at <UTC ISO> --engine <file> --core <file> --package <file> --output <file>`

模块索引：[tools](./README.md)
