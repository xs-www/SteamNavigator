# -*- coding: utf-8 -*-
# @static-doc
# 作用：LOD1 基础套件（M0-5）的派生生成器：把工作台里 **kit 26 件**（weapon_kit /
# ship_parts / machinery / cargo / dock / architecture / environment）与 **4 艘可玩船**
# 的 LOD0 层级就地简化成单 mesh 的远景低模 `SN_<Asset>_LOD1`，写共享贴图材质 + 盒式 UV，
# 并把每个 LOD1 作为独立对象放回工作台 `SN_LOD1_Kit_Ships` 集合；随后可逐件导出 GLB
# 候选并把内嵌贴图外部化为 `shared_materials/<texture>.png`。
#
# ## 契约与约束
# - 纯 Python 数据段（`PLAN` / `budget_plan` / `CAP_RATIO`）不 import bpy，dryrun /
#   verifier / installer 可以直接加载本文件读计划；Blender 相关 import 全部在函数内。
# - **LOD0 是唯一几何真源**：不复制生成器参数，不手摆点；LOD1 由工作台 LOD0 网格
#   `Decimate(collapse)` 派生。≤`KEEP_TRI` 的小件原样保留，其余按资产预算统一 ratio，
#   因此小结构（吊环、栏杆、系缆、铰链）不会先被吃掉。
# - 包围盒钉死：LOD1 顶点在**根节点局部空间**按 LOD0 的 x/y/z min/max 逐轴重映射，
#   保证 LOD0↔LOD1 世界包围盒逐轴一致（远景切换不跳尺寸、轴心落地/水线不变）。
# - 单 mesh 交付：LOD1 把 LOD0 的所有 mesh 子件合并成一个 mesh（按材质分 primitive），
#   不保留 socket / pivot / 层级；远景 LOD 不参与装配，接口契约只属于 LOD0。
# - 材质：只允许 `SN_Tex_*` 共享贴图材质；先按面记录材质名，合并后去重再交给
#   `sn_shared_materials.apply_to_object(space="local")` 重写槽位与 UV（几何不变）。
# - 只写 `SN_LOD1_Kit_Ships` 集合与 `_LOD1` 对象；不删改任何 LOD0 / 其它集合对象。
# - 导出候选写 `.design/lod1_kit_ships/`，不直接覆盖内容目录；安装由
#   `install_lod1_kit_ships.py` 在独立验收通过后执行。
#
# ## 重点逻辑
# ### `build_all(assets=None)`
# - 逐件取根节点的全部 mesh 后代（含 root 自身为 mesh 的 Ironclad），按 tri 预算决定
#   每件 ratio；大件复制对象加 Decimate 后用 depsgraph 求值取网格（不 apply 修改器），
#   小件直接读原网格；把三者统一变换到根局部空间、累加进一个 bmesh、三角化、去退化面。
# - 生成 mesh 后写材质/UV、按 LOD0 bbox 重映射顶点、挂到 LOD1 集合，记录逐件报告。
# ### `report()`
# - 逐件门禁：tri ≤ 上限且 ≤ LOD0×cap、bbox 与 LOD0 逐轴一致、LOD1 网格健康
#   （边界边 / 非流形 / 退化面 / 孤立点）不高于 LOD0、材质全部是共享贴图材质、UV 完整。
# ### `export_candidates()`
# - 逐件把对象矩阵临时置单位阵、selection-only 导出 GLB，再用
#   `glb_shared_textures.externalize_glb(prefer_authored=True)` 外部化贴图；候选目录
#   保留 `<category>/shared_materials/` 同级结构，安装时可整目录复制。
# @end-static-doc

import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
TILES_DIR = os.path.join(REPO_ROOT, "docs", "design", "textures", "shared_materials", "tiles")
WORK_DIR = os.path.join(REPO_ROOT, ".design", "lod1_kit_ships")
EMBEDDED_DIR = os.path.join(WORK_DIR, "embedded")
OUT_DIR = os.path.join(WORK_DIR, "out")
WORKBENCH_PATH = os.path.join(REPO_ROOT, ".design", "SN_Asset_Workbench.blend")

LOD1_COLLECTION = "SN_LOD1_Kit_Ships"
PLACEMENT_Y = 780.0
URI_PREFIX = "shared_materials"
TEXTURE_PREFIX = "SN_Tex_"

