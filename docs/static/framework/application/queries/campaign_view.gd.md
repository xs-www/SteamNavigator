# `framework/application/queries/campaign_view.gd`

> 作用：v2 战役运行时快照查询（`campaign.view`，Phase B B3）。只读地输出

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `CampaignViewQuery` | L1 |
| `execute(_params: Dictionary, context) -> Dictionary` | L25 |

`setup / regions / sites / factions / codex / exploration` 六块，供 UI 与测试读取
当前战役身份、世界装配结果与探索进度；1.0 旧档返回同一形状的空默认块。

- 关键依赖：`GameState.campaign_setup()` / `campaign_world()` / `campaign_codex()` /
  `campaign_factions()`、`ExplorationRules.read()`、`GameState.clues()`、
  `ContentRefs.is_v2_campaign()`

## 契约与约束
- 只读：不写状态、不发事件、不调用 ensure 以外的变更路径。
- 形状稳定：无 run 或 1.0 旧档也返回六个键；`regions/sites` 为 Array，
  `setup/factions/codex/exploration` 为 Dictionary，不因档版本缺键。
- 内容定义不进入快照：只输出实例 id / 数值 / 进度；`exploration.rules` 是
  `ExplorationRules.read()` 合并后的纯数值字典。
- `factions` 按 faction id 输出 `{reputation, attitude, discovered, met_at}`；
  旧档条目经 `GameState` 的逐键惰性回填后同样齐全。
- 1.0 兼容：`campaign.setup` 全空、`regions/sites` 为空数组、`is_v2=false`，
  不重排 / 不重新生成世界。

模块索引：[framework/application](../README.md)
