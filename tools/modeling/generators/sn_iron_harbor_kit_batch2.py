# -*- coding: utf-8 -*-
"""铁港建筑套件第二批（其余 4 栋 drop-in）的 Blender 装配/自检/导出 harness。

这份文件只做 **Blender 侧**的事，几何仍然在各自的纯 Python 生成器里：
    sn_iron_harbor_warehouse_short_generator.py
    sn_iron_harbor_harbor_office_generator.py
    sn_iron_harbor_cargo_shed_generator.py
    sn_iron_harbor_tavern_generator.py
（每个文件都能被 `dryrun_props.py` 离线干跑。）

本 harness 负责：
1. `build_all()`      —— 逐栋 importlib 加载生成器 → 取 Part → 建单 mesh 对象（集合
                        `SN_Iron_Harbor_Architecture`，工作台摆放位置见 `BUILDINGS`）；
2. 材质 —— 调 `sn_iron_harbor_materials.apply_to_object(obj, cells=...)`，每栋可以用
                        同一张 trim sheet 的不同 cell（砖/灰泥/木/铁/石/玻璃各选一档），
                        几何不动、UV 按盒投影写；
3. `report_all()`     —— 逐栋 tri/尺寸/zmin/轴心/材质槽/网格健康/UV/贴图/设计清单 + 全场景
                        digest 回归（证明没有动别的对象与旧占位资产）；
4. `export_all()`     —— 备份旧内容 GLB（只备份一次），再逐栋导出 GLB 到
                        `dev_mods/core/assets/models/props/SN_HT_<Name>.glb`；
5. `restore_legacy()` —— 把 4 个旧 GLB 备份还原（回滚用）。

用法（Blender 内 MCP）：
    p = r"<abs path>/sn_iron_harbor_kit_batch2.py"
    ns = {"__name__": "kit_batch2", "__file__": p}
    exec(compile(open(p, encoding="utf-8").read(), p, "exec"), ns)
    ns["build_all"](); ns["report_all"](); ns["export_all"]()
"""

import hashlib
import importlib.util
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
COLLECTION = "SN_Iron_Harbor_Architecture"
PREFIX = "SN_HT_"
PROPS_DIR = os.path.join(REPO_ROOT, "dev_mods", "core", "assets", "models", "props")
BACKUP_DIR = os.path.join(REPO_ROOT, ".design", "buildings", "iron_harbor")
MAX_MATERIAL_SLOTS = 6

# 每栋：生成器文件、资产名、工作台摆放（y=150 这一排是空的）、目标尺寸、
# 三角面上下限，以及**本栋采样哪一档 trim sheet cell**（同材质槽、不同 cell =
# 同一套共享贴图下的建筑差异，不增加材质槽也不增加贴图）。
BUILDINGS = [
    {
        "module": "sn_iron_harbor_warehouse_short_generator.py",
        "asset": "SN_HT_Warehouse_Short",
        "location": (-30.0, 150.0, 0.0),
        "target": (11.0, 9.0, 9.5),
        "budget": (3000, 5000),
        "cells": {
            "SN_Town_Brick": "brick_wall",
            "SN_Town_Plaster": "plaster_light",
            "SN_Town_Wood": "wood_plank",
            "SN_Town_Iron": "iron_rust",
            "SN_Town_Stone": "stone_base",
            "SN_Town_Glass": "glass_dark",
        },
    },
    {
        "module": "sn_iron_harbor_harbor_office_generator.py",
        "asset": "SN_HT_Harbor_Office",
        "location": (-10.0, 150.0, 0.0),
        "target": (9.0, 8.0, 14.0),
        "budget": (8000, 14000),
        "cells": {
            "SN_Town_Brick": "brick_wall",
            "SN_Town_Plaster": "plaster_light",
            "SN_Town_Wood": "wood_plank_weathered",
            "SN_Town_Iron": "iron_dark",
            "SN_Town_Stone": "stone_base",
            "SN_Town_Glass": "glass_reflect",
        },
    },
    {
        "module": "sn_iron_harbor_cargo_shed_generator.py",
        "asset": "SN_HT_Cargo_Shed",
        "location": (10.0, 150.0, 0.0),
        "target": (8.0, 6.0, 4.5),
        "budget": (3000, 5000),
        "cells": {
            "SN_Town_Brick": "brick_wall",
            "SN_Town_Plaster": "plaster_grime",
            "SN_Town_Wood": "wood_plank",
            "SN_Town_Iron": "iron_rust",
            "SN_Town_Stone": "stone_base",
            "SN_Town_Glass": "glass_dark",
        },
    },
    {
        "module": "sn_iron_harbor_tavern_generator.py",
        "asset": "SN_HT_Tavern",
        "location": (30.0, 150.0, 0.0),
        "target": (10.0, 8.0, 8.0),
        "budget": (5000, 8000),
        "cells": {
            "SN_Town_Brick": "brick_wall",
            "SN_Town_Plaster": "plaster_grime",
            "SN_Town_Wood": "wood_plank",
            "SN_Town_Iron": "iron_dark",
            "SN_Town_Stone": "stone_base_dirty",
            "SN_Town_Glass": "glass_reflect",
        },
    },
]

