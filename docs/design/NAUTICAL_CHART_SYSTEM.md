# Steam Navigator — 航海图系统（Nautical Chart System）

> 正式版核心系统：坐标空间世界、三重迷雾、渐进式探索、事件化海洋。
> 本文档取代 MVP 时期的抽象图模型（`MapGenerator` 4-5 港口全连接图），作为正式版海图的唯一真源。
> 状态：**设计冻结 v1.0** — 阶段 0（世界生成器）、阶段 1（迷雾系统）、阶段 2（海图 UI 核心组件与查询层，
> 含真实渲染视觉验收、Shell 入口接线与航程预估）已实现；阶段 3（航行演出状态机）**已落地第一切片**：
> 状态机、云层转场、海图船只沿贝塞尔路径行进与时间加速、事件中断、抵达结算、**3D 离港/入港镜头升降**（见 §8.2）。

## 1. 愿景与世界观约束

世界被未知力量笼罩，海中存在无尽未知。只有沿岸区域是固定不变的，海况随时变动：海盗、海怪、随机移动岛屿秘境、未标明固定岛屿。玩家的海图只能显示已知的岛屿与沿岸港口，海洋被不同等级的迷雾笼罩。

由此导出的设计原则：

- **信息是稀缺资源**：探索本身就是玩法，不是「开局全图可见」的观光。
- **海洋 = 随机副本**：每次航行经过的海域都可能遇到新事件，离开后一切重归迷雾。
- **沿岸 = 稳定世界**：港口一旦被发现就永久标注在海图上，是玩家的锚点。
- **同 seed 可复现**：世界生成、迷雾分布、事件生成全部走 `RngService` 命名流。

## 2. 世界数据模型

```text
WorldMap (一次性生成，seed 可复现)
├── bounds: Rect2                          # 世界坐标范围
├── landmasses[]                           # 陆地/岛屿
│   ├── id: str
│   ├── polygon: PackedVector2Array        # 轮廓多边形（程序生成）
│   ├── archetype: continent / large_island / small_island / atoll
│   └── region_id: str
├── coastlines[]                           # 海岸线折线（从 landmass 提取）
├── regions[]                              # 行政区域
│   ├── id: str, name_key: str
│   ├── tier: coastal / oceanic
│   └── landmass_ids[]
├── ports[]                                # 港口（锚定在陆地海岸线上）
│   ├── id: str, position: Vector2
│   ├── region_id: str
│   ├── archetype: str, size: int, facilities[]
│   ├── diorama: {}
│   ├── departure_angle: float             # 唯一出航角度（贝塞尔切线）
│   ├── is_start_port: bool
│   └── landmass_id: str
├── fixed_unknown_islands[]                # 固定未知岛屿（中后期基地建设目标）
│   ├── id: str, position: Vector2
│   ├── resources[]: (勘探后才发现)
│   └── capacity: int (可建设施上限)
├── fog_grid                               # 战争迷雾网格
│   ├── cell_size: float
│   └── cells[][]: { state, alpha }
└── connectivity_graph                     # 港口连通图
    └── edges[]: { from, to, bezier_path[], distance, travel_hours }
```

### 2.1 陆地生成

候选算法（按 archetype）：

- **大陆（continent）**：Perlin/Simplex 噪声 → 阈值裁剪 → 多边形提取 → Douglas-Peucker 简化；贴世界边缘生成。
- **大岛（large_island）**：Voronoi cell + 噪声扰动边缘；半径 15-25 单位。
- **小岛（small_island）**：同上但更小；半径 4-8 单位。
- **环礁（atoll）**：环形 Voronoi + 内部挖空；半径 2-4 单位。

**生成约束**：
- 港口必须锚定在海岸线上（不在海洋上）
- 同一区域内港口间有最小间距（避免过密）
- 跨区域港口距离更远，航线穿过开放海域
- 造船厂和情报站保证在起始区域 2 条边内（保留 MVP 约束）
- 陆地总面积占世界约 15-25%

### 2.2 规模

- 单局 15-20 个港口
- 世界一次性生成，不分块加载
- 后续通过扩大世界尺寸支持更大地图
- 初始建议尺寸 400×400 单位

**实现与验收口径**（`framework/domain/world/world_generator.gd`）：

- `WorldGenerator.MIN_PORTS = 15` / `MAX_PORTS = 20` 是冻结常量，`_validate_world`
  缺省即按这对边界校验；profile 可用 `min_ports` / `max_ports` 显式覆盖（真实对局的
  孪生世界按抽象地图港口数传值，是另一条路径）。
- 港口数不足时生成直接失败（`too few ports: N < 15`），不会静默返回一张小图。
  失败信息直接回传最后一次尝试的原因（不再吞成「failed after 60 attempts」），
  验收时能一眼看出是卡在哪条约束上。
