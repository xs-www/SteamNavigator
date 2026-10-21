# -*- coding: utf-8 -*-
# @static-doc
# 作用：四台起重机的 GLB 归档导出脚本（人工/自动验收通过后由 Lead 执行）。
#
# 约定（见 docs/design/MODELING_WORKFLOW.md 第 8 节）：
# - 逐件导出：导出前把根空物体 `location` 临时归零，导出后还原；根空物体归零后
#   几何即根局部坐标，轴心落在底面中心 / 轨道面中心；
# - 只导出该集合内的对象（根 / Pivot / 网格），不导相机 / 灯光 / 其它资产；
# - glTF 默认 +Y 向上，进入 Godot 后尺寸为 (Blender X, Blender Z, Blender Y)；
# - 覆盖前把旧 GLB 备份到 `.design/props/backup_glb/`；
# - 塔吊沿用 Core 既有资产键 `model.prop.harbor_crane`，导出后同步
#   `dev_mods/core/assets/models/props/` 副本；新增三件暂不接 Core manifest。
# - 全部导出后保存工作台 `.design/SN_Asset_Workbench.blend`。
#
# 用法（已连 Blender 的会话）：
#     import runpy; runpy.run_path(<本文件>, run_name="__main__")
# 或后台：
#     blender -b .design/SN_Asset_Workbench.blend -P tools/modeling/generators/export_cranes_glb.py
# @end-static-doc

import os
import shutil
import time

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
OUT_DIR = os.path.join(WORKDIR, "assets", "models", "props")
CORE_DIR = os.path.join(WORKDIR, "dev_mods", "core", "assets", "models", "props")
BACKUP_DIR = os.path.join(WORKDIR, ".design", "props", "backup_glb")

# 资产名 -> (集合, 根空物体, 是否同步 Core 副本)
CRANES = [
    ("SN_Harbor_Crane", "SN_Harbor_Crane_Prototype", "SN_Crane_Root", True),
    ("SN_Mega_Gantry", "SN_Mega_Gantry_Prototype", "SN_MG_Root", False),
    ("SN_Wooden_Mast_Crane", "SN_Wooden_Mast_Crane_Prototype", "SN_WM_Root", False),
    ("SN_Hand_Jib_Crane", "SN_Hand_Jib_Crane_Prototype", "SN_HJ_Root", False),
]


def _backup(path):
    if not os.path.isfile(path):
        return None
    os.makedirs(BACKUP_DIR, exist_ok=True)
    base = os.path.splitext(os.path.basename(path))[0]
    stamp = time.strftime("%Y%m%d-%H%M%S")
    dst = os.path.join(BACKUP_DIR, "%s.%s.glb" % (base, stamp))
    shutil.copy2(path, dst)
    return dst


def export_one(asset, collection, root_name, sync_core):
    col = bpy.data.collections.get(collection)
    if col is None:
        raise RuntimeError("找不到集合 %s" % collection)
    root = bpy.data.objects.get(root_name)
    if root is None:
        raise RuntimeError("找不到根空物体 %s" % root_name)

    path = os.path.join(OUT_DIR, "%s.glb" % asset)
    os.makedirs(OUT_DIR, exist_ok=True)
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
            export_extras=False,
        )
    finally:
        root.location = saved_loc
        for ob in bpy.context.selected_objects:
            ob.select_set(False)
        for ob in saved_selection:
            ob.select_set(True)
        bpy.context.view_layer.update()

    core_copy = None
    if sync_core:
        os.makedirs(CORE_DIR, exist_ok=True)
        core_copy = os.path.join(CORE_DIR, "%s.glb" % asset)
        shutil.copy2(path, core_copy)

    info = {
        "asset": asset,
        "glb": path,
        "bytes": os.path.getsize(path),
        "backup": backup,
        "core_copy": core_copy,
    }
    print("EXPORTED %s -> %s (%d bytes) core=%s" % (
        asset, path, info["bytes"], bool(core_copy)))
    return info


def export_all():
    results = [export_one(*item) for item in CRANES]
    bpy.ops.wm.save_mainfile()
    print("CRANES_EXPORT_DONE %r" % {
        "count": len(results),
        "workbench": bpy.data.filepath,
        "results": results,
    })
    return results


if __name__ == "__main__":
    export_all()
