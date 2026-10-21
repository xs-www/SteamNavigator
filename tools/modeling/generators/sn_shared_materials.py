# -*- coding: utf-8 -*-
# @static-doc
# 作用：共享贴图材质库（材质名 ↔ 贴图 / tile_m / PBR 参数），以及 Blender 侧的材质绑定、
# 世界空间盒式 UV 投影与验收；纯 Python 数据可在 Blender 外读取。
#
# 真源：`docs/design/textures/shared_materials/shared_materials.spec.json`
# （由 `tools/art/gen_shared_material_textures.py` 生产 512² 无缝贴图）。
# 模型生成器只按材质名引用；贴图作为外部共享资源 `shared_materials/<texture>.png`
# 随 core 模组发布，多件资产在 Godot 里共享同一个 `Texture2D`。
#
# 约定：
# - 1 unit = 1 m；每个材质有 `tile_m`（一张贴图覆盖多少米），UV 用世界坐标 / tile_m，
#   采样器 REPEAT，因此任意大面都连续平铺、没有接缝。
# - UV 投影按面法线主轴的盒式投影：X 面用 (Y,Z)、Y 面用 (X,Z)、Z 面用 (X,Y)。
# - Blender 材质节点：Image Texture(sRGB, Linear, REPEAT) → Principled Base Color；
#   Roughness / Metallic 来自 spec；背面剔除关闭（低模薄板双面）。
# - bpy 只在函数内部 import；纯数据段可被 dryrun / 工具直接加载。
#
# 用法（Blender MCP / runpy）：
#   import sn_shared_materials as sm
#   sm.build_materials()
#   report = sm.apply_collection(bpy.data.collections["SN_Mega_Gantry_Prototype"])
# @end-static-doc

import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SPEC_PATH = os.path.join(REPO_ROOT, "docs", "design", "textures", "shared_materials",
                         "shared_materials.spec.json")
UV_LAYER = "UVMap"

_SPEC = None


def load_spec():
    global _SPEC
    if _SPEC is None:
        with open(SPEC_PATH, "r", encoding="utf-8") as handle:
            _SPEC = json.load(handle)
    return _SPEC


def material_specs():
    """{材质名: spec 条目}，按 spec 顺序。"""
    return {entry["name"]: entry for entry in load_spec()["materials"]}


def texture_names():
    return {entry["name"]: entry["texture"] for entry in load_spec()["materials"]}


def tile_path(material):
    entry = material_specs()[material]
    root = load_spec()["outputs"]["tiles"]
    return os.path.join(REPO_ROOT, root, entry["texture"] + ".png")


def runtime_uri(material):
    return "%s/%s.png" % (load_spec()["uri_prefix"],
                          material_specs()[material]["texture"])


def _srgb_to_linear(value):
    value = value / 255.0
    if value <= 0.04045:
        return value / 12.92
    return ((value + 0.055) / 1.055) ** 2.4


def palette_linear():
    """{材质名: (线性 base color, roughness, metallic)}，供 BuildConfig 回退使用。"""
    out = {}
    for name, entry in material_specs().items():
        rgb = [_srgb_to_linear(v) for v in entry["mean_rgb"]]
        out[name] = (tuple(round(v, 4) for v in rgb),
                     float(entry["roughness"]), float(entry["metallic"]))
    return out


def texture_report():
    """纯 Python 贴图事实（供 dryrun / 验收）：文件、字节、tile_m、px/m。"""
    spec = load_spec()
    tile_px = int(spec["tile_px"])
    out = {}
    for name, entry in material_specs().items():
        path = tile_path(name)
        out[name] = {
            "texture": entry["texture"],
            "file": os.path.relpath(path, REPO_ROOT).replace("\\", "/"),
            "exists": os.path.exists(path),
            "bytes": os.path.getsize(path) if os.path.exists(path) else None,
            "tile_m": float(entry["tile_m"]),
            "px_per_m": round(tile_px / float(entry["tile_m"]), 1),
            "uri": runtime_uri(name),
        }
    return out