_RESULTS = {}
_BASELINE = {}


def _load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _load_materials():
    return _load(os.path.join(HERE, "sn_iron_harbor_materials.py"), "sn_iron_harbor_materials")


def _ensure_collection():
    import bpy

    col = bpy.data.collections.get(COLLECTION)
    if col is None:
        col = bpy.data.collections.new(COLLECTION)
        bpy.context.scene.collection.children.link(col)
    return col


def _make_object(name, part, location, collection, grey_materials):
    """把纯 Python 的 Part 变成单 mesh 对象（每面材质 → 材质槽）。"""
    import bmesh
    import bpy

    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata([tuple(v) for v in part.verts], [], [list(f) for f, _m in part.faces])
    mesh.update()

    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()

    slots = []
    for _face, mat_name in part.faces:
        if mat_name not in slots:
            slots.append(mat_name)
    if len(slots) > MAX_MATERIAL_SLOTS:
        raise RuntimeError("%s: 材质槽 %d > 上限 %d" % (name, len(slots), MAX_MATERIAL_SLOTS))
    for mat_name in slots:
        mesh.materials.append(grey_materials(mat_name))
    index = {mat_name: i for i, mat_name in enumerate(slots)}
    for poly, (_face, mat_name) in zip(mesh.polygons, part.faces):
        poly.material_index = index[mat_name]
        poly.use_smooth = False

    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (0.0, 0.0, 0.0)
    obj.scale = (1.0, 1.0, 1.0)
    return obj


def _grey_material(name):
    """灰阶占位材质（贴图缺失时 apply_to_object 会退回它）。"""
    import bpy

    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    tints = {"SN_Town_Brick": 0.345, "SN_Town_Plaster": 0.560, "SN_Town_Wood": 0.215,
             "SN_Town_Iron": 0.120, "SN_Town_Stone": 0.445, "SN_Town_Glass": 0.050}
    tint = tints.get(name, 0.5)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (tint, tint, tint, 1.0)
    mat.diffuse_color = (tint, tint, tint, 1.0)
    return mat


def _scene_digest(exclude_names):
    """除本套件对象外的全场景指纹：证明没动别的对象与旧占位资产。"""
    import bpy

    rows = []
    for o in bpy.data.objects:
        if o.name in exclude_names:
            continue
        tris = 0
        if o.type == "MESH" and o.data:
            o.data.calc_loop_triangles()
            tris = len(o.data.loop_triangles)
        rows.append((o.name, o.type,
                     tuple(round(v, 5) for v in o.location),
                     tuple(round(v, 5) for v in o.rotation_euler),
                     tuple(round(v, 5) for v in o.scale), tris,
                     sorted(m.name for m in o.data.materials) if o.type == "MESH" else []))
    rows.sort()
    return hashlib.sha256(json.dumps(rows, default=str).encode()).hexdigest(), len(rows)


