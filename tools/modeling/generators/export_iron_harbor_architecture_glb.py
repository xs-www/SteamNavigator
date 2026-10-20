"""Export the R1 `SN_HT_Warehouse_Long_LOD0` grey model to the PortStage content path.

Run this **inside Blender** through the MCP `execute_blender_code` tool:

    exec(compile(open("/abs/path/tools/modeling/generators/export_iron_harbor_architecture_glb.py").read(),
                 "export_iron_harbor_architecture_glb.py", "exec"))
    report = export_warehouse_long_r1()

The script (Lead-owned, after the independent Verifier passes):
- backs the legacy `SN_HT_Warehouse_Long.glb` up to
  `.design/buildings/iron_harbor/SN_HT_Warehouse_Long_legacy.glb`;
- temporarily zeroes the kit object's location (geometry is local, pivot = base
  centre) and exports a single-object GLB to
  `dev_mods/core/assets/models/props/SN_HT_Warehouse_Long.glb`;
- also keeps a candidate copy at
  `.design/buildings/iron_harbor/SN_HT_Warehouse_Long_R1.glb`;
- restores the workbench location, so the scene stays unchanged;
- never touches the runtime code or any other object.

`restore_legacy_glb()` copies the backup back, so the PortStage capture step is
reversible and the committed content keeps the old asset until the user decides.

Godot reads these raw GLBs through `ContentAssetLoader` (no editor re-import),
so replacing the file is enough for the preview scene to pick the new mesh.
"""

import hashlib
import os
import shutil

# Resolved from this file: <repo>/tools/modeling/generators/export_iron_harbor_architecture_glb.py
REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
CONTENT_PATH = os.path.join(REPO_ROOT, "dev_mods", "core", "assets", "models",
                            "props", "SN_HT_Warehouse_Long.glb")
BACKUP_DIR = os.path.join(REPO_ROOT, ".design", "buildings", "iron_harbor")
BACKUP_PATH = os.path.join(BACKUP_DIR, "SN_HT_Warehouse_Long_legacy.glb")
CANDIDATE_PATH = os.path.join(BACKUP_DIR, "SN_HT_Warehouse_Long_R1.glb")
OBJECT_NAME = "SN_HT_Warehouse_Long_LOD0"


def _sha256(path):
    if not os.path.exists(path):
        return None
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _tri_count(obj):
    import bmesh

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    result = sum(len(face.verts) - 2 for face in bm.faces)
    bm.free()
    return result


def export_warehouse_long_r1():
    import bpy

    obj = bpy.data.objects.get(OBJECT_NAME)
    if obj is None or obj.type != "MESH":
        return {"ok": False, "error": "object not found: %s" % OBJECT_NAME}

    os.makedirs(BACKUP_DIR, exist_ok=True)
    legacy_sha = _sha256(CONTENT_PATH)
    if not os.path.exists(BACKUP_PATH):
        if legacy_sha is None:
            return {"ok": False, "error": "missing content glb and no backup: %s" % CONTENT_PATH}
        shutil.copy2(CONTENT_PATH, BACKUP_PATH)

    original_location = tuple(obj.location)
    was_selected = list(bpy.context.selected_objects)
    try:
        for other in was_selected:
            other.select_set(False)
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        obj.location = (0.0, 0.0, 0.0)
        bpy.ops.export_scene.gltf(
            filepath=CONTENT_PATH,
            export_format="GLB",
            use_selection=True,
            export_apply=True,
            export_cameras=False,
            export_lights=False,
            export_yup=True,
            export_extras=False,
        )
    finally:
        obj.location = original_location
        obj.select_set(False)
        for other in was_selected:
            other.select_set(True)

    shutil.copy2(CONTENT_PATH, CANDIDATE_PATH)
    return {
        "ok": True,
        "object": OBJECT_NAME,
        "content_glb": CONTENT_PATH,
        "candidate_glb": CANDIDATE_PATH,
        "legacy_backup": BACKUP_PATH,
        "tris": _tri_count(obj),
        "bytes": os.path.getsize(CONTENT_PATH),
        "legacy_sha256": legacy_sha,
        "new_sha256": _sha256(CONTENT_PATH),
        "backup_sha256": _sha256(BACKUP_PATH),
    }


def restore_legacy_glb():
    if not os.path.exists(BACKUP_PATH):
        return {"ok": False, "error": "no legacy backup at %s" % BACKUP_PATH}
    shutil.copy2(BACKUP_PATH, CONTENT_PATH)
    return {"ok": True, "restored_to": CONTENT_PATH,
            "sha256": _sha256(CONTENT_PATH),
            "matches_backup": _sha256(CONTENT_PATH) == _sha256(BACKUP_PATH)}


if "bpy" in globals():  # executed inside Blender
    print("export_iron_harbor_architecture_glb: call export_warehouse_long_r1() "
          "/ restore_legacy_glb()")
