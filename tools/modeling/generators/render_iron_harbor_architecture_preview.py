# -*- coding: utf-8 -*-
"""Steam Navigator — 铁港建筑套件样板预览渲染（Lead 验收截图，非游戏资产）。

只对 SN_Iron_Harbor_Architecture 集合里的 LOD0 对象出图：
    固定 PortStage 机位 / 街道低机位 / 正视 / 屋顶 / 960x540 可读性复查 / 材质近景 ×2

渲染时临时隐藏其它 mesh 对象（含 SN_Harbor_Town 里的旧占位资产），
渲染结束后逐项还原相机 / 引擎 / 分辨率 / 世界背景 / 可见性，不保存 .blend。

输出（docs/design/screenshots/iron_harbor_architecture/）：
    SN_HT_Warehouse_Long_LOD0_port_stage_fixed_1440x900.png   ← 固定 PortStage 机位（忠实画面）
    SN_HT_Warehouse_Long_LOD0_port_stage_fixed_960x540.png    ← 16:9 keep_height 复查
    SN_HT_Warehouse_Long_LOD0_port_stage_centred_1440x900.png ← 同机位方向、建筑居中
    SN_HT_Warehouse_Long_LOD0_street_low_1440x900.png          ← 街道低机位（1.7 m 眼高）
    SN_HT_Warehouse_Long_LOD0_front_1440x900.png               ← 正交正视（+Y 主立面）
    SN_HT_Warehouse_Long_LOD0_roof_1440x900.png                ← 屋顶视图
    SN_HT_Warehouse_Long_LOD0_detail_door_1440x900.png         ← 材质近景：装卸门一带
    SN_HT_Warehouse_Long_LOD0_detail_base_1440x900.png         ← 材质近景：墙脚 / 转角

用法（Blender 内）：
    p = r"<abs path>/render_iron_harbor_architecture_preview.py"
    import runpy; runpy.run_path(p, run_name="__main__")
"""

import math
import os

import bpy
from mathutils import Vector

WORKDIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))
OUT_DIR = os.path.join(WORKDIR, "docs", "design", "screenshots",
                       "iron_harbor_architecture")

TARGET = "SN_HT_Warehouse_Long_LOD0"

# ---- PortStage 固定机位（由 framework/ui/stages/port_stage.gd 换算） ----
# Godot：eye (46,28,64) / look_at (0,12,-8) / vfov 30° / keep_height / 1440x900；
#        town 槽位 pos (-30, 1.9, -33)、yaw -106°、scale 1 → 工作台等价机位：
#        Blender 眼点 (24.30, 209.79, 26.1)、目标 (-32.24, 145.73, 10.1)。
# 换算：godot_local = R_yaw^-1 (p - slot_pos)，blender = (-48,110,0) + (gx, -gz, gy)；
#        yaw -90° 时还原为 (50, 186, 26.1) / (-22, 140, 10.1)。
# 该机位看到的是资产本地 +Y 主立面（装卸门）与 +X 山墙（吊梁）；-Y 立面在机位背面。
FAITHFUL_EYE = Vector((24.30, 209.79, 26.1))
FAITHFUL_TARGET = Vector((-32.24, 145.73, 10.1))
LENS_16_10 = 41.9856     # 1440x900，垂直 FOV 30°
LENS_16_9 = 37.7870      # 960x540，垂直 FOV 仍 30°（KEEP_HEIGHT，横向展开）

# ---- 材质近景（只用于判读 trim sheet 的贴图尺度/接缝，不是验收机位） ----
DETAIL_DOOR = {
    # 双装卸门 + 人门 + 气窗：砖墙 / 铁门 / 石门槛 / 玻璃 / 木门一次看全
    "eye": Vector((-42.0, 124.5, 4.20)),
    "target": Vector((-42.6, 114.2, 4.60)),
    "lens": 42.0,
}
DETAIL_BASE = {
    # 墙脚转角的石基 + 砖墙 + 落水管 + 檐沟收口
    "eye": Vector((-33.6, 122.6, 2.40)),
    "target": Vector((-39.2, 114.2, 3.10)),
    "lens": 38.0,
}

