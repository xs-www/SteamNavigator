# -*- coding: utf-8 -*-
# @static-doc
# 作用：旧资产 UV 迁移 B 的 GLB 归档导出（验收通过后由 Lead 在 Blender 内执行）——
# 导出 12 件船模块（11 件专用 + modules 占位副本）、4 艘船、5 件旧小镇剩余道具，
# 把内嵌贴图外部化为 `shared_materials/<texture>.png`，旧 GLB 备份到
# `.design/legacy_uv_b/backup_glb/`，并同步 `dev_mods/core` 副本与共享贴图目录。
#
# 导出方式按资产类型区分：
# - 单 mesh（模块 / 旧小镇 / 铁甲舰）：逐件 `location` 归零，只导该对象（`export_extras=False`）；
# - 多节点船体（明轮货轮 / 明轮客船 / 纵帆船）：根节点归零后导出整个集合
#   （`export_extras=True`，保留 Root extras 契约）。
#
# 目标目录：
# - modules：`assets/models/modules/` + Core 副本；
# - ships：`assets/models/ships/` + Core 副本；
# - town：只写 `dev_mods/core/assets/models/props/`（旧小镇建筑 GLB 已是建筑套件产物，不覆盖）。
#
# 用法（已连 Blender 的会话）：
#     import runpy; runpy.run_path(<本文件>, run_name="__main__")
# @end-static-doc

import json
import os
import shutil
import time

import bpy

import glb_shared_textures
import sn_legacy_uv_migration as mig

HERE = os.path.dirname(os.path.abspath(__file__))
WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
TILES_DIR = os.path.join(WORKDIR, "docs", "design", "textures", "shared_materials", "tiles")
BACKUP_ROOT = os.path.join(WORKDIR, ".design", "legacy_uv_b", "backup_glb")
REPORT_PATH = os.path.join(WORKDIR, ".design", "legacy_uv_b", "export_report.json")
URI_PREFIX = "shared_materials"

CATEGORY_DIRS = {
    "modules": {
        "out": os.path.join(WORKDIR, "assets", "models", "modules"),
        "core": os.path.join(WORKDIR, "dev_mods", "core", "assets", "models", "modules"),
        "mirror": True,
    },
    "ships": {
        "out": os.path.join(WORKDIR, "assets", "models", "ships"),
        "core": os.path.join(WORKDIR, "dev_mods", "core", "assets", "models", "ships"),
        "mirror": True,
    },
    "town": {
        # 旧小镇内容资产只存在于 core mod；assets/models/props 没有 SN_HT_* 副本
        "out": os.path.join(WORKDIR, "dev_mods", "core", "assets", "models", "props"),
        "core": None,
        "mirror": False,
    },
}


def _backup(path, category):
    if not os.path.isfile(path):
        return None
    folder = os.path.join(BACKUP_ROOT, category)
    os.makedirs(folder, exist_ok=True)
    base = os.path.splitext(os.path.basename(path))[0]
    stamp = time.strftime("%Y%m%d-%H%M%S")
    dst = os.path.join(folder, "%s.%s.glb" % (base, stamp))
    shutil.copy2(path, dst)
    return dst


def _deselect_all():
    for ob in bpy.context.selected_objects:
        ob.select_set(False)


def _export_glb(path, selected, active, extras):
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        export_extras=extras,
    )


def export_single(name, category):
    obj = bpy.data.objects.get(name)
    if obj is None or obj.type != "MESH":
        raise RuntimeError("找不到网格对象 %s" % name)
    out_dir = CATEGORY_DIRS[category]["out"]
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "%s.glb" % name)
    backup = _backup(path, category)
    saved_loc = tuple(obj.location)
    saved_selection = list(bpy.context.selected_objects)
    try:
        obj.location = (0.0, 0.0, 0.0)
        bpy.context.view_layer.update()
        _deselect_all()
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        _export_glb(path, [obj], obj, extras=False)
    finally:
        obj.location = saved_loc
        _deselect_all()
        for other in saved_selection:
            other.select_set(True)
        bpy.context.view_layer.update()
    return path, backup


def export_collection(asset, collection_name, root_name, category):
    collection = bpy.data.collections.get(collection_name)
    root = bpy.data.objects.get(root_name)
    if collection is None:
        raise RuntimeError("找不到集合 %s" % collection_name)
    if root is None:
        raise RuntimeError("找不到根空物体 %s" % root_name)
    out_dir = CATEGORY_DIRS[category]["out"]
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "%s.glb" % asset)
    backup = _backup(path, category)
    objects = list(collection.all_objects)
    saved_loc = tuple(root.location)
    saved_selection = list(bpy.context.selected_objects)
    try:
        root.location = (0.0, 0.0, 0.0)
        bpy.context.view_layer.update()
        _deselect_all()
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = root
        _export_glb(path, objects, root, extras=True)
    finally:
        root.location = saved_loc
        _deselect_all()
        for other in saved_selection:
            other.select_set(True)
        bpy.context.view_layer.update()
    return path, backup