- 正式 profile：`WorldGenerator.formal_profile(definition)` 把内容层 `map_profiles`
  定义（`port_count_range` / `archetypes` / `port_name_keys` / `required_facility_tags`）
  展开成生成器 profile——5 个区域（起始沿岸 / 中部沿岸 ×2 / 远洋 / 外洋）、11 块陆地
  （1 块大陆 + 5 块大岛 + 3 块小岛 + 2 座环礁）、按 `FORMAL_PORT_SLOTS` 排好的港口槽位
  （起始大陆 6 港、大岛 2–3 港、小岛与环礁各 1 港）。槽位而不是「随机撒点」是刻意的：
  小岛周长放不下第二个港湾，随机撒点会一直撞最小间距。
- 验收用例 `test_formal_profile_matches_design_bounds`：用 `[15, 20]` 的 profile
  真的生成一张世界，断言港口数 = 15、全部锚定海岸线（< 2 单位）、陆地占比 < 0.45。
  配套 `test_world_below_port_floor_is_rejected` 断言 10 港的世界必须被拒。

> 边界：当前 MVP 的可玩地图仍走 `MapGenerator` 的 4–5 港分支网络（`core:map_profile/standard`），
> 不经过 `WorldGenerator` 的 15 港下限；坐标空间世界（正式版口径 + 现有对局的孪生世界）
> 才走这条校验。真实 run 直接跑 15–20 港的坐标空间世界属于阶段 3 之后的接入工作，见 `todo.md`。

### 2.3 区域分层

| 区域类型 | 数量 | 港口数 | 特征 |
|---|---|---|---|
| 起始沿岸区 | 1 | 4-5 | 密集、安全、低利润 |
| 中间沿岸区 | 2-3 | 2-3/区 | 中等距离、中等利润 |
| 远洋区 | 1-2 | 1-2/区 | 远距离、高风险高回报 |
| 隐藏/未知 | - | 3-5 | 只能通过探索发现 |

## 3. 三重迷雾系统

### 3.1 状态定义

| 状态 | 海图表现 | 触发条件 | 持久性 |
|---|---|---|---|
| **黑雾（black）** | 完全不透明深色 | 默认 / 海洋离开后 | 直到被探索 |
| **灰雾（explored）** | 半透明，能看到陆地轮廓但暗淡 | 仅用于沿岸（被船只经过后） | 永久保留 |
| **可见（visible）** | 全亮 | 当前航行中的船只视野内 | 实时，船离开后降回黑雾或保留灰雾 |

### 3.2 沿岸 vs 海洋的不同规则

- **沿岸格子**（距海岸线 N 个格子内）：首次被船只经过后永久保留为**灰雾**（能看到陆地轮廓但不知道实时情况）；当前船只在附近时升级为**可见**。
- **海洋格子**：船只离开后**直接变回黑雾**，不保留任何痕迹。每次航行经过的海域都是「新副本」。

### 3.3 港口揭示（路灯花效应）

港口首次被发现时，以港口为中心半径 `port_reveal_radius` 的格子永久清除战争迷雾（变为灰雾）。这给了玩家「我来过这里」的成就感。

### 3.4 网格粒度

```text
cell_size = min_vision_radius / 4
```

迷雾分辨率始终比最小视野细一个量级，避免「一格迷雾比船看到的还大」的违和感。

### 3.5 视觉实现

- 战争迷雾 = 一层覆盖在 2D 海图上的 shader/material
- 每个格子一个 alpha 值，格子间 alpha 插值平滑过渡
- 沿岸发光 = 仅在可见态（visible）时显示，不是 shader 发光，只是无迷雾显得「亮」
- 陆地轮廓由程序生成的多边形渲染，先做轮廓剪影（纯色），后续可升级为手绘风格

## 4. 航线系统

### 4.1 Route 数据结构

```text
Route (航线 = 两个港口之间的可航行路径)
├── from_port_id, to_port_id
├── bezier_path: PackedVector2Array        # 贝塞尔曲线路径
├── distance: float                        # 路径总长度
├── travel_hours: float                    # 按船速计算
├── risk_level: float                      # 基础风险等级（离岸距离相关）
└── is_explored: bool                      # 是否已被玩家走过
```

**实现状态**：`WorldMap.edges[]` 已落地（world schema 1.1），每条连通边在**生成期**
算好 `{from, to, distance, path}` 并随世界存档；查询与 UI 只读该表。
`path` 以扁平整数组（`[x0,y0,x1,y1,…]`，坐标保留 2 位小数）存储以压小存档。

`travel_hours` / `risk_level` **不进世界表**（它们是船况与航行规则的函数，同一张世界表
配不同船会得出不同值），改由查询层 `VoyageEstimator` 在 `sea_chart.view` 输出时推导：
`duration = distance / (船速 × 策略 speed_mul × 载重系数)`，煤/水消耗与风险档位与
`VoyageCalculator.preview` 用同一套常量与同一套钳位，因此海图面板与出航预览不会给出
两个数字。距离取抽象地图航线距离（`distance_source="voyage"`）；孪生世界 MST 图上
不存在对应抽象边时退回海图距离，并把风险标记为未知（`risk_level = -1`）而不是 0。

