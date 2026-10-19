# 物品建模半工作流（Modeling Dispatch Workflow）

> 一句话：把「我要一个 X」变成一张标准工单，由 Lead 自动派发给建模子代理，子代理在 Blender 里参数化建模，独立质检子代理验收；人工只在**开工前**和**交付前**各点一次头。

- 工单模板：[`tools/modeling/briefs/_template.json`](../../tools/modeling/briefs/_template.json)
- 样板工单：[`tools/modeling/briefs/sn_ship_prototype.json`](../../tools/modeling/briefs/sn_ship_prototype.json)
- 批量派发脚本：[`tools/modeling/dispatch.workflow.js`](../../tools/modeling/dispatch.workflow.js)

## 1. 为什么是"半"自动

全自动建模在三个地方必然翻车：需求本身有歧义、风格会漂移、Blender 场景被误改。所以自动化只覆盖"确定性工作"，人工只保留两个决策点：

| 阶段 | 谁做 | 自动化程度 |
| --- | --- | --- |
| 需求 → 工单 | Lead + 人工批准 | 半自动（Lead 起草，人点头） |
| 派发 → 建模 | Builder 子代理 | 全自动 |
| 自动质检 | Verifier 子代理 | 全自动 |
| 视觉验收 / 返工判断 | 人工 | 人工 |
| 归档 / 导出 / 登记 | Lead | 全自动 |

## 2. 角色与写权限（最重要的一条）

| 角色 | 由谁担任 | 职责 | 可写 Blender |
| --- | --- | --- | --- |
| **Lead**（调度） | 主代理 | 写工单、派发、汇总、卡门禁、验收后落盘归档 | **否**（Builder 工作期间不碰场景） |
| **Builder**（建模） | `spawn_teammate` 或 workflow `agent()` | 在 Blender 里创建对象、材质、层级、自检 | **是（唯一写者）** |
| **Verifier**（质检） | 另一个子代理 | 只读核验 + `look` 截图判断 + 出 JSON 报告 | **否** |
| **Human** | 你 | 批准工单、验收成品、决定返工 | — |

**单写者锁**：Blender 是单实例共享场景。任意时刻只允许一个 Builder 写；Verifier 必须在 Builder 结束之后运行；Lead 在 Builder 运行期间只做只读或非 Blender 的工作。

## 3. 状态机

```text
DRAFT ──人工批准──▶ APPROVED ──派发──▶ BUILDING ──▶ AUTO_QA
  ▲                                                │
  │                                                ▼
  └──退回重写（记录原因）◀── REWORK ≤ 2 ◀──── HUMAN_REVIEW ──通过──▶ DONE
```

- `REWORK` 每轮必须写明**失败项**与**修正目标**；禁止"为了过检查而改需求"。
- 超过 2 轮仍不过 → 退回 `DRAFT`，由人工重新定义工单。

## 4. 工单契约

工单必须**自包含**（子代理不共享主会话上下文）。字段见 `_template.json`，关键项：

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `id` | ✓ | 唯一工单号，同时用于对象/文件命名 |
| `category` | ✓ | `ship` / `prop` / `building` / `module` / `ui` |
| `style` | ✓ | 低模、flat shading、调色板、参考图 |
| `dimensions` | ✓ | 长宽高 + 容差（米） |
| `tri_budget` | ✓ | 三角面上限，防止子代理过度建模 |
| `required_parts` | ✓ | 必须包含的部件清单（验收依据） |
| `materials` | ✓ | 材质名与数量（3–5 个，禁止贴图） |
| `naming` | ✓ | `SN_` 前缀 + 集合名 |
| `transform` | ✓ | 轴心（地面/水线/中心）、前向轴、单位 |
| `hierarchy` | ✓ | 根空物体、需要动画的 Pivot |
| `scene_rules` | ✓ | 禁止修改/删除的现有对象 |
| `deliverables` | ✓ | `.blend` / `.glb` / 生成脚本 / 截图路径 |
| `acceptance` | ✓ | 可机器判定的验收条件 |

## 5. 两条派发路径

### A. 单件派发（推荐日常使用）

Lead 按顺序执行：

