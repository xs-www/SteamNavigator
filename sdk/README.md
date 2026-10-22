# Steam Navigator SDK

模组开发工具：内容校验（`validate.gd`）、打包（`pack_mod.gd`）、模板（`templates/`）与示例（`examples/`）。
全部脚本只依赖 Godot 与仓库内的公开 Schema / 框架接口，不引入第三方依赖。

## 类型与版本的唯一真源

`content_types.json` 是内容类型清单的唯一真源，生成物 `framework/modding/content_types.gd`（`ContentTypes`）
携带每个 **active** 类型的 Schema 路径与 `schema_version`。SDK 不维护第二套类型或版本表：

- **active 类型**：由运行时真实加载；C4 收尾后所有运行时类型（含 `contracts` / `patches`）统一为 `2.0`。
- **草案（draft）类型**：登记在 `content_types.json` 的 `draft_schemas` / `draft_types`，目前是
  `weapons`、`story_arcs`、`story_levels`。运行时不会加载它们，只能做 `--mode=draft` 静态校验，不能发布。

新增类型时先改 `content_types.json` 与 `schemas/`，再跑 `node tools/gen_content_types.mjs`；不要在 SDK 里硬编码类型表。

## 校验：`sdk/validate.gd`

```powershell
# 默认 runtime：真实 Bootstrap 加载 core + 指定模组（旧调用方式保持兼容）
godot --headless --path . --script res://sdk/validate.gd -- --mod-root=sdk/examples/example_crew_roles

# 草案 / 混合模组的静态 Schema 校验：不启动运行时
godot --headless --path . --script res://sdk/validate.gd -- \
  --mod-root=sdk/templates/draft_weapons_pack --mode=draft --json

# 只校验 Core
godot --headless --path . --script res://sdk/validate.gd -- --mode=runtime
```

| `--mode` | 行为 |
| --- | --- |
| `runtime`（默认） | Core 从 `dev_mods` 加载，`--mod-root` 的父目录追加为扫描根，走真实 `Bootstrap`；未激活草案内容被显式拒绝，错误码 `inactive_content_type`。 |
| `draft` | 不启动运行时，按 `ContentTypes` + `content_types.json` 的草案表做静态 Schema 校验；草案与混合模组都能校验。 |

- `--json` 输出 `StartupReport` 的既有字段，并附加 `mode` 与 `ok`；`errors[]` 每项含
  `code` / `message` / `severity` / `mod` / `file` / `path`，可直接给 CI 解析。
- 退出码：`0` 无 error；`1` 存在 error / fatal（runtime 拒绝草案、Schema 错误、版本不符等）；
  `2` 用法错误（例如未知 `--mode`）。
- `runtime` 保留 `--mod-root` 旧语义：指向单个模组目录时自动改用其父目录作为扫描根。

## 打包：`sdk/pack_mod.gd`

```powershell
# 普通打包：保持旧行为，只校验 manifest 可读，输出 mods/<id>/... 结构的 .snavmod.zip
godot --headless --path . --script res://sdk/pack_mod.gd -- \
  --source=dev_mods/core --out=dist/mods

# 正式发布：打包前跑真实 runtime 校验；存在未激活草案或任何 error 时拒绝打包
godot --headless --path . --script res://sdk/pack_mod.gd -- \
  --source=dev_mods/core --out=dist/mods --release
```

`--release` 的校验与 `validate.gd --mode=runtime` 共用同一套实现（`sdk/validation_core.gd`）：
Core 从 `dev_mods` 加载，第三方模组先复制到 `user://` 隔离目录再加载，避免同目录下其它示例模组影响结果。
被拒绝时不会写出 zip。`.snavmod.zip` 结构始终为 `mods/<mod_id>/...`，不因 `--release` 改变。

## 示例与模板

| 路径 | 版本 | 说明 |
| --- | --- | --- |
| `examples/example_crew_roles/` | 2.0 | 已激活的 `crew_roles` 2.0 示例；runtime 与 draft 校验都应通过。 |
| `examples/example_boilers/` | 2.0 | 已激活的 `modules` 2.0 示例。 |
| `examples/example_mixed_crew_roles_items/` | 2.0 + 2.0 | `crew_roles` + `items` 两个 active 2.0 类型共存；runtime 加载通过。 |
| `templates/mod_template/` | 2.0 | 最小 `items` 2.0 模组模板。 |
| `templates/draft_weapons_pack/` | 2.0 草案 | `weapons` 草案示例：**只能** `--mode=draft` 校验，`--release` 打包必然被拒绝。 |
| `templates/story_pack_iron_tide/` | 2.0 草案 | `story_arcs` / `story_levels` 剧情包草案示例，同样只能 draft 校验、不可发布。 |

> `sdk/examples/` 是开发态可被 runtime 扫描的目录，**不要**把草案内容放进 `examples/`；草案示例统一放在
> `templates/`，避免同目录其它示例的 runtime 校验被连带拒绝。

## 发布门禁

`.github/workflows/release.yml` 在发布 tag 上依次执行：

1. Core runtime 校验（`--mode=runtime`）；
2. 示例 mod 的 runtime 校验（全部为 2.0），以及草案模板的 draft 校验；
3. 草案发布拦截（`pack_mod --release` 对草案必须失败）；
4. `pack_mod --release` 打包 Core（校验通过才写 zip）。
