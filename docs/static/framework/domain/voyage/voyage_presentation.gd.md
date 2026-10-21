# `framework/domain/voyage/voyage_presentation.gd`

> 作用：航行演出（海图系统阶段 3）的**纯状态机**：把一次已经由 `voyage.start`

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `VoyagePresentation` | L1 |
| `SECONDS_PER_GAME_HOUR` | L67 |
| `MIN_PLAYBACK_SECONDS` | L68 |
| `MAX_PLAYBACK_SECONDS` | L69 |
| `VEIL_SECONDS` | L71 |
| `DEPARTURE_3D_SECONDS` | L74 |
| `HARBOR_SECONDS` | L75 |
| `FALLBACK_HOURS` | L77 |
| `DEFAULT_EVENT_PROGRESS` | L79 |
| `CHART_NEAR_SCALE` | L83 |
| `plan(hours: float, event_at: float = -1.0) -> void` | L113 |
| `begin_departure() -> void` | L135 |
| `finish_departure_beat() -> void` | L149 |
| `skip_harbor_beat() -> void` | L157 |
| `resolve_event() -> void` | L165 |
| `begin_event_reveal() -> void` | L174 |
| `force_arrival() -> bool` | L187 |
| `tick(delta: float) -> Step` | L202 |
| `skip() -> Step` | L244 |
| `is_active() -> bool` | L270 |
| `elapsed_hours() -> float` | L275 |
| `remaining_hours() -> float` | L280 |
| `hours_per_second() -> float` | L285 |
| `chart_zoom_scale() -> float` | L294 |
| `is_veiled() -> bool` | L305 |
| `phase_name() -> String` | L309 |
| `snapshot() -> Dictionary` | L314 |
| `sample_polyline(points: PackedVector2Array, t: float) -> Vector2` | L333 |
| `polyline_length(points: PackedVector2Array) -> float` | L351 |
| `unpack_path(flat: Array) -> PackedVector2Array` | L362 |

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
- **海图取景也在模型里**：`chart_zoom_scale()` 与云层同相给出取景倍数（云层刚散开
  时近景，随云层散尽回到 1；入港前反向推近）。阶段 3 验收反馈 F2 要求"镜头还在
  继续上升/下降"，所以不能由 UI 一次性 fit 到位——倍数由本类决定，海图只负责缩放。
- **掉头可以直接入港（4.2）**：`force_arrival()` 允许在途中（`AT_SEA` / 告警决策点 /
  事件云层）把 `progress` 推到 1 并进入与普通抵达相同的 `ARRIVAL_APPROACH →
  ARRIVAL_HARBOR → DONE` 段落；半程返航的领域结算由 `explore.decide(turn_back)`
  负责，状态机只跳过剩余航程。`EVENT_WAIT` 下 `skip()` 仍返回 `NONE`（不能替玩家
  回答告警），因此掉头必须由 Shell 在玩家选择后显式调用。

模块索引：[framework/domain](../README.md)
