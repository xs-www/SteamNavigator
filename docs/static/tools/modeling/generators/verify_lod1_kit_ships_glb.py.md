# `tools/modeling/generators/verify_lod1_kit_ships_glb.py`

> 作用：LOD1 基础套件（M0-5）的独立结构验收：逐件解析 30 个 `SN_*_LOD1.glb`

- 类型：项目配置/数据文件

（kit 26 + 船 4），核对单根节点 / 单 mesh / tri 比例与硬上限 / 与 LOD0 的世界包围盒
逐轴一致 / `SN_Tex_*` 共享材质 / 外部 `shared_materials/<texture>.png` 与授权 tile
逐字节一致 / 每个 primitive 的 UV 完整 / LOD1 节点 extras；并汇总 kit 与船两组预算
与 Core manifest 的船体 LOD1 资源键。纯 Python，不依赖 Blender / Godot。

## 契约与约束
- 默认验收**已安装**路径（`assets/models/<category>/` 与 `dev_mods/core/...`）；`--candidate`
  改验 `.design/lod1_kit_ships/out/<category>/`，供安装前门禁。
- LOD0 世界包围盒用 `glb_world_bounds.world_bounds`（按节点层级合成 TRS、读真实顶点），
  不用 accessor min/max 近似；LOD1 单节点同一路径，因此 bbox 对账是精确值。
- 上限口径与生成器一致：kit ≤ LOD0×0.35、船 ≤ LOD0×0.30；同时必须有实质简化
  （LOD1 ≤ LOD0×0.5）与足够几何（LOD1 ≥ 24 tri），防止空模型通过。
- 外部 PNG 必须与 `docs/design/textures/shared_materials/tiles/<texture>.png`
  字节一致；不比对 Blender 重编码字节。缺文件 / 内嵌图 / URI 不在 `shared_materials/`
  一律失败，不静默回退。
- manifest 只校验 `model.ship.*_lod1` 四个键（kit 尚未登记 manifest，归
  `kit_catalog.json` 的 LOD1 段）；缺键或路径不存在记失败。

## 重点逻辑
### `verify_asset(asset)`
- 读 LOD0/LOD1 两个 GLB：tri、bbox、材质、image URI、UV、root extras 全部一次拿齐；
  逐项 checks 记录后在 `main()` 汇总；任何 failures 让退出码为 2。
### `main(argv)`
- `--candidate` 切候选目录；`--report <path>` 落盘 JSON；打印逐件表与总 tri / 总字节。

模块索引：[tools](../../README.md)