> 换航线算法的约定：算法只在**生成期写入**这一张表。只要
> `{from, to, distance, path}` 契约不变，海图查询、渲染与将来的航行演出都不需要改；
> 缺 `edges` 的旧存档由消费方回退现场计算（`sea_chart.view` 的 `_compute_routes`）。

### 4.2 路径计算

- 每港口有唯一出航角度（`departure_angle`）：贝塞尔曲线的起点切线
- 起点切线从港口邻居组中心计算（MVP 已有逻辑，扩展到坐标空间）
- 路径绕开陆地（A* 或 visibility graph）
- 连通图在世界生成时预计算，运行时查表

### 4.3 「航线」语义澄清

严格来说不存在「航线」这个实体——玩家只是「知道这两个港口是连通的」。海图演出需要一条可视化路径让船舶 icon 沿之移动，这就是 `Route.bezier_path`。已探索的港口之间总是可以安全往返（玩家已知道路），未探索区域仍充满风险。

## 5. 探索系统

### 5.1 探索命令流程

```text
玩家选择线索 → 发起 explore_voyage.start(clue_id)
  → 按线索方向 + 距离 + 可信度计算目标搜索区
  → 生成探索路径（从当前港出发，向目标区）
  → 预计算航行事件（命名流，seed 可复现）
  → 进入航行演出
  → 进入搜索区后按 credibility 判定发现
  → 发现 → 解锁港口 → 战争迷雾清除 → 港口加入已知列表
  → 未发现 → 见 §5.3 探索失败处理
```

### 5.2 探索演出差异

| | 已知港口航行 | 探索未知航行 |
|---|---|---|
| 路径 | 确定贝塞尔曲线 | 向大致方向延伸 |
| 终点 | 明确港口图标 | 虚线圈/问号 |
| 云层/氛围 | 常规 | 更暗，暗示风险 |
| 掉头 | 不允许（常规航行不允许反悔） | 特定时间点可选择掉头 |

### 5.3 探索失败处理

- 资源告急事件（见 §6.2）触发掉头选项
- 主动选择消耗大量物资+耐久，漂到最近港口（允许未知，直接发现并解锁）
- 漂流到的港口未来可能无法维修（边界情况：如果维修绑定到设施，而该港口没有维修设施）
- 线索标记为 `failed`，不删除（玩家知道这条路没东西）

### 5.4 探索航行中的掉头

仅在特定时间点允许：
- 探索航行资源消耗 50% 时触发「资源告急」事件
- 此时玩家可选择：继续探索 / 掉头回最近已知港口
- 正常港口间移动**不允许反悔**

## 6. 事件系统

### 6.1 事件类型

| 类型 | 描述 | 是否真实地图位置 |
|---|---|---|
| 敌对事件 | 海盗、海怪 | 否，触发时临时生成 |
| 环境事件 | 风暴、浓雾 | 否 |
| 奖励事件 | 漂流物资、遇难船只 | 否 |
| 随机岛屿秘境 | 临时出现的秘境入口 | **否**，事件不是真实位置 |
| 固定未知岛屿 | 基地建设目标 | **是**，真实地图实体 |
| 安全航行 | 什么都没发生 | 否 |

### 6.2 资源告急事件

探索航行中，某航行必备资源（煤/水/耐久）较出发前消耗一半时触发一次。玩家可选择继续或掉头。

### 6.3 事件预加载

- 事件在出航前全部确定（命名流 + seed 可复现）
- 玩家不知道具体事件列表
- 出航前生成事件遇见时间表，并预加载场景
- 触发事件时镜头从云层快速下降到 3D 场景（场景已就绪）

## 7. 线索系统

### 7.1 线索数据结构

```text
Clue
├── id: str, source_key: str, source_display_key: str
├── clue_type: port_location / port_goods
├── target_port_id: str? (港口类)
├── target_goods_id: str? (货物类)
├── revealed_info:
│   ├── exists: bool
│   ├── direction: enum (8 方位)
│   ├── distance_range: [min_days, max_days]
│   ├── name_key: str?
│   └── goods_info: {}?
├── credibility: float (0-1, 不直接显示，通过来源暗示)
├── is_permanent: bool (港口位置 = 永久，货物 = 有时效)
├── expires_at: game_hour?
├── investigation_cost: {} (金币/时间/委托)
└── is_investigated: bool
```

### 7.2 线索分级与海图表现

| 线索等级 | 披露内容 | 海图表现 |
|---|---|---|
| 1 - 存在港口 | 「xx 方向好像有港口」 | **仅在线索 UI 中显示**，海图上无标记 |
| 2 - 方向 | 「xx 港以东」 | 参照港口旁出现方向箭头 |
| 3 - 距离 | 「约 3 天航程」 | 在预计位置画一个虚线圆圈 |
| 4 - 名称 | 「那是自由镇」 | 圆圈内显示 `？港口名？` |

### 7.3 来源与可信度

- 可信度不直接显示在线索中
- 通过 `source_display_key` 暗示（「铁港酒馆老板」vs 「陌生水手」）
- 海盗/不可靠来源给的线索可信度低