#: 小件保留阈值：≤ 这个三角数的对象不简化，避免远景 LOD 先把小结构吃掉。
KEEP_TRI = 20
#: 单件 ratio 下限：预算不足时也不会把大件压到无法辨认。
MIN_RATIO = 0.08
#: LOD1 三角面上限（相对 LOD0）：kit 35%、船 30%（远景船更依赖轮廓，给得略宽）。
CAP_RATIO = {"kit": 0.35, "ship": 0.30}
#: 目标 ratio（实际按小件保留后的剩余预算再分配，通常贴合这个值）。
TARGET_RATIO = {"kit": 0.30, "ship": 0.25}

#: 30 件交付清单。`ratio` 是目标比例（预算再分配的上限口径见 `budget_plan`）。
PLAN = [
    {"asset": "SN_Weapon_Cannon", "family": "weapon_kit", "category": "weapons",
     "collection": "SN_Weapon_Cannon_Prototype", "root": "SN_Weapon_Cannon_Root", "kind": "kit"},
    {"asset": "SN_Weapon_GunCarriage", "family": "weapon_kit", "category": "weapons",
     "collection": "SN_Weapon_GunCarriage_Prototype", "root": "SN_Weapon_GunCarriage_Root", "kind": "kit"},
    {"asset": "SN_Weapon_Turret", "family": "weapon_kit", "category": "weapons",
     "collection": "SN_Weapon_Turret_Prototype", "root": "SN_Weapon_Turret_Root", "kind": "kit"},
    {"asset": "SN_Weapon_Pedestal", "family": "weapon_kit", "category": "weapons",
     "collection": "SN_Weapon_Pedestal_Prototype", "root": "SN_Weapon_Pedestal_Root", "kind": "kit"},
    {"asset": "SN_ShipPart_Deck", "family": "ship_parts", "category": "ship_parts",
     "collection": "SN_ShipPart_Deck_Prototype", "root": "SN_ShipPart_Deck_Root", "kind": "kit"},
    {"asset": "SN_ShipPart_Mast", "family": "ship_parts", "category": "ship_parts",
     "collection": "SN_ShipPart_Mast_Prototype", "root": "SN_ShipPart_Mast_Root", "kind": "kit"},
    {"asset": "SN_ShipPart_Funnel", "family": "ship_parts", "category": "ship_parts",
     "collection": "SN_ShipPart_Funnel_Prototype", "root": "SN_ShipPart_Funnel_Root", "kind": "kit"},
    {"asset": "SN_ShipPart_HatchCover", "family": "ship_parts", "category": "ship_parts",
     "collection": "SN_ShipPart_HatchCover_Prototype", "root": "SN_ShipPart_HatchCover_Root", "kind": "kit"},
    {"asset": "SN_Machinery_GearSet", "family": "machinery_kit", "category": "machinery",
     "collection": "SN_Machinery_GearSet_Prototype", "root": "SN_Machinery_GearSet_Root", "kind": "kit"},
    {"asset": "SN_Machinery_Winch", "family": "machinery_kit", "category": "machinery",
     "collection": "SN_Machinery_Winch_Prototype", "root": "SN_Machinery_Winch_Root", "kind": "kit"},
    {"asset": "SN_Machinery_PowerUnit", "family": "machinery_kit", "category": "machinery",
     "collection": "SN_Machinery_PowerUnit_Prototype", "root": "SN_Machinery_PowerUnit_Root", "kind": "kit"},
    {"asset": "SN_Cargo_Crate", "family": "cargo_kit", "category": "cargo",
     "collection": "SN_Cargo_Crate_Prototype", "root": "SN_Cargo_Crate_Root", "kind": "kit"},
    {"asset": "SN_Cargo_CoalScuttle", "family": "cargo_kit", "category": "cargo",
     "collection": "SN_Cargo_CoalScuttle_Prototype", "root": "SN_Cargo_CoalScuttle_Root", "kind": "kit"},
    {"asset": "SN_Cargo_Tank", "family": "cargo_kit", "category": "cargo",
     "collection": "SN_Cargo_Tank_Prototype", "root": "SN_Cargo_Tank_Root", "kind": "kit"},
    {"asset": "SN_Cargo_Pallet", "family": "cargo_kit", "category": "cargo",
     "collection": "SN_Cargo_Pallet_Prototype", "root": "SN_Cargo_Pallet_Root", "kind": "kit"},
    {"asset": "SN_Dock_Structure", "family": "dock_kit", "category": "dock",
     "collection": "SN_Dock_Structure_Prototype", "root": "SN_Dock_Structure_Root", "kind": "kit"},
    {"asset": "SN_Dock_Jetty", "family": "dock_kit", "category": "dock",
     "collection": "SN_Dock_Jetty_Prototype", "root": "SN_Dock_Jetty_Root", "kind": "kit"},
    {"asset": "SN_Dock_Mooring", "family": "dock_kit", "category": "dock",
     "collection": "SN_Dock_Mooring_Prototype", "root": "SN_Dock_Mooring_Root", "kind": "kit"},
    {"asset": "SN_Arch_Warehouse", "family": "architecture_kit", "category": "architecture",
     "collection": "SN_Arch_Warehouse_Prototype", "root": "SN_Arch_Warehouse_Root", "kind": "kit"},
    {"asset": "SN_Arch_Workshop", "family": "architecture_kit", "category": "architecture",
     "collection": "SN_Arch_Workshop_Prototype", "root": "SN_Arch_Workshop_Root", "kind": "kit"},
    {"asset": "SN_Arch_Tavern", "family": "architecture_kit", "category": "architecture",
     "collection": "SN_Arch_Tavern_Prototype", "root": "SN_Arch_Tavern_Root", "kind": "kit"},
    {"asset": "SN_Arch_Factory", "family": "architecture_kit", "category": "architecture",
     "collection": "SN_Arch_Factory_Prototype", "root": "SN_Arch_Factory_Root", "kind": "kit"},
    {"asset": "SN_Env_Reef", "family": "environment_kit", "category": "environment",
     "collection": "SN_Env_Reef_Prototype", "root": "SN_Env_Reef_Root", "kind": "kit"},
    {"asset": "SN_Env_Wreck", "family": "environment_kit", "category": "environment",
     "collection": "SN_Env_Wreck_Prototype", "root": "SN_Env_Wreck_Root", "kind": "kit"},
    {"asset": "SN_Env_Lighthouse", "family": "environment_kit", "category": "environment",
     "collection": "SN_Env_Lighthouse_Prototype", "root": "SN_Env_Lighthouse_Root", "kind": "kit"},
    {"asset": "SN_Env_Buoy", "family": "environment_kit", "category": "environment",
     "collection": "SN_Env_Buoy_Prototype", "root": "SN_Env_Buoy_Root", "kind": "kit"},
    {"asset": "SN_Paddle_Freighter", "family": "ship", "category": "ships",
     "collection": "SN_Paddle_Freighter_Prototype", "root": "SN_PF_Root", "kind": "ship"},
    {"asset": "SN_Paddle_Steamer", "family": "ship", "category": "ships",
     "collection": "SN_Paddle_Steamer_Prototype", "root": "SN_PS_Root", "kind": "ship"},
    {"asset": "SN_Schooner_Fame", "family": "ship", "category": "ships",
     "collection": "SN_Schooner_Fame_Prototype", "root": "SN_SF_Root", "kind": "ship"},
    {"asset": "SN_Ironclad", "family": "ship", "category": "ships",
     "collection": "SN_Ironclad_Prototype", "root": "SN_Ironclad", "kind": "ship"},
]

