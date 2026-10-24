# -*- coding: utf-8 -*-
# @static-doc
# 作用：`SN_Grand_Harbour_Terminal` 大型航站楼的 EEVEE 预览渲染（Lead 人工验收用截图，
# 不进游戏、不保存 .blend）。
#
# 在现有工作台里临时搭一个港口预览舞台：
# - 只显示集合 `SN_GHT_Grand_Harbour_Terminal_Prototype`，其余 mesh 临时 hide_render；
# - EEVEE Next（引擎不存在时回退 BLENDER_EEVEE）、采样 32，AgX 视图变换；
# - 临时世界：地平线雾蓝 → 天顶深蓝的程序化渐变天空；
# - 临时水面：z≈0 的大平面，深青绿色、低粗糙度、Noise→Bump 轻微波纹；
# - 太阳主光 + 面积补光；相机按集合 bbox 自动取景（目标中心不硬编码世界坐标）。
#
# 4 个镜头（输出到 `.design/architecture/preview/` 与
# `docs/design/screenshots/architecture/`，两处同名 `grand_terminal_*.png`）：
#   grand_terminal_three_quarter.png   约 +X/-Y 45°、略高的 3/4 全景   1600x900
#   grand_terminal_front.png           +X 正立面（略仰）               1600x900
#   grand_terminal_aerial.png          高角度俯视                      1600x900
#   grand_terminal_entrance_detail.png 中央拱门近景                    1400x900
#
# 渲染完成后逐项恢复 hide_render / 集合可见性 / 渲染设置 / 世界 / 视图变换，
# 删除全部临时对象与数据块；**不保存 .blend、不导出 GLB**。
#
# 用法（已连 Blender 的会话，先执行生成器 build_all()）：
#     import runpy; runpy.run_path(<本文件>, run_name="__main__")
# @end-static-doc

import math
import os
import shutil

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
LOCAL_DIR = os.path.join(WORKDIR, ".design", "architecture", "preview")
DOCS_DIR = os.path.join(WORKDIR, "docs", "design", "screenshots",
                        "architecture")

COLLECTION = "SN_GHT_Grand_Harbour_Terminal_Prototype"
ASSET = "SN_Grand_Harbour_Terminal"
SHOT_SLUG = "grand_terminal"     # 交付截图命名：grand_terminal_<view>.png
TEMP_PREFIX = "SN_GHT_PREVIEW_"
GEOMETRY_TYPES = frozenset({"MESH", "CURVE", "FONT", "SURFACE", "META"})

WATER_Z = -0.02        # 略低于资产地面，避免与码头/铺装面 z-fighting
WATER_TEAL = (0.006, 0.034, 0.035)
SUN_ENERGY = 5.8
FILL_IRRADIANCE = 0.07
EEVEE_SAMPLES = 48
VIEW_TRANSFORM = "AgX"
VIEW_LOOK = "AgX - Medium High Contrast"
EXPOSURE = -0.35
LENS = 50.0


# ---------------------------------------------------------------- 状态保存 / 恢复

def _capture_state():
    scene = bpy.context.scene
    state = {
        "engine": scene.render.engine,
        "camera": scene.camera,
        "resolution": (scene.render.resolution_x,
                       scene.render.resolution_y,
                       scene.render.resolution_percentage),
        "filepath": scene.render.filepath,
        "film_transparent": scene.render.film_transparent,
        "image_settings": (scene.render.image_settings.file_format,
                           scene.render.image_settings.color_mode),
        "world": scene.world,
        "view": (scene.view_settings.view_transform,
                 scene.view_settings.look,
                 scene.view_settings.exposure),
        "hide_render": {ob.name: ob.hide_render for ob in bpy.data.objects},
        "collection_hide_render": {col.name: col.hide_render
                                   for col in bpy.data.collections},
        "eevee": {},
    }
    eevee = getattr(scene, "eevee", None)
    if eevee is not None:
        for attr in ("taa_render_samples", "use_raytracing", "use_ssr",
                     "use_shadows", "use_gtao"):
            if hasattr(eevee, attr):
                state["eevee"][attr] = getattr(eevee, attr)
    return state