### 7.4 调查方式

- 花金币在酒馆买情报
- 花时间在港等待消息
- 完成特定委托后解锁
- 以上都有，按线索类型和稀有度不同

### 7.5 时效性

- 港口位置类线索：**无时效**（港口坐标不变）
- 港口货物/市场类线索：**有时效**（`expires_at`）

## 8. 航行演出

### 8.1 状态机

```text
InPort
  → OpenSeaChart (按 M / 准备出航按钮打开海图)
  → VoyagePlanned (选择目的地/线索，右侧 Panel 显示预计信息)
  → Departure (3D → 云层上升 → 2D 海图视角)
  → AtSea (船舶 icon 沿路径移动，时间加速流逝)
    ├→ EventTriggered (云层下降 → 3D 场景 → 事件决策 → 回到 AtSea)
    ├→ ExplorationFound (发现港口 → 解锁 → 继续或入港)
    ├→ ResourceAlert (资源告急事件 → 选择继续/掉头)
    └→ Arrived (云层下降 → 3D 入港场景)
```

**实现状态（阶段 3 第一切片）**：状态机是纯模型
[`VoyagePresentation`](../static/framework/domain/voyage/voyage_presentation.gd.md)，不碰
`GameState`、不碰节点树，因此可以在无头测试里逐帧推进。相位与上图的对应关系：

| 设计相位 | 实现相位 | 界面 |
|---|---|---|
| VoyagePlanned | `VOYAGE_PLANNED` | 出航页确认锅炉策略 |
| Departure | `DEPARTURE_3D` → `DEPARTURE_VEIL` | **3D 离港：船驶离泊位、镜头升到高位**，云层再盖住高位镜头 |
| — | `AT_SEA` | 海图页 + 船只沿贝塞尔折线行进 + 航程条 |
| EventTriggered | `EVENT_APPROACH` → `EVENT_WAIT` → `EVENT_RESUME` | 云层落下 → 事件选项 → 云层重新盖住后回到海图 |
| Arrived | `ARRIVAL_APPROACH` → `ARRIVAL_HARBOR` | 云层盖住海图 → **3D 入港：镜头从高位下降、船从海门驶入泊位**（云层同时散开） |
| — | `DONE` | 抵达结算页 |

**关键取舍**：`voyage.start` 仍然一次性结算航行（含事件抽取与抵达结算），演出层只决定
「什么时候把哪个画面推到玩家面前」。这样阶段 3 不需要改动任何领域规则与存档格式，
旧存档、9 seed 通关回归、`at_sea` 语义全部保持不变；代价是演出期间领域状态已经是
"已抵达"，所以顶栏与海图的"当前港"由 Shell 用出发港覆盖（见 `_rebuild_ui`）。

**时间加速**：整段航程压缩到 `MIN_PLAYBACK_SECONDS..MAX_PLAYBACK_SECONDS`（2–9 s），
`hours_per_second` 就是航程条上显示的倍率；游戏时间本身不加速，它已经由
`voyage.start` 推进。跳过演出（`skip()`）不替玩家做事件决策：未处理的事件仍会推到
玩家面前。

### 8.2 镜头过渡

- 港口内：3D 场景（`PortStage`）
- 按 M 或「准备出航」：打开 2D 海图
- 选择目的地后：右侧展开 Panel 显示目的地基础信息 + 预计时间/消耗/风险
- 确认出航：镜头回到 3D → 船只向海域行动 → 镜头逐渐上升穿过云层遮罩 → 2D 海图视角
- 航行中：icon 在海上移动，时间加速流逝
- 触发事件：镜头从云层快速下降到 3D 场景 → 事件决策 → 回到 2D 海图
- 抵达目的地：镜头下降穿过云层 → 3D 入港场景

**实现状态**：云层遮罩已落地（`SNCloudVeil`，程序化软边云团，三档深浅 + 穿越漂移，
`cover` 由状态机逐帧驱动），出航 / 事件 / 抵达三处都用它做"盖住 → 换页 → 散开"。

**3D 镜头升降已落地**（`PortStage.begin_departure()` / `begin_arrival()` / `advance_voyage()`）：

| 动作 | 3D 表现 | 接缝 |
|---|---|---|
| 离港 | 船从泊位驶向 `SEA_HANDOFF`（港外海面），镜头同时从站位机位升到 `DEPART_CAMERA` 高位广角 | 高位镜头被云层盖满后才切海图 |
| 入港 | 目的港先以高位「从海上来」的机位出现，镜头下降回站位机位，船从 `SEA_HANDOFF` 驶入泊位 | 云层在下降过程中散开，演完才切结算页 |

**「船消失的地方 = 海图船标志的位置」的做法**：两端共用一个具名交接点。3D 船在
`PortStage.SEA_HANDOFF` 停住的那一刻，海图船标记从 `VoyagePresentation.handoff_progress`
（默认 0，即出发港的港口图标）开始 —— 3D 船就是从这个港口驶出去的，所以两边是同一个
地理位置。`test_chart_ship_starts_where_the_stage_ship_vanished` 同时断言 3D 船确实停在
`SEA_HANDOFF`、以及海图接管第一帧的船标记坐标等于出发港在航线上的起点坐标。
状态机与 3D 动画共用一个 beat 长度（`VoyagePresentation.DEPARTURE_3D_SECONDS ==
PortStage.VOYAGE_BEAT_SECONDS`，有测试守护），云层才不会在镜头还在动时就盖下来。

