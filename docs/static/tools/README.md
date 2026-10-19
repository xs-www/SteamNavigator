# `tools`

> PowerShell 辅助脚本、Godot 验收脚本、建模工单 / 参数化生成器与静态文档生成器。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `gen_static_docs.mjs` | 静态文档生成器：读取本文件的 FILE_DOCS/MODULES，生成镜像文档、模块 README、总计索引与带 SHA-256 的 manifest。 | [查看](./gen_static_docs.mjs.md) |
| `godot/_tmp_inspect.gd` | PowerShell 测试/打包脚本与静态文档生成器。 | 本页 |
| `godot/_tmp_xform_test.gd` | PowerShell 测试/打包脚本与静态文档生成器。 | 本页 |
| `godot/verify_props.gd` | 道具 GLB 导入验收（只读）：加载 `assets/models/props/*.glb`，量测 Godot 侧包围盒、三角面与材质名，对照 brief 尺寸判定尺度与轴向。 | [查看](./godot/verify_props.gd.md) |
| `modeling/briefs/IRON_HARBOR_PLAN.md` | 铁港小部件 31 件 / 5 批的工单总表、布局、材质与已知坑。 | 本页 |
| `modeling/briefs/_template.json` | 建模工单模板：字段说明与必填项。 | 本页 |
| `modeling/briefs/sn_harbor_crane.json` | 港口塔吊工单（锤头式，含回转枢轴与吊钩层级）。 | 本页 |
| `modeling/briefs/sn_iron_harbor_batch1.json` | 铁港第一批 6 件道具工单（岸壁/护舷/系缆桩/木箱/木桶/矿堆，y=24）。 | 本页 |
| `modeling/briefs/sn_iron_harbor_batch2.json` | 铁港第二批 6 件工单（煤气灯/跳板/抓斗/煤堆/爬梯/钢板堆，y=30）。 | 本页 |
| `modeling/briefs/sn_iron_harbor_batch3.json` | 铁港第三批 6 件工单（堆场/管线，y=36）。 | 本页 |
| `modeling/briefs/sn_iron_harbor_batch4.json` | 铁港第四批 6 件工单（机械/水上件，y=42）。 | 本页 |
| `modeling/briefs/sn_iron_harbor_batch5.json` | 铁港第五批 7 件工单（结构/标识/动力，y=48）。 | 本页 |
| `modeling/briefs/sn_ship_prototype.json` | 帆船原型工单（三桅六帆低模）。 | 本页 |
| `modeling/dispatch.workflow.js` | 批量派发脚本：串行 Builder + 独立 Verifier，脚本内不落盘（导出由 Lead 在人工验收后执行）。 | 本页 |
| `modeling/generators/dryrun_batch2.py` | 第二批专用干跑（dryrun_props.py 的前身，保留兼容）。 | 本页 |
| `modeling/generators/dryrun_props.py` | 通用纯 Python 干跑：把 bpy/bmesh 换成空壳加载生成器，离线校验 tri 预算、包围盒、边界边/非流形边/退化面。 | 本页 |
| `modeling/generators/export_props_glb.py` | 道具 GLB 导出：逐件把 location 临时归零、只导出选中对象、导出后还原；按批次分组避免无谓重导。 | 本页 |
| `modeling/generators/p0_finalize.py` | P0 归档：备份旧 GLB → 清临时对象 → 导出 → 保存工作台。 | 本页 |
| `modeling/generators/p0_rework_2026-10-19.py` | 第一批 P0 整改：重建系缆桩 → SN_Ore 改锈红 → 三段岸壁拼接测试。 | 本页 |
| `modeling/generators/sn_iron_harbor_batch2_generator.py` | 铁港第二批 6 件生成器（煤气灯/跳板/抓斗/煤堆/爬梯/钢板堆）。 | 本页 |
| `modeling/generators/sn_iron_harbor_batch3_generator.py` | 铁港第三批 6 件生成器（木料堆/麻袋堆/蒸汽管/缆绳卷/吊货网/托盘）。 | 本页 |
| `modeling/generators/sn_iron_harbor_batch4_generator.py` | 铁港第四批 6 件生成器（浮标/锚链堆/绞盘/手推车/碰垫/齿轮箱）。 | 本页 |
| `modeling/generators/sn_iron_harbor_batch5_generator.py` | 铁港第五批 7 件生成器（石阶/港口牌/钟/旗杆/煤溜槽/锅炉/龙骨墩）。 | 本页 |
| `modeling/generators/sn_mooring_bollard_generator.py` | 系缆桩生成器（十字桩头 + 方形法兰板 + 四螺栓 + 喇叭脚柱身）；单件 API，不走 dryrun_props。 | 本页 |
| `pack_core.ps1` | PowerShell 测试/打包脚本与静态文档生成器。 | 本页 |
| `static_docs_data.mjs` | 静态文档的策展数据：文件职责/契约/L2、模块简介与分组角色。 | [查看](./static_docs_data.mjs.md) |
| `test.ps1` | PowerShell 测试/打包脚本与静态文档生成器。 | 本页 |

## 模块契约

- `test.ps1` / `pack_core.ps1` 通过 `GODOT_BIN` 定位引擎。
- `gen_static_docs.mjs` 读取 `static_docs_data.mjs` 生成 `docs/static/`。
- `modeling/briefs/*.json` 是建模子代理的自包含工单；尺寸/预算/材质只改这里，不靠口述传递。
- `modeling/generators/*.py` 是几何唯一真源：改了参数重跑即可重建，禁止手工摆点；`.blend` 只是产物。
- `modeling/generators/dryrun_props.py` 必须在进 Blender 前跑通（tri 预算 / 包围盒 / 边界边 / 退化面）。
- `modeling/dispatch.workflow.js` 必须串行派发：Blender 单实例，禁止 `parallel`/`pipeline` 并发建模。
- `godot/verify_props.gd` 是 GLB 导入的回归闸门，改动资产后必须重跑。
