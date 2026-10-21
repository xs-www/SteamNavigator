# -*- coding: utf-8 -*-
# @static-doc
# 作用：模型素材库批次 1（武器套件 + 船体部件）的预览渲染（Lead 在人工验收前执行，
# 不进游戏）。
#
# 在工作台里逐件隔离目标集合，临时创建相机 / 灯光 / 地面，渲染 3/4 与侧视；再输出
# 两组 lineup（武器套件 / 船体部件）与两张拼装演示（火炮+炮架、甲板+桅杆+烟囱+
# 货舱盖+炮塔+基座）。渲染完成后删除临时对象并恢复所有 hide_render、root 变换与
# 视口 shading（工作台约定 Solid = SINGLE 灰模，渲染时临时切 TEXTURE 后恢复），
# 不保存 .blend、不导出 GLB。
#
# 用法（已连 Blender 的会话）：
#     import runpy; runpy.run_path(<本文件>, run_name="__main__")
# 输出：.design/kits/preview/*.png 与 docs/design/screenshots/kits/*.png
# @end-static-doc

import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
LOCAL_DIR = os.path.join(WORKDIR, ".design", "kits", "preview")
DOCS_DIR = os.path.join(WORKDIR, "docs", "design", "screenshots", "kits")

# (资产, 集合, 根空物体, slug, 组)
ASSETS = [
    ("SN_Weapon_Cannon", "SN_Weapon_Cannon_Prototype",
     "SN_Weapon_Cannon_Root", "cannon", "weapon"),
    ("SN_Weapon_GunCarriage", "SN_Weapon_GunCarriage_Prototype",
     "SN_Weapon_GunCarriage_Root", "gun_carriage", "weapon"),
    ("SN_Weapon_Turret", "SN_Weapon_Turret_Prototype",
     "SN_Weapon_Turret_Root", "turret", "weapon"),
    ("SN_Weapon_Pedestal", "SN_Weapon_Pedestal_Prototype",
     "SN_Weapon_Pedestal_Root", "pedestal", "weapon"),
    ("SN_ShipPart_Deck", "SN_ShipPart_Deck_Prototype",
     "SN_ShipPart_Deck_Root", "deck", "ship"),
    ("SN_ShipPart_Mast", "SN_ShipPart_Mast_Prototype",
     "SN_ShipPart_Mast_Root", "mast", "ship"),
    ("SN_ShipPart_Funnel", "SN_ShipPart_Funnel_Prototype",
     "SN_ShipPart_Funnel_Root", "funnel", "ship"),
    ("SN_ShipPart_HatchCover", "SN_ShipPart_HatchCover_Prototype",
     "SN_ShipPart_HatchCover_Root", "hatch_cover", "ship"),
]

VIEW_DIRS = {
    "three_quarter": (1.00, -1.00, 0.62),
    "side": (0.02, 1.00, 0.30),
}
PER_ASSET_VIEWS = ("three_quarter", "side")
TEMP_PREFIX = "SN_KIT_PREVIEW_"
_ORIGINAL = {}


# ---------------------------------------------------------------- 临时舞台

def _capture_stage_state():
    scene = bpy.context.scene
    world = scene.world
    bg = None
    if world is not None and world.use_nodes:
        bg = next((n for n in world.node_tree.nodes
                   if n.type == "BACKGROUND"), None)
    shading = scene.display.shading
    _ORIGINAL.update({
        "engine": scene.render.engine,
        "camera": scene.camera,
        "resolution": (scene.render.resolution_x,
                       scene.render.resolution_y,
                       scene.render.resolution_percentage),
        "bg": ((tuple(bg.inputs["Color"].default_value),
                bg.inputs["Strength"].default_value) if bg else None),
        "shading": (shading.color_type, tuple(shading.single_color),
                    shading.light, shading.studio_light,
                    shading.show_shadows, shading.show_cavity,
                    shading.cavity_type, shading.background_type,
                    tuple(shading.background_color)),
    })


