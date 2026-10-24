# `framework/ui/components/sn_story_card.gd`

> 作用：新手剧情 / 教学系统的全屏剧情卡（阶段 4.5）。深色遮罩 + 居中剧情面板：

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNStoryCard` | L1 |
| `advance_requested (signal)` | L29 |
| `skip_requested (signal)` | L30 |
| `CARD_WIDTH` | L32 |
| `is_skip_confirm() -> bool` | L47 |

标题、多段正文、右侧「继续」与「跳过教程」；点「跳过教程」先切到确认页，
确认后才发 `skip_requested`。纯表现组件，不查询后端、不改状态。

- 关键依赖：`story.view` 的 `card` 字典、本地化回调

## 契约与约束
- `bind(card, translate)` 注入已裁剪的 card 数据（`title_key` / `body_keys` /
  `advance_label_key` / `skip_label_key`）；文案键由调用方 / 本地化服务翻译。
- 信号：`advance_requested`（继续）、`skip_requested`（确认跳过）。确认页的
  「取消」只回到剧情正文，不发信号。
- 遮罩 `mouse_filter = STOP`：卡片打开期间拦截页面点击；尺寸变化由布局自适应。
- 测试通过节点名访问按钮：`ContinueButton` / `SkipButton` / `SkipConfirmButton` /
  `SkipCancelButton`。

## 皮肤与节点约束（UI 贴图层）
- 剧情卡是航海日志纸面：面板用 `SNParchmentPanel`（`StoryPanel` 节点名不变），
  遮罩色取 `SNSkin.color("bg.abyss")` + 0.72 alpha；标题/眉题沿用
  `SNTitleLabel` / `SNEyebrowLabel`，在纸面上把文字色覆盖为
  `ink.primary` / `brass.shadow`。按钮统一 Theme 变体（继续 `SNPrimaryButton`、
  跳过/取消 `SNGhostButton`），Ghost 在纸面用深墨色字体覆盖以保证对比度。
- 卡片宽度 `CARD_WIDTH = 720`、按钮节点名与信号（`advance_requested` /
  `skip_requested`）不变，test_story_ui 按名字查找。

模块索引：[framework/ui](../README.md)
