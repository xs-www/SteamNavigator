# -*- coding: utf-8 -*-
# @static-doc
# 作用：模型素材库批次 4（M1-1 architecture_kit 扩展，6 件建筑可拼装件）的 GLB
# 归档导出与运行时副本同步；沿用批次 1–3 的导出 / 贴图外部化 / Core 同步模式。
#
# 数据源：`kit_batch4_generator.py`（本批唯一生成器）的 `ASSETS` / `SPECS` /
# `build_config(asset)` / `WORKBENCH_POS`；工单见
# `tools/modeling/briefs/sn_kit_batch4_architecture_extension.json`。
#
# 约定（见 MODELING_WORKFLOW §8 / §12 与 ASSET_MAP）：
# - 逐件导出：导出前把根空物体 location 临时归零，导出后还原；轴心即 root datum
#   （全部为地面件，根在体量底面中心，zmin=0）；
# - 只导出该集合内的对象（root / socket / mesh），不导相机、灯光、其它资产；
# - glTF 默认 +Y 向上，进入 Godot 后尺寸为 (Blender X, Blender Z, Blender Y)；
# - 覆盖前把旧 GLB 备份到 `.design/architecture/backup_glb/`（仅旧文件存在时）；
# - 贴图外部化复用 `glb_shared_textures.externalize_glb(..., prefer_authored=True)`，
#   URI 写 `shared_materials/<texture>.png`；
# - 同步 `assets/models/architecture/` 与
#   `dev_mods/core/assets/models/architecture/` 两处 GLB 副本，并把共享贴图
#   （`sn_shared_materials.texture_report()` 的 11 张授权 tile）补齐到两处
#   `shared_materials/`；
# - 全部导出后保存工作台 `.design/SN_Asset_Workbench.blend`。
#
# 用法（已连 Blender 的会话）：
#     import runpy; runpy.run_path(<本文件>, run_name="__main__")
# @end-static-doc

import os
import shutil
import sys
import time

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import glb_shared_textures  # noqa: E402
import kit_batch4_generator as gen  # noqa: E402
import sn_shared_materials as smat  # noqa: E402

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
CATEGORY = "architecture"
BACKUP_DIR = os.path.join(WORKDIR, ".design", "architecture", "backup_glb")
TILES_DIR = os.path.join(WORKDIR, "docs", "design", "textures",
                         "shared_materials", "tiles")
URI_PREFIX = "shared_materials"


# ---------------------------------------------------------------- 生成器接口

def _spec_for(asset):
    """从生成器读单件 spec；兼容 `SPECS`（dict）与 `SPEC`（dict/单件）两种形态。"""
    specs = getattr(gen, "SPECS", None)
    if isinstance(specs, dict) and isinstance(specs.get(asset), dict):
        return specs[asset]
    spec = getattr(gen, "SPEC", None)
    if isinstance(spec, dict):
        entry = spec.get(asset)
        if isinstance(entry, dict):
            return entry
        if spec.get("asset") == asset:
            return spec
    return {}


def _out_dirs():
    dev = os.path.join(WORKDIR, "assets", "models", CATEGORY)
    core = os.path.join(WORKDIR, "dev_mods", "core", "assets", "models",
                        CATEGORY)
    return dev, core


def _backup(path):
    """覆盖前把旧 GLB 备份到 `.design/architecture/backup_glb/`。"""
    if not os.path.isfile(path):
        return None
    os.makedirs(BACKUP_DIR, exist_ok=True)
    base = os.path.splitext(os.path.basename(path))[0]
    stamp = time.strftime("%Y%m%d-%H%M%S")
    dst = os.path.join(BACKUP_DIR, "%s.%s.glb" % (base, stamp))
    shutil.copy2(path, dst)
    return dst


def _collection_tris(collection):
    """集合内 mesh 的三角面数（n 边形按 n-2 计，与 glTF 导出三角化一致）。"""
    total = 0
    for ob in collection.objects:
        if ob.type != "MESH":
            continue
        total += sum(max(0, len(poly.vertices) - 2) for poly in ob.data.polygons)
    return total


# ---------------------------------------------------------------- 单件导出

