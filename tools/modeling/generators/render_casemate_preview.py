# -*- coding: utf-8 -*-
# @static-doc
# 作用：casemate gun 模块化的**预览渲染**（Lead 验收截图，非游戏资产，Blender 内执行）：
# - 单件：`SN_Weapon_CasemateGun` 的 3/4 与正侧（照 `docs/design/screenshots/weapons/` 惯例）；
# - 装舰：把模块临时实例化到铁甲舰 12 个炮门 socket 上，出 3/4 全景与炮列近景；
# - 空载：同一近景机位、不装模块，对照“空炮门”读感。
# 临时实例只在本脚本内创建，渲染后删除；相机/灯光/世界/可见性全部还原，不改资产。
#
# 输出：`docs/design/screenshots/weapons/casemate_gun_{three_quarter,side}.png`、
#       `docs/design/screenshots/ironclad_casemate_{three_quarter,guns_closeup,empty_closeup}.png`
#
# 用法（已连 Blender 的会话）：
#     import runpy; runpy.run_path(<本文件>, run_name="__main__")
# @end-static-doc

import math
import os

import bpy
from mathutils import Vector

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
SHOT_DIR = os.path.join(WORKDIR, "docs", "design", "screenshots")
WEAPON_SHOT_DIR = os.path.join(SHOT_DIR, "weapons")

IRONCLAD = "SN_Ironclad"
GUN_COLLECTION = "SN_Weapon_CasemateGun_Prototype"
GUN_ROOT = "SN_Weapon_CasemateGun_Root"
GUN_MESHES = ("SN_Weapon_CasemateGun_Barrel", "SN_Weapon_CasemateGun_Breech")
PORT_PREFIX = "SN_IC_Socket_GunPort_"

# 近景机位：瞄 3 号炮门（x=3.586, y=6.1655, z=2.2623，左舷中部）
CLOSEUP_LOCAL = Vector((3.586, 6.1655, 2.2623))  # 船体局部坐标（= 3 号炮门中心）
CLOSEUP_DIR = Vector((0.55, 0.80, 0.28))
CLOSEUP_DISTANCE = 9.5


def _world_points(obj):
    return [obj.matrix_world @ Vector(c) for c in obj.bound_box]


def _bounds(objs):
    points = []
    for obj in objs:
        points.extend(_world_points(obj))
    return (Vector((min(p.x for p in points), min(p.y for p in points),
                    min(p.z for p in points))),
            Vector((max(p.x for p in points), max(p.y for p in points),
                    max(p.z for p in points))))


def _aim(cam, target, direction, distance):
    cam.location = target + direction.normalized() * distance
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()


def _frame(cam, objs, direction, res_x, res_y, margin=1.08):
    mn, mx = _bounds(objs)
    center = (mn + mx) / 2.0
    cam.data.lens = 50.0
    cam.data.sensor_fit = "HORIZONTAL"
    cam.data.sensor_width = 36.0
    tan_x = 18.0 / cam.data.lens
    tan_y = (18.0 / (res_x / res_y)) / cam.data.lens
    dirv = direction.normalized()
    forward = -dirv
    right = forward.cross(Vector((0.0, 0.0, 1.0))).normalized()
    up = right.cross(forward).normalized()
    distance = 0.0
    for obj in objs:
        for point in _world_points(obj):
            q = point - center
            need = q.dot(dirv) + max(abs(q.dot(right)) / tan_x, abs(q.dot(up)) / tan_y)
            distance = max(distance, need)
    _aim(cam, center, dirv, max(distance * margin, 1.0))


def _spawn_mounted_gun(socket, tag):
    """把炮模块（根 + 两个 mesh）临时实例化到 socket 位姿上，返回新对象列表。"""
    collection = bpy.data.collections[GUN_COLLECTION]
    root = bpy.data.objects[GUN_ROOT]
    relative = root.matrix_world.inverted()
    created = []
    new_root = bpy.data.objects.new("TMP_CASEMATE_%s_RedRoot" % tag, None)
    collection.objects.link(new_root)
    new_root.matrix_world = socket.matrix_world.copy()
    created.append(new_root)
    for name in GUN_MESHES:
        source = bpy.data.objects[name]
        duplicate = source.copy()
        duplicate.name = "TMP_CASEMATE_%s_%s" % (tag, name.rsplit("_", 1)[-1])
        collection.objects.link(duplicate)
        duplicate.parent = None
        duplicate.matrix_world = new_root.matrix_world @ (relative @ source.matrix_world)
        created.append(duplicate)
    return created


def _remove(objects):
    for obj in objects:
        data = obj.data if obj.type == "MESH" else None
        bpy.data.objects.remove(obj, do_unlink=True)
        if data is not None and data.users == 0 and data.name.startswith("TMP_"):
            bpy.data.meshes.remove(data)


