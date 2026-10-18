# Audio Assets

```text
assets/audio/
  music/                 环境音乐
  sfx/
    ui/                  按钮、翻页、提示
    economy/             买卖、金币、合同
```

当前资产：

- `sfx/economy/pickup_gold_00.wav` — 购买/拾取金币。建议作为买入、卖出、委托奖励的短音效。

约定：

- 文件名 `snake_case`，不用空格。
- UI 音效默认单声道/短时长；环境音乐可用 OGG。
- 用 `AudioStreamPlayer` / `AudioStreamPlayer2D` 加载；音量走 Audio Bus，不把音量烘焙进文件。
- 来源和授权记录在 `assets/audio/SOURCES.md`。
