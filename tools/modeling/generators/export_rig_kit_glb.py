# -*- coding: utf-8 -*-
# @static-doc
# 作用：`rig_kit` 独立套件（12 件 `SN_Rig_*`）的 GLB 归档导出（Blender 内执行，
# 人工验收通过后由 Lead 运行）——逐件根节点归零导出，把内嵌共享贴图外部化为
# `shared_materials/<texture>.png`，调 `glb_rig_kit.standardize()` 归一化接口节点名
# 并写 Root extras，备份旧 GLB，同步 `assets/models/rig/` 与
# `dev_mods/core/assets/models/rig/` 两份副本，最后保存工作台。
#
# 约定：轴心 = 该资产的 Root datum（桅杆/艏斜桁/索具在甲板，桁/帆在各自挂点）；
# 只导出目标集合；不导相机/灯光；旧 GLB 备份到 `.design/rig_kit/backup_glb/`。
#
# 用法（已连 Blender 的会话）：
#     import runpy; runpy.run_path(<本文件>, run_name="__main__")
# @end-static-doc

import glob
import os
import shutil
import sys
import time

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import glb_rig_kit  # noqa: E402
import glb_shared_textures  # noqa: E402
import rig_kit_batch1_generator as gen  # noqa: E402

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
CATEGORY = "rig"
DEV_DIR = os.path.join(WORKDIR, "assets", "models", CATEGORY)
CORE_DIR = os.path.join(WORKDIR, "dev_mods", "core", "assets", "models",
                        CATEGORY)
BACKUP_DIR = os.path.join(WORKDIR, ".design", "rig_kit", "backup_glb")
TILES_DIR = os.path.join(WORKDIR, "docs", "design", "textures",
                         "shared_materials", "tiles")
URI_PREFIX = "shared_materials"


def _backup(path):
    if not os.path.isfile(path):
        return None
    os.makedirs(BACKUP_DIR, exist_ok=True)
    base = os.path.splitext(os.path.basename(path))[0]
    stamp = time.strftime("%Y%m%d-%H%M%S")
    dst = os.path.join(BACKUP_DIR, "%s.%s.glb" % (base, stamp))
    shutil.copy2(path, dst)
    return dst


def _export_glb(asset):
    spec = gen.SPECS[asset]
    collection = spec["collection"]
    root_name = spec["prefix"] + "Root"
    col = bpy.data.collections.get(collection)
    root = bpy.data.objects.get(root_name)
    if col is None:
        raise RuntimeError("缺少集合 %s" % collection)
    if root is None:
        raise RuntimeError("缺少根空物体 %s" % root_name)
    os.makedirs(DEV_DIR, exist_ok=True)
    path = os.path.join(DEV_DIR, "%s.glb" % asset)
    backup = _backup(path)
    saved_loc = tuple(root.location)
    saved_selection = list(bpy.context.selected_objects)
    try:
        root.location = (0.0, 0.0, 0.0)
        bpy.context.view_layer.update()
        for obj in bpy.context.selected_objects:
            obj.select_set(False)
        for obj in col.objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = root
        bpy.ops.export_scene.gltf(
            filepath=path,
            export_format="GLB",
            use_selection=True,
            export_apply=True,
            export_yup=True,
            export_cameras=False,
            export_lights=False,
            export_extras=True,
        )
    finally:
        root.location = saved_loc
        for obj in bpy.context.selected_objects:
            obj.select_set(False)
        for obj in saved_selection:
            obj.select_set(True)
        bpy.context.view_layer.update()
    return path, backup


def _sync_shared_textures():
    copied = []
    for dst_dir in (os.path.join(DEV_DIR, "shared_materials"),
                    os.path.join(CORE_DIR, "shared_materials")):
        os.makedirs(dst_dir, exist_ok=True)
        for src in sorted(glob.glob(os.path.join(TILES_DIR, "*.png"))):
            dst = os.path.join(dst_dir, os.path.basename(src))
            shutil.copy2(src, dst)
            copied.append(os.path.relpath(dst, WORKDIR).replace("\\", "/"))
    return copied


def export_all():
    results = []
    for asset in gen.ASSETS:
        path, backup = _export_glb(asset)
        external = glb_shared_textures.externalize_glb(
            path, path,
            shared_dir=os.path.join(DEV_DIR, "shared_materials"),
            uri_prefix=URI_PREFIX,
            tiles_dir=TILES_DIR,
            write_pngs=True,
            prefer_authored=True,
        )
        socket_report = glb_rig_kit.standardize(path, asset)
        os.makedirs(CORE_DIR, exist_ok=True)
        core_glb = os.path.join(CORE_DIR, "%s.glb" % asset)
        shutil.copy2(path, core_glb)
        results.append({
            "asset": asset,
            "glb": path,
            "core_glb": core_glb,
            "bytes": os.path.getsize(path),
            "backup": backup,
            "images": len(external.get("images", [])),
            "bytes_saved": external.get("bytes_saved", 0),
            "sockets": socket_report["sockets"],
            "renamed": socket_report["renamed"],
        })
        print("EXPORTED %-22s %8d bytes sockets=%d images=%d"
              % (asset, results[-1]["bytes"], len(socket_report["sockets"]),
                 results[-1]["images"]))
    shared = _sync_shared_textures()
    bpy.ops.wm.save_mainfile()
    report = {
        "workbench": bpy.data.filepath,
        "results": results,
        "total_bytes": sum(item["bytes"] for item in results),
        "shared_textures": shared,
    }
    print("RIG_KIT_EXPORT_DONE %r" % {
        "count": len(results),
        "workbench": report["workbench"],
        "total_bytes": report["total_bytes"],
        "shared": len(shared),
    })
    return report


if __name__ == "__main__":
    export_all()
