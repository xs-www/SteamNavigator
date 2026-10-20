# 铁港建筑套件 · 批次 A · 最终交付独立终验（task-5）

> 只读终验，时间盒 ≤10 分钟：已完成全部关键项；少数需重渲染的项目按 Lead 要求标「未独立重跑」。
> 验收对象：`MODELING_REQUIREMENTS_NEXT_BATCH.md` §5 / §8 / §9 的批次 A 最终落地
> （10 个 GLB、共享外部贴图、manifest、加载路径、文档、测试）。
> 关联报告：[BATCH_A](IRON_HARBOR_ARCHITECTURE_BATCH_A.md)、[SHARED_TEXTURES](IRON_HARBOR_ARCHITECTURE_SHARED_TEXTURES.md)、
> [LOD1_BUILD](IRON_HARBOR_ARCHITECTURE_LOD1_BUILD.md)、[LOD1_VERIFY](IRON_HARBOR_ARCHITECTURE_LOD1_VERIFY.md)。
> 原始证据：`.design/verify_a/final/`（glb_check.log、package_check.log、measure_loose.log、measure_zip.log、final_test.log）
> 与 `.design/verify_a/out/glb_check.json`、`final/package_check.json`。日期：2026-10-20 · verifier-a

## 0. 总判定

**PASS**（关键项全部独立复算通过；无 FAIL；4 项按时间盒标「未独立重跑」，均有 A4 证据且结构侧已独立核对）。

| # | 验收项 | 独立结论 | 证据 |
| --- | --- | --- | --- |
| 1 | 10 个内容 GLB 存在、结构合法、LOD1 tri 上限、LOD0 tri、bbox/轴心 | **PASS** | `glb_check.py` 10/10 PASS，0 failures |
| 2 | 共享外部贴图（11 张、与 tile 逐字节一致、全在 `iron_harbor_shared/`） | **PASS** | 11/11 `bytes_match_tile=True`，pool 校验通过 |
| 3 | manifest LOD1 资产键 5 个、指向存在文件 | **PASS** | 5/5 exists=True（`model.prop.*_lod1`） |
| 4 | 旧 GLB 备份（回滚路径） | **PASS** | `.design/buildings/iron_harbor/a4/legacy/` 5 个 GLB |
| 5 | 包体：5 栋模型+纹理 ≤4.5 MB、LOD1 组合 ≤20 000 tri | **PASS** | 独立求和 **4 168 841 B = 4.17 MB**；LOD1 合计 **6 564** tri |
| 6 | Godot 实机 draw_meshes ≤75（硬上限 80）/ 三站位 draw calls | **PASS（独立重跑）** | 松散与 ZIP 均 `draw_meshes=73`、draws 71/64/65/71/69、batches=41 |
| 7 | 同屏城镇建筑 tri ≤60 000（LOD0）/ LOD1 组合 ≤20 000 | **PASS** | 5 栋 GLB 求和 30 032 / 6 564 |
| 8 | 三种加载路径（松散 / dist zip / 发布包） | **PASS（前两路径独立重跑；发布包结构独立核对）** | 松散≡ZIP 数值完全相同；dist 与发布包 mods zip 均 121 files/10 GLB/11 PNG |
| 9 | 文档一致性 + 静态文档不过期 | **PASS** | 4 份报告存在；ASSET_MAP/todo 已更新；`gen_static_docs --check` = up to date |
| 10 | 完整无头测试 | **PASS（独立运行）** | `Tests: 223 passed, 0 failed, 223 total`（99.3 s） |
| 11 | LOD1 临时入舞台证据（49 760 tri） | **PASS（算术复核）** | 73 228 − 30 032 + 6 564 = **49 760**，与 A4 一致 |
| 12 | 1440×900 / 960×540 实机截图独立重渲染 | **未独立重跑**（时间盒） | A4 截图存在（见 §6）；结构/尺寸/加载路径均已独立验证 |
| 13 | 发布包渲染实测 | **未独立重跑**（时间盒） | 仅独立核对发布包 mods zip 内容 + A4 启动日志证据 |

## 1. 内容资产（独立 GLB 解析，非采信 A4）

