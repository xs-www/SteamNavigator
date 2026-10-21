# -*- coding: utf-8 -*-
# @static-doc
# 作用：M0-3 / M0-4 船侧 socket 的 GLB 归档导出（Blender 内执行，验收通过后由 Lead 运行）——
# 4 艘船（明轮货轮 / 明轮客船 / 纵帆船 / 铁甲舰）重新导出 GLB，保留 Root extras 与新增
# 武器 socket / 帆索 socket 空节点，外部化共享贴图为 `shared_materials/<texture>.png`，
# 备份旧 GLB，同步 Core 副本，最后依次调 `glb_ship_sockets.standardize()`（武器）与
# `glb_ship_rig_sockets.standardize()`（PF/SF/IC 的 Mast/Yard/Sail），把 BLEND 前缀名
# 归一化为 `SN_Socket_Weapon_*` / `SN_Socket_Mast|Yard|Sail_*` 并写入对应 Root 列表。
#
# 导出方式按根节点类型区分：
# - 多节点船体（PF / PS / SF）：根节点归零后导出整个集合（`export_extras=True`）；
# - 单 mesh 铁甲舰：根 mesh 归零，连同其 socket 子空节点一起导出（`export_extras=True`）；
#   这是本轮新增——批次 B 的铁甲舰导出是 `export_extras=False`，没有子节点。
#
# 前置条件：`sn_ship_weapon_sockets.verify_all()` 必须通过（只读复核场景里的 socket）。
# 目标目录：`assets/models/ships/` + `dev_mods/core/assets/models/ships/`；旧 GLB 备份到
# `.design/ship_sockets/backup_glb/`，导出报告写 `.design/ship_sockets/export_report.json`。
#
# 用法（已连 Blender 的会话）：
#     import runpy; runpy.run_path(<本文件>, run_name="__main__")
# @end-static-doc

import json
import os
import shutil
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import bpy

import glb_shared_textures
import glb_ship_sockets
import glb_ship_rig_sockets
import sn_ship_weapon_sockets as socks
import sn_ship_rig_sockets as rigsocks

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
TILES_DIR = os.path.join(WORKDIR, "docs", "design", "textures", "shared_materials", "tiles")
OUT_DIR = os.path.join(WORKDIR, "assets", "models", "ships")
CORE_DIR = os.path.join(WORKDIR, "dev_mods", "core", "assets", "models", "ships")
BACKUP_ROOT = os.path.join(WORKDIR, ".design", "ship_sockets", "backup_glb")
REPORT_PATH = os.path.join(WORKDIR, ".design", "ship_sockets", "export_report.json")
URI_PREFIX = "shared_materials"


def _relative(path):
    return os.path.relpath(path, WORKDIR).replace("\\", "/")


def _deselect_all():
    for obj in bpy.context.selected_objects:
        obj.select_set(False)


def _backup(path):
    if not os.path.isfile(path):
        return None
    os.makedirs(BACKUP_ROOT, exist_ok=True)
    base = os.path.splitext(os.path.basename(path))[0]
    stamp = time.strftime("%Y%m%d-%H%M%S")
    dst = os.path.join(BACKUP_ROOT, "%s.%s.glb" % (base, stamp))
    shutil.copy2(path, dst)
    return dst


def _descendants(obj):
    out = [obj]
    for child in obj.children:
        out.extend(_descendants(child))
    return out


def _export_selected(path, objects, active):
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


def _export_single_mesh(ship):
    obj = bpy.data.objects.get(ship["root"])
    if obj is None or obj.type != "MESH":
        raise RuntimeError("找不到铁甲舰网格 %s" % ship["root"])
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, "%s.glb" % ship["asset"])
    backup = _backup(path)
    saved_loc = tuple(obj.location)
    saved_selection = list(bpy.context.selected_objects)
    try:
        obj.location = (0.0, 0.0, 0.0)
        bpy.context.view_layer.update()
        _deselect_all()
        objects = _descendants(obj)
        for item in objects:
            item.select_set(True)
        bpy.context.view_layer.objects.active = obj
        _export_selected(path, objects, obj)
    finally:
        obj.location = saved_loc
        _deselect_all()
        for other in saved_selection:
            other.select_set(True)
        bpy.context.view_layer.update()
    return path, backup