def _restore_state(state):
    if not state:
        return
    scene = bpy.context.scene
    for name, value in state["hide_render"].items():
        ob = bpy.data.objects.get(name)
        if ob is not None:
            ob.hide_render = value
    for name, value in state["collection_hide_render"].items():
        collection = bpy.data.collections.get(name)
        if collection is not None:
            collection.hide_render = value
    scene.render.engine = state["engine"]
    scene.camera = state["camera"]
    (scene.render.resolution_x, scene.render.resolution_y,
     scene.render.resolution_percentage) = state["resolution"]
    scene.render.filepath = state["filepath"]
    scene.render.film_transparent = state["film_transparent"]
    (scene.render.image_settings.file_format,
     scene.render.image_settings.color_mode) = state["image_settings"]
    scene.world = state["world"]
    view_transform, look, exposure = state["view"]
    scene.view_settings.view_transform = view_transform
    scene.view_settings.look = look
    scene.view_settings.exposure = exposure
    eevee = getattr(scene, "eevee", None)
    if eevee is not None:
        for attr, value in state["eevee"].items():
            setattr(eevee, attr, value)


def _clean_temps():
    """删除全部临时对象与数据块（名称统一带 TEMP_PREFIX）。"""
    for ob in list(bpy.data.objects):
        if ob.name.startswith(TEMP_PREFIX):
            bpy.data.objects.remove(ob, do_unlink=True)
    for blocks in (bpy.data.meshes, bpy.data.materials, bpy.data.lights,
                   bpy.data.cameras, bpy.data.worlds):
        for block in list(blocks):
            if block.name.startswith(TEMP_PREFIX):
                blocks.remove(block)


# ---------------------------------------------------------------- 目标集合

def _target_objects():
    collection = bpy.data.collections.get(COLLECTION)
    if collection is None:
        raise RuntimeError("找不到集合 %s：先执行生成器 build_all()"
                           % COLLECTION)
    collection.hide_render = False
    objects = [ob for ob in collection.all_objects
               if ob.type in GEOMETRY_TYPES]
    if not objects:
        raise RuntimeError("集合 %s 内没有几何对象" % COLLECTION)
    return collection, objects


def _hide_others(keep_names):
    """所有非目标 mesh 临时 hide_render=True；灯光 / 相机不受影响。"""
    for ob in bpy.data.objects:
        if ob.type in GEOMETRY_TYPES:
            ob.hide_render = ob.name not in keep_names
        else:
            ob.hide_render = False


def _world_points(objects):
    points = []
    for ob in objects:
        for corner in ob.bound_box:
            points.append(ob.matrix_world @ Vector(corner))
    return points


def _bounds(points):
    mn = Vector((min(p.x for p in points), min(p.y for p in points),
                 min(p.z for p in points)))
    mx = Vector((max(p.x for p in points), max(p.y for p in points),
                 max(p.z for p in points)))
    return mn, mx


def _box_points(center, half):
    points = []
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            for sz in (-1.0, 1.0):
                points.append(center + Vector((sx * half[0], sy * half[1],
                                               sz * half[2])))
    return points


# ---------------------------------------------------------------- 舞台

def _set_input(node, names, value):
    for name in names:
        socket = node.inputs.get(name)
        if socket is not None:
            socket.default_value = value
            return True
    return False


def _make_material(name, color, roughness=0.5, metallic=0.0):
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = (*color, 1.0)
    material.roughness = roughness
    material.metallic = metallic
    return material