STREET_LOW = {
    # 街面人眼高度 1.7 m，从主立面 (+Y) 一侧斜看
    "eye": Vector((-34.0, 130.0, 1.70)),
    "target": Vector((-48.0, 110.0, 5.00)),
    "lens": 30.0,
}

FRONT_ORTHO = {
    "center": Vector((-48.0, 110.0, 5.50)),
    "eye": Vector((-48.0, 152.0, 5.50)),   # 沿 -Y 看 +Y 主立面
    "ortho_scale": 23.0,
}

ROOF = {
    "direction": Vector((0.18, 0.34, 1.0)),
    "lens": 52.0,
    "margin": 1.12,
}


def _world_points(obj):
    return [obj.matrix_world @ Vector(c) for c in obj.bound_box]


def _bounds(objs):
    pts = []
    for ob in objs:
        pts.extend(_world_points(ob))
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx


def _place_fit_camera(cam, objs, direction, res_x, res_y, lens, margin=1.06):
    """按目标包围盒自动取景的透视机位（沿 direction 方向后退）。"""
    bpy.context.view_layer.update()
    mn, mx = _bounds(objs)
    center = (mn + mx) / 2.0
    cam.data.type = "PERSP"
    cam.data.lens = lens
    cam.data.sensor_fit = "HORIZONTAL"
    cam.data.sensor_width = 36.0
    fov_x = 2.0 * math.atan(18.0 / lens)
    fov_y = 2.0 * math.atan((18.0 / (res_x / float(res_y))) / lens)
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
            distance = max(distance, a + max(x / tan_x, y / tan_y))
    distance = max(distance * margin, 1.0)

    eye = center + dirv * distance
    cam.location = eye
    cam.rotation_euler = (center - eye).to_track_quat("-Z", "Y").to_euler()
    return center, distance


def _place_eye_camera(cam, eye, target, lens):
    cam.data.type = "PERSP"
    cam.data.lens = lens
    cam.data.sensor_fit = "HORIZONTAL"
    cam.data.sensor_width = 36.0
    cam.location = eye
    cam.rotation_euler = (target - eye).to_track_quat("-Z", "Y").to_euler()


def _place_ortho_camera(cam, eye, center, ortho_scale):
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho_scale
    cam.location = eye
    cam.rotation_euler = (center - eye).to_track_quat("-Z", "Y").to_euler()


def _hide_others(keep):
    states = {}
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            states[ob.name] = ob.hide_render
            ob.hide_render = ob.name not in keep
    return states


def _restore_visibility(states):
    for name, value in states.items():
        ob = bpy.data.objects.get(name)
        if ob is not None:
            ob.hide_render = value