def render_all():
    scene = bpy.context.scene
    os.makedirs(WEAPON_SHOT_DIR, exist_ok=True)
    ironclad = bpy.data.objects[IRONCLAD]
    collection = bpy.data.collections[GUN_COLLECTION]
    gun_objects = [obj for obj in collection.objects if obj.type == "MESH"]
    sockets = sorted((obj for obj in bpy.data.objects if obj.name.startswith(PORT_PREFIX)),
                     key=lambda obj: obj.name)

    saved = {
        "engine": scene.render.engine,
        "camera": scene.camera,
        "res_x": scene.render.resolution_x,
        "res_y": scene.render.resolution_y,
        "filepath": scene.render.filepath,
        "bg": None,
    }
    cam_data = bpy.data.cameras.new("TMP_CASEMATE_CAM")
    cam = bpy.data.objects.new("TMP_CASEMATE_CAM", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    temp = [cam]
    for name, energy, rot in (
        ("TMP_CASEMATE_SUN_KEY", 4.0, (math.radians(50), 0.0, math.radians(35))),
        ("TMP_CASEMATE_SUN_FILL", 1.5, (math.radians(62), 0.0, math.radians(215))),
    ):
        data = bpy.data.lights.new(name, "SUN")
        data.energy = energy
        data.angle = 0.35
        obj = bpy.data.objects.new(name, data)
        obj.rotation_euler = rot
        scene.collection.objects.link(obj)
        temp.append(obj)

    world = scene.world
    if world and world.use_nodes:
        background = next((node for node in world.node_tree.nodes
                           if node.type == "BACKGROUND"), None)
        if background is not None:
            saved["bg"] = tuple(background.inputs["Color"].default_value)
            background.inputs["Color"].default_value = (0.055, 0.062, 0.075, 1.0)

    hidden = {}
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            hidden[obj.name] = obj.hide_render

    scene.render.engine = "BLENDER_EEVEE_NEXT"
    if hasattr(scene, "eevee"):
        scene.eevee.taa_render_samples = 32
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.film_transparent = False
    scene.render.resolution_percentage = 100

    results = []
    mounted = []

    def shoot(path, res):
        scene.render.resolution_x, scene.render.resolution_y = res
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        results.append(path)

    try:
        # ---- 1. 单件 -------------------------------------------------------
        def only(show):
            for obj in bpy.data.objects:
                if obj.type == "MESH":
                    obj.hide_render = obj.name not in show

        only(set(obj.name for obj in gun_objects))
        _frame(cam, gun_objects, Vector((0.80, -0.95, 0.42)), 1240, 780)
        shoot(os.path.join(WEAPON_SHOT_DIR, "casemate_gun_three_quarter.png"), (1240, 780))
        _frame(cam, gun_objects, Vector((0.0, -1.0, 0.10)), 1400, 620)
        shoot(os.path.join(WEAPON_SHOT_DIR, "casemate_gun_side.png"), (1400, 620))

        # ---- 2. 装舰（12 门全部临时实例化） --------------------------------
        for index, socket in enumerate(sockets, start=1):
            mounted.extend(_spawn_mounted_gun(socket, "%02d" % index))
        only({IRONCLAD} | {obj.name for obj in mounted if obj.type == "MESH"})
        _frame(cam, [ironclad], Vector((0.90, -1.00, 0.50)), 1300, 780)
        shoot(os.path.join(SHOT_DIR, "ironclad_casemate_three_quarter.png"), (1300, 780))
        closeup_target = ironclad.matrix_world @ CLOSEUP_LOCAL
        _aim(cam, closeup_target, CLOSEUP_DIR, CLOSEUP_DISTANCE)
        shoot(os.path.join(SHOT_DIR, "ironclad_casemate_guns_closeup.png"), (1400, 800))

        # ---- 3. 空负载（同机位对照） ---------------------------------------
        only({IRONCLAD})
        _aim(cam, closeup_target, CLOSEUP_DIR, CLOSEUP_DISTANCE)
        shoot(os.path.join(SHOT_DIR, "ironclad_casemate_empty_closeup.png"), (1400, 800))
    finally:
        _remove(mounted)
        for obj in temp:
            data = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            if isinstance(data, bpy.types.Light):
                bpy.data.lights.remove(data)
            elif isinstance(data, bpy.types.Camera):
                bpy.data.cameras.remove(data)
        for name, value in hidden.items():
            obj = bpy.data.objects.get(name)
            if obj is not None:
                obj.hide_render = value
        scene.camera = saved["camera"]
        scene.render.engine = saved["engine"]
        scene.render.resolution_x = saved["res_x"]
        scene.render.resolution_y = saved["res_y"]
        scene.render.filepath = saved["filepath"]
        if saved["bg"] is not None:
            background = next((node for node in world.node_tree.nodes
                               if node.type == "BACKGROUND"), None)
            if background is not None:
                background.inputs["Color"].default_value = saved["bg"]

    print("CASEMATE_PREVIEW_DONE " + repr({"count": len(results), "files": results}))
    return results


if __name__ == "__main__":
    render_all()
