# -*- coding: utf-8 -*-
# @static-doc
# 作用：四台起重机的 GLB 归档导出脚本（验收通过后由 Lead 执行）；导出后把 GLB 内嵌的
# 材质贴图外部化为 `shared_materials/<texture>.png` 共享 URI，并把 GLB + 共享贴图同步到
# Core 模组目录，使多件资产在 Godot 运行时共享同一个 `Texture2D`。
#
# 约定（见 docs/design/MODELING_WORKFLOW.md 第 8 节与 docs/design/ASSET_MAP.md）：
# - 逐件导出：导出前把根空物体 `location` 临时归零，导出后还原；根空物体归零后
#   几何即根局部坐标，轴心落在底面中心 / 轨道面中心；
# - 只导出该集合内的对象（根 / Pivot / 网格），不导相机 / 灯光 / 其它资产；
# - glTF 默认 +Y 向上，进入 Godot 后尺寸为 (Blender X, Blender Z, Blender Y)；
# - 覆盖前把旧 GLB 备份到 `.design/props/backup_glb/`；
# - 贴图外部化复用 `glb_shared_textures.externalize_glb(..., prefer_authored=True)`：
#   共享 PNG 使用 `docs/design/textures/shared_materials/tiles/` 的授权源字节，
#   不采用 Blender 重编码后的字节，保证 `shared_materials/<texture>.png` 可复核；
# - 四台起重机都同步 Core 副本（塔吊沿用既有资产键，另外三件新增 `model.prop.*`）；
# - 全部导出后保存工作台 `.design/SN_Asset_Workbench.blend`。
#
# 用法（已连 Blender 的会话）：
#     import runpy; runpy.run_path(<本文件>, run_name="__main__")
# 或后台：
#     blender -b .design/SN_Asset_Workbench.blend -P tools/modeling/generators/export_cranes_glb.py
# @end-static-doc

import os
import shutil
import time

import bpy

import glb_shared_textures

HERE = os.path.dirname(os.path.abspath(__file__))
WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
OUT_DIR = os.path.join(WORKDIR, "assets", "models", "props")
CORE_DIR = os.path.join(WORKDIR, "dev_mods", "core", "assets", "models", "props")
BACKUP_DIR = os.path.join(WORKDIR, ".design", "props", "backup_glb")
TILES_DIR = os.path.join(WORKDIR, "docs", "design", "textures", "shared_materials", "tiles")
SHARED_OUT = os.path.join(OUT_DIR, "shared_materials")
SHARED_CORE = os.path.join(CORE_DIR, "shared_materials")
URI_PREFIX = "shared_materials"

# 资产名 -> (集合, 根空物体)
CRANES = [
    ("SN_Harbor_Crane", "SN_Harbor_Crane_Prototype", "SN_Crane_Root"),
    ("SN_Mega_Gantry", "SN_Mega_Gantry_Prototype", "SN_MG_Root"),
    ("SN_Wooden_Mast_Crane", "SN_Wooden_Mast_Crane_Prototype", "SN_WM_Root"),
    ("SN_Hand_Jib_Crane", "SN_Hand_Jib_Crane_Prototype", "SN_HJ_Root"),
]


def _backup(path):
    if not os.path.isfile(path):
        return None
    os.makedirs(BACKUP_DIR, exist_ok=True)
    base = os.path.splitext(os.path.basename(path))[0]
    stamp = time.strftime("%Y%m%d-%H%M%S")
    dst = os.path.join(BACKUP_DIR, "%s.%s.glb" % (base, stamp))
    shutil.copy2(path, dst)
    return dst


def _export_glb(asset, collection, root_name):
    col = bpy.data.collections.get(collection)
    if col is None:
        raise RuntimeError("找不到集合 %s" % collection)
    root = bpy.data.objects.get(root_name)
    if root is None:
        raise RuntimeError("找不到根空物体 %s" % root_name)

    path = os.path.join(OUT_DIR, "%s.glb" % asset)
    os.makedirs(OUT_DIR, exist_ok=True)
    backup = _backup(path)

    saved_loc = tuple(root.location)
    saved_selection = list(bpy.context.selected_objects)
    try:
        root.location = (0.0, 0.0, 0.0)
        bpy.context.view_layer.update()
        for ob in bpy.context.selected_objects:
            ob.select_set(False)
        for ob in col.objects:
            ob.select_set(True)
        bpy.context.view_layer.objects.active = root
        bpy.ops.export_scene.gltf(
            filepath=path,
            export_format="GLB",
            use_selection=True,
            export_apply=True,
            export_yup=True,
            export_cameras=False,
            export_lights=False,
            export_extras=False,
        )
    finally:
        root.location = saved_loc
        for ob in bpy.context.selected_objects:
            ob.select_set(False)
        for ob in saved_selection:
            ob.select_set(True)
        bpy.context.view_layer.update()
    return path, backup


def _sync_shared_textures():
    """把授权 tile 字节复制到 Core 的共享贴图目录；返回复制清单。"""
    os.makedirs(SHARED_CORE, exist_ok=True)
    copied = []
    for name in sorted(os.listdir(TILES_DIR)):
        if not name.endswith(".png"):
            continue
        src = os.path.join(TILES_DIR, name)
        dst = os.path.join(SHARED_CORE, name)
        shutil.copy2(src, dst)
        copied.append(os.path.relpath(dst, WORKDIR).replace("\\", "/"))
    return copied


def export_all():
    results = []
    textures = None
    for asset, collection, root_name in CRANES:
        path, backup = _export_glb(asset, collection, root_name)
        external = glb_shared_textures.externalize_glb(
            path, path,
            shared_dir=SHARED_OUT,
            uri_prefix=URI_PREFIX,
            tiles_dir=TILES_DIR,
            write_pngs=True,
            prefer_authored=True,
        )
        textures = external
        core_glb = os.path.join(CORE_DIR, "%s.glb" % asset)
        os.makedirs(CORE_DIR, exist_ok=True)
        shutil.copy2(path, core_glb)
        results.append({
            "asset": asset,
            "glb": path,
            "bytes": os.path.getsize(path),
            "backup": backup,
            "core_glb": core_glb,
            "images": len(external.get("images", [])),
            "bytes_saved": external.get("bytes_saved", 0),
            "authored_pngs": sum(1 for p in external.get("pngs", []) if p.get("authored")),
        })
        print("EXPORTED %s -> %s (%d bytes) images=%d saved=%d" % (
            asset, path, results[-1]["bytes"], results[-1]["images"],
            results[-1]["bytes_saved"]))

    core_textures = _sync_shared_textures()
    bpy.ops.wm.save_mainfile()
    report = {
        "workbench": bpy.data.filepath,
        "results": results,
        "texture_pngs": [p["png"] for p in textures.get("pngs", [])] if textures else [],
        "core_textures": core_textures,
    }
    print("CRANES_EXPORT_DONE %r" % {
        "count": len(results),
        "workbench": report["workbench"],
        "shared_textures": len(report["texture_pngs"]),
    })
    return report


if __name__ == "__main__":
    export_all()
