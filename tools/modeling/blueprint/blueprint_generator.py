# -*- coding: utf-8 -*-
# @static-doc
# 作用：Blender 后台工业蓝图线稿生成内核；只读加载 `.blend` / `.glb`，自动计算模型边界、
# 创建正交侧视/俯视/轴测相机，用 Freestyle 输出透明 PNG，默认按 Alpha 自动裁切后写
# 确定性 `metadata.json`。
#
# ## 契约与约束
# - 原始模型只在内存中打开或导入，脚本不保存 `.blend`、不导出模型、不覆盖输入文件。
# - `simple / normal / detailed` 只逐级增加结构线类型；三角化产生的共面内部边不会被选择。
# - 元数据不写时间戳，路径使用输出目录相对路径；同一模型与配置的相机计算可重复。
# - 直接入口：`blender -b -P blueprint_generator.py -- --input model.glb --output out`。
#
# ## 重点逻辑
# ### `generate(args)`
# 清理默认场景、载入一个模型、把表面替换为透明材质、逐视图渲染并原子写元数据。
# @end-static-doc

import argparse
import hashlib
import json
import math
import os
import sys
import traceback

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from png_alpha_crop import crop_png


GENERATOR_VERSION = "1.0.0"
SUPPORTED_INPUTS = {".blend", ".glb"}
SUPPORTED_VIEWS = ("side", "top", "iso")
AXES = {
    "+X": Vector((1.0, 0.0, 0.0)),
    "-X": Vector((-1.0, 0.0, 0.0)),
    "+Y": Vector((0.0, 1.0, 0.0)),
    "-Y": Vector((0.0, -1.0, 0.0)),
    "+Z": Vector((0.0, 0.0, 1.0)),
    "-Z": Vector((0.0, 0.0, -1.0)),
}
DEFAULT_CONFIG = {
    "resolution": 2048,
    "margin": 1.10,
    "transparent": True,
    "crease_angle_degrees": 35.0,
    "line_color": [0.72, 0.92, 1.0],
    "outline_thickness": 3.2,
    "structure_thickness": 1.65,
    "detail_thickness": 1.0,
    "outline_alpha": 1.0,
    "structure_alpha": 0.82,
    "detail_alpha": 0.48,
    "crop": True,
    "crop_padding": 0.04,
    "crop_alpha_threshold": 8,
}


def _log(level, message, **fields):
    payload = {"level": level, "message": message}
    payload.update(fields)
    print("BLUEPRINT " + json.dumps(payload, ensure_ascii=False, sort_keys=True), flush=True)


def _script_args():
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def _parser():
    parser = argparse.ArgumentParser(description="Render engineering-blueprint line art in Blender.")
    parser.add_argument("--input", required=True, help="Source .blend or .glb file")
    parser.add_argument("--output", required=True, help="Output directory")
    parser.add_argument("--views", default="side,top,iso", help="Comma-separated: side,top,iso")
    parser.add_argument("--detail", choices=("simple", "normal", "detailed"), default="normal")
    parser.add_argument("--resolution", type=int, help="Square PNG resolution in pixels")
    parser.add_argument("--margin", type=float, help="Orthographic framing margin, e.g. 1.10")
    parser.add_argument("--forward-axis", choices=tuple(AXES), default="+X")
    parser.add_argument("--up-axis", choices=tuple(AXES), default="+Z")
    parser.add_argument("--config", help="Optional JSON style config")
    parser.add_argument("--no-crop", action="store_true", help="Keep the original square render canvas")
    parser.add_argument("--crop-padding", type=float, help="Padding as a ratio of content's longer edge")
    parser.add_argument("--crop-alpha-threshold", type=int, help="Content pixels have alpha above this value")
    return parser


