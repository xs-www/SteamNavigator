# -*- coding: utf-8 -*-
# @static-doc
# 作用：模型素材库批次 1（武器套件 4 件 + 船体部件 4 件）的 GLB 归档导出（人工验收
# 通过后由 Lead 执行）；导出后把内嵌材质贴图外部化为 `shared_materials/<texture>.png`
# 共享 URI，并同步 `assets/models/{weapons,ship_parts}/` 与
# `dev_mods/core/assets/models/{weapons,ship_parts}/` 两处副本。
#
# 约定（见 MODELING_WORKFLOW §8 / §12 与 ASSET_MAP）：
# - 逐件导出：导出前把根空物体 location 临时归零，导出后还原；轴心即 root datum
#   （火炮 = 耳轴轴心，其余 = 底面中心）；
# - 只导出该集合内的对象（root / socket / mesh），不导相机、灯光、其它资产；
# - glTF 默认 +Y 向上，进入 Godot 后尺寸为 (Blender X, Blender Z, Blender Y)；
# - 覆盖前把旧 GLB 备份到 `.design/kits/backup_glb/`；
# - 贴图外部化复用 `glb_shared_textures.externalize_glb(..., prefer_authored=True)`；
# - 本批不登记 Core manifest 键，只交付资产副本；
# - 全部导出后保存工作台 `.design/SN_Asset_Workbench.blend`。
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

import glb_shared_textures  # noqa: E402
import glb_weapon_nodes  # noqa: E402

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
BACKUP_DIR = os.path.join(WORKDIR, ".design", "kits", "backup_glb")
TILES_DIR = os.path.join(WORKDIR, "docs", "design", "textures",
                         "shared_materials", "tiles")
URI_PREFIX = "shared_materials"

# (资产, 集合, 根空物体, 资产类别目录)
KITS = [
    ("SN_Weapon_Cannon", "SN_Weapon_Cannon_Prototype",
     "SN_Weapon_Cannon_Root", "weapons"),
    ("SN_Weapon_GunCarriage", "SN_Weapon_GunCarriage_Prototype",
     "SN_Weapon_GunCarriage_Root", "weapons"),
    ("SN_Weapon_Turret", "SN_Weapon_Turret_Prototype",
     "SN_Weapon_Turret_Root", "weapons"),
    ("SN_Weapon_Pedestal", "SN_Weapon_Pedestal_Prototype",
     "SN_Weapon_Pedestal_Root", "weapons"),
    ("SN_ShipPart_Deck", "SN_ShipPart_Deck_Prototype",
     "SN_ShipPart_Deck_Root", "ship_parts"),
    ("SN_ShipPart_Mast", "SN_ShipPart_Mast_Prototype",
     "SN_ShipPart_Mast_Root", "ship_parts"),
    ("SN_ShipPart_Funnel", "SN_ShipPart_Funnel_Prototype",
     "SN_ShipPart_Funnel_Root", "ship_parts"),
    ("SN_ShipPart_HatchCover", "SN_ShipPart_HatchCover_Prototype",
     "SN_ShipPart_HatchCover_Root", "ship_parts"),
]


def _out_dirs(category):
    dev = os.path.join(WORKDIR, "assets", "models", category)
    core = os.path.join(WORKDIR, "dev_mods", "core", "assets", "models",
                        category)
    return dev, core


def _backup(path):
    if not os.path.isfile(path):
        return None
    os.makedirs(BACKUP_DIR, exist_ok=True)
    base = os.path.splitext(os.path.basename(path))[0]
    stamp = time.strftime("%Y%m%d-%H%M%S")
    dst = os.path.join(BACKUP_DIR, "%s.%s.glb" % (base, stamp))
    shutil.copy2(path, dst)
    return dst


def _export_glb(asset, collection, root_name, out_dir):
    col = bpy.data.collections.get(collection)
    if col is None:
        raise RuntimeError("missing collection %s" % collection)
    root = bpy.data.objects.get(root_name)
    if root is None:
        raise RuntimeError("missing root empty %s" % root_name)

    path = os.path.join(out_dir, "%s.glb" % asset)
    os.makedirs(out_dir, exist_ok=True)
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


def _sync_shared_textures(category):
    dev, core = _out_dirs(category)
    copied = []
    for dst_dir in (os.path.join(dev, "shared_materials"),
                    os.path.join(core, "shared_materials")):
        os.makedirs(dst_dir, exist_ok=True)
        for src in sorted(glob.glob(os.path.join(TILES_DIR, "*.png"))):
            dst = os.path.join(dst_dir, os.path.basename(src))
            shutil.copy2(src, dst)
            copied.append(os.path.relpath(dst, WORKDIR).replace("\\", "/"))
    return copied


def export_all():
    results = []
    textures = {}
    for asset, collection, root_name, category in KITS:
        dev, core = _out_dirs(category)
        path, backup = _export_glb(asset, collection, root_name, dev)
        external = glb_shared_textures.externalize_glb(
            path, path,
            shared_dir=os.path.join(dev, "shared_materials"),
            uri_prefix=URI_PREFIX,
            tiles_dir=TILES_DIR,
            write_pngs=True,
            prefer_authored=True,
        )
        textures[asset] = external
        glb_weapon_nodes.standardize(path, asset)
        core_glb = os.path.join(core, "%s.glb" % asset)
        os.makedirs(core, exist_ok=True)
        shutil.copy2(path, core_glb)
        results.append({
            "asset": asset,
            "category": category,
            "glb": path,
            "core_glb": core_glb,
            "bytes": os.path.getsize(path),
            "backup": backup,
            "images": len(external.get("images", [])),
            "bytes_saved": external.get("bytes_saved", 0),
            "authored_pngs": sum(1 for p in external.get("pngs", [])
                                 if p.get("authored")),
        })
        print("EXPORTED %s -> %s (%d bytes) images=%d saved=%d" % (
            asset, path, results[-1]["bytes"], results[-1]["images"],
            results[-1]["bytes_saved"]))

    shared = {}
    for category in ("weapons", "ship_parts"):
        shared[category] = _sync_shared_textures(category)
    bpy.ops.wm.save_mainfile()
    report = {
        "workbench": bpy.data.filepath,
        "results": results,
        "shared_textures": shared,
    }
    print("KIT_EXPORT_DONE %r" % {
        "count": len(results),
        "workbench": report["workbench"],
        "shared_weapons": len(shared["weapons"]),
        "shared_ship_parts": len(shared["ship_parts"]),
    })
    return report


if __name__ == "__main__":
    export_all()
