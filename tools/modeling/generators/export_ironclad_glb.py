# -*- coding: utf-8 -*-
"""Steam Navigator — SN_Ironclad GLB 导出 + 集合快照（人工验收后由 Lead 执行）。

约定（同 docs/design/MODELING_WORKFLOW.md 第 8 节）：
- 导出前把 object.location 临时归零，导出后还原；轴心即水线中心；
- 只导出 SN_Ironclad 一个网格对象；
- 覆盖旧 GLB 前先备份到 .design/ships/backup_glb/；
- 另存集合快照 .design/ships/SN_Ironclad.blend（bpy.data.libraries.write，不切文件）。

用法：在已连 Blender 的会话里
    import runpy; runpy.run_path(<本文件>, run_name="__main__")
"""

import datetime
import os

import bpy

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT_DIR = os.path.join(WORKDIR, "assets", "models", "ships")
BACKUP_DIR = os.path.join(WORKDIR, ".design", "ships", "backup_glb")
SNAPSHOT = os.path.join(WORKDIR, ".design", "ships", "SN_Ironclad.blend")
OBJECT = "SN_Ironclad"


def _backup(path):
    if not os.path.exists(path):
        return None
    os.makedirs(BACKUP_DIR, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    dst = os.path.join(BACKUP_DIR, "SN_Ironclad.%s.glb" % stamp)
    os.replace(path, dst)
    return dst


def export_glb():
    ob = bpy.data.objects.get(OBJECT)
    if ob is None or ob.type != "MESH":
        raise RuntimeError("找不到网格对象 %s" % OBJECT)
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, "%s.glb" % OBJECT)
    backup = _backup(path)

    saved_loc = tuple(ob.location)
    saved_selection = list(bpy.context.selected_objects)
    try:
        ob.location = (0.0, 0.0, 0.0)
        bpy.context.view_layer.update()
        for other in bpy.context.selected_objects:
            other.select_set(False)
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
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
        ob.location = saved_loc
        for other in bpy.context.selected_objects:
            other.select_set(False)
        for other in saved_selection:
            other.select_set(True)
        bpy.context.view_layer.update()

    size = os.path.getsize(path)
    print("EXPORTED %s -> %s (%d bytes, backup=%r)" % (OBJECT, path, size, backup))
    return path


def save_snapshot():
    ob = bpy.data.objects[OBJECT]
    bpy.data.libraries.write(SNAPSHOT, {ob}, path_remap="NONE")
    print("SNAPSHOT %s (%d bytes)" % (SNAPSHOT, os.path.getsize(SNAPSHOT)))
    return SNAPSHOT


if __name__ == "__main__":
    export_glb()
    save_snapshot()
