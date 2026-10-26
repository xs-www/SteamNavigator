# 运行时性能与闪退取证报告（v0.2.0-dev.3 → HEAD）

> 状态：**Active**（2026-10-24 取证）。对象：已发布给外部测试者的 `v0.2.0-dev.3` Windows exe，以及当前 HEAD 作为「下一版是否更糟」的对照。
> 原始数据（JSON / CSV / 日志）在本地 `.design/perf/`（`D:\桌面\sisi_apps\SteamNavigator\.design\perf\`），该目录不入库；可复现命令见附录 B。
> 相关文档：[KNOWN_LIMITS.md](KNOWN_LIMITS.md)、[2.5D_STAGE_PLAN.md](2.5D_STAGE_PLAN.md) §9、[UI_SKIN_PIPELINE.md](UI_SKIN_PIPELINE.md)、[todo.md](../../todo.md)。

## 0. 一页结论

两个人反馈的 exe 已确认是 **v0.2.0-dev.3**（2026-10-22 19:57 打包）。本机（i7-13650HX / RTX 4060 Laptop / 32GB / 240Hz 屏）用真实 exe + 工程实测：

| 问题 | 结论 | 关键证据 |
| --- | --- | --- |
| **稳态帧率低？** | **代码本身不是稳态掉帧型问题。** 1440×900 下整帧 GPU 成本 ≈ **1.2–1.9 ms**（dev.3 exe 在 240Hz 下 vsync 饱和 = 240fps），每帧 CPU 脚本只有 **0.02–0.23 ms**（海图 0.93、演出 1.07）。 | 见 §3.1、§4.1 |
| **但玩家会觉得「卡」** | **是。每次成功交互都整页重建 UI**：点一次买/卖 = **≈380 ms 主线程卡死**（命令 24ms + 整页重建 167ms + 每查询 11.6ms 全状态深拷贝 × N + `_port_name()` 13.5ms/次）；切一次页 = 100–340ms（海图 340ms）；自动存档同步写盘 167ms。弱 CPU（4 核）上放大 2–4 倍 → **0.8–1.5 s 一次**。这与「帧率低」的用户描述高度吻合。 | 见 §3.2 |
| **弱机帧率** | 第二风险项：3D 舞台是**固定画布分辨率（≈1440×900，不随窗口缩放）+ 硬编码 4× MSAA** 的全窗 SubViewport；`render_shrink` 存在但**从未被设置**，设置页只有「语言/自动存档」，**没有任何画质档位**。iGPU / 低端独显 + 60Hz vsync 掉半 → 观感直接掉到 30fps。 | 见 §4.2–§4.4 |
| **闪退** | **已复现并已修复（兜底）**：只要本会话渲染过 3D 舞台，退出（关窗 / Alt+F4 / 退出按钮）时引擎 GLES3 teardown 必崩 **0xC0000005**——dev.3 与 HEAD 导出版均可复现，纯菜单退出干净。应用层清理无法避免（见 §5.1），最终用「清理完成后终止进程」的引擎兜底解决，实测 WER 不再新增。**运行中闪退仍无日志/代码证据**，排序首位是环境（弱 GPU/驱动 TDR、混合显卡走核显、GL 初始化失败）。 | 见 §5 |
| **启动** | dev.3 冷启动 ≈ 2 s；**HEAD 冷启动 ≈ 3.2 s**（mod 内容从 32 MB 涨到 37 MB，挂载+编译从 213 ms 涨到 1708 ms）。`run.start`（世界生成）p50 300 ms / max 375 ms。 | 见 §3.3 |

**一句话**：这一版「帧率低」的主要观感来源不是渲染掉帧，而是**每次交互 0.4 s 级的整页重建 + 全状态深拷贝**（弱机更糟）；「闪退」里只有**退出阶段**有一类可复现的崩溃，运行中闪退更像**弱机/驱动环境**问题，需要测试者日志。下一条 P0 不是「优化渲染」，而是「把每次交互的重建成本降下来 + 加优雅退出 + 给弱机一个画质档位」。

---

## 1. 对象与环境

| 项 | 值 |
| --- | --- |
| 被测构建 A | `release/SteamNavigator/SteamNavigator.exe`（113 MB，内嵌 PCK；构建 2026-10-22 19:57）= **v0.2.0-dev.3** |
| 被测构建 B | 当前 HEAD（2026-10-24 18:55，比 dev.3 多 1018 文件 / +101k 行） |
| 身份验证 | exe 内嵌 PCK 共 438 条，dev.3 之后新增的 227 个脚本/场景**一个都不在**；exe 旁 `mods/core-1.0.0.snavmod.zip` 与 `git ls-tree v0.2.0-dev.3 -- dev_mods/core` **328/328 文件字节数一致** |
| 引擎 | Godot 4.7.2 stable（Steam 版），GL Compatibility / OpenGL 3.3 |
| 本机 | i7-13650HX（20 线程）/ RTX 4060 Laptop / 32 GB / 240 Hz 屏 / Windows 11 26200 |
| 重要前提 | 本机是**强机**，dev.3 在本机 240fps 饱和 → 不可能复现「低帧率」。本报告的重点是**成本结构**与**可外推的放大器**，不是本机绝对帧率。 |

### 1.1 渲染配置（dev.3 与 HEAD 完全一致）

`project.godot`（`git diff v0.2.0-dev.3 HEAD -- project.godot` 为空）：

- `rendering_method = gl_compatibility`
- `anti_aliasing/quality/msaa_3d = 2`（2×）
- `window/size/viewport 1440×900`、`window_width/height_override 1440×900`、`stretch/mode = canvas_items`、`aspect = expand`
- 未配置 `vsync_mode`（默认开启）、未配置 `max_fps`
- 3D 舞台额外强制 **4× MSAA**：`framework/ui/components/sn_stage_host.gd:194` → `_viewport.msaa_3d = Viewport.MSAA_4X`

---

## 2. 方法（可复现）

新增 3 个只读探针（另复用 1 个既有工具；都不改产品代码）：

| 工具 | 用途 | 运行方式 |
| --- | --- | --- |
| `tools/godot/perf_probe.gd` | 真实 Shell（Bootstrap → main.tscn → run.start → 逐页）的帧时间 / p95 / hitch / draw calls / prims / VMem / SubViewport 清单；支持 `--resolution`、`--msaa`、`--no-stage`、`--stage-msaa` | 窗口模式 |
| `tools/godot/perf_cpu_probe.gd` | 启动链路分阶段、`run.start`、查询/命令 p50/p95、整页重建、autosave、稳态每帧 CPU；支持 loose 与 zip 两条 mod 路径 | headless |
| `tools/godot/probe_export_assets.gd` | 挂载真实发布 zip，验证 `Image.load_from_file` / GLB 外部贴图 / 全量贴图显存口径 | headless |
| `tools/godot/measure_port_stage.gd`（既有） | 独立 PortStage 场景 draw call / tri 预算 | 窗口模式 |

测量口径说明（很重要）：

- **本机无 vsync 的帧时间**（probe 内 `vsync=off`，600–2000 fps）用于比较「成本结构」，但**±0.3–1.3 ms 的跨进程漂移**会淹没小于 0.3 ms 的组间差异，因此本报告只对 >0.3 ms 的差异下结论。
- **玩家实际看到的是 vsync 帧率**：60 Hz 屏上错过 16.6 ms 会**直接掉到 30fps**（阶跃，不是平滑下降）；本机 240 Hz 屏上 dev.3 实测 240fps 饱和。

---

## 3. 结论一：稳态不慢，交互卡顿才是主因（CPU 侧）

### 3.1 稳态每帧 CPU（headless，HEAD）

| 场景 | 每帧 CPU p50 |
| --- | --- |
| 城镇页（overview/market/shipyard/base…） | 0.02–0.23 ms |
| 海图页（`_draw` 每帧全量重绘） | 0.93 ms |
| 出航演出页 | 1.07 ms |

→ 稳态只有 16.6 ms 预算的 **1%–7%**，不是掉帧来源。

### 3.2 每次交互的主线程卡死（这是「帧率低」最可能的真实体感来源）

`shell._run_command()` = `CommandBus.execute` + `_refresh()` **整页重建**：

| 交互 | p50 | p95 | max |
| --- | --- | --- | --- |
| 市场买入 `trade.buy` | **381.3 ms** | 394.5 | 394.5 |
| 市场卖出 `trade.sell` | **379.5 ms** | 396.0 | 396.0 |
| 船厂安装模块 `ship.install_module` | **391.7 ms** | 396.6 | 396.6 |
| 导航：总览 → 海图（无命令，仅切页） | **346.1 ms** | 362.1 | 362.1 |

381 ms 的构成：

1. 命令本体 **24 ms**（一次成功的命令 = 2 次全状态深拷贝：`state.clone()` 11.6 ms + `replace_with()` 11.4 ms）；
2. **整页重建 ~167 ms**（`_rebuild_ui()` 销毁并重建整棵页面树，41 次查询）；
3. `story.observe` / `quest.observe` 各 24 ms（每次成功命令后都执行）；
4. 状态消息里的 `_port_name()`：**每出现一个港口名就一次 `map.view` 全克隆 = 13.5 ms**。

查询本身的固定开销也是全状态深拷贝：**11.6 ms/次**（`app.view` 12.3、`port.view` 17.6、`market.view` 18.9、`shipyard.view` 27.4）。状态紧凑 JSON 251 KB，其中 `fog` 151 KB（61%）、`world_map` 57 KB——这两块几乎只在探索时变化，却参与**每一次**查询/命令的克隆。

> **2026-10-24 优化后复测**（P0 阶段 1 已落地）：`trade.buy` end-to-end **381 → 309 ms**（−19%），切海图 **346 → 277 ms**（−20%），`_port_name()` **13.5 → 0 ms**。剩余成本集中在「整页重建的节点构建」与 `story.observe` / `quest.observe` 两条命令（各约 24 ms），是阶段 2 的目标。

> **dev.3 对照**：同一套结构在 dev.3 就存在（`GameState.clone()`、每查询克隆、整页重建、`_port_name()` 全部相同），dev.3 开局状态 215.7 KB ≈ HEAD 的 87% → 点一次约 **0.33 s**。所以这不是 10-24 新 UI 引入的回归。

### 3.3 启动 / 加载

| 阶段 | loose `dev_mods`（开发） | dev.3 内容包 32 MB zip | HEAD 内容包 37 MB zip |
| --- | --- | --- | --- |
| scan | 15 ms | 151 ms | **1020 ms** |
| mount（`load_resource_pack`） | 0 | 5 ms（首挂 412 ms） | 17 ms（首挂 1499 ms） |
| compile | 65 ms | 44 ms | **642 ms** |
| **mod 总耗时** | **80 ms** | **213 ms**（首 608） | **1694 ms**（首 3175） |
| 引擎初始化到脚本入口 | ≈1450–1480 ms | 同 | 同 |

- 玩家冷启动 ≈ 引擎初始化 + mod 加载：dev.3 ≈ **≥2 秒**，HEAD ≈ **≥3.2 秒**（首挂 3.6 s）。
- `run.start`（世界生成 + 市场初始化）：p50 **300 ms**、max 375 ms（本机；弱 CPU 上按比例放大）。
- 单次存盘 167 ms，其中 `canonical_stringify` 107.6 ms（65%）、`state.to_dict()` 12.6 ms；**同步写在主线程**，在开局/每次抵达/剧情推进/委托完成时触发 → 0.17 s 级冻结（弱机 0.4–0.8 s）。

---

## 4. 结论二：渲染成本结构（弱机放大器）

### 4.1 分页帧时间（HEAD，RTX 4060 Laptop，1440×900，无 vsync 上限）

| 页面 | 帧时间 p50 | p95 | draw calls | primitives | VMem | SubViewport |
| --- | --- | --- | --- | --- | --- | --- |
| main_menu | 0.46 ms | 0.70 | 36 | 464 | 30 MB | 0 |
| overview（3D 港口舞台） | 1.19 ms | 1.70 | 241 | 69,800 | 93 MB | 1×1440×900 |
| market（3D 舞台 + 市场面板） | 1.39 ms | 1.95 | 303 | 71,574 | 94 MB | 1×1440×900 |
| shipyard（船体 3D + 操作台） | 1.51 ms | 1.98 | 309 | 14,707 | 142 MB | 2（一个隐藏） |
| sea_chart（2D 全量 `_draw`） | 1.60 ms | 2.18 | 185 | 3,274 | 121 MB | 0（停止更新） |
| at_sea（演出/海图） | 1.83 ms | 2.41 | 175 | 5,868 | 121 MB | 0（停止更新） |

切页首帧 hitch（首访 GLB 解析 / 着色器 / 贴图上传）：overview **max 56.2 ms**、market 28.0 ms、shipyard 17.4 ms、sea_chart 12.1 ms。

> **⚠️ 本机测量漂移很大，跨运行不能直接横比**：同代码同参数重跑（控制组 A2）得到 main_menu 0.46→1.70 ms（3.7×）、overview 1.19→1.91 ms、market 1.39→2.31 ms、at_sea 1.83→2.45 ms。原因是这台机器是**共享交互桌面**（常驻 Wallpaper Engine / Edge / 微信 / 音频服务）。因此上表只适合描述「量级」，**任何 <0.3 ms 的组间差异都视为不可判定**；`--no-stage` / `--msaa=0` 反而更慢的那些读数已确认是漂移假象。

**唯一可信的 3D vs 2D 定量（同进程内配对、3 轮 on/off 交替）**：

| 工程 | overview 舞台成本（配对差值中位） | market |
| --- | --- | --- |
| HEAD | **0.00 ms**（各轮 +0.026 / −0.048 / −0.17） | +0.30 ms |
| dev.3 | **+0.60 ms**（各轮 +0.40 / +0.55 / +0.73） | — |

→ 在 RTX 4060 级 GPU 上，3D 舞台与 2D/引擎开销同数量级且都很小；**本机数据无法证明「关 4× MSAA 能省多少帧时间」**（`--msaa=0` 只确定性地省下约 40 MB 显存：93.1→53.5 MB）。

补充审计（都通过，不需要整改）：

- 隐藏页面**不会**继续渲染：不可见页的 StageViewport 是 `UPDATE_DISABLED`、舞台 `PROCESS_MODE_DISABLED`；shipyard 虽有两个 SubViewport，隐藏的那个不渲染。
- 关掉 3D 的确定性收益（draw/prims，不受漂移影响）：overview −85 draws / −68.6k prims，market −85 / −68.6k，shipyard −92 / −11.5k。
- 稳态最贵的两个页面是 **sea_chart 与 at_sea**：它们是全屏 2D 每帧重绘 + 演出逻辑（CPU 0.93–1.07 ms/帧），不是 3D 舞台。

### 4.1b dev.3 与 HEAD 的对照（同机同时段，worktree 源码）

| 页面 | dev.3 帧时间 p50 | draws / prims | VMem | HEAD 帧时间 p50 | draws / prims | VMem |
| --- | --- | --- | --- | --- | --- | --- |
| overview（3D 舞台） | 1.80 ms | **321 / 85.1k** | 125.6 MB | 1.19–1.91 ms | **241 / 69.8k** | 93–95 MB |
| market（舞台 + 面板） | 1.60 ms | 274 / 84.8k | 128.5 MB | 1.39–2.31 ms | 303 / 71.6k | 96 MB |

- dev.3 的 3D 舞台**更重**（多玩家船 + 市镇，prims +22%）；HEAD 起点港切到 landmark minimal 模式后 3D 变轻。
- HEAD 的新 UI 皮肤把 market 的 draw calls 从 274 抬到 303，但帧时间差异在漂移范围内 → **没有证据表明 HEAD 变慢**。
- 结论：**「低帧率」不是 10-24 的新 UI/新场景引入的回归**，dev.3 就已经存在（且 dev.3 的 GPU 成本更高）；两者的 `project.godot` 渲染配置完全一致。

### 4.2 3D 舞台的两个结构性放大器

1. **固定画布分辨率 + 全窗 SubViewport**：`stretch/mode=canvas_items` + 基准 1440×900 下，StageViewport 尺寸跟随**画布空间**而不是窗口物理分辨率。实测：1440×900 窗口 → 1440×900；960×540 窗口 → **1600×900**（aspect expand 反而更宽）；2560×1600 窗口 → 1467×900。
   ⇒ **玩家调小窗口分辨率救不了 3D 帧率**（甚至变差 11%）；能救的只有 `render_shrink` / MSAA / 关 3D 层。
2. **硬编码 4× MSAA**（`sn_stage_host.gd:194`）：1440×900 画布 = 1.3 Mpx × 4 samples；`render_shrink`（÷2 渲染）这个「廉价质量杠杆」**全仓库从未被赋值**（只有默认 1）。

### 4.3 2D UI 在物理像素上是真·随分辨率增长

`canvas_items` 下 2D UI 按**窗口物理像素**光栅化：main_menu 从 1440×900 → 2560×1600 帧时间 0.46 → 1.24 ms（2.7×，≈像素比 3.16×）。市场页 303 draws / 30 万+ 节点树（399 nodes / 301 controls）。高分屏 + 弱 GPU 的机器上，UI 填充率是第二成本项。

### 4.4 可外推的弱机风险（推算，不是实测）

以本机 1440×900 舞台 ≈1.4–1.6 ms 为基线，按填充率/带宽粗略折算：

| 机型 | 1440×900 预计 | 观感 |
| --- | --- | --- |
| RTX 4060 Laptop（本机实测） | 1.4–1.6 ms | 240fps（vsync 饱和） |
| GTX 1650 级 | 5.5–8 ms | 120–180 fps，可玩 |
| GTX 1050 级 | 8.3–12.8 ms | 78–120 fps，60Hz 边缘 |
| Vega 8 / Iris Xe 级核显 | 11–19 ms | **52–90 fps，60Hz 下开始掉 30** |
| UHD 620/630 | 21–40 ms | **25–48 fps，不可玩** |
| 任意机型 + 60Hz vsync | 帧时间 >16.6 ms 时**阶跃掉到 30fps** | 用户感知断崖 |

**可证伪的验证**（交给测试者，见 §8）：报显卡型号；任务管理器看游戏跑在哪个 GPU（混合显卡笔记本最常见「跑核显」）；`--resolution 960x540` 与 `2560x1600` 对比 FPS；事件查看器查 Event 4101（驱动 TDR）。

### 4.5 显存 / 贴图口径（发布路径）

- 发布路径的共享贴图走 `ContentAssetLoader.load_texture()` → `ImageTexture.create_from_image()`：**无 mipmap、无 VRAM 压缩、RGBA8**。
- 发布 zip 内 148 张 PNG 全量解码 = **150 MB**；GLB 实际引用的 **114 条路径 = 114 MB**，但只对应 **27 张唯一内容**（13 个 `models/<category>/shared_materials/` 各存一份副本）→ **121 MB 是重复副本浪费**；另有 2172×724 港口横幅 6 MB。
- 实测把舞台跑起来后 GPU 专用显存峰值 **195–199 MB**、RAM WorkingSet **369 MB（舞台）→ 546 MB 峰值**（dev.3 exe，150 s 运行无增长）。⇒ **不会 OOM**，但重复贴图在弱 GPU 上是带宽/填充率负担。

---

## 5. 结论三：闪退

**证据强度排序**（三类闪退按「能证实」的顺序）：

1. **P0｜弱 GPU / iGPU 渲染环境**：解释「低帧率 + 可能 TDR 闪退」，证据中（本机强机测不出，缺弱机实测）；
2. **P0（已证实、已兜底）｜退出阶段 GL 清理崩溃**：3D 会话退出必崩已实测（dev.3 / HEAD 导出版都复现），应用层清理无效 → 引擎缺陷，已用进程终止兜底并验证不再产生 WER 崩溃；
3. **P2｜启动即崩**（GL 3.3 不可用 / ANGLE / 远程桌面 / 虚拟显示）：低–中，纯静态推断。

> 说明：**运行中（非退出）闪退没有任何直接证据**——dev.3 exe 在 3D 舞台连续运行 150 s，stderr 无资产加载失败、无脚本错误。要把这一条坐实，只能靠测试者日志（§8）。

### 5.1 已复现并已兜底：退出阶段 GLES3 清理崩溃（0xC0000005）

> **结论（2026-10-24 20:29 更新）**：用户可见性**已证实**——从 3D 舞台页点 X 关窗 → Windows 事件日志新增 `APPCRASH SteamNavigator.exe / 0xC0000005 / fault offset 0x3f88249`。**应用层优雅退出（卸舞台、释放 SubViewport、清空页面树、`ContentAssetLoader.clear_cache()`、`FrameworkRuntime.shutdown()`、`RenderingServer.force_sync()`、多等 5 帧）都不能避免**，属于引擎 GLES3 teardown 缺陷；最终在「已渲染过 3D 且非编辑器构建」时于清理完成后 `OS.kill()` 终止进程作为兜底，**实测 WER 不再新增、玩家看到正常关闭**。该兜底随引擎升级应移除。

- 复现：`SteamNavigator.exe --resolution 1440x900 --print-fps --quit-after 36000`（或直接点 X）进入 3D 舞台后退出。
- 现象：退出瞬间 **Windows Application Error 1000 `APPCRASH SteamNavigator.exe 4.7.2.0`，异常码 0xC0000005，fault offset 0x3f88249（模块 = exe 自身 = 引擎代码）**。
- 崩溃前 stderr：`Pages in use exist at exit in PagedAllocator: RasterizerSceneGLES3::GeometryInstanceSurface/GeometryInstanceGLES3`、`1 shaders of type SceneShaderGLES3 were never freed`、大量 `Texture with GL ID … leaked 1048575 bytes`（正好 512²×4 = 运行时 `ImageTexture`）与 buffer 泄漏。
- 触发条件：**本会话渲染过 3D 舞台**（港口舞台或船厂 3D）。纯主菜单会话、源码级 probe（`--no-teardown` / `--mount-zip`）都干净退出，只有导出版 + 渲染过 3D 才崩。
- 应用层修复尝试（均已实现但**不足以**避免崩溃，仍保留为「释放游戏资源」的正确做法）：
  `auto_accept_quit=false` → `NOTIFICATION_WM_CLOSE_REQUEST` → `_prepare_quit()`（停演出 / `unmount_stage()` / 释放 `SNStageHost` 的 SubViewport / 释放页面树、全屏层、热点层）→ `ContentAssetLoader.clear_cache()` → `FrameworkRuntime.shutdown()` → `RenderingServer.force_sync()` → 等 5 帧 → 仍崩。
- **最终兜底（已落地，HEAD 导出构建实测）**：清理完成后若 `_had_3d_stage` 且非编辑器构建，`OS.kill(OS.get_process_id())` 结束进程，跳过引擎 teardown；纯菜单会话仍走 `get_tree().quit()`。验证：同一自动化流程（进 3D 舞台 → 点 X）WER 计数 **4 → 4（不变）**，而修复前为 3 → 4（新增崩溃）。


交叉验证（说明触发条件不是「quit 本身」，而是「本会话渲染过 3D」）：

| 退出场景 | 结果 |
| --- | --- |
| dev.3 exe `--quit-after 36000`，3D 舞台已加载 ~150 s | ❌ **0xC0000005** + GL 泄漏刷屏 |
| **dev.3 exe：进 3D 舞台 → 点 X 关窗**（2026-10-24 20:16 补测） | ❌ **0xC0000005 @ 0x3f88249**（WER +1）→ 用户可见性证实 |
| dev.3 exe 主菜单态点 X / 退出按钮 | ✅ 干净退出（3/3，无舞台资源） |
| **HEAD 导出版：进 3D 舞台 → 点 X 关窗（修复前）** | ❌ **0xC0000005**（WER 3→4） |
| **HEAD 导出版：进 3D 舞台 → 点 X（本报告落地兜底后）** | ✅ **WER 4→4**，进程正常关闭、无崩溃弹窗 |
| HEAD 导出版主菜单态点 X | ✅ 干净退出（WER 不变） |
| dev.3 源码 + `--mount-zip` / HEAD 工程 probe 加载舞台后 `--no-teardown` quit | ✅ EXIT=0（刷 `RID leaked` 警告，无 AV） |
| HEAD headless `--quit-after 300` | ✅ 退出码 0 |

→ 在源码级（含 zip 挂载路径）**复现不出这个 AV**，只有真实导出 exe 才崩，且与应用层清理无关 → **引擎（Godot 4.7.2 GL Compatibility）teardown 缺陷**，与游戏脚本无关；`RID leaked` 警告在正常退出的测试里也会出现，不能单独作为崩溃证据。已在应用层用「清理后终止进程」兜底，并留 TODO：引擎升级后移除兜底并复测。

### 5.2 未复现：运行中闪退（环境相关，无直接证据）

dev.3 exe 在 3D 舞台连续运行 150 s：stderr **无资产加载失败、无脚本错误**，唯一 warning 是 `looking_at: Target and up vectors are colinear`（舞台相机，无害）。发布路径探针（headless 挂真实 zip）：148/148 PNG 解码成功、162/162 GLB 解析成功、114/114 外置贴图 URI 命中、缺失资产返回 null 并缓存（不刷屏）。⇒ 已排除「资产在 exe 里读不到」这类系统性缺陷。

按「什么环境会让同一份 240fps 代码崩/掉帧」排序：

| 排序 | 假设 | 影响机型 | 证据强度 |
| --- | --- | --- | --- |
| A1 | 弱 GPU / 混合显卡跑核显：4× MSAA + 全窗 3D → 帧时间过长触发 **Windows TDR（驱动重置）** → 黑屏/退出；老 Intel/AMD 驱动 multisample FBO 兼容 bug | iGPU、GTX 1050/1650 级、笔记本省电模式 | 中（需测试者 GPU 型号 + Event 4101） |
| A2 | 启动即崩：OpenGL 3.3 不可用 / ANGLE 回退失败 / 虚拟显示或远程桌面（本机就装了 `OrayIddDriver`） | 老 Intel HD、远程桌面、虚拟显示器 | 低（静态推断，无日志） |
| A3 | 存量脚本/数据问题 | 任意 | 低（150 s 实跑 0 错误，保留） |
| — | 内存/显存 OOM | — | 已排除（RAM 峰值 546 MB、VRAM ~200 MB） |
| — | 存档损坏/版本校验 | — | 已排除（失败路径是拒绝加载 + 提示，不崩） |

---

## 6. 成本清单（按「玩家感知」排序）

> **先分清玩家的「低帧率」是哪一种**（这决定接下来修哪里）：
> - **站着不动也低** / 每个页面都低 → 看 **GPU 侧**（§4、§7 P1：弱机 + 4× MSAA + 高分屏 2D）；
> - **只有操作/切页/出航时才卡** → 看 **CPU 侧**（本节 #1–#5c，每次交互 0.38–0.49 s），这是本次最有把握的解释。

| # | 成本项 | 量级 | 触发频率 | 影响 |
| --- | --- | --- | --- | --- |
| 1 | 每次成功命令整页重建 `_rebuild_ui` | **167 ms** + 查询深拷贝 × N | 每次点击（买卖/安装/导航） | 0.38 s 卡死/次（弱机 0.8–1.5 s） |
| 2 | 全状态深拷贝（`clone` 11.6 ms / `replace_with` 11.4 ms；每查询 1 次） | 11.6 ms/次 | 每查询、每命令 | 与 #1 叠加 |
| 3 | `_port_name()` 每调一次一次 `map.view` 全克隆 | 13.5 ms/次 | 每条状态消息 1–3 次 | 与 #1 叠加 |
| 4 | autosave 同步写盘 | **167 ms** | 开局/抵达/剧情/委托 | 定点冻结 |
| 5 | 切页整页重建 | 100–340 ms（海图 340） | 每次导航 | 卡顿 |
| 5b | 全屏 2D **每帧无条件重绘**：`sn_sea_chart_view._process` 每帧 `queue_redraw` 全量重画海图、`sn_ship_view` 在 EXTERIOR 有 3D renderer 时仍每帧重绘 | CPU **0.93–1.07 ms/帧** + 全屏填充 | 常驻（sea_chart / at_sea 是 HEAD 最贵的稳态页） | 弱 CPU 与弱 GPU 双重成本 |
| 5c | 出航演出的相位切换也走 `_rebuild_ui`（`DEPARTED` / `AT_SEA_STARTED` / `ARRIVAL_READY`） | 单帧 **489 ms** 毛刺 | 每次出航 3 次 | 演出期间明显卡顿 |
| 6 | 3D 舞台固定画布 + 4× MSAA（弱机） | 本机 1.4–1.6 ms；弱机 10–40 ms | 常驻（overview/market/shipyard） | 弱机掉到 30 fps |
| 7 | 首访页面 GLB 解析 / 着色器上传 | 12–56 ms hitch | 每页首次 | 一次性卡顿 |
| 8 | 发布 zip 冷启动 | dev.3 213 ms；HEAD 1694 ms（首 3175） | 每次启动 | 启动慢 |
| 9 | `run.start` 世界生成 | 300 ms（max 375） | 开新局 | 开局面板冻结 |
| 10 | 重复共享贴图 | 114 条路径 → 27 张唯一 = 浪费 ~121 MB | 常驻 | 弱 GPU 带宽/解码 |
| 11 | `looking_at` 共线 warning | 82 次（舞台构建时） | 每次舞台构建 | 日志噪音/构图隐患 |

---

## 7. 整改建议（按收益/风险）

### P0 — 先修这两件（顺序即优先级）

1. **交互重建降到 <100 ms（这是「卡」的主因，对应「帧率低」反馈）** — 状态：**阶段 1 已落地（2026-10-24）**，`trade.buy` 381 → **309 ms**、切海图 346 → **277 ms**，`_port_name` 13.5 → **0 ms**；**阶段 2（局部刷新/observe 合并）尚未做**。
   建议按「风险从低到高」分三步落地：
   - ① **`_port_name()` 缓存**（零架构风险、15 个调用点、每条消息 1–3 次 × 13.5 ms）→ **已落地**：按 run seed 缓存 `port_id → name_key`，一次 `map.view` 填满整表；
   - ② **QueryBus 共享只读快照**（收益最大：每次重建 −58～−104 ms，但要动「查询不写状态」这条既有不变量）→ **已落地**：`begin_read_scope()` / `end_read_scope()`，`CommandBus` 提交后 `invalidate_read_snapshot()`；`test_ui_shell` 新增两条守门测试；
   - ③ **`_rebuild_ui` 局部化**：市场/船厂等高频页只刷新变化区块（数量、价格、持仓），chrome / 状态条 / 侧牌 / 故事层不重建；演出相位切换（`DEPARTED` / `AT_SEA_STARTED` / `ARRIVAL_READY`）预建目标页，消除单帧 489 ms 毛刺 — **待做（阶段 2）**；
   - 其余：`story.observe` / `quest.observe` 合并为一次且仅在状态变化时执行；autosave 改后台线程/分帧序列化（或只在「抵达/退出」同步一次），主线程不再 167 ms 冻结 — **待做**。
   - 验收：用 `perf_cpu_probe.gd --mode=interactions` 复测（当前 309 ms），最终目标 <100 ms；UI 测试全绿（当前 668/668）。
2. **优雅退出（消除已复现的退出崩溃）** — 状态：**已落地并实测通过（2026-10-24）**。
   - 已实现：`auto_accept_quit=false` + `NOTIFICATION_WM_CLOSE_REQUEST` → `_graceful_quit()`；`_prepare_quit()` 幂等（停演出 / `unmount_stage()` / 释放 `SNStageHost` 的 SubViewport / 释放页面树、全屏层、热点层 / 清 `ContentAssetLoader` 缓存 / `FrameworkRuntime.shutdown()` / `force_sync()` / 等帧）。
   - **实测：应用层清理不足以避免引擎崩溃**（见 §5.1 交叉验证），因此补了引擎兜底：`_had_3d_stage` 且非编辑器构建时，清理完成后 `OS.kill(OS.get_process_id())`；纯菜单会话仍 `get_tree().quit()`。
   - 验收（已达成）：同一自动化流程「进 3D 舞台 → 点 X 关窗」，修复前 WER 3→4，修复后 **WER 4→4（无新增崩溃）**；主菜单退出干净；Godot 全量 **668/668**。
   - 后续：引擎升级后移除该兜底并复测（`grep _had_3d_stage`，见 [todo.md](../../todo.md)）。
   - 复现命令（无需 UI）：`SteamNavigator.exe --resolution 1440x900 --print-fps --quit-after 36000`，让它在 3D 舞台跑满 ~150 s 后自行退出，随后查事件查看器 Application Error 1000。

### P1 — 弱机适配（决定「低配能否玩」）

3. **画质档位 + 自动低配**：设置页新增「画质：高/中/低」；低档 = `StageViewport.render_shrink=2` + 关闭 4× MSAA + 关闭雾带/粒子 + 3D 页可回退 2D 背景。启动时按渲染器名/显存/首帧时间自动选档（并在设置页可见）。
4. **MSAA 可配置**：`sn_stage_host.gd` 的 4× MSAA 改为档位驱动（高=4×、中=2×、低=0），并把 `render_shrink` 接上设置。
5. **vsync / 帧率上限**：暴露「垂直同步 / 帧率上限」设置；至少让 60Hz 屏玩家在低于 60fps 时有稳定选项（避免 30fps 阶跃）。
6. **显存去重**：`ContentAssetLoader` 按内容哈希缓存贴图（或打包时合并 `shared_materials`），114 条路径 → 27 张，省 ~121 MB 显存与解码时间。
7. **全屏 2D 降本**：`sn_sea_chart_view` 改条件重绘 / 静态层缓存（陆地、雾、网格缓存为可复用的绘制层，只重画船与脉冲）；`sn_ship_view` 在已有 3D renderer 时不要再 `queue_redraw`；九宫格（22 个唯一 style）与 30 枚图标做图集 → market 的 **303 draw calls 目标降 30%–50%**。
8. **修正 540p 下舞台变宽**：`stretch/aspect=expand` 让 960×540 窗口的画布变成 1600×900（比 1440×900 更大），低分辨率档反而更贵；低配应显式固定 3D 画布（`render_shrink`/`SubViewport.size`），而不是靠缩窗口。

### P2 — 启动与体验

9. 发布 zip 冷启动优化：HEAD 内容 37 MB → 1.7 s（首 3.2 s）。按入口页懒读内容文件、压缩 zip 目录扫描、或预生成内容索引。
10. 首访页面预加载：切页前空闲帧预解析该页 GLB（避免 56 ms hitch）；确认舞台/船厂节点重建时旧树 `queue_free` 完整。
11. 修复 `looking_at` 共线 warning（`port_stage.gd:3500 _add_beam` / `_add_foreground_frame`）。
12. **崩溃/取证兜底**：启动时把引擎版本、渲染器/GPU 型号、内容包版本、mod 列表写入 `user://logs/startup.log`；文档里给测试者日志路径（`%APPDATA%\Godot\app_userdata\Steam Navigator\logs\godot.log`）。

