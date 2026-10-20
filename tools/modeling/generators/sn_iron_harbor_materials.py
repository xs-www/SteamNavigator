"""Shared material library + trim-sheet derived tiling textures for the SN iron-harbor kit.

Every iron-harbor building generator imports this module instead of inventing
materials, so the whole kit (warehouse_long, warehouse_short, harbor_office,
cargo_shed, tavern, ...) samples ONE shared texture set and ONE shared shader
setup.  The 6 palette slots (`SN_Town_Brick / Plaster / Wood / Iron / Stone /
Glass`) are fixed by the brief: adding a slot costs a draw call per building,
so the surface variety lives in the trim sheet, not in extra materials.

Texture source
--------------
`docs/design/textures/iron_harbor/iron_harbor_trim_sheet_2048.spec.json` is the
single authored source (16 cells, 4x4, 512 px each, 2.0 m of surface per cell at
256 px/m).  `tools/art/gen_iron_harbor_trim_sheet.py` paints it into

    docs/design/textures/iron_harbor/iron_harbor_trim_sheet_2048.png   (review montage)
    docs/design/textures/iron_harbor/tiles/<cell_id>.png                (one tiling texture per cell)

Why per-cell tile files instead of sampling the atlas directly: the walls, roof,
plinth and gutters are single quads up to 20 m long, and a UV range confined to
an atlas cell (CLAMP) cannot tile across such a face without cutting the mesh up
(measured: +1 484 triangles at a 4 m cell, over the 8 000 triangle budget).  With
one repeat-wrapped texture per material the UVs are simply unbounded
(`world / tile_m`), so a 20 m wall repeats the brick 10 times for free and the
geometry is untouched.  The 2048 atlas stays the reviewable "trim sheet".

UV rules (`apply_to_object`)
----------------------------
* box projection on the face's dominant normal axis, so every face keeps its
  own scale and nothing is stretched by more than the 45 deg chamfer faces;
* `u = world_u / tile_m`, `v = world_v / tile_m` (unbounded, sampler REPEAT), so
  the pattern flows continuously across adjacent faces and parts: brick courses
  stay level around the whole building, the roof ribs run down the slope
  (`u = X`, `v = Y` on the Z-dominant roof faces) and the vertical door planks
  stay vertical (`v = Z` on the Y-dominant wall faces).

Run inside Blender through the MCP `execute_blender_code` tool:

    import importlib.util
    p = r"<repo>/tools/modeling/generators/sn_iron_harbor_materials.py"
    spec = importlib.util.spec_from_file_location("sn_iron_harbor_materials", p)
    MAT = importlib.util.module_from_spec(spec); spec.loader.exec_module(MAT)
    MAT.build_materials()
    MAT.apply_to_object(bpy.data.objects["SN_HT_Warehouse_Long_LOD0"])

Everything except `build_materials()` / `apply_to_object()` / `verify_object()`
is pure Python, so the spec can be validated outside Blender.
"""

import json
import math
import os

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SPEC_PATH = os.path.join(REPO_ROOT, "docs", "design", "textures", "iron_harbor",
                         "iron_harbor_trim_sheet_2048.spec.json")

# Material slot -> the trim-sheet cell it samples and the shader numbers.
# `tile_m` is how many metres of surface one texture repeat covers; it is the
# only place the texel density of a material is defined.
MATERIAL_SURFACES = {
    "SN_Town_Brick":   {"cell": "brick_wall",    "tile_m": 2.0, "roughness": 0.86, "metallic": 0.00},
    "SN_Town_Plaster": {"cell": "plaster_light", "tile_m": 2.0, "roughness": 0.84, "metallic": 0.00},
    "SN_Town_Wood":    {"cell": "wood_plank_weathered", "tile_m": 2.0, "roughness": 0.78, "metallic": 0.00},
    "SN_Town_Iron":    {"cell": "iron_dark",     "tile_m": 2.0, "roughness": 0.62, "metallic": 0.55},
    "SN_Town_Stone":   {"cell": "stone_base_dirty", "tile_m": 2.0, "roughness": 0.90, "metallic": 0.00},
    "SN_Town_Glass":   {"cell": "glass_dark",    "tile_m": 2.0, "roughness": 0.22, "metallic": 0.15},
}

UV_LAYER = "UVMap"


