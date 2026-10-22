# `sdk`

> 模组开发工具：打包、校验、模板与示例。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `examples/example_boilers/content/boilers.json` | 第三方锅炉示例，验证公共内容接口。 | 本页 |
| `examples/example_boilers/localization/en.json` | 第三方锅炉示例，验证公共内容接口。 | 本页 |
| `examples/example_boilers/localization/zh_CN.json` | 第三方锅炉示例，验证公共内容接口。 | 本页 |
| `examples/example_boilers/manifest.json` | 第三方锅炉示例，验证公共内容接口。 | 本页 |
| `pack_mod.gd` | 把松散模组目录打包为 `mods/<id>/...` 的 `.snavmod.zip`。 | [查看](./pack_mod.gd.md) |
| `templates/mod_template/README.md` | 模组模板：Manifest、商品、双语本地化与说明。 | 本页 |
| `templates/mod_template/content/goods.json` | 模组模板：Manifest、商品、双语本地化与说明。 | 本页 |
| `templates/mod_template/localization/en.json` | 模组模板：Manifest、商品、双语本地化与说明。 | 本页 |
| `templates/mod_template/localization/zh_CN.json` | 模组模板：Manifest、商品、双语本地化与说明。 | 本页 |
| `templates/mod_template/manifest.json` | 模组模板：Manifest、商品、双语本地化与说明。 | 本页 |
| `templates/story_pack_iron_tide/README.md` | 模组模板：Manifest、商品、双语本地化与说明。 | 本页 |
| `templates/story_pack_iron_tide/content/story_arcs.json` | 模组模板：Manifest、商品、双语本地化与说明。 | 本页 |
| `templates/story_pack_iron_tide/content/story_levels.json` | 模组模板：Manifest、商品、双语本地化与说明。 | 本页 |
| `templates/story_pack_iron_tide/localization/en.json` | 模组模板：Manifest、商品、双语本地化与说明。 | 本页 |
| `templates/story_pack_iron_tide/localization/zh_CN.json` | 模组模板：Manifest、商品、双语本地化与说明。 | 本页 |
| `templates/story_pack_iron_tide/manifest.json` | 模组模板：Manifest、商品、双语本地化与说明。 | 本页 |
| `validate.gd` | 无头校验 Core + 可选第三方模组，输出文本或 JSON 报告。 | [查看](./validate.gd.md) |

## 模块契约

- SDK 只使用公开框架接口，不依赖 core 私有路径。
- 示例 `example_boilers` 通过普通注册表进入游戏。
