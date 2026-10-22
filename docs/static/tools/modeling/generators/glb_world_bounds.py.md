# `tools/modeling/generators/glb_world_bounds.py`

> 作用：纯 Python 的 GLB 世界空间几何读取器：按 glTF 节点层级合成完整 TRS（含四元数

- 类型：项目配置/数据文件

旋转 / matrix / 非均匀缩放），读取 POSITION accessor 的真实顶点，求得**世界包围盒**、
三角面数、UV 完整性、节点根名，供 LOD0↔LOD1 对比、门禁与验收脚本复用。

## 契约与约束
- 不依赖 bpy / Godot；只读 GLB，不修改文件。复用 `glb_shared_textures.read_glb`
  的容器解析与 `structure_report` 的材质 / image 报告，本模块只补「真实几何」。
- POSITION 只支持 float32（componentType 5126），与 Blender glTF 导出/本仓库资产一致；
  其它类型直接抛 ValueError，不静默换算法。
- 包围盒取实际顶点（不是 accessor min/max 的 8 角点），因此带旋转 Pivot 的多节点船体
  与 kit 拼装件的 bbox 是精确值；LOD1 单节点也走同一条路径，可以直接对账。
- `uv_missing` / `uv_count_mismatch` 用于守护"每个图元都有 TEXCOORD_0 且数量等于
  POSITION"，不判断 UV 数值是否合理（盒式投影由 Blender 侧负责）。

## 重点逻辑
### `world_bounds(path, only_nodes=None)`
- 根节点 = 没有被任何节点 `children` 引用的节点；沿 children 递归合成
  `parent @ trs(node)`，把每个 mesh primitive 的 POSITION 变换到世界空间累积 min/max。
- 同时返回 `tris`（indices.count/3 或 POSITION.count/3）、`mesh_nodes`、`root_nodes`、
  `primitives`、`uv_missing`、`uv_count_mismatch`，一次遍历拿到门禁需要的全部几何事实。
### `node_world_matrices(path)`
- 返回 `{node_index: matrix}`，供需要按节点核对（例如 socket 空节点）的脚本使用。

模块索引：[tools](../../README.md)