def _resolve_cells(cells=None):
    """material name -> trim-sheet cell id, with per-building overrides.

    The kit language fixes the six material slots, but different buildings may
    sample different cells of the same trim sheet (sooty brick for a warehouse,
    clean ashlar for the office, weathered planks for the tavern, ...).  `cells`
    is `{material: cell_id}`; unknown names or cells raise instead of silently
    falling back, because a typo would otherwise ship the wrong surface.
    """
    resolved = {name: surface["cell"] for name, surface in MATERIAL_SURFACES.items()}
    for name, cell_id in (cells or {}).items():
        if name not in MATERIAL_SURFACES:
            raise KeyError("cell override for unknown material: %s" % name)
        known = {c["id"] for c in load_spec()["cells"]}
        if cell_id not in known:
            raise KeyError("cell override %s -> unknown trim sheet cell %r" % (name, cell_id))
        resolved[name] = cell_id
    return resolved


# --------------------------------------------------------------------------- #
# spec / tile lookup (pure python)
# --------------------------------------------------------------------------- #

_SPEC = {}
_SPEC_SOURCE = None


def load_spec(path=None):
    """Read and cache the trim-sheet spec, with a schema sanity check."""
    global _SPEC_SOURCE
    path = path or SPEC_PATH
    if _SPEC and _SPEC_SOURCE == path:
        return _SPEC
    with open(path, encoding="utf-8") as handle:
        spec = json.load(handle)
    grid = spec.get("grid", {})
    cells = spec.get("cells", [])
    seen = set()
    for cell in cells:
        cid = cell.get("id")
        if not cid:
            raise ValueError("trim sheet cell without id: %r" % (cell,))
        if cid in seen:
            raise ValueError("duplicate trim sheet cell id: %s" % cid)
        seen.add(cid)
        if not (0 <= int(cell["col"]) < int(grid["cols"]) and
                0 <= int(cell["row"]) < int(grid["rows"])):
            raise ValueError("cell %s outside the %dx%d grid" % (cid, grid["cols"], grid["rows"]))
    missing = [cid for cid in (s["cell"] for s in MATERIAL_SURFACES.values()) if cid not in seen]
    if missing:
        raise ValueError("materials reference unknown trim sheet cells: %s" % missing)
    _SPEC.clear()
    _SPEC.update(spec)
    _SPEC_SOURCE = path
    return _SPEC


def cell_entry(cell_id):
    for cell in load_spec()["cells"]:
        if cell["id"] == cell_id:
            return cell
    raise KeyError(cell_id)


def tile_path(cell_id):
    spec = load_spec()
    root = spec["outputs"]["tiles"]
    return os.path.join(REPO_ROOT, root, cell_id + ".png") if not os.path.isabs(root) \
        else os.path.join(root, cell_id + ".png")


def atlas_path():
    spec = load_spec()
    return os.path.join(REPO_ROOT, spec["outputs"]["png"])


def missing_tiles(cells=None):
    """Cell ids whose painted tile file is not on disk yet."""
    return [cid for cid in _resolve_cells(cells).values() if not os.path.exists(tile_path(cid))]


def texture_stats(cells=None):
    """Per-material texture facts for reports (file size, density, cell)."""
    spec = load_spec()
    resolved = _resolve_cells(cells)
    out = {}
    for name, surface in sorted(MATERIAL_SURFACES.items()):
        path = tile_path(resolved[name])
        exists = os.path.exists(path)
        out[name] = {
            "cell": resolved[name],
            "tile": os.path.relpath(path, REPO_ROOT) if exists else None,
            "tile_bytes": os.path.getsize(path) if exists else None,
            "cell_px": int(spec["grid"]["cell_px"]),
            "tile_m": surface["tile_m"],
            "px_per_m": round(spec["grid"]["cell_px"] / surface["tile_m"], 1),
            "roughness": surface["roughness"],
            "metallic": surface["metallic"],
        }
    out["_atlas"] = {
        "path": os.path.relpath(atlas_path(), REPO_ROOT) if os.path.exists(atlas_path()) else None,
        "bytes": os.path.getsize(atlas_path()) if os.path.exists(atlas_path()) else None,
    }
    return out


# --------------------------------------------------------------------------- #
# Blender side: materials
# --------------------------------------------------------------------------- #

