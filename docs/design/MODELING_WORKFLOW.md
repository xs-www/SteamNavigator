# 物品建模半工作流（Modeling Dispatch Workflow）

> 一句话：把「我要一个 X」变成一张标准工单，由 Lead 自动派发给建模子代理，子代理在 Blender 里参数化建模，独立质检子代理验收；人工只在**开工前**和**交付前**各点一次头。
>
> 管线边界：本工作流固定使用 **Blender MCP** 直接操作活体 Blender；**除非用户明确指定，否则不考虑 BMH**（`D:\桌面\sisi_apps\BMH` 仍在开发中），不要运行 `bmh` 命令，也不要把 BMH 当作默认建模管线。

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
| `category` | ✓ | `ship` / `prop` / `building` / `module` / `weapon` / `ui` |
| `style` | ✓ | 低模、flat shading、调色板、参考图 |
| `dimensions` | ✓ | 长宽高 + 容差（米） |
| `tri_budget` | ✓ | 三角面上限，防止子代理过度建模 |
| `required_parts` | ✓ | 必须包含的部件清单（验收依据） |
| `materials` | ✓ | 材质名与数量（3–5 个；**新资产必须使用共享贴图材质**：`SN_Tex_*` + `shared_materials/<texture>.png` + `tile_m`，禁止用纯色代表材质；spec 见 §12） |
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
| 材质 | 材质槽 / UV | 与共享材质 spec 一致，全部槽绑定 512² 共享贴图；UV 完整（`len(uv) == len(loops)`）；单层曲面双面 |
| 回归 | 对象快照 | 原有对象未被删除/移动 |
| 视觉 | `look` 3/4 截图 | 轮廓可辨认、比例合理 |

## 8. 归档与命名