def _apply_cells(entry):
    """把**本栋**的 cell 覆盖重新写进那 6 个共享材质 datablock。

    六个材质是全局 datablock（按名字复用），`apply_to_object()` 每次都会重建它们
    的 node tree —— 所以 build/report/export/render 的**每一个**阶段都必须"轮到谁就
    重新写一次"，否则最后一栋的 cell 会覆盖前面所有栋（曾因此在 3 栋 GLB 里嵌成
    Tavern 的贴图套装）。
    """
    mats = _load_materials()
    result = mats.apply_to_object(entry["object"], cells=entry["spec"]["cells"])
    entry["texture"] = result
    entry["verify"] = mats.verify_object(entry["object"])
    return entry["texture"]


def _glb_image_names(path):
    """读 GLB 的 JSON chunk，返回内嵌贴图名（用于「材质 → 本栋 cell」硬校验）。"""
    import struct

    data = open(path, "rb").read()
    clen, _ = struct.unpack("<II", data[12:20])
    spec = json.loads(data[20:20 + clen].decode("utf-8"))
    return [img.get("name") for img in spec.get("images", [])]


def _used_materials(obj):
    usage = {}
    for poly in obj.data.polygons:
        usage[poly.material_index] = usage.get(poly.material_index, 0) + 1
    return {obj.data.materials[i].name for i, n in usage.items() if n > 0}


def build_all():
    """重建 4 栋对象（只删本集合内以 SN_HT_ 开头、名字在本批清单里的对象）。"""
    import bpy

    collection = _ensure_collection()
    names = {b["asset"] + "_LOD0" for b in BUILDINGS}
    _BASELINE["digest"], _BASELINE["count"] = _scene_digest(names)

    for obj in list(collection.objects):
        if obj.name.startswith(PREFIX) and obj.name in names:
            old_mesh = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            if old_mesh is not None and old_mesh.users == 0:
                bpy.data.meshes.remove(old_mesh)
    for stale in [me for me in bpy.data.meshes if me.users == 0 and me.name.split("_mesh")[0] in names]:
        bpy.data.meshes.remove(stale)

    mats = _load_materials()
    missing = sorted({c for b in BUILDINGS for c in mats.missing_tiles(b["cells"])})
    built = []
    for spec in BUILDINGS:
        path = os.path.join(HERE, spec["module"])
        if not os.path.exists(path):
            built.append((spec["asset"], "MISSING GENERATOR: " + spec["module"]))
            continue
        gen = _load(path, "gen_" + spec["asset"].lower())
        name = gen.NAME
        part = gen.build_all_geometry()[name]
        obj = _make_object(name, part, spec["location"], collection, _grey_material)
        result = {"ok": True, "tris_before": sum(max(0, len(f) - 2) for f, _m in part.faces)}
        if missing:
            result.update({"ok": False, "reason": "missing trim sheet tiles: %s" % missing})
        else:
            result.update(mats.apply_to_object(obj, cells=spec["cells"]))
            result["verify"] = mats.verify_object(obj)
            result["texture_stats"] = mats.texture_stats(spec["cells"])
        _RESULTS[spec["asset"]] = {"spec": spec, "gen": gen, "object": obj, "texture": result}
        built.append((spec["asset"], {"tris": result.get("tris_before"), "ok": result.get("ok")}))
    return built