# ---------------------------------------------------------------- Blender 侧

def _load_image(material):
    import bpy
    entry = material_specs()[material]
    path = tile_path(material)
    if not os.path.exists(path):
        return None
    image = bpy.data.images.get(entry["texture"])
    if image is None or os.path.abspath(bpy.path.abspath(image.filepath)) != os.path.abspath(path):
        image = bpy.data.images.load(path, check_existing=True)
        image.name = entry["texture"]
    image.colorspace_settings.name = "sRGB"
    return image


def build_materials(force=True):
    """创建/刷新全部共享贴图材质；返回 {材质名: 报告}。"""
    import bpy
    out = {}
    for name, entry in material_specs().items():
        mat = bpy.data.materials.get(name)
        if mat is None:
            mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        tree = mat.node_tree
        image = _load_image(name)
        if force or not tree.nodes:
            tree.nodes.clear()
            bsdf = tree.nodes.new("ShaderNodeBsdfPrincipled")
            bsdf.name = "Principled BSDF"
            bsdf.location = (0, 0)
            output = tree.nodes.new("ShaderNodeOutputMaterial")
            output.location = (320, 0)
            tree.links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
            if image is not None:
                tex = tree.nodes.new("ShaderNodeTexImage")
                tex.name = "SharedTexture"
                tex.image = image
                tex.interpolation = "Linear"
                tex.extension = "REPEAT"
                tex.location = (-380, 0)
                tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
            bsdf.inputs["Roughness"].default_value = float(entry["roughness"])
            bsdf.inputs["Metallic"].default_value = float(entry["metallic"])
            try:
                bsdf.inputs["Specular IOR Level"].default_value = 0.4
            except KeyError:
                pass
        mat.use_backface_culling = False
        linear = palette_linear()[name][0]
        mat.diffuse_color = (linear[0], linear[1], linear[2], 1.0)
        mat.roughness = float(entry["roughness"])
        mat.metallic = float(entry["metallic"])
        out[name] = {
            "texture": entry["texture"],
            "image": image.name if image else None,
            "image_px": list(image.size) if image else None,
            "tile_m": float(entry["tile_m"]),
            "roughness": float(entry["roughness"]),
            "metallic": float(entry["metallic"]),
        }
    return out


def _project_axes(normal):
    ax = max(range(3), key=lambda i: abs(normal[i]))
    if ax == 0:
        return 1, 2
    if ax == 1:
        return 0, 2
    return 0, 1


def apply_to_object(obj, specs=None):
    """给一个 mesh 对象重建材质槽并写世界空间盒式 UV（几何不变）。"""
    import bpy

    specs = specs or material_specs()
    mesh = obj.data
    before = {"verts": len(mesh.vertices), "polys": len(mesh.polygons),
              "loops": len(mesh.loops)}

    slot_names = [m.name for m in mesh.materials if m is not None]
    face_materials = [slot_names[p.material_index] if slot_names else None
                      for p in mesh.polygons]
    # 只保留**实际被面使用**的材质，避免把 spec 里全部材质塞进每个 mesh。
    used = {name for name in face_materials if name in specs}
    wanted = [name for name in slot_names if name in used]
    for name in sorted(used):
        if name not in wanted:
            wanted.append(name)
    if not wanted:
        return {"ok": False, "error": "no shared material slots", "object": obj.name}

    mesh.materials.clear()
    for name in wanted:
        mat = bpy.data.materials.get(name)
        if mat is None:
            build_materials()
            mat = bpy.data.materials.get(name)
        mesh.materials.append(mat)
    index = {name: i for i, name in enumerate(wanted)}

    usage = {}
    for poly, name in zip(mesh.polygons, face_materials):
        if name is None or name not in index:
            return {"ok": False, "error": "polygon %d has no shared material" % poly.index,
                    "object": obj.name}
        poly.material_index = index[name]
        usage[name] = usage.get(name, 0) + 1

    uv_layer = mesh.uv_layers.get(UV_LAYER) or mesh.uv_layers.new(name=UV_LAYER)
    uv_layer.active = True
    world = obj.matrix_world
    u_min = v_min = float("inf")
    u_max = v_max = float("-inf")
    for poly in mesh.polygons:
        name = mesh.materials[poly.material_index].name
        tile = float(specs[name]["tile_m"])
        ua, va = _project_axes(poly.normal)
        for li in range(poly.loop_start, poly.loop_start + poly.loop_total):
            co = world @ mesh.vertices[mesh.loops[li].vertex_index].co
            u, v = co[ua] / tile, co[va] / tile
            uv_layer.data[li].uv = (u, v)
            u_min, u_max = min(u_min, u), max(u_max, u)
            v_min, v_max = min(v_min, v), max(v_max, v)
    mesh.update()

    after = {"verts": len(mesh.vertices), "polys": len(mesh.polygons),
             "loops": len(mesh.loops)}
    return {
        "ok": True,
        "object": obj.name,
        "geometry_unchanged": before == after,
        "uv_layer": uv_layer.name,
        "uv_loops": len(mesh.loops),
        "uv_range_u": [round(u_min, 3), round(u_max, 3)],
        "uv_range_v": [round(v_min, 3), round(v_max, 3)],
        "material_slots": [m.name for m in mesh.materials],
        "material_usage": usage,
    }