```text
.design/<category>/SN_<Name>.blend                    源文件（gitignore，本地）
tools/modeling/generators/sn_<name>_generator.py      参数化生成脚本（入库，可重建）
assets/models/<category>/SN_<Name>.glb                运行时资产（进 res://）
docs/design/textures/shared_materials/tiles/*.png     共享材质贴图授权源（入库）
assets/models/<category>/shared_materials/*.png       共享贴图开发态副本（GLB 相对 URI）
dev_mods/core/assets/models/<category>/SN_<Name>.glb  Core 模组运行时副本
dev_mods/core/assets/models/<category>/shared_materials/*.png  Core 模组共享贴图
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
- 武器/模块不规则形态的挂载契约（Mount 帧 / mount_class / base_footprint / envelope / anchors）见 [WEAPON_SOCKET_CONTRACT.md](WEAPON_SOCKET_CONTRACT.md)；
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
| 后续 | ① ~~把 masts/sails/rigging 抽成 `rig_kit`~~ —— **✅ M0-4 已完成**（2026-10-22，见 §11.18）；② 增加第二艘船型验证复用（M0-4 已用 PF/SF/IC 三型验证）；③ 等 2.5D 舞台立项后，再从同一份部件源码导出独立 GLB + `SN_Socket_*` + `parts_manifest.json`，不在生成器里维护第二套几何 |

### 11.11 港口起重机四件套（2026-10-21，塔吊生成器补全 + 三件新起重机）

| 环节 | 实际结果 |
| --- | --- |
| 需求 | 人工指定四种：塔吊（补全此前缺失的生成器）、大型龙门吊（巨型钢结构 + 复杂传动）、木制桅杆起重机（参考图：黑白港口照片的钢构 / 码头语言）、手摇悬臂吊。工单 `briefs/sn_crane_batch1.json` 自包含尺寸 / 预算 / 必含件 / 验收 |
| 生成器与部件库 | 新增 `crane_kit.py`（桁架臂 / 格构柱 / 梯子 / 栏杆 / 车轮 / 卷筒 / 滑轮 / 齿轮 / 钢缆 / 吊钩组 / 手摇绞车，纯 Python 复用 `ship_parts.core`）+ **共享贴图材质库 `sn_shared_materials.py`**（spec → `SN_Tex_*` 材质节点 / 世界空间盒式 UV / 验收，见 §12）+ 资产侧视图 `sn_crane_materials.py`（`MAT_*` 常量 / 每资产白名单 / 回退色）+ 4 个生成器；装配统一走 `ship_parts.assembly.build_collection()`，随后 `apply_collection()` 写材质与 UV |
| 干跑 | `dryrun_cranes.py` 一次校验四件：前缀 / 父级 / 预算 / bbox / 边界边 / 非流形边 / 退化面 / 材质白名单 / zmin=0 / 必含对象；新增 **PivotSpec 契约检查**（`rotation` 必须三元组、`location` 必须等于 `origins` 对应值） |
| Builder R0 | 第一轮在生成器 1/4 处失败：`PivotSpec(..., (0,0,PIVOT_Z), 1.4)` 把 `size` 当成 `rotation` 传进去，`rotation_euler` 收到 float 报 ValueError。Builder 按规则停止并回报 traceback，未手工修补；Lead 改成 `size=1.4` 后重跑 |
| Builder R1 | 四件一次执行成功：塔吊 33 对象 / 3912 tri；龙门吊 20 / 9420 tri；木制桅杆 11 / 1932 tri；手摇悬臂 7 / 896 tri。只读自检：网格健康四项全 0、四件 zmin=0、塔吊 Pivot 挂 21 个旋转件、吊钩最低点 4.42 m（3–6 m 内）、其它 11 个集合对象数逐一不变、场景 261→298 与公式一致、无新增相机灯光 |
| 导出与自检 | `export_cranes_glb.py` 逐件根节点归零导出并保存工作台（旧塔吊 GLB 已备份到 `.design/props/backup_glb/`，并同步 `dev_mods/core` 副本）；`verify_cranes_glb.py` 4/4 通过（**世界空间** bbox 按节点 TRS 合成）；`tools/godot/verify_cranes.gd` 4/4 PASS（尺寸 / tri / 材质 / 贴地） |
| 共享贴图轮（R2，2026-10-21） | 按人工“不再用纯色代表材质”的要求：新增 `shared_materials` 10 张 512² 无缝贴图（spec + 生成器 + montage + stats）、`sn_shared_materials.py`（`SN_Tex_*` 材质 / 世界空间盒式 UV / 验收）与 `verify_crane_materials.gd`；四台起重机全部加 UV 并改用 `SN_Tex_*` 材质，导出时把内嵌贴图外部化为 `shared_materials/<texture>.png`（授权源字节）并同步 Core；`verify_cranes_glb.py` 4/4、Godot 材质验收 4/4（10 个共享 Texture2D 实例、0 失败）；旧纯色 `SN_*` 材质保持不动 |
| 过程发现 | ① **`PivotSpec` 位置参数顺序是坑**：`(key, name, location, rotation=(0,0,0), size=1.2)`，多写一个位置参数就把 float 塞进 rotation；干跑已补契约检查，后续 pivot 类资产必须先过这条。② **多节点 GLB 的 bbox 不能直接累加 accessor min/max**：Pivot 子件的坐标是父级局部坐标，必须按 glTF 节点层级合成 TRS 再求世界包围盒，否则会把塔吊高度算成 30.5 m。③ 木制桅杆起重机按历史木质桅杆 / 后倾吊臂 / 拉索 / 手摇绞车设计，照片里的钢构塔吊只作为码头语言参考，不照搬。④ 新增三件已接入 Core manifest + 共享贴图，PortStage 槽位仍待接。⑤ **材质与模型分离**：材质 / 贴图 spec 与 `SN_Tex_*` 共享贴图材质库见 §12；旧纯色 `SN_*` 材质被大量旧对象共用，不能原地改，新资产用 `SN_Tex_*`；GLB 材质定义仍随文件内嵌（glTF 无外部材质引用），但贴图外部化为共享 URI，运行时按路径共享 `Texture2D` |
| 预览与截图 | `.design/props/preview/crane_<asset>_{three_quarter,side}.png`（8 张，本地产物） |

### 11.12 模型素材库批次 1（2026-10-21，武器套件 + 船体部件）

| 环节 | 实际结果 |
| --- | --- |
| 需求 | 人工给出两组 P0 素材：`weapon_kit` 火炮 / 炮架 / 炮塔 / 武器基座，`ship_parts` 甲板 / 桅杆 / 烟囱 / 货舱盖；目标是「后续搭建的模型素材库」，即模块化、可拼装，而不是 8 件孤立道具。工单 `briefs/sn_kit_batch1.json` 自包含尺寸 / 预算 / 接口清单 / 验收条件 |
| 设计 | 先定**拼装契约**再建模：每件资产固定 `SN_<Asset>_Mount` + 语义接口空节点（Trunnion_L/R、Socket_*、Exhaust、Hinge、Collar…）；甲板是母模块，提供 5 个 socket；火炮是唯一「根 = 耳轴轴心」的子件，炮架耳轴 socket 高度 0.62 与之对齐；其余件根在底面中心 z=0 |
| 生成器 | `kit_batch1_generator.py` 一份参数表产出 8 件（共用 `weapon_kit.py` + `ship_parts.core`）；`sn_kit_materials.py` 提供每件材质白名单；`gen_kit_catalog.py` 从纯几何导出 `tools/modeling/kit_catalog.json`（机器可读目录，不再手写尺寸表） |
| 干跑 | `dryrun_kit_batch1.py` 一次校验 8 件：命名 / 父级 / tri / bbox / 基准面 / 网格健康 / 材质白名单 / 共享贴图 / Mount+socket 命名与坐标 / 左右对称 / 各件 datum 断言；**新增 mesh 名与 socket 名重名检查** |
| 首次构建发现 | Builder 回报全绿，但场景对象里出现 3 个 `.001` 后缀：Cannon 的 `Breech`、Pedestal 的 `Collar`、Mast 的 `Top` 与同名 socket 冲突。干跑只查「parts 字典」，查不出 Blender 的对象命名空间冲突 → 修生成器（BreechBlock / CollarRing / Platform），并给干跑补上同名检查，重建后零 `.001` |
| 构建 | Builder R1（8 件，11,316 tri）+ R2（命名修复后幂等重建）+ R3（Verifier 修复 + 桅顶瞭望台，11,964 tri）：对象/网格数、tri、bbox、zmin、材质、UV、root extras、网格健康四项全绿；非 kit 对象名 SHA-256 与基线一致；Camera=2 / Light=1；场景 476 objects / 351 mesh / 31 collections |
| 独立 Verifier | 只读复核 8 件 + 拼装对齐 + 视觉 3/4 与正视。**3 项真缺陷**：① 炮塔 Yaw 子 socket 用根坐标挂在 z=0.22 的 Yaw 下 → 整体高 0.22 m；② 炮塔 Anchor_1..4 在四角 (±1.55,±1.55)，半径 2.19 > 基座 1.72，悬空 0.533 m；③ 甲板实际 22 条铺板，工单写 24 条。另报 P2：Heavy 炮塔放到原 weapon socket 会出甲板边缘 0.32/0.52 m |
| 返工 R3 | 修 3 项失败 + P2：Yaw 子 socket 改局部坐标（world = +0.22）、Anchor 收到底座环 r=1.5/z=0.20、甲板改 24 条铺板、weapon socket 内移到 (±2.30,1.10)；干跑补「Yaw 子节点世界高度」「Anchor 到环半径」「deck socket 在甲板内且能承载 Heavy 炮塔」断言 |
| 人工验收反馈 | 用户指出「桅杆的观望台不应该在最顶上吗」→ 把驻人平台从下桅头 7.9 m 移到桅顶 12.08–12.16 m，补三面半栏杆（-X 留登台梯口）、长梯（下端落到上横桁 z=10.40）+ 3 道支撑、4 根斜撑与黄铜单筒望远镜，新增 `SN_ShipPart_Mast_Lookout` 接口；下桅头只保留 trestle/crosstree 结构 |
| 复检 R4 | 独立 Verifier 复检 3 件修复 + 桅顶瞭望台：**0 failures**；P2 观察「短梯下端悬空」→ 梯子下延到上横桁并加梯脚卡箍，桅杆 2640 → 2764 tri（预算 2700 → 2800），复检确认瞭望台最高点 12.706 ≤ 12.84 |
| 归档 | 8 个 GLB（`assets/models/{weapons,ship_parts}/` + Core 副本）、共享贴图 10 张 ×2 目录、预览 lineup / 拼装图 / 单件图、[KIT_ASSET_LIBRARY.md](KIT_ASSET_LIBRARY.md)、[KIT_BATCH1_ACCEPTANCE.md](../archive/KIT_BATCH1_ACCEPTANCE.md) |
| 过程发现 | ① **mesh 与 sockets 共享一个对象命名空间**：资产内部 mesh 名与接口空节点同名时 Blender 会静默加 `.001`，GLB 节点名也跟着变；接口名优先，mesh 让位，干跑必须检查。② 模块化资产的验收重点从「单件像不像」变成「接口对不对」：bbox/tri 只是下限，还要断言 socket 坐标、左右对称、父级顺序、跨件对齐（火炮耳轴 → 炮架座）。③ **父级空节点的子 socket 要写局部坐标**：同一份数值既是 world、又是 local 时，会整体偏移父级高度；mesh 有 origin 补偿但空节点没有。④ 素材库要同时交付**人读目录**与**机器目录**（KIT_ASSET_LIBRARY.md + kit_catalog.json），后续 Godot 侧装配直接读 JSON。 |

### 11.13 模型素材库批次 2（2026-10-21，机械 / 货物 / 码头 P1）

| 环节 | 实际结果 |
| --- | --- |
| 需求 | 在批次 1 之后继续做 P1：`machinery_kit` 齿轮 / 卷扬机 / 动力装置，`cargo_kit` 货箱 / 煤斗 / 储罐 / 托盘，`dock_kit` 码头结构 / 栈桥 / 系缆设施；共 10 件，仍作为可拼装素材库。工单 `briefs/sn_kit_batch2.json` |
| 共享材质扩展 | 煤斗需要新材质：在 spec 新增 `SN_Tex_Coal`（碎煤，512²，`kind=coal`，`tile_m=1.0`），生成器新增 `_paint_coal` 画家；重跑生成器后 11 张贴图全部确定性 / 无缝、旧 10 张字节不变；`runtime_dirs` 新增 machinery / cargo / dock 六个目录 |
| 设计 | 机械：动力装置（卧式蒸汽机 + 飞轮）→ 齿轮组（开式机架 + 三级齿轮）→ 卷扬机（绳鼓 + 棘轮 + 曲柄）；货物：托盘/货箱可堆叠、煤斗带碎煤堆、储罐带人孔/阀门；码头：8.4×4.2 m 岸壁模块 + 8×2.6 m 栈桥（桩到水下 z=−1.30）+ 双柱缆桩，`Module_Next/Prev` 沿 X 平铺、`Socket_*` 接收系缆与栈桥 |
| 干跑 | `dryrun_kit_batch2.py` 校验 10 件 + 新增 `SN_Tex_Coal` 存在性；抓出并修掉 mesh/socket 同名 4 处（Crank / Chute / Ladder / Ring）、煤斗材质白名单、储罐人孔零厚面、货箱 zmin=0.1、托盘/货箱/栈桥 bbox 偏差 |
| 构建 | Builder R1 一次建 10 件：13,516 tri；10 集合 / 101 对象；非批次 2 对象名 + 位置 SHA-256 与基线一致；Camera=2 / Light=1；命名零 `.001`、零 mesh/socket 重名；网格健康四项全 0；UV / 贴图 / extras 全绿 |
| 视觉反哺 | Builder 看 3/4 与正视后报：齿轮组正面被实心侧板挡死、系缆绳圈悬空 0.10 m 且穿底板、栈桥铺板 ±X 轻微不对称。Lead 改成开式机架（立柱 + 上下横梁 + 竖撑/轴承）、绳圈落到 base 顶面、铺板对称排布；再修码头爬梯朝向与 Pallet/Crate 叠放面（R2–R4） |
| 独立 Verifier | R1（task-10）报 3 个 P1：Pallet 铜钉顶 0.215 与货箱底互穿 35 mm、Jetty 端梯朝向错误且插铺板、Mooring 木护舷悬空；R2（task-12）确认 3 项修复通过，新发现 Jetty `Ladder` socket 仍停旧位（错位 1.10 m）；R3（task-14）确认 socket 对齐、端梯 2 柱+6 横档+2 上支架贴铺板底、10 件全绿 → **passed=true / 0 failures** |
| 最终结果 | 10 件 **13,680 tri / 预算 20,600**；49 mesh 健康四项 + wire 全 0；11 张共享贴图 512²；GLB 自检 10/10 ALL OK；名称回归 SHA-256 一致；无 `.001` / 无重名 |
| 人工验收反馈 | 用户指出机械 lineup 第一件（PowerUnit）有浮空：飞轮无轴承支撑、调速器悬在汽缸上方。补飞轮贯穿轴 + 两侧轴承立柱落到横跨滑橇的木承梁（梁底 z=0）、调速器移到汽缸顶并加法兰底座；PowerUnit 1984→2260 tri，bbox 不变；Builder 射线自检两柱 5/5 命中承梁 |
| 过程发现 | ① **活体 Blender 会缓存纯 Python 模块**：本次新增 `MAT_COAL` 后，同一 Blender 会话里的 `sn_kit_materials` / `sn_shared_materials` 仍是旧版，首次执行 ImportError；先 `importlib.reload`（或重启 Blender）再跑生成器即可。② 模块化零件要留「可读窗口」：实心机架在 3/4 视角挡住全部齿轮，改开式机架后齿轮传动一眼可读；③ 码头类资产用**水线 datum**（栈桥桩到 −1.30）比强制 zmin=0 更符合摆放语义，干跑需按件声明 zmin 范围。④ **堆叠面要按最高点定 socket**：托盘铜钉/角铁比铺板高 35 mm，用铺板面当 Stack_Top 会让货箱互穿；修复是把压平件压到台面而不是抬 socket。⑤ Verifier 的「接口与几何是否同源」检查非常值钱：端梯搬了位置但 socket 没搬，是纯数据缺陷，渲染图看不出来。 |
| 归档 | 10 个 GLB（`assets/models/{machinery,cargo,dock}/` + Core 副本）、共享贴图 11 张 × 8 目录、预览 3 lineup + 2 拼装图 + 20 单件图、[KIT_ASSET_LIBRARY.md §9](KIT_ASSET_LIBRARY.md)、[KIT_BATCH2_ACCEPTANCE.md](../archive/KIT_BATCH2_ACCEPTANCE.md) |

### 11.14 模型素材库批次 3（2026-10-21，建筑 / 环境 P2）

| 环节 | 实际结果 |
| --- | --- |
| 需求 | 用户指定 P2 两组：`architecture_kit` 仓库 / 工坊 / 酒馆 / 厂房，`environment_kit` 礁石 / 残骸 / 灯塔等；要求继续作为可拼装素材库。工单 `briefs/sn_kit_batch3.json`（8 件、按 4 m 网格平铺、环境件根在水线） |
| 设计 | 建筑 = 「体量 + 立面节奏」：石基座 + 铁包木/石墙 + 双坡或锯齿顶 + 门/雨棚/招牌/烟囱，`Module_Next/Prev` 沿 X 平铺，工坊 `Drive_Shaft` 直接对 `PowerUnit` Shaft_Out；环境 = 水线 datum：礁石宽平顶 + 4.6 m 石砌灯塔基台（`Top` 落座）、横倾 13° 的断船壳（断桅穿甲板落龙骨）、灯塔（环廊 / 灯室 / 穹顶）、浮标（灯 / 钟 / 锚链）。新增根字段 `module_x/y` 与 `waterline` |
| 干跑 | `dryrun_kit_batch3.py` 校验 8 件：命名 / 父级 / tri / bbox / 基准面（建筑 zmin=0、环境水线范围）/ 网格健康 / 材质白名单 / 11 张共享贴图 / socket 契约 / 建筑 module 字段 / 环境 waterline 字段；抓出并修掉 mesh/socket 同名 6 处（Chimney×2 / Gantry / Mast / Gallery / Bell / Chain）、礁石湿痕面拆分导致的非流形、礁石压顶覆盖不足、压舱石悬空 |
| 构建 | Builder R1 一次建 8 件：15,214 tri；8 集合 / 91 对象；共享贴图 8/8 PASS；无 `.001` / 无重名；网格健康四项全 0；批次 1–2 的 577 对象 / 41 集合不变；Camera=2 / Light=1 |
| Builder 几何复核 | 用 world-space BVHTree + raycast 做「无浮空」专项：**真缺陷**① 残骸断桅离最近部件 1.064 m（悬在船体开口上方）→ 断桅改为从龙骨起、加桅座横梁接两舷后 ↔Hull 0.003 / ↔Ribs 0.004 m；② 礁石 Top 平台 2.1×2.1 装不下 4.62×4.60 灯塔基座（外挑 1.3 m）→ 礁石改宽平顶 + 石鼓 + 压顶（circumradius 2.66）+ 4 块礁岩扶壁，16 采样点 0 gap / 0 外挑；③ 压舱石与船底 0.10–0.14 m 悬空 → 按船底内底平面逐颗定 z0，5/5 轻嵌 1 cm（并修掉「顺序标签错位 + 外皮误命中」两处测量根因，最终 gap −0.010 / 颗）；④ 礁石「蘑菇顶」观感 → 石鼓四周加 4 块扶壁并收压顶；用户再报「底部石头没有全部比底座大、边缘悬空」→ 石鼓改等径、外圈加 16 块密排礁岩裙、顶部盖过石鼓底沿（Reef 896→1944 tri），24 方位采样确认底座周边全部有岩石承托 |
| 复检 | 独立 Verifier 只读验收 8 件 + 拼装（建筑街区、礁石+灯塔、残骸+浮标）：接口、bbox、tri、材质、UV、extras、落地/落座、无浮空；**passed=true / 0 failures**；随后导出 GLB 8/8 OK 与预览 8×2 + 2 lineup + 4 拼装图 |
| 最终结果 | 8 件 **16,414 tri / 预算 23,200**；三批合计 **42,058 / 60,300**；42 mesh 健康四项全 0；GLB 8/8 ALL OK；无 `.001` / 无重名 |
| 过程发现 | ① **网格名与 socket 名共享命名空间**的问题在批次 3 再次出现 6 处，干跑的同名检查必须保留；② **「无浮空」要按支撑面测量，不能只看 bbox zmin**：残骸断桅、压舱石、灯塔-礁石落座都是 bbox 正常但空间关系错；raycast/BVHTree 要在 Builder 侧固化为必检项；③ **测量参照面会骗人**：压舱石向下 raycast 可能穿过内底打到外皮，报出「虚大间隙」；应用内底上法线面 + 生成器纯几何回代互相验证，且**按生成器列表顺序**传递逐件偏移，避免标签排序错位；④ 环境件允许 zmin<0（水线 datum），干跑按件声明范围比强制 z=0 更符合摆放语义；⑤ 建筑 / 环境件尺寸大，预览要把 Root 临时抬到水线以上再渲染，否则水下部分被地面挡住。 |
| 归档 | 8 个 GLB（`assets/models/{architecture,environment}/` + Core 副本）、共享贴图 11 张 × 4 目录、预览 2 lineup + 4 拼装图 + 16 单件图、[KIT_ASSET_LIBRARY.md §10](KIT_ASSET_LIBRARY.md)、[KIT_BATCH3_ACCEPTANCE.md](../archive/KIT_BATCH3_ACCEPTANCE.md) |

### 11.15 旧资产 UV 迁移 A（2026-10-22，31 件铁港道具 + 6 件港口设施）

| 环节 | 实际结果 |
| --- | --- |
| 需求 | backlog M0-1：31 件铁港道具 + 6 件港口设施**补 UV、切 `SN_Tex_*`、重导 GLB**；纯材质/UV 改造，不改几何，完成后旧纯色 `SN_*` 从港区退场 |
| 基线 | 先跑 `capture_baseline.py` 记录 37 个旧 GLB：**11 278 tri**（props 6 282 / port 4 996）、80 个图元全部无 `TEXCOORD_0`、9 个旧纯色材质、0 内嵌贴图；tri / 尺寸作为迁移后回归硬约束 |
| 映射 | 9 个旧材质 → `SN_Tex_*`：Wood / Wood_Dark / Metal / Iron / Iron_Red / Brass / Stone 一对一；`SN_Canvas` 与 `SN_Canvas_Shade` 合并到唯一 `SN_Tex_Canvas_Shade`；`SN_Coal → SN_Tex_Coal`；**`SN_Ore → SN_Tex_Iron_Red`**（旧 ORE_BASE 0.155/0.038/0.024 线性 ≈ iron_red 均值 118/56/43，避免为一种材质新增贴图） |
| 生成器 | `sn_legacy_uv_migration.py`（纯数据映射 + Blender 侧迁移/验收）：先按槽位把旧材质换成 `SN_Tex_*`（面索引不变），再调 `sn_shared_materials.apply_to_object(space="local")` 写 `UVMap`；每个对象迁移前后做**几何签名对比**（顶点坐标 + 面顶点索引 + tri + 对象变换 SHA-256）与面材质计数对比，任一变化即失败 |
| 共享材质库扩展 | `sn_shared_materials.apply_to_object()` 新增 `space` 参数（`world` 默认不变，`local` 用于单 mesh 道具/设施，UV 相位不随工作台布局位置变化），并去重"多个旧材质映射到同一 `SN_Tex_*`"产生的重复槽位 |
| 迁移结果 | 37/37 OK：**11 278 tri 不变、24 188 UV loops、9 个共享材质**；几何签名 / 三角面 / 对象变换全部逐位一致，面材质计数按映射守恒；旧纯色材质槽 0 残留 |
| 导出 | `export_legacy_uv_glb.py`：逐件归零导出 → `glb_shared_textures.externalize_glb(prefer_authored=True)` 把贴图变 `shared_materials/<texture>.png` 外部 URI → 旧 GLB 备份 `.design/legacy_uv/backup_glb/` → 同步 `dev_mods/core` 副本 → props / port 各补齐 11 张共享贴图运行时副本 → 保存工作台 |
| 验收 | `verify_legacy_uv_glb.py` **37/37 ALL OK**（tri、图元数、世界尺寸、贴地、材质名、doubleSided、每图元 UV、外部 PNG 与授权 tile 逐字节一致、无内嵌图）；Godot `verify_legacy_uv_materials.gd` **37 件 / 14 个共享贴图实例 / 0 失败**；`verify_props.gd` 31/31、`verify_port_facilities.gd` 6/6、`verify_crane_materials.gd` 回归 4/4；新增 `test_legacy_uv_assets.gd` 2 例守护外部贴图 + 类别内实例共享 |
| 交付 | 37 个 GLB（`assets/models/{props,port}/` + Core 副本）、4 个 `shared_materials/` 目录各 11 张 PNG、迁移/预检/导出/验收 4 个脚本、Godot 运行时验收脚本、[LEGACY_UV_MIGRATION_A_ACCEPTANCE.md](../archive/LEGACY_UV_MIGRATION_A_ACCEPTANCE.md) |
| 过程发现 | ① **活体 Blender 会缓存纯 Python 模块**：改完 `sn_shared_materials` 后首次执行仍用旧签名报 `unexpected keyword argument 'space'`，`migrate_all()` 里先 `importlib.reload` 再跑；② 单 mesh 资产用**局部空间** UV，世界空间会把工作台布局位置（每批 y=24/30/…）烘进 UV 相位，资产挪位后图案会整体漂移；③ 旧 GLB 本来**没有贴图**（纯色材质），"外部化"不是把已有图拿出来，而是首次导出时由共享材质生成内嵌图再替换为外部 URI，因此 `prefer_authored=True` 才能保证 PNG 与授权 tile 逐字节一致；④ 同一类别内共享 `shared_materials/` 才能让 `ContentAssetLoader` 复用 `Texture2D`（props / port 各自一份，跨类别仍不共享）；⑤ 迁移脚本对已迁移对象幂等（再次执行只重写 UV），方便返工时重跑 |


### 11.16 旧资产 UV 迁移 B（2026-10-22，船模块 / 4 艘船 / 旧小镇）

| 环节 | 实际结果 |
| --- | --- |
| 需求 | backlog M0-2：11 件船模块 + 4 艘船 + 旧小镇 10 件补 UV、切 `SN_Tex_*`、重导 GLB |
| 范围修正 | 旧小镇 10 件中 5 栋建筑已在建筑套件批次升级为 `SN_Town_*` trim-sheet LOD0（运行时 GLB 已替换），本次只处理剩余 5 件旧纯色道具；另把 manifest `model.module.boiler` 引用的 `modules/SN_Boiler_Unit` 占位副本一并迁移 → **实际重导 21 个 GLB** |
| 基线 | `.design/legacy_uv_b/baseline.json`：**55 256 tri**（modules 7 492 / ships 45 968 / town 1 796）、118 网格、334 图元（331 无 UV）、18 个旧材质、0 内嵌贴图 |
| 映射 | 18 旧材质 → 10 个 `SN_Tex_*`：`SN_Iron_Hull` / `SN_Hull_Black` → `SN_Tex_Iron`（黑船身保留深色读感）；`SN_Ochre` → `SN_Tex_Wood_Deck`；`SN_White` / `SN_PS_UpperWhite` → `SN_Tex_Canvas_Shade`；`SN_Flag_Red/White/Blue` → `SN_Tex_Iron_Red` / `SN_Tex_Canvas_Shade` / `SN_Tex_Glass_Dark`；其余同名映射；**不新增贴图** |
| UV 空间 | 单 mesh（模块 / 旧小镇 / 铁甲舰）用 `space="local"`；多节点船体新增 `space="root"`（`root.matrix_world.inverted() @ obj.matrix_world`），跨子件连续、不烘入工作台摆位（±45 / −70 / 90） |
| 迁移结果 | 21/21 OK：**55 256 tri / 118 网格 / 对象变换全部与基线一致**，UV loops **111 564**；面材质计数按映射守恒，旧槽 0 残留；`SN_Schooner_Fame` 图元 73→70（3 处 `SN_Canvas` + `SN_Canvas_Shade` 合并，tri 不变） |
| 导出 | `export_legacy_uv_b_glb.py`：单 mesh 逐件归零导出；船体根节点归零后整集合导出（`export_extras=True` 保留 Root extras）；旧 GLB 备份 + Core 同步；仅更新 5 件旧小镇 GLB（不覆盖 5 栋升级建筑） |
| 共享贴图目录 | `shared_materials.spec.json` 的 `runtime_dirs` 补 `port`（批次 A 遗留）/ `modules` / `ships`，共 **22 个目录**；重跑贴图生成器后 11 张 tile 字节不变、deterministic / seam_ok |
| 验收 | `verify_legacy_uv_b_glb.py` **21/21 ALL OK**；Godot `verify_legacy_uv_materials_b.gd` **21 件 / 24 个共享贴图实例 / 0 失败**；批次 A / 道具 / 设施 / 起重机回归全绿；`test_legacy_uv_assets_b.gd` 2 例守护 |
| 交付 | 21 个 GLB（`assets/models/{modules,ships}` + Core 副本 + 5 件 town core props）、4 个新 `shared_materials/` 目录、4 个迁移/预检/导出/验收脚本、Godot 验收脚本、[LEGACY_UV_MIGRATION_B_ACCEPTANCE.md](../archive/LEGACY_UV_MIGRATION_B_ACCEPTANCE.md) |
| 过程发现 | ① 多节点资产必须用根节点局部空间 UV：world 烘摆位、local 让子件图案互相错位；② 多旧材质映射到同一 `SN_Tex_*` 时同 mesh 槽位合并、glTF 图元数下降，验收应以 tri / 节点 / 网格为几何不变量；③ 旧小镇 5 栋建筑已被建筑套件取代，不能按旧 backlog 字面重导，否则会把升级后的 GLB 覆盖回旧模型；④ `modules/SN_Boiler_Unit` 是 props 锅炉的占位副本，对象住在 `SN_IronHarbor_Props`；⑤ 纯白 / 彩旗没有对应贴图，按"不新增贴图"映射到最接近的共享材质（明轮客船二级白层次合并） |




### 11.17 船侧武器安装点 M0-3（2026-10-22，4 艘船 14 个空节点）

| 环节 | 实际结果 |
| --- | --- |
| 需求 | backlog M0-3：4 艘可玩船各加 2–4 个 `SN_Socket_Weapon*` 空节点 + `socket_class / clearance_*` extras；**不要求整块甲板，空节点即可，禁止动几何** |
| 设计 | 先定净空口径再选点：安装面以上 0.12 m 做 16 向水平射线得 `clearance_r`，socket 局部 ±X / ±Y 得 `clearance_x/y`，向上射线得 `clearance_h`（露天封顶 20 m）；侧舷点 rotZ ±90° 让 +X 指向舷外、local Y 沿船体纵轴，炮列按 `clearance_y` 判长度。声明值一律**低于实测 0.05 m**，脚本断言实测 ≥ 声明，不达标直接抛错 |
| 选点 | 用 16 向扫描 + 甲板 down-ray 逐点比较，避开舱口/烟囱/舱室/舵轮柜/救生艇吊架：PF 前侧舷 2 + 后侧舷 2（Side + Light），PS 艏甲板 2（Light）+ 艉上层甲板 1（Medium），SF 艉楼 2（Light）+ 艏 1（Medium），IC 炮房前 2（Heavy）+ 后甲板 2（Medium）。z 取该点甲板实测高度（同船不同点 1.91–4.60 m） |
| 生成器 | `sn_ship_weapon_sockets.py`：纯 Python `SHIPS` 规格表 + `DECK_Z_EXPECTED`、`validate_spec()`（2–4 个/船、命名、class、镜像、clearance 上限）、Blender 侧 `apply_all()`（幂等重建只删本前缀空节点、实测/断言/写 extras/Root extras、逐集合 mesh/tri/材质/对象名快照比对）与 `verify_all()` 只读复核；`--check` 可纯 Python 干跑 |
| 构建 | Builder 子代理原样执行一次：4/4 `passed=true`、`failures=[]`、`removed=[]`（未删既有对象）；场景 objects 693→707（+14 全为 EMPTY）、mesh 445 不变；几何快照 PF 39/12200、PS 32/11764、SF 29/13174、IC 1/8830 前后一致 |
| 导出 | `export_ship_weapon_sockets_glb.py`：4 个 GLB 重新导出（铁甲舰改为 `export_extras=True` 并连同 socket 子空节点一起导出）、共享贴图外部化、旧 GLB 备份 `.design/ship_sockets/backup_glb/`、同步 Core 副本；导出后 `glb_ship_sockets.standardize()` 把 `SN_PF_Socket_Weapon_*` 归一化为 `SN_Socket_Weapon_*` 并写 Root `weapon_sockets` 列表。GLB 节点数 46→50 / 35→38 / 32→35 / 1→5 |
| 验收 | `verify_ship_weapon_sockets_glb.py` **4/4 ALL OK**（节点/网格/图元/tri/世界尺寸/材质/UV/外部贴图字节/Core 一致 + socket 父子/translation=(x, deck_z, −y)/朝向/extras）；批次 B `verify_legacy_uv_b_glb.py` 21 files 0 failures；新增 Godot `test_ship_weapon_sockets.gd` 2 例（运行时空节点 + GLB JSON extras）；**独立 Verifier 只读复核**：BIN chunk 与 pre-socket 备份逐字节相同（只多 14 个空节点）、14/14 射线命中甲板、translation/朝向/贴图三方哈希全通过；全量 headless 套件 **369 passed / 0 failed** |
| 过程发现 | ① 甲板不是平面：同船不同安装点甲板高度差 0.45 m（PS 艏 1.91 vs 艉上层 3.42），socket z 必须逐点 down-ray 实测，不能按船写一个常量；② “净空”要分径向/纵轴/横向三个数：只给 `clearance_r` 会把 8 m 长的舷炮列判死（径向被舷墙压到 0.75 m），`clearance_x/y` 才能表达排布方向；③ Godot 的 `Array.has(int)` 对 JSON 解析出的 float（`0` vs `0.0`）返回 false，测试里要 `int()` 后建索引表再判断；④ 4 艘船同工作台时标准节点名会撞全局命名空间，必须沿用武器 v2 的「BLEND 前缀 → GLB 后处理归一化」；⑤ **活体 Blender 会缓存纯 Python 模块**：改完 `sn_ship_weapon_sockets.py`（新增 Root extras）后同一会话里 `import` 仍拿到旧版，`apply` 结果缺字段；修法是 `importlib.reload` 或先 `sys.modules.pop` 再 `runpy`（与 §11.13 的教训同源）；⑥ 独立 Verifier 抓到契约层真缺陷 F1：武器批次 1 的 `base_footprint`=整机 bbox，按字面判据会误杀小船 Light/Heavy 点——资产改了、契约没对齐，仍算不通过（见 §8.3 / §7.5） |
| 交付 | 4 个 GLB（`assets/models/ships/` + Core 副本）、`sn_ship_weapon_sockets.py` / `glb_ship_sockets.py` / `export_ship_weapon_sockets_glb.py` / `verify_ship_weapon_sockets_glb.py`、Godot 测试、[WEAPON_SOCKET_CONTRACT.md §8](WEAPON_SOCKET_CONTRACT.md#L156) |

### 11.18 船体帆索部件库 rig_kit M0-4（2026-10-22，12 件套件 + 3 艘船参数化替换）

| 环节 | 实际结果 |
| --- | --- |
| 需求 | backlog M0-4：桅杆 / 斜桁 / 帆面 / 索具参数化，接口 `SN_Socket_Mast/Yard/Sail`，8–12 件约 6–8k tri，“替换现有船体上焊死的帆索”；用户 2026-10-22 选 **A（套件 + 3 艘船改用部件库，逐对象几何 digest 不变）**，运行时 `ShipVisualAssembler` 本批不实现 |
| 设计 | 先定“部件库 = 几何组合 + 船型布局分离”：`rig_kit.py` 提供 `RigBuilder`（统一 `add(vf, material)`，兼容 SF/PF 的 `add(vf, mat)` 与铁甲舰的 `add(verts, faces, mat)`，基本体由调用方模块提供以保逐位一致）、通用积木、帆面曲面/帆缝/帆缘绳、三型船的部件函数；船型生成器只保留桅位/后倾/帆角/锚点；独立套件用同一批函数 + 套件参数生成 |
| 部件库与套件 | `rig_kit.py` + `rig_kit_batch1_generator.py`（12 件：帆船桅 / 蒸汽桅 / 横桁 / 斜桁 / 帆杠 / 艏斜桁 / 斜桁帆 / 方帆 / 艏三角帆 / 侧支索 / 支索 / 动索，共 **3,774 tri / 7,050 预算**）+ `sn_rig_materials.py`（材质白名单）+ `dryrun_rig_kit.py`（命名/tri/bbox/z 基准/材质/网格健康/Mount+Socket） |
| 船体替换 | PF `build_mast/yards/bowsprit/rigging`、SF 六个帆索函数、IC `build_masts/rigging` 改为调用 `rig_kit`；新增 `rig_kit_baseline.py`（纯 Python 逐对象 verts/faces/tri/材质/bbox/SHA-256 基线）作硬门禁：重构前后 **3/3 SAME**（PF 39/12,200、SF 28/12,994、IC 1/8,830） |
| socket | `sn_ship_rig_sockets.py` 只补空节点：PF 6 / SF 7 / IC 9 = **22 个** `SN_Socket_Mast/Yard/Sail_*`，坐标直接取 3 艘船参数表（不射线）；`glb_ship_rig_sockets.py` 与 `glb_rig_kit.py` 把 BLEND 前缀名归一化，并把名单写进 Root `rig_sockets`（Blender IDProperty 不支持字符串数组） |
| 构建 | Builder 一次通过：12 集合 / 12 mesh + 57 empty / 3,774 tri；3 艘船重建命中基线；武器 socket 14 个 re-apply；rig socket 22 个 `geometry_unchanged=True`；批次 B 材质/UV 迁移 4 艘船 101 mesh 全绿；场景 707→798 objects、445→457 mesh、259→338 empty、相机灯光不变 |
| 导出与验收 | `export_rig_kit_glb.py` 12 件（308.3 KB）+ `export_ship_weapon_sockets_glb.py` 4 艘；`verify_rig_kit_glb.py` **12/12 ALL OK**、`verify_ship_weapon_sockets_glb.py` **4/4**（PF 56 / PS 38 / SF 42 / IC 14 节点）、`verify_legacy_uv_b_glb.py` 21 files 0 failures；`gen_rig_kit_catalog.py` 出机器目录；Godot 新增 `test_rig_kit.gd` 3 例 + 武器/批次 B 套件回归全绿 |
| 过程发现 | ① **帆面曲面归一化要逐位复刻**：最初把 `vnorm((fwd.x,0,fwd.z))` 写成“先按 3D 长度除再归一化”，最后几位不同，导致 `SN_SF_Sails_Main` digest 变化；改成单次 2D 归一化后 3/3 一致——重构类工作必须用 digest 对比，不能靠肉眼；② 3 艘船 Part/基本体实现不同（SF 用 `ship_parts.core`、PF 自带同构副本、IC 的 `taper_cyl` 相位与 `Part.add` 签名都不同），所以 `RigBuilder` 只统一“追加接口”，基本体由各船模块注入；③ **新建 socket 脚本要限定自己的前缀**：铁甲舰若用 `SN_` 当前缀，会把 `SN_Rig_*_Socket_*` 套件接口当船体 socket 删掉，改成 `SN_IC_`；④ GLB 后处理只处理 Mast/Yard/Sail 三类节点，不能把 M0-3 武器 socket 与 PF 旧通用 socket（Engine/Cabin/…）算进“规格外”；⑤ 运行时装配仍缺 `ShipVisualAssembler`，本批只交付资产/接口/目录，避免把建模批次与 GDScript 装配混在一起；⑥ 独立 QA 抓到 3 类真实缺陷并已修：Bowsprit/Stays/Running 的 datum 离地（补甲板接触几何，zmin→0、total 3,690→3,774）、SF `rig_yard_z` 取桅局部 z 与 PF/IC 语义不一致（统一取船体 z）、契约键名/计数/接口名前缀不一致（纯文档）；详见 [RIG_KIT_ACCEPTANCE.md](../archive/RIG_KIT_ACCEPTANCE.md) §8 |
| 交付 | 12 个 GLB（`assets/models/rig/` + Core 副本 + 共享贴图）、4 艘船 GLB 重导、`rig_kit.py` / 生成器 / 干跑 / 基线 / socket / GLB 归一化 / 导出 / 自检 / 目录脚本、Godot 测试、[RIG_KIT_CONTRACT.md](RIG_KIT_CONTRACT.md)、[RIG_KIT_ACCEPTANCE.md](../archive/RIG_KIT_ACCEPTANCE.md) |

## 12. 共享贴图材质与 UV（新资产默认约定，2026-10-21 起）

> 结论：**新资产不再用纯色代表材质**。材质 = 共享贴图（`SN_Tex_*`）+ spec 参数，
> 贴图作为外部共享 PNG 随 core 模组发布；模型只保留几何与 UV。
> 本节是 `sn_crane_batch1` 的实践沉淀，后续道具 / 船舶 / 设施都按此执行。

### 12.1 资产真源与文件

| 环节 | 路径 | 说明 |
| --- | --- | --- |
| 材质 / 贴图 spec | `docs/design/textures/shared_materials/shared_materials.spec.json` | 材质名、纹理名、`tile_m`、roughness / metallic、调色板、贴图均值目标；改颜色的唯一入口 |
| 贴图生成器 | `tools/art/gen_shared_material_textures.py` | 11 张 512² 无缝 sRGB 贴图（批次 2 新增 `SN_Tex_Coal` 碎煤）、montage、stats、运行时副本；确定性可复现（复用铁港生成器的周期噪声 / 木材 / 石材 / 玻璃画家） |
| 授权贴图 | `docs/design/textures/shared_materials/tiles/<texture>.png` | 入库真源；材质贴图以它为准（不采用 Blender 重编码字节） |
| 共享贴图运行时副本 | `assets/models/<category>/shared_materials/`（开发态）与 `dev_mods/core/assets/models/<category>/shared_materials/`（发布；示例：`props`、`weapons`、`ship_parts`、`machinery`、`cargo`、`dock`） | GLB 用相对 URI `shared_materials/<texture>.png` 引用；`ContentAssetLoader` 按路径缓存成同一个 `Texture2D`；新分类目录要同步写进 `shared_materials.spec.json` 的 `runtime_dirs` |
| 材质库 | `tools/modeling/generators/sn_shared_materials.py` | spec → Blender 材质节点 / 世界空间盒式 UV / 验收；纯 Python 数据段可干跑 |
| 资产侧材质视图 | `tools/modeling/generators/sn_crane_materials.py`（示例） | `MAT_*` 常量、每资产材质白名单、`colors_for()` 回退色 |

### 12.2 命名与旧资产兼容

- 新贴图材质统一用 **`SN_Tex_*`**（`SN_Tex_Metal` / `SN_Tex_Wood` / …）。
- 旧资产的纯色材质（`SN_Metal` / `SN_Wood` / …）被 160+ 个既有对象共用，**不允许原地改成贴图**；
  否则没有 UV 的旧网格会变成单色采样。旧资产按“加 UV → 切换材质名 → 重导 GLB”逐批迁移，
  迁移前保持 `SN_*` 纯色。**批次 A（31 件铁港道具 + 6 件港口设施）已完成**，
  映射与脚本见 §11.15；**批次 B（船模块 / 4 艘船 / 旧小镇剩余道具）也已完成**
  （2026-10-22，实际重导 21 个 GLB，§11.16）；仅 `SN_Ship_Prototype` 这一遗留原型键仍是旧纯色。
- 干跑/自检按 `ASSET_MATERIALS` 白名单核对，禁止新资产偷偷退回纯色材质。

### 12.3 UV 与材质绑定（Blender）

- 盒式投影：按面法线主轴选 UV 轴（X 面 → (Y,Z)，Y 面 → (X,Z)，Z 面 → (X,Y)），
  `uv = 坐标 / tile_m`，采样器 REPEAT；因此任意大面连续平铺、无需手工展 UV。
- 坐标空间：
  - `space="world"`（默认）：世界坐标，跨子件连续（起重机等）；
  - `space="local"`：mesh 自身局部坐标，UV 相位不随工作台布局位置变化（单 mesh 道具 / 设施 / 模块 / 旧小镇）；
  - `space="root"`：`root.matrix_world.inverted() @ obj.matrix_world`，多节点船体专用（跨子件连续、不烘入工作台摆位，批次 B 起）。
- UV 层名固定 `UVMap`；每个 mesh 的 `len(uv) == len(loops)`。
- 节点：Image Texture（sRGB / Linear / REPEAT）→ Principled Base Color；
  Roughness / Metallic 来自 spec；背面剔除关闭。
- 生成器入口：`build_all()` 在 `assembly.build_collection()` 之后调用
  `sn_shared_materials.apply_collection()`；`report()` 调 `verify_collection()` 自检。
- 每个对象保留自己的 Pivot / 根层级；世界空间 UV 不因父级平移而改变图案尺度。

### 12.4 导出、运行时与验收

- 导出后调用 `glb_shared_textures.externalize_glb(..., prefer_authored=True)`：
  GLB 的 `images[].uri` 改为 `shared_materials/<texture>.png`，共享 PNG 用授权源字节写出，
  BIN 里不再重复图片字节；GLB 与贴图同时同步到 `dev_mods/core/assets/models/props/`。
- 运行时：`ContentAssetLoader.load_scene()` 的 `_apply_shared_textures()` 把外部 URI
  解析成同一个 `Texture2D` 实例；多件资产因此共享贴图，`PortStage` 的材质签名合批可合并。
- 验收：`verify_cranes_glb.py` / `verify_legacy_uv_glb.py`（外部 URI、贴图字节与授权源一致、
  每个图元有 `TEXCOORD_0`、世界空间 bbox）+ `tools/godot/verify_crane_materials.gd` /
  `tools/godot/verify_legacy_uv_materials.gd`（贴图实例共享、UV 存在）。
- 工作台视口约定（2026-10-22）：**Solid 统一 `color_type = SINGLE` + `single_color = 0.55 灰`**，各 3D 视口 `shading.type = SOLID`，避免「有贴图的资产带色、旧的纯色资产发灰」混看；预览渲染脚本临时切 `TEXTURE` 出图，结束后恢复灰模（`render_kit_preview.py` 的 `_capture_stage_state` / `_restore_stage_state` 已覆盖）。
- 旧资产迁移状态：**批次 A（31 件铁港道具 + 6 件港口设施）已完成（2026-10-22，§11.15）**；
  **批次 B（11 件船模块 + 4 艘船 + 旧小镇剩余 5 件，实际重导 21 个 GLB）也已完成（§11.16）**。
  仅 `SN_Ship_Prototype`（`model.ship.prototype` 遗留键）仍是旧纯色，留待后续清理批次。