def _load_image(cell_id):
    """Load (or reuse) the packed tile image; returns None if it is missing."""
    import bpy

    path = tile_path(cell_id)
    if not os.path.exists(path):
        return None
    name = "SN_TEX_" + cell_id
    image = bpy.data.images.get(name)
    if image is None or os.path.abspath(bpy.path.abspath(image.filepath)) != os.path.abspath(path):
        image = bpy.data.images.load(path, check_existing=True)
        image.name = name
    image.colorspace_settings.name = "sRGB"
    return image


def build_materials(force=True, cells=None):
    """Create/refresh the 6 kit materials with the shared tile textures.

    Returns {material: {texture, image, tile_m, uv_scale, ...}}.  When a tile is
    missing the material falls back to the flat grey placeholder colour and the
    entry reports `texture: None`, so the pipeline can still run a geometry pass.
    """
    import bpy

    out = {}
    resolved = _resolve_cells(cells)
    for name, surface in MATERIAL_SURFACES.items():
        mat = bpy.data.materials.get(name)
        if mat is None:
            mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        tree = mat.node_tree
        image = _load_image(resolved[name])
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
                tex.name = "TrimSheet"
                tex.image = image
                tex.interpolation = "Linear"
                tex.extension = "REPEAT"
                tex.location = (-360, 0)
                tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
                mat.diffuse_color = (0.5, 0.5, 0.5, 1.0)
            else:
                # Grey placeholder (R=G=B) so a material-less build still renders.
                tint = {"SN_Town_Brick": 0.345, "SN_Town_Plaster": 0.560, "SN_Town_Wood": 0.215,
                        "SN_Town_Iron": 0.120, "SN_Town_Stone": 0.445, "SN_Town_Glass": 0.050}[name]
                bsdf.inputs["Base Color"].default_value = (tint, tint, tint, 1.0)
                mat.diffuse_color = (tint, tint, tint, 1.0)
            bsdf.inputs["Roughness"].default_value = surface["roughness"]
            bsdf.inputs["Metallic"].default_value = surface["metallic"]
            try:
                bsdf.inputs["Specular IOR Level"].default_value = 0.4
            except KeyError:
                pass
        mat.use_backface_culling = False
        out[name] = {
            "cell": resolved[name],
            "texture": os.path.relpath(tile_path(resolved[name]), REPO_ROOT) if image else None,
            "image": image.name if image else None,
            "image_px": list(image.size) if image else None,
            "tile_m": surface["tile_m"],
        }
    return out


# --------------------------------------------------------------------------- #
# Blender side: UVs
# --------------------------------------------------------------------------- #

def _project_axes(normal):
    """Dominant-axis box projection: returns (u_index, v_index) for a face."""
    ax = max(range(3), key=lambda i: abs(normal[i]))
    if ax == 0:      # +-X wall: u = Y (run), v = Z (height)
        return 1, 2
    if ax == 1:      # +-Y wall: u = X (run), v = Z (height)
        return 0, 2
    return 0, 1      # roof / floor: u = X, v = Y (ribs run down the slope)


def apply_to_object(obj, build=True, cells=None):
    """Texture-map every face of `obj` and return a verification dict.

    Geometry is not touched: only the UV layer and the material slots change.
    """
    import bpy

    if build:
        materials = build_materials(cells=cells)
    else:
        materials = {name: {"tile_m": surface["tile_m"], "cell": _resolve_cells(cells)[name]}
                     for name, surface in MATERIAL_SURFACES.items()}
    mesh = obj.data
    before = {"verts": len(mesh.vertices), "polys": len(mesh.polygons),
              "loops": len(mesh.loops)}

    # Palette-only slots, in the object's existing slot order when possible.
    slot_names = [m.name for m in mesh.materials if m is not None]
    wanted = [name for name in MATERIAL_SURFACES if name in slot_names]
    for name in MATERIAL_SURFACES:
        if name not in wanted:
            wanted.append(name)
    # `mesh.materials.clear()` resets every polygon's material_index, so the
    # per-face palette name has to be read out *before* the slots are rebuilt.
    face_materials = [slot_names[p.material_index] if slot_names else None
                      for p in mesh.polygons]
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
            return {"ok": False, "error": "polygon %d has no palette material" % poly.index}
        poly.material_index = index[name]
        usage[name] = usage.get(name, 0) + 1

    uv_layer = mesh.uv_layers.get(UV_LAYER) or mesh.uv_layers.new(name=UV_LAYER)
    uv_layer.active = True
    u_min = v_min = float("inf")
    u_max = v_max = float("-inf")
    for poly in mesh.polygons:
        tile = materials[mesh.materials[poly.material_index].name]["tile_m"]
        ua, va = _project_axes(poly.normal)
        for li in range(poly.loop_start, poly.loop_start + poly.loop_total):
            co = mesh.vertices[mesh.loops[li].vertex_index].co
            u = co[ua] / tile
            v = co[va] / tile
            uv_layer.data[li].uv = (u, v)
            u_min, u_max = min(u_min, u), max(u_max, u)
            v_min, v_max = min(v_min, v), max(v_max, v)
    mesh.update()

    after = {"verts": len(mesh.vertices), "polys": len(mesh.polygons),
             "loops": len(mesh.loops)}
    textured = sum(1 for m in materials.values() if m.get("image"))
    return {
        "ok": True,
        "geometry_unchanged": before == after,
        "before": before,
        "after": after,
        "uv_layer": uv_layer.name,
        "uv_loops": len(mesh.loops),
        "uv_range_u": [round(u_min, 3), round(u_max, 3)],
        "uv_range_v": [round(v_min, 3), round(v_max, 3)],
        "material_slots": [m.name for m in mesh.materials],
        "material_usage": usage,
        "textured_slots": textured,
        "materials": materials,
    }


