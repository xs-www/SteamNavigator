# 官网图片资产清单（MANIFEST）

> 生成日期：2026-10-24 · 契约：`docs/design/WEBSITE.md` §5 图片槽位
> 输出目录：`website/assets/img/` · 共 14 个 JPEG · 合计 **1.48 MB / 1,546,939 字节**（上限 4 MB，目标 ≤3 MB）
> 处理链：Pillow 9.5 · `Image.open(...).convert("RGB")` → `LANCZOS` 缩放 → 渐进式 JPEG（`optimize=True, progressive=True`）
> 质量策略：以契约 quality 为起点自适应下调（本次 14 张均在契约 quality 下即满足体积上限，无需降质）

## 一、文件清单

| 文件名 | 源路径 | 最终尺寸 | 文件大小 | 裁切区域 | 检查结论（是否含调试 UI） |
| --- | --- | --- | --- | --- | --- |
| `hero-main.jpg` | `assets/ui/banners/main_menu_harbor.png` (1672×941) | 1600×900 | 273.8 KB (q84, ≤420) | 中心裁到 16:9：源 (0,0,1672,940) → 缩放 1600×900 | ✅ 无调试 UI / 无文字 / 无署名；蒸汽船与港城主体完整，渐变天空与海面压缩无可见瑕疵 |
| `og-cover.jpg` | `assets/ui/banners/main_menu_harbor.png` (1672×941) | 1200×630 | 149.2 KB (q82, ≤260) | 中心裁到 1.905:1：源 (0,31,1672,909) → 缩放 1200×630 | ✅ 无调试 UI / 无文字；船体完整位于画面中下部，适合叠加分享标题 |
| `port-hero.jpg` | `docs/design/screenshots/port_stage/port_stage_preview.png` (1440×900) | 1440×900 | 140.0 KB (q82, ≤260) | 源图即 16:10，不裁切，仅重编码 | ✅ 无调试 UI / 无文字；站前建筑与码头完整 |
| `port-terminal.jpg` | `docs/design/screenshots/architecture/grand_terminal_three_quarter.png` (1600×900) | 1600×900 | 70.6 KB (q82, ≤220) | 源图即 16:9，不裁切，仅重编码 | ✅ 无调试 UI / 无文字；候船楼主体完整 |
| `ship-schooner.jpg` | `docs/design/screenshots/ship_assembly/shipyard_schooner_hero.png` (1440×900) | 1440×900 | 91.8 KB (q82, ≤240) | 源图即 16:10，不裁切，仅重编码 | ✅ 无调试 UI / 无文字；双桅纵帆船完整，帆面高光无噪点 |
| `ship-ironclad.jpg` | `docs/design/screenshots/ship_assembly/shipyard_ironclad.png` (1440×900) | 1440×900 | 80.1 KB (q82, ≤240) | 源图即 16:10，不裁切，仅重编码 | ✅ 无调试 UI / 无文字；装甲舰完整，尾迹与水花细节保留 |
| `ship-paddle.jpg` | `docs/design/screenshots/paddle_steamer_three_quarter.png` (1400×820) | 1440×900 | 65.9 KB (q82, ≤240) | 按 16:10 内裁：源 (44,0,1356,820) → 放大到 1440×900 | ✅ 无调试 UI / 无文字；明轮蒸汽船完整，9.8% 放大后边缘仍清晰 |
| `chart.jpg` | `docs/design/screenshots/sea_chart/sea_chart_explored.png` (1440×900) | 1440×900 | 64.4 KB (q82, ≤220) | 源图即 16:10，不裁切，仅重编码 | ✅ 无调试 UI / 无版本号 / 无署名；右侧「香料港 / 航程信息 / 启航」与左下角图例均为游戏内海图 UI，非调试信息 |
| `market-ui.jpg` | `docs/design/screenshots/market_station.png` (1440×900) | 1440×720 | 154.1 KB (q82, ≤220) | 裁 (0,136,1440,856)：顶部 136 px、底部 44 px | ✅ 顶部 HUD 整条移除（含「框架就绪 v0.1.0」「诊断日志」「刷新」与剩余载重/货舱/煤炭/淡水/耐久数值行）；底部「开发团队 · Steam Navigator Team」「版本 · v0.2.0」已移除；顶部无半截数值、底部为完整面板边框，无残字 |
| `shipyard-ui.jpg` | `docs/design/screenshots/skin/1440x900/shipyard_refit.png` (1440×900) | 1440×714 | 194.0 KB (q82, ≤260) | 裁 (0,142,1440,856)：顶部 142 px、底部 44 px | ✅ 顶部主 HUD 整条移除（含「框架就绪 v0.1.0」「诊断日志」「刷新」与数值行）；底部署名已移除；无裁切残字。保留游戏内「指引 备齐补给」与「获得线索：酒馆消息」两条完整提示条（属玩法 UI，非调试 UI）。源图右下角小面板内另有部分渲染的蓝字 UI 标签，非本次裁切造成，详见第二节 |
| `combat-lineup.jpg` | `docs/design/screenshots/combat/combat_lineup.png` (1920×720) | 1600×600 | 25.7 KB (q82, ≤220) | 保持原 8:3 比例，整图缩放至宽 1600 | ✅ 无调试 UI / 无文字；四艘舰船编队完整 |
| `base-kit.jpg` | `docs/design/screenshots/kits/kit_base_assembly.png` (1800×980) | 1600×871 | 69.6 KB (q82, ≤260) | 保持原比例，整图缩放至宽 1600 | ✅ 无调试 UI / 无文字；基地建筑群完整，灰底体积小 |
| `ruins.jpg` | `docs/design/screenshots/kits/kit_wreck_three_quarter.png` (900×700) | 900×700 | 16.4 KB (q82, ≤200) | 保持原比例原尺寸（宽 900 ≤1600），仅重编码 | ✅ 无调试 UI / 无文字；沉船残骸完整，暗部未出现色块 |
| `harbor-diorama.jpg` | `docs/design/screenshots/harbor_diorama_schooner.png` (1440×900) | 1440×900 | 115.2 KB (q82, ≤240) | 源图即 16:10，不裁切，仅重编码 | ✅ 无调试 UI / 无文字；夜景帆船与码头完整，月光与水面倒影无明显压缩条纹 |

