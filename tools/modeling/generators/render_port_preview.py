# -*- coding: utf-8 -*-
"""Steam Navigator — 港口设施锚点第一批预览渲染（Lead 验收截图，非游戏资产）。

对 SN_Port_Facilities 的 6 件设施逐件出 3/4 视角截图，另出两张总览
（沿 +X 侧看的一排 / 从场内看设施组）。渲染时临时隐藏其它对象（不删除、不保存），
渲染结束还原相机 / 引擎 / 世界 / 可见性。

输出（.design 被 gitignore，属本地产物）：
    .design/port/preview/SN_<Name>_3q.png          每件 3/4 视角
    .design/port/preview/overview_row.png          6 件沿 y=60 一排总览
    .design/port/preview/overview_group.png        船厂组（干船坞 + 龙门吊）俯视 3/4

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")
"""

import math
import os

import bpy
from mathutils import Vector

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT_DIR = os.path.join(WORKDIR, ".design", "port", "preview")

COLLECTION = "SN_Port_Facilities"

ITEMS = [
    "SN_Market_Stall",
    "SN_Notice_Board",
    "SN_Water_Tank",
    "SN_Signal_Tower",
    "SN_Shipyard_Gantry",
    "SN_Dry_Dock",
]

THREE_QUARTER = Vector((0.85, -1.0, 0.55))
FRONT = Vector((1.0, 0.0, 0.22))
ROW_DIR = Vector((0.20, -1.0, 0.52))
GROUP_DIR = Vector((0.55, -1.0, 0.58))

# 逐件取景方向：干船坞低矮宽扁，必须抬高机位才能看清坞内台阶 / 滑道轨 / 龙骨墩
ITEM_DIRS = {
    "SN_Dry_Dock": Vector((0.42, -1.0, 0.95)),
    "SN_Market_Stall": Vector((0.70, -1.0, 0.42)),
}


def _world_points(obj):
    return [obj.matrix_world @ Vector(c) for c in obj.bound_box]


def _bounds(objs):
    pts = []
    for ob in objs:
        pts.extend(_world_points(ob))
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx


def _place_camera(cam, objs, direction, res_x, res_y, margin=1.06):
    bpy.context.view_layer.update()
    mn, mx = _bounds(objs)
    center = (mn + mx) / 2.0
    cam.data.lens = 50.0
    cam.data.sensor_fit = "HORIZONTAL"
    cam.data.sensor_width = 36.0
    fov_x = 2.0 * math.atan(18.0 / cam.data.lens)
    fov_y = 2.0 * math.atan((18.0 / (res_x / res_y)) / cam.data.lens)
    tan_x = math.tan(fov_x / 2.0)
    tan_y = math.tan(fov_y / 2.0)

    dirv = direction.normalized()
    forward = -dirv
    right = forward.cross(Vector((0.0, 0.0, 1.0))).normalized()
    up = right.cross(forward).normalized()

    distance = 0.0
    for ob in objs:
        for p in _world_points(ob):
            q = p - center
            a = q.dot(dirv)
            x = abs(q.dot(right))
            y = abs(q.dot(up))
            distance = max(distance, a + max(x / tan_x, y / tan_y))
    distance = max(distance * margin, 0.5)

    eye = center + dirv * distance
    cam.location = eye
    cam.rotation_euler = (center - eye).to_track_quat("-Z", "Y").to_euler()
    return center, distance


def _set_visibility(names):
    states = {}
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            states[ob.name] = ob.hide_render
            ob.hide_render = ob.name not in names
    return states


def _restore_visibility(states):
    for name, value in states.items():
        ob = bpy.data.objects.get(name)
        if ob is not None:
            ob.hide_render = value