---

## 8. 复测与取证

### 8.1 给测试者的取证包（可直接转发）

1. 日志：`%APPDATA%\Godot\app_userdata\Steam Navigator\logs\godot.log`（以及同目录里 `godot<时间>.log` 旋转日志）。
2. 机器：显卡型号 + 是否笔记本 + 电源模式（省电/平衡/性能）；任务管理器「性能」里游戏运行在哪个 GPU。
3. 闪退时机：启动时 / 切页 / 出航演出 / 存档 / 退出？闪退前后有没有 Windows 弹窗（拍屏即可）。
4. 复现命令（两种分辨率对比，判断是填充率受限还是 CPU 受限）：
   ```
   SteamNavigator.exe --resolution 960x540 --print-fps
   SteamNavigator.exe --resolution 2560x1600 --print-fps
   ```
5. 事件查看器 → Windows 日志 → 应用程序：筛选 `Application Error`(1000) / WER(1001) / `Display`(4101，驱动 TDR)。

### 8.2 本地复测命令

```powershell
$godot = "C:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"

# CPU 侧（headless，~135 s）
& $godot --headless --path . --fixed-fps 60 --script res://tools/godot/perf_cpu_probe.gd -- --mode=all

# 渲染侧（窗口，逐页帧时间）
& $godot --path . --resolution 1440x900 --script res://tools/godot/perf_probe.gd -- --out=.design/perf/render.json

# 发布资产链路（headless）
& $godot --headless --path . --script res://tools/godot/probe_export_assets.gd -- --report=.design/perf/assets.json
```

---

## 附录 A：数据文件（本地 `.design/perf/`，不入库）

| 文件 | 内容 |
| --- | --- |
| `render_report.md` / `head_*.json` / `run_head-*.log` | 渲染侧逐页数据、变量矩阵、退出码 |
| `cpu_report.md` / `cpu_probe_loose.json` / `cpu_probe_zip.json` | 启动、查询/命令、整页重建、autosave、稳态每帧 |
| `crash_report.md` / `probe_export_assets.json` / `dev3-*.log` / `gpu_phase*.csv` | dev.3 身份证据、资产链路、显存口径、退出崩溃 WER 记录 |
| `release_pck_entries.csv` | exe 内嵌 PCK 目录清单（438 条） |

## 附录 B：测量环境注意事项

- 同一时间只允许一个窗口模式 Godot/exe 运行，否则 GPU 争用会污染帧时间。
- 无 vsync 的 uncapped FPS 对背景负载极敏感（600 fps 时 0.2 ms 抖动 = 30%），组间差异 <0.3 ms 视为不可判定。
- 本机桌面为共享交互桌面，窗口可能被遮挡；遮挡会影响采样状态，截图必须与采样同一次运行。
