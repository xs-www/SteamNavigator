# -*- coding: utf-8 -*-
"""Steam Navigator — 船舶模块预览渲染（Lead 验收截图，非游戏资产）。

对 SN_Ship_Modules 集合里的 11 件模块逐件出 3/4 视角截图，另出三张分组图与
一张总览图。渲染时临时隐藏场景中其它对象（不删除、不保存），渲染结束还原
相机 / 引擎 / 世界 / 可见性。

输出（.design 被 gitignore，属本地产物）：
    .design/modules/preview/SN_<Name>_3q.png        每件 3/4 视角
    .design/modules/preview/group_boilers.png       锅炉三件
    .design/modules/preview/group_cargo.png         货舱三件
    .design/modules/preview/group_nav_safety_cabin.png
    .design/modules/preview/overview.png            11 件总览

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")
"""

import math
import os

import bpy
from mathutils import Vector

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT_DIR = os.path.join(WORKDIR, ".design", "modules", "preview")

COLLECTION = "SN_Ship_Modules"

ITEMS = [
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

GROUPS = [
    ("group_boilers", ["SN_Boiler_Efficient", "SN_Boiler_Standard", "SN_Boiler_Performance"], (1000, 700)),
    ("group_cargo", ["SN_Cargo_Small_Hold", "SN_Cargo_Medium_Hold", "SN_Cargo_Large_Hold"], (1000, 700)),
    ("group_nav_safety_cabin", ["SN_Nav_Spyglass", "SN_Nav_Chart_Room",
                                "SN_Safety_Lifeboat", "SN_Safety_Valve",
                                "SN_Cabin_Passenger"], (1100, 700)),
    ("overview", ITEMS, (1400, 850)),
]

THREE_QUARTER = Vector((0.85, -1.0, 0.55))
FRONT = Vector((1.0, 0.0, 0.22))
OVERVIEW_DIR = Vector((0.55, -1.0, 0.40))


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
    """按投影包围盒精确取景：保证所有角点都落在画面内，且尽量占满。"""
    bpy.context.view_layer.update()  # 重建后 matrix_world 可能滞后，取景前强制刷新
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
            need = a + max(x / tan_x, y / tan_y)
            distance = max(distance, need)
    distance *= margin
    distance = max(distance, 0.5)

    eye = center + dirv * distance
    cam.location = eye
    cam.rotation_euler = (center - eye).to_track_quat("-Z", "Y").to_euler()
    return center, distance


def _set_visibility(visible):
    states = {}
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            states[ob.name] = ob.hide_render
            ob.hide_render = ob not in visible
    return states


def _restore_visibility(states):
    for name, value in states.items():
        ob = bpy.data.objects.get(name)
        if ob is not None:
            ob.hide_render = value


def render_all():
    scene = bpy.context.scene
    os.makedirs(OUT_DIR, exist_ok=True)

    coll = bpy.data.collections.get(COLLECTION)
    if coll is None:
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
        "lights": None,
        "samples": getattr(scene.eevee, "taa_render_samples", None) if hasattr(scene, "eevee") else None,
        "bg": None,
    }

    # 临时相机 / 太阳光 / 深色世界
    cam_data = bpy.data.cameras.new("TMP_PREVIEW_CAM")
    cam = bpy.data.objects.new("TMP_PREVIEW_CAM", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam

    suns = []
    for name, energy, rot in (
        ("TMP_PREVIEW_SUN_KEY", 4.0, (math.radians(48), 0.0, math.radians(35))),
        ("TMP_PREVIEW_SUN_FILL", 1.4, (math.radians(60), 0.0, math.radians(210))),
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
        world = bpy.data.worlds.new("TMP_PREVIEW_WORLD")
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
    # 每件 3/4 视角 + 正前方（+X 面）
    for name in ITEMS:
        objs = [items[name]]
        states = _set_visibility(objs)
        try:
            res = (700, 700)
            scene.render.resolution_x, scene.render.resolution_y = res
            scene.render.resolution_percentage = 100
            for label, direction in (("3q", THREE_QUARTER), ("front", FRONT)):
                _place_camera(cam, objs, direction, res[0], res[1], margin=1.08)
                path = os.path.join(OUT_DIR, "%s_%s.png" % (name, label))
                scene.render.filepath = path
                bpy.ops.render.render(write_still=True)
                results.append(path)
        finally:
            _restore_visibility(states)

    # 分组图 + 总览
    for label, names, res in GROUPS:
        objs = [items[n] for n in names]
        states = _set_visibility(objs)
        try:
            scene.render.resolution_x, scene.render.resolution_y = res
            scene.render.resolution_percentage = 100
            direction = OVERVIEW_DIR if label == "overview" else THREE_QUARTER
            _place_camera(cam, objs, direction, res[0], res[1], margin=1.05)
            path = os.path.join(OUT_DIR, "%s.png" % label)
            scene.render.filepath = path
            bpy.ops.render.render(write_still=True)
            results.append(path)
        finally:
            _restore_visibility(states)

    # 清理与还原
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

    print("PREVIEW_RENDER_DONE %r" % {"count": len(results), "dir": OUT_DIR})
    return results


if __name__ == "__main__":
    render_all()