def _render(path, res):
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.resolution_percentage = 100
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def render_all():
    scene = bpy.context.scene
    os.makedirs(OUT_DIR, exist_ok=True)

    if bpy.data.collections.get(COLLECTION) is None:
        raise RuntimeError("集合 %s 不存在" % COLLECTION)
    items = {name: bpy.data.objects[name] for name in ITEMS}

    saved = {
        "engine": scene.render.engine,
        "camera": scene.camera,
        "res_x": scene.render.resolution_x,
        "res_y": scene.render.resolution_y,
        "res_pct": scene.render.resolution_percentage,
        "filepath": scene.render.filepath,
        "world": scene.world,
        "samples": getattr(scene.eevee, "taa_render_samples", None) if hasattr(scene, "eevee") else None,
        "bg": None,
    }

    cam_data = bpy.data.cameras.new("TMP_PORT_PREVIEW_CAM")
    cam = bpy.data.objects.new("TMP_PORT_PREVIEW_CAM", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam

    suns = []
    for name, energy, rot in (
        ("TMP_PORT_SUN_KEY", 4.0, (math.radians(48), 0.0, math.radians(35))),
        ("TMP_PORT_SUN_FILL", 1.5, (math.radians(60), 0.0, math.radians(210))),
    ):
        data = bpy.data.lights.new(name, "SUN")
        data.energy = energy
        data.angle = 0.35
        ob = bpy.data.objects.new(name, data)
        ob.rotation_euler = rot
        scene.collection.objects.link(ob)
        suns.append(ob)

    world = scene.world
    if world is None:
        world = bpy.data.worlds.new("TMP_PORT_PREVIEW_WORLD")
        scene.world = world
    if not world.use_nodes:
        world.use_nodes = True
    bg = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"), None)
    if bg is not None:
        saved["bg"] = tuple(bg.inputs["Color"].default_value)
        bg.inputs["Color"].default_value = (0.055, 0.060, 0.070, 1.0)

    scene.render.engine = "BLENDER_EEVEE_NEXT"
    if hasattr(scene, "eevee"):
        scene.eevee.taa_render_samples = 24
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"

    results = []
    for name in ITEMS:
        states = _set_visibility({name})
        try:
            direction = ITEM_DIRS.get(name, THREE_QUARTER)
            _place_camera(cam, [items[name]], direction, 760, 760, margin=1.08)
            results.append(_render(os.path.join(OUT_DIR, "%s_3q.png" % name), (760, 760)))
            _place_camera(cam, [items[name]], FRONT, 760, 760, margin=1.08)
            results.append(_render(os.path.join(OUT_DIR, "%s_front.png" % name), (760, 760)))
        finally:
            _restore_visibility(states)

    all_objs = [items[n] for n in ITEMS]
    states = _set_visibility(set(ITEMS))
    try:
        _place_camera(cam, all_objs, ROW_DIR, 1600, 700, margin=1.03)
        results.append(_render(os.path.join(OUT_DIR, "overview_row.png"), (1600, 700)))
        shipyard = [items["SN_Dry_Dock"], items["SN_Shipyard_Gantry"]]
        _place_camera(cam, shipyard, GROUP_DIR, 1300, 780, margin=1.03)
        results.append(_render(os.path.join(OUT_DIR, "overview_group.png"), (1300, 780)))
    finally:
        _restore_visibility(states)

    for ob in suns:
        data = ob.data
        bpy.data.objects.remove(ob, do_unlink=True)
        bpy.data.lights.remove(data)
    bpy.data.objects.remove(cam, do_unlink=True)
    bpy.data.cameras.remove(cam_data)
    scene.camera = saved["camera"]
    scene.render.engine = saved["engine"]
    scene.render.resolution_x = saved["res_x"]
    scene.render.resolution_y = saved["res_y"]
    scene.render.resolution_percentage = saved["res_pct"]
    scene.render.filepath = saved["filepath"]
    if saved["samples"] is not None and hasattr(scene, "eevee"):
        scene.eevee.taa_render_samples = saved["samples"]
    if saved["bg"] is not None and bg is not None:
        bg.inputs["Color"].default_value = saved["bg"]

    print("PORT_PREVIEW_DONE %r" % {"count": len(results), "dir": OUT_DIR})
    return results


if __name__ == "__main__":
    render_all()