PLAN_BY_ASSET = {entry["asset"]: entry for entry in PLAN}


# --------------------------------------------------------------------------- #
# Pure-Python planning helpers (used by dryrun / verifier / installer)
# --------------------------------------------------------------------------- #

def lod1_name(asset):
    return asset + "_LOD1"


def lod0_path(asset):
    entry = PLAN_BY_ASSET[asset]
    return os.path.join(REPO_ROOT, "assets", "models", entry["category"], asset + ".glb")


def lod1_dev_path(asset):
    entry = PLAN_BY_ASSET[asset]
    return os.path.join(REPO_ROOT, "assets", "models", entry["category"], asset + "_LOD1.glb")


def lod1_core_path(asset):
    entry = PLAN_BY_ASSET[asset]
    return os.path.join(REPO_ROOT, "dev_mods", "core", "assets", "models",
                        entry["category"], asset + "_LOD1.glb")


def candidate_paths(asset):
    entry = PLAN_BY_ASSET[asset]
    embedded = os.path.join(EMBEDDED_DIR, entry["category"], asset + "_LOD1.glb")
    final = os.path.join(OUT_DIR, entry["category"], asset + "_LOD1.glb")
    return embedded, final


def budget_plan(lod0_tris, small_tris=0, big_tris=None, kind="kit"):
    """Return the per-asset tri target, hard cap and big-part decimate ratio."""
    if big_tris is None:
        big_tris = max(0, lod0_tris - small_tris)
    target_ratio = TARGET_RATIO[kind]
    cap_ratio = CAP_RATIO[kind]
    target = max(96, int(round(lod0_tris * target_ratio)))
    cap = int(math.floor(lod0_tris * cap_ratio))
    remaining = max(0, target - small_tris)
    if big_tris <= 0:
        ratio = 1.0
    else:
        ratio = remaining / float(big_tris)
        ratio = max(MIN_RATIO, min(1.0, ratio))
    return {"lod0_tris": lod0_tris, "small_tris": small_tris, "big_tris": big_tris,
            "target_tris": target, "cap_tris": cap, "target_ratio": target_ratio,
            "cap_ratio": cap_ratio, "big_ratio": round(ratio, 6)}


