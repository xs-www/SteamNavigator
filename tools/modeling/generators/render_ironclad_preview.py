# -*- coding: utf-8 -*-
"""Steam Navigator — SN_Ironclad 预览渲染（Lead 验收截图，非游戏资产）。

临时相机 / 太阳光 / 深色世界，隐藏场景中其它对象，渲 4 个视角：
    3/4、正侧（broadside）、舰艏、舰艉 3/4。
输出到 .design/ships/preview/（.design 被 gitignore，属本地产物）。
渲染后还原相机 / 引擎 / 世界 / 灯光 / 可见性。

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")
"""

import math
import os

import bpy
from mathutils import Vector

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT_DIR = os.path.join(WORKDIR, ".design", "ships", "preview")

OBJECT = "SN_Ironclad"

VIEWS = [
    ("three_quarter", Vector((0.90, -1.00, 0.50)), (1300, 780)),
    ("broadside", Vector((0.00, -1.00, 0.16)), (1400, 700)),
    ("bow", Vector((1.00, -0.18, 0.18)), (1100, 800)),
    ("stern_quarter", Vector((-0.85, -0.75, 0.35)), (1100, 800)),
]


def _world_points(obj):
    return [obj.matrix_world @ Vector(c) for c in obj.bound_box]


def _bounds(objs):
    pts = []
    for ob in objs:
        pts.extend(_world_points(ob))
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx


def _place_camera(cam, objs, direction, res_x, res_y, margin=1.04):
    bpy.context.view_layer.update()
    mn, mx = _bounds(objs)
    center = (mn + mx) / 2.0
    cam.data.lens = 50.0
    cam.data.sensor_fit = "HORIZONTAL"
    cam.data.sensor_width = 36.0
    tan_x = math.tan(math.atan(18.0 / cam.data.lens))
    tan_y = math.tan(math.atan((18.0 / (res_x / res_y)) / cam.data.lens))
    dirv = direction.normalized()
    forward = -dirv
    right = forward.cross(Vector((0.0, 0.0, 1.0))).normalized()
    up = right.cross(forward).normalized()
    distance = 0.0
    for ob in objs:
        for p in _world_points(ob):
            q = p - center
            a = q.dot(dirv)
            need = a + max(abs(q.dot(right)) / tan_x, abs(q.dot(up)) / tan_y)
            distance = max(distance, need)
    distance = max(distance * margin, 1.0)
    cam.location = center + dirv * distance
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()


def render_all():
    scene = bpy.context.scene
    os.makedirs(OUT_DIR, exist_ok=True)
    obj = bpy.data.objects[OBJECT]

    saved = {
        "engine": scene.render.engine,
        "camera": scene.camera,
        "res_x": scene.render.resolution_x,
        "res_y": scene.render.resolution_y,
        "res_pct": scene.render.resolution_percentage,
        "filepath": scene.render.filepath,
        "samples": getattr(scene.eevee, "taa_render_samples", None) if hasattr(scene, "eevee") else None,
        "bg": None,
    }

    cam_data = bpy.data.cameras.new("TMP_IC_CAM")
    cam = bpy.data.objects.new("TMP_IC_CAM", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam

    suns = []
    for name, energy, rot in (
        ("TMP_IC_SUN_KEY", 4.2, (math.radians(48), 0.0, math.radians(35))),
        ("TMP_IC_SUN_FILL", 1.6, (math.radians(62), 0.0, math.radians(215))),
    ):
        data = bpy.data.lights.new(name, "SUN")
        data.energy = energy
        data.angle = 0.35
        ob = bpy.data.objects.new(name, data)
        ob.rotation_euler = rot
        scene.collection.objects.link(ob)
        suns.append(ob)

    world = scene.world
    if world and world.use_nodes:
        bg = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"), None)
        if bg is not None:
            saved["bg"] = tuple(bg.inputs["Color"].default_value)
            bg.inputs["Color"].default_value = (0.055, 0.062, 0.075, 1.0)

    states = {}
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            states[ob.name] = ob.hide_render
            ob.hide_render = ob is not obj

    scene.render.engine = "BLENDER_EEVEE_NEXT"
    if hasattr(scene, "eevee"):
        scene.eevee.taa_render_samples = 28
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.film_transparent = False

    results = []
    try:
        for label, direction, res in VIEWS:
            scene.render.resolution_x, scene.render.resolution_y = res
            scene.render.resolution_percentage = 100
            _place_camera(cam, [obj], direction, res[0], res[1])
            path = os.path.join(OUT_DIR, "ironclad_%s.png" % label)
            scene.render.filepath = path
            bpy.ops.render.render(write_still=True)
            results.append(path)
    finally:
        for ob in suns:
            data = ob.data
            bpy.data.objects.remove(ob, do_unlink=True)
            bpy.data.lights.remove(data)
        bpy.data.objects.remove(cam, do_unlink=True)
        bpy.data.cameras.remove(cam_data)
        for name, value in states.items():
            ob = bpy.data.objects.get(name)
            if ob is not None:
                ob.hide_render = value
        scene.camera = saved["camera"]
        scene.render.engine = saved["engine"]
        scene.render.resolution_x = saved["res_x"]
        scene.render.resolution_y = saved["res_y"]
        scene.render.resolution_percentage = saved["res_pct"]
        scene.render.filepath = saved["filepath"]
        if saved["samples"] is not None and hasattr(scene, "eevee"):
            scene.eevee.taa_render_samples = saved["samples"]
        if saved["bg"] is not None:
            bg = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"), None)
            if bg is not None:
                bg.inputs["Color"].default_value = saved["bg"]

    print("IRONCLAD_PREVIEW_DONE %r" % {"count": len(results), "dir": OUT_DIR})
    return results


if __name__ == "__main__":
    render_all()