def verify_object(obj):
    """Checks a textured kit object: slots, UVs, image bindings, texel facts."""
    import bpy

    mesh = obj.data
    slots = [m.name if m else None for m in mesh.materials]
    uv_layer = mesh.uv_layers.get(UV_LAYER)
    checks = {
        "palette_only": all(name in MATERIAL_SURFACES for name in slots if name),
        "slot_count_ok": 0 < len(slots) <= 6,
        "uv_layer_present": uv_layer is not None,
        "uv_loops_complete": bool(uv_layer) and len(uv_layer.data) == len(mesh.loops),
        "all_images_bound": True,
        "images_512": True,
        "uv_projection_ok": bool(uv_layer),
    }
    bound = []
    for poly in mesh.polygons:
        name = slots[poly.material_index] if poly.material_index < len(slots) else None
        mat = bpy.data.materials.get(name) if name else None
        if mat is None:
            checks["all_images_bound"] = False
            continue
        tex = next((n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE"), None)
        if tex is None or tex.image is None:
            checks["all_images_bound"] = False
            continue
        if tuple(tex.image.size) != (512, 512):
            checks["images_512"] = False
        if tex.image.name not in bound:
            bound.append(tex.image.name)
    degenerate_uv = 0
    uv_mismatch = 0
    usage = {}
    for poly in mesh.polygons:
        usage[poly.material_index] = usage.get(poly.material_index, 0) + 1
        if uv_layer is None:
            continue
        tile = MATERIAL_SURFACES.get(slots[poly.material_index], {}).get("tile_m", 2.0)
        ua, va = _project_axes(poly.normal)
        us = [uv_layer.data[li].uv for li in range(poly.loop_start, poly.loop_start + poly.loop_total)]
        if max(u[0] for u in us) - min(u[0] for u in us) < 1e-6 and \
           max(u[1] for u in us) - min(u[1] for u in us) < 1e-6:
            degenerate_uv += 1
        # Re-derive the expected box projection and compare: this is what catches a
        # wrong axis pair / wrong UV scale on the *next* building, not just a missing UV.
        for li in range(poly.loop_start, poly.loop_start + poly.loop_total):
            co = mesh.vertices[mesh.loops[li].vertex_index].co
            expected = (co[ua] / tile, co[va] / tile)
            actual = uv_layer.data[li].uv
            if abs(actual[0] - expected[0]) > 1e-4 or abs(actual[1] - expected[1]) > 1e-4:
                uv_mismatch += 1
    checks["uv_projection_ok"] = checks["uv_projection_ok"] and uv_mismatch == 0
    checks["palette_spread_ok"] = len(usage) >= 5
    checks["no_collapsed_uv_faces"] = degenerate_uv == 0
    checks["all_pass"] = all(checks.values())
    return {"checks": checks, "bound_images": bound, "degenerate_uv_faces": degenerate_uv,
            "uv_mismatched_loops": uv_mismatch,
            "material_usage": {slots[k]: v for k, v in sorted(usage.items())},
            "texture_stats": texture_stats()}


if "bpy" in globals():   # executed inside Blender
    print("sn_iron_harbor_materials: call build_materials() / apply_to_object(obj) / "
          "verify_object(obj); tiles missing: %s" % (missing_tiles(),))