**合计：14 个文件 / 1,546,939 字节 / 1.48 MB**（单张均低于契约体积上限；总大小为上限 4 MB 的 37%）

## 二、与契约裁切数值的偏差（有依据，已目检确认）

两张带调试 UI 的 1440×900 实机截图，契约给的是起始建议值；按实际像素测量后做了调整，**优先保证「无调试元素 + 无半截文字」**。

### 1. `market-ui.jpg` — 契约「顶部 100 / 底部 72 → 1440×728」→ 实际「顶部 136 / 底部 44 → 1440×720」

- 顶部 HUD 面板实际下沿在 **y≈129–133**（半透明深色条 + 金色描边）。按契约裁 100 px 会水平切断第二行数值（剩余载重 `6.0/100.0`、剩余货舱 `24.0/32.0`、煤炭、淡水、耐久），留下半截数字，故从 **136 px** 起裁，HUD 整条消失。
- 底部「开发团队 · Steam Navigator Team」亮像素自 **y=859** 开始，「版本 · v0.2.0」在其下。裁 44 px（保留到 y=855）可在文字上方留出安全间距，同时保留交易面板下边框；契约的 72 px 亦可行但会少 28 px 画面，故取 44。
- 结果 **1440×720（精确 2:1）**，与契约 728 相差 8 px，构图不变形。

### 2. `shipyard-ui.jpg` — 契约「顶部 100 / 底部 64 → 1440×736」→ 实际「顶部 142 / 底部 44 → 1440×714」

- 顶部主 HUD 实际下沿在 **y≈124–133**。裁 100 px 同样会切断数值行（剩余载重 / 货舱 / 煤炭 / 淡水 / 耐久与「总览 / 市场 / 委托 / 船厂…」按钮文字下半截）。
- 顶部 `y≈145–198` 是游戏内「指引 备齐补给 · 购买 4 单位煤」提示条、`y≈199–241` 是「获得线索：酒馆消息」提示条。取 **142 px** 正好落在 HUD 与提示条之间的空隙：既完整移除调试 HUD，又完整保留这两条**玩法**提示（不属于调试 UI，不切半条）。
  - 说明：任务交接中提示「顶部 chrome 约 180 px」——目检确认 180 px 会切在「指引」提示条内部造成半截文字，故改取 142。
- 底部同 `market-ui`：署名自 y=859 起，裁 44 px 可完全去除并保留面板金边。
- 结果 **1440×714**，与契约 736 相差 22 px。
- 已知残留在源图内、非本次裁切造成：源图右下角一处小面板内有一行只渲染出部分的蓝字 UI 标签（源图自身 UI 裁切，y≈822–830）。本裁切下边界在 y=856，远在该行之下，因此不是裁切残字；若要把它排除需裁到 y≈821，而左侧蓝图面板的金色下边框位于 y≈824–840，会被一并切断，取舍后选择保留完整面板边框。该残留为游戏 UI 自身显示效果，不含调试/开发者信息。

## 三、替代源图

**无。** 契约表格中的 13 个源文件全部存在且可用，未使用替代图。

## 四、验收自检

- 14 个 JPEG 齐全，文件名与契约一致；全部为 **渐进式**（`progressive=True`），均已 `optimize=True`。
- 尺寸复核：1600×900 / 1200×630 / 1440×900×6 / 1440×720 / 1440×714 / 1600×600 / 1600×871 / 900×700。
- 体积复核：单张最大 `hero-main.jpg` 273.8 KB（上限 420 KB）；总 1.48 MB（上限 4 MB）。
- 逐张 `read_image` 目检：主体完整、无调试按钮、无版本号、无开发者署名、无裁切残字、无明显压缩噪点（`shipyard-ui.jpg` 源图固有的一行面板内滚动裁切文字见第二节说明，非本次裁切造成）。
- 写入边界：仅写 `website/assets/img/`；临时脚本与探针图在 `tmp/art-work/`；未改动 HTML / CSS / JS / docs / dev_mods。

## 五、与页面引用的对齐情况（只读核对，未改动页面）

- 站点页面 `<img>` 上写的 `width`/`height` 与本目录产物逐张一致，含 `market-ui.jpg` 1440×720、`shipyard-ui.jpg` 1440×714、`base-kit.jpg` 1600×871、`ruins.jpg` 900×700，不会因尺寸不符产生布局抖动。
- 已确认被引用：`hero-main`、`og-cover`、`port-hero`、`port-terminal`、`ship-schooner`、`ship-ironclad`、`ship-paddle`、`chart`、`market-ui`、`shipyard-ui`、`base-kit`、`ruins`、`harbor-diorama`。
- `combat-lineup.jpg` 已按 §5 生成备用，但当前 5 个页面及其 CSS/JS 中尚无引用；若站点后续未使用该槽位，可忽略此文件。