def _restore_stage_state():
    if not _ORIGINAL:
        return
    scene = bpy.context.scene
    scene.render.engine = _ORIGINAL["engine"]
    scene.camera = _ORIGINAL["camera"]
    (scene.render.resolution_x, scene.render.resolution_y,
     scene.render.resolution_percentage) = _ORIGINAL["resolution"]
    shading_state = _ORIGINAL.get("shading")
    if shading_state:
        (color_type, single_color, light, studio_light, show_shadows,
         show_cavity, cavity_type, background_type,
         background_color) = shading_state
        shading = scene.display.shading
        shading.color_type = color_type
        shading.single_color = single_color
        shading.light = light
        shading.studio_light = studio_light
        shading.show_shadows = show_shadows
        shading.show_cavity = show_cavity
        shading.cavity_type = cavity_type
        shading.background_type = background_type
        shading.background_color = background_color
    bg_original = _ORIGINAL.get("bg")
    world = scene.world
    if bg_original is not None and world is not None and world.use_nodes:
        bg = next((n for n in world.node_tree.nodes
                   if n.type == "BACKGROUND"), None)
        if bg is not None:
            bg.inputs["Color"].default_value = bg_original[0]
            bg.inputs["Strength"].default_value = bg_original[1]


def _clean_temps():
    for ob in list(bpy.data.objects):
        if ob.name.startswith(TEMP_PREFIX):
            bpy.data.objects.remove(ob, do_unlink=True)