```text
1. ask_user_question  ← 人工批准工单（半自动的那一半）
2. team_task_create   ← 把工单登记到共享任务板
3. spawn_teammate(name="modeler-<id>", prompt=BuilderPrompt(brief))
4. wait_agent         ← 等待 Builder 完成
5. spawn_teammate(name="qa-<id>", prompt=VerifierPrompt(brief)) 或 Lead 自检
6. Lead 用 look 出 3/4 截图 → ask_user_question  ← 人工验收
7. 通过：Lead 落盘 .blend / .glb / 生成脚本 + 更新 ASSET_MAP
   不通过：send_message 把失败项发给 Builder，最多 2 轮
```

### B. 批量派发（多物品排队）

用 DSH `workflow` 工具运行 `tools/modeling/dispatch.workflow.js` 的内容，`args = { "briefs": [ ... ] }`。

脚本**串行**执行（`for` + `await`，不用 `parallel`/`pipeline`，否则多个 Builder 会同时写同一个 Blender 场景）。它只做「建模 + 自动质检」，返回结构化结果；人工门禁在脚本外部完成。

## 6. 提示词模板

### Builder Prompt

```text
你是 Steam Navigator 的建模子代理（Builder），在用户正在运行的 Blender 4.4（已连接 Blender MCP）里工作。

【绝对规则】
1. 只允许创建新对象；禁止删除或修改场景中已有对象（Camera、Light、SN_Ship_Prototype 及其子对象）。
2. 只在集合 <collection> 内工作，所有新对象必须以 <prefix> 开头；若集合已存在（重跑），
   只能删除/重建该集合内以 <prefix> 开头的对象。
3. 不要保存 .blend、不要导出 .glb、不要新建灯光或相机（落盘由 Lead 在人工验收后执行）。
4. 所有写操作通过 mcp__blender__execute_blender_code 完成；几何必须由**参数表**生成，
   便于以后改数值重建，不要手工摆点。

【共用约定】
- 单位米（1 unit = 1 m），+X 为前方，+Z 向上；轴心 <pivot>。
- 低多边形：flat shading，无贴图，材质只用工单列出的 3–5 个。
- 层级：根空物体 <root>，按部件命名；需要动画的部件挂 Pivot 空物体。
- 曲面对称件用参数化放样（横剖面站 + 剖面线），不要用布尔。

【工单】
<brief JSON>

【执行步骤】
1. mcp__blender__get_scene_info 确认场景与目标集合当前状态（只读）。
2. execute_blender_code 执行参数化建模脚本，创建集合并生成全部部件。
3. 只读自检：对象清单、三角面数、包围盒、材质、非流形边 / 退化面 / 孤立点、材质槽越界。
4. 按 schema 返回 JSON（不要输出建模过程代码，只返回结果）。

失败或超出预算时，不要静默降低需求；在 notes 里写清原因。
```

### Verifier Prompt

```text
你是独立质检子代理（Verifier），只读，不得修改场景。

【工单】
<brief JSON>

【检查项】
1. 命名与集合：新增对象是否全部 <prefix> 开头、是否都在 <collection>；
   用 get_scene_info(root="<root>") 与只读代码列出。
2. 几何：三角面 <= tri_budget；无孤立点 / 退化面 / 材质槽越界；闭合件无非流形边。
3. 尺寸：包围盒与 dimensions 的误差 <= tolerance。
4. 材质：名称与工单一致；单层曲面（帆/布/板）必须双面。
5. 回归：原有对象（Camera、Light、SN_Ship_Prototype 等）数量、名称、位置未变。
6. 视觉：调用 mcp__blender__look（mode="angles", views=["three_quarter","front"],
   shading="material"），判断轮廓是否可辨认、比例是否合理。

【规则】
- 只读！禁止任何创建/删除/修改操作；execute_blender_code 只允许读语句。
- 不以"通过检查"为目标；发现问题必须写进 failures，并给出可执行的修正建议。

【返回】{ "passed": bool, "failures": [...], "checks": [...], "notes": "..." }
```

## 7. 自动质检清单

