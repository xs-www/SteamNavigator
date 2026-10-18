# `.design` 美术与交互原型

> 作用：Steam Navigator 的本地美术方向与界面交互验证台。该目录按约定由 `.gitignore` 排除，不进入游戏构建、发行包或源码提交。

## 文件索引

| 文件 | 职责 |
| --- | --- |
| `.design/index.html` | 可点击的全流程界面原型，覆盖主菜单、港口、市场、委托、船厂、补给、情报、出航和抵达结算。 |
| `.design/styles.css` | 蒸汽朋克视觉系统、响应式布局、按钮/卡片/面板状态与环境动效。 |
| `.design/app.js` | 页面淡入淡出、轻量点击音效、交易反馈、委托盖章和出航结算演示。 |
| `.design/tokens.json` | 可映射至 Godot Theme 的颜色、字体、间距、9-slice 与动效令牌。 |
| `.design/assets/main-menu-harbor.png` | 主菜单蒸汽船与港口概念背景。 |
| `.design/assets/iron-harbor-banner.png` | 铁港港口页横幅概念图。 |

## Godot 落地

- `assets/ui/theme/steam_navigator_theme.tres` 是运行时共享 Theme。
- `framework/ui/components/` 提供可拖入场景的语义按钮、面板、徽标、章节标题和资源存量条。
- `framework/ui/showcase/ui_kit_showcase.tscn` 用于独立预览与视觉冒烟。
- 页面先使用 Theme variation 表达公共状态，业务脚本只负责布局和数据绑定。

## 原型契约

- 原型只用于视觉与流程验证，不直接读写游戏状态，也不作为运行时依赖。
- 当前港、已访问港、可航行港、未知港使用形状、颜色和明度三重区分，不能只依赖颜色。
- 抵达采用独立结算页，至少显示收入、奖金、耗时、煤水、耐久和声望变化。

模块索引：[静态代码文档](../static/README.md)