def report_all():
    """逐栋报告 + 全场景回归。返回 {asset: report}。"""
    import bpy

    out = {}
    for spec in BUILDINGS:
        entry = _RESULTS.get(spec["asset"])
        if entry is None:
            out[spec["asset"]] = {"missing": True}
            continue
        obj = entry["object"]
        gen = entry["gen"]
        _apply_cells(entry)          # 本栋的 cell 必须在测量前重新写回
        tex = entry["texture"]
        mesh = obj.data
        mesh.calc_loop_triangles()
        tris = len(mesh.loop_triangles)

        import bmesh

        bm = bmesh.new()
        bm.from_mesh(mesh)
        loose = sum(1 for v in bm.verts if not v.link_edges)
        degen = sum(1 for f in bm.faces if f.calc_area() < 1e-9)
        nonman = sum(1 for e in bm.edges if not e.is_manifold)
        boundary = sum(1 for e in bm.edges if e.is_boundary)
        bm.free()

        xs = [v.co.x for v in mesh.vertices]
        ys = [v.co.y for v in mesh.vertices]
        zs = [v.co.z for v in mesh.vertices]
        size = [round(max(xs) - min(xs), 4), round(max(ys) - min(ys), 4),
                round(max(zs) - min(zs), 4)]
        zmin = round(min(zs), 6)
        slots = [m.name for m in mesh.materials]
        target = spec["target"]
        verify = (entry.get("verify") or {}).get("checks") or {}
        checks = {
            "tris_in_budget": spec["budget"][0] <= tris <= spec["budget"][1],
            "size_matches": all(abs(size[i] - target[i]) <= 0.05 for i in range(3)),
            "grounded": abs(zmin) <= 1e-6,
            "pivot_ground_centre": abs(min(xs) + max(xs)) <= 1e-6 and abs(min(ys) + max(ys)) <= 1e-6,
            "material_slots_ok": 0 < len(slots) <= MAX_MATERIAL_SLOTS,
            "palette_only": all(s in _load_materials().MATERIAL_SURFACES for s in slots),
            "loose_verts_zero": loose == 0,
            "degenerate_faces_zero": degen == 0,
            "non_manifold_zero": nonman == 0,
            "boundary_edges_zero": boundary == 0,
            "uv_loops_complete": bool(verify.get("uv_loops_complete")),
            "geometry_unchanged_by_uv": bool(tex.get("geometry_unchanged")),
            "all_images_bound": bool(verify.get("all_images_bound")),
            "uv_projection_ok": bool(verify.get("uv_projection_ok")),
        }
        checks["all_pass"] = all(checks.values())
        out[spec["asset"]] = {
            "object": obj.name,
            "location": list(spec["location"]),
            "target_size": list(target),
            "budget": list(spec["budget"]),
            "measured": {"tris": tris, "verts": len(mesh.vertices), "size": size, "zmin": zmin,
                         "material_slots": slots,
                         "material_usage": (entry.get("verify") or {}).get("material_usage")},
            "cells": {k: v for k, v in spec["cells"].items()},
            "design": getattr(gen, "DESIGN", None),
            "texture": {k: tex.get(k) for k in ("uv_range_u", "uv_range_v", "uv_loops",
                                                "textured_slots", "bound_images")},
            "checks": checks,
        }

    names = {b["asset"] + "_LOD0" for b in BUILDINGS}
    digest, count = _scene_digest(names)
    out["_regression"] = {
        "baseline_count": _BASELINE.get("count"),
        "after_count": count,
        "digest_matches_baseline": _BASELINE.get("digest") == digest,
        "legacy_placeholders": {b["asset"]: _legacy_state(b["asset"]) for b in BUILDINGS},
    }
    print("KIT_BATCH2_REPORT " + repr(out))
    return out


def _legacy_state(asset):
    import bpy

    obj = bpy.data.objects.get(asset)
    if obj is None:
        return None
    return {"location": [round(v, 3) for v in obj.location],
            "dimensions": [round(v, 3) for v in obj.dimensions],
            "collection": obj.users_collection[0].name if obj.users_collection else None,
            "tris": len(obj.data.loop_triangles) if obj.type == "MESH" else None}