| 检查项 | 方法 | 通过标准 |
| --- | --- | --- |
| 命名 | 只读遍历集合 | 100% `<prefix>` 开头，无重名 |
| 集合归属 | 只读遍历 | 全部在目标集合，无泄漏 |
| 面数 | 三角化计数 | ≤ `tri_budget` |
| 网格健康 | bmesh | 无孤立点、退化面、材质槽越界；闭合件非流形边 = 0 |
| 尺寸 | 世界包围盒 | 与 `dimensions` 误差 ≤ `tolerance` |
| 轴心/朝向 | 矩阵分解 | 轴心符合 `transform.pivot`，前向 +X |
| 材质 | 材质槽 | 与工单一致，数量 3–5，单层曲面双面 |
| 回归 | 对象快照 | 原有对象未被删除/移动 |
| 视觉 | `look` 3/4 截图 | 轮廓可辨认、比例合理 |

## 8. 归档与命名

```text
.design/<category>/SN_<Name>.blend                    源文件（gitignore，本地）
tools/modeling/generators/sn_<name>_generator.py      参数化生成脚本（入库，可重建）
assets/models/<category>/SN_<Name>.glb                运行时资产（进 res://）
docs/design/ASSET_MAP.md                              增加一行映射
```

> 生成器进 `tools/modeling/generators/` 而不是 `.design/`：`.design/` 被 gitignore，
> 放那里等于"换机器就丢源"。只有 `.blend`、GLB 备份、基线快照这类本地产物留在 `.design/`。

命名：工单 `id` = `sn_<category>_<name>_v<n>`；对象 `SN_<Part>`；集合 `SN_<Name>_Prototype`；Pivot `SN_<Part>_Pivot`。

## 9. 与 Godot 工程的对接

- 建模产出 `.glb` 直接落 `assets/models/<category>/`，Godot 导入为 `PackedScene`；
- 轴向：Blender +X 船首 → glTF +X → Godot 需绕 Y 轴 +90°（引擎前方 −Z）；
- 轴心：船用「中部水线」、道具用「地面中心」，1 unit = 1 m；
- 数据绑定：`dev_mods/core/content/*.json` 增加 `visual` 字段（资源路径或 visual_id），
  对应 schema 与 `ShipVisualLibrary` 一起改；
- 2.5D 固定舞台的机位、socket、灯光与 2D 回退策略见 [2.5D_STAGE_PLAN.md](2.5D_STAGE_PLAN.md)；本文件只负责资产生产与交付；
- 模组安全：当前只允许内容包提交 JSON / 图片 / 音频，若要支持模组自带 `.glb`，需单独评审白名单变更。

## 10. 已验证的能力与边界

**实测（本轮探针子代理）**：子代理可以直接调用 Blender MCP 工具（`get_addon_status` / `get_scene_info` 均成功），Blender 4.4.3、addon 1.8、场景 38 个对象（32 mesh + 4 empty + 1 light + 1 camera）。因此「子代理真正上手建模」这条路是通的。

已知边界：

1. **单实例 Blender**：没有并行写能力，批量必须串行；
2. **子代理不共享上下文**：工单必须自包含，禁止"参见上文"；
3. **workflow 脚本无法向人提问**：人工门禁必须在脚本外；
4. **`get_scene_info` 默认只列顶层对象**：列子级要用 `root="<Root>"`，集合信息要靠只读代码；
5. **EEVEE 预览依赖场景灯光**：验收截图前确认相机/灯光可用，或直接用 `look` 的自动取景。

## 11. 样板

### 11.1 SN_Ship_Prototype（第一个资产，手工迭代）

| 环节 | 实际结果 |
| --- | --- |
| 工单 | `briefs/sn_ship_prototype.json` |
| 建模 | 4 轮迭代（比例 → 艉楼 → 桅帆 → 腰板），单脚本参数化生成 |
| 自动质检 | 36 对象 / 32 网格 / 2608 三角面 / 5 材质 / 无孤立点与退化面 |
| 人工验收 | 材质渲染预览通过；原 Cube 经确认后删除 |
| 归档 | `.design/ships/*.blend` + `_generator.py`，`assets/models/ships/*.glb`，ASSET_MAP 已登记 |

### 11.2 港口起重机（第一次完整跑通工作流）