def _make_water(center):
    """临时水面：z≈0 大平面，深青绿、低粗糙度、Noise→Bump 轻微波纹。"""
    mesh = bpy.data.meshes.new(TEMP_PREFIX + "WaterMesh")
    half = 6000.0
    cx, cy = center.x, center.y
    mesh.from_pydata(
        [(cx - half, cy - half, WATER_Z), (cx + half, cy - half, WATER_Z),
         (cx + half, cy + half, WATER_Z), (cx - half, cy + half, WATER_Z)],
        [], [(0, 1, 2, 3)])
    mesh.update()
    material = _make_material(TEMP_PREFIX + "WaterMat", WATER_TEAL,
                              roughness=0.10, metallic=0.0)
    tree = material.node_tree
    tree.nodes.clear()
    output = tree.nodes.new("ShaderNodeOutputMaterial")
    bsdf = tree.nodes.new("ShaderNodeBsdfPrincipled")
    coord = tree.nodes.new("ShaderNodeTexCoord")
    noise = tree.nodes.new("ShaderNodeTexNoise")
    bump = tree.nodes.new("ShaderNodeBump")
    output.location = (520.0, 0.0)
    bsdf.location = (260.0, 0.0)
    bump.location = (40.0, -260.0)
    noise.location = (-220.0, -260.0)
    coord.location = (-440.0, -260.0)
    _set_input(bsdf, ("Base Color",), (*WATER_TEAL, 1.0))
    _set_input(bsdf, ("Roughness",), 0.065)
    _set_input(bsdf, ("Metallic",), 0.0)
    _set_input(bsdf, ("IOR",), 1.33)
    _set_input(noise, ("Scale",), 0.09)
    _set_input(noise, ("Detail",), 4.0)
    _set_input(noise, ("Roughness",), 0.55)
    _set_input(noise, ("Distortion",), 0.25)
    _set_input(bump, ("Strength",), 0.18)
    _set_input(bump, ("Distance",), 0.60)
    tree.links.new(coord.outputs["Object"], noise.inputs["Vector"])
    tree.links.new(noise.outputs["Fac"], bump.inputs["Height"])
    tree.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    tree.links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    mesh.materials.append(material)
    water = bpy.data.objects.new(TEMP_PREFIX + "Water", mesh)
    bpy.context.scene.collection.objects.link(water)
    water.hide_render = False
    return water


def _make_sky_world():
    """临时世界：地平线雾蓝 → 天顶深蓝的程序化渐变。"""
    world = bpy.data.worlds.new(TEMP_PREFIX + "SkyWorld")
    world.use_nodes = True
    tree = world.node_tree
    tree.nodes.clear()
    output = tree.nodes.new("ShaderNodeOutputWorld")
    background = tree.nodes.new("ShaderNodeBackground")
    coord = tree.nodes.new("ShaderNodeTexCoord")
    separate = tree.nodes.new("ShaderNodeSeparateXYZ")
    remap = tree.nodes.new("ShaderNodeMapRange")
    ramp = tree.nodes.new("ShaderNodeValToRGB")
    output.location = (620.0, 0.0)
    background.location = (400.0, 0.0)
    ramp.location = (120.0, 0.0)
    remap.location = (-80.0, 120.0)
    separate.location = (-280.0, 120.0)
    coord.location = (-480.0, 120.0)
    _set_input(remap, ("From Min",), -1.0)
    _set_input(remap, ("From Max",), 1.0)
    _set_input(remap, ("To Min",), 0.0)
    _set_input(remap, ("To Max",), 1.0)
    elements = ramp.color_ramp.elements
    elements[0].position = 0.0
    elements[0].color = (0.008, 0.020, 0.025, 1.0)     # 地平线以下
    elements[1].position = 0.58
    elements[1].color = (0.135, 0.195, 0.225, 1.0)     # 地平线雾
    zenith = elements.new(0.90)
    zenith.color = (0.012, 0.038, 0.085, 1.0)          # 天顶
    _set_input(background, ("Strength",), 0.62)
    tree.links.new(coord.outputs["Generated"], separate.inputs["Vector"])
    tree.links.new(separate.outputs["Z"], remap.inputs["Value"])
    tree.links.new(remap.outputs["Result"], ramp.inputs["Fac"])
    tree.links.new(ramp.outputs["Color"], background.inputs["Color"])
    tree.links.new(background.outputs["Background"], output.inputs["Surface"])
    bpy.context.scene.world = world
    return world