def _sha256(path):
    if not os.path.exists(path):
        return None
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def export_all():
    """逐栋导出 GLB 到内容路径（旧资产先备份一次，绝不覆盖备份）。"""
    import bpy

    os.makedirs(BACKUP_DIR, exist_ok=True)
    results = {}
    for spec in BUILDINGS:
        entry = _RESULTS.get(spec["asset"])
        if entry is None:
            results[spec["asset"]] = {"ok": False, "error": "not built"}
            continue
        obj = entry["object"]
        _apply_cells(entry)          # 导出前把本栋 cell 写回共享材质
        content = os.path.join(PROPS_DIR, spec["asset"] + ".glb")
        backup = os.path.join(BACKUP_DIR, spec["asset"] + "_legacy.glb")
        legacy_sha = _sha256(content)
        if not os.path.exists(backup):
            if legacy_sha is None:
                results[spec["asset"]] = {"ok": False, "error": "no content glb and no backup"}
                continue
            import shutil

            shutil.copy2(content, backup)
        original = tuple(obj.location)
        was_selected = list(bpy.context.selected_objects)
        try:
            for other in was_selected:
                other.select_set(False)
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            obj.location = (0.0, 0.0, 0.0)
            bpy.ops.export_scene.gltf(
                filepath=content, export_format="GLB", use_selection=True, export_apply=True,
                export_cameras=False, export_lights=False, export_yup=True, export_extras=False)
        finally:
            obj.location = original
            obj.select_set(False)
            for other in was_selected:
                other.select_set(True)
        images = sorted(x for x in _glb_image_names(content) if x)
        expected = sorted({spec["cells"][name] for name in _used_materials(obj)
                           if name in spec["cells"]})
        results[spec["asset"]] = {
            "ok": images == expected, "content_glb": content, "legacy_backup": backup,
            "content_sha_before": legacy_sha, "new_sha256": _sha256(content),
            "bytes": os.path.getsize(content),
            "glb_images": images, "expected_cells": expected,
            "cells_ok": images == expected,
        }
    return results


def restore_legacy():
    """把 4 个旧 GLB 备份还原（导出后如需回滚）。"""
    import shutil

    out = {}
    for spec in BUILDINGS:
        content = os.path.join(PROPS_DIR, spec["asset"] + ".glb")
        backup = os.path.join(BACKUP_DIR, spec["asset"] + "_legacy.glb")
        if not os.path.exists(backup):
            out[spec["asset"]] = {"ok": False, "error": "no backup"}
            continue
        shutil.copy2(backup, content)
        out[spec["asset"]] = {"ok": True, "sha256": _sha256(content)}
    return out


