# -*- coding: utf-8 -*-
# @static-doc
# 作用：旧资产 UV 迁移 A 的 GLB 归档导出（验收通过后由 Lead 在 Blender 内执行）——
# 逐件导出 31 件铁港道具 + 6 件港口设施，把 GLB 内嵌贴图外部化为
# `shared_materials/<texture>.png` 共享 URI，旧 GLB 备份到 `.design/legacy_uv/backup_glb/`，
# 并把 GLB + 共享贴图同步到 `dev_mods/core` 副本，最后保存工作台。
#
# 约定（见 docs/design/MODELING_WORKFLOW.md 第 8 节）：
# - 迁移必须已由 `sn_legacy_uv_migration.migrate_all()` 完成并通过 `verify_scene()`；
# - 逐件导出：导出前把 `object.location` 临时归零（轴心 = 底面中心）、只选该对象，导出后还原；
# - glTF 默认 +Y 向上；每个 .glb 只含一个网格节点；
# - 贴图外部化复用 `glb_shared_textures.externalize_glb(..., prefer_authored=True)`：
#   共享 PNG 使用 `docs/design/textures/shared_materials/tiles/` 的授权源字节；
# - props / port 各自持有一份 `shared_materials/` 运行时副本（与现有分类目录约定一致）；
# - 全部导出后保存 `.design/SN_Asset_Workbench.blend`，报告写
#   `.design/legacy_uv/export_report.json`（本地产物）。
#
# 用法（已连 Blender 的会话）：
#     import runpy; runpy.run_path(<本文件>, run_name="__main__")
# 或后台：
#     blender -b .design/SN_Asset_Workbench.blend -P tools/modeling/generators/export_legacy_uv_glb.py
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
BACKUP_ROOT = os.path.join(WORKDIR, ".design", "legacy_uv", "backup_glb")
REPORT_PATH = os.path.join(WORKDIR, ".design", "legacy_uv", "export_report.json")
URI_PREFIX = "shared_materials"

CATEGORY_DIRS = {
    "props": {
        "out": os.path.join(WORKDIR, "assets", "models", "props"),
        "core": os.path.join(WORKDIR, "dev_mods", "core", "assets", "models", "props"),
    },
    "port": {
        "out": os.path.join(WORKDIR, "assets", "models", "port"),
        "core": os.path.join(WORKDIR, "dev_mods", "core", "assets", "models", "port"),
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


def export_one(name, category):
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
        obj.location = saved_loc
        _deselect_all()
        for other in saved_selection:
            other.select_set(True)
        bpy.context.view_layer.update()
    return path, backup


def _sync_tiles(shared_dir):
    """把授权 tile 字节复制到指定运行时共享贴图目录；返回复制数量。"""
    os.makedirs(shared_dir, exist_ok=True)
    copied = 0
    for name in sorted(os.listdir(TILES_DIR)):
        if not name.endswith(".png"):
            continue
        shutil.copy2(os.path.join(TILES_DIR, name), os.path.join(shared_dir, name))
        copied += 1
    return copied


def export_all():
    scene_check = mig.verify_scene()
    if not scene_check["ok"]:
        raise RuntimeError("迁移未完成，拒绝导出：%s" % scene_check["failures"])

    results = []
    texture_sync = []
    for category, names in mig.TARGETS.items():
        out_dir = CATEGORY_DIRS[category]["out"]
        core_dir = CATEGORY_DIRS[category]["core"]
        shared_out = os.path.join(out_dir, "shared_materials")
        shared_core = os.path.join(core_dir, "shared_materials")
        os.makedirs(core_dir, exist_ok=True)
        for name in names:
            path, backup = export_one(name, category)
            external = glb_shared_textures.externalize_glb(
                path, path,
                shared_dir=shared_out,
                uri_prefix=URI_PREFIX,
                tiles_dir=TILES_DIR,
                write_pngs=True,
                prefer_authored=True,
            )
            core_glb = os.path.join(core_dir, "%s.glb" % name)
            shutil.copy2(path, core_glb)
            summary = {
                "asset": name,
                "category": category,
                "glb": os.path.relpath(path, WORKDIR).replace("\\", "/"),
                "bytes": os.path.getsize(path),
                "backup": (os.path.relpath(backup, WORKDIR).replace("\\", "/")
                           if backup else None),
                "core_glb": os.path.relpath(core_glb, WORKDIR).replace("\\", "/"),
                "images": len(external.get("images", [])),
                "bytes_saved": external.get("bytes_saved", 0),
                "authored_pngs": sum(1 for p in external.get("pngs", [])
                                     if p.get("authored")),
            }
            results.append(summary)
            print("EXPORTED %-22s %-6s %7d bytes images=%d authored=%d" % (
                name, category, summary["bytes"], summary["images"],
                summary["authored_pngs"]))
        texture_sync.append({
            "category": category,
            "core_textures": _sync_tiles(shared_core),
            # 开发态目录也补齐全部 11 张 tile（externalize 只写本批用到的 ~7 张，
            # 目录内容与 props / 其它分类保持一致的完整共享贴图库）。
            "dev_textures": _sync_tiles(shared_out),
        })

    bpy.ops.wm.save_mainfile()
    report = {
        "workbench": bpy.data.filepath,
        "uv_space": mig.UV_SPACE,
        "objects": len(results),
        "props": sum(1 for r in results if r["category"] == "props"),
        "port": sum(1 for r in results if r["category"] == "port"),
        "total_bytes": sum(r["bytes"] for r in results),
        "texture_sync": texture_sync,
        "results": results,
    }
    os.makedirs(os.path.dirname(REPORT_PATH), exist_ok=True)
    with open(REPORT_PATH, "w", encoding="utf-8") as handle:
        json.dump(report, handle, ensure_ascii=False, indent=1)
    print("LEGACY_UV_EXPORT_DONE %r" % {
        "objects": report["objects"],
        "total_bytes": report["total_bytes"],
        "workbench": report["workbench"],
    })
    return report


if __name__ == "__main__":
    export_all()
