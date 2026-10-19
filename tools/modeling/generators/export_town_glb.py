"""Export the `SN_Harbor_Town` builder collection to individual GLBs.

Run this **inside Blender** through the MCP `execute_blender_code` tool after the
modeling Builder and the independent Verifier both pass (Lead owns this step).
The Builder never saves or exports the file, so the workbench scene stays clean.

Usage (inside Blender, after the Lead has verified the collection):

    exec(compile(open("/abs/path/tools/modeling/generators/export_town_glb.py").read(),
                 "export_town_glb.py", "exec"))
    report = export_harbor_town()

The script:
- finds every object in `SN_Harbor_Town` whose name starts with `SN_HT_`;
- temporarily zeroes each object's location (geometry is already local and the
  pivot is the base centre) and exports a single-object GLB;
- restores the layout location afterwards, so the workbench is unchanged;
- writes to `dev_mods/core/assets/models/props/SN_HT_<Name>.glb` (content assets
  ship inside the core mod; `assets/models/*` is excluded from the game PCK);
- prints a per-file triangle count / byte size report and returns it as a dict.

Godot reads these raw GLBs through `ContentAssetLoader`; they are not imported
by the editor. Keep `.gltf` settings identical to the other core props:
glTF Y-up, embedded buffers, no cameras/lights.
"""

import os

# Resolved from this file: <repo>/tools/modeling/generators/export_town_glb.py
REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT_DIR = os.path.join(REPO_ROOT, "dev_mods", "core", "assets", "models", "props")
COLLECTION_NAME = "SN_Harbor_Town"
PREFIX = "SN_HT_"


def _tri_count(obj):
    import bmesh

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    result = sum(len(face.verts) - 2 for face in bm.faces)
    bm.free()
    return result


def export_harbor_town():
    import bpy

    scene = bpy.context.scene
    collection = bpy.data.collections.get(COLLECTION_NAME)
    if collection is None:
        return {"ok": False, "error": "collection not found: %s (scene=%s)" % (COLLECTION_NAME, scene.name)}

    objects = [obj for obj in collection.objects if obj.name.startswith(PREFIX)]
    objects.sort(key=lambda obj: obj.name)
    if not objects:
        return {"ok": False, "error": "no %s objects in %s" % (PREFIX, COLLECTION_NAME)}

    os.makedirs(OUT_DIR, exist_ok=True)
    report = {"ok": True, "collection": COLLECTION_NAME, "out_dir": OUT_DIR, "items": []}
    for obj in objects:
        if obj.type != "MESH":
            report["ok"] = False
            report["items"].append({"name": obj.name, "error": "not a mesh: %s" % obj.type})
            continue
        original_location = tuple(obj.location)
        was_selected = [other for other in bpy.context.selected_objects]
        try:
            for other in was_selected:
                other.select_set(False)
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            obj.location = (0.0, 0.0, 0.0)
            file_name = obj.name + ".glb"
            file_path = os.path.join(OUT_DIR, file_name)
            bpy.ops.export_scene.gltf(
                filepath=file_path,
                export_format="GLB",
                use_selection=True,
                export_apply=True,
                export_cameras=False,
                export_lights=False,
                export_yup=True,
                export_extras=False,
            )
            report["items"].append({
                "name": obj.name,
                "file": file_path,
                "tris": _tri_count(obj),
                "bytes": os.path.getsize(file_path) if os.path.exists(file_path) else 0,
            })
        finally:
            obj.location = original_location
            obj.select_set(False)
            for other in was_selected:
                other.select_set(True)

    missing = [item for item in report["items"] if not os.path.exists(item.get("file", ""))]
    if missing:
        report["ok"] = False
        report["error"] = "%d file(s) missing after export" % len(missing)
    report["total_tris"] = sum(int(item.get("tris", 0)) for item in report["items"])
    return report


if "bpy" in globals():  # executed inside Blender
    print("export_town_glb: call export_harbor_town() to export %s" % COLLECTION_NAME)
