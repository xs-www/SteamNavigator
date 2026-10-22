# `SNModMaker/tests/run-tests.js`

> 作用：Node 单元测试：Schema 校验、项目模型、全部内容类型表单、索引/克隆、ZIP、导入导出往返、GLB 解析与部署目标解析；含 `weapons` 草案、船体 socket 镜像、「舰载武器包」模板与剧情模式（`story_arcs` / `story_levels`）用例。

- 类型：浏览器经典脚本

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `UI` | L29 |
| `GLB` | L31 |
| `schemaFilesOnDisk()` | L34 |
| `test(name, fn)` | L53 |
| `freshProject()` | L66 |
| `projectFromDir(dir)` | L71 |
| `storyPackProject()` | L86 |
| `errorsOf(result)` | L90 |
| `warningsOf(result)` | L94 |

## 契约与约束

- 不依赖浏览器或 Godot；直接 require 经典脚本并以 `globalThis.SN*` 访问模块。
- 覆盖实体多语言键事务、资源候选类型过滤、船体模块区、武器表单字段、船体安装点编辑、贴图/GLB 引用、GLB 解析与发布包 mods 目标解析；任何失败以退出码 1 结束。
- 「舰载武器包」模板断言 5 件预设（`WEAPON_PRESETS`）、生成一个 `content/weapons.json`、每条 `information.model` 为 `asset://core/model.weapon.*` 且 manifest 声明 `content.combat.v1`。
- 剧情用例：Schema bundle 31 个（含 `v2/story_arc` / `v2/story_level`）；catalog 默认值与示例包 `sdk/templates/story_pack_iron_tide` 零错误；`story_pack_off_whitelist`、`story_protagonist_unknown`、`story_level_checkpoint_missing`、`story_beat_stage_unknown`、`story_fail_default_not_allowed`、`story_fixed_*` 等语义错误可被触发；纯剧情项目与武器草案分开建项目（混装会被白名单拒绝）。

模块索引：[SNModMaker](../README.md)
