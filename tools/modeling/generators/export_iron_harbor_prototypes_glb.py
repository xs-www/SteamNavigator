# @static-doc
# 作用：批次 B 的 Blender 侧导出器：把工作台 y=200 / y=225 两排的三栋新原型（LOD0 + LOD1）逐件导出为单对象、根节点归零、内嵌贴图的 GLB 候选，并输出 tri/尺寸/材质槽/cell 报告；随后由 `glb_shared_textures.py` 外部化为共享贴图并安装进内容模组。
#
# ### 契约与约束
# - Blender 单写者：只在 Verifier 通过后由 Lead 在 live 工作台执行；不删改其它对象/集合（y=110/150/175 的 A 批 10 个对象、y=200 的三栋 LOD0 只在导出时临时归零位置，导出后恢复）。
# - 每栋导出前按栋重写 `sn_iron_harbor_materials.apply_to_object(obj, cells=...)`：6 个 `SN_Town_*` 是全局 datablock，最后一栋的 cells 会覆盖全部。
# - 候选写 `.design/buildings/iron_harbor/b4/embedded/`，不直接写内容 mod；旧内容 GLB 先备份到 `b4/legacy/`（不覆盖已有备份），`restore_legacy()` 可回滚。
# - LOD0 的 tri 必须精确等于 §6 验收表（BH 7 388 / WR 7 312 / BT 9 376）；LOD1 只校验硬上限 2 800 / 2 800 / 4 900（精确值由 Builder 的 LOD1 报告提供后可在 EXPECTED 里补）。
# - 导出后 `report_candidates()` 用 GLB 自身解析结果对账：单根节点、tri、内嵌贴图名、Godot 空间包围盒（Y-up，与 accessor 一致）与 Blender 本地包围盒一致。
# - `save_workbench()` 只在人工验收后调用：先备份旧 `.blend` 再保存。
# @end-static-doc

# -*- coding: utf-8 -*-
"""Export the batch-B prototype LOD0 + LOD1 candidates (Lead-owned, Blender side)."""

import hashlib
import importlib.util
import json
import os
import shutil

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
COLLECTION = "SN_Iron_Harbor_Architecture"
CONTENT_PROPS = os.path.join(REPO_ROOT, "dev_mods", "core", "assets", "models", "props")
B4_DIR = os.path.join(REPO_ROOT, ".design", "buildings", "iron_harbor", "b4")
CANDIDATE_DIR = os.path.join(B4_DIR, "embedded")
LEGACY_DIR = os.path.join(B4_DIR, "legacy")
WORKBENCH_PATH = os.path.join(REPO_ROOT, ".design", "SN_Asset_Workbench.blend")

#: asset -> workbench row/object tri expectations (LOD1 exact values filled in after
#: the Builder LOD1 report; the caps below are the requirement hard limits).
ASSETS = [
    {"asset": "SN_HT_Boiler_House", "location": (-45.0, 200.0, 0.0),
     "tri_lod0": 7388, "tri_lod1_cap": 2800, "tri_lod1_exact": 2536},
    {"asset": "SN_HT_Workshop_Row", "location": (0.0, 200.0, 0.0),
     "tri_lod0": 7312, "tri_lod1_cap": 2800, "tri_lod1_exact": 2444},
    {"asset": "SN_HT_Brick_Tenement", "location": (45.0, 200.0, 0.0),
     "tri_lod0": 9376, "tri_lod1_cap": 4900, "tri_lod1_exact": 2704},
]