def _export_one(asset, dev_dir, core_dir):
    cfg = gen.build_config(asset)
    spec = _spec_for(asset)
    collection = spec.get("collection") or cfg.collection
    root_name = spec.get("root") or cfg.root_name
    tri_budget = int(spec.get("tri_budget") or cfg.tri_budget or 0)

    col = bpy.data.collections.get(collection)
    if col is None:
        raise RuntimeError("missing collection %s" % collection)
    root = bpy.data.objects.get(root_name)
    if root is None:
        raise RuntimeError("missing root empty %s" % root_name)

    tris = _collection_tris(col)
    if tri_budget and tris > tri_budget:
        raise RuntimeError("%s over tri budget: %d > %d" % (
            asset, tris, tri_budget))

    expected_pos = getattr(gen, "WORKBENCH_POS", {}).get(asset)
    saved_loc = tuple(root.location)
    if expected_pos is not None and any(
            abs(saved_loc[i] - float(expected_pos[i])) > 1e-3 for i in range(3)):
        print("WARN %s root at %r != WORKBENCH_POS %r" % (
            asset, saved_loc, tuple(expected_pos)))

    path = os.path.join(dev_dir, "%s.glb" % asset)
    os.makedirs(dev_dir, exist_ok=True)
    backup = _backup(path)
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

    external = glb_shared_textures.externalize_glb(
        path, path,
        shared_dir=os.path.join(dev_dir, "shared_materials"),
        uri_prefix=URI_PREFIX,
        tiles_dir=TILES_DIR,
        write_pngs=True,
        prefer_authored=True,
    )
    images = external.get("images") or []
    if not images:
        raise RuntimeError("%s: no externalized images (shared textures missing)"
                           % asset)
    not_authored = [entry.get("name") for entry in images
                    if not entry.get("authored")
                    and not entry.get("already_external")]
    if not_authored:
        raise RuntimeError("%s: images not mapped to authored tiles: %r" % (
            asset, not_authored))

    core_glb = os.path.join(core_dir, "%s.glb" % asset)
    shutil.copy2(path, core_glb)

    bytes_total = os.path.getsize(path)
    print("EXPORTED %s tri=%d/%d bytes=%d images=%d -> %s" % (
        asset, tris, tri_budget, bytes_total, len(images),
        os.path.relpath(path, WORKDIR).replace("\\", "/")))
    return {
        "asset": asset,
        "collection": collection,
        "root": root_name,
        "glb": path,
        "core_glb": core_glb,
        "tris": tris,
        "tri_budget": tri_budget,
        "bytes": bytes_total,
        "backup": backup,
        "images": len(images),
        "bytes_saved": external.get("bytes_saved", 0),
        "authored_pngs": sum(1 for png in external.get("pngs", [])
                             if png.get("authored")),
    }


# ---------------------------------------------------------------- 共享贴图

def _sync_shared_textures(dev_dir, core_dir):
    """把 11 张授权 tile 复制到两处 architecture/shared_materials/。"""
    report = smat.texture_report()
    copied = []
    for dst_dir in (os.path.join(dev_dir, "shared_materials"),
                    os.path.join(core_dir, "shared_materials")):
        os.makedirs(dst_dir, exist_ok=True)
        for material in sorted(report):
            entry = report[material]
            src = os.path.join(WORKDIR, entry["file"])
            if not os.path.isfile(src):
                raise RuntimeError("missing authored tile for %s: %s" % (
                    material, src))
            dst = os.path.join(dst_dir, entry["texture"] + ".png")
            shutil.copy2(src, dst)
            copied.append(os.path.relpath(dst, WORKDIR).replace("\\", "/"))
    return copied


# ---------------------------------------------------------------- 全批导出

def export_all():
    dev_dir, core_dir = _out_dirs()
    os.makedirs(dev_dir, exist_ok=True)
    os.makedirs(core_dir, exist_ok=True)

    results = []
    for asset in gen.ASSETS:
        results.append(_export_one(asset, dev_dir, core_dir))

    shared = _sync_shared_textures(dev_dir, core_dir)
    bpy.ops.wm.save_mainfile()
    report = {
        "workbench": bpy.data.filepath,
        "results": results,
        "shared_textures": shared,
    }
    total_tris = sum(item["tris"] for item in results)
    print("KIT_BATCH4_EXPORT_DONE %r" % {
        "count": len(results),
        "total_tris": total_tris,
        "workbench": report["workbench"],
        "shared_png_copies": len(shared),
    })
    return report


if __name__ == "__main__":
    export_all()