def render_previews():
    """每栋 3 张：3/4 街道视角 + 正交正视（+X 主立面）+ 屋顶。"""
    import bpy
    from mathutils import Vector

    # 新建/移动过的对象 matrix_world 在 depsgraph 求值前是单位矩阵，必须先更新，
    # 否则按包围盒取景会得到错误的世界坐标（曾经因此渲出纯背景）。
    bpy.context.view_layer.update()
    out_dir = os.path.join(REPO_ROOT, "docs", "design", "screenshots",
                           "iron_harbor_architecture")
    os.makedirs(out_dir, exist_ok=True)
    scene = bpy.context.scene
    saved = {"engine": scene.render.engine, "res": (scene.render.resolution_x,
             scene.render.resolution_y, scene.render.resolution_percentage),
             "filepath": scene.render.filepath, "camera": scene.camera}

    cam_data = bpy.data.cameras.new("TMP_KIT2_CAM")
    cam = bpy.data.objects.new("TMP_KIT2_CAM", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    lights = []
    for name, energy, rot, color in (
            ("TMP_KIT2_KEY", 2.6, (48.0, 0.0, 128.0), (1.0, 0.96, 0.90)),
            ("TMP_KIT2_FILL", 0.55, (62.0, 0.0, 8.0), (0.80, 0.87, 1.0)),
            ("TMP_KIT2_RIM", 0.9, (18.0, 0.0, 210.0), (0.92, 0.94, 1.0))):
        data = bpy.data.lights.new(name, "SUN")
        data.energy = energy
        data.angle = 0.105
        data.color = color
        ob = bpy.data.objects.new(name, data)
        ob.rotation_euler = [__import__("math").radians(v) for v in rot]
        scene.collection.objects.link(ob)
        lights.append(ob)
    world = scene.world
    bg = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"), None) if world else None
    saved_bg = tuple(bg.inputs["Color"].default_value) if bg else None
    saved_strength = float(bg.inputs["Strength"].default_value) if bg else None
    saved_image = (scene.render.image_settings.file_format,
                   scene.render.image_settings.color_mode)
    if bg:
        bg.inputs["Color"].default_value = (0.040, 0.045, 0.055, 1.0)
        bg.inputs["Strength"].default_value = 0.35
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    if hasattr(scene, "eevee"):
        scene.eevee.taa_render_samples = 48
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"

    hidden = {}
    for o in bpy.data.objects:
        if o.type == "MESH" and o.name not in {b["asset"] + "_LOD0" for b in BUILDINGS}:
            hidden[o] = o.hide_render
            o.hide_render = True
    files = []
    try:
        for spec in BUILDINGS:
            entry = _RESULTS.get(spec["asset"])
            if entry is None:
                continue
            obj = entry["object"]
            # 只留当前这一栋可见：kit 里其余建筑会挡在画面里
            _apply_cells(entry)      # 渲染前也要把本栋 cell 写回
            keep = obj.name
            other_state = {}
            for o in bpy.data.objects:
                if o.type == "MESH" and o.name in {b2["asset"] + "_LOD0" for b2 in BUILDINGS} and o.name != keep:
                    other_state[o] = o.hide_render
                    o.hide_render = True
            bpy.context.view_layer.update()
            pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
            lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
            hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
            centre = (lo + hi) * 0.5
            radius = max((hi - lo).length * 0.5, 1.0)
            target = spec["asset"] + "_LOD0"
            for tag, direction, lens, ortho in (
                    ("street_3q", Vector((1.0, 0.62, 0.34)), 40.0, False),
                    ("front_x", Vector((1.0, 0.0, 0.0)), 40.0, False),
                    ("roof", Vector((0.18, 0.34, 1.0)), 52.0, False)):
                d = direction.normalized()
                if tag == "front_x":
                    cam.location = centre + d * (radius * 3.4)
                    cam.rotation_euler = (d * -1.0).to_track_quat("-Z", "Y").to_euler()
                    cam_data.type = "ORTHO"
                    cam_data.ortho_scale = max((hi - lo).x, (hi - lo).y, (hi - lo).z) * 1.25
                else:
                    cam.location = centre + d * (radius * 3.2)
                    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
                    cam_data.type = "PERSP"
                    cam_data.lens = lens
                scene.render.resolution_x, scene.render.resolution_y = 1280, 800
                scene.render.resolution_percentage = 100
                path = os.path.join(out_dir, "%s_%s_1280x800.png" % (target, tag))
                scene.render.filepath = path
                print("[kit2-render] %s %s cam=%s type=%s obj_hidden=%s" % (
                    target, tag, tuple(round(v, 2) for v in cam.location), cam_data.type,
                    obj.hide_render))
                bpy.ops.render.render(write_still=True)
                files.append(path)
            for o, state in other_state.items():
                o.hide_render = state
            other_state = {}
    finally:
        for o, state in hidden.items():
            o.hide_render = state
        for o in bpy.data.objects:          # 异常路径也把 kit 兄弟建筑放出来
            if o.type == "MESH" and o.name in {b2["asset"] + "_LOD0" for b2 in BUILDINGS}:
                o.hide_render = False
        for ob in lights:
            data = ob.data
            bpy.data.objects.remove(ob, do_unlink=True)
            bpy.data.lights.remove(data)
        bpy.data.objects.remove(cam, do_unlink=True)
        bpy.data.cameras.remove(cam_data)
        if bg is not None and saved_bg is not None:
            bg.inputs["Color"].default_value = saved_bg
            if saved_strength is not None:
                bg.inputs["Strength"].default_value = saved_strength
        scene.render.image_settings.file_format, scene.render.image_settings.color_mode = saved_image
        scene.camera = saved["camera"]
        scene.render.engine = saved["engine"]
        scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = saved["res"]
        scene.render.filepath = saved["filepath"]
    print("KIT_BATCH2_PREVIEW " + repr({"count": len(files), "files": [os.path.basename(f) for f in files]}))
    return files


if "bpy" in globals():  # executed inside Blender
    print("sn_iron_harbor_kit_batch2: call build_all() / report_all() / export_all() / "
          "render_previews() / restore_legacy()")
