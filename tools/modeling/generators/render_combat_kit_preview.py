# -*- coding: utf-8 -*-
# @static-doc
# 作用：`combat_kit` 敌舰套件（M2-1）预览渲染（人工 / 独立 Verifier 验收前由 Builder
# 在 Blender 内执行，不进游戏）—— 逐艘隔离目标集合，临时创建相机 / 双太阳灯 / 水面，
# 渲染 3/4 与侧视；再输出一张四艘 lineup。渲染结束删除临时对象并恢复 hide_render /
# 相机 / 渲染器 / 世界背景，不保存 .blend、不导出 GLB。
#
# 输出：`.design/combat/preview/<asset>_<view>.png` + `combat_lineup.png`；
# 便于文档使用的副本写到 `docs/design/screenshots/combat/`。
#
# 用法（已连 Blender、4 艘敌舰已构建的会话）：
#     import runpy; runpy.run_path(<本文件>, run_name="__main__")
# @end-static-doc

import math
import os

import bpy
from mathutils import Vector

import combat_kit_generator as ck

HERE = os.path.dirname(os.path.abspath(__file__))
WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
OUT_DIR = os.path.join(WORKDIR, ".design", "combat", "preview")
DOCS_DIR = os.path.join(WORKDIR, "docs", "design", "screenshots", "combat")
TEMP_PREFIX = "TMP_COMBAT_"

VIEWS = [
    ("three_quarter", Vector((1.0, -1.0, 0.58)), (1280, 800)),
    ("side", Vector((0.05, -1.0, 0.30)), (1280, 800)),
]
LINEUP_VIEW = Vector((0.35, -1.0, 0.55))
LINEUP_RES = (1920, 720)


def _world_points(obj):
    return [obj.matrix_world @ Vector(c) for c in obj.bound_box]


def _bounds(objs):
    pts = []
    for ob in objs:
        pts.extend(_world_points(ob))
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts),
                 min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts),
                 max(p.z for p in pts)))
    return mn, mx


def _place_camera(cam, objs, direction, res_x, res_y, margin=1.08):
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


def _mesh_objects(asset):
    collection = bpy.data.collections[ck.SHIP_CONFIGS[asset]["collection"]]
    return [o for o in collection.all_objects if o.type == "MESH"]


def _make_water():
    mat = bpy.data.materials.new(TEMP_PREFIX + "WATER")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0.018, 0.040, 0.055, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Metallic"].default_value = 0.0
    spec = bsdf.inputs.get("Specular IOR Level")
    if spec is not None:
        spec.default_value = 0.0
    me = bpy.data.meshes.new(TEMP_PREFIX + "WATER")
    me.from_pydata([(-200.0, -200.0, 0.0), (200.0, -200.0, 0.0),
                    (200.0, 200.0, 0.0), (-200.0, 200.0, 0.0)],
                   [], [(0, 1, 2, 3)])
    me.materials.append(mat)
    ob = bpy.data.objects.new(TEMP_PREFIX + "WATER", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob, me, mat


def render_all():
    scene = bpy.context.scene
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(DOCS_DIR, exist_ok=True)
    saved = {
        "engine": scene.render.engine,
        "camera": scene.camera,
        "res_x": scene.render.resolution_x,
        "res_y": scene.render.resolution_y,
        "res_pct": scene.render.resolution_percentage,
        "filepath": scene.render.filepath,
        "bg": None,
    }
    cam_data = bpy.data.cameras.new(TEMP_PREFIX + "CAM")
    cam = bpy.data.objects.new(TEMP_PREFIX + "CAM", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    suns = []
    for name, energy, rot in (
        (TEMP_PREFIX + "SUN_KEY", 3.4, (math.radians(52), 0.0,
                                        math.radians(28))),
        (TEMP_PREFIX + "SUN_FILL", 1.4, (math.radians(66), 0.0,
                                         math.radians(212))),
    ):
        data = bpy.data.lights.new(name, "SUN")
        data.energy = energy
        data.angle = 0.32
        ob = bpy.data.objects.new(name, data)
        ob.rotation_euler = rot
        scene.collection.objects.link(ob)
        suns.append(ob)
    water, water_me, water_mat = _make_water()

    world = scene.world
    if world and world.use_nodes:
        bg = next((n for n in world.node_tree.nodes
                   if n.type == "BACKGROUND"), None)
        if bg is not None:
            saved["bg"] = tuple(bg.inputs["Color"].default_value)
            bg.inputs["Color"].default_value = (0.150, 0.195, 0.235, 1.0)

    states = {}
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            states[ob.name] = ob.hide_render
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    if hasattr(scene, "eevee"):
        scene.eevee.taa_render_samples = 32
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.film_transparent = False
    results = []
    try:
        for asset in ck.SHIP_CLASS_ORDER:
            objs = _mesh_objects(asset)
            root = bpy.data.objects[ck.SHIP_CONFIGS[asset]["root"]]
            origin = tuple(root.matrix_world.translation)
            water.location = (origin[0], origin[1], 0.0)
            visible = set(objs)
            for ob in bpy.data.objects:
                if ob.type == "MESH":
                    ob.hide_render = ob not in visible
            water.hide_render = False
            for label, direction, res in VIEWS:
                scene.render.resolution_x, scene.render.resolution_y = res
                scene.render.resolution_percentage = 100
                _place_camera(cam, objs, direction, res[0], res[1])
                path = os.path.join(OUT_DIR, "%s_%s.png" % (asset, label))
                scene.render.filepath = path
                bpy.ops.render.render(write_still=True)
                results.append(path)
        # 四艘 lineup：全部可见，水面覆盖整排
        all_objs = [o for asset in ck.SHIP_CLASS_ORDER
                    for o in _mesh_objects(asset)]
        visible = set(all_objs)
        for ob in bpy.data.objects:
            if ob.type == "MESH":
                ob.hide_render = ob not in visible
        water.hide_render = False
        mn, mx = _bounds(all_objs)
        water.location = ((mn.x + mx.x) * 0.5, (mn.y + mx.y) * 0.5, 0.0)
        scene.render.resolution_x, scene.render.resolution_y = LINEUP_RES
        scene.render.resolution_percentage = 100
        _place_camera(cam, all_objs, LINEUP_VIEW, LINEUP_RES[0], LINEUP_RES[1],
                      margin=1.02)
        lineup = os.path.join(OUT_DIR, "combat_lineup.png")
        scene.render.filepath = lineup
        bpy.ops.render.render(write_still=True)
        results.append(lineup)
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
        if saved["bg"] is not None and world is not None and world.use_nodes:
            bg = next((n for n in world.node_tree.nodes
                       if n.type == "BACKGROUND"), None)
            if bg is not None:
                bg.inputs["Color"].default_value = saved["bg"]
    # 文档副本
    for path in results:
        name = os.path.basename(path)
        if name == "combat_lineup.png":
            target = os.path.join(DOCS_DIR, "combat_lineup.png")
            with open(path, "rb") as src, open(target, "wb") as dst:
                dst.write(src.read())
    print("COMBAT_KIT_PREVIEW_DONE %r" % {"images": results,
                                          "docs": DOCS_DIR})
    return results


if __name__ == "__main__":
    render_all()
