# UI 场景化迁移规范（Scene-backed UI Migration）

> 契约：把可复用 UI 组件的**静态结构**放进 `.tscn`，把**数据绑定、动态行、自绘**留在 GDScript；
> 按批次迁移、每批用测试 + 截图收口，不追求一次性重写。
> 相关文档：[UI_FOUNDATION_SPEC_V1.md](../design/UI_FOUNDATION_SPEC_V1.md)、[UI_SKIN_PIPELINE.md](../design/UI_SKIN_PIPELINE.md)、
> [UI_PROTOTYPE.md](../design/UI_PROTOTYPE.md)、[HIGH_FREQUENCY_UI_REFACTOR_GUIDE.md](HIGH_FREQUENCY_UI_REFACTOR_GUIDE.md)。

## 1. 现状盘点（2026-10-27）

| 指标 | 数值 | 说明 |
| --- | --- | --- |
| `.tscn` 总数 | 37 | 其中 34 个是 < 600 B 的单节点「挂脚本空壳」 |
| 含真实布局的场景 | 3 | `framework/ui/shell/main.tscn`、`framework/ui/showcase/ui_kit_showcase.tscn`、`dev_scenes/harbor/harbor_diorama.tscn`；其余 `.tscn` 都是单节点壳 |
| `framework/ui` GDScript | 63 文件 / 约 23,600 行 | 页面、组件、Shell 全部在 `_ready()` / `_rebuild()` 里 `add_child(...)` |
| `.new()` 构造点 | 约 631 处 | 组件、页面、容器、标签、按钮均程序化构造 |
| 自绘组件 | 5 | `SNShipView`、`SNSeaChartView`、`SNSparkline`、`SNCloudVeil`、`SNWeaponSocketTarget` |

结论：**是的，除 `main.tscn` 外，悬浮窗（`SNInteractionHint`）、光标幽灵（`SNCarryGhost`）、
出航确认弹窗（`SNVoyageConfirm`）以及所有页面都是纯代码拼装**；现有组件 `.tscn` 只是
「根节点 + 脚本」的空壳，`components/README.md` 里「可拖入场景」的说法对大部分组件名不副实。

历史原因：Shell 在每次命令后整页重建，页面与组件用代码构造更容易跟 ViewModel 数据同步、
也方便无头测试按文字/类型查找节点；皮肤统一走 Theme variation + `SNSkin`，不依赖场景里的美术摆放。
但这些理由只解释了**动态部分**，静态骨架（面板、标题、行布局、按钮排列）没有必须留在代码里的理由。

## 2. 边界：什么进场景，什么留代码

| 内容 | 归属 | 规则 |
| --- | --- | --- |
| 节点层级、容器类型、`separation`、`custom_minimum_size`、对齐/伸展标志、`mouse_filter` | `.tscn` | 设计常量，编辑器内可直接改 |
| 皮肤钩子（`theme_type_variation`、Theme 资源引用） | `.tscn` | 不写 `StyleBoxFlat`、不写十六进制色 |
| 颜色 token（`SNSkin.color(...)`）、克隆并调整的 StyleBox | GDScript | 唯一来源仍是 `SNSkin`；场景里不复制颜色值 |
| 字体大小（`font_size` 覆盖） | `.tscn` | 属于设计常量，不是皮肤 token |
| 数据注入、文本/数值、启用状态、可见性 | GDScript | 公开 API / `bind(...)` 不变 |
| 动态行（估值行、阻断列表、策略选项、仓库列表……） | GDScript | 场景只预留空容器（如 `EstimateBox` / `BlockersBox`） |
| 自绘（`_draw`、线稿、曲线、图形 chip） | GDScript | 不进场景 |
| 页面级布局（整页三栏、抽屉、舞台挂载点） | P3 再评估 | 页面 `bind()` 仍整页重建，先不动页面 |

## 3. 硬性规则

- **R1 场景化组件必须从 `.tscn` 实例化**：`const X_SCENE := preload("res://.../x.tscn")` +
  `X_SCENE.instantiate()`。禁止再 `SCRIPT.new()`（脚本 `.new()` 没有子树，会在 `bind()` 时静默空白）。
- **R2 节点名是契约**：已被测试/Shell 按名字查找的节点（`VoyageConfirm` / `ConfirmPanel` /
  `CancelButton` / `ConfirmButton` / `VoyageConfirm` 的 `ConfirmShade`）不得改名；
  新增结构节点用可读名（`EstimateBox` / `BlockersBox` / `GhostPanel` / `HintPanel`）。
- **R3 脚本延迟解析节点**：`_ready()` 里缓存 `@onready` 引用，同时提供
  `_ensure_refs()`（`get_node_or_null`）给「先 `begin()` 后 `add_child()`」的调用方兜底；
  `bind()` 在节点缺失时安全返回，不崩。