| 资产 | LOD0 tri | LOD1 tri | LOD1 上限 | 占比 | LOD0 bbox (m) | LOD1 bbox (m) | zmin | 根节点 | UV | 图 |
| --- | ---: | ---: | ---: | ---: | --- | --- | ---: | --- | --- | ---: |
| Warehouse_Long | 7 436 | 1 584 | 2 602 | 0.213 | 20.00×9.00×11.00 | 20.00×9.00×11.00 | 0 | 单根 `SN_HT_Warehouse_Long_LOD0` | 全有 | 6 |
| Warehouse_Short | 3 788 | 1 060 | 1 325 | 0.280 | 11.00×9.00×9.50 | 11.00×9.00×9.50 | 0 | 单根 | 全有 | 6 |
| Harbor_Office | 10 336 | 1 896 | 3 617 | 0.183 | 9.00×8.00×14.00 | 9.00×8.00×14.00 | 0 | 单根 | 全有 | 6 |
| Cargo_Shed | 3 356 | 776 | 1 174 | 0.231 | 8.00×6.00×4.50 | 8.00×6.00×4.50 | 0 | 单根 | 全有 | 5/4 |
| Tavern | 5 116 | 1 248 | 1 790 | 0.244 | 10.00×8.00×8.00 | 10.00×8.00×8.00 | 0 | 单根 | 全有 | 6 |

- LOD0 tri 与 §5.1 表 5/5 一致（Short 檐口修复未改 tri，3 788）；LOD1 全部 ≤ 上限且 ≤35%。
- LOD0↔LOD1 bbox 逐轴 **0.000 m**；10/10 根节点唯一且变换归零；UV 全 primitive 存在；材质槽 ≤6。
- 独立算术复核：LOD1 合计 1 584+1 060+1 896+776+1 248 = **6 564**；LOD0 = **30 032**。

## 2. 共享贴图、manifest、包体

- 外部贴图池：**11 个 PNG**，全部 `uri = iron_harbor_shared/<cell>.png`，全部存在于内容路径，
  且与 `docs/design/textures/iron_harbor/tiles/<cell>.png` **sha256 逐字节一致（11/11）**；
  LOD1 仅引用其 LOD0 的子集（Cargo_Shed LOD1 4 张，属允许简化）。
- manifest：`model.prop.*_lod1` 5 个键全存在、指向文件均存在；LOD0 资产键未变。
- 包体（独立求和，字节精确）：
  - 5 个 LOD0 GLB：**1 895 364 B**
  - 5 个 LOD1 GLB：**388 604 B**
  - 11 张共享 PNG：**1 884 873 B**
  - **LOD0+LOD1 GLB + 纹理 = 4 168 841 B = 4.17 MB ≤ 4.5 MB PASS**；
    （仅运行时 LOD0 口径 = 1 895 364 + 1 884 873 = 3 780 237 B = 3.60 MB。）
- 打包：`dist/mods/core-1.0.0.snavmod.zip` 与发布包 `dist/build/windows/mods/core-1.0.0.snavmod.zip`
  均 **121 files**、含 manifest + 10 个 GLB + 11 张共享 PNG，zip 内 GLB 与内容路径逐字节一致。
- 回滚：`a4/legacy/` 5 个旧 GLB；`a4/external/` 10 个导出快照与内容路径 **sha256 10/10 一致**（导出可复现、无拷后手改）。

## 3. Godot 实机（独立重跑，窗口模式）

| 路径 | draw_meshes | draw calls（preview/sparse/market/harbor/supply） | batches | 结论 |
| --- | ---: | --- | ---: | --- |
| 松散 `dev_mods`（默认） | **73**（sparse 60） | 71 / 64 / 65 / 71 / 69 | 41 | ≤75 PASS |
| `--core-zip=dist/mods/core-1.0.0.snavmod.zip` | **73**（sparse 60） | 71 / 64 / 65 / 71 / 69 | 41 | 与松散完全一致 PASS |

- `draw_meshes` 目标 ≤75、硬上限 80：**73 PASS**（A4 报 91→73，与本次实测一致）。
- 城镇建筑 tri 口径：5 栋 GLB 求和 **30 032（LOD0）/ 6 564（LOD1）**，均 ≤ 需求上限；
  整帧 `tris=73 228` 是含玩家船/水面/设施/道具的全场景口径（与 A4 报告 §5 说明一致，不是 §5.1 的城镇建筑口径）。