**剩余项（下一切片）**：
- 事件触发时的 3D 场景与云层下降（当前事件页仍是 2D 页面，只有 2D 云层转场）。
- `ExplorationFound` / `ResourceAlert` 分支属于阶段 4 与阶段 5，未实现。

### 8.3 玩家限制

- 航行中不能主动改变方向
- 仅在事件决策点（如资源告急）才能掉头
- 正常港口间移动不允许反悔

## 9. 海图 UI

### 9.1 单视图连续缩放

- 不分区域/世界双视图
- 一个连续可缩放的区域
- 鼠标滚轮缩放，拖拽平移

### 9.2 信息层级

海图上显示：
- 已知港口图标 + 名称
- 已探索的陆地轮廓（灰雾态也可见）
- 当前船只位置（仅在航行中显示）
- 线索可视化（按 §7.2 分级显示）
- 战争迷雾（黑雾/灰雾/可见三态）

不显示：
- 海洋实时信息（事件、NPC 位置）
- 未探索海域的任何信息

### 9.3 入口

- 在港口默认不打开海图
- 按 M 键或点击「准备出航」按钮打开
- 在海图上选择目的地
- 选择后右侧展开 Panel 显示目的地基础信息 + 预计信息
- 确认出航后镜头回到 3D 场景开始演出

**实现状态**：`M` 键、顶部导航「海图」、出航页「打开海图 (M)」三个入口已接线
（`framework/ui/shell/main.gd` + `framework/ui/screens/flow/sea_chart_screen.tscn`）。
面板「启航」冒泡为 `voyage_requested(port_id)`，Shell 跳到出航页并预选目的港；
真正的 `voyage.start` 仍在出航页确认锅炉策略后发出。
「确认出航后镜头回到 3D 场景」属于阶段 3 的镜头过渡，尚未实现。

## 10. 与现有系统的集成

### 10.1 复用现有基础设施

| 现有系统 | 海图系统复用方式 |
|---|---|
| `RngService` 命名流 | 世界生成、迷雾分布、事件生成全部走命名流，保证同 seed 可复现 |
| `CommandBus` / `QueryBus` | 探索、发现港口、解锁航线都走命令/查询总线 |
| `CampaignState.world` 分区 | 存储已探索港口、已固定航线、迷雾状态、发现事件 |
| `IntelService` | 扩展线索类型，`intel.view` 输出线索列表 |
| `VoyageCalculator` / `VoyageService` | 扩展为支持贝塞尔路径与事件化海洋 |
| `PortStage` | 入港/出港 3D 场景继续复用 |
| `SNStageHost` | 海图 2D 舞台复用通用宿主机制 |

### 10.2 替换现有系统

- `MapGenerator`：从抽象图模型升级为坐标空间世界生成器
- `MapView`：从全连接图查询升级为海图查询（迷雾状态 + 已知港口）
- 航行状态机：从「瞬间完成」升级为演出化状态机

### 10.3 GameState 新增字段

```text
GameState
├── campaign.world (已有分区，扩展)
│   ├── world_seed: int
│   ├── discovered_ports: Set[port_id]
│   ├── discovered_islands: Set[island_id]
│   ├── explored_coast_cells: Set[(gx, gy)]
│   └── known_connectivity: Set[(from, to)]
├── data (新增)
│   ├── active_clues: Clue[]
│   ├── failed_clues: Set[clue_id]
│   └── voyage_events: VoyageEvent[] (当前航行的事件列表)
```

## 11. 开发阶段规划

### 阶段 0：数据模型与生成器

- `WorldMap` / `Landmass` / `Port` 数据结构
- 程序化陆地生成器（continent / large_island / small_island / atoll）
- 港口锚定算法（海岸线 + 最小间距）
- 连通图预计算（A* 绕开陆地）
- 贝塞尔航线生成（每港口唯一出航角度）
- 同 seed 可复现性测试

### 阶段 1：迷雾网格

- `FogGrid` 数据结构（cell_size = min_vision / 4）
- 三重状态机（black / explored / visible）
- 沿岸 vs 海洋不同规则
- 港口揭示（路灯花效应）
- 迷雾 shader（格子 alpha 插值平滑）
- 陆地轮廓渲染（剪影优先）

### 阶段 2：海图 UI

- 连续可缩放 2D 视图（`SNSeaChartView`）
- 信息层级（港口/陆地/船只/线索）
- 右侧 Panel（目的地信息 + 预计信息）
- 入口（M 键 / 准备出航按钮）