- **R4 皮肤单一来源**：静态骨架用 Theme variation；动态色调（成功/失败/风险/黄铜高亮）继续
  `SNSkin.color()` / `SNSkin.style()` 克隆。场景内允许 Theme 资源引用，不允许裸颜色字面量。
  新场景在根节点挂 `steam_navigator_theme.tres`，保证编辑器内可直接预览。
- **R5 测试不降级**：迁移必须保持现有断言（按文字、按节点名、按类型、鼠标穿透、
  位置钳制、信号）全部通过；新增场景化组件至少补一条「从场景实例化后 bind / 交互」的断言。
- **R6 静态文档**：`.tscn` 用 `docs/static_headers/<路径>.md` sidecar（`作用：...` 开头），
  `.gd` 继续维护 `@static-doc`；改完运行 `node tools/gen_static_docs.mjs`，提交前 `--check`。
- **R7 一批一收口**：每批迁移只碰自己的组件/调用点/测试；全量测试、文档生成、截图验收通过后再进下一批。
  视觉相关批次需要在 Godot 窗口内真实渲染截图（1440×900）复核，不能只靠无头断言。

## 4. 分批计划

### P0（本批，已完成）

| 组件 | 类型 | 场景化内容 | 保留在代码里 |
| --- | --- | --- | --- |
| `SNInteractionHint` | Shell 浮层（交互处提示） | `HintPanel` / `HintRow` / `Icon` / `Message` 布局、字号、鼠标穿透 | 成功/失败色调、图标、`place_at()` 钳制、淡出 Tween |
| `SNCarryGhost` | Shell 浮层（光标幽灵） | `GhostPanel` / `GhostRow` / `Icon` / 标题·数量·消费·提示四行 | 黄铜色调、图标/数量/消费文本、`place_at()` 钳制、跟随鼠标 |
| `SNVoyageConfirm` | 海图内出航确认弹窗 | 遮罩 / 居中容器 / 钢框面板 / 标题 / 副标题 / 估值容器 / 策略行 / 阻断容器 / 提示 / 取消·启航按钮 | 估值行、策略选项填充、阻断文案、风险色、按钮状态、信号 |

调用点：`framework/ui/shell/main.gd`（hint / ghost 懒创建）、`framework/ui/screens/flow/sea_chart_screen.gd`（弹窗 `_add_confirm_overlay`）。
测试：`test_ui_shell`（hint / ghost）、`test_sea_chart` + `test_ui_shell`（弹窗契约）。

### P1（下一批，待做）

基础复合控件，收益最高（编辑器里直接调布局，调用点最多）：
`SNSectionHeader`、`SNPartRow`、`SNResourceMeter`、`SNBadge`、`SNButton`、`SNPanel`、`SNSupplyCard`。
这些已有空壳 `.tscn`，把 `_build()` 的静态层级搬进去即可；按钮/徽标的语义 variant 继续由脚本
`variant` / `theme_type_variation` 控制。注意 `SNSupplyCard` 有公开 `bind()` 契约与测试。

### P2（再下一批）

卡片/列表类：`SNTaskTracker`、`SNStoryCard`、`SNStoryObjective`、`SNFocusOverlay`、
`SNWeaponRow`、`SNWeaponSocketCard`、`SNCargoHoldPanel`、`SNItemTile`。
其中 `SNItemTile` 的角标/数量行为与市场测试绑定，迁移前先补「场景实例化」回归。

### P3（最后）

页面壳：`screens/**/*.tscn` 从单节点空壳升级为「页面骨架（顶栏/滚动区/侧栏锚点）」，
`_rebuild()` 只重建动态 body。这一步改动面最大，必须等 P1/P2 的场景契约稳定后再评估。

### 不迁移

`SNShipView`、`SNSeaChartView`、`SNSparkline`、`SNCloudVeil`、`SNWeaponSocketTarget`（自绘优先）；
`SNCarryGhost` / `SNInteractionHint` 的淡出与钳制逻辑（动态）。

## 5. 验收门禁（每批）

```powershell
$env:GODOT_BIN = "C:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
pwsh ./tools/test.ps1 -Summary          # 全量
node tools/gen_static_docs.mjs          # 生成静态文档
node tools/gen_static_docs.mjs --check  # 提交前
node tools/check_content_schema_v2.mjs  # 内容基线（改到内容时）
```

视觉相关批次追加：Godot 窗口内挂真实 `main.tscn` 截图，确认组件在新场景结构下与迁移前一致
（或按设计更新），截图保存在 `docs/design/screenshots/`（本地验收产物，按需入库）。

## 6. 回退

- 每批改动自成一体：场景文件 + 脚本 + 调用点 + 测试；出问题时整体回退该批，不影响其他批次。
- 场景化组件保留原公开 API / 信号 / 节点名，回退时调用点只需恢复 `preload(.gd).new()`。