- 黑材质/丢贴图：`[asset]` 自证行（tri/uv/贴图数）与 A4 一致；本次测量 5/5 sample、0 failure。
- **未独立重跑**：1440×900 / 960×540 实机截图（A4 已产出 `SN_HT_Warehouse_Long_LOD0/LOD1_port_stage_{1440x900,960x540}.png`）；
  发布包 exe 渲染（结构+启动日志已由 A4 提供，本次独立核对了其 mods zip 内容）。

## 4. 文档与测试

- 文档存在且互相引用：`IRON_HARBOR_ARCHITECTURE_BATCH_A.md`（14.7 KB，含 §1 门禁表、BEFORE/AFTER 对比、加载路径矩阵）、
  `IRON_HARBOR_ARCHITECTURE_SHARED_TEXTURES.md`（10.9 KB，方案对比+三路径）、`LOD1_BUILD.md`、`LOD1_VERIFY.md`。
- `docs/design/ASSET_MAP.md`：新增「批次 A LOD0+LOD1」建筑表（LOD1 路径/尺寸/tri/上限）。
- `todo.md`：批次 A 条目已勾选并写明 6 564 tri / 檐口 −3.543→0 / 共享贴图 / 91→73 / 4.17 MB。
- 静态文档：`node tools/gen_static_docs.mjs --check` → **static docs are up to date**。
- 测试：独立运行完整无头套件 → **223 passed / 0 failed / 223 total**（与 A4 声明一致）。
- 并发工作流（海图 phase 2）改动未纳入本次终验范围；本批相关路径（dev_mods/core 建筑资产、manifest、
  content_asset_loader、批次 A 文档与截图）未见冲突。

## 5. 与 A4/Lead 数字对照（独立复核）

| Lead/A4 声明 | Verifier 独立实测 | 一致 |
| --- | --- | --- |
| draws 71/64/65/71/69，建筑升级口径 91→73 | 松散与 ZIP 均 71/64/65/71/69、draw_meshes 73 | ✅ |
| 模型+纹理 4.17 MB（≤4.5） | 4 168 841 B = 4.17 MB（逐字节求和） | ✅ |
| core zip 6.14 MB / 121 files | 121 files、manifest+10 GLB+11 PNG（zip 内字节与内容路径一致） | ✅ |
| LOD1 tri 1 584/1 060/1 896/776/1 248（合计 6 564） | GLB 解析完全一致 | ✅ |
| LOD0 tri 7 436/3 788/10 336/3 356/5 116 | 完全一致 | ✅ |
| LOD1 临时入舞台 tris 49 760 | 73 228 − 30 032 + 6 564 = 49 760（算术复核） | ✅ |
| 223 passed / 0 failed | 独立运行同数 | ✅ |
| 三路径（松散/ZIP/发布包） | 前两路径数值一致；发布包 mods zip 结构独立核对 | ✅（发布包渲染未重跑） |

## 6. 未闭合项 / 未验（时间盒内未做，不判 FAIL）

1. 1440×900 / 960×540 固定机位截图未独立重渲染——A4 截图已存在且命名符合需求，结构与加载路径已独立验证。
2. 发布包 exe 的渲染实测未独立重跑（A4 记录 `content=51 status=ok`；本次独立核对发布包 mods zip 内容与内容路径一致）。
3. 目视复核（建筑与船/设施/横幅风格协调、960×540 主入口可读）仍属人工/视觉门禁范围；本批自动门禁均 PASS。
4. 并发海图工作流可能改动 `framework/domain/world` 等与批次 A 无关文件；本终验未对其做判定。

## 7. 复现命令

```powershell
python .design/verify_a/glb_check.py            # 10 GLB 结构/tri/外部贴图/manifest/pool/包体
python .design/verify_a/package_check.py        # dist zip / 发布包 mods / legacy 备份 / A4 快照
$godot = "C:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
& $godot --path . --script res://tools/godot/measure_port_stage.gd                                   # 松散
& $godot --path . --script res://tools/godot/measure_port_stage.gd -- --core-zip=dist/mods/core-1.0.0.snavmod.zip
node tools/gen_static_docs.mjs --check
& $godot --headless --path . --script res://framework/tests/test_runner.gd
```

证据文件：`.design/verify_a/final/{glb_check.log,package_check.log,measure_loose.log,measure_zip.log,final_test.log}`、
`.design/verify_a/out/glb_check.json`、`.design/verify_a/final/package_check.json`。