def _load_config(args):
    config = dict(DEFAULT_CONFIG)
    if args.config:
        with open(os.path.abspath(args.config), "r", encoding="utf-8") as handle:
            raw = json.load(handle)
        unknown = sorted(set(raw) - set(DEFAULT_CONFIG))
        if unknown:
            raise ValueError("unknown config keys: %s" % ", ".join(unknown))
        config.update(raw)
    if args.resolution is not None:
        config["resolution"] = args.resolution
    if args.margin is not None:
        config["margin"] = args.margin
    if args.no_crop:
        config["crop"] = False
    if args.crop_padding is not None:
        config["crop_padding"] = args.crop_padding
    if args.crop_alpha_threshold is not None:
        config["crop_alpha_threshold"] = args.crop_alpha_threshold
    if not 256 <= int(config["resolution"]) <= 8192:
        raise ValueError("resolution must be between 256 and 8192")
    if not 1.0 <= float(config["margin"]) <= 2.0:
        raise ValueError("margin must be between 1.0 and 2.0")
    if not isinstance(config["crop"], bool):
        raise ValueError("crop must be true or false")
    if not 0.0 <= float(config["crop_padding"]) <= 0.5:
        raise ValueError("crop_padding must be between 0.0 and 0.5")
    if not 0 <= int(config["crop_alpha_threshold"]) <= 254:
        raise ValueError("crop_alpha_threshold must be between 0 and 254")
    color = config["line_color"]
    if not isinstance(color, list) or len(color) != 3 or any(not 0.0 <= float(v) <= 1.0 for v in color):
        raise ValueError("line_color must be three numbers in the range 0..1")
    return config


def _validate_axes(forward_name, up_name):
    forward = AXES[forward_name].copy()
    up = AXES[up_name].copy()
    if abs(forward.dot(up)) > 1.0e-6:
        raise ValueError("forward-axis and up-axis must be perpendicular")
    return forward, up


def _parse_views(value):
    views = []
    for item in value.split(","):
        name = item.strip().lower()
        if not name:
            continue
        if name not in SUPPORTED_VIEWS:
            raise ValueError("unsupported view: %s" % name)
        if name not in views:
            views.append(name)
    if not views:
        raise ValueError("at least one view is required")
    return views


def _clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        if collection.users == 0:
            bpy.data.collections.remove(collection)


def _load_input(path):
    suffix = os.path.splitext(path)[1].lower()
    if suffix not in SUPPORTED_INPUTS:
        raise ValueError("input must be .blend or .glb: %s" % path)
    if suffix == ".blend":
        bpy.ops.wm.open_mainfile(filepath=path, load_ui=False)
    else:
        _clear_scene()
        bpy.ops.import_scene.gltf(filepath=path)
    bpy.context.view_layer.update()


def _mesh_objects():
    result = []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH" or obj.hide_render:
            continue
        if len(obj.data.vertices) == 0:
            continue
        result.append(obj)
    if not result:
        raise ValueError("input contains no renderable mesh objects")
    return sorted(result, key=lambda obj: obj.name)


def _world_bounds(objects):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    points = []
    for obj in objects:
        evaluated = obj.evaluated_get(depsgraph)
        points.extend(evaluated.matrix_world @ Vector(corner) for corner in evaluated.bound_box)
    minimum = Vector(tuple(min(point[index] for point in points) for index in range(3)))
    maximum = Vector(tuple(max(point[index] for point in points) for index in range(3)))
    return minimum, maximum


def _transparent_material(name):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    transparent = nodes.new("ShaderNodeBsdfTransparent")
    material.node_tree.links.new(transparent.outputs[0], output.inputs[0])
    if hasattr(material, "surface_render_method"):
        material.surface_render_method = "DITHERED"
    return material


