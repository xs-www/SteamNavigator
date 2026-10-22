# -*- coding: utf-8 -*-
# @static-doc
# 作用：LOD1 基础套件（M0-5）的预览渲染：在工作台里逐件把 `SN_<Asset>_LOD1` 临时摆到
# LOD0 右侧同机位渲染对比图（kit 26 + 船 4），再按类别输出 8 张 LOD1 lineup；渲染用
# Workbench TEXTURE（与 kit 预览一致），临时相机 / 灯光 / 地面 / hide_render 在 finally
# 里全部还原，不保存 .blend、不改资产变换。
#
# ## 契约与约束
# - 只读资产：唯一写操作是 LOD1 对象的临时 location 与场景渲染设置，渲染后还原。
# - 输出双份：`.design/lod1_kit_ships/preview/*.png`（本地）与
#   `docs/design/screenshots/lod1/*.png`（文档证据；仓库对 screenshots 目录 gitignore，
#   提交时需要 `git add -f`，与历史批次一致）。
# - 对比图机位：3/4 视角、LOD1 放在 LOD0 包围盒右侧 2 m，地面/水线对齐；两侧用同一
#   包围盒取景，因此可以直接比较轮廓与尺寸。
#
# ## 重点逻辑
# ### `render_comparisons(assets=None)`
# - 逐件隐藏其它对象 → 摆 LOD1 → 取 LOD0+LOD1 世界包围盒 → 相机取景 → 渲染 1024×640。
# ### `render_lineups()`
# - 按 category 取 LOD1 对象（工作台 y=780 一排）→ 正交构图渲染 1440×620。
# @end-static-doc

import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
LOCAL_DIR = os.path.join(REPO_ROOT, ".design", "lod1_kit_ships", "preview")
DOCS_DIR = os.path.join(REPO_ROOT, "docs", "design", "screenshots", "lod1")
TEMP_PREFIX = "SN_LOD1_PREVIEW_"
VIEW_DIRS = {
    "three_quarter": (1.0, -1.0, 0.62),
    "front": (0.05, -1.0, 0.18),
    "side": (1.0, 0.02, 0.28),
}
_ORIGINAL = {}


