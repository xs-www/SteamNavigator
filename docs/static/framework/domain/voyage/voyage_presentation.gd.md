# `framework/domain/voyage/voyage_presentation.gd`

> 作用：航行演出（海图系统阶段 3）的**纯状态机**：把一次已经由 `voyage.start`

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `VoyagePresentation` | L1 |
| `SECONDS_PER_GAME_HOUR` | L59 |
| `MIN_PLAYBACK_SECONDS` | L60 |
| `MAX_PLAYBACK_SECONDS` | L61 |
| `VEIL_SECONDS` | L63 |
| `DEPARTURE_3D_SECONDS` | L66 |
| `HARBOR_SECONDS` | L67 |
| `FALLBACK_HOURS` | L69 |
| `DEFAULT_EVENT_PROGRESS` | L71 |
| `plan(hours: float, event_at: float = -1.0) -> void` | L101 |
| `begin_departure() -> void` | L123 |
| `finish_departure_beat() -> void` | L137 |
| `skip_harbor_beat() -> void` | L145 |
| `resolve_event() -> void` | L153 |
| `begin_event_reveal() -> void` | L162 |
| `tick(delta: float) -> Step` | L169 |
| `skip() -> Step` | L211 |
| `is_active() -> bool` | L237 |
| `elapsed_hours() -> float` | L242 |
| `remaining_hours() -> float` | L247 |
| `hours_per_second() -> float` | L252 |
| `is_veiled() -> bool` | L258 |
| `phase_name() -> String` | L262 |
| `snapshot() -> Dictionary` | L267 |
| `sample_polyline(points: PackedVector2Array, t: float) -> Vector2` | L285 |
| `polyline_length(points: PackedVector2Array) -> float` | L303 |
| `unpack_path(flat: Array) -> PackedVector2Array` | L311 |

结算的航行，在界面上依次演成「出航云层 → 海图航行（时间加速）→ 事件中断 →
抵达云层」。它不碰 `GameState`、不碰节点树，只输出阶段、进度和里程碑，
因此可以在无头测试里逐帧推进。

## 契约与约束
- **只做表现，不改规则**：航行结果（是否抵达、事件、结算）由 `VoyageService`
  决定；本类只决定「什么时候把哪个画面推到玩家面前」。领域数值一行不改。
- **阶段不可跳跃**：`plan()` → `begin_departure()` → 云层盖满后自动进 `AT_SEA`
  → 事件点/终点各自先盖云层再交界面。所有转移集中在本类，Shell 只按 `Step`
  换页，避免演出顺序散落在 UI 里。
- **时间加速可解释**：整段航程压缩成 `MIN_PLAYBACK_SECONDS..MAX_PLAYBACK_SECONDS`
  的实时时长，`hours_per_second` 就是界面上要显示的倍率；游戏时间本身不加速，
  它已经由 `voyage.start` 一次性推进。
- **跳过不等于替玩家做决定**：`skip()` 只跳过航行过程；未处理的事件仍然会被
  推到玩家面前（决策不能替玩家做）。

模块索引：[framework/domain](../README.md)
