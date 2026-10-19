# -*- coding: utf-8 -*-
"""Steam Navigator — 港口设施锚点第一批归档脚本（Lead 人工验收后执行）。

工单：tools/modeling/briefs/sn_port_facilities_batch1.json
规划：tools/modeling/briefs/PORT_FACILITIES_PLAN.md §6

做什么
------
1. 备份旧 GLB 到 .design/port/backup_glb/（.design 被 gitignore，属本地产物）；
2. 保存工作台 .design/SN_Asset_Workbench.blend（6 件保留布局位置）；
3. 逐件导出 assets/models/port/SN_<Name>.glb：
   导出前把 object.location 临时归零（轴心 = 底面中心）、只选该对象，导出后还原；
4. 逐件写 .design/port/SN_<Name>.blend 快照（不切换当前文件）；
5. 把实测数据写到 .design/port/report.json，供 ASSET_MAP / 静态文档引用。

用法（已连 Blender 的会话，Lead 执行）：
    import io
    p = r"D:\\桌面\\sisi_apps\\SteamNavigator\\tools\\modeling\\generators\\export_port_glb.py"
    exec(compile(io.open(p, encoding="utf-8").read(), p, "exec"), {"__name__": "__main__"})
"""

import json
import os
import shutil

import bpy

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT_DIR = os.path.join(WORKDIR, "assets", "models", "port")
BACKUP_DIR = os.path.join(WORKDIR, ".design", "port", "backup_glb")
SNAP_DIR = os.path.join(WORKDIR, ".design", "port")
WORKBENCH = os.path.join(WORKDIR, ".design", "SN_Asset_Workbench.blend")

COLLECTION = "SN_Port_Facilities"

TARGETS = [
    "SN_Market_Stall",
    "SN_Notice_Board",
    "SN_Water_Tank",
    "SN_Signal_Tower",
    "SN_Shipyard_Gantry",
    "SN_Dry_Dock",
]

MATERIALS = [
    "SN_Wood", "SN_Wood_Dark", "SN_Wood_Deck", "SN_Metal", "SN_Iron",
    "SN_Brass", "SN_Stone", "SN_Canvas", "SN_Canvas_Shade",
]


def _backup(path):
    if not os.path.exists(path):
        return None
    os.makedirs(BACKUP_DIR, exist_ok=True)
    base = os.path.splitext(os.path.basename(path))[0]
    n = 1
    while True:
        dst = os.path.join(BACKUP_DIR, "%s.%02d.glb" % (base, n))
        if not os.path.exists(dst):
            break
        n += 1
    shutil.copy2(path, dst)
    return dst


def _deselect_all():
    for ob in bpy.context.selected_objects:
        ob.select_set(False)


def measure(name):
    ob = bpy.data.objects[name]
    mesh = ob.data
    mesh.calc_loop_triangles()
    xs = [v.co.x for v in mesh.vertices]
    ys = [v.co.y for v in mesh.vertices]
    zs = [v.co.z for v in mesh.vertices]
    return {
        "name": name,
        "location": [round(v, 4) for v in ob.location],
        "tris": len(mesh.loop_triangles),
        "verts": len(mesh.vertices),
        "size_local_xyz": [round(max(xs) - min(xs), 4),
                           round(max(ys) - min(ys), 4),
                           round(max(zs) - min(zs), 4)],
        "zmin": round(min(zs), 4),
        "materials": [m.name for m in mesh.materials],
        "mesh_datablock": mesh.name,
    }


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
        _deselect_all()
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
        _deselect_all()
        for other in saved_selection:
            other.select_set(True)
        bpy.context.view_layer.update()

    print("EXPORTED %s -> %s (%d bytes, backup=%r)"
          % (name, path, os.path.getsize(path), backup))
    return path


def snapshot_one(name, snap_dir=SNAP_DIR):
    """单件 .blend 快照：只写该对象 + 网格 + 本批调色板材质，不切换当前文件。"""
    ob = bpy.data.objects.get(name)
    if ob is None:
        raise RuntimeError("找不到对象 %s" % name)
    os.makedirs(snap_dir, exist_ok=True)
    path = os.path.join(snap_dir, "%s.blend" % name)

    saved_loc = tuple(ob.location)
    try:
        ob.location = (0.0, 0.0, 0.0)
        bpy.context.view_layer.update()
        data = {ob}
        if ob.data is not None:
            data.add(ob.data)
        for mat in bpy.data.materials:
            if mat.name in MATERIALS and mat.users > 0:
                data.add(mat)
        bpy.data.libraries.write(path, data, fake_user=True, compress=True)
    finally:
        ob.location = saved_loc
        bpy.context.view_layer.update()
    print("SNAPSHOT %s -> %s (%d bytes)" % (name, path, os.path.getsize(path)))
    return path


def export_many(names=None, do_snapshot=True):
    names = names or TARGETS
    os.makedirs(SNAP_DIR, exist_ok=True)
    os.makedirs(BACKUP_DIR, exist_ok=True)

    # 1) 保存工作台（6 件保留布局位置，便于后续烘焙 / 场景装配）
    bpy.ops.wm.save_as_mainfile(filepath=WORKBENCH)
    print("WORKBENCH_SAVED %s" % WORKBENCH)

    # 2) 导出 GLB + 逐件快照
    report = {"items": [], "glb": [], "blend": []}
    for name in names:
        report["items"].append(measure(name))
        report["glb"].append(export_one(name))
        if do_snapshot:
            report["blend"].append(snapshot_one(name))

    with open(os.path.join(SNAP_DIR, "report.json"), "w", encoding="utf-8") as fh:
        json.dump(report, fh, ensure_ascii=False, indent=2)
    print("EXPORT_SUMMARY " + repr({
        "count": len(names),
        "total_tris": sum(i["tris"] for i in report["items"]),
        "out_dir": OUT_DIR,
    }))
    return report


if __name__ == "__main__":
    export_many()
