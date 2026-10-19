# -*- coding: utf-8 -*-
"""Steam Navigator — 船舶模块 GLB 导出（人工验收后由 Lead 执行）。

约定（见 docs/design/MODELING_WORKFLOW.md 第 8 节与 docs/design/ASSET_MAP.md）：
- 逐件导出：每件导出前把 object.location 临时归零，导出后还原；
- 只导出选中的那一个网格对象，不导相机/灯光/其它模块；
- glTF 默认 +Y 向上，进入 Godot 后尺寸为 (Blender X, Blender Z, Blender Y)；
- 每个 .glb 只含一个网格节点，轴心在底面中心；
- 覆盖已有 GLB 前，先备份到 .design/modules/backup_glb/<name>.<timestamp>.glb
  （.design 被 gitignore，属本地产物）。

用法：
    blender -b .design/SN_Asset_Workbench.blend -P tools/modeling/generators/export_modules_glb.py
或在已连 Blender 的会话里 exec 本文件后调用 export_many()。
"""

import datetime
import os

import bpy

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT_DIR = os.path.join(WORKDIR, "assets", "models", "modules")
BACKUP_DIR = os.path.join(WORKDIR, ".design", "modules", "backup_glb")

TARGETS = [
    "SN_Boiler_Efficient",
    "SN_Boiler_Standard",
    "SN_Boiler_Performance",
    "SN_Cargo_Small_Hold",
    "SN_Cargo_Medium_Hold",
    "SN_Cargo_Large_Hold",
    "SN_Nav_Spyglass",
    "SN_Nav_Chart_Room",
    "SN_Safety_Lifeboat",
    "SN_Safety_Valve",
    "SN_Cabin_Passenger",
]


def _backup(path):
    if not os.path.exists(path):
        return None
    os.makedirs(BACKUP_DIR, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    name = os.path.splitext(os.path.basename(path))[0]
    dst = os.path.join(BACKUP_DIR, "%s.%s.glb" % (name, stamp))
    os.replace(path, dst)
    return dst


def export_one(name, out_dir=OUT_DIR):
    ob = bpy.data.objects.get(name)
    if ob is None or ob.type != "MESH":
        raise RuntimeError("找不到网格对象 %s" % name)

    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "%s.glb" % name)
    backup = _backup(path)

    saved_loc = tuple(ob.location)
    saved_selection = list(bpy.context.selected_objects)
    try:
        # 轴心在底面中心 -> 导出时把摆放位置归零，几何即局部坐标
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
    print("EXPORTED %s -> %s (%d bytes, backup=%r)" % (name, path, size, backup))
    return path


def export_many(names=None):
    names = names or TARGETS
    out = [export_one(n) for n in names]
    print("EXPORT_SUMMARY " + repr({"count": len(out), "files": out}))
    return out


if __name__ == "__main__":
    export_many()
