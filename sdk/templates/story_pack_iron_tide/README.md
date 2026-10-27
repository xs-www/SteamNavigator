# Story Pack Template: Iron Tide

剧情模式的**数据包模板 / 示例**：一个篇章（`story_arcs`）+ 两个关卡（`story_levels`），
按普通模组格式加载，但只允许携带剧情内容（白名单：`story_arcs` / `story_levels`）。

- 契约与设计：[docs/specs/STORY_MODE_DATA_CONTRACT_V2.md](../../../docs/specs/STORY_MODE_DATA_CONTRACT_V2.md)、[docs/design/STORY_MODE.md](../../../docs/design/STORY_MODE.md)
- Schema：`schemas/v2/story_arc.schema.json`、`schemas/v2/story_level.schema.json`
- 结构说明：

| 路径 | 内容 |
| --- | --- |
| `manifest.json` | 模组清单；`capabilities: ["content.story.v1"]` |
| `content/story_arcs.json` | 篇章 `iron_tide`：固定主角 `captain`、角色表、术语、有序关卡列表 |
| `content/story_levels.json` | 关卡 `01_first_smoke`、`02_homeward`：手写陆地/航道、初始状态、2D 叙事（lines/choices）、内嵌任务、可见限制、难度、checkpoint 重试 |
| `localization/zh_CN.json` / `en.json` | 全部文本键 |

## 内容说明

- 本包是**虚构示例**，`canon: false`，不属于官方正史；数值与文本仅用于验证数据驱动演示。
- 放在 `sdk/templates/` 而不是 `sdk/examples/`：`sdk/examples` 是运行时启动扫描根，
  而剧情包是 Schema 2.0 草案内容，当前 1.0 运行时还不加载；等剧情模式进入运行时后再迁移。
- 关卡内嵌固定地图（`data.map.fixed`）：**手写陆地多边形 + 港口 + 航道路径点**，港口 ID 为
  `port_0` / `port_1` / `port_2`，不使用随机生成；`distance` 由航道路径折线长度派生。
- 叙事用 `stages[].lines`（说话人 + 文本 + 可选立绘/背景/音频）与 `stages[].choices`；
  本示例未携带媒体资源，只验证文本与选择结构。
- 任务用关卡内嵌 `tasks[]`（复用 quest 阶段/目标语义），本示例的补给任务 `auto_start: true`。
- 可见限制用 `access.pages` / `access.actions` 三态；示例把船厂隐藏、借贷锁定并给出原因键。
- 失败处理：`fail.default_mode = checkpoint`，允许 `checkpoint` / `level_start` 两种重试方式。
- 奖励只记录成就 / 图鉴（`rewards.achievements` / `codex_entries`），不写金钱与物品，
  保证剧情包不会影响自由模式进度；任务奖励只在本关生效。

## 校验（draft）

剧情内容类型（`story_arcs` / `story_levels`）仍是 Schema 2.0 草案，运行时不会加载；用 SDK 的
draft 模式做静态 Schema 校验：

```powershell
godot --headless --path . --script res://sdk/validate.gd -- \
  --mod-root=sdk/templates/story_pack_iron_tide --mode=draft
```

期望退出码 0、0 error。注意：

- 用 `--mode=runtime`（默认）校验本包会按预期失败，错误码 `inactive_content_type`；
- `sdk/pack_mod.gd --release` 会拒绝打包本包：草案内容不可发布。

SNModMaker / Content CLI 仍可用 `node SNModMaker/tools/content.mjs validate --mod sdk/templates/story_pack_iron_tide`
做编辑器侧校验（草案会给出 `draft_content` warning，属预期）。

## 编辑

用 `SNModMaker/`（模组编辑器，剧情关卡直接在其中编辑）打开本目录，或由编辑器导出同名数据包；
两者共享同一套 Schema 与校验逻辑，round-trip 不丢字段。数据契约 V2 已冻结（2026-10-27）：
`node tools/check_story_schema_freeze.mjs --check`，约束见
[docs/specs/STORY_MODE_DATA_CONTRACT_V2.md](../../../docs/specs/STORY_MODE_DATA_CONTRACT_V2.md)。