# `tools/modeling/blueprint/apply_hull_blueprints.mjs`

> 作用：把离线蓝图线稿接入 Core 船体内容：拷贝 side/top PNG、登记 manifest 资源键、写入 `data.blueprint_views`，并用生成器 metadata 的正交相机把船体武器 socket 的 `position` 投影成 `blueprint` 归一化坐标。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `VIEWS` | L36 |
| `usage()` | L38 |
| `parseArgs(argv)` | L51 |
| `mat3FromEuler([ex, ey, ez])` | L87 |
| `applyMat3(matrix, vector)` | L102 |
| `projectPoint(position, viewMetadata)` | L115 |
| `modelKeyToGlb(manifest, modelKey)` | L143 |
| `assetKeyFor(hullLocalId, view)` | L149 |
| `readJson(file)` | L153 |
| `readText(file)` | L157 |
| `setMember(text, memberPath, value)` | L166 |
| `buildPlan(options)` | L175 |
| `applyPlan(built, options)` | L240 |
| `main()` | L283 |

## 契约与约束
- 输入是 `tools/modeling/blueprint/blueprint_batch.py` 的产物目录（每船含 `side.png` / `top.png` / `metadata.json`）；不重新渲染、不改 PNG。
- 坐标空间 = 裁切后线稿纹理的归一化 uv（`space: "trimmed"`，左上原点 0..1）；投影使用 metadata 的相机旋转/位置、`orthographic_scale`、`render_resolution` 与 `crop.crop_bounds`，与蓝图生成器共用同一组数字。
- 武器 socket 的 `position` 取内容侧 `[x, y, deck_z]` 镜像（Blender 船体局部坐标）；脚本只读内容，不回读 GLB。
- 写入 hulls.json 时通过 `SNModMaker/tools/content_json.mjs` 保留原文件风格；manifest 用 2 空格 JSON 重写。
- `--check` 只比较、不写盘：有差异退出码 1，供 CI / 发布门禁使用。

## 重点逻辑
### `projectPoint(position, viewMetadata)`
- Blender Euler XYZ → 相机基向量，按正交投影得到像素坐标，再经 crop 归一化；越界钳制到 0..1。
### `buildPlan(input)`
- 由 hull 的 `information.model` → manifest 资源路径 → GLB 文件名找到线稿目录；输出每船的 blueprint_views、asset 键与 socket 坐标。
### `applyPlan(plan, options)`
- 依次替换/插入 hulls.json 的 `data.blueprint_views` 与 `data.weapon_sockets[N].blueprint`；`--check` 时只比对。

模块索引：[tools](../../README.md)