def apply_collection(collection):
    """给集合内所有 mesh 应用共享贴图材质 + UV；返回汇总报告。"""
    build_materials()
    specs = material_specs()
    reports = []
    failures = []
    for obj in collection.objects:
        if obj.type != "MESH":
            continue
        report = apply_to_object(obj, specs=specs)
        if report.get("ok"):
            reports.append(report)
        else:
            failures.append(report)
    return {
        "collection": collection.name,
        "objects": len(reports) + len(failures),
        "textured": len(reports),
        "failures": failures,
        "uv_loops": sum(r["uv_loops"] for r in reports),
        "materials": sorted({m for r in reports for m in r["material_slots"]}),
        "per_object": reports,
    }


def verify_collection(collection):
    """只读验收：UV 完整、每个槽都绑定 512² 贴图、只用 spec 内材质。"""
    import bpy

    specs = material_specs()
    checks = {
        "all_uv_complete": True,
        "all_images_bound": True,
        "images_512": True,
        "materials_in_spec": True,
    }
    failures = []
    meshes = [o for o in collection.objects if o.type == "MESH"]
    for obj in meshes:
        mesh = obj.data
        uv_layer = mesh.uv_layers.get(UV_LAYER)
        if uv_layer is None or len(uv_layer.data) != len(mesh.loops):
            checks["all_uv_complete"] = False
            failures.append("%s: uv layer incomplete" % obj.name)
        for mat in mesh.materials:
            if mat is None:
                checks["all_images_bound"] = False
                failures.append("%s: empty material slot" % obj.name)
                continue
            if mat.name not in specs:
                checks["materials_in_spec"] = False
                failures.append("%s: material %s not in spec" % (obj.name, mat.name))
            tex = next((n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE"), None) \
                if mat.use_nodes and mat.node_tree else None
            if tex is None or tex.image is None:
                checks["all_images_bound"] = False
                failures.append("%s: %s has no image texture" % (obj.name, mat.name))
                continue
            if tuple(tex.image.size) != (512, 512):
                checks["images_512"] = False
                failures.append("%s: %s image %s not 512" % (
                    obj.name, mat.name, tuple(tex.image.size)))
    return {
        "collection": collection.name,
        "meshes": len(meshes),
        "checks": checks,
        "failures": failures,
        "ok": all(checks.values()) and not failures,
    }


def report(collection):
    """apply + verify 的合并报告，供生成器 `report()` 使用。"""
    applied = apply_collection(collection)
    verified = verify_collection(collection)
    return {"applied": applied, "verified": verified}
