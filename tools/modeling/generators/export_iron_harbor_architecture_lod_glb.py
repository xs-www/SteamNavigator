# @static-doc
# 作用：批次 A 的 Blender 侧导出器：把工作台里 5 栋 LOD0 + 5 栋 LOD1 逐件导出为单对象、根节点归零、内嵌贴图的 GLB 候选，并输出逐件 tri/尺寸/材质槽/cell/结构报告；后续由 `glb_shared_textures.py`（纯 Python、Blender 外）统一外部化共享贴图并安装进内容模组。
#
# ### 契约与约束
# - Blender 单写者：只在 Verifier 通过后由 Lead 在 live 工作台执行；不删改其它对象与集合。
# - 每栋导出前必须重新 `sn_iron_harbor_materials.apply_to_object(obj, cells=...)`：6 个 `SN_Town_*` 材质是全局 datablock，最后一栋的 cells 会覆盖全部（BATCH2 §3 坑）。
# - 导出用 `use_selection + 根节点临时归零 + export_yup`；导出后恢复 location/选择/active；候选写 `.design/buildings/iron_harbor/a4/embedded/`，不直接写内容 mod。
# - 旧内容 GLB 先备份到 `.design/buildings/iron_harbor/a4/legacy/`（不覆盖已有备份），`restore_legacy()` 可回滚。
# - `save_workbench()` 只在人工验收后调用：先备份旧 `.blend` 再保存 `.design/SN_Asset_Workbench.blend`。
# - `report_candidates()` 用 GLB 自身解析结果对账：tri 必须等于验收表、单根节点、内嵌贴图、bbox 与 Blender 本地包围盒一致。
# @end-static-doc

# -*- coding: utf-8 -*-
"""Export the iron-harbor LOD0 + LOD1 building candidates (batch A, Lead-owned).

Run **inside Blender** through the MCP `execute_blender_code` tool after the
independent Verifier passes:

    p = r"<repo>/tools/modeling/generators/export_iron_harbor_architecture_lod_glb.py"
    ns = {"__name__": "export_iron_harbor_lod", "__file__": p}
    exec(compile(open(p, encoding="utf-8").read(), p, "exec"), ns)
    ns["backup_legacy"](); ns["export_candidates"](); ns["report_candidates"]()

What it does
------------
1. `backup_legacy()` — copies the currently installed content GLBs (LOD0) and
   any existing LOD1 GLBs into `.design/buildings/iron_harbor/a4/legacy/`
   (never overwrites an existing backup).
2. `export_candidates()` — for every building and LOD:
   - re-applies **that building's** trim-sheet cells (the six `SN_Town_*`
     materials are global datablocks; the cell set of the last building would
     otherwise leak into every export, see BATCH2 §3);
   - temporarily zeroes the object location (geometry is local, pivot = base
     centre), exports a single-object embedded-texture GLB to
     `.design/buildings/iron_harbor/a4/embedded/SN_HT_<Name>[_LOD1].glb`,
     and restores the workbench location/selection.
   The embedded GLBs are post-processed into the shared-texture form by
   `glb_shared_textures.py` (pure Python, run outside Blender); the candidates
   are **not** written into the content mod here.
3. `report_candidates()` — per asset tri / verts / size / material slots / cells
   / embedded image names / byte size / sha256, plus a structure report parsed
   from the exported GLB itself.
4. `save_workbench(path)` — optional delivery snapshot of the workbench (backs
   up the previous `.blend` first). Call only after the human acceptance step.
5. `restore_legacy()` — copies the backups back and can restore the workbench
   row (not required unless rolling back).

The candidate directory keeps the `iron_harbor_shared/` sibling so the same
relative `images[].uri` works before and after installing into the content mod.
"""

import hashlib
import importlib.util
import json
import os
import shutil

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
COLLECTION = "SN_Iron_Harbor_Architecture"
CONTENT_PROPS = os.path.join(REPO_ROOT, "dev_mods", "core", "assets", "models", "props")
WORKBENCH_DIR = os.path.join(REPO_ROOT, ".design", "buildings", "iron_harbor")
A4_DIR = os.path.join(WORKBENCH_DIR, "a4")
CANDIDATE_DIR = os.path.join(A4_DIR, "embedded")
LEGACY_DIR = os.path.join(A4_DIR, "legacy")
WORKBENCH_PATH = os.path.join(REPO_ROOT, ".design", "SN_Asset_Workbench.blend")

#: asset -> (workbench location, LOD0/LOD1 tri) — tris are the acceptance numbers.
ASSETS = [
    {"asset": "SN_HT_Warehouse_Long", "location": (-48.0, 150.0, 0.0), "tris": {"LOD0": 7436, "LOD1": 1584}},
    {"asset": "SN_HT_Warehouse_Short", "location": (-30.0, 150.0, 0.0), "tris": {"LOD0": 3788, "LOD1": 1060}},
    {"asset": "SN_HT_Harbor_Office", "location": (-10.0, 150.0, 0.0), "tris": {"LOD0": 10336, "LOD1": 1896}},
    {"asset": "SN_HT_Cargo_Shed", "location": (10.0, 150.0, 0.0), "tris": {"LOD0": 3356, "LOD1": 776}},
    {"asset": "SN_HT_Tavern", "location": (30.0, 150.0, 0.0), "tris": {"LOD0": 5116, "LOD1": 1248}},
]

