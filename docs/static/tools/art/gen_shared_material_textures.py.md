# `tools/art/gen_shared_material_textures.py`

> 作用：生成通用共享材质贴图库（每张 512² 无缝平铺的 sRGB 贴图对应一个 `SN_*` 材质），

- 类型：项目配置/数据文件

并把它们复制到运行时目录、拼出一张评审 montage、写出可复核的 stats。

材质贴图是“材质与模型分离”的资产真源：模型侧只按材质名引用，
贴图以相对 URI `shared_materials/<texture>.png` 作为外部共享资源随 core 模组发布。
规格文件：`docs/design/textures/shared_materials/shared_materials.spec.json`
（材质名 / 纹理名 / tile_m / 粗糙度 / 金属度 / 调色板 / 均值目标都在 spec 里）。

画家复用 `tools/art/gen_iron_harbor_trim_sheet.py` 的周期噪声与木材 / 石材 / 玻璃
画家，保证与铁港建筑同一套低饱和手绘语言；金属 / 铸铁 / 锈红漆 / 黄铜 / 帆布
是新增画家。全部图案由 wrap-safe 的周期噪声与整数周期结构生成，天然无缝。

输出：
  docs/design/textures/shared_materials/tiles/<texture>.png        512² PNG-8，入库真源
  docs/design/textures/shared_materials/shared_materials_montage.png  评审 montage
  docs/design/textures/shared_materials/shared_materials.stats.json   逐张统计 / 哈希 / 确定性
  assets/models/props/shared_materials/<texture>.png                  开发态运行时副本
  dev_mods/core/assets/models/props/shared_materials/<texture>.png    core 模组运行时副本

用法：
  python tools/art/gen_shared_material_textures.py
  python tools/art/gen_shared_material_textures.py --out-root <dir>
  python tools/art/gen_shared_material_textures.py --spec <spec.json>

模块索引：[tools](../README.md)
