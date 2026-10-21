# -*- coding: utf-8 -*-
# @static-doc
# 作用：舰载武器五件套的预览渲染（Lead 在人工验收前执行，不进游戏）。
#
# 在工作台里逐件隔离目标集合，临时创建相机 / 灯光 / 地面，渲染 3/4 与侧视；
# 最后把五件临时摆成一排渲染 lineup（正交相机，便于判断相互比例）。渲染完成后
# 删除临时对象并恢复所有 hide_render 状态，不保存 .blend、不导出 GLB。
#
# 用法（已连 Blender 的会话）：
#     import runpy; runpy.run_path(<本文件>, run_name="__main__")
# 输出：.design/weapons/preview/*.png 与 docs/design/screenshots/weapons/*.png
# @end-static-doc

import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
LOCAL_DIR = os.path.join(WORKDIR, ".design", "weapons", "preview")
DOCS_DIR = os.path.join(WORKDIR, "docs", "design", "screenshots", "weapons")

WEAPONS = [
    ("SN_Weapon_DeckGun", "SN_Weapon_DeckGun_Prototype",
     "SN_Weapon_DeckGun_Root", "deck_gun"),
    ("SN_Weapon_HeavyCannon", "SN_Weapon_HeavyCannon_Prototype",
     "SN_Weapon_HeavyCannon_Root", "heavy_cannon"),
    ("SN_Weapon_Mortar", "SN_Weapon_Mortar_Prototype",
     "SN_Weapon_Mortar_Root", "mortar"),
    ("SN_Weapon_Repeater", "SN_Weapon_Repeater_Prototype",
     "SN_Weapon_Repeater_Root", "repeater"),
    ("SN_Weapon_Broadside", "SN_Weapon_Broadside_Prototype",
     "SN_Weapon_Broadside_Root", "broadside"),
]

VIEW_DIRS = {
    "three_quarter": (1.00, -1.00, 0.72),
    "side": (0.02, 1.00, 0.30),
    "front": (1.00, 0.02, 0.30),
}

PER_ASSET_VIEWS = ("three_quarter", "side")
TEMP_PREFIX = "SN_WPN_PREVIEW_"
LINEUP_NAME = "weapon_batch1_lineup"
LINEUP_ROTATE_Z = {"SN_Weapon_Broadside": 90.0}
_ORIGINAL = {}


def _capture_stage_state():
    scene = bpy.context.scene
    world = scene.world
    bg = None
    if world is not None and world.use_nodes:
        bg = next((n for n in world.node_tree.nodes
                   if n.type == "BACKGROUND"), None)
    _ORIGINAL.update({
        "engine": scene.render.engine,
        "camera": scene.camera,
        "resolution": (scene.render.resolution_x,
                       scene.render.resolution_y,
                       scene.render.resolution_percentage),
        "bg": ((tuple(bg.inputs["Color"].default_value),
                bg.inputs["Strength"].default_value) if bg else None),
    })


def _restore_stage_state():
    if not _ORIGINAL:
        return
    scene = bpy.context.scene
    scene.render.engine = _ORIGINAL["engine"]
    scene.camera = _ORIGINAL["camera"]
    (scene.render.resolution_x, scene.render.resolution_y,
     scene.render.resolution_percentage) = _ORIGINAL["resolution"]
    bg_original = _ORIGINAL.get("bg")
    world = scene.world
    if bg_original is not None and world is not None and world.use_nodes:
        bg = next((n for n in world.node_tree.nodes
                   if n.type == "BACKGROUND"), None)
        if bg is not None:
            bg.inputs["Color"].default_value = bg_original[0]
            bg.inputs["Strength"].default_value = bg_original[1]


def _safe_remove(name):
    ob = bpy.data.objects.get(name)
    if ob is not None:
        bpy.data.objects.remove(ob, do_unlink=True)


def _clean_temps():
    for ob in list(bpy.data.objects):
        if ob.name.startswith(TEMP_PREFIX):
            bpy.data.objects.remove(ob, do_unlink=True)


