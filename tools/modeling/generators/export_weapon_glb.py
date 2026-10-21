# -*- coding: utf-8 -*-
# @static-doc
# 作用：舰载武器五件套的 GLB 归档导出脚本（人工验收通过后由 Lead 执行）；导出后把
# GLB 内嵌材质贴图外部化为 `shared_materials/<texture>.png` 共享 URI，并同步
# `assets/models/weapons/` 与 `dev_mods/core/assets/models/weapons/` 两处副本。
#
# 约定（见 docs/design/MODELING_WORKFLOW.md 第 8 节与 docs/design/ASSET_MAP.md）：
# - 逐件导出：导出前把根空物体 `location` 临时归零，导出后还原；轴心落在炮座底面中心；
# - 只导出该集合内的对象（根 / Pivot / 网格），不导相机 / 灯光 / 其它资产；
# - glTF 默认 +Y 向上，进入 Godot 后尺寸为 (Blender X, Blender Z, Blender Y)；
# - 覆盖前把旧 GLB 备份到 `.design/weapons/backup_glb/`；
# - 贴图外部化复用 `glb_shared_textures.externalize_glb(..., prefer_authored=True)`；
# - 本批不登记 Core manifest 键，只交付资产副本；
# - 全部导出后保存工作台 `.design/SN_Asset_Workbench.blend`。
#
# 用法（已连 Blender 的会话）：
#     import runpy; runpy.run_path(<本文件>, run_name="__main__")
# 或后台：
#     blender -b .design/SN_Asset_Workbench.blend -P tools/modeling/generators/export_weapon_glb.py
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

import glb_shared_textures  # noqa: E402
import glb_weapon_nodes  # noqa: E402

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
OUT_DIR = os.path.join(WORKDIR, "assets", "models", "weapons")
CORE_DIR = os.path.join(WORKDIR, "dev_mods", "core", "assets", "models",
                        "weapons")
BACKUP_DIR = os.path.join(WORKDIR, ".design", "weapons", "backup_glb")
TILES_DIR = os.path.join(WORKDIR, "docs", "design", "textures",
                         "shared_materials", "tiles")
SHARED_OUT = os.path.join(OUT_DIR, "shared_materials")
SHARED_CORE = os.path.join(CORE_DIR, "shared_materials")
URI_PREFIX = "shared_materials"

# 资产名 -> (集合, 根空物体)
WEAPONS = [
    ("SN_Weapon_DeckGun", "SN_Weapon_DeckGun_Prototype",
     "SN_Weapon_DeckGun_Root"),
    ("SN_Weapon_HeavyCannon", "SN_Weapon_HeavyCannon_Prototype",
     "SN_Weapon_HeavyCannon_Root"),
    ("SN_Weapon_Mortar", "SN_Weapon_Mortar_Prototype",
     "SN_Weapon_Mortar_Root"),
    ("SN_Weapon_Repeater", "SN_Weapon_Repeater_Prototype",
     "SN_Weapon_Repeater_Root"),
    ("SN_Weapon_Broadside", "SN_Weapon_Broadside_Prototype",
     "SN_Weapon_Broadside_Root"),
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
            export_extras=True,
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
    copied = []
    for dst_dir in (SHARED_OUT, SHARED_CORE):
        os.makedirs(dst_dir, exist_ok=True)
        for src in sorted(glob.glob(os.path.join(TILES_DIR, "*.png"))):
            dst = os.path.join(dst_dir, os.path.basename(src))
            shutil.copy2(src, dst)
            copied.append(os.path.relpath(dst, WORKDIR).replace("\\", "/"))
    return copied


def export_all():
    results = []
    textures = None
    for asset, collection, root_name in WEAPONS:
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
        glb_weapon_nodes.standardize(path, asset)
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
            "authored_pngs": sum(1 for p in external.get("pngs", [])
                                 if p.get("authored")),
        })
        print("EXPORTED %s -> %s (%d bytes) images=%d saved=%d" % (
            asset, path, results[-1]["bytes"], results[-1]["images"],
            results[-1]["bytes_saved"]))

    shared = _sync_shared_textures()
    bpy.ops.wm.save_mainfile()
    report = {
        "workbench": bpy.data.filepath,
        "results": results,
        "texture_pngs": ([p["png"] for p in textures.get("pngs", [])]
                         if textures else []),
        "shared_textures": shared,
    }
    print("WEAPON_EXPORT_DONE %r" % {
        "count": len(results),
        "workbench": report["workbench"],
        "shared_textures": len(shared),
    })
    return report


if __name__ == "__main__":
    export_all()