#: Per-building trim-sheet cells, identical to the Builder's LOD0 report (§5).
CELLS = {
    "SN_HT_Boiler_House": {
        "SN_Town_Brick": "brick_wall_soot",
        "SN_Town_Plaster": "plaster_grime",
        "SN_Town_Wood": "wood_plank_weathered",
        "SN_Town_Iron": "iron_rust",
        "SN_Town_Stone": "stone_base_dirty",
        "SN_Town_Glass": "glass_dark",
    },
    "SN_HT_Workshop_Row": {
        "SN_Town_Brick": "brick_wall",
        "SN_Town_Plaster": "plaster_light",
        "SN_Town_Wood": "wood_plank",
        "SN_Town_Iron": "iron_dark",
        "SN_Town_Stone": "stone_base",
        "SN_Town_Glass": "glass_reflect",
    },
    "SN_HT_Brick_Tenement": {
        "SN_Town_Brick": "brick_wall",
        "SN_Town_Plaster": "plaster_grime",
        "SN_Town_Wood": "wood_plank_weathered",
        "SN_Town_Iron": "iron_dark",
        "SN_Town_Stone": "stone_base_dirty",
        "SN_Town_Glass": "glass_dark",
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


def _object_name(asset, lod):
    return "%s_%s" % (asset, lod)


def _content_name(asset, lod):
    return (asset + ".glb") if lod == "LOD0" else ("%s_%s.glb" % (asset, lod))


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
        "zmin": round(min(zs), 6),
        "pivot_ground_centre": abs(min(xs) + max(xs)) <= 1e-6 and abs(min(ys) + max(ys)) <= 1e-6,
    }


def backup_legacy():
    """Back up any already-installed prototype GLBs (never overwrite a backup)."""
    os.makedirs(LEGACY_DIR, exist_ok=True)
    out = {}
    for spec in ASSETS:
        for lod in ("LOD0", "LOD1"):
            file_name = _content_name(spec["asset"], lod)
            content = os.path.join(CONTENT_PROPS, file_name)
            backup = os.path.join(LEGACY_DIR, file_name)
            if not os.path.exists(content):
                out[file_name] = {"ok": False, "note": "not installed yet"}
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
    """Export single-object embedded-texture GLB candidates for the prototype rows."""
    import bpy

    os.makedirs(CANDIDATE_DIR, exist_ok=True)
    selected = assets or [spec["asset"] for spec in ASSETS]
    lods = ["LOD0", "LOD1"] if lod == "both" else [lod]
    mats = _materials()
    results = {}
    for spec in ASSETS:
        asset = spec["asset"]
        if asset not in selected:
            continue
        cells = CELLS.get(asset) or None
        for lod_name in lods:
            object_name = _object_name(asset, lod_name)
            obj = bpy.data.objects.get(object_name)
            if obj is None or obj.type != "MESH":
                results[object_name] = {"ok": False, "error": "object not found"}
                continue
            collection = bpy.data.collections.get(COLLECTION)
            if collection is None or collection not in obj.users_collection:
                results[object_name] = {"ok": False, "error": "not in %s" % COLLECTION}
                continue
            texture = mats.apply_to_object(obj, cells=cells)
            content = os.path.join(CANDIDATE_DIR, object_name + ".glb")
            original = tuple(obj.location)
            was_selected = list(bpy.context.selected_objects)
            was_active = bpy.context.view_layer.objects.active
            entry = {"ok": True, "cells": texture.get("materials", {}),
                     "uv_loops": texture.get("uv_loops"),
                     "textured_slots": texture.get("textured_slots"),
                     "geometry_unchanged_by_uv": texture.get("geometry_unchanged")}
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


def report_candidates():
    """Structure report of the exported candidates, parsed from the GLBs."""
    glb = _glb_tools()
    out = {}
    for spec in ASSETS:
        for lod in ("LOD0", "LOD1"):
            name = _object_name(spec["asset"], lod)
            path = os.path.join(CANDIDATE_DIR, name + ".glb")
            if not os.path.exists(path):
                out[name] = {"missing": True}
                continue
            structure = glb.structure_report(path)
            expected = int(spec["tri_lod0"]) if lod == "LOD0" else int(spec["tri_lod1_exact"] or 0)
            out[name] = {
                "asset": spec["asset"],
                "lod": lod,
                "tris": structure["tris"],
                "expected_tris": expected,
                "tri_cap": 0 if lod == "LOD0" else int(spec["tri_lod1_cap"]),
                "tris_ok": (structure["tris"] == expected) if expected else
                           (structure["tris"] <= int(spec["tri_lod1_cap"])),
                "nodes": [node["name"] for node in structure["nodes"]],
                "single_root_node": len(structure["nodes"]) == 1,
                "materials": [material["name"] for material in structure["materials"]],
                "images": [image["name"] for image in structure["images"]],
                "embedded_images": all(image.get("embedded") for image in structure["images"]),
                "bbox": structure["bbox"],
                "bytes": structure["bytes"],
                "sha256": structure["sha256"],
                "blender_bounds": RESULTS.get(name, {}).get("blender_bounds"),
                "cells": RESULTS.get(name, {}).get("cells"),
            }
    return out


def save_workbench(path=None):
    """Delivery snapshot of the workbench .blend (only after human acceptance)."""
    import bpy
    import time

    path = path or WORKBENCH_PATH
    os.makedirs(os.path.dirname(path), exist_ok=True)
    backup = os.path.join(B4_DIR, "SN_Asset_Workbench_pre_batch_b_%s.blend" % time.strftime("%Y%m%d"))
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
    print("export_iron_harbor_prototypes_glb: call backup_legacy() / export_candidates() / "
          "report_candidates() / save_workbench() / restore_legacy()")