def summarise_plan(lod0_by_asset):
    """Pure-Python aggregated plan for the dry run report."""
    rows = []
    for entry in PLAN:
        asset = entry["asset"]
        lod0 = int(lod0_by_asset[asset])
        plan = budget_plan(lod0, kind=entry["kind"])
        rows.append({"asset": asset, "kind": entry["kind"], "family": entry["family"],
                     "category": entry["category"], **plan})
    groups = {}
    for row in rows:
        group = groups.setdefault(row["kind"], {"assets": 0, "lod0_tris": 0,
                                                "target_tris": 0, "cap_tris": 0})
        group["assets"] += 1
        group["lod0_tris"] += row["lod0_tris"]
        group["target_tris"] += row["target_tris"]
        group["cap_tris"] += row["cap_tris"]
    return {"assets": rows, "groups": groups, "total_lod0_tris": sum(
        row["lod0_tris"] for row in rows), "total_target_tris": sum(
        row["target_tris"] for row in rows), "total_cap_tris": sum(
        row["cap_tris"] for row in rows)}


# --------------------------------------------------------------------------- #
# Blender-side helpers
# --------------------------------------------------------------------------- #

def _bpy():
    import bpy
    return bpy


def _tri_count_mesh(mesh):
    return sum(max(0, len(polygon.vertices) - 2) for polygon in mesh.polygons)


def _root_and_sources(entry):
    bpy = _bpy()
    root = bpy.data.objects.get(entry["root"])
    if root is None:
        raise RuntimeError("missing root object %s" % entry["root"])
    sources = []
    stack = list(root.children)
    if root.type == "MESH":
        sources.append(root)
    while stack:
        node = stack.pop()
        if node.type == "MESH":
            sources.append(node)
        stack.extend(node.children)
    if not sources:
        raise RuntimeError("no mesh children for %s" % entry["root"])
    sources.sort(key=lambda node: node.name)
    return root, sources


def _mesh_health(mesh):
    import bmesh

    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.edges.ensure_lookup_table()
    boundary = sum(1 for edge in bm.edges if len(edge.link_faces) == 1)
    non_manifold = sum(1 for edge in bm.edges if len(edge.link_faces) > 2)
    wire = sum(1 for edge in bm.edges if len(edge.link_faces) == 0)
    loose = sum(1 for vert in bm.verts if not vert.link_faces)
    degenerate = sum(1 for face in bm.faces
                     if face.calc_area() < 1e-12
                     or len({vert.index for vert in face.verts}) < 3)
    bm.free()
    return {"boundary_edges": boundary, "non_manifold_edges": non_manifold,
            "wire_edges": wire, "loose_verts": loose, "degenerate_faces": degenerate}


def _health_bytes(sources):
    total = {"boundary_edges": 0, "non_manifold_edges": 0, "wire_edges": 0,
             "loose_verts": 0, "degenerate_faces": 0}
    for obj in sources:
        report = _mesh_health(obj.data)
        for key in total:
            total[key] += int(report[key])
    return total


def _drop_duplicate_faces(faces, face_materials):
    """Remove every face that shares its exact vertex set with another face.

    Collapse decimation merges the two walls of zero-thickness regions and can leave
    a pair of coincident faces sharing all three vertices (a zero-volume "pillow").
    Such a pair is topologically a closed flap on its own: neither face shares an
    edge with the surrounding surface, so removing **both** keeps the neighbour
    topology intact (no boundary edges / holes are introduced), while keeping only
    one would open the flap. LOD0 has no duplicate faces, so every duplicate here is
    a decimation artefact.
    """
    groups = {}
    for index, face in enumerate(faces):
        groups.setdefault(tuple(sorted(face)), []).append(index)
    dropped = {index for indices in groups.values() if len(indices) > 1
               for index in indices}
    if not dropped:
        return faces, face_materials, 0
    kept_faces = []
    kept_materials = []
    for index, (face, material) in enumerate(zip(faces, face_materials)):
        if index in dropped:
            continue
        kept_faces.append(face)
        kept_materials.append(material)
    return kept_faces, kept_materials, len(dropped)