实现状态：视图 / 信息层级 / 右侧面板 / `sea_chart.view` 查询**已落地**；
入口（`M` 键、顶部导航「海图」、出航页「打开海图」）已在阶段 2 补完并接进 Shell。
线索可视化未做（线索依赖阶段 4）。视觉验收见 §14。

右侧面板的航程信息包括：距离、预计时间、煤/水预计消耗（需求 / 存量）、风险档位、
是否已探索航线。所有数值来自查询层，面板只负责渲染（详见 §4.1）。

### 阶段 3：航行演出状态机

- 状态机实现（InPort → OpenSeaChart → VoyagePlanned → Departure → AtSea → Arrived）
- 镜头过渡（3D ↔ 云层 ↔ 2D）
- 船舶 icon 沿贝塞尔路径移动
- 时间加速流逝
- 事件触发（云层下降 → 3D 场景）

实现状态（第一切片已落地）：
- `VoyagePresentation`（纯模型，`framework/domain/voyage/voyage_presentation.gd`）：11 个相位 + 5 个
  里程碑，逐帧 `tick()` 推进，云层与航程进度都在模型里算。
- `SNCloudVeil`（`framework/ui/components/sn_cloud_veil.gd`）：程序化软边云团全屏转场层，
  只渲染 `cover`，不做时序。
- `AtSeaScreen` 重写为演出页：整幅海图 + 船只 icon（`SNSeaChartView.set_ship_position()` 逐帧覆盖）
  + 底部航程条（起终港 / 进度 / 航程小时 / 时间倍率 / 跳过演出）。
- `PortStage` 新增 3D 离港 / 入港 beat：`begin_departure()` / `begin_arrival()` / `advance_voyage()`
  （船驶离/驶入 + 镜头升降，可被 Shell 与测试逐帧步进），交接点 `SEA_HANDOFF` 与海图的
  `handoff_progress` 对齐。
- Shell 接线：`voyage.start` → **3D 离港** → 云层盖住高位镜头 → 海图航行 → 事件云层中断 →
  云层盖住海图 → **3D 入港**（镜头下降 + 船驶入）→ 结算页；`_process` 驱动，演出期间隐藏导航、
  顶栏与海图"当前港"以出发港为准，离港场景用出发港的港口数据（`_presentation_origin_view`）。
- 测试：`test_voyage_presentation`（13 例，纯模型 + 云层 + 弧长采样）、
  `test_voyage_flow`（6 例，真实 Shell + 真实命令，含 3D 交接点与事件中断、跳过）、
  `test_stage_host` 新增 2 例（3D 离港停在海门、入港回到泊位）。

剩余项：事件触发的 3D 场景下降、阶段 4/5 的探索发现与资源告急分支。

### 阶段 4：探索系统

- `Clue` 数据结构与 `ClueService`
- 线索分级与海图可视化（箭头/圆圈/`？港口名？`）
- `explore_voyage` 命令
- 搜索区判定与发现概率
- 资源告急事件与掉头机制
- 探索失败与漂流处理

### 阶段 5：事件化海洋

- 航行事件预生成（出航前全部确定）
- 事件预加载机制
- 敌对/环境/奖励/随机岛屿秘境事件
- 安全航行与消耗结算

### 阶段 6：固定未知岛屿与基地建设（中后期）

- `FixedUnknownIsland` 数据结构
- 勘探机制
- 基地建设系统
- 公开港口建立
- 设施建造

## 12. 验收标准（阶段 0-3 的 MVP 切片）

- 同 seed 生成的世界布局一致
- 15-20 港口合理分布在陆地海岸线上
- 迷雾三态视觉清晰（黑雾/灰雾/可见）
- 沿岸格子被经过后永久保留灰雾
- 海洋格子离开后变回黑雾
- 港口发现时路灯花效应正确清除周围战争迷雾
- 航线为贝塞尔曲线，每港口有唯一出航角度
- 航行演出完整：3D → 云层 → 2D → 事件 → 2D → 云层 → 3D
- 海图 UI 连续可缩放，信息层级正确
- 右侧 Panel 显示目的地基础信息与预计信息
- 168+ 测试通过（新增海图系统测试）

阶段 3 追加的验收项（见 §15）：出航/抵达云层转场可见、船只 icon 沿航线行进、航程条显示
时间与倍率、事件决策期间演出暂停且不能跳过、跳过演出仍会抵达结算页。
## 13. 未决定的事项（留给后续迭代）

- 陆地轮廓视觉风格升级（剪影 → 手绘风格）
- 随机岛屿秘境的漂移规则
- 多人港口区域（一个岛屿上多个港口）的可行性
- 海图视觉风格统一（羊皮纸古地图 / 蓝图 / 蒸汽朋克铜版画）
- 探索航行的演出细节（云层颜色/氛围）
- 漂流到未知港口时的设施限制（维修/补给/交易）

## 14. 阶段 2 视觉验收记录

海图不能只靠无头测试验收：无头模式用 dummy 渲染器，`_draw()` 里的任何东西都不会被看见。
因此补了独立预览场景与真实渲染截图工具，全部 1440×900：