def _aim(ob, target):
    direction = Vector(target) - ob.location
    ob.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def _make_lights(center, max_dim):
    sun_data = bpy.data.lights.new(TEMP_PREFIX + "SunData", type="SUN")
    sun_data.energy = SUN_ENERGY
    sun_data.angle = math.radians(4.0)
    sun_data.color = (1.0, 0.95, 0.86)
    sun = bpy.data.objects.new(TEMP_PREFIX + "Sun", sun_data)
    sun.location = center + Vector((1.0, -0.75, 1.25)).normalized() * max_dim * 2.0
    _aim(sun, center)
    bpy.context.scene.collection.objects.link(sun)

    fill_data = bpy.data.lights.new(TEMP_PREFIX + "FillData", type="AREA")
    fill_data.color = (0.72, 0.82, 1.0)
    fill_data.size = max(20.0, max_dim * 0.90)
    fill_data.shape = "RECTANGLE"
    fill_data.size_y = max(20.0, max_dim * 0.60)
    distance = max_dim * 1.20
    # 面积光能量（W）≈ 目标辐照度 × 4πd²，保证 130 m 级别资产仍能被补到。
    fill_data.energy = FILL_IRRADIANCE * 4.0 * math.pi * distance * distance
    fill = bpy.data.objects.new(TEMP_PREFIX + "Fill", fill_data)
    fill.location = center + Vector((-0.90, 0.60, 0.55)).normalized() * distance
    _aim(fill, center)
    bpy.context.scene.collection.objects.link(fill)
    return sun, fill


def _make_camera():
    camera_data = bpy.data.cameras.new(TEMP_PREFIX + "CamData")
    camera_data.lens = LENS
    camera_data.sensor_fit = "HORIZONTAL"
    camera_data.sensor_width = 36.0
    camera = bpy.data.objects.new(TEMP_PREFIX + "Camera", camera_data)
    bpy.context.scene.collection.objects.link(camera)
    bpy.context.scene.camera = camera
    return camera


def _apply_render_settings():
    scene = bpy.context.scene
    applied = None
    for name in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            scene.render.engine = name
        except TypeError:
            continue
        if scene.render.engine == name:
            applied = name
            break
    if applied is None:
        raise RuntimeError("当前 Blender 没有可用的 EEVEE 渲染引擎")
    eevee = getattr(scene, "eevee", None)
    if eevee is not None:
        if hasattr(eevee, "taa_render_samples"):
            eevee.taa_render_samples = EEVEE_SAMPLES
        for attr in ("use_raytracing", "use_ssr", "use_shadows", "use_gtao"):
            if hasattr(eevee, attr):
                try:
                    setattr(eevee, attr, True)
                except (TypeError, ValueError):
                    pass
    try:
        scene.view_settings.view_transform = VIEW_TRANSFORM
        scene.view_settings.look = VIEW_LOOK
        scene.view_settings.exposure = EXPOSURE
    except (TypeError, ValueError):
        pass
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.resolution_percentage = 100
    return applied


# ---------------------------------------------------------------- 取景 / 渲染

def _frame_camera(camera, center, points, direction, resolution, lens=LENS,
                  margin=1.05):
    """沿 direction 后退到能容纳 points 的透视机位。"""
    camera.data.type = "PERSP"
    camera.data.lens = lens
    camera.data.sensor_fit = "HORIZONTAL"
    camera.data.sensor_width = 36.0
    res_x, res_y = resolution
    fov_x = 2.0 * math.atan(18.0 / lens)
    fov_y = 2.0 * math.atan((18.0 / (res_x / float(res_y))) / lens)
    tan_x = math.tan(fov_x / 2.0)
    tan_y = math.tan(fov_y / 2.0)

    direction = Vector(direction).normalized()
    forward = -direction
    right = forward.cross(Vector((0.0, 0.0, 1.0)))
    if right.length < 1e-6:            # 垂直俯视的退化情形
        right = Vector((1.0, 0.0, 0.0))
    right.normalize()
    up = right.cross(forward).normalized()

    distance = 0.0
    for point in points:
        offset = point - center
        along = offset.dot(direction)
        horizontal = abs(offset.dot(right))
        vertical = abs(offset.dot(up))
        distance = max(distance, along + max(horizontal / tan_x,
                                             vertical / tan_y))
    distance = max(distance * margin, 1.0)
    eye = center + direction * distance
    camera.location = eye
    camera.rotation_euler = (center - eye).to_track_quat("-Z", "Y").to_euler()
    # 资产 130 m 级、机位 300 m 级：默认 clip_end=100 会把全景裁掉。
    camera.data.clip_start = max(0.1, distance * 0.001)
    camera.data.clip_end = max(1000.0, distance * 6.0)
    return eye, distance