def _export_collection(ship):
    collection = bpy.data.collections.get(ship["collection"])
    root = bpy.data.objects.get(ship["root"])
    if collection is None or root is None:
        raise RuntimeError("%s: 找不到集合或根" % ship["asset"])
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, "%s.glb" % ship["asset"])
    backup = _backup(path)
    saved_loc = tuple(root.location)
    saved_selection = list(bpy.context.selected_objects)
    try:
        root.location = (0.0, 0.0, 0.0)
        bpy.context.view_layer.update()
        _deselect_all()
        objects = list(collection.all_objects)
        for item in objects:
            item.select_set(True)
        bpy.context.view_layer.objects.active = root
        _export_selected(path, objects, root)
    finally:
        root.location = saved_loc
        _deselect_all()
        for other in saved_selection:
            other.select_set(True)
        bpy.context.view_layer.update()
    return path, backup


def _sync_core(path, asset, shared_out, shared_core, external):
    os.makedirs(CORE_DIR, exist_ok=True)
    os.makedirs(shared_core, exist_ok=True)
    core_glb = os.path.join(CORE_DIR, "%s.glb" % asset)
    shutil.copy2(path, core_glb)
    copied = 0
    for entry in external.get("pngs", []):
        name = os.path.basename(entry["png"])
        shutil.copy2(os.path.join(shared_out, name), os.path.join(shared_core, name))
        copied += 1
    return core_glb, copied


def export_all():
    summary = socks.verify_all()
    if not summary["passed"]:
        raise RuntimeError("socket 场景复核失败，拒绝导出：%s"
                           % [item["failures"] for item in summary["ships"]])
    rig_summary = rigsocks.verify_all()
    if not rig_summary["passed"]:
        raise RuntimeError("rig socket 场景复核失败，拒绝导出：%s"
                           % [item["failures"] for item in rig_summary["ships"]])
    rig_assets = {ship["asset"] for ship in rigsocks.SHIPS}
    results = []
    for ship in socks.SHIPS:
        if bpy.data.objects.get(ship["root"]) is None:
            raise RuntimeError("场景里找不到 %s，确认工作台 .blend 已打开" % ship["root"])
        if bpy.data.objects.get(ship["root"]).type == "MESH":
            path, backup = _export_single_mesh(ship)
        else:
            path, backup = _export_collection(ship)
        shared_out = os.path.join(OUT_DIR, "shared_materials")
        shared_core = os.path.join(CORE_DIR, "shared_materials")
        external = glb_shared_textures.externalize_glb(
            path, path,
            shared_dir=shared_out,
            uri_prefix=URI_PREFIX,
            tiles_dir=TILES_DIR,
            write_pngs=True,
            prefer_authored=True,
        )
        sock_report = glb_ship_sockets.standardize(path, ship["asset"])
        rig_report = None
        if ship["asset"] in rig_assets:
            rig_report = glb_ship_rig_sockets.standardize(path, ship["asset"])
        core_glb, core_tiles = _sync_core(path, ship["asset"], shared_out, shared_core, external)
        item = {
            "asset": ship["asset"],
            "glb": _relative(path),
            "core_glb": _relative(core_glb),
            "bytes": os.path.getsize(path),
            "backup": _relative(backup) if backup else None,
            "images": len(external.get("images", [])),
            "core_tiles": core_tiles,
            "sockets": sock_report["sockets"],
            "renamed_nodes": sock_report["renamed"],
            "rig_sockets": rig_report["sockets"] if rig_report else [],
            "rig_renamed_nodes": rig_report["renamed"] if rig_report else 0,
        }
        results.append(item)
        print("EXPORTED %-22s %8d bytes sockets=%d rig=%d renamed=%d"
              % (ship["asset"], item["bytes"], len(item["sockets"]),
                 len(item["rig_sockets"]),
                 item["renamed_nodes"] + item["rig_renamed_nodes"]))
    bpy.ops.wm.save_mainfile()
    report = {
        "workbench": bpy.data.filepath,
        "objects": len(results),
        "total_bytes": sum(item["bytes"] for item in results),
        "sockets": sum(len(item["sockets"]) for item in results),
        "rig_sockets": sum(len(item["rig_sockets"]) for item in results),
        "results": results,
    }
    os.makedirs(os.path.dirname(REPORT_PATH), exist_ok=True)
    with open(REPORT_PATH, "w", encoding="utf-8") as handle:
        json.dump(report, handle, ensure_ascii=False, indent=1)
    print("SHIP_SOCKET_EXPORT_DONE %r" % {
        "objects": report["objects"],
        "sockets": report["sockets"],
        "rig_sockets": report["rig_sockets"],
        "total_bytes": report["total_bytes"],
        "workbench": report["workbench"],
    })
    return report


if __name__ == "__main__":
    export_all()