| 环节 | 实际结果 |
| --- | --- |
| 工单 | `briefs/sn_harbor_crane.json`（v2：锤头式塔吊，26 × 6.09 × 21.5 m） |
| 派发 | `spawn_teammate("modeler-crane")`；一次建模 + 两轮返工（1.45× 放大 → 改塔吊造型） |
| 自动质检 | 独立 Verifier 子代理三轮只读验收；v2 11/11 通过：34 对象 / 3420 三角面 / 网格零问题 |
| 人工门禁 | 闸门 1 由需求确认；闸门 2 拍板尺寸、材质与造型方向 |
| 归档 | `.design/SN_Asset_Workbench.blend` + `assets/models/props/SN_Harbor_Crane.glb` |
| 过程发现 | Blender 切换文件会让子代理写到错误场景（发生过一次）；造型方向不对时要整机重做而不是改参数；工作台 + 不落盘规则兜住了误写 |

### 11.3 铁港第一批 6 件（批量派发实测）

| 环节 | 实际结果 |
| --- | --- |
| 工单 | `briefs/sn_iron_harbor_batch1.json`（6 件一次派发） |
| 派发 | 1 个 Builder 一次建 6 件，1 个 Verifier 一次验 6 件（逐件派发需要 12 轮） |
| 自动质检 | 7/7 通过：1260 三角面、原点局部化、材质调色板、网格零问题、回归哈希一致 |
| 归档 | 工作台 `SN_IronHarbor_Props` 集合 + 6 个独立 `.glb` |
| 结论 | 小部件必须批量派发；单件派发会让调用数按件数放大 |

### 11.4 铁港第二批 6 件（生成器 + 纯 Python 干跑，推荐做法）

| 环节 | 实际结果 |
| --- | --- |
| 反例 | 第一次按"子代理自己从零设计 6 件"派发：Builder 烧光上下文、一件没建就退出（场景无损失，基线哈希未变） |
| 改法 | **Lead 先写参数化生成器**（`tools/modeling/generators/sn_iron_harbor_batch2_generator.py`），Builder 只做"执行 + 只读自检 + 回报" |
| 干跑 | 新增 `tools/modeling/generators/dryrun_batch2.py`：把 `bpy`/`bmesh` 换成空壳加载生成器，不进 Blender 就能查 tri 预算、包围盒、边界边、非流形边、退化面 |
| 干跑战果 | 抓出两个真缺陷：锥体封盖各复制一份顶点（172 条边界边）、煤堆抖动让包围盒缩水 0.1 m——都在进 Blender 前修掉 |
| 造型返工 | 抓斗首版"上宽下窄"做成漏斗；改为"顶口窄（0.42）/ 中腰最宽（0.747）/ 刃口收拢（0.10）"的蛋形，再把斗口放宽到 0.58 |
| 自动质检 | 6/6 通过：合计 1214 tri（预算 1900）、边界边与非流形边全 0、Godot 侧 12 件全 PASS |
| 结论 | "Lead 写生成器 + 干跑 + Builder 执行"比"让子代理自己设计"少 3–4 轮往返，几何缺陷在进 Blender 前就被拦住 |

### 11.5 铁港第三批 6 件（流程固化为可复用脚本）

| 环节 | 实际结果 |
| --- | --- |
| 干跑通用化 | 抽出 `tools/modeling/generators/dryrun_props.py`，传生成器路径即可校验（默认跑第三批）；第二批的 `dryrun_batch2.py` 保留 |
| 干跑战果 | 揪出吊货网最低点在 z=0.02（角环悬空、原点没贴地），修正后 `ALL OK` |
| 建模 | Builder 一轮执行通过：6 件 1024 tri（预算 1300），四项健康全 0 |
| 自动质检 | Godot 侧 18 件全 PASS（前两批 + 本批）；场景 90 对象 / 82 mesh / 8 材质 |
| 结论 | 单批从"写生成器"到"Godot 验收通过"约 10 分钟，Builder 只需 1 轮 |

### 11.6 铁港第四批 6 件（Builder 复核反哺设计）