def _make_surfaces_transparent(objects):
    cache = {}
    processed_meshes = set()
    for obj in objects:
        mesh_key = obj.data.as_pointer()
        if mesh_key in processed_meshes:
            continue
        processed_meshes.add(mesh_key)
        slot_count = len(obj.data.materials)
        original_names = [material.name if material else "Empty" for material in obj.data.materials]
        if not original_names:
            obj.data.materials.append(_transparent_material("BP_Transparent_%03d" % len(cache)))
            continue
        for index in range(slot_count):
            key = original_names[index]
            if key not in cache:
                cache[key] = _transparent_material("BP_Transparent_%03d" % len(cache))
            # Replacing slots in place preserves polygon.material_index, which is
            # required for the detailed preset's material-boundary LineSet.
            obj.data.materials[index] = cache[key]


def _set_if_present(target, name, value):
    if hasattr(target, name):
        setattr(target, name, value)


def _new_lineset(settings, name, color, thickness, alpha, selectors):
    lineset = settings.linesets.new(name)
    lineset.select_by_visibility = True
    lineset.visibility = "VISIBLE"
    lineset.select_by_edge_types = True
    for prop in (
        "select_silhouette", "select_border", "select_contour", "select_external_contour",
        "select_crease", "select_ridge_valley", "select_suggestive_contour",
        "select_material_boundary", "select_edge_mark",
    ):
        _set_if_present(lineset, prop, prop in selectors)
    style = lineset.linestyle
    style.color = tuple(float(v) for v in color)
    style.alpha = float(alpha)
    style.thickness = float(thickness)
    _set_if_present(style, "caps", "ROUND")
    _set_if_present(style, "thickness_position", "CENTER")
    return lineset


def _configure_freestyle(scene, detail, config):
    scene.render.use_freestyle = True
    settings = bpy.context.view_layer.freestyle_settings
    settings.crease_angle = math.radians(float(config["crease_angle_degrees"]))
    while settings.linesets:
        settings.linesets.remove(settings.linesets[0])
    color = config["line_color"]
    _new_lineset(
        settings, "BP_Outline", color, config["outline_thickness"], config["outline_alpha"],
        {"select_silhouette", "select_border", "select_contour", "select_external_contour"},
    )
    if detail in {"normal", "detailed"}:
        _new_lineset(
            settings, "BP_Structure", color, config["structure_thickness"],
            config["structure_alpha"], {"select_crease"},
        )
    if detail == "detailed":
        _new_lineset(
            settings, "BP_Detail", color, config["detail_thickness"], config["detail_alpha"],
            {"select_material_boundary", "select_edge_mark"},
        )


def _configure_scene(scene, config):
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = int(config["resolution"])
    scene.render.resolution_y = int(config["resolution"])
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.film_transparent = bool(config["transparent"])
    scene.render.use_file_extension = True
    scene.render.dither_intensity = 0.0
    scene.render.image_settings.color_mode = "RGBA"
    if hasattr(scene, "eevee"):
        scene.eevee.taa_samples = 1
        scene.eevee.taa_render_samples = 1
        scene.eevee.volumetric_samples = 1
    # Blender 4.4 prefixes AgX looks while older releases expose the short label.
    for look in ("AgX - Medium High Contrast", "Medium High Contrast", "None"):
        try:
            scene.view_settings.look = look
            break
        except TypeError:
            continue


def _view_directions(forward, up):
    side = forward.cross(up).normalized()
    return {
        "side": side,
        "top": up.normalized(),
        "iso": (forward.normalized() + side + up.normalized() * 0.75).normalized(),
    }


def _fit_orthographic_camera(camera, minimum, maximum, direction, resolution, margin):
    center = (minimum + maximum) * 0.5
    diagonal = (maximum - minimum).length
    camera.location = center + direction.normalized() * max(diagonal * 2.0, 10.0)
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.view_layer.update()
    inverse = camera.matrix_world.inverted()
    projected = []
    for x in (minimum.x, maximum.x):
        for y in (minimum.y, maximum.y):
            for z in (minimum.z, maximum.z):
                projected.append(inverse @ Vector((x, y, z)))
    width = max(point.x for point in projected) - min(point.x for point in projected)
    height = max(point.y for point in projected) - min(point.y for point in projected)
    aspect = float(resolution[0]) / float(resolution[1])
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = max(height, width / aspect, 1.0e-4) * float(margin)
    camera.data.lens = 50.0
    camera.data.dof.use_dof = False
    return center


