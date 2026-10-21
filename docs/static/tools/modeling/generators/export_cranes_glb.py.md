# `tools/modeling/generators/export_cranes_glb.py`

> 作用：四台起重机的 GLB 归档导出脚本（验收通过后由 Lead 执行）；导出后把 GLB 内嵌的

- 类型：项目配置/数据文件

材质贴图外部化为 `shared_materials/<texture>.png` 共享 URI，并把 GLB + 共享贴图同步到
Core 模组目录，使多件资产在 Godot 运行时共享同一个 `Texture2D`。

约定（见 docs/design/MODELING_WORKFLOW.md 第 8 节与 docs/design/ASSET_MAP.md）：
- 逐件导出：导出前把根空物体 `location` 临时归零，导出后还原；根空物体归零后
  几何即根局部坐标，轴心落在底面中心 / 轨道面中心；
- 只导出该集合内的对象（根 / Pivot / 网格），不导相机 / 灯光 / 其它资产；
- glTF 默认 +Y 向上，进入 Godot 后尺寸为 (Blender X, Blender Z, Blender Y)；
- 覆盖前把旧 GLB 备份到 `.design/props/backup_glb/`；
- 贴图外部化复用 `glb_shared_textures.externalize_glb(..., prefer_authored=True)`：
  共享 PNG 使用 `docs/design/textures/shared_materials/tiles/` 的授权源字节，
  不采用 Blender 重编码后的字节，保证 `shared_materials/<texture>.png` 可复核；
- 四台起重机都同步 Core 副本（塔吊沿用既有资产键，另外三件新增 `model.prop.*`）；
- 全部导出后保存工作台 `.design/SN_Asset_Workbench.blend`。

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")
或后台：
    blender -b .design/SN_Asset_Workbench.blend -P tools/modeling/generators/export_cranes_glb.py

模块索引：[tools](../../README.md)