| 环节 | 实际结果 |
| --- | --- |
| 干跑战果 | 锚链堆最低链节中心多算了 1 mm（zmin=0.001），修正后 `ALL OK` |
| Builder 反哺 #1 | 回报"链节是实心方块，低角度更像散落金属条" → 把链节改成**带孔的方形环**（4 边环 32 tri/个，11 个共 352 tri，仍在 1.5× 上限内） |
| Builder 反哺 #2 | 回报"齿轮内端面 y=0.400 与箱体 +Y 面同面" → 齿轮内缩 5 mm，Builder 复验确认该平面上只剩箱体 1 个多边形 |
| 自动质检 | 6 件 1452 tri（预算 1600），四项健康全 0；Godot 侧 24 件全 PASS |
| 结论 | 让 Builder 做"独立复核 + 视觉挑刺"确实能捞到 Lead 自己看不见的共面与读感问题；两处都是改了生成器参数重跑，没有手工补丁 |

### 11.7 铁港第五批 7 件（收官批次）

| 环节 | 实际结果 |
| --- | --- |
| 干跑战果 | 揪出三处：旗面是开放单层（10 条边界边）、煤溜槽超宽 0.15 m、锅炉阀门管装错轴导致 Y 超 0.385 m |
| 旗面处理 | 改成"前后两张波浪网格 + 四周边缘"的 14 mm 厚闭合薄板，仍然是低模布面但网格水密 |
| Builder 反哺 | 抓到两个**数据全对但空间关系错**的悬空：煤溜槽 4 条腿离料斗 0.19 m（整组悬空）、龙骨墩铁箍离锥面 0.06–0.10 m |
| 修法 | 支撑腿改成斜撑、顶环收进到漏斗壁内（z=1.30 处半宽 0.55）；铁箍改成"内壁贴合锥面"的矩形环箍；斜槽低端落到 z=0 |
| Builder 复验 | 用 BVH 求交确认料斗与 8 个部件全部真实相交；铁箍内壁间隙 0.000000 m |
| 自动质检 | 7 件 1232 tri（预算 2100），四项健康全 0；Godot 侧 **31 件全 PASS** |
| 收官 | 铁港道具 31 件 / 6282 tri 全部交付，工作台 103 对象 / 95 mesh / 8 材质 |

### 11.8 大型明轮蒸汽货轮（第一次"大船 + 人工追加需求"全流程）

