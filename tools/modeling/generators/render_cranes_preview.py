# -*- coding: utf-8 -*-
# @static-doc
# 作用：四台起重机的预览渲染（Lead 验收截图，非游戏资产）。
#
# 逐件临时相机 / 双太阳光 / 深色世界，隐藏场景中其它网格，渲 3/4 与正侧两个
# 视角到 `.design/props/preview/`（`.design` 被 gitignore，属本地产物）。
# 渲染后还原相机 / 引擎 / 世界 / 灯光 / 可见性，不保存 .blend。
#
# 用法（已连 Blender 的会话）：
#     import runpy; runpy.run_path(<本文件>, run_name="__main__")
# @end-static-doc

import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
OUT_DIR = os.path.join(WORKDIR, ".design", "props", "preview")

ASSETS = [
    ("SN_Harbor_Crane", "SN_Harbor_Crane_Prototype",
     Vector((0.85, -1.00, 0.42)), Vector((0.00, -1.00, 0.12))),
    ("SN_Mega_Gantry", "SN_Mega_Gantry_Prototype",
     Vector((0.95, -1.00, 0.34)), Vector((0.00, -1.00, 0.10))),
    ("SN_Wooden_Mast_Crane", "SN_Wooden_Mast_Crane_Prototype",
     Vector((0.80, -1.00, 0.34)), Vector((0.00, -1.00, 0.12))),
    ("SN_Hand_Jib_Crane", "SN_Hand_Jib_Crane_Prototype",
     Vector((0.90, -1.00, 0.30)), Vector((0.00, -1.00, 0.10))),
]
RES = (1300, 820)


def _world_points(ob):
    return [ob.matrix_world @ Vector(c) for c in ob.bound_box]


def _bounds(objs):
    pts = []
    for ob in objs:
        pts.extend(_world_points(ob))
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts),
                 min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts),
                 max(p.z for p in pts)))
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
    cam.rotation_euler = (center - cam.location).to_track_quat(
        "-Z", "Y").to_euler()


def render_all():
    scene = bpy.context.scene
    os.makedirs(OUT_DIR, exist_ok=True)

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

    cam_data = bpy.data.cameras.new("TMP_CR_CAM")
    cam = bpy.data.objects.new("TMP_CR_CAM", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam

    suns = []
    for name, energy, rot in (
        ("TMP_CR_SUN_KEY", 4.4, (math.radians(50), 0.0, math.radians(35))),
        ("TMP_CR_SUN_FILL", 1.5, (math.radians(62), 0.0, math.radians(215))),
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
        bg = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"),
                  None)
        if bg is not None:
            saved["bg"] = tuple(bg.inputs["Color"].default_value)
            bg.inputs["Color"].default_value = (0.055, 0.062, 0.075, 1.0)

    mesh_states = {ob.name: ob.hide_render for ob in bpy.data.objects
                   if ob.type == "MESH"}

    scene.render.engine = "BLENDER_EEVEE_NEXT"
    if hasattr(scene, "eevee"):
        scene.eevee.taa_render_samples = 24
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.film_transparent = False
    scene.render.resolution_x, scene.render.resolution_y = RES
    scene.render.resolution_percentage = 100

    results = []
    try:
        for asset, collection, dir_34, dir_side in ASSETS:
            col = bpy.data.collections.get(collection)
            if col is None:
                raise RuntimeError("缺少集合 %s" % collection)
            meshes = [ob for ob in col.objects if ob.type == "MESH"]
            for ob in bpy.data.objects:
                if ob.type == "MESH":
                    ob.hide_render = ob not in meshes
            slug = asset.lower()
            for label, direction in (("three_quarter", dir_34),
                                     ("side", dir_side)):
                _place_camera(cam, meshes, direction, RES[0], RES[1])
                path = os.path.join(OUT_DIR, "%s_%s.png" % (slug, label))
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
        for name, value in mesh_states.items():
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
            bg = next((n for n in world.node_tree.nodes
                       if n.type == "BACKGROUND"), None)
            if bg is not None:
                bg.inputs["Color"].default_value = saved["bg"]

    print("CRANES_PREVIEW_DONE %r" % {"count": len(results), "dir": OUT_DIR})
    return results


if __name__ == "__main__":
    render_all()
