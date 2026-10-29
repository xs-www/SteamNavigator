# `framework/ui/screens/menu/main_menu_screen.gd`

> 作用：启动主菜单页面场景：展示启动状态与主入口，并把用户操作转成 Shell 意图。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MainMenuScreen` | L1 |
| `action_requested (signal)` | L28 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L35 |
| `set_update_state(state: Dictionary) -> void` | L95 |

- 关键依赖：`app.view` 启动状态、`SNBadge`、`SNSkin`、纹理化 Theme

## 契约与约束
- bind(vm, translate) 接收状态、本地化和 autosave_available，不访问 AppContext、
  存档服务或场景树退出 API。
- 开始、加载、模组、设置、诊断与退出均发出 action_requested(action, params)，
  由 Shell 执行。
- 加载按钮的禁用状态只由 autosave_available 决定；页面不自行探测文件。
- 页面可重复 bind，每次清理旧节点。

## 皮肤与节点约束（UI 贴图层）
- 主菜单入口列由 `SNCanvasPanel` 纹理承托，顶部状态行用 `SNChromePanel`；
  分割线改用 Theme 的 `HSeparator`（主题铜色细线），不再手搓 ColorRect 色块。
- 按钮文本与顺序不变，图标经 `Button.icon` + Button 的 `icon_max_width` 主题常量
  （20）接外部 skin：开始→nav_departure、加载→nav_chart、模组→status_locked、
  设置→nav_intelligence、退出→status_anchor、诊断→status_warning。
- 文案尺寸保持：入口按钮 360×52 / 17 px、标题 68 px、副标题 16 px、列宽 470、
  左边距 72；测试与截图依赖这些尺寸和按钮文本。
- 颜色统一 `SNSkin.color(token)`：标题 `brass.highlight`、眉题/次要 `text.muted`、
  正文 `text.light`；本页无内联 StyleBox。

模块索引：[framework/ui](../../README.md)