def _sync_used_tiles(shared_out, shared_core, external):
    """把本次 GLB 实际引用的 tile 同步到 Core 共享目录。"""
    if not shared_core:
        return 0
    os.makedirs(shared_core, exist_ok=True)
    count = 0
    for entry in external.get("pngs", []):
        name = os.path.basename(entry["png"])
        shutil.copy2(os.path.join(shared_out, name), os.path.join(shared_core, name))
        count += 1
    return count


def _finalize_item(asset, category, path, backup):
    out_dir = CATEGORY_DIRS[category]["out"]
    core_dir = CATEGORY_DIRS[category]["core"]
    shared_out = os.path.join(out_dir, "shared_materials")
    external = glb_shared_textures.externalize_glb(
        path, path,
        shared_dir=shared_out,
        uri_prefix=URI_PREFIX,
        tiles_dir=TILES_DIR,
        write_pngs=True,
        prefer_authored=True,
    )
    core_glb = None
    core_tiles = 0
    core_backup = None
    if CATEGORY_DIRS[category]["mirror"] and core_dir:
        os.makedirs(core_dir, exist_ok=True)
        core_glb = os.path.join(core_dir, "%s.glb" % asset)
        if os.path.isfile(core_glb) and not backup:
            # 只在 assets 侧原本没有文件时（如 modules/SN_Boiler_Unit 占位副本）
            # 单独备份 Core 旧文件，避免丢唯一旧版本。
            core_backup = _backup(core_glb, category)
        shutil.copy2(path, core_glb)
        core_tiles = _sync_used_tiles(shared_out,
                                      os.path.join(core_dir, "shared_materials"),
                                      external)
    return {
        "asset": asset,
        "category": category,
        "glb": os.path.relpath(path, WORKDIR).replace("\\", "/"),
        "bytes": os.path.getsize(path),
        "backup": (os.path.relpath(backup, WORKDIR).replace("\\", "/")
                   if backup else None),
        "core_backup": (os.path.relpath(core_backup, WORKDIR).replace("\\", "/")
                        if core_backup else None),
        "core_glb": (os.path.relpath(core_glb, WORKDIR).replace("\\", "/")
                     if core_glb else None),
        "core_tiles": core_tiles,
        "images": len(external.get("images", [])),
        "authored_pngs": sum(1 for p in external.get("pngs", [])
                             if p.get("authored")),
    }


def export_all():
    scene_check = mig.verify_scene_b()
    if not scene_check["ok"]:
        raise RuntimeError("迁移未完成，拒绝导出：%s" % scene_check["failures"])

    results = []
    for category in ("modules", "town"):
        for name in mig.BATCH_B_SINGLE[category]:
            path, backup = export_single(name, category)
            item = _finalize_item(name, category, path, backup)
            results.append(item)
            print("EXPORTED %-24s %-8s %7d bytes images=%d" % (
                name, category, item["bytes"], item["images"]))
    for name in mig.BATCH_B_SINGLE["ships"]:
        path, backup = export_single(name, "ships")
        item = _finalize_item(name, "ships", path, backup)
        results.append(item)
        print("EXPORTED %-24s %-8s %7d bytes images=%d" % (
            name, "ships", item["bytes"], item["images"]))
    for asset, collection_name, root_name in mig.BATCH_B_SHIPS:
        path, backup = export_collection(asset, collection_name, root_name, "ships")
        item = _finalize_item(asset, "ships", path, backup)
        results.append(item)
        print("EXPORTED %-24s %-8s %7d bytes images=%d" % (
            asset, "ships", item["bytes"], item["images"]))

    bpy.ops.wm.save_mainfile()
    report = {
        "workbench": bpy.data.filepath,
        "objects": len(results),
        "modules": sum(1 for r in results if r["category"] == "modules"),
        "ships": sum(1 for r in results if r["category"] == "ships"),
        "town": sum(1 for r in results if r["category"] == "town"),
        "total_bytes": sum(r["bytes"] for r in results),
        "results": results,
    }
    os.makedirs(os.path.dirname(REPORT_PATH), exist_ok=True)
    with open(REPORT_PATH, "w", encoding="utf-8") as handle:
        json.dump(report, handle, ensure_ascii=False, indent=1)
    print("LEGACY_UV_B_EXPORT_DONE %r" % {
        "objects": report["objects"],
        "modules": report["modules"],
        "ships": report["ships"],
        "town": report["town"],
        "total_bytes": report["total_bytes"],
        "workbench": report["workbench"],
    })
    return report


if __name__ == "__main__":
    export_all()
