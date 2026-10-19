# Steam Navigator 可复用船体部件库（v1）

> 状态：**建模期复用**（不是运行时可换装）；当前只服务 `SN_Schooner_Fame`，但接口已按多船复用设计。

## 分层

| 模块 | 职责 |
| --- | --- |
| `core.py` | `Part`、向量/基本体、放样、镜像、`PartSpec`；纯 Python，不依赖 bpy |
| `deck.py` | 甲板属具（舱口/天窗/绞盘/起锚机/舵轮/罗经柜/钟/木桶/盘绳/缆柱/水桶/fife rail/短梯） |
| `bow.py` | 艏斜桁/jibboom/艏饰 |
| `stern.py` | 艉廊/艉窗/艉灯 |
| `assembly.py` | Blender 集合/材质/空物体/文字铭牌/report；bpy 只在函数内 import |

## 新增或复用部件

1. 在对应模块写一个 `def xxx(part, ...)`，把几何追加到 `Part`；参数只收**位置/尺寸/材质名**，不要 import 某艘船的站表常量。
2. 需要新基本体时放 `core.py`，保持纯 Python。
3. 生成器里只负责“船型布局”：算好 `x/y/z`，调用部件函数，按原有 `parts` 顺序注册。
4. 运行 `python tools/modeling/generators/dryrun_<ship>.py`；再按 `MODELING_WORKFLOW.md` 派发 Builder/Verifier。

## 部件契约

- 单位米，+X 船首、+Y 左舷、+Z 向上。
- `Part` 用 `faces` 里的材质名引用调色板；公共材质名见 `palette.py`，船体主色由船型生成器传入。
- 多部件对象（如 `SN_SF_Hatches`）在生成器里合并；独立部件对象保持独立 mesh，便于后续导出独立 GLB。
- `PartSpec` 预留给后续运行时可替换部件：`name / part / parent / origin / sockets / tags`。
- 重构验收：同一船型的 `build_all_geometry()` 逐对象顶点/面 digest 与重构前完全一致。

## 当前已验证

`SN_Schooner_Fame` 重构后：

- 纯 Python：28 个几何部件、12994 tri、bbox `33.44 × 6.88 × 26.42 m`（未施加 Pivot 前）；与重构前**逐对象 verts/faces/tris/material/parent digest 0 差异**；
- Blender 装配：32 对象 / 29 mesh / 3 empty / 13174 tri / bbox `33.441 × 6.88 × 26.866 m`；逐对象 `local_sha256 / world_sha256 / polys_sha256 / parent / matrix_world / materials` 与基线 **0 差异**；
- `importlib` 加载、以及无 `__file__` 时用 `bpy.data.filepath` 回退定位 `tools/modeling/generators` 两条路径均已验证。
