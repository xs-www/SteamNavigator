# Fonts

当前不随包分发字体，Godot `SystemFont` 回退到：

- Microsoft YaHei UI / Microsoft YaHei
- Noto Sans CJK SC
- Source Han Sans SC
- SimHei
- Arial

设计 token 目标是 **Noto Serif SC**（标题）与 **Noto Sans SC**（正文）。正式 UI 更新前需要确认字体授权，再把 `.ttf`/`.otf` 放在这里，例如：

```text
assets/fonts/noto_serif_sc/NotoSerifSC-Bold.otf
assets/fonts/noto_sans_sc/NotoSansSC-Regular.otf
```

字体文件不要直接来自系统目录；必须是可再分发的授权副本。
