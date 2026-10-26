# `website/tools/build-wiki-data.mjs`

> 作用：把 Core 内容 JSON（`dev_mods/core/content/*.json`）与中文文案（`dev_mods/core/localization/zh_CN.json`）编译成官网百科数据 `website/assets/data/wiki-data.js`。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `HERE` | L35 |
| `ROOT` | L36 |
| `CONTENT_DIR` | L37 |
| `LOC_PATH` | L38 |
| `OUT_PATH` | L39 |
| `UPDATED` | L41 |
| `CATEGORIES` | L47 |
| `SECTIONS` | L62 |
| `ZH` | L79 |
| `TAG_ZH` | L118 |
| `STAT_ZH` | L171 |
| `EFFECT_ZH` | L178 |
| `readJson(file)` | L193 |
| `textOf(key)` | L198 |
| `refName(id)` | L204 |
| `refList(ids)` | L208 |
| `num(value)` | L212 |
| `signed(value)` | L216 |
| `pct(value)` | L222 |
| `signedPct(value)` | L228 |
| `mul(value)` | L234 |
| `band(value, pairs)` | L239 |
| `roman(n)` | L245 |
| `pairs(...items)` | L250 |
| `zh(key)` | L261 |
| `itemCounts(list, keyName, amountKey)` | L266 |
| `modifierText(list)` | L278 |
| `SOURCE_SPECS` | L298 |
| `GLOSSARY` | L623 |
| `LINK_BY_CATEGORY` | L640 |
| `slugFor(definitionId, fallbackType)` | L646 |
| `tagsFor(definition, kind, title)` | L655 |
| `titleFor(definition, type, local)` | L668 |
| `descriptionFor(definition)` | L675 |
| `loadInputs()` | L679 |
| `buildEntries(data)` | L697 |
| `SLUG_RE` | L747 |
| `FORBIDDEN` | L748 |
| `INTERNAL_LABELS` | L750 |
| `RAW_RISK_RE` | L752 |
| `CJK_RE` | L753 |
| `validate(entries)` | L755 |
| `buildDocument(entries)` | L799 |
| `serialize(document)` | L807 |
| `report(document, countByCategory, file, written)` | L817 |
| `main()` | L831 |

## 契约与约束
- 只读输入，不修改 `dev_mods/`；输出固定为 `window.SN_WIKI_DATA = { updated, categories, entries }`。
- `updated` 恒为 `2026-10-24`，不读取系统时间；条目按“分类固定顺序 + 内容定义顺序”输出，同输入必同输出。
- 11 个分类的 id / label / heading / icon 固定（docs/design/WEBSITE.md §6），顺序固定。
- 条目字段：`id`（锚点 slug，不展示）、`category`、`title`、`kind`（中文徽标）、`description`、`tags`（中文 1–3）、`stats`（0–4 组 [中文标签, 玩家可读数值]）；`link` 预留但当前不输出。
- 文案只取 zh_CN 的 `name_key` / `description_key`；`description` 缺失时输出空字符串，绝不用 key 或英文兜底。
- 禁止展示实现字段：`core:` ID、`schema_version`、`content_type`、`capability`、`*_key`、资产路径；构建末尾有强制扫描。
- 数值原样展示并补玩家可读单位（金币 / 节 / 人 / 槽 / 小时）；概率与风险增量统一为带符号百分比（`-1.5%` / `+6%`），倍率写 `×1.18`，只改写法、不做单位换算；权重、射程、冷却、距离、危险度等无单位语义的数值保持原样。
- 内部生成字段（如地点 `weight` 出现权重、`spawn_weight`）不进入玩家可见文案，`validate()` 有回归守卫。
- 标签从内容 tag slug 翻译成中文，去掉与徽标 / 标题重复的词后截断到 3 个；不照搬英文 slug。
- `link` 为可选字段；`LINK_BY_CATEGORY` 目前为空（game.html 锚点未冻结），不生成对不存在锚点的链接。
- 零依赖，只使用 Node 内置模块；`ROOT` 由脚本位置推导，可在仓库根直接 `node website/tools/build-wiki-data.mjs`。

## 重点逻辑
### 数据装配
- `SOURCE_SPECS` 按内容文件声明徽标与 stats 构造器；`SECTIONS` 决定分类内各来源的先后，保证条目顺序稳定。
- `REF_NAMES` 把全部定义 id 映射到中文名，用于“投入 / 产出 / 遗物池 / 危险表”等引用字段，避免把 `core:` ID 写进正文。
- 引用解析不到时该 stats 直接省略（宁缺毋滥），而不是回退成原始 ID。
### 文案与回退
- `textOf(key)` 只返回 zh_CN 的非空字符串；名称缺失时用本地 id 的连字符写法兜底并记录警告（当前数据无缺失）。
- 描述缺失输出 `''`，由页面决定是否隐藏，避免把 `item.core.x.description` 展示给玩家。
### 校验
- `validate()` 检查 slug 唯一性、tags 数量与中文、stats 上限、禁用字段扫描、内部生成字段与风险百分比守卫；任一失败直接抛错，不写出半成品。
- 输出前与磁盘内容比较，内容相同则跳过写入，避免并行构建时无意义的时间戳抖动。

模块索引：[website](../README.md)