def _mesh_chunk(obj, root, ratio):
    """Return ``(verts, faces, face_materials, tris)`` in root-local space."""
    bpy = _bpy()
    source_mesh = obj.data
    matrix = root.matrix_world.inverted() @ obj.matrix_world
    materials = [material.name if material else None for material in source_mesh.materials]
    if ratio is None or ratio >= 0.999:
        verts = [tuple(matrix @ vertex.co) for vertex in source_mesh.vertices]
        faces = [tuple(polygon.vertices) for polygon in source_mesh.polygons]
        face_materials = [materials[polygon.material_index] if materials else None
                          for polygon in source_mesh.polygons]
        return verts, faces, face_materials, _tri_count_mesh(source_mesh)

    duplicate = obj.copy()
    duplicate.data = obj.data.copy()
    duplicate.parent = None
    duplicate.matrix_world = obj.matrix_world
    bpy.context.scene.collection.objects.link(duplicate)
    duplicate.name = "__LOD1_TMP__" + obj.name
    try:
        modifier = duplicate.modifiers.new("LOD1_DECIMATE", "DECIMATE")
        modifier.decimate_type = "COLLAPSE"
        modifier.ratio = float(ratio)
        modifier.use_collapse_triangulate = True
        modifier.use_symmetry = False
        bpy.context.view_layer.update()
        depsgraph = bpy.context.evaluated_depsgraph_get()
        evaluated = duplicate.evaluated_get(depsgraph)
        evaluated_mesh = evaluated.to_mesh()
        try:
            evaluated_materials = [material.name if material else None
                                   for material in evaluated_mesh.materials]
            vertex_count = len(evaluated_mesh.vertices)
            verts = [tuple(matrix @ vertex.co) for vertex in evaluated_mesh.vertices]
            faces = []
            face_materials = []
            for polygon in evaluated_mesh.polygons:
                indices = tuple(polygon.vertices)
                if min(indices) < 0 or max(indices) >= vertex_count:
                    continue
                faces.append(indices)
                face_materials.append(
                    evaluated_materials[polygon.material_index]
                    if evaluated_materials else None)
            faces, face_materials, deduped = _drop_duplicate_faces(faces, face_materials)
            tris = sum(max(0, len(face) - 2) for face in faces)
            return verts, faces, face_materials, tris
        finally:
            evaluated.to_mesh_clear()
    finally:
        bpy.data.objects.remove(duplicate, do_unlink=True)


def _root_local_bounds(root, sources):
    low = [float("inf")] * 3
    high = [float("-inf")] * 3
    for obj in sources:
        matrix = root.matrix_world.inverted() @ obj.matrix_world
        for vertex in obj.data.vertices:
            point = matrix @ vertex.co
            for axis in range(3):
                low[axis] = min(low[axis], point[axis])
                high[axis] = max(high[axis], point[axis])
    return low, high


def _remap_bounds(mesh, target_low, target_high):
    """Scale/translate mesh local coordinates so its bbox is exactly LOD0's."""
    low = [float("inf")] * 3
    high = [float("-inf")] * 3
    for vertex in mesh.vertices:
        for axis in range(3):
            low[axis] = min(low[axis], vertex.co[axis])
            high[axis] = max(high[axis], vertex.co[axis])
    scale = [1.0, 1.0, 1.0]
    for axis in range(3):
        current = high[axis] - low[axis]
        target = target_high[axis] - target_low[axis]
        if current > 1e-9:
            scale[axis] = target / current
    before = {"size": [round(high[axis] - low[axis], 6) for axis in range(3)],
              "min": [round(low[axis], 6) for axis in range(3)]}
    for vertex in mesh.vertices:
        coordinate = []
        for axis in range(3):
            value = target_low[axis] + (vertex.co[axis] - low[axis]) * scale[axis]
            coordinate.append(value)
        vertex.co = coordinate
    mesh.update()
    return {"pre_correct_size": before["size"], "pre_correct_min": before["min"],
            "scale": [round(value, 6) for value in scale]}


