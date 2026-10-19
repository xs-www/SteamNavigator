# -*- coding: utf-8 -*-
"""可复用船体装配层：把纯 Python 的 Part 字典装配进 Blender 集合。

各船生成器只提供：
- `parts: {object_name: (Part, parent_key)}`
- 集合/前缀/根节点/摆位/材质调色板/Pivot/铭牌等 `BuildConfig`

本模块负责清理、建集合、材质、父级、文字铭牌与 report，避免每艘船复制一遍
`_make_object` / `_ensure_material`。所有 bpy 导入都在函数内部，纯 Python 干跑
加载生成器时不会误触发 Blender。
"""

from dataclasses import dataclass, field

from .core import Part, tri_count


@dataclass
class PivotSpec:
    key: str
    name: str
    location: tuple
    rotation: tuple = (0.0, 0.0, 0.0)
    size: float = 1.2


@dataclass
class BuildConfig:
    collection: str
    prefix: str
    root_name: str
    workbench_pos: tuple
    material_colors: dict
    material_reuse: dict
    root_props: dict
    pivots: list = field(default_factory=list)       # list[PivotSpec]
    origins: dict = field(default_factory=dict)      # parent_key -> origin
    name_plates: dict = field(default_factory=dict)  # name -> text spec
    text_material: str = "SN_Brass"
    report_title: str = "Ship"
    tri_budget: int = 0
    root_size: float = 3.0


def _clean_previous(cfg):
    import bpy
    for ob in list(bpy.data.objects):
        if ob.name.startswith(cfg.prefix):
            bpy.data.objects.remove(ob, do_unlink=True)
    old = bpy.data.collections.get(cfg.collection)
    if old is not None:
        bpy.data.collections.remove(old)
    for me in list(bpy.data.meshes):
        if me.name.startswith(cfg.prefix) and me.users == 0:
            bpy.data.meshes.remove(me)
    for cu in list(bpy.data.curves):
        if cu.name.startswith(cfg.prefix):
            bpy.data.curves.remove(cu)


def _ensure_material(name, cfg):
    import bpy
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    spec = cfg.material_colors.get(name) or cfg.material_reuse[name]
    color, rough, metal = spec
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        out = next((n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"), None)
        if out is None:
            out = nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(bsdf.outputs[0], out.inputs[0])
    bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    mat.diffuse_color = (color[0], color[1], color[2], 1.0)
    mat.roughness = rough
    mat.metallic = metal
    mat.use_backface_culling = False
    return mat


def _make_object(name, part, collection, parent, cfg, origin=(0.0, 0.0, 0.0)):
    import bpy
    import bmesh
    me = bpy.data.meshes.new(name)
    local = [(x - origin[0], y - origin[1], z - origin[2])
             for (x, y, z) in part.verts]
    me.from_pydata(local, [], [f for f, _m in part.faces])
    me.validate(verbose=False)
    me.update()
    if len(me.polygons) != len(part.faces):
        raise RuntimeError("%s: 面数在 validate 后变化（%d -> %d）" % (
            name, len(part.faces), len(me.polygons)))
    if getattr(part, "recalc", True):
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        me.update()
    slots = []
    for _f, mat_name in part.faces:
        if mat_name not in slots:
            slots.append(mat_name)
    for mat_name in slots:
        me.materials.append(_ensure_material(mat_name, cfg))
    for poly, (_f, mat_name) in zip(me.polygons, part.faces):
        poly.material_index = slots.index(mat_name)
        poly.use_smooth = False
    ob = bpy.data.objects.new(name, me)
    collection.objects.link(ob)
    if parent is not None:
        ob.parent = parent
    return ob


def _add_empty(name, location, parent, collection, size=1.0):
    import bpy
    ob = bpy.data.objects.new(name, None)
    ob.empty_display_type = "PLAIN_AXES"
    ob.empty_display_size = size
    ob.location = location
    collection.objects.link(ob)
    if parent is not None:
        ob.parent = parent
    return ob


def _add_text(name, spec, collection, parent, material):
    """文字铭牌：FONT 曲线转 mesh，旋转/平移到船体坐标。"""
    import bpy
    import bmesh
    from mathutils import Matrix, Vector
    cu = bpy.data.curves.new(name + "_Curve", 'FONT')
    cu.body = spec["text"]
    cu.size = spec["size"]
    cu.extrude = 0.004
    cu.resolution_u = 1
    cu.align_x = 'CENTER'
    cu.align_y = 'CENTER'
    ob = bpy.data.objects.new(name + "_Tmp", cu)
    collection.objects.link(ob)
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob, do_unlink=True)
    bpy.data.curves.remove(cu)
    me.name = name
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-5, edges=bm.edges)
    zero = [f for f in bm.faces if f.calc_area() < 1e-10]
    if zero:
        bmesh.ops.delete(bm, geom=zero, context="FACES")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.update()
    rot = Matrix(spec["matrix"])
    base = Vector(spec["base"])
    for v in me.vertices:
        v.co = rot @ v.co + base
    me.materials.append(material)
    for poly in me.polygons:
        poly.material_index = 0
        poly.use_smooth = False
    ob = bpy.data.objects.new(name, me)
    collection.objects.link(ob)
    if parent is not None:
        ob.parent = parent
    return ob


