# -*- coding: utf-8 -*-
"""Steam Navigator — SN_Paddle_Steamer 预览渲染（Lead 验收截图，非游戏资产）。

临时相机 / 太阳光 / 深色世界 / 临时水面，隐藏场景中其它对象，渲 5 个视角：
    3/4 艏、正侧、艏、艉 3/4、俯视。
输出到 docs/design/screenshots/（入库截图）；同时把 3/4 主图另存一份预览。
渲染后还原相机 / 引擎 / 世界 / 灯光 / 可见性，并删除临时水面。

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")
"""

import math
import os

import bpy
from mathutils import Vector

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
OUT_DIR = os.path.join(WORKDIR, "docs", "design", "screenshots")

COLLECTION = "SN_Paddle_Steamer_Prototype"

VIEWS = [
    ("three_quarter", Vector((0.90, -1.00, 0.34)), (1400, 820)),
    ("broadside", Vector((0.00, -1.00, 0.14)), (1500, 720)),
    ("bow", Vector((1.00, -0.20, 0.18)), (1100, 820)),
    ("stern_quarter", Vector((-0.90, -0.80, 0.32)), (1200, 820)),
    ("top", Vector((-0.20, -0.25, 1.00)), (1000, 900)),
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


def _place_camera(cam, objs, direction, res_x, res_y, margin=1.06):
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
    col = bpy.data.collections[COLLECTION]
    objs = [o for o in col.objects if o.type == "MESH"]
    root = bpy.data.objects["SN_PS_Root"]
    root_loc = tuple(root.location)

    saved = {
        "engine": scene.render.engine,
        "camera": scene.camera,
        "res_x": scene.render.resolution_x,
        "res_y": scene.render.resolution_y,
        "res_pct": scene.render.resolution_percentage,
        "filepath": scene.render.filepath,
        "samples": getattr(scene.eevee, "taa_render_samples", None)
                   if hasattr(scene, "eevee") else None,
        "bg": None,
    }

    cam_data = bpy.data.cameras.new("TMP_PS_CAM")
    cam = bpy.data.objects.new("TMP_PS_CAM", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam

    suns = []
    for name, energy, rot in (
        ("TMP_PS_SUN_KEY", 3.3, (math.radians(50), 0.0, math.radians(28))),
        ("TMP_PS_SUN_FILL", 1.3, (math.radians(64), 0.0, math.radians(210))),
    ):
        data = bpy.data.lights.new(name, "SUN")
        data.energy = energy
        data.angle = 0.32
        ob = bpy.data.objects.new(name, data)
        ob.rotation_euler = rot
        scene.collection.objects.link(ob)
        suns.append(ob)

    # 临时水面：z=0 大平面，让水线关系可读
    water_mat = bpy.data.materials.new("TMP_PS_WATER")
    water_mat.use_nodes = True
    nt = water_mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    bsdf.inputs["Base Color"].default_value = (0.018, 0.040, 0.055, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Metallic"].default_value = 0.0
    spec = bsdf.inputs.get("Specular IOR Level")
    if spec is not None:
        spec.default_value = 0.0
    water_me = bpy.data.meshes.new("TMP_PS_WATER")
    water_me.from_pydata(
        [(-120.0, -120.0, 0.0), (120.0, -120.0, 0.0),
         (120.0, 120.0, 0.0), (-120.0, 120.0, 0.0)],
        [], [(0, 1, 2, 3)])
    water_me.materials.append(water_mat)
    water = bpy.data.objects.new("TMP_PS_WATER", water_me)
    scene.collection.objects.link(water)
    water.location = (root_loc[0], root_loc[1], 0.0)

    world = scene.world
    if world and world.use_nodes:
        bg = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"), None)
        if bg is not None:
            saved["bg"] = tuple(bg.inputs["Color"].default_value)
            bg.inputs["Color"].default_value = (0.150, 0.195, 0.235, 1.0)

    states = {}
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            states[ob.name] = ob.hide_render
            ob.hide_render = ob not in objs
    water.hide_render = False

    scene.render.engine = "BLENDER_EEVEE_NEXT"
    if hasattr(scene, "eevee"):
        scene.eevee.taa_render_samples = 32
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.film_transparent = False

    results = []
    try:
        for label, direction, res in VIEWS:
            scene.render.resolution_x, scene.render.resolution_y = res
            scene.render.resolution_percentage = 100
            _place_camera(cam, objs, direction, res[0], res[1])
            path = os.path.join(OUT_DIR, "paddle_steamer_%s.png" % label)
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
        bpy.data.objects.remove(water, do_unlink=True)
        bpy.data.meshes.remove(water_me)
        bpy.data.materials.remove(water_mat)
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

    print("PADDLE_STEAMER_PREVIEW_DONE %r" % {"count": len(results), "dir": OUT_DIR})
    return results


if __name__ == "__main__":
    render_all()