def _load_generator():
    import importlib.util

    path = os.path.join(HERE, "sn_lod1_kit_ships_generator.py")
    spec = importlib.util.spec_from_file_location("sn_lod1_kit_ships_generator", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# ---------------------------------------------------------------- stage state

def _capture_stage_state():
    scene = bpy.context.scene
    world = scene.world
    background = None
    if world is not None and world.use_nodes:
        background = next((node for node in world.node_tree.nodes
                           if node.type == "BACKGROUND"), None)
    shading = scene.display.shading
    _ORIGINAL.update({
        "engine": scene.render.engine,
        "camera": scene.camera,
        "resolution": (scene.render.resolution_x, scene.render.resolution_y,
                       scene.render.resolution_percentage),
        "background": ((tuple(background.inputs["Color"].default_value),
                        background.inputs["Strength"].default_value)
                       if background else None),
        "shading": (shading.color_type, tuple(shading.single_color), shading.light,
                    shading.studio_light, shading.show_shadows, shading.show_cavity,
                    shading.cavity_type, shading.background_type,
                    tuple(shading.background_color)),
        "filepath": scene.render.filepath,
    })


def _restore_stage_state():
    if not _ORIGINAL:
        return
    scene = bpy.context.scene
    scene.render.engine = _ORIGINAL["engine"]
    scene.camera = _ORIGINAL["camera"]
    (scene.render.resolution_x, scene.render.resolution_y,
     scene.render.resolution_percentage) = _ORIGINAL["resolution"]
    scene.render.filepath = _ORIGINAL["filepath"]
    shading_state = _ORIGINAL.get("shading")
    if shading_state:
        shading = scene.display.shading
        (shading.color_type, shading.single_color, shading.light,
         shading.studio_light, shading.show_shadows, shading.show_cavity,
         shading.cavity_type, shading.background_type,
         shading.background_color) = shading_state
    background_state = _ORIGINAL.get("background")
    world = scene.world
    if background_state is not None and world is not None and world.use_nodes:
        background = next((node for node in world.node_tree.nodes
                           if node.type == "BACKGROUND"), None)
        if background is not None:
            background.inputs["Color"].default_value = background_state[0]
            background.inputs["Strength"].default_value = background_state[1]


def _clean_temps():
    for obj in list(bpy.data.objects):
        if obj.name.startswith(TEMP_PREFIX):
            mesh = obj.data if obj.type == "MESH" else None
            bpy.data.objects.remove(obj, do_unlink=True)
            if mesh is not None and mesh.users == 0:
                bpy.data.meshes.remove(mesh)


def _make_floor(z):
    mesh = bpy.data.meshes.new(TEMP_PREFIX + "FloorMesh")
    mesh.from_pydata([(-3000, -3000, z), (3000, -3000, z), (3000, 8000, z),
                      (-3000, 8000, z)], [], [(0, 1, 2, 3)])
    material = bpy.data.materials.get(TEMP_PREFIX + "FloorMat")
    if material is None:
        material = bpy.data.materials.new(TEMP_PREFIX + "FloorMat")
        material.use_nodes = True
        bsdf = next(node for node in material.node_tree.nodes
                    if node.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (0.11, 0.12, 0.13, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.93
    # Workbench TEXTURE 模式下没有贴图的材质回退到 diffuse_color，必须显式设深色。
    material.diffuse_color = (0.11, 0.12, 0.13, 1.0)
    material.roughness = 0.93
    mesh.materials.append(material)
    obj = bpy.data.objects.new(TEMP_PREFIX + "Floor", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _make_stage(ground_z):
    _clean_temps()
    if not _ORIGINAL:
        _capture_stage_state()
    _make_floor(ground_z - 0.01)
    world = bpy.context.scene.world
    if world is None:
        world = bpy.data.worlds.new("World")
        bpy.context.scene.world = world
    world.use_nodes = True
    background = next((node for node in world.node_tree.nodes
                       if node.type == "BACKGROUND"), None)
    if background is not None:
        background.inputs["Color"].default_value = (0.16, 0.17, 0.19, 1.0)
        background.inputs["Strength"].default_value = 0.8
    sun_data = bpy.data.lights.new(TEMP_PREFIX + "SunData", type="SUN")
    sun_data.energy = 3.2
    sun_data.angle = math.radians(8.0)
    sun = bpy.data.objects.new(TEMP_PREFIX + "Sun", sun_data)
    bpy.context.scene.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(52.0), math.radians(8.0), math.radians(35.0))
    fill_data = bpy.data.lights.new(TEMP_PREFIX + "FillData", type="AREA")
    fill_data.energy = 2400.0
    fill_data.size = 30.0
    fill = bpy.data.objects.new(TEMP_PREFIX + "Fill", fill_data)
    bpy.context.scene.collection.objects.link(fill)
    scene = bpy.context.scene
    camera_data = bpy.data.cameras.new(TEMP_PREFIX + "CamData")
    camera_data.lens = 55.0
    camera_data.clip_end = 10000.0
    camera = bpy.data.objects.new(TEMP_PREFIX + "Camera", camera_data)
    bpy.context.scene.collection.objects.link(camera)
    scene.camera = camera
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.render_aa = "8"
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.studio_light = "paint.sl"
    shading.color_type = "TEXTURE"
    shading.show_shadows = True
    shading.show_cavity = True
    shading.cavity_type = "BOTH"
    shading.background_type = "VIEWPORT"
    shading.background_color = (0.20, 0.21, 0.23)
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    return camera


# ---------------------------------------------------------------- helpers

def _look_at(camera, target, location):
    camera.location = location
    direction = Vector(target) - Vector(location)
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def _hide_others(visible):
    states = {}
    for obj in bpy.data.objects:
        states[obj.name] = obj.hide_render
        obj.hide_render = True
    for obj in bpy.data.objects:
        if obj.name.startswith(TEMP_PREFIX) and obj.type in {"MESH", "LIGHT"}:
            obj.hide_render = False
    for name in visible:
        obj = bpy.data.objects.get(name)
        if obj is not None:
            obj.hide_render = False
    return states


def _restore_hidden(states):
    for name, value in states.items():
        obj = bpy.data.objects.get(name)
        if obj is not None:
            obj.hide_render = value


def _world_bbox(objects):
    low = Vector((1e18, 1e18, 1e18))
    high = Vector((-1e18, -1e18, -1e18))
    for obj in objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            point = obj.matrix_world @ Vector(corner)
            for axis in range(3):
                low[axis] = min(low[axis], point[axis])
                high[axis] = max(high[axis], point[axis])
    return low, high


def _frame(camera, low, high, view, resolution=(1024, 640), fill=0.82):
    """Frame the bbox tightly using the actual camera FOV (two refinement passes)."""
    center = (low + high) * 0.5
    size = high - low
    direction = Vector(VIEW_DIRS[view]).normalized()
    distance = max(size.length * 1.25, 2.0)
    tan_h = 18.0 / camera.data.lens
    tan_v = tan_h * (resolution[1] / float(resolution[0]))
    corners = []
    for x in (low.x, high.x):
        for y in (low.y, high.y):
            for z in (low.z, high.z):
                corners.append(Vector((x, y, z)))
    for _pass in range(3):
        location = center + direction * distance
        _look_at(camera, center, location)
        bpy.context.view_layer.update()
        inverse = camera.matrix_world.inverted()
        ratio = 0.0
        for corner in corners:
            point = inverse @ corner
            depth = max(0.05, -point.z)
            ratio = max(ratio, abs(point.x) / (depth * tan_h),
                        abs(point.y) / (depth * tan_v))
        if ratio <= 0.0:
            break
        distance = max(distance * (ratio / fill), 1.0)
        distance = min(max(distance, size.length * 0.6), size.length * 40.0 + 20.0)


def _render(path, resolution):
    scene = bpy.context.scene
    scene.render.resolution_x = resolution[0]
    scene.render.resolution_y = resolution[1]
    scene.render.resolution_percentage = 100
    scene.render.filepath = path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.render.render(write_still=True)


def _sources(generator, entry):
    root = bpy.data.objects[entry["root"]]
    objects = [root] if root.type == "MESH" else []
    stack = list(root.children)
    while stack:
        node = stack.pop()
        if node.type == "MESH":
            objects.append(node)
        stack.extend(node.children)
    return root, objects


# ---------------------------------------------------------------- renders

def render_comparisons(assets=None, views=("three_quarter",)):
    generator = _load_generator()
    selected = None if assets is None else set(assets)
    results = []
    for entry in generator.PLAN:
        asset = entry["asset"]
        if selected is not None and asset not in selected:
            continue
        root, lod0_objects = _sources(generator, entry)
        lod1 = bpy.data.objects.get(asset + "_LOD1")
        if lod0_objects is None or lod1 is None:
            results.append((asset, "missing"))
            continue
        lod0_low, lod0_high = _world_bbox(lod0_objects)
        camera = _make_stage(lod0_low.z)
        visible = [obj.name for obj in lod0_objects] + [lod1.name]
        hidden = _hide_others(visible)
        saved_location = lod1.location.copy()
        try:
            root_location = root.matrix_world.translation
            lod1.location = (root_location.x + (lod0_high.x - lod0_low.x) + 2.0,
                             root_location.y, root_location.z)
            bpy.context.view_layer.update()
            lod1_low, lod1_high = _world_bbox([lod1])
            low = Vector((min(lod0_low.x, lod1_low.x), min(lod0_low.y, lod1_low.y),
                          min(lod0_low.z, lod1_low.z)))
            high = Vector((max(lod0_high.x, lod1_high.x), max(lod0_high.y, lod1_high.y),
                           max(lod0_high.z, lod1_high.z)))
            for view in views:
                _frame(camera, low, high, view, resolution=(1024, 640))
                name = "%s_LOD0_vs_LOD1_%s_1024x640.png" % (asset, view)
                _render(os.path.join(DOCS_DIR, name), (1024, 640))
                _render(os.path.join(LOCAL_DIR, name), (1024, 640))
                results.append((asset, view))
        finally:
            lod1.location = saved_location
            _restore_hidden(hidden)
            _clean_temps()
    bpy.context.view_layer.update()
    return results


def render_lineups(categories=None):
    generator = _load_generator()
    selected = None if categories is None else set(categories)
    results = []
    by_category = {}
    for entry in generator.PLAN:
        by_category.setdefault(entry["category"], []).append(entry["asset"])
    for category, assets in by_category.items():
        if selected is not None and category not in selected:
            continue
        objects = [bpy.data.objects.get(asset + "_LOD1") for asset in assets]
        objects = [obj for obj in objects if obj is not None]
        saved_locations = {obj.name: obj.location.copy() for obj in objects}
        hidden = _hide_others([])
        try:
            if not objects:
                continue
            cursor = 0.0
            gap = 1.2
            for obj in objects:
                width = max(float(obj.dimensions.x), 0.4)
                obj.location = (cursor + width * 0.5, 780.0, 0.0)
                cursor += width + gap
            bpy.context.view_layer.update()
            low, high = _world_bbox(objects)
            camera = _make_stage(low.z)
            hidden = _hide_others([obj.name for obj in objects])
            center = (low + high) * 0.5
            size = high - low
            camera.data.type = "ORTHO"
            camera.data.ortho_scale = max(size.x + 4.0, (size.z + 2.0) * 1440.0 / 620.0)
            _look_at(camera, center, center + Vector((0.0, -1.0, 0.30)).normalized()
                     * (max(size.x, size.z) * 2.2 + 10.0))
            name = "LOD1_lineup_%s_1440x620.png" % category
            _render(os.path.join(DOCS_DIR, name), (1440, 620))
            _render(os.path.join(LOCAL_DIR, name), (1440, 620))
            results.append((category, name))
        finally:
            _restore_hidden(hidden)
            for obj in objects:
                obj.location = saved_locations[obj.name]
            _clean_temps()
    bpy.context.view_layer.update()
    return results


def main():
    try:
        comparisons = render_comparisons()
        lineups = render_lineups()
        print("LOD1_PREVIEW_DONE %r" % {
            "comparisons": len(comparisons), "lineups": len(lineups),
            "docs_dir": os.path.relpath(DOCS_DIR, REPO_ROOT),
        })
    finally:
        _clean_temps()
        _restore_stage_state()


if __name__ == "__main__":
    main()