def _collection_bbox(collection):
    mn = Vector((1e18, 1e18, 1e18))
    mx = Vector((-1e18, -1e18, -1e18))
    for ob in collection.objects:
        if ob.type != "MESH":
            continue
        for corner in ob.bound_box:
            p = ob.matrix_world @ Vector(corner)
            for i in range(3):
                mn[i] = min(mn[i], p[i])
                mx[i] = max(mx[i], p[i])
    return mn, mx


def _make_material(name, color, roughness=0.9):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        bsdf = next(n for n in mat.node_tree.nodes
                    if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
    return mat


def _make_stage():
    if not _ORIGINAL:
        _capture_stage_state()
    _clean_temps()
    floor_mesh = bpy.data.meshes.new(TEMP_PREFIX + "FloorMesh")
    floor_mesh.from_pydata(
        [(-120, 300, -0.01), (120, 300, -0.01),
         (120, 500, -0.01), (-120, 500, -0.01)],
        [], [(0, 1, 2, 3)])
    floor = bpy.data.objects.new(TEMP_PREFIX + "Floor", floor_mesh)
    bpy.context.scene.collection.objects.link(floor)
    floor_mesh.materials.append(_make_material(
        TEMP_PREFIX + "FloorMat", (0.10, 0.105, 0.115), 0.92))
    floor.hide_render = False

    world = bpy.context.scene.world
    if world is None:
        world = bpy.data.worlds.new("World")
        bpy.context.scene.world = world
    world.use_nodes = True
    bg = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"),
              None)
    if bg is not None:
        bg.inputs["Color"].default_value = (0.16, 0.17, 0.19, 1.0)
        bg.inputs["Strength"].default_value = 0.8

    sun_data = bpy.data.lights.new(TEMP_PREFIX + "SunData", type="SUN")
    sun_data.energy = 3.2
    sun_data.angle = math.radians(8.0)
    sun = bpy.data.objects.new(TEMP_PREFIX + "Sun", sun_data)
    bpy.context.scene.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(52.0), math.radians(8.0),
                          math.radians(35.0))

    fill_data = bpy.data.lights.new(TEMP_PREFIX + "FillData", type="AREA")
    fill_data.energy = 900.0
    fill_data.size = 12.0
    fill = bpy.data.objects.new(TEMP_PREFIX + "Fill", fill_data)
    bpy.context.scene.collection.objects.link(fill)
    fill.location = (12.0, 330.0, 14.0)

    cam_data = bpy.data.cameras.new(TEMP_PREFIX + "CamData")
    cam_data.lens = 55.0
    cam = bpy.data.objects.new(TEMP_PREFIX + "Camera", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.render_aa = "8"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.studio_light = "paint.sl"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.display.shading.cavity_type = "BOTH"
    scene.display.shading.background_type = "VIEWPORT"
    scene.display.shading.background_color = (0.20, 0.21, 0.23)
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    return cam, sun, fill, floor


def _look_at(cam, target, location):
    cam.location = location
    direction = Vector(target) - Vector(location)
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def _hide_others(visible_collection_names):
    states = {}
    for ob in bpy.data.objects:
        states[ob.name] = ob.hide_render
        ob.hide_render = True
    for ob in bpy.data.objects:
        if ob.type == "MESH" and ob.name.startswith(TEMP_PREFIX):
            ob.hide_render = False
        for col in ob.users_collection:
            if col.name in visible_collection_names:
                ob.hide_render = False
                break
    return states


def _restore_hidden(states):
    for name, value in states.items():
        ob = bpy.data.objects.get(name)
        if ob is not None:
            ob.hide_render = value


def _render(path, resolution):
    scene = bpy.context.scene
    scene.render.resolution_x = resolution[0]
    scene.render.resolution_y = resolution[1]
    scene.render.resolution_percentage = 100
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def render_assets():
    os.makedirs(LOCAL_DIR, exist_ok=True)
    os.makedirs(DOCS_DIR, exist_ok=True)
    cam, _sun, _fill, _floor = _make_stage()
    results = []
    for asset, collection_name, root_name, slug in WEAPONS:
        collection = bpy.data.collections.get(collection_name)
        if collection is None:
            raise RuntimeError("missing collection %s" % collection_name)
        states = _hide_others({collection_name})
        try:
            mn, mx = _collection_bbox(collection)
            center = (mn + mx) * 0.5
            size = mx - mn
            max_dim = max(size.x, size.y, size.z)
            for view in PER_ASSET_VIEWS:
                direction = Vector(VIEW_DIRS[view]).normalized()
                distance = max_dim * 2.1 + 2.0
                location = center + direction * distance
                _look_at(cam, center, location)
                for out_dir in (LOCAL_DIR, DOCS_DIR):
                    path = os.path.join(
                        out_dir, "weapon_%s_%s.png" % (slug, view))
                    _render(path, (900, 700))
                results.append((asset, view, os.path.join(
                    DOCS_DIR, "weapon_%s_%s.png" % (slug, view))))
        finally:
            _restore_hidden(states)
    return results


def render_lineup():
    cam, _sun, _fill, _floor = _make_stage()
    scene = bpy.context.scene
    scene.camera = cam
    cam.data.type = "ORTHO"
    roots = []
    saved = {}
    widths = []
    max_height = 0.0
    for asset, collection_name, root_name, slug in WEAPONS:
        root = bpy.data.objects.get(root_name)
        collection = bpy.data.collections.get(collection_name)
        if root is None or collection is None:
            raise RuntimeError("missing %s / %s" % (root_name, collection_name))
        saved[asset] = (tuple(root.location), tuple(root.rotation_euler))
        roots.append(root)
        mn, mx = _collection_bbox(collection)
        size = mx - mn
        rot = LINEUP_ROTATE_Z.get(asset, 0.0)
        widths.append(size.y if abs(rot) > 1.0 else size.x)
        max_height = max(max_height, size.z)
    hidden = _hide_others({c[1] for c in WEAPONS})
    try:
        gap = 2.0
        total = sum(widths) + gap * max(0, len(widths) - 1)
        cursor = -total * 0.5
        for index, root in enumerate(roots):
            asset = WEAPONS[index][0]
            width = widths[index]
            root.location.x = cursor + width * 0.5
            root.location.y = 420.0
            root.location.z = 0.0
            root.rotation_euler.z = math.radians(
                LINEUP_ROTATE_Z.get(asset, 0.0))
            cursor += width + gap
        target_z = max(1.2, max_height * 0.5)
        target = (0.0, 420.0, target_z)
        _look_at(cam, target, (0.0, 470.0, target_z + 10.8))
        cam.data.ortho_scale = max(total + 4.0,
                                   (max_height + 2.0) * 1400.0 / 520.0)
        for out_dir in (LOCAL_DIR, DOCS_DIR):
            _render(os.path.join(out_dir, "%s.png" % LINEUP_NAME),
                    (1400, 520))
    finally:
        _restore_hidden(hidden)
        for (asset, collection_name, root_name, slug), (loc, rot) in zip(
                WEAPONS, [saved[a] for a, _c, _r, _s in WEAPONS]):
            root = bpy.data.objects.get(root_name)
            if root is not None:
                root.location = loc
                root.rotation_euler = rot
        cam.data.type = "PERSP"
        cam.data.ortho_scale = 1.0
        bpy.context.view_layer.update()
    return os.path.join(DOCS_DIR, "%s.png" % LINEUP_NAME)


def main():
    try:
        assets = render_assets()
        lineup = render_lineup()
        print("WEAPON_PREVIEW_DONE %r" % {
            "per_asset": len(assets),
            "lineup": lineup,
        })
    finally:
        _clean_temps()
        _restore_stage_state()


if __name__ == "__main__":
    main()