#: Per-building trim-sheet cells, identical to `sn_iron_harbor_kit_batch2.BUILDINGS`
#: (Warehouse_Long uses the materials module defaults, as in M1).
CELLS = {
    # M1 default cells of the shared materials module (explicit so the verifier
    # can assert the per-building image set from one table).
    "SN_HT_Warehouse_Long": {
        "SN_Town_Brick": "brick_wall",
        "SN_Town_Plaster": "plaster_light",
        "SN_Town_Wood": "wood_plank_weathered",
        "SN_Town_Iron": "iron_dark",
        "SN_Town_Stone": "stone_base_dirty",
        "SN_Town_Glass": "glass_dark",
    },
    "SN_HT_Warehouse_Short": {
        "SN_Town_Brick": "brick_wall",
        "SN_Town_Plaster": "plaster_light",
        "SN_Town_Wood": "wood_plank",
        "SN_Town_Iron": "iron_rust",
        "SN_Town_Stone": "stone_base",
        "SN_Town_Glass": "glass_dark",
    },
    "SN_HT_Harbor_Office": {
        "SN_Town_Brick": "brick_wall",
        "SN_Town_Plaster": "plaster_light",
        "SN_Town_Wood": "wood_plank_weathered",
        "SN_Town_Iron": "iron_dark",
        "SN_Town_Stone": "stone_base",
        "SN_Town_Glass": "glass_reflect",
    },
    "SN_HT_Cargo_Shed": {
        "SN_Town_Brick": "brick_wall",
        "SN_Town_Plaster": "plaster_grime",
        "SN_Town_Wood": "wood_plank",
        "SN_Town_Iron": "iron_rust",
        "SN_Town_Stone": "stone_base",
        "SN_Town_Glass": "glass_dark",
    },
    "SN_HT_Tavern": {
        "SN_Town_Brick": "brick_wall",
        "SN_Town_Plaster": "plaster_grime",
        "SN_Town_Wood": "wood_plank",
        "SN_Town_Iron": "iron_dark",
        "SN_Town_Stone": "stone_base_dirty",
        "SN_Town_Glass": "glass_reflect",
    },
}

RESULTS = {}


def _load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _materials():
    return _load(os.path.join(HERE, "sn_iron_harbor_materials.py"), "sn_iron_harbor_materials")


def _glb_tools():
    return _load(os.path.join(HERE, "glb_shared_textures.py"), "glb_shared_textures")


def _sha256(path):
    if not os.path.exists(path):
        return None
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _object_names(asset):
    return [asset + "_LOD0", asset + "_LOD1"]


def _content_name(object_name):
    """Workbench object -> runtime GLB file name (LOD0 keeps the bare asset name)."""
    return object_name[:-5] + ".glb" if object_name.endswith("_LOD0") else object_name + ".glb"


def _tri_count(obj):
    import bmesh

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    result = sum(len(face.verts) - 2 for face in bm.faces)
    bm.free()
    return result


def _local_bounds(obj):
    mesh = obj.data
    xs = [vertex.co.x for vertex in mesh.vertices]
    ys = [vertex.co.y for vertex in mesh.vertices]
    zs = [vertex.co.z for vertex in mesh.vertices]
    return {
        "size": [round(max(xs) - min(xs), 4), round(max(ys) - min(ys), 4), round(max(zs) - min(zs), 4)],
        "min": [round(min(xs), 4), round(min(ys), 4), round(min(zs), 4)],
        "max": [round(max(xs), 4), round(max(ys), 4), round(max(zs), 4)],
        "zmin": round(min(zs), 6),
        "pivot_ground_centre": abs(min(xs) + max(xs)) <= 1e-6 and abs(min(ys) + max(ys)) <= 1e-6,
    }


def backup_legacy():
    """Back up the currently installed content GLBs (never overwrite a backup)."""
    import bpy

    os.makedirs(LEGACY_DIR, exist_ok=True)
    out = {}
    for spec in ASSETS:
        asset = spec["asset"]
        for name in _object_names(asset):
            file_name = _content_name(name)
            content = os.path.join(CONTENT_PROPS, file_name)
            backup = os.path.join(LEGACY_DIR, file_name)
            if not os.path.exists(content):
                out[file_name] = {"ok": False, "note": "no installed glb (new LOD?)"}
                continue
            if not os.path.exists(backup):
                shutil.copy2(content, backup)
            out[file_name] = {
                "ok": True,
                "content_sha256": _sha256(content),
                "backup_sha256": _sha256(backup),
                "bytes": os.path.getsize(content),
            }
    return out