```powershell
# 必须窗口模式（--headless 下视口纹理是空图）
godot --path . --resolution 1440x900 --script res://tools/godot/capture_sea_chart.gd
```

| 截图 | 变体 | 验证内容 |
|---|---|---|
| [sea_chart_fresh.png](screenshots/sea_chart/sea_chart_fresh.png) | `fresh` | 开局只有起点港：整张海图接近全黑，仅港口揭示（路灯花）露出一点海岸 |
| [sea_chart_bare.png](screenshots/sea_chart/sea_chart_bare.png) | `bare` | 诊断用：全图已揭示，单独看清陆地形状、港口分布与航线拓扑（排除迷雾干扰）；**15 个港口全部可见**，即 §2.2 的验收规模 |
| [sea_chart_explored.png](screenshots/sea_chart/sea_chart_explored.png) | `explored` | 沿岸航行后：海岸永久灰雾带、整岛暗淡剪影、稀疏可读的航线网络、三态港口图标 |
| [sea_chart_voyage.png](screenshots/sea_chart/sea_chart_voyage.png) | `voyage` | 在航：船只图标停在航线 45%（按弧长）处、四周有实时视野；右侧面板显示**距离 / 预计时间 / 煤水预计消耗（需求·存量）/ 风险档 / 已探索** |

变体由 `dev_scenes/sea_chart/sea_chart_preview.gd` 提供。预览世界按
`WorldGenerator.MIN_PORTS..MAX_PORTS`（15–20）生成，和验收口径同一把尺子。`explored` 会真实回放一次沿岸航行
（`FogOps.update_ship_vision` 沿大陆海岸环走一圈），所以灰雾带是阶段 1 的真实产出，不是画上去的。

面板里的航程数字不是预览编的：预览会跑一次真实 `RunFactory.create_run`，只替换坐标
`world_map`，船况、锅炉策略与抽象地图航线都来自真实对局，因此截图里的预计时间/消耗/风险
就是玩家在游戏里会看到的数值（`voyage.preview` 同源）。

### 14.1 视觉验收中发现并修复的缺陷

| 现象 | 根因 | 修复 |
|---|---|---|
| 海岸线坑坑洼洼、呈锯齿星形（"噪声不该是平滑的吗？"） | **代码里没有 Perlin/Simplex**：每个顶点独立 `rng.randf()`（白噪声），且正弦项的相位也是逐顶点随机，把波形打碎 | `land_generator.gd` 改为相干谐波剖面 `radius(θ)=base+Σaᵢsin(fᵢθ+φᵢ)`，相位每岛只抽一次；采样段数 128/96/64；`simplify_polygon()` 真正投入使用（容差 0.3） |
| 迷雾是硬边方块，和"格子间 alpha 插值平滑"不符 | 每个格子画一个纯色矩形 | 迷雾烘焙成一张每格 1 texel 的 RGBA 纹理 + 线性过滤，一次绘制且天然平滑 |
| 海图把 13 个港口的**完全图**画成 78 条线，不可读 | `build_connectivity_graph` 连接所有港口对 | 改为最小生成树 + 每港 2 条最近邻捷径（38 条），保持连通但可读 |
| 航线直接横穿岛屿 | `_find_path_around_land` 是"绕岛试探"循环，会振荡；返回折线从未校验；出航角可能指向内陆 | 出航角改为"邻居质心方向 + 内陆回退到背离陆地法线"；绕行改为沿岸环行 + 外切点候选的有界递归，且每条曲线落地前都用包围盒剪枝的陆地校验 |
| 沿岸带太窄（1 格），整岛不成形 | `COASTAL_DISTANCE = 2.0` 单位 < 雾格尺寸；且"已探索"只按质心判定 | 沿岸带改为 `COASTAL_CELLS = 2` 格；"已探索"改为海岸采样点 ≥25% 已揭示才画整岛剪影 |
| 预览里港口名显示 `port.spice_harbor` 等裸键 | 预览 profile 用了不存在的键 | 改用 Core 真实原型 ID 与 `port_name.core.*` 键（Core 只有 6 个港名键，其余用 `port_name.preview.*` 并在预览内解析——这是内容缺口，正式版前要补） |
| 右侧面板显示 `Core:port Archetype/spice_port`、`facility.exchange` | 面板用端口 archetype id / 裸设施 key | 查询输出 `archetype_name_key` / `region_name_key`；面板按 `ui.facility.*` 解析设施 |
| 点击港口会让海图跳位 | `select_port()` 顺带把视图居中到该港口 | `select_port()` 只改选中态；居中拆为显式 `center_on_port()` |
| 航线距离文字压住港口名牌 | 用"路径点序号中点"定位，且不避让港口 | 改为按弧长取中点，且中点距任何港口 <46 px 时不画 |
| 港口出航刻度全部指向正东、扎进陆地 | `departure_angle` 已是弧度，绘制时又套了一次 `deg_to_rad()` | 直接用弧度做 cos/sin |

回归：`test_world_generator` 新增 2 个用例锁死上述行为（航线不得穿过陆地、连通图必须稀疏且连通），
全套 **231 个测试通过 / 0 失败**。