def _round_vector(vector):
    return [round(float(value), 6) for value in vector]


def _sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _atomic_json(path, value):
    temporary = path + ".tmp"
    with open(temporary, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")
    os.replace(temporary, path)


def generate(args):
    source = os.path.abspath(args.input)
    output = os.path.abspath(args.output)
    if not os.path.isfile(source):
        raise FileNotFoundError(source)
    config = _load_config(args)
    views = _parse_views(args.views)
    forward, up = _validate_axes(args.forward_axis, args.up_axis)
    os.makedirs(output, exist_ok=True)
    for name in tuple(view + ".png" for view in SUPPORTED_VIEWS) + ("metadata.json",):
        stale = os.path.join(output, name)
        if os.path.isfile(stale):
            os.remove(stale)
    _log("info", "loading model", input=source)
    _load_input(source)
    objects = _mesh_objects()
    minimum, maximum = _world_bounds(objects)
    dimensions = maximum - minimum
    _make_surfaces_transparent(objects)
    scene = bpy.context.scene
    _configure_scene(scene, config)
    _configure_freestyle(scene, args.detail, config)

    camera_data = bpy.data.cameras.new("BP_Camera")
    camera = bpy.data.objects.new("BP_Camera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    directions = _view_directions(forward, up)
    view_metadata = {}
    for name in views:
        direction = directions[name]
        center = _fit_orthographic_camera(
            camera, minimum, maximum, direction,
            (int(config["resolution"]), int(config["resolution"])), config["margin"],
        )
        path = os.path.join(output, name + ".png")
        scene.render.filepath = path
        _log("info", "rendering view", view=name, output=path)
        bpy.ops.render.render(write_still=True)
        if not os.path.isfile(path) or os.path.getsize(path) == 0:
            raise RuntimeError("Blender did not create %s" % path)
        if config["crop"]:
            crop = crop_png(
                path,
                alpha_threshold=int(config["crop_alpha_threshold"]),
                padding_ratio=float(config["crop_padding"]),
            )
        else:
            crop = {
                "enabled": False,
                "source_size": [int(config["resolution"]), int(config["resolution"])],
                "output_size": [int(config["resolution"]), int(config["resolution"])],
            }
        view_metadata[name] = {
            "camera_direction": _round_vector(direction),
            "camera_location": _round_vector(camera.location),
            "camera_rotation_euler": _round_vector(camera.rotation_euler),
            "look_at": _round_vector(center),
            "orthographic_scale": round(float(camera.data.ortho_scale), 6),
            "render_resolution": [int(config["resolution"]), int(config["resolution"])],
            "resolution": crop["output_size"],
            "crop": crop,
            "output": name + ".png",
        }

    metadata = {
        "schema_version": 1,
        "generator": {"name": "steam-navigator-blueprint", "version": GENERATOR_VERSION},
        "source": {
            "name": os.path.basename(source),
            "extension": os.path.splitext(source)[1].lower(),
            "sha256": _sha256(source),
        },
        "model": {
            "bounds_min": _round_vector(minimum),
            "bounds_max": _round_vector(maximum),
            "center": _round_vector((minimum + maximum) * 0.5),
            "dimensions": _round_vector(dimensions),
            "mesh_object_count": len(objects),
        },
        "orientation": {"forward_axis": args.forward_axis, "up_axis": args.up_axis},
        "style": {"detail": args.detail, **config},
        "views": view_metadata,
    }
    metadata_path = os.path.join(output, "metadata.json")
    _atomic_json(metadata_path, metadata)
    _log("info", "generation complete", metadata=metadata_path, views=views)
    return metadata


def main():
    args = _parser().parse_args(_script_args())
    try:
        generate(args)
    except Exception as error:
        _log("error", str(error), traceback=traceback.format_exc())
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