| 环节 | 实际结果 |
| --- | --- |
| 人工门禁 1 | 船型二选一：明轮蒸汽货轮 / 双烟囱远洋货轮；尺度三选一：55 / 90 / 35 m。人工选「明轮 + 55 m」，工单 `briefs/sn_paddle_freighter.json` 落盘 |
| Lead 生成器 | `sn_paddle_freighter_generator.py`：18 站放样 hull + 甲板/舷墙/艏楼/艉楼 + 双明轮 + 轮罩 + 双烟囱 + 锅炉围罩 + 桥楼 + 4 舱口/4 吊杆 + 双桅横桁 + 救生艇/舵轮/旗；全部参数表驱动 |
| 干跑 | 新增 `dryrun_ship.py`：纯 Python 查 tri / 包围盒 / 边界边 / 非流形 / 退化面 / 命名 / 父级键；**没**查左右对称（教训见下） |
| Builder R0 | 一次执行成功；硬验收全绿，但视觉复核抓到 6 处穿插/悬空（救生艇穿艉楼舷墙、起锚机手柄伸出舷外、舱屋压舱口、天窗穿烟囱、绞盘碰舱口、吊杆跟部悬空 0.20 m） |
| 返工 R1 | Lead 按 Builder 的 fix_hint 改参数（救生艇改吊艇架外挂、起锚机后移 + 手柄转 45°、舱屋缩窄、天窗改小箱、绞盘杆缩短、吊杆加鹅颈箍），2 项清零、4 项仍有交面 |
| 返工 R2 | Builder 低角度左右舷对比抓到**既有 hull 非对称 bug**：`build_hull` 环形放样 `reversed(pts[1:-1])` 漏掉甲板边缘镜像点，右舷少一层列板（0.79–0.86 m）。改 `pts[1:]` 后 hull 306 顶点镜像差 0；13 对目标交面第一次全部清零，R2 passed |
| 人工门禁 2（追加需求） | 人工看近景提「明轮像裸露轮架：补轮缘/辐条/轮叶，加部分遮挡轮罩」 |
| R3 | 明轮 14 桨叶 / 每侧 8 辐条 / 16 段双轮缘 + 内加强环 + 黄铜轮缘条 + 4 斜撑 + 轮毂法兰；轮罩圆弧 `-6°..186°`；新增艏楼/艉楼侧封板 `SN_PF_Raised_Plating`（修掉 R2 报告的侧视空腔）。passed |
| R4 | 人工二次反馈「轮罩仍是窄拱环、整圈裸轮」→ 侧板径向 2.95→3.35 改为 **1.4 m 宽实心半包箱板**（r_in 1.95）+ 中央观察窗 + 黄铜包边/铭牌；视觉达标，但端封板横切轮缘（48 面/侧） |
| R5 | 端封板内径改 `cap_r_in=2.75` 让开轮扫掠（静态 + 0/45/…/315° 八个旋转角 0 交面），内板观察窗放到 `r_in_inner=2.30` 让开蒸汽管斜穿包络，sponson 在蒸汽管经过处开槽；15 对关键交面全 0 |
| 独立 Verifier | 只读全量复核：命名/集合、tri、6 材质与参数、包围盒、网格健康、层级、明轮结构（44 网格岛逐项）、侧封板射线、15 对交面、回归基线、视觉 —— R3 版本 **passed=true，failures=[]**；R4/R5 为人工追加设计轮次，由 Builder 交面矩阵 + Lead 三角化 BVH 复核（15 对全 0、8 个旋转角全 0） |
| 归档 | `assets/models/ships/SN_Paddle_Freighter.glb`（46 节点 / 39 网格 / 6 材质全 doubleSided / 12200 tri / 639.5 KB）；`.design/ships/SN_Paddle_Freighter.blend` 用 `bpy.data.libraries.write` 只打包集合（不切文件）；工作台保存于 `.design/SN_Asset_Workbench.blend`（149 对象） |
| 过程发现 | ① 干跑只查数字不查**对称**，hull 镜像缺点的靠 Builder 低角度侧视才抓到 → 大船验收必须加"左右镜像差"与"低角度侧视"两项；② `BVHTree.FromObject` 对父子对象在各自局部空间，跨对象直接 overlap 会出假阳性，必须用世界坐标 `FromPolygons`；③ 轮罩"看上去像什么"由**径向板宽**决定：0.4 m 窄环 = 裸轮框，1.4 m 半包板 = 明轮箱，光加桨叶/辐条不够 |

### 11.9 1795 双桅纵帆船（SN_Schooner_Fame，R0 → R4）

| 环节 | 实际结果 |
| --- | --- |
| 需求门禁 | 用户给 1795 Salem 名船 Fame 的绘画，要求替换港口旧帆船；选「新建资产 + 替换场景实例」、精度「风格化精修 ≈1.5–1.8 万 tri」；追加「不要星条旗」 |
| Lead 生成器 | 18 站放样黑/赭黄船体 + 双桅后倾 + 斜桁帆/方顶帆/三角顶帆 + 两面艏三角帆 + 完整索具 + 艉廊/FAME 铭牌 + 红白长旒；帆腹镜像到 −Y 对齐 Godot 港口相机侧 |
| 干跑盲区（教训 1） | 第一版 dryrun 直接累加 Part 原始顶点，**没有对 FORE/MAIN 施加 Pivot 平移/旋转**，导致 bbox 少 0.4 m、也无法发现“两桅世界坐标重合”；修复：驱动 `mast_to_world()` 后累加，并新增两桅轴距/后倾/主桅更高三条断言 |
| 装配 P0（教训 2） | `build_all()` 给 FORE/MAIN 的 `_make_object` 传了 `mast_pivot_world()` 作为 origin，而 Part 本来就是 Pivot 局部坐标 → 减一次、父级再加回，**两桅在世界坐标完全重合**；同时 Pivot 没设 `rotation_euler.y`，rake 从未生效，索具/艏三角帆/长旒全部悬空。修复：`origins` 全零 + `pivot.rotation_euler[1]=radians(rake)` |
| 返工 | R1 修复双桅/后倾；R2 修艉廊窗框镜像 0.020、FAME 被舵头遮挡；R3 修艉柱与艉廊面板共面黑斑；R4 把艉柱上段再收 20 mm，原黑斑带 0 命中 |
| 自动质检 | 终版 32 对象 / 29 mesh / 3 empty / **13174 tri**（预算 18000）/ 12 材质 / bbox **33.44 × 6.88 × 26.82 m** / 双桅轴距 6.39 m / Sails×Deck=0 / Headsails×Mast_Fore=156 / 长旒→主桅 0.0425 m / 艉廊镜像 0 / 铭牌后视 96/96 无遮挡 / 非流形·退化·孤立点 0 |
| 独立 Verifier | R0 `passed=false`（P0 双桅重合）；R1 独立复算后 **passed=true**，只余 3 项 P2；R4 终版可归档 |
| 归档 | `assets/models/ships/SN_Schooner_Fame.glb`（32 节点 / 29 网格 / 13174 tri / 720.9 KB）+ `.design/ships/SN_Schooner_Fame.blend`（32 对象快照）；港口样片 `harbor_diorama.tscn` 浮船实例替换为新船，水面泡沫环同步改 13.2×3.9 |
| 过程发现 | ① **Pivot 部件不要既减原点又在父级加回**：局部部件必须 `origin=(0,0,0)`，否则世界坐标退化为局部坐标；② 干跑必须复刻 Blender 的装配变换（Pivot 位移 + 旋转），否则 bbox 与桅轴类 P0 会漏检；③ 港口相机在 Godot +Z 侧 = Blender −Y，帆腹要朝相机侧镜像，否则游戏里看到的是凹面/暗面；④ 移除星条旗后旗杆段、旗材质、文档三处都要同步清理，避免“残留对象/过期说明” |