## 15. 阶段 3 航行演出验收记录

演出同样是"画出来的东西"，无头测试只能证明状态机，不能证明玩家看得见。因此补了一个窗口
截图工具，挂载**真正的** `main.tscn`、用真实命令开一局、真实发出 `voyage.start`，按演出
里程碑抓图：

```powershell
# 必须窗口模式（--headless 下视口纹理是空图）
godot --path . --resolution 1440x900 --script res://tools/godot/capture_voyage_presentation.gd
```

| 截图 | 里程碑 | 验证内容 |
|---|---|---|
| [voyage_departure_3d.png](screenshots/voyage_presentation/voyage_departure_3d.png) | `phase == departure_3d` 且舞台 `voyage_progress ≥ 0.45` | **3D 离港**：船已驶离泊位到港外水面、镜头升到高位广角；顶栏「在航 → 目的港」，导航按钮消失 |
| [voyage_departure_clouds.png](screenshots/voyage_presentation/voyage_departure_clouds.png) | `_cloud_veil.cover ≥ 0.45` | 云层正在盖住那个高位镜头（盖满后才切海图） |
| [voyage_at_sea.png](screenshots/voyage_presentation/voyage_at_sea.png) | `_presentation.progress ≥ 0.35` | 航行中：海图铺开、船只 icon 在航线中段、"当前港"高亮出发港；底部航程条显示起终港、进度条、`航程 5 小时 / 14 小时`、`时间加速 ×2.9` 与「跳过演出」 |
| [voyage_arrival_3d.png](screenshots/voyage_presentation/voyage_arrival_3d.png) | `phase == arrival_harbor` 且舞台 `voyage_progress ≥ 0.45` | **3D 入港**：目的港从高位「从海上来」的机位出现，船从海门驶入泊位，镜头正在下降 |
| [voyage_arrival.png](screenshots/voyage_presentation/voyage_arrival.png) | `_presentation == null` 且 `_active_screen == settlement` | 抵达：云层散尽后落在抵达结算页（委托收入 / 准时 / 延误 / 当前金币 / 交付明细） |

### 15.1 视觉验收中发现并修复的缺陷

| 现象 | 根因 | 修复 |
|---|---|---|
| 云层完全看不见，但状态机报告"已盖满" | 运行时 `new()` 的 `Control` 没有父容器排版，只调用 `set_anchors_preset()` 不设 offsets，控件停在 0×0 | `SNCloudVeil._ready()` 与 Shell 挂载处都改用 `set_anchors_and_offsets_preset(PRESET_FULL_RECT)`；截图工具顺手把 `cover / visible / size` 打进日志，0×0 这种事不会再静默通过 |
| 云团是一颗颗硬边气泡 | 用 `draw_circle` 画的圆必然有硬边 | 改成运行时生成一张 128×128 的白色 + smoothstep alpha 贴图，所有云团复用 `draw_texture_rect` 调制颜色，边缘自然发虚 |
| 演出期间顶栏显示已经抵达目的港，等于剧透 | `voyage.start` 已结算抵达，`port.view.current_port_id` 是目的港 | Shell 在演出期间用 `_presentation_voyage.origin` 覆盖顶栏与海图的"当前港"，并把 `at_sea` 设为 true，显示「在航 → 目的港」 |
| 事件云层还没散开就选方案后演出卡死 | `resolve_event()` 从 `veil=1` 再 `_start_veil(1.0)`，`_advance_veil()` 因"已在目标值"永不返回，`EVENT_RESUME` 一直等不到交还 | `tick()` 改为每帧判断 `is_equal_approx(veil, _veil_to)` 再结算里程碑——「本来就在目标值」也立刻交还海图 |
| 加了 3D 离港后，高位镜头会和站位平移"抢镜头"、船被站间航行拽回泊位 | 3D beat 与 `advance_station()` 都在每帧改相机与船位，两边互覆盖 | `_process` 在 beat 进行时跳过 `advance_station(delta)`；`begin_departure/begin_arrival` 把 `_camera_t` 钉到 1.0 取消排队的站位 pan；beat 期间不重算 `camera_shift`，画幅层不再随镜头滑动 |
| 离港 3D 场景显示的是目的港而不是出发港 | `voyage.start` 已结算抵达，`port.view.current_port` 立刻变成目的港 | 在命令前缓存 `_presentation_origin_view`（最后一帧在港的 `port.view`），离港舞台用它 bind；顶栏与海图"当前港"同样取出发港 |
| 事件页一直藏在云层后面（这一轮回归抓到） | `tick()` 的 `EVENT_WAIT` 分支没有推进 `_advance_veil()`，`begin_event_reveal()` 设的目标值永远不会被消费 | `EVENT_WAIT` 每帧推进云层；截图/用例都能看到事件页在云散后出现 |

回归：`test_voyage_presentation`（13 例）+ `test_voyage_flow`（6 例）+ `test_stage_host` 新增 2 例，
全套 **252 个测试通过 / 0 失败**。