def _clear_lod1():
    """Remove only this batch's LOD1 objects (never the iron-harbor `SN_HT_*_LOD1`)."""
    bpy = _bpy()
    collection = bpy.data.collections.get(LOD1_COLLECTION)
    if collection is not None:
        for obj in list(collection.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
    for entry in PLAN:
        obj = bpy.data.objects.get(lod1_name(entry["asset"]))
        if obj is not None:
            bpy.data.objects.remove(obj, do_unlink=True)
    if collection is not None and collection.name in bpy.data.collections:
        bpy.data.collections.remove(collection)
    planned_meshes = {lod1_name(entry["asset"]) for entry in PLAN}
    for mesh in list(bpy.data.meshes):
        if mesh.name in planned_meshes and mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    for obj in list(bpy.data.objects):
        if obj.name.startswith("__LOD1_TMP__"):
            bpy.data.objects.remove(obj, do_unlink=True)


def _ensure_lod1_collection():
    bpy = _bpy()
    collection = bpy.data.collections.get(LOD1_COLLECTION)
    if collection is None:
        collection = bpy.data.collections.new(LOD1_COLLECTION)
        bpy.context.scene.collection.children.link(collection)
    return collection


def _build_one(entry):
    import bmesh

    import sn_shared_materials as shared

    bpy = _bpy()
    root, sources = _root_and_sources(entry)
    source_tris = [(obj, _tri_count_mesh(obj.data)) for obj in sources]
    lod0_tris = sum(tris for _obj, tris in source_tris)
    small_tris = sum(tris for _obj, tris in source_tris if tris <= KEEP_TRI)
    big_tris = lod0_tris - small_tris
    plan = budget_plan(lod0_tris, small_tris, big_tris, entry["kind"])
    lod1_health_lod0 = _health_bytes(sources)
    target_low, target_high = _root_local_bounds(root, sources)

    material_order = []
    chunks = []
    for obj, tris in source_tris:
        ratio = None if tris <= KEEP_TRI else plan["big_ratio"]
        verts, faces, face_materials, kept_tris = _mesh_chunk(obj, root, ratio)
        for face, material_name in zip(faces, face_materials):
            if material_name is None:
                continue
            if material_name not in material_order:
                material_order.append(material_name)
        chunks.append((verts, faces, face_materials, ratio, kept_tris))

    bm = bmesh.new()
    material_index = {name: index for index, name in enumerate(material_order)}
    for verts, faces, face_materials, _ratio, _tris in chunks:
        base = len(bm.verts)
        verts_bm = [bm.verts.new(tuple(vertex)) for vertex in verts]
        bm.verts.ensure_lookup_table()
        for face, material_name in zip(faces, face_materials):
            if material_name is None:
                continue
            try:
                new_face = bm.faces.new([verts_bm[index] for index in face])
            except ValueError:
                continue
            if len(new_face.verts) < 3:
                bm.faces.remove(new_face)
                continue
            new_face.material_index = material_index[material_name]
    bmesh.ops.triangulate(bm, faces=list(bm.faces), quad_method="BEAUTY",
                          ngon_method="BEAUTY")
    loose = [vert for vert in bm.verts if not vert.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    empty_faces = [face for face in bm.faces if face.calc_area() < 1e-12]
    if empty_faces:
        bmesh.ops.delete(bm, geom=empty_faces, context="FACES_ONLY")
    loose = [vert for vert in bm.verts if not vert.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    mesh = bpy.data.meshes.new(lod1_name(entry["asset"]))
    bm.to_mesh(mesh)
    bm.free()

    for name in material_order:
        material = bpy.data.materials.get(name)
        if material is None:
            raise RuntimeError("missing shared material %s" % name)
        mesh.materials.append(material)
    mesh.update()

    correction = _remap_bounds(mesh, target_low, target_high)
    obj = bpy.data.objects.new(lod1_name(entry["asset"]), mesh)
    obj.matrix_world = root.matrix_world.copy()
    collection = _ensure_lod1_collection()
    collection.objects.link(obj)

    texture = shared.apply_to_object(obj, space="local")
    lod1_tris = _tri_count_mesh(mesh)
    bbox = {
        "min": [round(value, 6) for value in (min(v.co[axis] for v in mesh.vertices)
                                              for axis in range(3))],
        "max": [round(value, 6) for value in (max(v.co[axis] for v in mesh.vertices)
                                              for axis in range(3))],
    }
    lod1_health = _mesh_health(mesh)
    obj["lod_level"] = 1
    obj["lod_source"] = entry["asset"]
    obj["lod0_triangles"] = lod0_tris
    obj["lod1_triangles"] = lod1_tris
    obj["lod1_tri_cap"] = plan["cap_tris"]
    obj["lod1_target_ratio"] = plan["target_ratio"]
    obj["lod1_big_ratio"] = plan["big_ratio"]
    obj["lod1_generator"] = "sn_lod1_kit_ships_generator.build_all"
    obj["lod1_sources"] = len(sources)

    return {
        "asset": entry["asset"], "kind": entry["kind"], "family": entry["family"],
        "category": entry["category"], "object": obj.name,
        "lod0_tris": lod0_tris, "lod1_tris": lod1_tris,
        "ratio": round(lod1_tris / float(lod0_tris), 6) if lod0_tris else 99.0,
        "cap_ratio": plan["cap_ratio"], "cap_tris": plan["cap_tris"],
        "target_tris": plan["target_tris"], "big_ratio": plan["big_ratio"],
        "small_tris": small_tris, "source_objects": len(sources),
        "health_lod0": lod1_health_lod0, "health_lod1": lod1_health,
        "bbox_lod0_root_local": {"min": [round(value, 6) for value in target_low],
                                 "max": [round(value, 6) for value in target_high]},
        "bbox_lod1_local": bbox,
        "bbox_correction": correction,
        "uv": texture,
        "materials": [material.name for material in mesh.materials],
    }


def build_all(assets=None, clear=True):
    """Build every LOD1 object (or the requested subset) in the live workbench."""
    if clear:
        _clear_lod1()
    import sn_shared_materials as shared

    shared.build_materials()
    selected = None if assets is None else set(assets)
    results = {}
    cursor = -60.0
    for entry in PLAN:
        if selected is not None and entry["asset"] not in selected:
            continue
        report = _build_one(entry)
        obj = _bpy().data.objects[report["object"]]
        mesh = obj.data
        width = max(8.0, max(v.co.x for v in mesh.vertices)
                    - min(v.co.x for v in mesh.vertices))
        obj.location = (cursor + width * 0.5, PLACEMENT_Y, 0.0)
        cursor += width + 6.0
        results[entry["asset"]] = report
        print("BUILT %-26s LOD0 %5d -> LOD1 %4d tri (%.1f%%, cap %d) %s" % (
            entry["asset"], report["lod0_tris"], report["lod1_tris"],
            report["ratio"] * 100.0, report["cap_tris"],
            "" if report["health_lod1"]["non_manifold_edges"] == 0 else "NONMANIFOLD"))
    _bpy().context.view_layer.update()
    return results


# --------------------------------------------------------------------------- #
# Blender-side report / export
# --------------------------------------------------------------------------- #

def _report_path():
    return os.path.join(WORK_DIR, "lod1_build_report.json")


def report(results=None):
    """Gate every built LOD1: budget, bbox, mesh health, materials, UV."""
    bpy = _bpy()
    results = results or build_all(clear=False)
    failures = []
    assets = {}
    for entry in PLAN:
        asset = entry["asset"]
        if asset not in results:
            continue
        row = dict(results[asset])
        checks = {}
        checks["tri_within_cap"] = row["lod1_tris"] <= row["cap_tris"]
        checks["tri_ratio_within_cap"] = row["ratio"] <= row["cap_ratio"] + 1e-9
        health0 = row["health_lod0"]
        health1 = row["health_lod1"]
        checks["no_new_non_manifold"] = health1["non_manifold_edges"] <= health0["non_manifold_edges"]
        checks["no_new_boundary"] = health1["boundary_edges"] <= health0["boundary_edges"]
        checks["no_new_wire"] = health1["wire_edges"] <= health0["wire_edges"]
        checks["degenerate_zero"] = health1["degenerate_faces"] == 0
        checks["loose_verts_zero"] = health1["loose_verts"] == 0
        target = row["bbox_lod0_root_local"]
        actual = row["bbox_lod1_local"]
        delta = max(abs(actual["min"][axis] - target["min"][axis]) for axis in range(3))
        delta = max(delta, max(abs(actual["max"][axis] - target["max"][axis])
                               for axis in range(3)))
        row["bbox_delta"] = round(delta, 6)
        checks["bbox_matches_lod0"] = delta <= 0.0005
        checks["uv_complete"] = bool(row["uv"].get("ok")) and row["uv"]["uv_loops"] > 0
        checks["materials_shared"] = all(name.startswith(TEXTURE_PREFIX)
                                         for name in row["materials"])
        row["checks"] = checks
        row["passed"] = all(checks.values())
        for name, passed in checks.items():
            if not passed:
                failures.append("%s: %s" % (asset, name))
        assets[asset] = row
    payload = {"assets": assets, "failures": failures,
               "passed": not failures,
               "totals": {
                   "assets": len(assets),
                   "lod0_tris": sum(row["lod0_tris"] for row in assets.values()),
                   "lod1_tris": sum(row["lod1_tris"] for row in assets.values()),
               }}
    os.makedirs(WORK_DIR, exist_ok=True)
    with open(_report_path(), "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, ensure_ascii=False)
    print("LOD1_REPORT %r" % {"passed": payload["passed"], "assets": len(assets),
                              "lod1_tris": payload["totals"]["lod1_tris"],
                              "failures": failures})
    return payload


def export_candidates(assets=None):
    """Export each LOD1 as a single-object GLB and externalize shared textures."""
    import glb_shared_textures as textures

    bpy = _bpy()
    results = {}
    selected = None if assets is None else set(assets)
    for entry in PLAN:
        asset = entry["asset"]
        if selected is not None and asset not in selected:
            continue
        obj = bpy.data.objects.get(lod1_name(asset))
        if obj is None:
            results[asset] = {"ok": False, "error": "LOD1 object missing"}
            continue
        from mathutils import Matrix
        embedded, final = candidate_paths(asset)
        category = entry["category"]
        os.makedirs(os.path.dirname(embedded), exist_ok=True)
        original_matrix = obj.matrix_world.copy()
        saved_selection = list(bpy.context.selected_objects)
        saved_active = bpy.context.view_layer.objects.active
        was_hidden = obj.hide_get()
        try:
            obj.hide_set(False)
            obj.matrix_world = Matrix.Identity(4)
            bpy.context.view_layer.update()
            for other in bpy.context.selected_objects:
                other.select_set(False)
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            bpy.ops.export_scene.gltf(
                filepath=embedded,
                export_format="GLB",
                use_selection=True,
                export_apply=True,
                export_cameras=False,
                export_lights=False,
                export_yup=True,
                export_extras=True,
            )
        finally:
            obj.matrix_world = original_matrix
            obj.hide_set(was_hidden)
            obj.select_set(False)
            for other in saved_selection:
                other.select_set(True)
            bpy.context.view_layer.objects.active = saved_active
            bpy.context.view_layer.update()
        final_dir = os.path.dirname(final)
        external = textures.externalize_glb(
            embedded, final,
            shared_dir=os.path.join(final_dir, "shared_materials"),
            uri_prefix=URI_PREFIX,
            tiles_dir=TILES_DIR,
            write_pngs=True,
            prefer_authored=True,
        )
        structure = textures.structure_report(final)
        results[asset] = {
            "ok": True, "category": category,
            "embedded": os.path.relpath(embedded, REPO_ROOT),
            "glb": os.path.relpath(final, REPO_ROOT),
            "bytes": structure["bytes"], "tris": structure["tris"],
            "nodes": [node["name"] for node in structure["nodes"]],
            "materials": [material["name"] for material in structure["materials"]],
            "images": [image.get("uri") for image in structure["images"]],
            "tiles_match": all(png.get("tile_matches", True) for png in external.get("pngs", [])),
            "bytes_saved": external.get("bytes_saved", 0),
        }
        print("EXPORTED %-26s %5d tri %8d B %s" % (
            asset, results[asset]["tris"], results[asset]["bytes"],
            "PASS" if results[asset]["tiles_match"] else "TILE-MISMATCH"))
    payload = {"assets": results, "failures": [asset for asset, row in results.items()
                                               if not row.get("ok") or not row.get("tiles_match", True)]}
    payload["passed"] = not payload["failures"]
    path = os.path.join(WORK_DIR, "lod1_export_report.json")
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, ensure_ascii=False)
    print("LOD1_EXPORT %r" % {"count": len(results), "passed": payload["passed"],
                              "report": os.path.relpath(path, REPO_ROOT)})
    return payload


def save_workbench(path=None):
    """Save the workbench snapshot (call only after acceptance)."""
    import shutil
    import time

    bpy = _bpy()
    path = path or WORKBENCH_PATH
    backup = os.path.join(WORK_DIR, "SN_Asset_Workbench_pre_lod1_%s.blend"
                          % time.strftime("%Y%m%d-%H%M%S"))
    if os.path.exists(path):
        os.makedirs(WORK_DIR, exist_ok=True)
        shutil.copy2(path, backup)
    bpy.ops.wm.save_as_mainfile(filepath=path)
    return {"ok": True, "workbench": os.path.relpath(path, REPO_ROOT),
            "backup": os.path.relpath(backup, REPO_ROOT) if os.path.exists(backup) else None}


if __name__ == "__main__":
    print("sn_lod1_kit_ships_generator: run inside Blender via "
          "build_all() / report() / export_candidates() / save_workbench()")