### 11.10 可复用部件库 v1（ship_parts，建模期复用）

| 环节 | 实际结果 |
| --- | --- |
| 需求 | 用户问“能否把一些部件抽离，做可替换/可复用的部件”；选择先做**建模期部件库**，不立刻做运行时可换装 GLB |
| 目录 | `tools/modeling/generators/ship_parts/`：`core.py`（Part/向量/基本体/PartSpec）、`deck.py`（甲板属具）、`bow.py`（艏斜桁/艏饰）、`stern.py`（艉廊/艉灯）、`assembly.py`（Blender 装配/材质/文字/report）、`palette.py`（共享材质名）、`README.md`（契约） |
| 抽离边界 | 低耦合件先抽：舱口/天窗/绞盘/起锚机/舵轮/罗经柜/钟/木桶/盘绳/缆柱/水桶/fife rail/短梯、艏斜桁/jibboom、艏饰、艉廊；hull/deck/bulwark/wales/keel/channels/rigging 仍留在船型生成器（与站表/曲面强耦合） |
| 生成器 | `sn_schooner_fame_generator.py` 只保留船型参数、hull/桅帆/索具/艏部锚架等船型相关几何，以及 `build_config()`；Blender 装配全部走 `ship_parts.assembly.build_collection()` |
| 基线锁 | 重构前保存两份基线：纯 Python 逐对象 verts/faces/tris/material/parent digest（`.design/schooner_baseline_geometry.json`）与 Blender 世界坐标/局部坐标/面材质 digest（`.design/schooner_blender_baseline.json`） |
| 验收 | 重构后纯 Python digest **0 差异**；dryrun `ALL OK`、12994 tri、bbox/材质/命名不变；Builder 重建后 Blender 逐对象 world/local/polys digest **0 差异**（32 对象 / 29 mesh / 3 empty / 13174 tri；196 个既有对象零漂移）；`importlib` 加载与无 `__file__` 时 `bpy.data.filepath` 回退均已验证 |
| 契约 | 单位米、+X 船首/+Z 向上；部件函数只收位置/尺寸/材质名，不 import 船型站表；`Part` 不含 bpy；`PartSpec(name, part, parent, origin, sockets, tags)` 预留给后续运行时可替换件 |
| 后续 | ① 把 masts/sails/rigging 抽成 `rig_kit`（参数化桅距/帆装）；② 增加第二艘船型验证复用；③ 等 2.5D 舞台立项后，再从同一份部件源码导出独立 GLB + `SN_Socket_*` + `parts_manifest.json`，不在生成器里维护第二套几何 |