def _make_material(name, color, roughness=0.9):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        bsdf = next(n for n in mat.node_tree.nodes
                    if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
    mat.diffuse_color = (*color, 1.0)
    mat.roughness = roughness
    return mat


def _make_stage():
    if not _ORIGINAL:
        _capture_stage_state()
    _clean_temps()
    floor_mesh = bpy.data.meshes.new(TEMP_PREFIX + "FloorMesh")
    floor_mesh.from_pydata(
        [(-140, 300, -0.012), (140, 300, -0.012),
         (140, 620, -0.012), (-140, 620, -0.012)],
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
    fill_data.energy = 1600.0
    fill_data.size = 18.0
    fill = bpy.data.objects.new(TEMP_PREFIX + "Fill", fill_data)
    bpy.context.scene.collection.objects.link(fill)
    fill.location = (16.0, 440.0, 18.0)

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
    cam.data.type = "PERSP"
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
            continue
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


def _render_both(name, resolution):
    for out_dir in (LOCAL_DIR, DOCS_DIR):
        _render(os.path.join(out_dir, name), resolution)


def _collections_bbox(collection_names):
    mn = Vector((1e18, 1e18, 1e18))
    mx = Vector((-1e18, -1e18, -1e18))
    for name in collection_names:
        collection = bpy.data.collections.get(name)
        if collection is None:
            raise RuntimeError("missing collection %s" % name)
        for ob in collection.objects:
            if ob.type != "MESH" or ob.hide_render:
                continue
            for corner in ob.bound_box:
                p = ob.matrix_world @ Vector(corner)
                for i in range(3):
                    mn[i] = min(mn[i], p[i])
                    mx[i] = max(mx[i], p[i])
    return mn, mx


def _frame(cam, mn, mx, view, factor=2.8):
    center = (mn + mx) * 0.5
    size = mx - mn
    max_dim = max(size.x, size.y, size.z, 0.6)
    # 55 mm 镜头（36 mm 传感器）垂直视场约 24.6°：默认 2.8 倍能把最高件
    # （桅杆 12.84 m）的桅顶瞭望台完整收进画面；矮宽件可传更小 factor。
    direction = Vector(VIEW_DIRS[view]).normalized()
    distance = max_dim * factor + 2.0
    _look_at(cam, center, center + direction * distance)


def _temp_box(name, lo, hi):
    """lineup 临时展示托架（渲染后删除，不属于资产）。"""
    verts = []
    for z in (lo[2], hi[2]):
        for (x, y) in ((lo[0], lo[1]), (hi[0], lo[1]),
                       (hi[0], hi[1]), (lo[0], hi[1])):
            verts.append((x, y, z))
    faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4),
             (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    me = bpy.data.meshes.new(TEMP_PREFIX + name + "Mesh")
    me.from_pydata(verts, [], faces)
    me.update()
    me.materials.append(_make_material(
        TEMP_PREFIX + "StandMat", (0.22, 0.16, 0.11), 0.85))
    ob = bpy.data.objects.new(TEMP_PREFIX + name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


# ---------------------------------------------------------------- 单件渲染

def render_assets():
    cam, _sun, _fill, _floor = _make_stage()
    results = []
    for asset, collection_name, root_name, slug, _group in ASSETS:
        states = _hide_others({collection_name})
        try:
            mn, mx = _collections_bbox([collection_name])
            for view in PER_ASSET_VIEWS:
                _frame(cam, mn, mx, view)
                name = "kit_%s_%s.png" % (slug, view)
                _render_both(name, (900, 700))
                results.append((asset, view))
        finally:
            _restore_hidden(states)
    return results


# ---------------------------------------------------------------- lineup

def _lineup(group, slug, resolution=(1500, 680), gap=1.6):
    cam, _sun, _fill, _floor = _make_stage()
    scene = bpy.context.scene
    cam.data.type = "ORTHO"
    items = [a for a in ASSETS if a[4] == group]
    collections = [a[1] for a in items]
    roots = []
    saved = {}
    widths = []
    max_height = 0.0
    for asset, collection_name, root_name, _slug, _group in items:
        root = bpy.data.objects.get(root_name)
        if root is None:
            raise RuntimeError("missing root %s" % root_name)
        roots.append(root)
        saved[asset] = tuple(root.location)
        mn, mx = _collections_bbox([collection_name])
        size = mx - mn
        widths.append(size.x)
        max_height = max(max_height, size.z)
        del mn, mx
    hidden = _hide_others(set(collections))
    stands = []
    try:
        total = sum(widths) + gap * max(0, len(widths) - 1)
        cursor = -total * 0.5
        base_y = 500.0
        for index, root in enumerate(roots):
            asset = items[index][0]
            root.location = (cursor + widths[index] * 0.5, base_y, 0.0)
            if asset == "SN_Weapon_Cannon":
                root.location.z = 0.62
            cursor += widths[index] + gap
        if group == "weapon":
            # 火炮是俯仰子件（根 = 耳轴轴心），lineup 里加临时托架说明它是被托住的
            cannon = bpy.data.objects["SN_Weapon_Cannon_Root"]
            cx, cy = cannon.location.x, cannon.location.y
            for name, x, top in (("StandRear", cx - 1.15, 0.39),
                                 ("StandFront", cx + 1.15, 0.46)):
                _temp_box(name, (x - 0.14, cy - 0.32, 0.0),
                          (x + 0.14, cy + 0.32, top))
                stands.append(TEMP_PREFIX + name)
        bpy.context.view_layer.update()
        target = (0.0, base_y, max_height * 0.5)
        cam.data.ortho_scale = max(total + 4.0,
                                   (max_height + 2.0) * resolution[0] / resolution[1])
        _look_at(cam, target, (0.0, base_y + 7.0, max_height * 0.5 + total * 0.02))
        _render_both("kit_%s_lineup.png" % slug, resolution)
    finally:
        _restore_hidden(hidden)
        for name in stands:
            ob = bpy.data.objects.get(name)
            if ob is not None:
                bpy.data.objects.remove(ob, do_unlink=True)
        for asset, _c, _r, _s, _g in items:
            root = bpy.data.objects.get(_r)
            if root is not None:
                root.location = saved[asset]
        cam.data.type = "PERSP"
        cam.data.ortho_scale = 1.0
        bpy.context.view_layer.update()


# ---------------------------------------------------------------- 拼装演示

def _save_roots(names):
    saved = {}
    for name in names:
        root = bpy.data.objects.get(name)
        if root is not None:
            saved[name] = tuple(root.location)
    return saved


def _restore_roots(saved):
    for name, location in saved.items():
        root = bpy.data.objects.get(name)
        if root is not None:
            root.location = location
    bpy.context.view_layer.update()


def render_gun_assembly():
    """火炮 + 炮架：火炮 root 落在炮架耳轴高度 z=0.62。"""
    cam, _sun, _fill, _floor = _make_stage()
    cannon = bpy.data.objects["SN_Weapon_Cannon_Root"]
    carriage = bpy.data.objects["SN_Weapon_GunCarriage_Root"]
    saved = _save_roots([cannon.name, carriage.name])
    hidden = _hide_others({"SN_Weapon_GunCarriage_Prototype",
                           "SN_Weapon_Cannon_Prototype"})
    try:
        carriage.location = (0.0, 500.0, 0.0)
        cannon.location = (carriage.location.x, carriage.location.y, 0.62)
        bpy.context.view_layer.update()
        mn, mx = _collections_bbox(["SN_Weapon_GunCarriage_Prototype",
                                    "SN_Weapon_Cannon_Prototype"])
        _frame(cam, mn, mx, "three_quarter", factor=1.9)
        _render_both("kit_assembly_gun.png", (1100, 760))
    finally:
        _restore_hidden(hidden)
        _restore_roots(saved)


def render_deck_assembly():
    """甲板 + 桅杆 + 烟囱 + 货舱盖 + 炮塔 + 基座：全部按 socket 落位。"""
    cam, _sun, _fill, _floor = _make_stage()
    deck = bpy.data.objects["SN_ShipPart_Deck_Root"]
    mounts = [
        ("SN_ShipPart_Mast_Root", (0.0, 0.40, 0.33)),
        ("SN_ShipPart_Funnel_Root", (2.40, -0.60, 0.33)),
        ("SN_ShipPart_HatchCover_Root", (-2.40, -0.30, 0.33)),
        ("SN_Weapon_Turret_Root", (2.30, 1.10, 0.33)),
        ("SN_Weapon_Pedestal_Root", (-2.30, 1.10, 0.33)),
    ]
    names = [deck.name] + [name for name, _loc in mounts]
    saved = _save_roots(names)
    collections = {"SN_ShipPart_Deck_Prototype", "SN_ShipPart_Mast_Prototype",
                   "SN_ShipPart_Funnel_Prototype",
                   "SN_ShipPart_HatchCover_Prototype",
                   "SN_Weapon_Turret_Prototype",
                   "SN_Weapon_Pedestal_Prototype"}
    hidden = _hide_others(collections)
    try:
        deck.location = (0.0, 500.0, 0.0)
        for name, location in mounts:
            root = bpy.data.objects[name]
            root.location = (deck.location.x + location[0],
                             deck.location.y + location[1],
                             deck.location.z + location[2])
        bpy.context.view_layer.update()
        mn, mx = _collections_bbox(sorted(collections))
        _frame(cam, mn, mx, "three_quarter")
        _render_both("kit_assembly_deck.png", (1200, 900))
        # 甲板层近景：突出模块拼装关系
        low_target = Vector((0.5, 500.0, 1.40))
        low_dir = Vector((1.0, -1.0, 0.42)).normalized()
        cam.location = low_target + low_dir * 16.0
        _look_at(cam, low_target, cam.location)
        _render_both("kit_assembly_deck_detail.png", (1200, 820))
    finally:
        _restore_hidden(hidden)
        _restore_roots(saved)


def main():
    os.makedirs(LOCAL_DIR, exist_ok=True)
    os.makedirs(DOCS_DIR, exist_ok=True)
    try:
        per_asset = render_assets()
        _lineup("weapon", "weapon")
        _lineup("ship", "ship_parts", resolution=(1500, 820))
        render_gun_assembly()
        render_deck_assembly()
        print("KIT_PREVIEW_DONE %r" % {
            "per_asset": len(per_asset) * 2,
            "lineups": 2,
            "assemblies": 2,
            "docs_dir": os.path.relpath(DOCS_DIR, WORKDIR),
        })
    finally:
        _clean_temps()
        _restore_stage_state()


if __name__ == "__main__":
    main()