def _make_temp_scene():
    """临时相机 / 灯光 / 地面 / 世界背景。返回还原回调需要的句柄。"""
    scene = bpy.context.scene
    saved = {
        "engine": scene.render.engine,
        "camera": scene.camera,
        "res_x": scene.render.resolution_x,
        "res_y": scene.render.resolution_y,
        "res_pct": scene.render.resolution_percentage,
        "filepath": scene.render.filepath,
        "film_transparent": scene.render.film_transparent,
        "image_settings": (scene.render.image_settings.file_format,
                           scene.render.image_settings.color_mode),
        "samples": (getattr(scene.eevee, "taa_render_samples", None)
                    if hasattr(scene, "eevee") else None),
    }

    cam_data = bpy.data.cameras.new("TMP_KIT_PREVIEW_CAM")
    cam = bpy.data.objects.new("TMP_KIT_PREVIEW_CAM", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam

    lights = []
    # 主光从固定机位同一侧（本地 +X/+Y/+Z）打过来，保证机位可见的 +Y 主立面与 +X 山墙同时受光
    for name, energy, rot, color in (
        ("TMP_KIT_SUN_KEY", 2.60, (math.radians(48), 0.0, math.radians(128)),
         (1.0, 0.96, 0.90)),
        ("TMP_KIT_SUN_FILL", 0.55, (math.radians(62), 0.0, math.radians(8)),
         (0.80, 0.87, 1.0)),
        ("TMP_KIT_SUN_RIM", 0.90, (math.radians(18), 0.0, math.radians(210)),
         (0.92, 0.94, 1.0)),
    ):
        data = bpy.data.lights.new(name, "SUN")
        data.energy = energy
        data.angle = math.radians(6.0)
        data.color = color
        ob = bpy.data.objects.new(name, data)
        ob.rotation_euler = rot
        scene.collection.objects.link(ob)
        lights.append(ob)

    ground_mesh = bpy.data.meshes.new("TMP_KIT_GROUND_mesh")
    ground_mesh.from_pydata(
        [(-400.0, -400.0, 0.0), (400.0, -400.0, 0.0),
         (400.0, 400.0, 0.0), (-400.0, 400.0, 0.0)], [],
        [[0, 1, 2, 3]])
    ground_mesh.update()
    gm = bpy.data.materials.new("TMP_KIT_GROUND_MAT")
    gm.use_nodes = True
    gbsdf = next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    gbsdf.inputs["Base Color"].default_value = (0.055, 0.060, 0.068, 1.0)
    gbsdf.inputs["Roughness"].default_value = 0.95
    ground_mesh.materials.append(gm)
    ground = bpy.data.objects.new("TMP_KIT_GROUND", ground_mesh)
    scene.collection.objects.link(ground)

    world = scene.world
    world_created = False
    if world is None:
        world = bpy.data.worlds.new("TMP_KIT_PREVIEW_WORLD")
        scene.world = world
        world_created = True
    if not world.use_nodes:
        world.use_nodes = True
    bg = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"), None)
    saved_bg = None
    if bg is not None:
        saved_bg = tuple(bg.inputs["Color"].default_value)
        bg.inputs["Color"].default_value = (0.040, 0.045, 0.055, 1.0)
        bg.inputs["Strength"].default_value = 0.35

    scene.render.engine = "BLENDER_EEVEE_NEXT"
    if hasattr(scene, "eevee"):
        scene.eevee.taa_render_samples = 64
        if hasattr(scene.eevee, "use_raytracing"):
            scene.eevee.use_raytracing = True
    try:
        scene.view_settings.view_transform = "AgX"
        scene.view_settings.look = "AgX - Base Contrast"
        scene.view_settings.exposure = 0.30
    except (TypeError, ValueError):
        pass
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"

    return {
        "saved": saved, "cam": cam, "cam_data": cam_data, "lights": lights,
        "ground": ground, "ground_mesh": ground_mesh, "ground_mat": gm,
        "world": world, "world_created": world_created, "bg": bg, "saved_bg": saved_bg,
    }


def _teardown(temp):
    scene = bpy.context.scene
    saved = temp["saved"]
    for ob in temp["lights"]:
        data = ob.data
        bpy.data.objects.remove(ob, do_unlink=True)
        bpy.data.lights.remove(data)
    bpy.data.objects.remove(temp["ground"], do_unlink=True)
    bpy.data.meshes.remove(temp["ground_mesh"])
    bpy.data.materials.remove(temp["ground_mat"])
    bpy.data.objects.remove(temp["cam"], do_unlink=True)
    bpy.data.cameras.remove(temp["cam_data"])
    if temp["world_created"]:
        pass
    if temp["bg"] is not None and temp["saved_bg"] is not None:
        temp["bg"].inputs["Color"].default_value = temp["saved_bg"]
        temp["bg"].inputs["Strength"].default_value = 1.0
    scene.camera = saved["camera"]
    scene.render.engine = saved["engine"]
    scene.render.resolution_x = saved["res_x"]
    scene.render.resolution_y = saved["res_y"]
    scene.render.resolution_percentage = saved["res_pct"]
    scene.render.filepath = saved["filepath"]
    scene.render.film_transparent = saved["film_transparent"]
    fmt, mode = saved["image_settings"]
    scene.render.image_settings.file_format = fmt
    scene.render.image_settings.color_mode = mode
    if saved["samples"] is not None and hasattr(scene, "eevee"):
        scene.eevee.taa_render_samples = saved["samples"]


def _render(path, res):
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.resolution_percentage = 100
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def render_all():
    scene = bpy.context.scene
    os.makedirs(OUT_DIR, exist_ok=True)
    obj = bpy.data.objects.get(TARGET)
    if obj is None:
        raise RuntimeError("找不到 %s，先运行 generator 的 build_all()" % TARGET)

    temp = _make_temp_scene()
    vis = _hide_others({TARGET})
    results = []
    try:
        cam = temp["cam"]
        tag = TARGET
        # 1) 固定 PortStage 机位（忠实画面：建筑落在 stage 里的实际屏幕位置）
        _place_eye_camera(cam, FAITHFUL_EYE, FAITHFUL_TARGET, LENS_16_10)
        results.append(_render(os.path.join(
            OUT_DIR, "%s_port_stage_fixed_1440x900.png" % tag), (1440, 900)))
        # 2) 固定 PortStage 机位（960x540，16:9 KEEP_HEIGHT 检查）
        _place_eye_camera(cam, FAITHFUL_EYE, FAITHFUL_TARGET, LENS_16_9)
        results.append(_render(os.path.join(
            OUT_DIR, "%s_port_stage_fixed_960x540.png" % tag), (960, 540)))
        # 3) 同机位同视角方向、但把建筑摆到画面中心的细节复查图
        view_dir = (FAITHFUL_TARGET - FAITHFUL_EYE).normalized()
        center = Vector((-48.0, 110.0, 5.5))
        dist = (center - FAITHFUL_EYE).length
        _place_eye_camera(cam, center - view_dir * dist, center, LENS_16_10)
        results.append(_render(os.path.join(
            OUT_DIR, "%s_port_stage_centred_1440x900.png" % tag), (1440, 900)))
        # 4) 街道低机位
        _place_eye_camera(cam, STREET_LOW["eye"], STREET_LOW["target"],
                          STREET_LOW["lens"])
        results.append(_render(os.path.join(
            OUT_DIR, "%s_street_low_1440x900.png" % tag), (1440, 900)))
        # 5) 正交正视（+Y 主立面）
        _place_ortho_camera(cam, FRONT_ORTHO["eye"], FRONT_ORTHO["center"],
                            FRONT_ORTHO["ortho_scale"])
        results.append(_render(os.path.join(
            OUT_DIR, "%s_front_1440x900.png" % tag), (1440, 900)))
        # 6) 屋顶视图
        _place_fit_camera(cam, [obj], ROOF["direction"], 1440, 900,
                          ROOF["lens"], ROOF["margin"])
        results.append(_render(os.path.join(
            OUT_DIR, "%s_roof_1440x900.png" % tag), (1440, 900)))
        # 7) 材质近景：装卸门 / 砖墙 / 铁件 / 石基 / 木门 / 玻璃
        _place_eye_camera(cam, DETAIL_DOOR["eye"], DETAIL_DOOR["target"],
                          DETAIL_DOOR["lens"])
        results.append(_render(os.path.join(
            OUT_DIR, "%s_detail_door_1440x900.png" % tag), (1440, 900)))
        # 8) 材质近景：墙脚石基 / 砖墙转角 / 落水管 / 檐沟
        _place_eye_camera(cam, DETAIL_BASE["eye"], DETAIL_BASE["target"],
                          DETAIL_BASE["lens"])
        results.append(_render(os.path.join(
            OUT_DIR, "%s_detail_base_1440x900.png" % tag), (1440, 900)))
    finally:
        _restore_visibility(vis)
        _teardown(temp)

    print("KIT_PREVIEW_DONE " + repr({"count": len(results), "dir": OUT_DIR,
                                      "files": [os.path.basename(p) for p in results]}))
    return results


if __name__ == "__main__":
    render_all()
