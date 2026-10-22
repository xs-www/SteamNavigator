# `sdk`

> 模组开发工具：打包、校验、模板与示例。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `README.md` | 源文件：README.md | 本页 |
| `examples/example_boilers/content/modules.json` | 可被运行时扫描的示例：全 2.0 的 modules / crew_roles / items / D1 weapons / D2 fleet 与多类型混合模组。 | 本页 |
| `examples/example_boilers/localization/en.json` | 可被运行时扫描的示例：全 2.0 的 modules / crew_roles / items / D1 weapons / D2 fleet 与多类型混合模组。 | 本页 |
| `examples/example_boilers/localization/zh_CN.json` | 可被运行时扫描的示例：全 2.0 的 modules / crew_roles / items / D1 weapons / D2 fleet 与多类型混合模组。 | 本页 |
| `examples/example_boilers/manifest.json` | 可被运行时扫描的示例：全 2.0 的 modules / crew_roles / items / D1 weapons / D2 fleet 与多类型混合模组。 | 本页 |
| `examples/example_crew_roles/content/crew_roles.json` | 可被运行时扫描的示例：全 2.0 的 modules / crew_roles / items / D1 weapons / D2 fleet 与多类型混合模组。 | 本页 |
| `examples/example_crew_roles/localization/en.json` | 可被运行时扫描的示例：全 2.0 的 modules / crew_roles / items / D1 weapons / D2 fleet 与多类型混合模组。 | 本页 |
| `examples/example_crew_roles/localization/zh_CN.json` | 可被运行时扫描的示例：全 2.0 的 modules / crew_roles / items / D1 weapons / D2 fleet 与多类型混合模组。 | 本页 |
| `examples/example_crew_roles/manifest.json` | 可被运行时扫描的示例：全 2.0 的 modules / crew_roles / items / D1 weapons / D2 fleet 与多类型混合模组。 | 本页 |
| `examples/example_fleet/content/captains.json` | 可被运行时扫描的示例：全 2.0 的 modules / crew_roles / items / D1 weapons / D2 fleet 与多类型混合模组。 | 本页 |
| `examples/example_fleet/content/fleet_doctrines.json` | 可被运行时扫描的示例：全 2.0 的 modules / crew_roles / items / D1 weapons / D2 fleet 与多类型混合模组。 | 本页 |
| `examples/example_fleet/content/formations.json` | 可被运行时扫描的示例：全 2.0 的 modules / crew_roles / items / D1 weapons / D2 fleet 与多类型混合模组。 | 本页 |
| `examples/example_fleet/content/ship_archetypes.json` | 可被运行时扫描的示例：全 2.0 的 modules / crew_roles / items / D1 weapons / D2 fleet 与多类型混合模组。 | 本页 |
| `examples/example_fleet/localization/en.json` | 可被运行时扫描的示例：全 2.0 的 modules / crew_roles / items / D1 weapons / D2 fleet 与多类型混合模组。 | 本页 |
| `examples/example_fleet/localization/zh_CN.json` | 可被运行时扫描的示例：全 2.0 的 modules / crew_roles / items / D1 weapons / D2 fleet 与多类型混合模组。 | 本页 |
| `examples/example_fleet/manifest.json` | 可被运行时扫描的示例：全 2.0 的 modules / crew_roles / items / D1 weapons / D2 fleet 与多类型混合模组。 | 本页 |
| `examples/example_mixed_crew_roles_items/content/crew_roles.json` | 可被运行时扫描的示例：全 2.0 的 modules / crew_roles / items / D1 weapons / D2 fleet 与多类型混合模组。 | 本页 |
| `examples/example_mixed_crew_roles_items/content/items.json` | 可被运行时扫描的示例：全 2.0 的 modules / crew_roles / items / D1 weapons / D2 fleet 与多类型混合模组。 | 本页 |
| `examples/example_mixed_crew_roles_items/localization/en.json` | 可被运行时扫描的示例：全 2.0 的 modules / crew_roles / items / D1 weapons / D2 fleet 与多类型混合模组。 | 本页 |
| `examples/example_mixed_crew_roles_items/localization/zh_CN.json` | 可被运行时扫描的示例：全 2.0 的 modules / crew_roles / items / D1 weapons / D2 fleet 与多类型混合模组。 | 本页 |
| `examples/example_mixed_crew_roles_items/manifest.json` | 可被运行时扫描的示例：全 2.0 的 modules / crew_roles / items / D1 weapons / D2 fleet 与多类型混合模组。 | 本页 |
| `examples/example_weapons/content/weapons.json` | 可被运行时扫描的示例：全 2.0 的 modules / crew_roles / items / D1 weapons / D2 fleet 与多类型混合模组。 | 本页 |
| `examples/example_weapons/localization/en.json` | 可被运行时扫描的示例：全 2.0 的 modules / crew_roles / items / D1 weapons / D2 fleet 与多类型混合模组。 | 本页 |
| `examples/example_weapons/localization/zh_CN.json` | 可被运行时扫描的示例：全 2.0 的 modules / crew_roles / items / D1 weapons / D2 fleet 与多类型混合模组。 | 本页 |
| `examples/example_weapons/manifest.json` | 可被运行时扫描的示例：全 2.0 的 modules / crew_roles / items / D1 weapons / D2 fleet 与多类型混合模组。 | 本页 |
| `pack_mod.gd` | 把松散模组目录打包成 `<mod_id>-<version>.snavmod.zip`；`--release` 在打包前强制跑一遍真实 runtime 校验。 | [查看](./pack_mod.gd.md) |
| `templates/draft_combat_ai_profile/content/combat_ai_profiles.json` | 模组模板：Manifest、`items` 2.0 最小模板，以及只能 draft 校验的 `story_arcs` / `story_levels` 剧情包模板。 | 本页 |
| `templates/draft_combat_ai_profile/localization/en.json` | 模组模板：Manifest、`items` 2.0 最小模板，以及只能 draft 校验的 `story_arcs` / `story_levels` 剧情包模板。 | 本页 |
| `templates/draft_combat_ai_profile/localization/zh_CN.json` | 模组模板：Manifest、`items` 2.0 最小模板，以及只能 draft 校验的 `story_arcs` / `story_levels` 剧情包模板。 | 本页 |
| `templates/draft_combat_ai_profile/manifest.json` | 模组模板：Manifest、`items` 2.0 最小模板，以及只能 draft 校验的 `story_arcs` / `story_levels` 剧情包模板。 | 本页 |
| `templates/mod_template/README.md` | 模组模板：Manifest、`items` 2.0 最小模板，以及只能 draft 校验的 `story_arcs` / `story_levels` 剧情包模板。 | 本页 |
| `templates/mod_template/content/items.json` | 模组模板：Manifest、`items` 2.0 最小模板，以及只能 draft 校验的 `story_arcs` / `story_levels` 剧情包模板。 | 本页 |
| `templates/mod_template/localization/en.json` | 模组模板：Manifest、`items` 2.0 最小模板，以及只能 draft 校验的 `story_arcs` / `story_levels` 剧情包模板。 | 本页 |
| `templates/mod_template/localization/zh_CN.json` | 模组模板：Manifest、`items` 2.0 最小模板，以及只能 draft 校验的 `story_arcs` / `story_levels` 剧情包模板。 | 本页 |
| `templates/mod_template/manifest.json` | 模组模板：Manifest、`items` 2.0 最小模板，以及只能 draft 校验的 `story_arcs` / `story_levels` 剧情包模板。 | 本页 |
| `templates/story_pack_iron_tide/README.md` | 模组模板：Manifest、`items` 2.0 最小模板，以及只能 draft 校验的 `story_arcs` / `story_levels` 剧情包模板。 | 本页 |
| `templates/story_pack_iron_tide/content/story_arcs.json` | 模组模板：Manifest、`items` 2.0 最小模板，以及只能 draft 校验的 `story_arcs` / `story_levels` 剧情包模板。 | 本页 |
| `templates/story_pack_iron_tide/content/story_levels.json` | 模组模板：Manifest、`items` 2.0 最小模板，以及只能 draft 校验的 `story_arcs` / `story_levels` 剧情包模板。 | 本页 |
| `templates/story_pack_iron_tide/localization/en.json` | 模组模板：Manifest、`items` 2.0 最小模板，以及只能 draft 校验的 `story_arcs` / `story_levels` 剧情包模板。 | 本页 |
| `templates/story_pack_iron_tide/localization/zh_CN.json` | 模组模板：Manifest、`items` 2.0 最小模板，以及只能 draft 校验的 `story_arcs` / `story_levels` 剧情包模板。 | 本页 |
| `templates/story_pack_iron_tide/manifest.json` | 模组模板：Manifest、`items` 2.0 最小模板，以及只能 draft 校验的 `story_arcs` / `story_levels` 剧情包模板。 | 本页 |
| `validate.gd` | SDK 无头校验入口：默认 `runtime` 模式跑真实 Bootstrap，`draft` 模式对草案 / 混合模组做静态 Schema 校验。 | [查看](./validate.gd.md) |
| `validation_core.gd` | SDK 共享校验核心：提供 runtime（真实 Bootstrap 加载）与 draft（静态 Schema）两种校验， | [查看](./validation_core.gd.md) |

## 模块契约

- SDK 只使用公开框架接口，不依赖 core 私有路径。
- 类型 / 版本唯一真源是 `content_types.json`：active 类型走生成物 `ContentTypes`，草案类型走其 `draft_schemas` / `draft_types`，SDK 不维护第二套表。
- `validate.gd` 默认 `--mode=runtime`（真实 Bootstrap，显式拒绝未激活草案），`--mode=draft` 做草案 / 混合模组的静态 Schema 校验；`--json` 附加 `mode` / `ok` 与结构化 `errors[]`。
- `pack_mod.gd --release` 复用同一套 runtime 校验，草案或 error 时拒绝打包；不带 `--release` 保持旧打包行为与 zip 结构。
- 示例：2.0 `example_boilers`（modules）、2.0 `example_crew_roles`（crew_roles）、混合 2.0 `example_mixed_crew_roles_items` 与 D1 `example_weapons`（weapons）、D2 `example_fleet`（fleet 4 类型）；草案模板 `story_pack_iron_tide` 只能 draft 校验、不可发布。