def _shot_specs(objects):
    """4 个镜头：目标中心全部按集合 bbox 自动算（不硬编码世界坐标）。"""
    points = _world_points(objects)
    mn, mx = _bounds(points)
    center = (mn + mx) * 0.5
    size = mx - mn
    max_dim = max(size.x, size.y, size.z, 1.0)
    full = _box_points(center, (size.x * 0.5, size.y * 0.5, size.z * 0.5))

    # 中央拱门近景：门廊位于进深前 1/4 处（广场在更前面），沿 Y 居中、
    # 约 42% 建筑高度；全部从 bbox 推导，不硬编码世界坐标 / 对象名。
    entrance_center = Vector((mn.x + size.x * 0.64, center.y,
                              mn.z + size.z * 0.40))
    entrance_half = (4.0, min(max(size.y * 0.13, 8.0), 18.0),
                     max(size.z * 0.22, 6.0))

    return {
        "center": center,
        "max_dim": max_dim,
        "shots": [
            ("three_quarter", center, full,
             Vector((1.0, -1.0, 0.52)), 50.0, 1.05, (1600, 900)),
            ("front", center, full,
             Vector((1.0, 0.0, 0.12)), 55.0, 1.03, (1600, 900)),
            ("aerial", center, full,
             Vector((0.62, -0.50, 1.50)), 45.0, 1.04, (1600, 900)),
            ("entrance_detail", entrance_center,
             _box_points(entrance_center, entrance_half),
             Vector((1.0, -0.20, 0.10)), 40.0, 1.02, (1400, 900)),
        ],
    }


def _render_to(path, resolution):
    scene = bpy.context.scene
    scene.render.resolution_x = resolution[0]
    scene.render.resolution_y = resolution[1]
    scene.render.resolution_percentage = 100
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def _render_both(name, resolution):
    """渲染一次，写出 .design 与 docs 两处同名副本。"""
    os.makedirs(LOCAL_DIR, exist_ok=True)
    os.makedirs(DOCS_DIR, exist_ok=True)
    local_path = _render_to(os.path.join(LOCAL_DIR, name), resolution)
    docs_path = os.path.join(DOCS_DIR, name)
    shutil.copy2(local_path, docs_path)
    return [local_path, docs_path]


# ---------------------------------------------------------------- 主流程

def render_all():
    state = _capture_state()
    results = []
    try:
        _collection, objects = _target_objects()
        keep = {ob.name for ob in objects}
        _hide_others(keep)
        spec = _shot_specs(objects)
        camera = _make_camera()
        _make_lights(spec["center"], spec["max_dim"])
        _make_sky_world()
        _apply_render_settings()
        _make_water(spec["center"])

        for view, center, points, direction, lens, margin, resolution in \
                spec["shots"]:
            _frame_camera(camera, center, points, direction, resolution,
                          lens=lens, margin=margin)
            name = "%s_%s.png" % (SHOT_SLUG, view)
            paths = _render_both(name, resolution)
            results.append({
                "view": view,
                "resolution": list(resolution),
                "files": [os.path.relpath(p, WORKDIR).replace("\\", "/")
                          for p in paths],
            })
            print("RENDERED %s %dx%d" % (view, resolution[0], resolution[1]))
    finally:
        _restore_state(state)
        _clean_temps()

    print("GHT_PREVIEW_DONE %r" % {
        "asset": ASSET,
        "count": len(results),
        "views": [item["view"] for item in results],
        "local_dir": os.path.relpath(LOCAL_DIR, WORKDIR).replace("\\", "/"),
        "docs_dir": os.path.relpath(DOCS_DIR, WORKDIR).replace("\\", "/"),
    })
    return results


if __name__ == "__main__":
    render_all()
