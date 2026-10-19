# `SNModMaker/tools/game_mods_dir.mjs`

> 作用：解析编辑器「导出并覆盖到发布包 mods/」的默认目标目录。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `PLATFORM_TARGETS` | L4 |
| `resolveGameModsDir(root, options = {})` | L16 |

## 契约与约束

- 优先级：`SNMODMAKER_GAME_MODS_DIR` > 当前平台已有的 `dist/build/<target>/` > 任意已有导出平台 > 当前平台 `dist/build/<platform>/mods`。
- 平台映射：win32→windows、darwin→macos，其余→linux。
- 纯函数可注入 env/platform/exists，供 Node 单元测试覆盖，不直接读真实目录。

模块索引：[SNModMaker](../README.md)