def build_collection(parts, cfg):
    """幂等重建整船集合；parts 顺序决定对象创建顺序。"""
    import bpy
    _clean_previous(cfg)
    col = bpy.data.collections.new(cfg.collection)
    bpy.context.scene.collection.children.link(col)

    root = bpy.data.objects.new(cfg.root_name, None)
    root.empty_display_type = "PLAIN_AXES"
    root.empty_display_size = cfg.root_size
    root.location = cfg.workbench_pos
    col.objects.link(root)
    for key, value in cfg.root_props.items():
        root[key] = value

    pivots = {}
    for spec in cfg.pivots:
        pivot = _add_empty(spec.name, spec.location, root, col, spec.size)
        pivot.rotation_euler = spec.rotation
        pivots[spec.key] = pivot

    for name, (part, parent_key) in parts.items():
        parent = root if parent_key == "ROOT" else pivots[parent_key]
        origin = cfg.origins.get(parent_key, (0.0, 0.0, 0.0))
        _make_object(name, part, col, parent, cfg, origin)

    text_mat = _ensure_material(cfg.text_material, cfg)
    for name, spec in cfg.name_plates.items():
        _add_text(name, spec, col, root, text_mat)
    bpy.context.view_layer.update()
    return col


def report(cfg, verbose=True):
    """只读统计：对象 / 三角面 / 包围盒 / 材质 / 命名。"""
    import bpy
    from mathutils import Vector
    col = bpy.data.collections[cfg.collection]
    meshes = [o for o in col.objects if o.type == "MESH"]
    empties = [o for o in col.objects if o.type == "EMPTY"]
    tris = 0
    mn = Vector((1e18, 1e18, 1e18))
    mx = Vector((-1e18, -1e18, -1e18))
    for ob in meshes:
        tris += sum(max(1, len(p.vertices) - 2) for p in ob.data.polygons)
        for c in ob.bound_box:
            p = ob.matrix_world @ Vector(c)
            for i in range(3):
                mn[i] = min(mn[i], p[i])
                mx[i] = max(mx[i], p[i])
    mats = sorted({m.name for ob in meshes for m in ob.data.materials if m})
    info = {
        "collection": cfg.collection,
        "root": cfg.root_name,
        "objects": len(col.objects),
        "meshes": len(meshes),
        "empties": len(empties),
        "tris": tris,
        "bbox": [round(mx[i] - mn[i], 3) for i in range(3)],
        "bbox_min": [round(mn[i], 3) for i in range(3)],
        "bbox_max": [round(mx[i], 3) for i in range(3)],
        "materials": mats,
        "root_location": [round(v, 3)
                          for v in bpy.data.objects[cfg.root_name].location],
    }
    if verbose:
        print("%s: %d 对象 / %d 网格 / %d 空物体" % (
            cfg.report_title, info["objects"], info["meshes"], info["empties"]))
        print("三角面: %d / 预算 %d" % (tris, cfg.tri_budget))
        print("包围盒: %.2f x %.2f x %.2f m  (min %s / max %s)" % (
            info["bbox"][0], info["bbox"][1], info["bbox"][2],
            info["bbox_min"], info["bbox_max"]))
        print("材质: %s" % ", ".join(mats))
        print("根节点位置: %s" % info["root_location"])
        print("对象清单:")
        for ob in sorted(col.objects, key=lambda o: o.name):
            if ob.type == "MESH":
                t = sum(max(1, len(p.vertices) - 2) for p in ob.data.polygons)
                print("  %-34s mesh  %5d tri  parent=%s" % (
                    ob.name, t, ob.parent.name if ob.parent else "-"))
            else:
                print("  %-34s empty" % ob.name)
    return info
