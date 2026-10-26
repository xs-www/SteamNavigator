# Steam Navigator 透明 UI Icons V1

![图标图集](sn_ui_icons_v1.png)

本批使用内置 imagegen，参考 SN Visual Baseline V1 与透明控件图集生成。共 30 枚无字图标，保持统一的粗墨线、手绘材质、旧黄铜和港务色彩。背景为真实 Alpha 透明。

> 图集实际画了 31 枚（第 3 行多出 1 枚交叉工具），声明的 30 枚按顺序绑定；多出的那枚记录在 `manifest.json` 的 `unmapped`，暂不生成独立文件。

## 文件

- `sn_ui_icons_v1.png`：1536×1024 图集（5 行；除第 3 行 7 枚外每行 6 枚）。
- `icons/*.png`：30 枚独立 PNG；每张 256×256 透明画布，图标按原像素尺寸居中（不缩放、不变形）。
- `manifest.json`：每枚图标的内容包围盒 `atlas_region`、行带与检测到的每行列数、未映射图标、复用别名。
- `PROMPT.md`：完整生成提示词。

## 图标顺序

| 行 | 从左到右 |
| --- | --- |
| 1 | 市场、委托、船厂、补给、情报、海图 |
| 2 | 出航、煤炭、淡水、耐久、货物、金币 |
| 3 | 船体、锅炉、货舱、导航、安全、客舱（图集此行为 7 枚，第 7 枚交叉工具未映射） |
| 4 | 增加、减少、确认、警告、锁定、解锁 |
| 5 | 锚点、时间、普通海况、风暴、声望、航线 |

船厂“杂项”复用 `nav_shipyard` 的交叉工具图标；货币复用 `resource_coins`。

## 重新切片

图集是生成式出图，行高不是整数等分、每行列数也不完全相等，**不能再用固定等宽/等高网格裁切**（旧版就是这样把下一行图标顶端裁进了每张 PNG 的底部）。切片统一走脚本：

```powershell
# 先 dry-run 看检测到的行带、每行列数与包围盒（不写文件）
godot --headless --path . --script res://tools/ui/slice_ui_icons.gd -- --dry-run
# 写 icons/*.png 与 manifest.json
godot --headless --path . --script res://tools/ui/slice_ui_icons.gd
# 再从母版生成 128×128 运行图标 / Theme
pwsh ./tools/build_ui_skin.ps1
```

切片规则：先用「全透明行/列」把图集分成图标格，再取每格 alpha>24 内容的紧包围盒（外扩 6 px 保留发光），居中放进 256×256 透明画布；图标顺序与命名取 `manifest.json` 的 `assets[].id`。源图集保持不变，同一输入重跑逐字节一致。

## 使用建议

- 常规 HUD/按钮显示为 24–32 逻辑像素；主导航可显示为 32–40。
- 独立 PNG 保留统一画布，不会因状态切换改变布局。用 TextureRect 的 `KEEP_ASPECT_CENTERED` 显示。
- 图标本体已经带墨线和材质色，不额外套统一 Tint；禁用态可在 Theme 中降低饱和度与亮度。
- Focus、Selected、Danger 等状态由底板、焦点框或状态覆盖层表达，不复制一套图标颜色。
- 图标不包含文字或底板，可叠加到黄铜钢板、布旗、羊皮纸和蓝图控件。
- 缩到 20 px 以下会丢失手绘细节，最小推荐显示尺寸为 24 px。

图标语义和实际按钮状态需在 Godot 页面中验收；运行纹理由 `tools/build_ui_skin.ps1` 生成，`-Check` 通过后再提交。