def export_candidates(assets=None, lod="both"):
    """Export single-object embedded-texture GLB candidates for the workbench row."""
    import bpy

    os.makedirs(CANDIDATE_DIR, exist_ok=True)
    selected_assets = assets or [spec["asset"] for spec in ASSETS]
    lods = ["LOD0", "LOD1"] if lod == "both" else [lod]
    mats = _materials()
    results = {}
    for spec in ASSETS:
        asset = spec["asset"]
        if asset not in selected_assets:
            continue
        cells = CELLS.get(asset) or None
        for lod_name in lods:
            object_name = "%s_%s" % (asset, lod_name)
            obj = bpy.data.objects.get(object_name)
            if obj is None or obj.type != "MESH":
                results[object_name] = {"ok": False, "error": "object not found"}
                continue
            if not _in_collection(obj):
                results[object_name] = {"ok": False, "error": "object not in %s" % COLLECTION}
                continue
            # The six SN_Town_* materials are shared datablocks: rewrite this
            # building's cells right before its own export.
            texture = mats.apply_to_object(obj, cells=cells)
            content = os.path.join(CANDIDATE_DIR, object_name + ".glb")
            original = tuple(obj.location)
            was_selected = list(bpy.context.selected_objects)
            was_active = bpy.context.view_layer.objects.active
            entry = {"ok": True, "cells": texture.get("materials", {}), "texture": {
                key: texture.get(key) for key in ("uv_loops", "textured_slots", "geometry_unchanged")
            }}
            try:
                for other in was_selected:
                    other.select_set(False)
                obj.select_set(True)
                bpy.context.view_layer.objects.active = obj
                obj.location = (0.0, 0.0, 0.0)
                bpy.ops.export_scene.gltf(
                    filepath=content,
                    export_format="GLB",
                    use_selection=True,
                    export_apply=True,
                    export_cameras=False,
                    export_lights=False,
                    export_yup=True,
                    export_extras=False,
                )
            finally:
                obj.location = original
                obj.select_set(False)
                for other in was_selected:
                    other.select_set(True)
                bpy.context.view_layer.objects.active = was_active
            entry.update({
                "path": os.path.relpath(content, REPO_ROOT),
                "bytes": os.path.getsize(content),
                "sha256": _sha256(content),
                "blender_tris": _tri_count(obj),
                "blender_bounds": _local_bounds(obj),
            })
            results[object_name] = entry
    RESULTS.update(results)
    return results


def _in_collection(obj):
    import bpy

    collection = bpy.data.collections.get(COLLECTION)
    if collection is None:
        return False
    return collection in obj.users_collection


def report_candidates():
    """Structure report of the exported candidates (parsed from the GLB itself)."""
    glb = _glb_tools()
    out = {}
    for spec in ASSETS:
        asset = spec["asset"]
        for name in _object_names(asset):
            lod = "LOD1" if name.endswith("LOD1") else "LOD0"
            path = os.path.join(CANDIDATE_DIR, name + ".glb")
            if not os.path.exists(path):
                out[name] = {"missing": True}
                continue
            structure = glb.structure_report(path)
            blender_entry = RESULTS.get(name, {})
            out[name] = {
                "asset": asset,
                "lod": lod,
                "tris": structure["tris"],
                "expected_tris": spec["tris"][lod],
                "tris_ok": structure["tris"] == spec["tris"][lod],
                "nodes": [node["name"] for node in structure["nodes"]],
                "single_root_node": len(structure["nodes"]) == 1,
                "materials": [material["name"] for material in structure["materials"]],
                "images": [image["name"] for image in structure["images"]],
                "embedded_images": all(image.get("embedded") for image in structure["images"]),
                "bbox": structure["bbox"],
                "bytes": structure["bytes"],
                "sha256": structure["sha256"],
                "blender_bounds": blender_entry.get("blender_bounds"),
                "cells": blender_entry.get("cells"),
            }
    return out


def save_workbench(path=None):
    """Delivery snapshot of the workbench .blend (only after human acceptance)."""
    import bpy

    import time

    path = path or WORKBENCH_PATH
    os.makedirs(os.path.dirname(path), exist_ok=True)
    backup = os.path.join(A4_DIR, "SN_Asset_Workbench_pre_batch_a_%s.blend" % time.strftime("%Y%m%d"))
    if os.path.exists(path) and not os.path.exists(backup):
        os.makedirs(os.path.dirname(backup), exist_ok=True)
        shutil.copy2(path, backup)
    bpy.ops.wm.save_as_mainfile(filepath=path)
    return {"ok": True, "path": os.path.relpath(path, REPO_ROOT),
            "bytes": os.path.getsize(path), "sha256": _sha256(path),
            "previous_backup": os.path.relpath(backup, REPO_ROOT) if os.path.exists(backup) else None}


def restore_legacy():
    out = {}
    for file_name in sorted(os.listdir(LEGACY_DIR)) if os.path.isdir(LEGACY_DIR) else []:
        if not file_name.endswith(".glb"):
            continue
        backup = os.path.join(LEGACY_DIR, file_name)
        content = os.path.join(CONTENT_PROPS, file_name)
        shutil.copy2(backup, content)
        out[file_name] = {"ok": True, "sha256": _sha256(content), "bytes": os.path.getsize(content)}
    return out


if "bpy" in globals():  # executed inside Blender
    print("export_iron_harbor_architecture_lod_glb: call backup_legacy() / export_candidates() / "
          "report_candidates() / save_workbench() / restore_legacy()")
